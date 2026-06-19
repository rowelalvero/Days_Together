import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:uuid/uuid.dart';

const Object _unset = Object();

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
  DateTime? _startDate;
  TimeOfDay? _startTime;
  String? _partnerName;
  String? _yourName;
  String? _yourAvatarPath;
  String? _partnerAvatarPath;
  String? _coupleCode;
  bool _isPaired = false;
  bool _isPremium = false;
  String? _storyTitle;
  String? _yourGender;
  String? _partnerGender;
  String? _yourPhone;
  String? _partnerPhone;
  DateTime? _yourBirthdate;
  DateTime? _partnerBirthdate;
  String? _yourAddress;
  String? _partnerAddress;
  String? _yourNationality;
  String? _partnerNationality;
  String? _yourWeight;
  String? _partnerWeight;
  String? _yourHeight;
  String? _partnerHeight;
  String? _yourBloodType;
  String? _partnerBloodType;
  String? _yourEyeColor;
  String? _partnerEyeColor;
  String? _yourConditions;
  String? _partnerConditions;
  DateTime? _yourDateIssued;
  DateTime? _partnerDateIssued;
  String? _yourSignature;
  String? _partnerSignature;

  // Firebase Streams Subscriptions
  StreamSubscription? _userSub;
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

  DateTime? get startDate => _startDate;
  TimeOfDay? get startTime => _startTime;
  String? get partnerName => _partnerName;
  String? get yourName => _yourName;
  String? get yourAvatarPath => _yourAvatarPath;
  String? get partnerAvatarPath => _partnerAvatarPath;
  String? get coupleCode => _coupleCode;
  bool get isPaired => _isPaired;
  bool get isPremium => _isPremium;
  String get storyTitle => _storyTitle ?? 'Our Story';
  String? get yourGender => _yourGender;
  String? get partnerGender => _partnerGender;
  String? get yourPhone => _yourPhone;
  String? get partnerPhone => _partnerPhone;
  DateTime? get yourBirthdate => _yourBirthdate;
  DateTime? get partnerBirthdate => _partnerBirthdate;
  String? get yourAddress => _yourAddress;
  String? get partnerAddress => _partnerAddress;
  String get yourNationality => _yourNationality ?? 'Love Land';
  String get partnerNationality => _partnerNationality ?? 'Love Land';
  String get yourWeight => _yourWeight ?? '—';
  String get partnerWeight => _partnerWeight ?? '—';
  String get yourHeight => _yourHeight ?? '—';
  String get partnerHeight => _partnerHeight ?? '—';
  String get yourBloodType => _yourBloodType ?? '—';
  String get partnerBloodType => _partnerBloodType ?? '—';
  String get yourEyeColor => _yourEyeColor ?? '—';
  String get partnerEyeColor => _partnerEyeColor ?? '—';
  String get yourConditions => _yourConditions ?? 'Madly in Love';
  String get partnerConditions => _partnerConditions ?? 'Madly in Love';
  DateTime? get yourDateIssued => _yourDateIssued;
  DateTime? get partnerDateIssued => _partnerDateIssued;
  String? get yourSignature => _yourSignature;
  String? get partnerSignature => _partnerSignature;
  String? get coupleId => _coupleId;
  String? get userId => _userId;
  String? get partnerId => _partnerId;

  bool get isPartnerOnline => _isPartnerOnline;
  DateTime? get yourJoinDate => _yourJoinDate;
  DateTime? get partnerJoinDate => _partnerJoinDate;

  bool get isFirebaseAvailable {
    try {
      Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

  RelationshipProvider() {
    _loadLocalData().then((_) {
      if (isFirebaseAvailable) {
        _initFirebaseSync();
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
    _isPaired = prefs.getBool('is_paired') ?? false;
    _isPremium = prefs.getBool('is_premium') ?? false;
    _storyTitle = prefs.getString('story_title');
    _yourGender = prefs.getString('your_gender');
    _partnerGender = prefs.getString('partner_gender');
    _yourPhone = prefs.getString('your_phone');
    _partnerPhone = prefs.getString('partner_phone');
    final yourBirthdateStr = prefs.getString('your_birthdate');
    if (yourBirthdateStr != null) {
      _yourBirthdate = DateTime.parse(yourBirthdateStr);
    }
    final partnerBirthdateStr = prefs.getString('partner_birthdate');
    if (partnerBirthdateStr != null) {
      _partnerBirthdate = DateTime.parse(partnerBirthdateStr);
    }
    _yourAddress = prefs.getString('your_address');
    _partnerAddress = prefs.getString('partner_address');
    _yourNationality = prefs.getString('your_nationality');
    _partnerNationality = prefs.getString('partner_nationality');
    _yourWeight = prefs.getString('your_weight');
    _partnerWeight = prefs.getString('partner_weight');
    _yourHeight = prefs.getString('your_height');
    _partnerHeight = prefs.getString('partner_height');
    _yourBloodType = prefs.getString('your_blood_type');
    _partnerBloodType = prefs.getString('partner_blood_type');
    _yourEyeColor = prefs.getString('your_eye_color');
    _partnerEyeColor = prefs.getString('partner_eye_color');
    _yourConditions = prefs.getString('your_conditions');
    _partnerConditions = prefs.getString('partner_conditions');
    final yourDateIssuedStr = prefs.getString('your_date_issued');
    if (yourDateIssuedStr != null) {
      _yourDateIssued = DateTime.parse(yourDateIssuedStr);
    }
    final partnerDateIssuedStr = prefs.getString('partner_date_issued');
    if (partnerDateIssuedStr != null) {
      _partnerDateIssued = DateTime.parse(partnerDateIssuedStr);
    }
    _yourSignature = prefs.getString('your_signature');
    _partnerSignature = prefs.getString('partner_signature');

    final yourJoinDateStr = prefs.getString('your_join_date');
    if (yourJoinDateStr != null) {
      _yourJoinDate = DateTime.parse(yourJoinDateStr);
    }
    final partnerJoinDateStr = prefs.getString('partner_join_date');
    if (partnerJoinDateStr != null) {
      _partnerJoinDate = DateTime.parse(partnerJoinDateStr);
    }

    notifyListeners();
  }

  void _initFirebaseSync() {
    _authSub?.cancel();
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      final user = data.session?.user;

      try {
        await Supabase.instance.client.removeAllChannels();
      } catch (_) {}

      _userSub?.cancel();
      _coupleSub?.cancel();
      _licenseSub?.cancel();

      if (user == null) {
        _userId = null;
        _coupleId = null;
        _partnerId = null;
        _isPaired = false;
        _isPartnerOnline = false;
        _yourJoinDate = null;
        _partnerJoinDate = null;
        _presenceChannel?.unsubscribe();
        _presenceChannel = null;
        notifyListeners();
        return;
      }

      _userId = user.id;

      _userSub = Supabase.instance.client
          .from('users')
          .stream(primaryKey: ['id'])
          .eq('id', _userId!)
          .listen((dataList) async {
            if (dataList.isEmpty) {
              try {
                await Supabase.instance.client.from('users').upsert({
                  'id': _userId!,
                  'display_name': _yourName,
                  'couple_id': null,
                });
              } catch (_) {}
              return;
            }

            final userData = dataList.first;
            _coupleId = userData['couple_id'] as String?;
            _partnerId = userData['partner_id'] as String?;

            final prefs = await SharedPreferences.getInstance();

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

            // Load and cache partner's join date if partnered
            if (_partnerId != null) {
              Supabase.instance.client
                  .from('users')
                  .select('id')
                  .eq('id', _partnerId!)
                  .maybeSingle()
                  .then((pData) async {
                if (pData != null) {
                  final pCreated = pData['created_at'] as String?;
                  if (pCreated != null) {
                    _partnerJoinDate = DateTime.parse(pCreated);
                    final innerPrefs = await SharedPreferences.getInstance();
                    await innerPrefs.setString('partner_join_date', pCreated);
                    notifyListeners();
                  }
                }
              }).catchError((error) {
                debugPrint('Error loading partner join date: $error');
              });
            } else {
              _partnerJoinDate = null;
              await prefs.remove('partner_join_date');
            }

            _initPresence(); // Initialize real-time presence channel

            if (_coupleId != null) {
              _isPaired = true;
              _coupleSub?.cancel();
              _syncLocalDetailsToCloud();

              _coupleSub = Supabase.instance.client
                  .from('couples')
                  .stream(primaryKey: ['id'])
                  .eq('id', _coupleId!)
                  .listen((coupleDataList) async {
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

                    final prefs = await SharedPreferences.getInstance();
                    if (_storyTitle != null)
                      await prefs.setString('story_title', _storyTitle!);
                    if (_startDate != null)
                      await prefs.setString(
                        'relationship_start_date',
                        _startDate!.toIso8601String(),
                      );
                    if (_startTime != null) {
                      await prefs.setInt(
                        'relationship_start_hour',
                        _startTime!.hour,
                      );
                      await prefs.setInt(
                        'relationship_start_minute',
                        _startTime!.minute,
                      );
                    }
                    await prefs.setBool('is_premium', _isPremium);

                    notifyListeners();
                  }, onError: (error) {
                    debugPrint('Supabase couples stream error: $error');
                  });

              _licenseSub = Supabase.instance.client
                  .from('license_details')
                  .stream(primaryKey: ['couple_id'])
                  .eq('couple_id', _coupleId!)
                  .listen((licenseDataList) async {
                    if (licenseDataList.isEmpty) return;
                    final lData = licenseDataList.first;

                    final isYouCreator = lData['creator_id'] == _userId;

                    _yourName =
                        (isYouCreator
                                ? lData['your_name']
                                : lData['partner_name'])
                            as String?;
                    _partnerName =
                        (isYouCreator
                                ? lData['partner_name']
                                : lData['your_name'])
                            as String?;
                    _yourGender =
                        (isYouCreator
                                ? lData['your_gender']
                                : lData['partner_gender'])
                            as String?;
                    _partnerGender =
                        (isYouCreator
                                ? lData['partner_gender']
                                : lData['your_gender'])
                            as String?;
                    _yourPhone =
                        (isYouCreator
                                ? lData['your_phone']
                                : lData['partner_phone'])
                            as String?;
                    _partnerPhone =
                        (isYouCreator
                                ? lData['partner_phone']
                                : lData['your_phone'])
                            as String?;

                    _yourAvatarPath =
                        (isYouCreator
                                ? lData['your_avatar_path']
                                : lData['partner_avatar_path'])
                            as String?;
                    _partnerAvatarPath =
                        (isYouCreator
                                ? lData['partner_avatar_path']
                                : lData['your_avatar_path'])
                            as String?;

                    final yBirth =
                        lData[isYouCreator
                                ? 'your_birthdate'
                                : 'partner_birthdate']
                            as String?;
                    _yourBirthdate = yBirth != null
                        ? DateTime.parse(yBirth)
                        : null;

                    final pBirth =
                        lData[isYouCreator
                                ? 'partner_birthdate'
                                : 'your_birthdate']
                            as String?;
                    _partnerBirthdate = pBirth != null
                        ? DateTime.parse(pBirth)
                        : null;

                    _yourAddress =
                        (isYouCreator
                                ? lData['your_address']
                                : lData['partner_address'])
                            as String?;
                    _partnerAddress =
                        (isYouCreator
                                ? lData['partner_address']
                                : lData['your_address'])
                            as String?;

                    _yourNationality =
                        (isYouCreator
                                ? lData['your_nationality']
                                : lData['partner_nationality'])
                            as String?;
                    _partnerNationality =
                        (isYouCreator
                                ? lData['partner_nationality']
                                : lData['your_nationality'])
                            as String?;

                    _yourWeight =
                        (isYouCreator
                                ? lData['your_weight']
                                : lData['partner_weight'])
                            as String?;
                    _partnerWeight =
                        (isYouCreator
                                ? lData['partner_weight']
                                : lData['your_weight'])
                            as String?;

                    _yourHeight =
                        (isYouCreator
                                ? lData['your_height']
                                : lData['partner_height'])
                            as String?;
                    _partnerHeight =
                        (isYouCreator
                                ? lData['partner_height']
                                : lData['your_height'])
                            as String?;

                    _yourBloodType =
                        (isYouCreator
                                ? lData['your_blood_type']
                                : lData['partner_blood_type'])
                            as String?;
                    _partnerBloodType =
                        (isYouCreator
                                ? lData['partner_blood_type']
                                : lData['your_blood_type'])
                            as String?;

                    _yourEyeColor =
                        (isYouCreator
                                ? lData['your_eye_color']
                                : lData['partner_eye_color'])
                            as String?;
                    _partnerEyeColor =
                        (isYouCreator
                                ? lData['partner_eye_color']
                                : lData['your_eye_color'])
                            as String?;

                    _yourConditions =
                        (isYouCreator
                                ? lData['your_conditions']
                                : lData['partner_conditions'])
                            as String?;
                    _partnerConditions =
                        (isYouCreator
                                ? lData['partner_conditions']
                                : lData['your_conditions'])
                            as String?;

                    final yIssued =
                        lData[isYouCreator
                                ? 'your_date_issued'
                                : 'partner_date_issued']
                            as String?;
                    _yourDateIssued = yIssued != null
                        ? DateTime.parse(yIssued)
                        : null;

                    final pIssued =
                        lData[isYouCreator
                                ? 'partner_date_issued'
                                : 'your_date_issued']
                            as String?;
                    _partnerDateIssued = pIssued != null
                        ? DateTime.parse(pIssued)
                        : null;

                    _yourSignature =
                        (isYouCreator
                                ? lData['your_signature']
                                : lData['partner_signature'])
                            as String?;
                    _partnerSignature =
                        (isYouCreator
                                ? lData['partner_signature']
                                : lData['your_signature'])
                            as String?;

                    final prefs = await SharedPreferences.getInstance();
                    if (_yourName != null)
                      await prefs.setString('your_name', _yourName!);
                    if (_partnerName != null)
                      await prefs.setString('partner_name', _partnerName!);
                    if (_yourGender != null)
                      await prefs.setString('your_gender', _yourGender!);
                    if (_partnerGender != null)
                      await prefs.setString('partner_gender', _partnerGender!);
                    if (_yourPhone != null)
                      await prefs.setString('your_phone', _yourPhone!);
                    if (_partnerPhone != null)
                      await prefs.setString('partner_phone', _partnerPhone!);
                    if (_yourAvatarPath != null)
                      await prefs.setString(
                        'your_avatar_path',
                        _yourAvatarPath!,
                      );
                    if (_partnerAvatarPath != null)
                      await prefs.setString(
                        'partner_avatar_path',
                        _partnerAvatarPath!,
                      );
                    if (_yourBirthdate != null)
                      await prefs.setString(
                        'your_birthdate',
                        _yourBirthdate!.toIso8601String(),
                      );
                    if (_partnerBirthdate != null)
                      await prefs.setString(
                        'partner_birthdate',
                        _partnerBirthdate!.toIso8601String(),
                      );
                    if (_yourAddress != null)
                      await prefs.setString('your_address', _yourAddress!);
                    if (_partnerAddress != null)
                      await prefs.setString(
                        'partner_address',
                        _partnerAddress!,
                      );
                    if (_yourNationality != null)
                      await prefs.setString(
                        'your_nationality',
                        _yourNationality!,
                      );
                    if (_partnerNationality != null)
                      await prefs.setString(
                        'partner_nationality',
                        _partnerNationality!,
                      );
                    if (_yourWeight != null)
                      await prefs.setString('your_weight', _yourWeight!);
                    if (_partnerWeight != null)
                      await prefs.setString('partner_weight', _partnerWeight!);
                    if (_yourHeight != null)
                      await prefs.setString('your_height', _yourHeight!);
                    if (_partnerHeight != null)
                      await prefs.setString('partner_height', _partnerHeight!);
                    if (_yourBloodType != null)
                      await prefs.setString('your_blood_type', _yourBloodType!);
                    if (_partnerBloodType != null)
                      await prefs.setString(
                        'partner_blood_type',
                        _partnerBloodType!,
                      );
                    if (_yourEyeColor != null)
                      await prefs.setString('your_eye_color', _yourEyeColor!);
                    if (_partnerEyeColor != null)
                      await prefs.setString(
                        'partner_eye_color',
                        _partnerEyeColor!,
                      );
                    if (_yourConditions != null)
                      await prefs.setString(
                        'your_conditions',
                        _yourConditions!,
                      );
                    if (_partnerConditions != null)
                      await prefs.setString(
                        'partner_conditions',
                        _partnerConditions!,
                      );
                    if (_yourDateIssued != null)
                      await prefs.setString(
                        'your_date_issued',
                        _yourDateIssued!.toIso8601String(),
                      );
                    if (_partnerDateIssued != null)
                      await prefs.setString(
                        'partner_date_issued',
                        _partnerDateIssued!.toIso8601String(),
                      );
                    if (_yourSignature != null)
                      await prefs.setString('your_signature', _yourSignature!);
                    if (_partnerSignature != null)
                      await prefs.setString(
                        'partner_signature',
                        _partnerSignature!,
                      );

                    notifyListeners();
                  }, onError: (error) {
                    debugPrint('Supabase license_details stream error: $error');
                  });
            }
          }, onError: (error) {
            debugPrint('Supabase users stream error: $error');
          });
    }, onError: (error) {
      debugPrint('Supabase AuthStateChange error: $error');
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

    _presenceChannel!.onPresenceSync((_) {
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
    }).subscribe((status, [error]) async {
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

  Future<void> setYourName(String name) async {
    _yourName = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('your_name', name);

    if (isFirebaseAvailable && _userId != null) {
      try {
        await Supabase.instance.client.from('users').update({
          'display_name': name,
        }).eq('id', _userId!);
      } catch (e) {
        debugPrint('Supabase setYourName display_name update failed: $e');
      }
    }
    // Also sync to license details if paired
    if (_coupleId != null) {
      _syncLicenseField('yourName', name, 'partnerName', _partnerName);
    }
    notifyListeners();
  }

  Future<void> _syncLocalDetailsToCloud() async {
    if (!isFirebaseAvailable || _coupleId == null) return;

    // 1. Sync display_name if not synced yet
    if (_userId != null && _yourName != null) {
      try {
        await Supabase.instance.client
            .from('users')
            .update({'display_name': _yourName})
            .eq('id', _userId!);
      } catch (_) {}
    }

    // 2. Sync couples table details
    try {
      final coupleUpdates = <String, dynamic>{};
      if (_storyTitle != null) coupleUpdates['story_title'] = _storyTitle;
      if (_startDate != null)
        coupleUpdates['start_date'] = _startDate!.toIso8601String();
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

    // 3. Sync license_details table details
    try {
      final snap = await Supabase.instance.client
          .from('license_details')
          .select()
          .eq('couple_id', _coupleId!)
          .maybeSingle();

      final creatorId = snap != null ? snap['creator_id'] : _userId;
      final isCreator = creatorId == _userId;

      final licenseUpdates = <String, dynamic>{
        'couple_id': _coupleId!,
        'creator_id': creatorId,
      };

      if (_yourName != null) {
        licenseUpdates[isCreator ? 'your_name' : 'partner_name'] = _yourName;
      }
      if (_partnerName != null) {
        licenseUpdates[isCreator ? 'partner_name' : 'your_name'] = _partnerName;
      }
      if (_yourGender != null) {
        licenseUpdates[isCreator ? 'your_gender' : 'partner_gender'] =
            _yourGender;
      }
      if (_partnerGender != null) {
        licenseUpdates[isCreator ? 'partner_gender' : 'your_gender'] =
            _partnerGender;
      }
      if (_yourPhone != null) {
        licenseUpdates[isCreator ? 'your_phone' : 'partner_phone'] = _yourPhone;
      }
      if (_partnerPhone != null) {
        licenseUpdates[isCreator ? 'partner_phone' : 'your_phone'] =
            _partnerPhone;
      }
      if (_yourBirthdate != null) {
        licenseUpdates[isCreator ? 'your_birthdate' : 'partner_birthdate'] =
            _yourBirthdate!.toIso8601String();
      }
      if (_partnerBirthdate != null) {
        licenseUpdates[isCreator ? 'partner_birthdate' : 'your_birthdate'] =
            _partnerBirthdate!.toIso8601String();
      }
      if (_yourAddress != null) {
        licenseUpdates[isCreator ? 'your_address' : 'partner_address'] =
            _yourAddress;
      }
      if (_partnerAddress != null) {
        licenseUpdates[isCreator ? 'partner_address' : 'your_address'] =
            _partnerAddress;
      }
      if (_yourNationality != null) {
        licenseUpdates[isCreator ? 'your_nationality' : 'partner_nationality'] =
            _yourNationality;
      }
      if (_partnerNationality != null) {
        licenseUpdates[isCreator ? 'partner_nationality' : 'your_nationality'] =
            _partnerNationality;
      }
      if (_yourWeight != null) {
        licenseUpdates[isCreator ? 'your_weight' : 'partner_weight'] =
            _yourWeight;
      }
      if (_partnerWeight != null) {
        licenseUpdates[isCreator ? 'partner_weight' : 'your_weight'] =
            _partnerWeight;
      }
      if (_yourHeight != null) {
        licenseUpdates[isCreator ? 'your_height' : 'partner_height'] =
            _yourHeight;
      }
      if (_partnerHeight != null) {
        licenseUpdates[isCreator ? 'partner_height' : 'your_height'] =
            _partnerHeight;
      }
      if (_yourBloodType != null) {
        licenseUpdates[isCreator ? 'your_blood_type' : 'partner_blood_type'] =
            _yourBloodType;
      }
      if (_partnerBloodType != null) {
        licenseUpdates[isCreator ? 'partner_blood_type' : 'your_blood_type'] =
            _partnerBloodType;
      }
      if (_yourEyeColor != null) {
        licenseUpdates[isCreator ? 'your_eye_color' : 'partner_eye_color'] =
            _yourEyeColor;
      }
      if (_partnerEyeColor != null) {
        licenseUpdates[isCreator ? 'partner_eye_color' : 'your_eye_color'] =
            _partnerEyeColor;
      }
      if (_yourConditions != null) {
        licenseUpdates[isCreator ? 'your_conditions' : 'partner_conditions'] =
            _yourConditions;
      }
      if (_partnerConditions != null) {
        licenseUpdates[isCreator ? 'partner_conditions' : 'your_conditions'] =
            _partnerConditions;
      }

      await Supabase.instance.client
          .from('license_details')
          .upsert(licenseUpdates);
    } catch (_) {}

    // 4. Upload local avatar if needed
    if (_yourAvatarPath != null &&
        !_yourAvatarPath!.startsWith('http') &&
        _yourAvatarPath!.isNotEmpty) {
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
  }

  Future<void> setStartTime(TimeOfDay time) async {
    _startTime = time;
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

    if (isFirebaseAvailable && _userId != null) {
      try {
        await Supabase.instance.client
            .from('users')
            .update({'display_name': yours})
            .eq('id', _userId!);
      } catch (e) {
        debugPrint('Supabase setNames display_name update failed: $e');
      }
    }

    _syncLicenseField('yourName', yours, 'partnerName', partner);
    notifyListeners();
  }

  Future<void> setGenders(String yours, String partner) async {
    _yourGender = yours;
    _partnerGender = partner;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('your_gender', yours);
    await prefs.setString('partner_gender', partner);
    _syncLicenseField('yourGender', yours, 'partnerGender', partner);
    notifyListeners();
  }

  Future<void> setPhoneNumbers(String yours, String partner) async {
    _yourPhone = yours;
    _partnerPhone = partner;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('your_phone', yours);
    await prefs.setString('partner_phone', partner);
    _syncLicenseField('yourPhone', yours, 'partnerPhone', partner);
    notifyListeners();
  }

  Future<void> setBirthdates(DateTime? yours, DateTime? partner) async {
    _yourBirthdate = yours;
    _partnerBirthdate = partner;
    final prefs = await SharedPreferences.getInstance();
    if (yours != null) {
      await prefs.setString('your_birthdate', yours.toIso8601String());
    } else {
      await prefs.remove('your_birthdate');
    }
    if (partner != null) {
      await prefs.setString('partner_birthdate', partner.toIso8601String());
    } else {
      await prefs.remove('partner_birthdate');
    }
    _syncLicenseField('yourBirthdate', yours, 'partnerBirthdate', partner);
    notifyListeners();
  }

  Future<void> setAddresses(String? yours, String? partner) async {
    _yourAddress = yours;
    _partnerAddress = partner;
    final prefs = await SharedPreferences.getInstance();
    if (yours != null) {
      await prefs.setString('your_address', yours);
    } else {
      await prefs.remove('your_address');
    }
    if (partner != null) {
      await prefs.setString('partner_address', partner);
    } else {
      await prefs.remove('partner_address');
    }
    _syncLicenseField('yourAddress', yours, 'partnerAddress', partner);
    notifyListeners();
  }

  Future<void> setNationalities(String yours, String partner) async {
    _yourNationality = yours;
    _partnerNationality = partner;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('your_nationality', yours);
    await prefs.setString('partner_nationality', partner);
    _syncLicenseField('yourNationality', yours, 'partnerNationality', partner);
    notifyListeners();
  }

  Future<void> setWeightsAndHeights(
    String yourW,
    String partnerW,
    String yourH,
    String partnerH,
  ) async {
    _yourWeight = yourW;
    _partnerWeight = partnerW;
    _yourHeight = yourH;
    _partnerHeight = partnerH;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('your_weight', yourW);
    await prefs.setString('partner_weight', partnerW);
    await prefs.setString('your_height', yourH);
    await prefs.setString('partner_height', partnerH);
    if (_coupleId != null) {
      try {
        final snap = await Supabase.instance.client
            .from('license_details')
            .select()
            .eq('couple_id', _coupleId!)
            .maybeSingle();
        final creatorId = snap != null ? snap['creator_id'] : _userId;
        final isCreator = creatorId == _userId;
        await Supabase.instance.client.from('license_details').upsert({
          'couple_id': _coupleId!,
          'creator_id': creatorId,
          isCreator ? 'your_weight' : 'partner_weight': yourW,
          isCreator ? 'partner_weight' : 'your_weight': partnerW,
          isCreator ? 'your_height' : 'partner_height': yourH,
          isCreator ? 'partner_height' : 'your_height': partnerH,
        });
      } catch (e) {
        debugPrint('setWeightsAndHeights failed: $e');
      }
    }
    notifyListeners();
  }

  Future<void> setBloodAndEyes(
    String yourB,
    String partnerB,
    String yourE,
    String partnerE,
  ) async {
    _yourBloodType = yourB;
    _partnerBloodType = partnerB;
    _yourEyeColor = yourE;
    _partnerEyeColor = partnerE;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('your_blood_type', yourB);
    await prefs.setString('partner_blood_type', partnerB);
    await prefs.setString('your_eye_color', yourE);
    await prefs.setString('partner_eye_color', partnerE);
    if (_coupleId != null) {
      try {
        final snap = await Supabase.instance.client
            .from('license_details')
            .select()
            .eq('couple_id', _coupleId!)
            .maybeSingle();
        final creatorId = snap != null ? snap['creator_id'] : _userId;
        final isCreator = creatorId == _userId;
        await Supabase.instance.client.from('license_details').upsert({
          'couple_id': _coupleId!,
          'creator_id': creatorId,
          isCreator ? 'your_blood_type' : 'partner_blood_type': yourB,
          isCreator ? 'partner_blood_type' : 'your_blood_type': partnerB,
          isCreator ? 'your_eye_color' : 'partner_eye_color': yourE,
          isCreator ? 'partner_eye_color' : 'your_eye_color': partnerE,
        });
      } catch (e) {
        debugPrint('setBloodAndEyes failed: $e');
      }
    }
    notifyListeners();
  }

  Future<void> setConditionsAndDateIssued(
    String yourC,
    String partnerC,
    DateTime? yourDate,
    DateTime? partnerDate,
  ) async {
    _yourConditions = yourC;
    _partnerConditions = partnerC;
    _yourDateIssued = yourDate;
    _partnerDateIssued = partnerDate;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('your_conditions', yourC);
    await prefs.setString('partner_conditions', partnerC);
    if (yourDate != null) {
      await prefs.setString('your_date_issued', yourDate.toIso8601String());
    }
    if (partnerDate != null) {
      await prefs.setString(
        'partner_date_issued',
        partnerDate.toIso8601String(),
      );
    }
    if (_coupleId != null) {
      try {
        final snap = await Supabase.instance.client
            .from('license_details')
            .select()
            .eq('couple_id', _coupleId!)
            .maybeSingle();
        final creatorId = snap != null ? snap['creator_id'] : _userId;
        final isCreator = creatorId == _userId;
        await Supabase.instance.client.from('license_details').upsert({
          'couple_id': _coupleId!,
          'creator_id': creatorId,
          isCreator ? 'your_conditions' : 'partner_conditions': yourC,
          isCreator ? 'partner_conditions' : 'your_conditions': partnerC,
          isCreator ? 'your_date_issued' : 'partner_date_issued': yourDate
              ?.toIso8601String(),
          isCreator ? 'partner_date_issued' : 'your_date_issued': partnerDate
              ?.toIso8601String(),
        });
      } catch (e) {
        debugPrint('setConditionsAndDateIssued failed: $e');
      }
    }
    notifyListeners();
  }

  Future<void> setYourSignature(String? signature) async {
    _yourSignature = signature;
    final prefs = await SharedPreferences.getInstance();
    if (signature != null) {
      await prefs.setString('your_signature', signature);
    } else {
      await prefs.remove('your_signature');
    }
    _syncSingleLicenseField('yourSignature', signature);
    notifyListeners();
  }

  Future<void> setPartnerSignature(String? signature) async {
    _partnerSignature = signature;
    final prefs = await SharedPreferences.getInstance();
    if (signature != null) {
      await prefs.setString('partner_signature', signature);
    } else {
      await prefs.remove('partner_signature');
    }
    _syncSingleLicenseField('partnerSignature', signature);
    notifyListeners();
  }

  String _toSnakeCase(String camel) {
    return camel.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (Match m) => '_${m[1]!.toLowerCase()}',
    );
  }

  void _syncLicenseField(
    String creatorKey,
    dynamic creatorVal,
    String partnerKey,
    dynamic partnerVal,
  ) async {
    if (_coupleId != null) {
      try {
        final snap = await Supabase.instance.client
            .from('license_details')
            .select()
            .eq('couple_id', _coupleId!)
            .maybeSingle();

        final creatorId = snap != null ? snap['creator_id'] : _userId;
        final isCreator = creatorId == _userId;

        final finalCreatorKey = _toSnakeCase(
          isCreator ? creatorKey : partnerKey,
        );
        final finalPartnerKey = _toSnakeCase(
          isCreator ? partnerKey : creatorKey,
        );

        dynamic finalCreatorVal = creatorVal;
        dynamic finalPartnerVal = partnerVal;

        if (creatorVal is DateTime)
          finalCreatorVal = creatorVal.toIso8601String();
        if (partnerVal is DateTime)
          finalPartnerVal = partnerVal.toIso8601String();

        await Supabase.instance.client.from('license_details').upsert({
          'couple_id': _coupleId!,
          'creator_id': creatorId,
          finalCreatorKey: finalCreatorVal,
          finalPartnerKey: finalPartnerVal,
        });
      } catch (e) {
        debugPrint('Supabase _syncLicenseField failed: $e');
      }
    }
  }

  void _syncSingleLicenseField(String key, dynamic val) async {
    if (_coupleId != null) {
      try {
        final snap = await Supabase.instance.client
            .from('license_details')
            .select()
            .eq('couple_id', _coupleId!)
            .maybeSingle();

        final creatorId = snap != null ? snap['creator_id'] : _userId;
        final isCreator = creatorId == _userId;

        String finalKey = key;
        if (!isCreator) {
          if (key.startsWith('your')) {
            finalKey = 'partner${key.substring(4)}';
          } else if (key.startsWith('partner')) {
            finalKey = 'your${key.substring(7)}';
          }
        }

        final snakeKey = _toSnakeCase(finalKey);
        dynamic finalVal = val;
        if (val is DateTime) finalVal = val.toIso8601String();

        await Supabase.instance.client.from('license_details').upsert({
          'couple_id': _coupleId!,
          'creator_id': creatorId,
          snakeKey: finalVal,
        });
      } catch (e) {
        debugPrint('Supabase _syncSingleLicenseField failed: $e');
      }
    }
  }

  Future<void> updateLicense({
    Object? yourName = _unset,
    Object? partnerName = _unset,
    Object? yourGender = _unset,
    Object? partnerGender = _unset,
    Object? yourPhone = _unset,
    Object? partnerPhone = _unset,
    Object? yourBirthdate = _unset,
    Object? partnerBirthdate = _unset,
    Object? yourAddress = _unset,
    Object? partnerAddress = _unset,
    Object? yourNationality = _unset,
    Object? partnerNationality = _unset,
    Object? yourWeight = _unset,
    Object? partnerWeight = _unset,
    Object? yourHeight = _unset,
    Object? partnerHeight = _unset,
    Object? yourBloodType = _unset,
    Object? partnerBloodType = _unset,
    Object? yourEyeColor = _unset,
    Object? partnerEyeColor = _unset,
    Object? yourConditions = _unset,
    Object? partnerConditions = _unset,
    Object? yourDateIssued = _unset,
    Object? partnerDateIssued = _unset,
    Object? yourSignature = _unset,
    Object? partnerSignature = _unset,
    Object? yourAvatarPath = _unset,
    Object? partnerAvatarPath = _unset,
  }) async {
    // 1. Update local variables if not unset
    if (!identical(yourName, _unset)) _yourName = yourName as String?;
    if (!identical(partnerName, _unset)) _partnerName = partnerName as String?;
    if (!identical(yourGender, _unset)) _yourGender = yourGender as String?;
    if (!identical(partnerGender, _unset))
      _partnerGender = partnerGender as String?;
    if (!identical(yourPhone, _unset)) _yourPhone = yourPhone as String?;
    if (!identical(partnerPhone, _unset))
      _partnerPhone = partnerPhone as String?;
    if (!identical(yourBirthdate, _unset))
      _yourBirthdate = yourBirthdate as DateTime?;
    if (!identical(partnerBirthdate, _unset))
      _partnerBirthdate = partnerBirthdate as DateTime?;
    if (!identical(yourAddress, _unset)) _yourAddress = yourAddress as String?;
    if (!identical(partnerAddress, _unset))
      _partnerAddress = partnerAddress as String?;
    if (!identical(yourNationality, _unset))
      _yourNationality = yourNationality as String?;
    if (!identical(partnerNationality, _unset))
      _partnerNationality = partnerNationality as String?;
    if (!identical(yourWeight, _unset)) _yourWeight = yourWeight as String?;
    if (!identical(partnerWeight, _unset))
      _partnerWeight = partnerWeight as String?;
    if (!identical(yourHeight, _unset)) _yourHeight = yourHeight as String?;
    if (!identical(partnerHeight, _unset))
      _partnerHeight = partnerHeight as String?;
    if (!identical(yourBloodType, _unset))
      _yourBloodType = yourBloodType as String?;
    if (!identical(partnerBloodType, _unset))
      _partnerBloodType = partnerBloodType as String?;
    if (!identical(yourEyeColor, _unset))
      _yourEyeColor = yourEyeColor as String?;
    if (!identical(partnerEyeColor, _unset))
      _partnerEyeColor = partnerEyeColor as String?;
    if (!identical(yourConditions, _unset))
      _yourConditions = yourConditions as String?;
    if (!identical(partnerConditions, _unset))
      _partnerConditions = partnerConditions as String?;
    if (!identical(yourDateIssued, _unset))
      _yourDateIssued = yourDateIssued as DateTime?;
    if (!identical(partnerDateIssued, _unset))
      _partnerDateIssued = partnerDateIssued as DateTime?;
    if (!identical(yourSignature, _unset))
      _yourSignature = yourSignature as String?;
    if (!identical(partnerSignature, _unset))
      _partnerSignature = partnerSignature as String?;
    if (!identical(yourAvatarPath, _unset))
      _yourAvatarPath = yourAvatarPath as String?;
    if (!identical(partnerAvatarPath, _unset))
      _partnerAvatarPath = partnerAvatarPath as String?;

    // 2. Save all to local SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    if (_yourName != null) await prefs.setString('your_name', _yourName!);
    if (_partnerName != null)
      await prefs.setString('partner_name', _partnerName!);
    if (_yourGender != null) await prefs.setString('your_gender', _yourGender!);
    if (_partnerGender != null)
      await prefs.setString('partner_gender', _partnerGender!);
    if (_yourPhone != null) await prefs.setString('your_phone', _yourPhone!);
    if (_partnerPhone != null)
      await prefs.setString('partner_phone', _partnerPhone!);
    if (_yourBirthdate != null)
      await prefs.setString(
        'your_birthdate',
        _yourBirthdate!.toIso8601String(),
      );
    if (_partnerBirthdate != null)
      await prefs.setString(
        'partner_birthdate',
        _partnerBirthdate!.toIso8601String(),
      );
    if (_yourAddress != null)
      await prefs.setString('your_address', _yourAddress!);
    if (_partnerAddress != null)
      await prefs.setString('partner_address', _partnerAddress!);
    if (_yourNationality != null)
      await prefs.setString('your_nationality', _yourNationality!);
    if (_partnerNationality != null)
      await prefs.setString('partner_nationality', _partnerNationality!);
    if (_yourWeight != null) await prefs.setString('your_weight', _yourWeight!);
    if (_partnerWeight != null)
      await prefs.setString('partner_weight', _partnerWeight!);
    if (_yourHeight != null) await prefs.setString('your_height', _yourHeight!);
    if (_partnerHeight != null)
      await prefs.setString('partner_height', _partnerHeight!);
    if (_yourBloodType != null)
      await prefs.setString('your_blood_type', _yourBloodType!);
    if (_partnerBloodType != null)
      await prefs.setString('partner_blood_type', _partnerBloodType!);
    if (_yourEyeColor != null)
      await prefs.setString('your_eye_color', _yourEyeColor!);
    if (_partnerEyeColor != null)
      await prefs.setString('partner_eye_color', _partnerEyeColor!);
    if (_yourConditions != null)
      await prefs.setString('your_conditions', _yourConditions!);
    if (_partnerConditions != null)
      await prefs.setString('partner_conditions', _partnerConditions!);
    if (_yourDateIssued != null)
      await prefs.setString(
        'your_date_issued',
        _yourDateIssued!.toIso8601String(),
      );
    if (_partnerDateIssued != null)
      await prefs.setString(
        'partner_date_issued',
        _partnerDateIssued!.toIso8601String(),
      );
    if (_yourSignature != null)
      await prefs.setString('your_signature', _yourSignature!);
    if (_partnerSignature != null)
      await prefs.setString('partner_signature', _partnerSignature!);
    if (_yourAvatarPath != null) {
      await prefs.setString('your_avatar_path', _yourAvatarPath!);
    } else {
      await prefs.remove('your_avatar_path');
    }
    if (_partnerAvatarPath != null) {
      await prefs.setString('partner_avatar_path', _partnerAvatarPath!);
    } else {
      await prefs.remove('partner_avatar_path');
    }

    // 3. Push to Database
    if (_coupleId != null) {
      try {
        final snap = await Supabase.instance.client
            .from('license_details')
            .select()
            .eq('couple_id', _coupleId!)
            .maybeSingle();
        final creatorId = snap != null ? snap['creator_id'] : _userId;
        final isCreator = creatorId == _userId;

        final Map<String, dynamic> updateData = {
          'couple_id': _coupleId!,
          'creator_id': creatorId,
          isCreator ? 'your_name' : 'partner_name': _yourName,
          isCreator ? 'partner_name' : 'your_name': _partnerName,
          isCreator ? 'your_gender' : 'partner_gender': _yourGender,
          isCreator ? 'partner_gender' : 'your_gender': _partnerGender,
          isCreator ? 'your_phone' : 'partner_phone': _yourPhone,
          isCreator ? 'partner_phone' : 'your_phone': _partnerPhone,
          isCreator ? 'your_birthdate' : 'partner_birthdate': _yourBirthdate
              ?.toIso8601String(),
          isCreator ? 'partner_birthdate' : 'your_birthdate': _partnerBirthdate
              ?.toIso8601String(),
          isCreator ? 'your_address' : 'partner_address': _yourAddress,
          isCreator ? 'partner_address' : 'your_address': _partnerAddress,
          isCreator ? 'your_nationality' : 'partner_nationality':
              _yourNationality,
          isCreator ? 'partner_nationality' : 'your_nationality':
              _partnerNationality,
          isCreator ? 'your_weight' : 'partner_weight': _yourWeight,
          isCreator ? 'partner_weight' : 'your_weight': _partnerWeight,
          isCreator ? 'your_height' : 'partner_height': _yourHeight,
          isCreator ? 'partner_height' : 'your_height': _partnerHeight,
          isCreator ? 'your_blood_type' : 'partner_blood_type': _yourBloodType,
          isCreator ? 'partner_blood_type' : 'your_blood_type':
              _partnerBloodType,
          isCreator ? 'your_eye_color' : 'partner_eye_color': _yourEyeColor,
          isCreator ? 'partner_eye_color' : 'your_eye_color': _partnerEyeColor,
          isCreator ? 'your_conditions' : 'partner_conditions': _yourConditions,
          isCreator ? 'partner_conditions' : 'your_conditions':
              _partnerConditions,
          isCreator ? 'your_date_issued' : 'partner_date_issued':
              _yourDateIssued?.toIso8601String(),
          isCreator ? 'partner_date_issued' : 'your_date_issued':
              _partnerDateIssued?.toIso8601String(),
          isCreator ? 'your_signature' : 'partner_signature': _yourSignature,
          isCreator ? 'partner_signature' : 'your_signature': _partnerSignature,
          isCreator ? 'your_avatar_path' : 'partner_avatar_path':
              _yourAvatarPath,
          isCreator ? 'partner_avatar_path' : 'your_avatar_path':
              _partnerAvatarPath,
        };
        await Supabase.instance.client
            .from('license_details')
            .upsert(updateData);
      } catch (e) {
        debugPrint('Supabase updateLicense failed: $e');
      }
    }
    notifyListeners();
  }

  Future<void> setAvatars({String? yourPath, String? partnerPath}) async {
    final prefs = await SharedPreferences.getInstance();

    if (isFirebaseAvailable && _coupleId != null) {
      if (yourPath != null) {
        if (!yourPath.startsWith('http') && yourPath.isNotEmpty) {
          try {
            final file = File(yourPath);
            if (await file.exists()) {
              final storagePath =
                  'couples/$_coupleId/avatars/${_userId ?? 'user'}.jpg';
              await Supabase.instance.client.storage
                  .from('avatars')
                  .upload(
                    storagePath,
                    file,
                    fileOptions: const FileOptions(upsert: true),
                  );
              final yourUrl = Supabase.instance.client.storage
                  .from('avatars')
                  .getPublicUrl(storagePath);
              _yourAvatarPath = yourUrl;
              await prefs.setString('your_avatar_path', yourUrl);
            }
          } catch (e) {
            debugPrint('Failed to upload your avatar: $e');
            _yourAvatarPath = yourPath;
            await prefs.setString('your_avatar_path', yourPath);
          }
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
        if (!partnerPath.startsWith('http') && partnerPath.isNotEmpty) {
          try {
            final file = File(partnerPath);
            if (await file.exists()) {
              final storagePath =
                  'couples/$_coupleId/avatars/${_partnerId ?? 'partner'}.jpg';
              await Supabase.instance.client.storage
                  .from('avatars')
                  .upload(
                    storagePath,
                    file,
                    fileOptions: const FileOptions(upsert: true),
                  );
              final partnerUrl = Supabase.instance.client.storage
                  .from('avatars')
                  .getPublicUrl(storagePath);
              _partnerAvatarPath = partnerUrl;
              await prefs.setString('partner_avatar_path', partnerUrl);
            }
          } catch (e) {
            debugPrint('Failed to upload partner avatar: $e');
            _partnerAvatarPath = partnerPath;
            await prefs.setString('partner_avatar_path', partnerPath);
          }
        } else {
          _partnerAvatarPath = partnerPath;
          if (partnerPath.isEmpty) {
            await prefs.remove('partner_avatar_path');
          } else {
            await prefs.setString('partner_avatar_path', partnerPath);
          }
        }
      }

      try {
        final snap = await Supabase.instance.client
            .from('license_details')
            .select()
            .eq('couple_id', _coupleId!)
            .maybeSingle();
        final creatorId = snap != null ? snap['creator_id'] : _userId;
        final isCreator = creatorId == _userId;

        final Map<String, dynamic> updateData = {
          'couple_id': _coupleId!,
          'creator_id': creatorId,
        };

        if (yourPath != null) {
          updateData[isCreator ? 'your_avatar_path' : 'partner_avatar_path'] =
              _yourAvatarPath;
        }
        if (partnerPath != null) {
          updateData[isCreator ? 'partner_avatar_path' : 'your_avatar_path'] =
              _partnerAvatarPath;
        }

        await Supabase.instance.client
            .from('license_details')
            .upsert(updateData);
      } catch (e) {
        debugPrint('Supabase setAvatars update failed: $e');
      }
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
  }

  String generateCoupleCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    _coupleCode = String.fromCharCodes(
      Iterable.generate(
        6,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );

    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('couple_code', _coupleCode!);
    });

    if (isFirebaseAvailable && _userId != null) {
      Supabase.instance.client
          .from('pairing_codes')
          .upsert({
            'code': _coupleCode,
            'creator_id': _userId,
            'created_at': DateTime.now().toIso8601String(),
          })
          .then((_) {});
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
    return _coupleCode!;
  }

  Future<bool> joinWithCode(String code) async {
    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.length != 6) return false;

    _coupleCode = cleanCode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('couple_code', cleanCode);

    if (isFirebaseAvailable && _userId != null) {
      try {
        final data = await Supabase.instance.client
            .from('pairing_codes')
            .select()
            .eq('code', cleanCode)
            .maybeSingle();
        if (data == null) {
          return false;
        }
        final creatorId = data['creator_id'] as String;
        final newCoupleId = const Uuid().v4();

        await Supabase.instance.client.from('couples').insert({
          'id': newCoupleId,
          'story_title': _storyTitle ?? 'Our Story',
        });

        await Supabase.instance.client
            .from('users')
            .update({'couple_id': newCoupleId, 'partner_id': _userId})
            .eq('id', creatorId);

        await Supabase.instance.client
            .from('users')
            .update({'couple_id': newCoupleId, 'partner_id': creatorId})
            .eq('id', _userId!);

        await Supabase.instance.client
            .from('pairing_codes')
            .delete()
            .eq('code', cleanCode);

        _coupleId = newCoupleId;
        _isPaired = true;
        await prefs.setBool('is_paired', true);
        notifyListeners();
        return true;
      } catch (e) {
        debugPrint('Supabase joinWithCode failed: $e');
        rethrow;
      }
    }

    // Offline fallback validation (only if DB is unavailable)
    _isPaired = true;
    await prefs.setBool('is_paired', true);
    notifyListeners();
    return true;
  }

  Future<void> completeOnboarding() async {
    _isPaired = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_paired', true);

    if (isFirebaseAvailable && _userId != null && _yourName != null) {
      try {
        await Supabase.instance.client
            .from('users')
            .update({'display_name': _yourName})
            .eq('id', _userId!);
      } catch (_) {}
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

  Future<void> unlinkPartner() async {
    _isPaired = false;
    _coupleCode = null;
    _partnerName = null;
    _partnerAvatarPath = null;
    _partnerJoinDate = null;
    _isPartnerOnline = false;
    _presenceChannel?.unsubscribe();
    _presenceChannel = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_paired', false);
    await prefs.remove('couple_code');
    await prefs.remove('partner_name');
    await prefs.remove('partner_avatar_path');
    await prefs.remove('partner_join_date');

    if (isFirebaseAvailable && _userId != null) {
      Supabase.instance.client
          .from('users')
          .update({'couple_id': null, 'partner_id': null})
          .eq('id', _userId!)
          .then((_) {});
    }

    notifyListeners();
  }

  Future<void> signUpWithEmail(String email, String password) async {
    await Supabase.instance.client.auth.signUp(
      email: email,
      password: password,
    );
  }

  Future<void> signInWithEmail(String email, String password) async {
    await Supabase.instance.client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signInWithGoogle() async {
    // TODO: Paste your Web Client ID from the Google Cloud Console Credentials page (required for Android):
    // https://console.cloud.google.com/apis/credentials
    const webClientId = String.fromEnvironment(
      'GOOGLE_CLIENT_ID_WEB',
      defaultValue: '1043515146762-s4pm3ed9r5aqface2457jafleen4q1tg.apps.googleusercontent.com',
    );

    // TODO: Paste your iOS Client ID from the Google Cloud Console Credentials page (required for iOS):
    const iosClientId = String.fromEnvironment(
      'GOOGLE_CLIENT_ID_IOS',
      defaultValue: 'YOUR_IOS_CLIENT_ID',
    );

    final googleSignIn = GoogleSignIn(
      serverClientId: webClientId == 'YOUR_WEB_CLIENT_ID' ? null : webClientId,
      clientId: iosClientId == 'YOUR_IOS_CLIENT_ID' ? null : iosClientId,
    );
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

    await Supabase.instance.client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
  }

  Future<void> logout() async {
    _startDate = null;
    _startTime = null;
    _partnerName = null;
    _yourName = null;
    _yourAvatarPath = null;
    _partnerAvatarPath = null;
    _coupleCode = null;
    _isPaired = false;
    _isPremium = false;
    _storyTitle = null;
    _yourGender = null;
    _partnerGender = null;
    _yourPhone = null;
    _partnerPhone = null;
    _yourBirthdate = null;
    _partnerBirthdate = null;
    _yourAddress = null;
    _partnerAddress = null;
    _yourNationality = null;
    _partnerNationality = null;
    _yourWeight = null;
    _partnerWeight = null;
    _yourHeight = null;
    _partnerHeight = null;
    _yourBloodType = null;
    _partnerBloodType = null;
    _yourEyeColor = null;
    _partnerEyeColor = null;
    _yourConditions = null;
    _partnerConditions = null;
    _yourDateIssued = null;
    _partnerDateIssued = null;
    _yourSignature = null;
    _partnerSignature = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    _userSub?.cancel();
    _coupleSub?.cancel();
    _licenseSub?.cancel();
    _presenceChannel?.unsubscribe();
    _presenceChannel = null;
    _isPartnerOnline = false;
    _yourJoinDate = null;
    _partnerJoinDate = null;

    if (isFirebaseAvailable) {
      await Supabase.instance.client.auth.signOut();
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

  int get totalDays => relationshipDuration.inDays;
  int get totalHours => relationshipDuration.inHours;
  int get totalMinutes => relationshipDuration.inMinutes;
  int get totalSeconds => relationshipDuration.inSeconds;

  Map<String, int> get preciseAge {
    final start = startDateTime;
    final now = DateTime.now();

    int years = now.year - start.year;
    int months = now.month - start.month;
    int days = now.day - start.day;
    int hours = now.hour - start.hour;
    int minutes = now.minute - start.minute;
    int seconds = now.second - start.second;

    if (seconds < 0) {
      minutes--;
      seconds += 60;
    }
    if (minutes < 0) {
      hours--;
      minutes += 60;
    }
    if (hours < 0) {
      days--;
      hours += 24;
    }
    if (days < 0) {
      months--;
      final previousMonth = DateTime(now.year, now.month, 0);
      days += previousMonth.day;
    }
    if (months < 0) {
      years--;
      months += 12;
    }

    return {
      'years': years,
      'months': months,
      'days': days,
      'hours': hours,
      'minutes': minutes,
      'seconds': seconds,
    };
  }

  int get totalMonths {
    if (_startDate == null) return 0;
    final now = DateTime.now();
    return (now.year - _startDate!.year) * 12 + now.month - _startDate!.month;
  }

  String get relationshipAge {
    final age = preciseAge;
    final parts = <String>[];
    if (age['years']! > 0)
      parts.add("${age['years']} Year${age['years']! > 1 ? 's' : ''}");
    if (age['months']! > 0)
      parts.add("${age['months']} Month${age['months']! > 1 ? 's' : ''}");
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
      final anniversaryDate = DateTime(
        _startDate!.year + nextYear,
        _startDate!.month,
        _startDate!.day,
      );
      final daysUntil = anniversaryDate.difference(DateTime.now()).inDays;
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
