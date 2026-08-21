import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:days_together/app_config.dart';
import 'package:days_together/services/notification_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:days_together/services/date_helper.dart';
import 'package:days_together/services/auth_service.dart';
import 'package:days_together/services/couple_service.dart';
import 'package:days_together/services/profile_service.dart';
import 'package:days_together/services/recent_activity_service.dart';
import 'package:days_together/services/relationship_lifecycle_manager.dart';
import 'package:days_together/services/home_widget_service.dart';
import 'package:days_together/services/storage_url_service.dart';

enum RelationshipStatus {
  waiting,
  active,
  disconnected,
  archived
}

class MilestoneInfo {
  final String title;
  final int daysUntil;
  final double progress; // 0.0 to 1.0

  const MilestoneInfo({
    required this.title,
    required this.daysUntil,
    required this.progress,
  });
}

class RelationshipProvider with ChangeNotifier {
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
  // The 24 license fields (12 your*/partner* pairs) that used to live here
  // -- gender through signature -- moved to LicenseController
  // (lib/features/relationship/license_controller.dart, Phase 5 of the
  // architecture migration). See migration-roadmap.md's Phase 5 corrections
  // for why the roadmap's original "28 fields" figure included 4 fields
  // (yourName/partnerName/yourAvatarPath/partnerAvatarPath) that are
  // ProfileController's, not this extraction's.
  // Firebase Streams Subscriptions
  StreamSubscription? _userSub;
  StreamSubscription? _partnerUserSub;
  StreamSubscription? _coupleSub;
  StreamSubscription? _licenseSub;
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
  /// requires a non-null [coupleId]. Exposed for `CoupleSession` (Phase 1 of
  /// the architecture migration) to mirror the exact field it owns per
  /// `PrefsKeys`' "Session / pairing identity" group.
  bool get onboardingCompleted => _onboardingCompleted;
  bool get isPremium => _isPremium;
  String get storyTitle => _storyTitle ?? 'Our Story';
  // The 24 license-field getters that used to live here moved to
  // LicenseController alongside the fields (see above).
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

  RelationshipProvider() {
    RelationshipLifecycleManager.instance.setRelationshipProvider(this);
    _loadLocalData().then((_) {
      if (isSupabaseAvailable) {
        _initSupabaseSync();
      }
    });
  }

  Future<void> _loadLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    final dateStr = prefs.getString('relationship_start_date');
    if (dateStr != null) {
      _startDate = DateTime.parse(dateStr);
    }
    final hour = prefs.getInt('relationship_start_hour');
    final minute = prefs.getInt('relationship_start_minute');
    if (hour != null && minute != null) {
      _startTime = TimeOfDay(hour: hour, minute: minute);
    }
    _yourName = prefs.getString('your_name');
    _partnerName = prefs.getString('partner_name');
    _yourAvatarPath = prefs.getString('your_avatar_path');
    _partnerAvatarPath = prefs.getString('partner_avatar_path');
    _coupleCode = prefs.getString('couple_code');
    _coupleId = prefs.getString('couple_id');
    _isPaired = prefs.getBool('is_paired') ?? false;
    _isCreator = prefs.getBool('is_creator') ?? false;
    _onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;
    _isPremium = prefs.getBool('is_premium') ?? false;
    _storyTitle = prefs.getString('story_title');
    // The 24 license fields used to be loaded here -- LicenseController now
    // hydrates them independently (lib/features/relationship/license_controller.dart).

    final yourJoinDateStr = prefs.getString('your_join_date');
    if (yourJoinDateStr != null) {
      _yourJoinDate = DateTime.parse(yourJoinDateStr);
    }
    final partnerJoinDateStr = prefs.getString('partner_join_date');
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
    _licenseSub?.cancel();
    _partnerUserSub?.cancel();
    _coupleSub = null;
    _licenseSub = null;
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
                  await prefs.setString('couple_id', _coupleId!);
                } else {
                  await prefs.remove('couple_id');
                }

                // Sync FCM Token to Supabase
                NotificationService().syncTokenToSupabase();

                _yourName = userData['display_name'] as String? ?? prefs.getString('your_name');
                _yourActivity = userData['current_activity'] as String?;
                if (_yourName != null) {
                  await prefs.setString('your_name', _yourName!);
                }
                final userAvatar = userData['avatar_url'] as String?;
                if (userAvatar != null && userAvatar.isNotEmpty) {
                  _yourAvatarPath = userAvatar;
                  await prefs.setString('your_avatar_path', userAvatar);
                }

                final storedComp = prefs.getBool('onboarding_completed');
                if (storedComp != null) {
                  _onboardingCompleted = storedComp;
                } else if (_coupleId != null && _yourName != null && _yourName!.isNotEmpty && (_startDate != null || _isPaired)) {
                  _onboardingCompleted = true;
                  await prefs.setBool('onboarding_completed', true);
                }

                // Restore preserved onboarding details if unpaired
                if (_coupleId == null) {
                  _isPaired = false;
                  _status = RelationshipStatus.disconnected;
                  await prefs.setBool('is_paired', false);
                  final dateStr = prefs.getString('relationship_start_date');
                  if (dateStr != null) {
                    _startDate = DateTime.parse(dateStr);
                  }
                  final hour = prefs.getInt('relationship_start_hour');
                  final minute = prefs.getInt('relationship_start_minute');
                  if (hour != null && minute != null) {
                    _startTime = TimeOfDay(hour: hour, minute: minute);
                  }
                  _yourAvatarPath = prefs.getString('your_avatar_path');
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
                  await prefs.setString('your_join_date', _yourJoinDate!.toIso8601String());
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
                            await prefs.setBool('is_paired', _isPaired);
                            if (_storyTitle != null) {
                              await prefs.setString('story_title', _storyTitle!);
                            }
                            if (_startDate != null) {
                              await prefs.setString('relationship_start_date', _startDate!.toIso8601String());
                            }
                            if (_startTime != null) {
                              await prefs.setInt('relationship_start_hour', _startTime!.hour);
                              await prefs.setInt('relationship_start_minute', _startTime!.minute);
                            }
                            await prefs.setBool('is_premium', _isPremium);

                            if (_startDate != null || _isPaired || statusStr == 'active') {
                              _onboardingCompleted = true;
                              await prefs.setBool('onboarding_completed', true);
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

                    _licenseSub = Supabase.instance.client
                        .from('license_details')
                        .stream(primaryKey: ['couple_id'])
                        .eq('couple_id', _coupleId!)
                        .listen(
                          (licenseDataList) async {
                            if (licenseDataList.isEmpty) return;
                            notifyListeners();
                          },
                          onError: (error) {
                            debugPrint('Supabase license_details stream error: $error');
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
              await prefs.setString('partner_name', partnerDisplayName);
            }

            final partnerAvatar = pData['avatar_url'] as String?;
            if (partnerAvatar != null && partnerAvatar.isNotEmpty) {
              _partnerAvatarPath = partnerAvatar;
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('partner_avatar_path', partnerAvatar);
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
              await prefs.setString('partner_join_date', pCreated);
            }

            final partnerDisplayName = pData['display_name'] as String?;
            if (partnerDisplayName != null && partnerDisplayName.isNotEmpty) {
              _partnerName = partnerDisplayName;
              await prefs.setString('partner_name', partnerDisplayName);
            }

            final partnerAvatar = pData['avatar_url'] as String?;
            if (partnerAvatar != null && partnerAvatar.isNotEmpty) {
              _partnerAvatarPath = partnerAvatar;
              await prefs.setString('partner_avatar_path', partnerAvatar);
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
    await prefs.setString('your_name', name);

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
        // RelationshipProvider no longer holds those fields to re-push --
        // narrower resync coverage than before for this one edge case
        // (offline-set license fields whose original push failed, never
        // edited again), acknowledged and left as a known gap rather than
        // building new Riverpod-from-non-widget plumbing to close it (see
        // migration-roadmap.md's Phase 5 corrections).

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
    await prefs.setString('story_title', title);
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
    await prefs.setString('relationship_start_date', date.toIso8601String());
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
    await prefs.setInt('relationship_start_hour', time.hour);
    await prefs.setInt('relationship_start_minute', time.minute);
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
    await prefs.setString('your_name', yours);
    await prefs.setString('partner_name', partner);

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
          await prefs.setString('your_avatar_path', yourRef);
        } else {
          _yourAvatarPath = yourPath;
          if (yourPath.isEmpty) {
            await prefs.remove('your_avatar_path');
          } else {
            await prefs.setString('your_avatar_path', yourPath);
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
          await prefs.setString('partner_avatar_path', partnerRef);
        } else {
          _partnerAvatarPath = partnerPath;
          if (partnerPath.isEmpty) {
            await prefs.remove('partner_avatar_path');
          } else {
            await prefs.setString('partner_avatar_path', partnerPath);
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
          await prefs.remove('your_avatar_path');
        } else {
          await prefs.setString('your_avatar_path', yourPath);
        }
      }
      if (partnerPath != null) {
        _partnerAvatarPath = partnerPath;
        if (partnerPath.isEmpty) {
          await prefs.remove('partner_avatar_path');
        } else {
          await prefs.setString('partner_avatar_path', partnerPath);
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
      final result = await CoupleService.instance.createRelationshipWorkspace();
      _coupleId = result['couple_id'] as String;
      _coupleCode = result['pairing_code'] as String;
      _recoveryCode = result['recovery_code'] as String;
      _status = RelationshipStatus.waiting;
      _isPaired = false;
      _isCreator = true;
      _onboardingCompleted = false;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('couple_code', _coupleCode!);
      await prefs.setString('couple_id', _coupleId!);
      await prefs.setBool('is_paired', false);
      await prefs.setBool('is_creator', true);
      await prefs.setBool('onboarding_completed', false);
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
      final result = await CoupleService.instance.getOrRotatePairingCode(forceRotate: forceRotate);
      if (result['success'] == true) {
        final newCode = result['pairing_code'] as String?;
        if (newCode != null && newCode.isNotEmpty) {
          _coupleCode = newCode;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('couple_code', newCode);
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
      await prefs.setString('couple_code', cleanCode);

      if (isSupabaseAvailable && _userId != null) {
        final result = await CoupleService.instance.joinWithCode(cleanCode);
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

        await prefs.setString('couple_id', _coupleId!);
        await prefs.setString('partner_id', _partnerId!);
        await prefs.setBool('is_paired', true);
        await prefs.setBool('onboarding_completed', false);

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
            await prefs.setString('relationship_start_date', startStr);
          }
          final hour = coupleData['start_time_hour'] as int?;
          final minute = coupleData['start_time_minute'] as int?;
          if (hour != null && minute != null) {
            _startTime = TimeOfDay(hour: hour, minute: minute);
            await prefs.setInt('relationship_start_hour', hour);
            await prefs.setInt('relationship_start_minute', minute);
          }
          _storyTitle = coupleData['story_title'] as String? ?? 'Our Story';
          await prefs.setString('story_title', _storyTitle!);
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
    await prefs.setBool('is_paired', _isPaired);
    await prefs.setBool('onboarding_completed', true);

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

  Future<void> togglePremium() async {
    _isPremium = !_isPremium;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_premium', _isPremium);
    if (_coupleId != null) {
      Supabase.instance.client
          .from('couples')
          .update({'is_premium': _isPremium})
          .eq('id', _coupleId!)
          .then((_) {});
    }
    notifyListeners();
  }

  Future<void> setPremium(bool value) async {
    _isPremium = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_premium', _isPremium);
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
      final result = await CoupleService.instance.recoverWithCode(code);
      final bool success = result['success'] as bool? ?? false;
      if (success) {
        _coupleId = result['couple_id'] as String;
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('couple_id', _coupleId!);
        
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
      final result = await CoupleService.instance.regenerateRecoveryCode();
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
      await prefs.setBool('is_paired', false);
      await prefs.remove('couple_code');
      await prefs.remove('partner_name');
      await prefs.remove('partner_avatar_path');
      await prefs.remove('partner_join_date');
      _onboardingCompleted = false;
      await prefs.setBool('onboarding_completed', false);

      if (isSupabaseAvailable && _userId != null) {
        try {
          await NotificationService().sendPartnerNotification(
            title: 'Relationship Unlinked 💔',
            body: 'Your partner has unlinked from the relationship.',
            feature: 'relationship',
          );
        } catch (_) {}
          await CoupleService.instance.disconnectRelationshipWorkspace();
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
      final onboardingCompleted = prefs.getBool('onboarding_completed');
      final startDate = prefs.getString('relationship_start_date');
      final startHour = prefs.getInt('relationship_start_hour');
      final startMinute = prefs.getInt('relationship_start_minute');
      final yourAvatarPath = prefs.getString('your_avatar_path');
      final yourName = prefs.getString('your_name');

      await prefs.clear();

      if (onboardingCompleted != null) await prefs.setBool('onboarding_completed', onboardingCompleted);
      if (startDate != null) await prefs.setString('relationship_start_date', startDate);
      if (startHour != null) await prefs.setInt('relationship_start_hour', startHour);
      if (startMinute != null) await prefs.setInt('relationship_start_minute', startMinute);
      if (yourAvatarPath != null) await prefs.setString('your_avatar_path', yourAvatarPath);
      if (yourName != null) await prefs.setString('your_name', yourName);
    }

    await RelationshipLifecycleManager.instance.handleLogout();

    _userSub?.cancel();
    _partnerUserSub?.cancel();
    _partnerUserSub = null;
    _partnerActivity = null;
    _coupleSub?.cancel();
    _licenseSub?.cancel();
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

  DateTime get startDateTime {
    if (_startDate == null) return DateTime.now();
    return DateTime(
      _startDate!.year,
      _startDate!.month,
      _startDate!.day,
      _startTime?.hour ?? 0,
      _startTime?.minute ?? 0,
    );
  }

  Duration get relationshipDuration {
    return DateTime.now().difference(startDateTime);
  }

  int get totalDays {
    if (_startDate == null) return 0;
    return DateHelper.calendarDaysBetween(_startDate!, DateTime.now());
  }
  
  int get totalHours => relationshipDuration.inHours;
  int get totalMinutes => relationshipDuration.inMinutes;
  int get totalSeconds => relationshipDuration.inSeconds;

  Map<String, int> get preciseAge {
    if (_startDate == null) {
      return {
        'years': 0,
        'months': 0,
        'days': 0,
        'hours': 0,
        'minutes': 0,
        'seconds': 0,
      };
    }
    return DateHelper.getPreciseAge(startDateTime, DateTime.now());
  }

  int get totalMonths {
    if (_startDate == null) return 0;
    final now = DateTime.now();
    return (now.year - _startDate!.year) * 12 + now.month - _startDate!.month;
  }

  String get relationshipAge {
    final age = preciseAge;
    final parts = <String>[];
    if (age['years']! > 0) {
      parts.add("${age['years']} Year${age['years']! > 1 ? 's' : ''}");
    }
    if (age['months']! > 0) {
      parts.add("${age['months']} Month${age['months']! > 1 ? 's' : ''}");
    }
    parts.add("${age['days']} Day${age['days']! > 1 ? 's' : ''}");
    return parts.join(', ');
  }

  int get years => preciseAge['years']!;

  List<MilestoneInfo> get nextMilestones {
    if (_startDate == null) return [];
    final milestones = <MilestoneInfo>[];
    final days = totalDays;

    for (final target in [
      100,
      200,
      365,
      500,
      730,
      1000,
      1500,
      2000,
      2500,
      3000,
    ]) {
      if (days < target) {
        final daysUntil = target - days;
        int prev = 0;
        for (final p in [0, 100, 200, 365, 500, 730, 1000, 1500, 2000, 2500]) {
          if (p < target && p <= days) prev = p;
        }
        final progress = (days - prev) / (target - prev);
        String label;
        if (target == 365) {
          label = '1st Anniversary';
        } else if (target == 730) {
          label = '2nd Anniversary';
        } else {
          label = '$target Days';
        }
        milestones.add(
          MilestoneInfo(
            title: label,
            daysUntil: daysUntil,
            progress: progress.clamp(0.0, 1.0),
          ),
        );
        if (milestones.length >= 5) break;
      }
    }

    if (milestones.length < 5 && _startDate != null) {
      final nextYear = years + 1;
      final anniversaryDate = DateHelper.getAnniversaryDate(_startDate!, nextYear);
      final daysUntil = DateHelper.daysUntil(anniversaryDate);
      if (daysUntil > 0) {
        final ordinal = _getOrdinal(nextYear);
        milestones.add(
          MilestoneInfo(
            title: '$ordinal Anniversary',
            daysUntil: daysUntil,
            progress: 1.0 - (daysUntil / 365.0).clamp(0.0, 1.0),
          ),
        );
      }
    }

    milestones.sort((a, b) => a.daysUntil.compareTo(b.daysUntil));
    return milestones.take(5).toList();
  }

  String _getOrdinal(int n) {
    if (n >= 11 && n <= 13) return '${n}th';
    switch (n % 10) {
      case 1:
        return '${n}st';
      case 2:
        return '${n}nd';
      case 3:
        return '${n}rd';
      default:
        return '${n}th';
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _userSub?.cancel();
    _partnerUserSub?.cancel();
    _coupleSub?.cancel();
    _licenseSub?.cancel();
    if (_presenceChannel != null) {
      try {
        _presenceChannel!.unsubscribe();
        Supabase.instance.client.removeChannel(_presenceChannel!);
      } catch (_) {}
    }
    super.dispose();
  }
}
