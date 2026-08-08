import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:days_together/models/daily_mood_model.dart';
import 'package:days_together/providers/relationship_provider.dart';
import 'package:days_together/services/notification_service.dart';
import 'package:days_together/services/recent_activity_service.dart';
import 'package:days_together/services/realtime_subscription_manager.dart';

import 'package:days_together/services/relationship_lifecycle_manager.dart';

class DailyMoodProvider extends SupabaseLifecycleProvider {
  static const String _moodKey = 'daily_moods';
  static const String _questionKey = 'daily_sync_questions';

  List<DailyMood> _moods = [];
  List<DailyMood> _partnerMoods = [];
  DailySyncQuestion? _todayQuestion;
  bool _isLoading = true;

  String? _partnerId;
  StreamSubscription? _moodsSub;
  StreamSubscription? _questionSub;

  List<DailyMood> get moods => List.unmodifiable(_moods);
  List<DailyMood> get partnerMoods => List.unmodifiable(_partnerMoods);
  DailySyncQuestion? get todayQuestion => _todayQuestion;
  bool get isLoading => _isLoading;
  bool get hasLoggedToday => _moods.any((m) => m.date == _todayString);

  DailyMood? get todayMood {
    try {
      return _moods.firstWhere((m) => m.date == _todayString);
    } catch (_) {
      return null;
    }
  }

  DailyMood? get partnerTodayMood {
    try {
      return _partnerMoods.firstWhere((m) => m.date == _todayString);
    } catch (_) {
      return null;
    }
  }

  List<DailyMood> get recentMoods {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final cutoffStr = DateFormat('yyyy-MM-dd').format(cutoff);
    return _moods.where((m) => m.date.compareTo(cutoffStr) >= 0).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  List<DailyMood> get partnerRecentMoods {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final cutoffStr = DateFormat('yyyy-MM-dd').format(cutoff);
    return _partnerMoods.where((m) => m.date.compareTo(cutoffStr) >= 0).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  String get _todayString => DateFormat('yyyy-MM-dd').format(DateTime.now());

  static const List<String> _defaultQuestions = [
    'What made you smile about your partner today?',
    'What\'s one thing you appreciate about your partner?',
    'If you could relive one moment together, what would it be?',
    'What\'s a small thing your partner does that makes you happy?',
    'What are you most looking forward to doing together?',
    'What song reminds you of your partner?',
    'What\'s the funniest thing your partner has ever done?',
    'What\'s the best advice your partner has given you?',
    'What\'s one thing you want to tell your partner right now?',
    'What does "home" feel like with your partner?',
  ];

  @override
  String get tableName => 'moods';

  DailyMoodProvider() : super() {
    _loadData();
  }

  @override
  void updateRelationship(RelationshipProvider relationship) {
    _partnerId = relationship.partnerId;
    super.updateRelationship(relationship);
  }

  @override
  Future<void> purgeCache() async {
    _moods = [];
    _partnerMoods = [];
    _todayQuestion = _generateTodayQuestion();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_moodKey);
      await prefs.remove(_partnerMoodKey);
      await prefs.remove(_questionKey);
    } catch (_) {}
    if (!isDisposed) notifyListeners();
  }

  @override
  Future<void> syncInitialData() async {
    if (coupleId == null) return;
    try {
      // 1. Fetch moods
      final List<dynamic> moodsRes = await Supabase.instance.client
          .from('moods')
          .select()
          .eq('couple_id', coupleId!);
      final List<DailyMood> incomingMyMoods = [];
      final List<DailyMood> incomingPartnerMoods = [];
      for (final data in moodsRes) {
        final m = DailyMood(
          id: data['id'] as String?,
          userId: data['user_id'] as String?,
          date: data['date'] as String? ?? '',
          moodScore: data['mood_score'] as int? ?? 5,
          note: data['note'] as String?,
        );
        if (m.userId == userId) {
          incomingMyMoods.add(m);
        } else {
          incomingPartnerMoods.add(m);
        }
      }
      _moods = incomingMyMoods;
      _partnerMoods = incomingPartnerMoods;
      await _persistLocalMoodsOnly();

      // 2. Fetch daily sync question
      final qRes = await Supabase.instance.client
          .from('daily_questions')
          .select()
          .eq('couple_id', coupleId!)
          .eq('date', _todayString)
          .maybeSingle();

      if (qRes != null) {
        final questionText = qRes['question'] as String? ?? '';
        final answers = Map<String, dynamic>.from(qRes['answers'] ?? {});
        final myAnswer = answers[userId];
        final partnerKey =
            _partnerId ??
            answers.keys.firstWhere(
              (k) => k != userId,
              orElse: () => 'partner_simulator',
            );
        final partnerAnswer = answers[partnerKey];

        _todayQuestion = DailySyncQuestion(
          question: questionText,
          myAnswer: myAnswer as String?,
          partnerAnswer: partnerAnswer as String?,
          date: _todayString,
        );
      } else {
        _todayQuestion = _generateTodayQuestion();
      }
      await _persistLocalQuestionOnly();
      if (!isDisposed) notifyListeners();
    } catch (e) {
      debugPrint('DailyMoodProvider.syncInitialData error: $e');
    }
  }

  @override
  void initRealtime() {
    if (coupleId == null || userId == null) return;
    if (_moodsSub != null && _questionSub != null) return;
    _isLoading = true;
    if (!isDisposed) notifyListeners();

    // Backup safety timeout to prevent infinite spinner
    Future.delayed(const Duration(seconds: 5), () {
      if (_isLoading && !isDisposed) {
        _isLoading = false;
        notifyListeners();
      }
    });

    _moodsSub?.cancel();
    _moodsSub = RealtimeSubscriptionManager.instance
        .getStream(tableName: 'moods', coupleId: coupleId!)
        .listen(
          (dataList) {
            final allMoods = dataList.map((data) {
              return DailyMood(
                id: data['id'] as String,
                userId: data['user_id'] as String?,
                date: data['date'] ?? '',
                moodScore: data['mood_score'] ?? 5,
                note: data['note'] as String?,
                createdAt: data['created_at'] != null
                    ? DateTime.parse(data['created_at'] as String)
                    : DateTime.now(),
              );
            }).toList();

            final incomingPartnerMoods = allMoods
                .where((m) => m.userId != userId)
                .toList();

            if (!_isLoading) {
              for (var mood in incomingPartnerMoods) {
                final match = _partnerMoods.firstWhere(
                  (old) => old.id == mood.id,
                  orElse: () => DailyMood(id: '', date: '', moodScore: 5),
                );
                if (match.id.isEmpty) {
                  RecentActivityService.instance.logActivity(
                    activityType: 'created',
                    title:
                        'Partner logged a mood ${_getMoodEmoji(mood.moodScore)}',
                    description: mood.note != null && mood.note!.isNotEmpty
                        ? 'Feeling: "${mood.note}"'
                        : 'Feeling changed',
                    icon: _getMoodEmoji(mood.moodScore),
                    referenceId: mood.id,
                    route: 'mood',
                  );
                } else if (match.moodScore != mood.moodScore ||
                    match.note != mood.note) {
                  RecentActivityService.instance.logActivity(
                    activityType: 'updated',
                    title:
                        'Partner updated their mood ${_getMoodEmoji(mood.moodScore)}',
                    description: mood.note != null && mood.note!.isNotEmpty
                        ? 'Feeling: "${mood.note}"'
                        : 'Feeling changed',
                    icon: _getMoodEmoji(mood.moodScore),
                    referenceId: mood.id,
                    route: 'mood',
                  );
                }
              }
            }

            _moods = allMoods.where((m) => m.userId == userId).toList();
            _partnerMoods = incomingPartnerMoods;

            _isLoading = false;
            if (!isDisposed) notifyListeners();
            _persistLocalMoodsOnly();
          },
          onError: (err) {
            debugPrint('DailyMoodProvider: moods Supabase error: $err');
            _loadLocalMoods();
            _loadLocalPartnerMoods();
          },
        );

    _questionSub?.cancel();
    _questionSub = RealtimeSubscriptionManager.instance
        .getStream(
          tableName: 'daily_questions',
          coupleId: coupleId!,
          primaryKey: ['date', 'couple_id'],
        )
        .listen(
          (dataList) {
            final todayData = dataList.where((d) => d['date'] == _todayString);
            if (todayData.isNotEmpty) {
              final data = todayData.first;
              final questionText = data['question'] as String? ?? '';
              final answers = Map<String, dynamic>.from(data['answers'] ?? {});

              final myAnswer = answers[userId];
              final partnerKey =
                  _partnerId ??
                  answers.keys.firstWhere(
                    (k) => k != userId,
                    orElse: () => 'partner_simulator',
                  );
              final partnerAnswer = answers[partnerKey];

              if (!_isLoading &&
                  partnerAnswer != null &&
                  (_todayQuestion == null ||
                      _todayQuestion!.partnerAnswer == null)) {
                RecentActivityService.instance.logActivity(
                  activityType: 'completed',
                  title: "Partner answered today's question ❓",
                  description: 'Answered: "$questionText"',
                  icon: '❓',
                  referenceId: _todayString,
                  route: 'mood',
                );
              }

              _todayQuestion = DailySyncQuestion(
                question: questionText,
                myAnswer: myAnswer as String?,
                partnerAnswer: partnerAnswer as String?,
                date: _todayString,
              );
            } else {
              _todayQuestion = _generateTodayQuestion();
            }
            if (!isDisposed) notifyListeners();
            _persistLocalQuestionOnly();
          },
          onError: (err) {
            debugPrint('DailyMoodProvider: question Supabase error: $err');
            _loadLocalQuestion();
          },
        );
  }

  @override
  void disposeRealtime() {
    _moodsSub?.cancel();
    _questionSub?.cancel();
    _moodsSub = null;
    _questionSub = null;
    super.disposeRealtime();
  }

  @override
  void onRealtimeData(List<Map<String, dynamic>> dataList) {
    // Handled by overriding initRealtime due to multiple tables
  }

  static const String _partnerMoodKey = 'partner_daily_moods';

  Future<void> _loadData() async {
    _isLoading = true;
    if (!isDisposed) notifyListeners();
    await _loadLocalMoods();
    await _loadLocalPartnerMoods();
    await _loadLocalQuestion();
    _isLoading = false;
    if (!isDisposed) notifyListeners();
  }

  Future<void> _loadLocalMoods() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final moodJson = prefs.getString(_moodKey);
      if (moodJson != null) {
        final jsonList = jsonDecode(moodJson) as List;
        _moods = jsonList.map((j) => DailyMood.fromJson(j)).toList();
      } else {
        _moods = [];
      }
    } catch (e) {
      debugPrint('DailyMoodProvider._loadLocalMoods failed: $e');
    }
  }

  Future<void> _loadLocalPartnerMoods() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final moodJson = prefs.getString(_partnerMoodKey);
      if (moodJson != null) {
        final jsonList = jsonDecode(moodJson) as List;
        _partnerMoods = jsonList.map((j) => DailyMood.fromJson(j)).toList();
      } else {
        _partnerMoods = [];
      }
    } catch (e) {
      debugPrint('DailyMoodProvider._loadLocalPartnerMoods failed: $e');
    }
  }

  Future<void> _loadLocalQuestion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final qJson = prefs.getString(_questionKey);
      if (qJson != null) {
        _todayQuestion = DailySyncQuestion.fromJson(jsonDecode(qJson));
        if (_todayQuestion!.date != _todayString) {
          _todayQuestion = _generateTodayQuestion();
          await _persistQuestion();
        }
      } else {
        _todayQuestion = _generateTodayQuestion();
        await _persistQuestion();
      }
    } catch (e) {
      debugPrint('DailyMoodProvider._loadLocalQuestion failed: $e');
    }
  }

  DailySyncQuestion _generateTodayQuestion() {
    final dayOfYear = DateTime.now()
        .difference(DateTime(DateTime.now().year))
        .inDays;
    final questionIndex = dayOfYear % _defaultQuestions.length;
    return DailySyncQuestion(
      question: _defaultQuestions[questionIndex],
      date: _todayString,
    );
  }

  Future<void> logMood(int score, {String? note}) async {
    final nextMood = DailyMood(
      userId: userId,
      date: _todayString,
      moodScore: score,
      note: note,
    );

    if (coupleId != null && userId != null) {
      try {
        final moodId = '${userId}_$_todayString';
        await Supabase.instance.client.from('moods').upsert({
          'id': moodId,
          'couple_id': coupleId,
          'user_id': userId,
          'date': _todayString,
          'mood_score': score,
          'note': note,
          'created_at': DateTime.now().toIso8601String(),
        });

        // Trigger push notification to partner
        try {
          await NotificationService().sendPartnerNotification(
            title: 'Mood Shared 💖',
            body: 'Your partner shared their mood today.',
            feature: 'love_meter',
          );
        } catch (fcmError) {
          debugPrint(
            'DailyMoodProvider: Failed to trigger push notification: $fcmError',
          );
        }
      } catch (e) {
        debugPrint('DailyMoodProvider.logMood Supabase error: $e');
        _logLocalMood(nextMood);
      }
    } else {
      _logLocalMood(nextMood);
    }

    await RecentActivityService.instance.logActivity(
      activityType: 'updated',
      title: "Today's mood updated",
      description: "Shared today's mood score: $score/10",
      icon: '❤️',
      route: 'love_meter',
    );
  }

  void _logLocalMood(DailyMood mood) {
    _moods.removeWhere((m) => m.date == _todayString);
    _moods.add(mood);
    _persistMoods();
  }

  Future<void> answerDailyQuestion(String answer) async {
    if (coupleId != null && userId != null) {
      try {
        final response = await Supabase.instance.client
            .from('daily_questions')
            .select('answers')
            .eq('couple_id', coupleId!)
            .eq('date', _todayString)
            .maybeSingle();

        final Map<String, dynamic> answers = {};
        if (response != null && response['answers'] != null) {
          answers.addAll(Map<String, dynamic>.from(response['answers']));
        }
        answers[userId!] = answer;

        await Supabase.instance.client.from('daily_questions').upsert({
          'couple_id': coupleId,
          'date': _todayString,
          'question':
              _todayQuestion?.question ?? _generateTodayQuestion().question,
          'answers': answers,
        });

        // Trigger push notification to partner
        try {
          final partnerJoined = _partnerId != null;
          final partnerAnswered =
              response != null &&
              response['answers'] != null &&
              partnerJoined &&
              Map<String, dynamic>.from(
                response['answers'],
              ).containsKey(_partnerId);

          if (partnerAnswered) {
            await NotificationService().sendPartnerNotification(
              title: 'Connection Prompt Completed 💬',
              body: 'Both of you have completed today\'s connection prompt!',
              feature: 'daily_prompt',
            );
          } else {
            await NotificationService().sendPartnerNotification(
              title: 'Connection Prompt Answered 💬',
              body: 'Your partner answered today\'s connection prompt.',
              feature: 'daily_prompt',
            );
          }
        } catch (fcmError) {
          debugPrint(
            'DailyMoodProvider: Failed to trigger push notification: $fcmError',
          );
        }
      } catch (e) {
        debugPrint('DailyMoodProvider.answerDailyQuestion Supabase error: $e');
        _answerLocal(answer);
      }
    } else {
      _answerLocal(answer);
    }

    await RecentActivityService.instance.logActivity(
      activityType: 'updated',
      title: "Connection prompt answered",
      description: "Answered today's sync question",
      icon: '❤️',
      route: 'love_meter',
    );
  }

  void _answerLocal(String answer) {
    if (_todayQuestion == null) return;
    _todayQuestion = DailySyncQuestion(
      question: _todayQuestion!.question,
      myAnswer: answer,
      partnerAnswer: _todayQuestion!.partnerAnswer,
      date: _todayQuestion!.date,
    );
    _persistQuestion();
  }

  Future<void> _persistMoods() async {
    await _persistLocalMoodsOnly();
    if (!isDisposed) notifyListeners();
  }

  Future<void> _persistQuestion() async {
    await _persistLocalQuestionOnly();
    if (!isDisposed) notifyListeners();
  }

  Future<void> _persistLocalMoodsOnly() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _moods.map((m) => m.toJson()).toList();
      await prefs.setString(_moodKey, jsonEncode(jsonList));

      final partnerJsonList = _partnerMoods.map((m) => m.toJson()).toList();
      await prefs.setString(_partnerMoodKey, jsonEncode(partnerJsonList));
    } catch (e, st) {
      debugPrint('DailyMoodProvider._persistLocalMoodsOnly failed: $e\n$st');
    }
  }

  Future<void> _persistLocalQuestionOnly() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_todayQuestion != null) {
        await prefs.setString(
          _questionKey,
          jsonEncode(_todayQuestion!.toJson()),
        );
      }
    } catch (e, st) {
      debugPrint('DailyMoodProvider._persistLocalQuestionOnly failed: $e\n$st');
    }
  }

  String _getMoodEmoji(int score) {
    switch (score) {
      case 1:
        return '😭';
      case 2:
        return '😢';
      case 3:
        return '😐';
      case 4:
        return '😊';
      case 5:
        return '😍';
      default:
        return '😊';
    }
  }
}
