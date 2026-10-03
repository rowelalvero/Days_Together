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
  /// [loadPartnerPublicKey] and [storeWrappedKey] default to the real
  /// Supabase read/RPC; they are injectable so the partner-key trust rules
  /// can be unit-tested (test/couple_key_exchange_test.dart).
  /// [onPartnerKeyChanged] fires when the server presents a partner key that
  /// differs from the pinned one -- see [KeyManagementService.checkPartnerKey].
  CoupleKeyExchange({
    required CoupleKeyExchangeIdentity Function() identity,
    KeyManagementService? keyManagementService,
    Future<String?> Function(String partnerId)? loadPartnerPublicKey,
    Future<void> Function(String partnerId, String wrappedKey)? storeWrappedKey,
    void Function(String partnerId)? onPartnerKeyChanged,
  }) : _identity = identity,
       _keys = keyManagementService ?? KeyManagementService.instance,
       _loadPartnerPublicKey = loadPartnerPublicKey ?? _loadFromSupabase,
       _storeWrappedKey = storeWrappedKey ?? _storeViaRpc,
       _onPartnerKeyChanged = onPartnerKeyChanged;

  final CoupleKeyExchangeIdentity Function() _identity;
  final KeyManagementService _keys;
  final Future<String?> Function(String partnerId) _loadPartnerPublicKey;
  final Future<void> Function(String partnerId, String wrappedKey)
  _storeWrappedKey;
  final void Function(String partnerId)? _onPartnerKeyChanged;

  static Future<String?> _loadFromSupabase(String partnerId) async {
    final partnerData = await Supabase.instance.client
        .from(Tables.users)
        .select('public_key')
        .eq('id', partnerId)
        .maybeSingle();
    final key = partnerData?['public_key'] as String?;
    return (key == null || key.isEmpty) ? null : key;
  }

  static Future<void> _storeViaRpc(String partnerId, String wrappedKey) =>
      Supabase.instance.client.rpc(
        'store_wrapped_key',
        params: {'p_recipient_id': partnerId, 'p_wrapped_key': wrappedKey},
      );

  /// The partner whose key changed and awaits the user's confirmation, if any.
  String? _partnerKeyChangedFor;
  String? get partnerKeyChangedFor => _partnerKeyChangedFor;

  /// The last wrapped key seen for the current couple, kept so it can be
  /// applied once the user accepts a changed partner key.
  ({String userId, String coupleId, String wrappedKey})? _lastSeenWrapped;

  /// The partner's current public key, but only if it is trusted: pinned now
  /// (first use) or equal to the pin. A changed key is withheld and reported.
  Future<String?> _trustedPartnerKey(
    String userId,
    String coupleId,
    String partnerId,
  ) async {
    final key = await _loadPartnerPublicKey(partnerId);
    if (key == null) return null;
    final trust = await _keys.checkPartnerKey(
      userId: userId,
      coupleId: coupleId,
      partnerId: partnerId,
      publicKeyBase64: key,
    );
    if (trust.isTrusted) return key;
    if (_partnerKeyChangedFor != partnerId) {
      _partnerKeyChangedFor = partnerId;
      _onPartnerKeyChanged?.call(partnerId);
    }
    return null;
  }

  /// The partner's current server-side public key, for the safety number
  /// (including a changed key the user is being asked to verify).
  Future<String?> currentPartnerPublicKey(String partnerId) =>
      _loadPartnerPublicKey(partnerId);

  /// The user confirmed (ideally after comparing safety numbers) that the
  /// partner's new key is genuine: pin it and complete whatever the change
  /// held up -- wrapping our couple key for them and/or applying a wrapped
  /// key they sent us.
  Future<void> acceptPartnerKey(String partnerId) async {
    final id = _identity();
    final userId = id.userId;
    final coupleId = id.coupleId;
    if (userId == null || coupleId == null || id.partnerId != partnerId) {
      return;
    }
    final key = await _loadPartnerPublicKey(partnerId);
    if (key == null) return;
    await _keys.acceptPartnerKey(
      userId: userId,
      coupleId: coupleId,
      partnerId: partnerId,
      publicKeyBase64: key,
    );
    _partnerKeyChangedFor = null;
    _lastWrappedForPartnerId = null;
    await wrapForPartnerIfHeld(partnerId);
    final seen = _lastSeenWrapped;
    if (seen != null && seen.userId == userId && seen.coupleId == coupleId) {
      _lastAppliedWrappedKey = null;
      await _applyWrappedKey(userId, coupleId, seen.wrappedKey);
    }
  }

  /// Watches `couple_key_exchanges` for a row wrapped for this device --
  /// scoped to the authenticated user, not the couple, so it lives and dies
  /// alongside the session's own `users` subscription.
  StreamSubscription? _sub;

  String? _lastWrappedForPartnerId;

  /// Rows can arrive before the user and couple streams resolve the current
  /// relationship. Keep their couple ids so an old relationship's wrapped
  /// key can never take precedence over the current one.
  List<Map<String, dynamic>>? _pendingRows;

  /// The wrapped key most recently unwrapped and stored, so a re-emission of
  /// the same row is a no-op. A field rather than a closure local because
  /// [_applyWrappedKey] is also reached from [drainPending], outside the
  /// listener.
  String? _lastAppliedWrappedKey;
  String? _lastAppliedCoupleId;

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
            await _handleRows(userId, rows);
          },
          onError: (error) {
            debugPrint('couple_key_exchanges stream error: $error');
          },
        );
  }

  Future<void> _handleRows(
    String userId,
    List<Map<String, dynamic>> rows,
  ) async {
    final id = _identity();
    if (id.coupleId == null || id.partnerId == null) {
      _pendingRows = rows;
      return;
    }

    _pendingRows = null;
    final wrappedKeyBase64 = wrappedKeyForCouple(rows, id.coupleId!);
    if (wrappedKeyBase64 != null) {
      _lastSeenWrapped = (
        userId: userId,
        coupleId: id.coupleId!,
        wrappedKey: wrappedKeyBase64,
      );
    }
    if (wrappedKeyBase64 == null ||
        (wrappedKeyBase64 == _lastAppliedWrappedKey &&
            id.coupleId == _lastAppliedCoupleId)) {
      return;
    }
    await _applyWrappedKey(userId, id.coupleId!, wrappedKeyBase64);
  }

  /// Test seam: delivers `couple_key_exchanges` rows as the stream opened by
  /// [start] would (a plain `flutter test` cannot open that stream).
  @visibleForTesting
  Future<void> handleRowsForTest(
    String userId,
    List<Map<String, dynamic>> rows,
  ) => _handleRows(userId, rows);

  @visibleForTesting
  static String? wrappedKeyForCouple(
    List<Map<String, dynamic>> rows,
    String coupleId,
  ) {
    for (final row in rows) {
      if (row['couple_id'] == coupleId) {
        return row['wrapped_key'] as String?;
      }
    }
    return null;
  }

  /// Unwraps [wrappedKeyBase64] with the partner's public key and caches the
  /// resulting couple photo key in secure storage.
  Future<void> _applyWrappedKey(
    String userId,
    String coupleId,
    String wrappedKeyBase64,
  ) async {
    final id = _identity();
    final partnerId = id.partnerId;
    if (partnerId == null || id.coupleId != coupleId || id.userId != userId) {
      return;
    }
    try {
      final partnerPublicKey = await _trustedPartnerKey(
        userId,
        coupleId,
        partnerId,
      );
      if (partnerPublicKey == null) return;

      final coupleKeyBytes = await _keys.unwrapKeyFromPartner(
        userId: userId,
        wrappedKeyBase64: wrappedKeyBase64,
        partnerPublicKeyBase64: partnerPublicKey,
      );
      final current = _identity();
      if (current.userId != userId ||
          current.coupleId != coupleId ||
          current.partnerId != partnerId) {
        return;
      }
      await _keys.storeCoupleKey(userId, coupleKeyBytes, coupleId: coupleId);
      _lastAppliedWrappedKey = wrappedKeyBase64;
      _lastAppliedCoupleId = coupleId;
      completeWaiter();
    } catch (e) {
      debugPrint('Error unwrapping couple photo key: $e');
    }
  }

  /// Applies a wrapped key that arrived before the partner identity was
  /// known. Called by the couples stream the moment a partner resolves.
  void drainPending() {
    final pending = _pendingRows;
    final id = _identity();
    final userId = id.userId;
    if (pending == null ||
        userId == null ||
        id.partnerId == null ||
        id.coupleId == null) {
      return;
    }
    _handleRows(userId, pending);
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
    final id = _identity();
    final userId = id.userId;
    final coupleId = id.coupleId;
    if (userId == null || coupleId == null) return;
    try {
      final coupleKeyBytes = await _keys.loadCoupleKey(userId);
      if (coupleKeyBytes == null) return;

      // Only ever wrap for a TRUSTED key: a substituted public key would
      // otherwise receive the couple key (re-audit R-03 / audit F-14).
      final partnerPublicKey = await _trustedPartnerKey(
        userId,
        coupleId,
        partnerId,
      );
      if (partnerPublicKey == null) return;

      final wrapped = await _keys.wrapKeyForPartner(
        userId: userId,
        coupleKeyBytes: coupleKeyBytes,
        partnerPublicKeyBase64: partnerPublicKey,
      );
      await _storeWrappedKey(partnerId, wrapped);
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
    _pendingRows = null;
    _lastSeenWrapped = null;
    _partnerKeyChangedFor = null;
    _lastAppliedWrappedKey = null;
    _lastAppliedCoupleId = null;
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
