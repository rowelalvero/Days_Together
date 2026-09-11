import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The couple's Realtime presence channel -- "is my partner in the app right
/// now" -- extracted from `CoupleSession`, which owned the channel, the
/// online flag, and the subscribe/track/teardown lifecycle inline alongside
/// auth, key exchange, profile sync, and pairing.
///
/// Presence is the one piece of session state with no persisted form: it is
/// true only while both devices hold a live socket, and it resets to false on
/// every teardown path (sign-out, unlink, logout, dispose). Keeping that in
/// one place is what stops the four paths from drifting apart.
///
/// [onChanged] is the owner's `notifyListeners` -- called only when
/// [isPartnerOnline] actually flips, matching the "don't rebuild for no
/// reason" contract the rest of the session follows.
class PartnerPresence {
  PartnerPresence({required VoidCallback onChanged}) : _onChanged = onChanged;

  final VoidCallback _onChanged;

  RealtimeChannel? _channel;
  bool _isPartnerOnline = false;

  bool get isPartnerOnline => _isPartnerOnline;

  /// (Re)joins the couple's presence channel. Any existing channel is torn
  /// down first, so this is safe to call on every couple-identity change.
  /// With no user or couple there is nothing to join: the partner is reported
  /// offline and [onChanged] fires, matching what a teardown looks like to a
  /// watcher.
  void connect({
    required String? userId,
    required String? coupleId,
    required String? partnerId,
  }) {
    if (_channel != null) {
      try {
        _channel!.unsubscribe();
        Supabase.instance.client.removeChannel(_channel!);
      } catch (e) {
        debugPrint(
          'PartnerPresence: tearing down the previous channel failed: $e',
        );
      }
      _channel = null;
    }

    if (userId == null || coupleId == null) {
      _isPartnerOnline = false;
      _onChanged();
      return;
    }

    final channel = Supabase.instance.client.channel(
      'couple_presence_$coupleId',
    );
    _channel = channel;

    channel
        .onPresenceSync((_) {
          bool partnerFound = false;
          for (final presenceState in channel.presenceState()) {
            for (final presence in presenceState.presences) {
              if (presence.payload['user_id'] == partnerId) {
                partnerFound = true;
                break;
              }
            }
            if (partnerFound) break;
          }
          if (_isPartnerOnline != partnerFound) {
            _isPartnerOnline = partnerFound;
            _onChanged();
          }
        })
        .subscribe((status, [error]) async {
          if (status == RealtimeSubscribeStatus.subscribed) {
            try {
              await channel.track({
                'user_id': userId,
                'online_at': DateTime.now().toIso8601String(),
              });
            } catch (e) {
              debugPrint('PartnerPresence: track() failed: $e');
            }
          }
        });
  }

  /// Leaves the channel and reports the partner offline, without notifying --
  /// every caller (sign-out, unlink, logout) is already mid-teardown and
  /// notifies once at the end, so firing here would only add a rebuild.
  void disconnect() {
    _channel?.unsubscribe();
    _channel = null;
    _isPartnerOnline = false;
  }

  void dispose() {
    if (_channel != null) {
      try {
        _channel!.unsubscribe();
        Supabase.instance.client.removeChannel(_channel!);
      } catch (e) {
        debugPrint(
          'PartnerPresence: channel teardown during dispose failed: $e',
        );
      }
      _channel = null;
    }
    _isPartnerOnline = false;
  }
}
