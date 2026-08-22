import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:days_together/app_config.dart';
import 'package:days_together/core/constants/prefs_keys.dart';
import 'package:days_together/services/notification_service.dart';
import 'package:days_together/services/auth_service.dart';
import 'package:days_together/services/couple_service.dart';
import 'package:days_together/services/profile_service.dart';
import 'package:days_together/services/recent_activity_service.dart';
import 'package:days_together/services/relationship_lifecycle_manager.dart';
import 'package:days_together/services/home_widget_service.dart';
import 'package:days_together/services/storage_url_service.dart';

enum RelationshipStatus { waiting, active, disconnected, archived }

/// The app's single readiness/routing state, replacing today's inline
/// conditional chain in `main.dart`'s `AppHome._buildHomeContent`.
///
/// CURRENT STATE (Phase 1 of the architecture migration): computing this
/// correctly needs one field beyond `CoupleSession`'s own five identity
/// fields -- [startDate] -- to distinguish [needsWorkspace]/[needsGenesis]/
/// [needsAvatar]. The roadmap's original Phase 1 text ("computed once from
/// the five identity fields") undercounted this by one field; `startDate`
/// belongs to `WorkspaceController` (Phase 5), so until that extraction
/// lands, callers pass it in from `RelationshipProvider` directly. See
/// docs/architecture/migration-roadmap.md, Phase 1.
enum SessionStage {
  loading,
  unauthenticated,
  needsWorkspace,
  needsCouple,
  needsGenesis,
  needsAvatar,
  ready,
}

/// Pure readiness computation -- the one function in the codebase that
/// decides "is the user ready for the main app," matching
/// `main.dart`'s pre-Phase-1 `_buildHomeContent` branch-for-branch
/// (verified against `main.dart:188-218`).
SessionStage computeSessionStage({
  required bool isInitialized,
  required String? userId,
  required String? coupleId,
  required bool isCreator,
  required bool isPaired,
  required bool onboardingCompleted,
  required DateTime? startDate,
}) {
  if (!isInitialized) return SessionStage.loading;
  if (userId == null) return SessionStage.unauthenticated;
  if (onboardingCompleted && coupleId != null) return SessionStage.ready;

  if (coupleId != null) {
    if (isCreator) {
      if (!isPaired && startDate == null) return SessionStage.needsWorkspace;
      if (startDate == null) return SessionStage.needsGenesis;
    }
    return SessionStage.needsAvatar;
  }

  return SessionStage.needsCouple;
}

/// The app's real session/identity/pairing engine (Phase 6b-1 of the
/// architecture migration, "make CoupleSession real").
///
/// CURRENT STATE: owns the entire Supabase auth listener chain --
/// `onAuthStateChange` -> the `users` row stream -> the `couples` row
/// stream -- plus the partner-row stream and the presence channel, all of
/// which used to live on `RelationshipProvider`. This class is the *sole*
/// owner of realtime subscriptions on the `users`/`couples` tables: the
/// auth callback's `removeAllChannels()` call (fired on every auth event,
/// including routine hourly `tokenRefreshed` events, not just sign-in/out)
/// tears down every realtime channel in the app, so a second independent
/// listener anywhere else would race destructively against this one. See
/// docs/architecture/migration-roadmap.md's Phase 6b section for the full
/// investigation that led here.
///
/// `RelationshipProvider` no longer owns any of this. It becomes a thin
/// pass-through facade over the live `CoupleSession` instance -- every
/// getter reads straight through, every write method delegates straight
/// through -- via a plain `ChangeNotifier.addListener` subscription (not a
/// `ChangeNotifierProxyProvider`, whose `update` callback only runs on the
/// *next* frame; `addListener` fires synchronously in the same call stack,
/// which is what `app_router.dart`'s `appRedirect` depends on to read
/// current values immediately after an `await session.joinWithCode(...)`
/// completes). This preserves every one of `RelationshipProvider`'s
/// existing getters and methods unchanged, so none of the ~24 UI files
/// that read it directly need to change in this step -- only the
/// underlying engine moved. UI files are converted to call `CoupleSession`
/// directly in a later step (Phase 6b-2), as originally planned.
class CoupleSession extends ChangeNotifier {
  RelationshipStatus _status = RelationshipStatus.disconnected;
  String? _recoveryCode;
  bool _onboardingCompleted = false;

  RelationshipStatus get status => _status;
  String? get recoveryCode => _recoveryCode;
  String? get relationshipId => _coupleId;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Safety valve: allows LoadingScreen to unblock the user after a timeout.
  /// The auth listener will correct state once connectivity returns.
  void forceInitialized() {
    if (!_isInitialized) {
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Validates a cached avatar ref against storage.
  ///
  /// Returns the ref when it is usable, or `null` ONLY when the object is
  /// definitively gone. A transient failure (offline, 403 while unpaired) must
  /// never return null — the caller deletes the cached ref on null, and doing
  /// that on a network blip wipes the user's avatar for no reason.
  ///
  /// Replaces an earlier HTTP HEAD probe, which cannot work now that the
  /// buckets are private: every HEAD would 403 and every avatar would be
  /// deleted on the next launch.
  Future<String?> _validateAvatarRef(String ref) async {
    if (StorageUrlService.isLocalFileRef(ref)) return ref;

    // A foreign URL (e.g. a Google OAuth avatar) is not ours to validate.
    if (StorageUrlService.pathFrom(ref, bucket: StorageBuckets.avatars) == null) {
      return ref;
    }

    final url = await StorageUrlService.instance
        .resolve(bucket: StorageBuckets.avatars, ref: ref);
    if (url != null) return ref;

    final gone = StorageUrlService.instance.lastFailureWasNotFound(
      bucket: StorageBuckets.avatars,
      ref: ref,
    );
    return gone ? null : ref;
  }

  /// Clears a stale avatar ref from SharedPreferences and drops its cached
  /// image bytes.
  Future<void> _clearStaleAvatarCache(String prefsKey, String? ref) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsKey);
    if (ref == null || ref.trim().isEmpty) return;

    await StorageUrlService.instance
        .evict(bucket: StorageBuckets.avatars, ref: ref);

    final cacheKey = StorageUrlService.cacheKeyFor(
      bucket: StorageBuckets.avatars,
      ref: ref,
    );
    if (cacheKey.isEmpty) return;
    try {
      final evictFuture = CachedNetworkImage.evictFromCache(cacheKey);
      await evictFuture.catchError((_) => false);
    } catch (_) {}
  }

  DateTime? _startDate;
  TimeOfDay? _startTime;
  String? _partnerName;
  String? _yourName;
  String? _yourAvatarPath;
  String? _partnerAvatarPath;
  String? _coupleCode;
  bool _isPaired = false;
  bool _isPremium = false;
  bool _isGeneratingCode = false;
  bool _isJoining = false;
  bool _isUnlinking = false;
  bool _showPartnerDeletedNotice = false;
  String? _storyTitle;
  // The 24 license fields (12 your*/partner* pairs) live on LicenseController
  // (lib/features/relationship/license_controller.dart, Phase 5 of the
  // architecture migration).
  StreamSubscription? _userSub;
  StreamSubscription? _partnerUserSub;
  StreamSubscription? _coupleSub;
  StreamSubscription? _authSub;
  String? _coupleId;
  String? _userId;
  String? _partnerId;

  // Real-time presence & connection dates
  bool _isPartnerOnline = false;
  DateTime? _yourJoinDate;
  DateTime? _partnerJoinDate;
  RealtimeChannel? _presenceChannel;

  String? _yourActivity;
  String? _partnerActivity;

  DateTime? get startDate => _startDate;
  TimeOfDay? get startTime => _startTime;
  String? get partnerName => _partnerName;
  String? get yourName => _yourName;
  String? get yourAvatarPath => _yourAvatarPath;
  String? get partnerAvatarPath => _partnerAvatarPath;
  String? get coupleCode => _coupleCode;
  bool get isPaired => _isPaired;
  bool get isOnboardingComplete => _onboardingCompleted && _coupleId != null;
  /// The raw persisted flag, distinct from [isOnboardingComplete] which also
  /// requires a non-null [coupleId].
  bool get onboardingCompleted => _onboardingCompleted;
  bool get isPremium => _isPremium;
  String get storyTitle => _storyTitle ?? 'Our Story';
  String? get coupleId => _coupleId;
  String? get userId => _userId;
  String? get partnerId => _partnerId;
  bool _isCreator = false;
  bool get isCreator => _isCreator;

  bool get isPartnerOnline => _isPartnerOnline;
  DateTime? get yourJoinDate => _yourJoinDate;
  DateTime? get partnerJoinDate => _partnerJoinDate;
  String? get yourActivity => _yourActivity;
  String? get partnerActivity => _partnerActivity;

  bool get isSupabaseAvailable {
    try {
      Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

  final CoupleService _coupleService;

  /// [coupleService] defaults to the real [CoupleService.instance] --
  /// injectable only so a test can substitute a fake for pairing-flow
  /// coverage (ADR-010's exception: "singletons convert to providers only
  /// when a specific test needs a fake"), no behavior change for the app.
  CoupleSession({CoupleService? coupleService})
      : _coupleService = coupleService ?? CoupleService.instance {
    _loadLocalData().then((_) {
      if (isSupabaseAvailable) {
        _initSupabaseSync();
      }
    });
  }

  Future<void> _loadLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    final dateStr = prefs.getString(PrefsKeys.relationshipStartDate);
    if (dateStr != null) {
      _startDate = DateTime.parse(dateStr);
    }
    final hour = prefs.getInt(PrefsKeys.relationshipStartHour);
    final minute = prefs.getInt(PrefsKeys.relationshipStartMinute);
    if (hour != null && minute != null) {
      _startTime = TimeOfDay(hour: hour, minute: minute);
    }
    _yourName = prefs.getString(PrefsKeys.yourName);
    _partnerName = prefs.getString(PrefsKeys.partnerName);
    _yourAvatarPath = prefs.getString(PrefsKeys.yourAvatarPath);
    _partnerAvatarPath = prefs.getString(PrefsKeys.partnerAvatarPath);
    _coupleCode = prefs.getString(PrefsKeys.coupleCode);
    _coupleId = prefs.getString(PrefsKeys.coupleId);
    _isPaired = prefs.getBool(PrefsKeys.isPaired) ?? false;
    _isCreator = prefs.getBool(PrefsKeys.isCreator) ?? false;
    _onboardingCompleted = prefs.getBool(PrefsKeys.onboardingCompleted) ?? false;
    _isPremium = prefs.getBool(PrefsKeys.isPremium) ?? false;
    _storyTitle = prefs.getString(PrefsKeys.storyTitle);

    final yourJoinDateStr = prefs.getString(PrefsKeys.yourJoinDate);
    if (yourJoinDateStr != null) {
      _yourJoinDate = DateTime.parse(yourJoinDateStr);
    }
    final partnerJoinDateStr = prefs.getString(PrefsKeys.partnerJoinDate);
    if (partnerJoinDateStr != null) {
      _partnerJoinDate = DateTime.parse(partnerJoinDateStr);
    }

    if (_coupleId != null && _yourName != null && _yourName!.isNotEmpty && (_startDate != null || _isPaired)) {
      _onboardingCompleted = true;
    }

    if (!isSupabaseAvailable || (_coupleId != null && _onboardingCompleted)) {
      _isInitialized = true;
    }
    HomeWidgetService.instance.updateWidget(startDate: _startDate, startTime: _startTime);
    notifyListeners();

    // Background-validate cached avatar URLs on startup.
    // If a cached URL is stale (e.g. file deleted, 400/404), clear it
    // immediately so the UI shows a placeholder instead of retrying.
    _backgroundValidateAvatars();
  }

  /// Validates cached avatar refs in the background on startup, clearing only
  /// those whose object is definitively gone so the UI stops retrying them.
  ///
  /// Local file refs are skipped: they are un-synced uploads, and the widget
  /// layer already falls back to a placeholder when the file is missing.
  void _backgroundValidateAvatars() {
    final yourRef = _yourAvatarPath;
    if (yourRef != null && !StorageUrlService.isLocalFileRef(yourRef)) {
      _validateAvatarRef(yourRef).then((valid) {
        if (valid == null && _yourAvatarPath == yourRef) {
          debugPrint('Clearing stale your_avatar_path (object not found)');
          _clearStaleAvatarCache('your_avatar_path', yourRef);
          _yourAvatarPath = null;
          notifyListeners();
        }
      });
    }
    final partnerRef = _partnerAvatarPath;
    if (partnerRef != null && !StorageUrlService.isLocalFileRef(partnerRef)) {
      _validateAvatarRef(partnerRef).then((valid) {
        if (valid == null && _partnerAvatarPath == partnerRef) {
          debugPrint('Clearing stale partner_avatar_path (object not found)');
          _clearStaleAvatarCache('partner_avatar_path', partnerRef);
          _partnerAvatarPath = null;
          notifyListeners();
        }
      });
    }
  }

  void _cancelActiveSubscriptions() {
    _coupleSub?.cancel();
    _partnerUserSub?.cancel();
    _coupleSub = null;
    _partnerUserSub = null;
  }

  void _initSupabaseSync() {
    _authSub?.cancel();
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) async {
        final user = data.session?.user;

        try {
          await Supabase.instance.client.removeAllChannels();
        } catch (_) {}

        _cancelActiveSubscriptions();
        _userSub?.cancel();
        _userSub = null;

        if (user == null) {
          _userId = null;
          _coupleId = null;
          _partnerId = null;
          _isPaired = false;
          _status = RelationshipStatus.disconnected;
          _isPartnerOnline = false;
          _yourActivity = null;
          _partnerActivity = null;
          _yourJoinDate = null;
          _partnerJoinDate = null;
          _presenceChannel?.unsubscribe();
          _presenceChannel = null;
          _isInitialized = true;
          notifyListeners();
          return;
        }

        _userId = user.id;
        _isInitialized = false;
        notifyListeners();

        _userSub = Supabase.instance.client
            .from('users')
            .stream(primaryKey: ['id'])
            .eq('id', _userId!)
            .listen(
              (dataList) async {
                if (dataList.isEmpty) {
                  try {
                    // Self-heal a missing public.users row. Deliberately an
                    // insert-if-absent, NOT an upsert: the stream can yield an
                    // empty list transiently (reconnect, RLS hiccup) even when
                    // the row exists, and an upsert would then degrade to
                    // `UPDATE ... SET couple_id = NULL` and silently wipe a
                    // live pairing. couple_id is omitted entirely so this can
                    // never clear an existing link.
                    await Supabase.instance.client.from('users').upsert(
                      {
                        'id': _userId!,
                        'display_name': _yourName,
                      },
                      ignoreDuplicates: true,
                    );
                  } catch (_) {}
                  _isInitialized = true;
                  notifyListeners();
                  return;
                }

                final prefs = await SharedPreferences.getInstance();
                final userData = dataList.first;
                final newCoupleId = userData['couple_id'] as String?;

                final partnerDeletedNotice = userData['partner_deleted_notice'] as bool? ?? false;
                if (partnerDeletedNotice) {
                  _showPartnerDeletedNotice = true;
                  Supabase.instance.client
                      .from('users')
                      .update({'partner_deleted_notice': false})
                      .eq('id', _userId!)
                      .then((_) {});
                }

                bool coupleIdChanged = _coupleId != newCoupleId;
                _coupleId = newCoupleId;
                if (_coupleId != null) {
                  await prefs.setString(PrefsKeys.coupleId, _coupleId!);
                } else {
                  await prefs.remove(PrefsKeys.coupleId);
                }

                // Sync FCM Token to Supabase
                NotificationService().syncTokenToSupabase();

                _yourName = userData['display_name'] as String? ?? prefs.getString(PrefsKeys.yourName);
                _yourActivity = userData['current_activity'] as String?;
                if (_yourName != null) {
                  await prefs.setString(PrefsKeys.yourName, _yourName!);
                }
                final userAvatar = userData['avatar_url'] as String?;
                if (userAvatar != null && userAvatar.isNotEmpty) {
                  _yourAvatarPath = userAvatar;
                  await prefs.setString(PrefsKeys.yourAvatarPath, userAvatar);
                }

                final storedComp = prefs.getBool(PrefsKeys.onboardingCompleted);
                if (storedComp != null) {
                  _onboardingCompleted = storedComp;
                } else if (_coupleId != null && _yourName != null && _yourName!.isNotEmpty && (_startDate != null || _isPaired)) {
                  _onboardingCompleted = true;
                  await prefs.setBool(PrefsKeys.onboardingCompleted, true);
                }

                // Restore preserved onboarding details if unpaired
                if (_coupleId == null) {
                  _isPaired = false;
                  _status = RelationshipStatus.disconnected;
                  await prefs.setBool(PrefsKeys.isPaired, false);
                  final dateStr = prefs.getString(PrefsKeys.relationshipStartDate);
                  if (dateStr != null) {
                    _startDate = DateTime.parse(dateStr);
                  }
                  final hour = prefs.getInt(PrefsKeys.relationshipStartHour);
                  final minute = prefs.getInt(PrefsKeys.relationshipStartMinute);
                  if (hour != null && minute != null) {
                    _startTime = TimeOfDay(hour: hour, minute: minute);
                  }
                  _yourAvatarPath = prefs.getString(PrefsKeys.yourAvatarPath);
                }

                // Load and cache your join date
                final createdAtStr = userData['created_at'] as String?;
                if (createdAtStr != null) {
                  _yourJoinDate = DateTime.parse(createdAtStr);
                } else {
                  final authCreated = Supabase.instance.client.auth.currentUser?.createdAt;
                  if (authCreated != null) {
                    _yourJoinDate = DateTime.parse(authCreated);
                  }
                }

                if (_yourJoinDate != null) {
                  await prefs.setString(PrefsKeys.yourJoinDate, _yourJoinDate!.toIso8601String());
                }

                if (_coupleId != null) {
                  if (coupleIdChanged) {
                    _cancelActiveSubscriptions();
                    _partnerActivity = null;
                    _syncLocalDetailsToCloud();

                    _coupleSub = Supabase.instance.client
                        .from('couples')
                        .stream(primaryKey: ['id'])
                        .eq('id', _coupleId!)
                        .listen(
                          (coupleDataList) async {
                            if (coupleDataList.isEmpty) return;
                            final coupleData = coupleDataList.first;

                            _storyTitle = coupleData['story_title'] as String?;
                            final startStr = coupleData['start_date'] as String?;
                            if (startStr != null) {
                              _startDate = DateTime.parse(startStr);
                            }
                            final hour = coupleData['start_time_hour'] as int?;
                            final minute = coupleData['start_time_minute'] as int?;
                            if (hour != null && minute != null) {
                              _startTime = TimeOfDay(hour: hour, minute: minute);
                            }
                            _isPremium = coupleData['is_premium'] as bool? ?? false;

                            final dbCode = coupleData['pairing_code'] as String?;
                            if (dbCode != null && dbCode.isNotEmpty) {
                              _coupleCode = dbCode;
                            }

                            final partnerAId = coupleData['partner_a_id'] as String?;
                            final partnerBId = coupleData['partner_b_id'] as String?;

                            final oldPartnerId = _partnerId;
                            _partnerId = (partnerAId == _userId) ? partnerBId : partnerAId;
                            _isPaired = _coupleId != null && _partnerId != null;

                            final statusStr = coupleData['status'] as String? ?? 'waiting';
                            _status = RelationshipStatus.values.firstWhere(
                              (e) => e.name == statusStr,
                              orElse: () => RelationshipStatus.waiting,
                            );

                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool(PrefsKeys.isPaired, _isPaired);
                            if (_storyTitle != null) {
                              await prefs.setString(PrefsKeys.storyTitle, _storyTitle!);
                            }
                            if (_startDate != null) {
                              await prefs.setString(PrefsKeys.relationshipStartDate, _startDate!.toIso8601String());
                            }
                            if (_startTime != null) {
                              await prefs.setInt(PrefsKeys.relationshipStartHour, _startTime!.hour);
                              await prefs.setInt(PrefsKeys.relationshipStartMinute, _startTime!.minute);
                            }
                            await prefs.setBool(PrefsKeys.isPremium, _isPremium);

                            if (_startDate != null || _isPaired || statusStr == 'active') {
                              _onboardingCompleted = true;
                              await prefs.setBool(PrefsKeys.onboardingCompleted, true);
                            }

                            if (oldPartnerId != _partnerId) {
                              _initPartnerUserSync();
                            }

                            _initPresence();
                            _isInitialized = true;
                            notifyListeners();
                          },
                          onError: (error) {
                            debugPrint('Supabase couples stream error: $error');
                            _isInitialized = true;
                            notifyListeners();
                          },
                        );
                  } else {
                    _isInitialized = true;
                    notifyListeners();
                  }
                } else {
                  _cancelActiveSubscriptions();
                  _partnerActivity = null;
                  _isInitialized = true;
                  notifyListeners();
                }
              },
              onError: (error) {
                debugPrint('Supabase users stream error: $error');
                _isInitialized = true;
                notifyListeners();
              },
            );
      },
      onError: (error) {
        debugPrint('Supabase AuthStateChange error: $error');
      },
    );
  }

  void _initPartnerUserSync() {
    _partnerUserSub?.cancel();
    _partnerUserSub = null;

    if (_partnerId == null) {
      _partnerJoinDate = null;
      _partnerActivity = null;
      notifyListeners();
      return;
    }

    _partnerUserSub = Supabase.instance.client
        .from('users')
        .stream(primaryKey: ['id'])
        .eq('id', _partnerId!)
        .listen((pDataList) async {
          if (pDataList.isNotEmpty) {
            final pData = pDataList.first;
            _partnerActivity = pData['current_activity'] as String?;

            final partnerDisplayName = pData['display_name'] as String?;
            if (partnerDisplayName != null && partnerDisplayName.isNotEmpty) {
              _partnerName = partnerDisplayName;
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString(PrefsKeys.partnerName, partnerDisplayName);
            }

            final partnerAvatar = pData['avatar_url'] as String?;
            if (partnerAvatar != null && partnerAvatar.isNotEmpty) {
              _partnerAvatarPath = partnerAvatar;
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString(PrefsKeys.partnerAvatarPath, partnerAvatar);
            }

            notifyListeners();
          }
        });

    Supabase.instance.client
        .from('users')
        .select()
        .eq('id', _partnerId!)
        .maybeSingle()
        .then((pData) async {
          if (pData != null) {
            final prefs = await SharedPreferences.getInstance();

            final pCreated = pData['created_at'] as String?;
            if (pCreated != null) {
              _partnerJoinDate = DateTime.parse(pCreated);
              await prefs.setString(PrefsKeys.partnerJoinDate, pCreated);
            }

            final partnerDisplayName = pData['display_name'] as String?;
            if (partnerDisplayName != null && partnerDisplayName.isNotEmpty) {
              _partnerName = partnerDisplayName;
              await prefs.setString(PrefsKeys.partnerName, partnerDisplayName);
            }

            final partnerAvatar = pData['avatar_url'] as String?;
            if (partnerAvatar != null && partnerAvatar.isNotEmpty) {
              _partnerAvatarPath = partnerAvatar;
              await prefs.setString(PrefsKeys.partnerAvatarPath, partnerAvatar);
            }

            notifyListeners();
          }
        })
        .catchError((error) {
          debugPrint('Error loading partner profile details: $error');
        });
  }

  void _initPresence() {
    if (_presenceChannel != null) {
      try {
        _presenceChannel!.unsubscribe();
        Supabase.instance.client.removeChannel(_presenceChannel!);
      } catch (_) {}
      _presenceChannel = null;
    }

    if (_userId == null || _coupleId == null) {
      _isPartnerOnline = false;
      notifyListeners();
      return;
    }

    final channelName = 'couple_presence_$_coupleId';
    _presenceChannel = Supabase.instance.client.channel(channelName);

    _presenceChannel!
        .onPresenceSync((_) {
          final state = _presenceChannel!.presenceState();
          bool partnerFound = false;
          for (final presenceState in state) {
            for (final presence in presenceState.presences) {
              final payload = presence.payload;
              if (payload['user_id'] == _partnerId) {
                partnerFound = true;
                break;
              }
            }
            if (partnerFound) break;
          }
          if (_isPartnerOnline != partnerFound) {
            _isPartnerOnline = partnerFound;
            notifyListeners();
          }
        })
        .subscribe((status, [error]) async {
          if (status == RealtimeSubscribeStatus.subscribed) {
            try {
              await _presenceChannel!.track({
                'user_id': _userId,
                'online_at': DateTime.now().toIso8601String(),
              });
            } catch (_) {}
          }
        });
  }

  Future<void> updateCurrentActivity(String? activity) async {
    _yourActivity = activity;
    notifyListeners();
    if (_userId != null) {
      try {
        await Supabase.instance.client
            .from('users')
            .update({'current_activity': activity})
            .eq('id', _userId!);
      } catch (e) {
        debugPrint('Error updating current activity: $e');
      }
    }
  }

  Future<void> setYourName(String name) async {
    _yourName = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PrefsKeys.yourName, name);

    if (isSupabaseAvailable && _userId != null) {
      try {
        await ProfileService.instance.updateUserDetails(_userId!, {'display_name': name});
      } catch (e) {
        debugPrint('Supabase setYourName display_name update failed: $e');
      }
    }
    notifyListeners();
  }

  Future<void> _syncLocalDetailsToCloud() async {
    if (!isSupabaseAvailable || _coupleId == null) return;

    // 1. Sync self profile details to public.users
    if (_userId != null) {
      try {
        final userUpdates = <String, dynamic>{};
        if (_yourName != null) userUpdates['display_name'] = _yourName;
        if (_yourAvatarPath != null) userUpdates['avatar_url'] = _yourAvatarPath;
        // The 12 license fields (gender..signature) used to get a second
        // sync attempt here on newly pairing, in case their write-time push
        // (now LicenseController.updateFields, still try/catch-silent on
        // failure exactly like the code this replaced) had failed earlier.
        // Neither RelationshipProvider nor CoupleSession holds those fields
        // to re-push -- narrower resync coverage than before for this one
        // edge case (offline-set license fields whose original push failed,
        // never edited again), acknowledged and left as a known gap rather
        // than building new Riverpod-from-non-widget plumbing to close it
        // (see migration-roadmap.md's Phase 5 corrections).

        if (userUpdates.isNotEmpty) {
          await ProfileService.instance.updateUserDetails(_userId!, userUpdates);
        }
      } catch (e) {
        debugPrint('_syncLocalDetailsToCloud users update failed: $e');
      }
    }

    // 2. Sync couples table details
    try {
      final coupleUpdates = <String, dynamic>{};
      if (_storyTitle != null) coupleUpdates['story_title'] = _storyTitle;
      if (_startDate != null) {
        coupleUpdates['start_date'] = _startDate!.toIso8601String();
      }
      if (_startTime != null) {
        coupleUpdates['start_time_hour'] = _startTime!.hour;
        coupleUpdates['start_time_minute'] = _startTime!.minute;
      }
      if (coupleUpdates.isNotEmpty) {
        await Supabase.instance.client
            .from('couples')
            .update(coupleUpdates)
            .eq('id', _coupleId!);
      }
    } catch (_) {}

    // 3. Upload the avatar if it is still only a local file.
    // Must test for a real device path, NOT `!startsWith('http')`: avatar refs
    // are now bare storage paths, so the old check would treat an
    // already-uploaded avatar as pending and try to re-upload a file that no
    // longer exists, throwing on every sync.
    if (StorageUrlService.isLocalFileRef(_yourAvatarPath)) {
      final path = _yourAvatarPath!;
      await setAvatars(yourPath: path);
    }
  }

  Future<void> setStoryTitle(String title) async {
    _storyTitle = title;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PrefsKeys.storyTitle, title);
    if (_coupleId != null) {
      Supabase.instance.client
          .from('couples')
          .update({'story_title': title})
          .eq('id', _coupleId!)
          .then((_) {});
    }
    notifyListeners();
  }

  Future<void> setStartDate(DateTime date) async {
    _startDate = date;
    await HomeWidgetService.instance.updateWidget(startDate: _startDate, startTime: _startTime);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PrefsKeys.relationshipStartDate, date.toIso8601String());
    if (_coupleId != null) {
      Supabase.instance.client
          .from('couples')
          .update({'start_date': date.toIso8601String()})
          .eq('id', _coupleId!)
          .then((_) {});
    }
    notifyListeners();

    await RecentActivityService.instance.logActivity(
      activityType: 'updated',
      title: 'Anniversary changed 💕',
      description: 'Anniversary changed to ${date.toString().substring(0, 10)}',
      icon: '💕',
      referenceId: 'anniversary_date',
      route: 'relationship_profile',
    );
  }

  Future<void> setStartTime(TimeOfDay time) async {
    _startTime = time;
    await HomeWidgetService.instance.updateWidget(startDate: _startDate, startTime: _startTime);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(PrefsKeys.relationshipStartHour, time.hour);
    await prefs.setInt(PrefsKeys.relationshipStartMinute, time.minute);
    if (_coupleId != null) {
      Supabase.instance.client
          .from('couples')
          .update({
            'start_time_hour': time.hour,
            'start_time_minute': time.minute,
          })
          .eq('id', _coupleId!)
          .then((_) {});
    }
    notifyListeners();
  }

  Future<void> setNames(String yours, String partner) async {
    _yourName = yours;
    _partnerName = partner;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PrefsKeys.yourName, yours);
    await prefs.setString(PrefsKeys.partnerName, partner);

    if (isSupabaseAvailable) {
      if (_userId != null) {
        try {
          await ProfileService.instance.updateUserDetails(_userId!, {'display_name': yours});
        } catch (e) {
          debugPrint('Supabase setNames self update failed: $e');
        }
      }
      if (_partnerId != null) {
        try {
          await ProfileService.instance.updatePartnerProfile(_partnerId!, {'display_name': partner});
        } catch (e) {
          debugPrint('Supabase setNames partner update failed: $e');
        }
      }
    }
    notifyListeners();
  }

  Future<void> setAvatars({String? yourPath, String? partnerPath}) async {
    final prefs = await SharedPreferences.getInstance();

    if (isSupabaseAvailable && _coupleId != null) {
      if (yourPath != null) {
        // Only a real device path means "upload this". A bare storage path is
        // an avatar that is already uploaded.
        if (StorageUrlService.isLocalFileRef(yourPath)) {
          final file = File(yourPath);
          if (!await file.exists()) {
            throw Exception('Selected avatar image file does not exist.');
          }

          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final storagePath =
              'couples/$_coupleId/avatars/${_userId ?? 'user'}_$timestamp.jpg';

          // Returns the storage path, not a URL.
          final yourRef = await ProfileService.instance.uploadAvatar(
            bucketName: StorageBuckets.avatars,
            filePath: yourPath,
            storagePath: storagePath,
          );

          // Reclaim the disk cache held by the superseded object. No cache
          // busting is needed on the new ref: the path embeds a timestamp, so
          // it is already a distinct cache key.
          await _clearStaleAvatarCache('your_avatar_path', _yourAvatarPath);

          _yourAvatarPath = yourRef;
          await prefs.setString(PrefsKeys.yourAvatarPath, yourRef);
        } else {
          _yourAvatarPath = yourPath;
          if (yourPath.isEmpty) {
            await prefs.remove(PrefsKeys.yourAvatarPath);
          } else {
            await prefs.setString(PrefsKeys.yourAvatarPath, yourPath);
          }
        }
      }

      if (partnerPath != null) {
        if (StorageUrlService.isLocalFileRef(partnerPath)) {
          final file = File(partnerPath);
          if (!await file.exists()) {
            throw Exception('Selected partner avatar image file does not exist.');
          }

          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final storagePath =
              'couples/$_coupleId/avatars/${_partnerId ?? 'partner'}_$timestamp.jpg';

          final partnerRef = await ProfileService.instance.uploadAvatar(
            bucketName: StorageBuckets.avatars,
            filePath: partnerPath,
            storagePath: storagePath,
          );

          await _clearStaleAvatarCache('partner_avatar_path', _partnerAvatarPath);

          _partnerAvatarPath = partnerRef;
          await prefs.setString(PrefsKeys.partnerAvatarPath, partnerRef);
        } else {
          _partnerAvatarPath = partnerPath;
          if (partnerPath.isEmpty) {
            await prefs.remove(PrefsKeys.partnerAvatarPath);
          } else {
            await prefs.setString(PrefsKeys.partnerAvatarPath, partnerPath);
          }
        }
      }

      if (yourPath != null && _yourAvatarPath != null && _userId != null) {
        await ProfileService.instance.updateUserDetails(_userId!, {'avatar_url': _yourAvatarPath});
      }
      if (partnerPath != null && _partnerAvatarPath != null && _partnerId != null) {
        await ProfileService.instance.updatePartnerProfile(_partnerId!, {'avatar_url': _partnerAvatarPath});
      }

      try {
        NotificationService().sendPartnerNotification(
          title: 'Profile Photo Updated 📸',
          body: 'Your partner updated their profile photo.',
          feature: 'relationship',
        );
      } catch (_) {}
    } else {
      if (yourPath != null) {
        _yourAvatarPath = yourPath;
        if (yourPath.isEmpty) {
          await prefs.remove(PrefsKeys.yourAvatarPath);
        } else {
          await prefs.setString(PrefsKeys.yourAvatarPath, yourPath);
        }
      }
      if (partnerPath != null) {
        _partnerAvatarPath = partnerPath;
        if (partnerPath.isEmpty) {
          await prefs.remove(PrefsKeys.partnerAvatarPath);
        } else {
          await prefs.setString(PrefsKeys.partnerAvatarPath, partnerPath);
        }
      }
    }
    notifyListeners();

    await RecentActivityService.instance.logActivity(
      activityType: 'updated',
      title: 'Profile photo updated 💕',
      description: 'Updated profile avatar photo',
      icon: '📸',
      referenceId: 'relationship_profile_avatar',
      route: 'relationship_profile',
    );
  }

  Future<void> createRelationshipWorkspace() async {
    if (_isGeneratingCode) return;
    _isGeneratingCode = true;
    notifyListeners();
    try {
      final result = await _coupleService.createRelationshipWorkspace();
      _coupleId = result['couple_id'] as String;
      _coupleCode = result['pairing_code'] as String;
      _recoveryCode = result['recovery_code'] as String;
      _status = RelationshipStatus.waiting;
      _isPaired = false;
      _isCreator = true;
      _onboardingCompleted = false;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(PrefsKeys.coupleCode, _coupleCode!);
      await prefs.setString(PrefsKeys.coupleId, _coupleId!);
      await prefs.setBool(PrefsKeys.isPaired, false);
      await prefs.setBool(PrefsKeys.isCreator, true);
      await prefs.setBool(PrefsKeys.onboardingCompleted, false);
      notifyListeners();
    } catch (e) {
      debugPrint('Error in createRelationshipWorkspace: $e');
      rethrow;
    } finally {
      _isGeneratingCode = false;
      notifyListeners();
    }
  }

  String generateCoupleCode({bool forceRegenerate = false}) {
    if (_coupleCode != null) {
      return _coupleCode!;
    }
    createRelationshipWorkspace();
    return '';
  }

  /// Refreshes or rotates the 20-minute pairing code for the relationship workspace.
  Future<String?> refreshPairingCode({bool forceRotate = false}) async {
    if (!isSupabaseAvailable || _coupleId == null) return _coupleCode;
    try {
      final result = await _coupleService.getOrRotatePairingCode(forceRotate: forceRotate);
      if (result['success'] == true) {
        final newCode = result['pairing_code'] as String?;
        if (newCode != null && newCode.isNotEmpty) {
          _coupleCode = newCode;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(PrefsKeys.coupleCode, newCode);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error in refreshPairingCode: $e');
    }
    return _coupleCode;
  }

  Future<bool> joinWithCode(String code) async {
    if (_isJoining) return false;
    _isJoining = true;
    notifyListeners();

    try {
      final cleanCode = code.trim().toUpperCase();
      if (cleanCode.length != 6) return false;

      _coupleCode = cleanCode;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(PrefsKeys.coupleCode, cleanCode);

      if (isSupabaseAvailable && _userId != null) {
        final result = await _coupleService.joinWithCode(cleanCode);
        final bool success = result['success'] as bool? ?? false;

        if (!success) {
          final errorMsg = result['error'] as String? ?? 'Pairing failed';
          debugPrint('Supabase join_relationship_with_code error: $errorMsg');
          throw Exception(errorMsg);
        }

        final joinedCoupleId = result['couple_id'] as String;
        final creatorId = result['partner_id'] as String;

        _coupleId = joinedCoupleId;
        _partnerId = creatorId;
        _isPaired = true;
        _status = RelationshipStatus.active;
        _onboardingCompleted = false;

        await prefs.setString(PrefsKeys.coupleId, _coupleId!);
        await prefs.setString(PrefsKeys.partnerId, _partnerId!);
        await prefs.setBool(PrefsKeys.isPaired, true);
        await prefs.setBool(PrefsKeys.onboardingCompleted, false);

        await RelationshipLifecycleManager.instance.handlePair(_coupleId!, _userId!);

        try {
          await NotificationService().sendPartnerNotification(
            title: 'Connected! 💞',
            body: 'You and your partner are now paired!',
            feature: 'relationship',
          );
        } catch (_) {}

        final coupleData = await Supabase.instance.client
            .from('couples')
            .select()
            .eq('id', _coupleId!)
            .maybeSingle();

        if (coupleData != null) {
          final startStr = coupleData['start_date'] as String?;
          if (startStr != null) {
            _startDate = DateTime.parse(startStr);
            await prefs.setString(PrefsKeys.relationshipStartDate, startStr);
          }
          final hour = coupleData['start_time_hour'] as int?;
          final minute = coupleData['start_time_minute'] as int?;
          if (hour != null && minute != null) {
            _startTime = TimeOfDay(hour: hour, minute: minute);
            await prefs.setInt(PrefsKeys.relationshipStartHour, hour);
            await prefs.setInt(PrefsKeys.relationshipStartMinute, minute);
          }
          _storyTitle = coupleData['story_title'] as String? ?? 'Our Story';
          await prefs.setString(PrefsKeys.storyTitle, _storyTitle!);
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error in joinWithCode: $e');
      rethrow;
    } finally {
      _isJoining = false;
      notifyListeners();
    }
  }

  Future<void> completeOnboarding() async {
    _onboardingCompleted = true;
    _isPaired = _coupleId != null && _partnerId != null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(PrefsKeys.isPaired, _isPaired);
    await prefs.setBool(PrefsKeys.onboardingCompleted, true);

    if (isSupabaseAvailable && _userId != null) {
      final updates = <String, dynamic>{};
      if (_yourName != null) updates['display_name'] = _yourName;
      if (_yourAvatarPath != null) updates['avatar_url'] = _yourAvatarPath;
      if (updates.isNotEmpty) {
        try {
          await Supabase.instance.client
              .from('users')
              .update(updates)
              .eq('id', _userId!);
        } catch (_) {}
      }
    }

    notifyListeners();
  }

  Future<void> setPremium(bool value) async {
    _isPremium = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(PrefsKeys.isPremium, _isPremium);
    if (_coupleId != null) {
      Supabase.instance.client
          .from('couples')
          .update({'is_premium': _isPremium})
          .eq('id', _coupleId!)
          .then((_) {});
    }
    notifyListeners();
  }

  Future<bool> recoverRelationship(String code) async {
    if (_isJoining) return false;
    _isJoining = true;
    notifyListeners();
    try {
      final result = await _coupleService.recoverWithCode(code);
      final bool success = result['success'] as bool? ?? false;
      if (success) {
        _coupleId = result['couple_id'] as String;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(PrefsKeys.coupleId, _coupleId!);

        // Triggers active sync streams
        _initSupabaseSync();
        await RelationshipLifecycleManager.instance.handleRepair(_coupleId!, _userId!);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error in recoverRelationship: $e');
      rethrow;
    } finally {
      _isJoining = false;
      notifyListeners();
    }
  }

  Future<void> regenerateRecoveryCode() async {
    try {
      final result = await _coupleService.regenerateRecoveryCode();
      _recoveryCode = result['recovery_code'] as String;
      notifyListeners();
    } catch (e) {
      debugPrint('Error in regenerateRecoveryCode: $e');
      rethrow;
    }
  }

  void clearRecoveryCode() {
    _recoveryCode = null;
    notifyListeners();
  }

  Future<void> unlinkPartner() async {
    if (_isUnlinking) return;
    _isUnlinking = true;
    notifyListeners();

    try {
      _isPaired = false;
      _coupleCode = null;
      _partnerName = null;
      _partnerAvatarPath = null;
      _partnerJoinDate = null;
      _isPartnerOnline = false;
      _cancelActiveSubscriptions();
      await RelationshipLifecycleManager.instance.handleDisconnect();
      _presenceChannel?.unsubscribe();
      _presenceChannel = null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(PrefsKeys.isPaired, false);
      await prefs.remove(PrefsKeys.coupleCode);
      await prefs.remove(PrefsKeys.partnerName);
      await prefs.remove(PrefsKeys.partnerAvatarPath);
      await prefs.remove(PrefsKeys.partnerJoinDate);
      _onboardingCompleted = false;
      await prefs.setBool(PrefsKeys.onboardingCompleted, false);

      if (isSupabaseAvailable && _userId != null) {
        try {
          await NotificationService().sendPartnerNotification(
            title: 'Relationship Unlinked 💔',
            body: 'Your partner has unlinked from the relationship.',
            feature: 'relationship',
          );
        } catch (_) {}
        await _coupleService.disconnectRelationshipWorkspace();
      }
      _coupleId = null;
      _partnerId = null;
      _status = RelationshipStatus.disconnected;
    } catch (e) {
      debugPrint('Error in unlinkPartner: $e');
    } finally {
      _isUnlinking = false;
      notifyListeners();
    }
  }

  bool get showPartnerDeletedNotice => _showPartnerDeletedNotice;

  void clearPartnerDeletedNotice() {
    _showPartnerDeletedNotice = false;
    notifyListeners();
    if (isSupabaseAvailable && _userId != null) {
      Supabase.instance.client
          .from('users')
          .update({'partner_deleted_notice': false})
          .eq('id', _userId!)
          .then((_) {});
    }
  }

  Future<void> deleteAccount() async {
    if (isSupabaseAvailable && _userId != null) {
      try {
        await AuthService.instance.deleteUserAccount();
      } catch (e) {
        debugPrint('Error calling delete_current_user RPC: $e');
        try {
          await Supabase.instance.client.from('users').delete().eq('id', _userId!);
        } catch (_) {}
      }
    }
    await logout(wipeAll: true);
  }

  Future<void> signUpWithEmail(String email, String password) async {
    await AuthService.instance.signUpWithEmail(email, password);
  }

  Future<void> signInWithEmail(String email, String password) async {
    await AuthService.instance.signInWithEmail(email, password);
  }

  Future<void> signInWithGoogle() async {
    final webClientId = AppConfig.googleClientIdWeb;
    final iosClientId = AppConfig.googleClientIdIos;

    final googleSignIn = GoogleSignIn(
      serverClientId: webClientId == 'YOUR_WEB_CLIENT_ID' || webClientId.isEmpty
          ? null
          : webClientId,
      clientId: iosClientId == 'YOUR_IOS_CLIENT_ID' || iosClientId.isEmpty
          ? null
          : iosClientId,
    );
    try {
      await googleSignIn.signOut();
    } catch (_) {}
    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      throw 'Sign in aborted by user';
    }
    final googleAuth = await googleUser.authentication;
    final accessToken = googleAuth.accessToken;
    final idToken = googleAuth.idToken;

    if (idToken == null) {
      throw 'No ID Token found. Make sure serverClientId (Web Client ID) is configured correctly.';
    }

    await AuthService.instance.signInWithIdToken(
      idToken: idToken,
      accessToken: accessToken ?? '',
    );
  }

  Future<void> logout({bool wipeAll = false}) async {
    _userId = null;
    _coupleId = null;
    _partnerId = null;
    _startDate = null;
    _startTime = null;
    _partnerName = null;
    _yourName = null;
    _yourAvatarPath = null;
    _partnerAvatarPath = null;
    _coupleCode = null;
    _isPaired = false;
    _isCreator = false;
    _onboardingCompleted = false;
    _isPremium = false;
    _storyTitle = null;
    // The 24 license fields used to be reset here -- LicenseController's
    // own state is invalidated on logout by main.dart's
    // _LicenseLifecycleBridge instead (see license_controller.dart).

    await HomeWidgetService.instance.clearWidget();

    final prefs = await SharedPreferences.getInstance();
    if (wipeAll) {
      await prefs.clear();
    } else {
      final onboardingCompleted = prefs.getBool(PrefsKeys.onboardingCompleted);
      final startDate = prefs.getString(PrefsKeys.relationshipStartDate);
      final startHour = prefs.getInt(PrefsKeys.relationshipStartHour);
      final startMinute = prefs.getInt(PrefsKeys.relationshipStartMinute);
      final yourAvatarPath = prefs.getString(PrefsKeys.yourAvatarPath);
      final yourName = prefs.getString(PrefsKeys.yourName);

      await prefs.clear();

      if (onboardingCompleted != null) await prefs.setBool(PrefsKeys.onboardingCompleted, onboardingCompleted);
      if (startDate != null) await prefs.setString(PrefsKeys.relationshipStartDate, startDate);
      if (startHour != null) await prefs.setInt(PrefsKeys.relationshipStartHour, startHour);
      if (startMinute != null) await prefs.setInt(PrefsKeys.relationshipStartMinute, startMinute);
      if (yourAvatarPath != null) await prefs.setString(PrefsKeys.yourAvatarPath, yourAvatarPath);
      if (yourName != null) await prefs.setString(PrefsKeys.yourName, yourName);
    }

    await RelationshipLifecycleManager.instance.handleLogout();

    _userSub?.cancel();
    _partnerUserSub?.cancel();
    _partnerUserSub = null;
    _partnerActivity = null;
    _coupleSub?.cancel();
    _presenceChannel?.unsubscribe();
    _presenceChannel = null;
    _isPartnerOnline = false;
    _yourJoinDate = null;
    _partnerJoinDate = null;

    if (isSupabaseAvailable) {
      await AuthService.instance.signOut();
      try {
        final googleSignIn = GoogleSignIn();
        await googleSignIn.signOut();
      } catch (_) {}
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _userSub?.cancel();
    _partnerUserSub?.cancel();
    _coupleSub?.cancel();
    if (_presenceChannel != null) {
      try {
        _presenceChannel!.unsubscribe();
        Supabase.instance.client.removeChannel(_presenceChannel!);
      } catch (_) {}
    }
    super.dispose();
  }
}

/// The Riverpod-side handle onto the single live [CoupleSession] instance
/// the Provider tree owns -- the strangler bridge's "Provider -> Riverpod"
/// direction (Phase 2 of the architecture migration, ADR-002).
///
/// This provider's own body is never actually read: `main.dart` overrides it
/// with the live instance via `overrideWithValue` inside a nested
/// `ProviderScope`, wrapped around a `Consumer<CoupleSession>` that reads the
/// same object the Provider tree already holds -- one instance, two
/// containers, so Riverpod-side code (starting with Phase 5's extracted
/// controllers) and untouched Provider-side screens can never observe
/// diverging state. See docs/architecture/state-management.md, "The
/// strangler bridge."
final coupleSessionProvider = Provider<CoupleSession>((ref) {
  throw UnimplementedError(
    'coupleSessionProvider must be overridden with the live CoupleSession '
    'instance -- see main.dart\'s nested ProviderScope.',
  );
});
