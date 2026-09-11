import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:days_together/core/security/key_management_service.dart';
import 'package:days_together/core/constants/tables.dart';

/// The three identity fields [CoupleKeyExchange] needs from its owner, read
/// fresh on every use rather than captured once: all three resolve
/// asynchronously and at different times (`userId` at sign-in, `partnerId`
/// and `coupleId` only once the couples stream produces a row), and the
/// ordering between them is exactly what this class exists to handle.
typedef CoupleKeyExchangeIdentity = ({
  String? userId,
  String? partnerId,
  String? coupleId,
});

/// Both halves of the E2EE photo-key exchange between the two paired
/// devices, extracted from `CoupleSession` (which owned the subscription,
/// four pieces of cached wrapped-key state, and six methods of exchange
/// protocol inline alongside auth, presence, profile sync, and pairing).
///
/// The receiving half is [start]: a `couple_key_exchanges` subscription,
/// scoped to the authenticated *user* rather than the couple, that unwraps
/// any key a partner device has wrapped for this one. The sending half is
/// [wrapForPartnerIfHeld]: if this device already holds the couple key, wrap
/// it for a newly-observed partner so their device can pick it up.
///
/// Nothing here reaches back into `CoupleSession`; it takes an [identity]
/// accessor instead, which is also what makes it unit-testable without a
/// live session.
class CoupleKeyExchange {
  CoupleKeyExchange({
    required CoupleKeyExchangeIdentity Function() identity,
    KeyManagementService? keyManagementService,
  }) : _identity = identity,
       _keys = keyManagementService ?? KeyManagementService.instance;

  final CoupleKeyExchangeIdentity Function() _identity;
  final KeyManagementService _keys;

  /// Watches `couple_key_exchanges` for a row wrapped for this device --
  /// scoped to the authenticated user, not the couple, so it lives and dies
  /// alongside the session's own `users` subscription.
  StreamSubscription? _sub;

  String? _lastWrappedForPartnerId;

  /// A wrapped key that arrived before the partner identity was known.
  /// Unwrapping needs the partner's public key, so the row cannot be applied
  /// yet -- and the stream will not re-emit an unchanged row, so dropping it
  /// would mean the couple photo key is never obtained on this device. Held
  /// until the couples stream resolves a partner, which drains it via
  /// [drainPending].
  String? _pendingWrappedKey;

  /// The wrapped key most recently unwrapped and stored, so a re-emission of
  /// the same row is a no-op. A field rather than a closure local because
  /// [_applyWrappedKey] is also reached from [drainPending], outside the
  /// listener.
  String? _lastAppliedWrappedKey;

  /// Completes as soon as this device holds the couple photo key, so callers
  /// that must encrypt something during onboarding (the avatar upload) can
  /// wait on the exchange instead of failing outright. See [waitForKey].
  Completer<void>? _waiter;

  /// Opens the receiving half of the exchange for the currently-signed-in
  /// user. A no-op when signed out.
  void start() {
    _sub?.cancel();
    final userId = _identity().userId;
    if (userId == null) return;

    _sub = Supabase.instance.client
        .from(Tables.coupleKeyExchanges)
        .stream(primaryKey: ['couple_id', 'recipient_user_id'])
        .eq('recipient_user_id', userId)
        .listen(
          (rows) async {
            if (rows.isEmpty) return;
            final wrappedKeyBase64 = rows.first['wrapped_key'] as String?;
            if (wrappedKeyBase64 == null ||
                wrappedKeyBase64 == _lastAppliedWrappedKey) {
              return;
            }
            // The partner's public key is required to unwrap, and the partner
            // id is routinely still null here: this stream is deliberately
            // scoped to the user rather than the couple, so it can (and on a
            // fresh join usually does) emit before the couples stream has
            // resolved a partner. Hold the row rather than dropping it --
            // Realtime will not re-send an unchanged row, so a drop was
            // permanent for the lifetime of that wrapped key.
            if (_identity().partnerId == null) {
              _pendingWrappedKey = wrappedKeyBase64;
              return;
            }
            await _applyWrappedKey(userId, wrappedKeyBase64);
          },
          onError: (error) {
            debugPrint('couple_key_exchanges stream error: $error');
          },
        );
  }

  /// Unwraps [wrappedKeyBase64] with the partner's public key and caches the
  /// resulting couple photo key in secure storage.
  Future<void> _applyWrappedKey(String userId, String wrappedKeyBase64) async {
    final id = _identity();
    final partnerId = id.partnerId;
    if (partnerId == null) return;
    try {
      final partnerData = await Supabase.instance.client
          .from(Tables.users)
          .select('public_key')
          .eq('id', partnerId)
          .maybeSingle();
      final partnerPublicKey = partnerData?['public_key'] as String?;
      if (partnerPublicKey == null || partnerPublicKey.isEmpty) return;

      final coupleKeyBytes = await _keys.unwrapKeyFromPartner(
        userId: userId,
        wrappedKeyBase64: wrappedKeyBase64,
        partnerPublicKeyBase64: partnerPublicKey,
      );
      await _keys.storeCoupleKey(userId, coupleKeyBytes, coupleId: id.coupleId);
      _lastAppliedWrappedKey = wrappedKeyBase64;
      completeWaiter();
    } catch (e) {
      debugPrint('Error unwrapping couple photo key: $e');
    }
  }

  /// Applies a wrapped key that arrived before the partner identity was
  /// known. Called by the couples stream the moment a partner resolves.
  void drainPending() {
    final pending = _pendingWrappedKey;
    final id = _identity();
    final userId = id.userId;
    if (pending == null || userId == null || id.partnerId == null) return;
    _pendingWrappedKey = null;
    _applyWrappedKey(userId, pending);
  }

  /// Resolves once this device holds the couple photo key, or after [timeout]
  /// if it never arrives.
  ///
  /// The joining side of a pairing has no key until the creator's device
  /// wraps one for it, which makes any encrypted upload in that window fail
  /// (`EncryptedStorageService` deliberately refuses to fall back to an
  /// unencrypted upload). Callers that can tolerate a short wait -- avatar
  /// upload during onboarding -- use this instead of failing immediately.
  /// Never throws: a timeout simply returns, and the caller decides what a
  /// missing key means for it.
  Future<void> waitForKey({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final userId = _identity().userId;
    if (userId == null) return;
    if (await _keys.loadCoupleKey(userId) != null) return;

    final waiter = _waiter ??= Completer<void>();
    try {
      await waiter.future.timeout(timeout);
    } catch (_) {
      // Timed out (or the waiter was replaced by a logout) -- not an error
      // here; the caller handles the still-missing key.
    }
  }

  /// Releases anyone blocked in [waitForKey]. Public because the session
  /// also obtains the couple key by *creating* it (workspace creation), not
  /// only by receiving one through this exchange.
  void completeWaiter() {
    final waiter = _waiter;
    if (waiter != null && !waiter.isCompleted) waiter.complete();
    _waiter = null;
  }

  /// The sending half: if this device already holds the couple photo key (it
  /// created the workspace, or it previously received one via [start]), wrap
  /// it for [partnerId] and store the wrapped copy so their device can pick
  /// it up. Called whenever the couples stream observes a *new* partner
  /// identity -- which covers both the original join (creator wraps for the
  /// joiner) and a later recovery (whichever side still holds the key
  /// re-wraps for whoever just claimed the vacant slot with a fresh keypair).
  ///
  /// A no-op if this device doesn't hold the couple key (the joining or
  /// recovering side never does) or the partner hasn't posted a public key
  /// yet -- there is no retry here; the next relevant realtime event (a fresh
  /// app launch re-observing the same partner counts) will try again.
  Future<void> wrapForPartnerIfHeld(String partnerId) async {
    if (_lastWrappedForPartnerId == partnerId) return;
    final userId = _identity().userId;
    if (userId == null) return;
    try {
      final coupleKeyBytes = await _keys.loadCoupleKey(userId);
      if (coupleKeyBytes == null) return;

      final partnerData = await Supabase.instance.client
          .from(Tables.users)
          .select('public_key')
          .eq('id', partnerId)
          .maybeSingle();
      final partnerPublicKey = partnerData?['public_key'] as String?;
      if (partnerPublicKey == null || partnerPublicKey.isEmpty) return;

      final wrapped = await _keys.wrapKeyForPartner(
        userId: userId,
        coupleKeyBytes: coupleKeyBytes,
        partnerPublicKeyBase64: partnerPublicKey,
      );
      await Supabase.instance.client.rpc(
        'store_wrapped_key',
        params: {'p_recipient_id': partnerId, 'p_wrapped_key': wrapped},
      );
      _lastWrappedForPartnerId = partnerId;
    } catch (e) {
      debugPrint('Error wrapping couple photo key for partner: $e');
    }
  }

  /// Forgets the in-memory exchange bookkeeping while leaving the
  /// subscription running. Used on unlink: the couple photo key belongs to
  /// the relationship being left, so keeping this state would make the
  /// *next* pairing's [wrapForPartnerIfHeld] push the dead relationship's key
  /// to the new partner.
  void clearCachedExchangeState() {
    _pendingWrappedKey = null;
    _lastAppliedWrappedKey = null;
    _lastWrappedForPartnerId = null;
  }

  /// Tears the exchange down to its signed-out state: subscription cancelled
  /// and all cached wrapped-key bookkeeping dropped. Deliberately does not
  /// touch the couple key held in secure storage, and does not release
  /// [waitForKey] callers -- a caller that wants both calls [completeWaiter]
  /// as well.
  void reset() {
    _sub?.cancel();
    _sub = null;
    clearCachedExchangeState();
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}
