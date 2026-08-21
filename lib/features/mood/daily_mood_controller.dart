import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:days_together/core/riverpod/supabase_lifecycle_notifier.dart';
import 'package:days_together/features/mood/daily_mood_state.dart';
import 'package:days_together/models/daily_mood_model.dart';
import 'package:days_together/providers/couple_session.dart';
import 'package:days_together/services/notification_service.dart';
import 'package:days_together/services/realtime_subscription_manager.dart';
import 'package:days_together/services/recent_activity_service.dart';

/// Riverpod port of `DailyMoodProvider` (Phase 6a of the architecture
/// migration). The second of the two providers (with `TopicCardsController`)
/// that bypass `SupabaseLifecycleNotifier`'s single-table default: overrides
/// [initRealtime]/[disposeRealtime] directly to run two independent
/// `RealtimeSubscriptionManager` subscriptions (`moods`, `daily_questions`
/// -- the latter with a non-default composite `primaryKey: ['date',
/// 'couple_id']`), exactly as the original did. [onRealtimeData] stays a
/// no-op, matching the original's own "Handled by overriding initRealtime
/// due to multiple tables" comment.
class DailyMoodController extends Notifier<DailyMoodState> with SupabaseLifecycleNotifier<DailyMoodState> {
  static const String _moodKey = 'daily_moods';
  static const String _partnerMoodKey = 'partner_daily_moods';
  static const String _questionKey = 'daily_sync_questions';

  static const List<String> _defaultQuestions = [
    'What made you smile about your partner today?',
    "What's one thing you appreciate about your partner?",
    'If you could relive one moment together, what would it be?',
    "What's a small thing your partner does that makes you happy?",
    'What are you most looking forward to doing together?',
    'What song reminds you of your partner?',
    "What's the funniest thing your partner has ever done?",
    "What's the best advice your partner has given you?",
    "What's one thing you want to tell your partner right now?",
    'What does "home" feel like with your partner?',
  ];

  String? _partnerId;
  StreamSubscription? _moodsSub;
  StreamSubscription? _questionSub;

  @override
  String get tableName => 'moods';

  @override
  DailyMoodState build() {
    initSessionLifecycle();
    ref.onDispose(() {
      _moodsSub?.cancel();
      _questionSub?.cancel();
    });
    _loadData();
    return const DailyMoodState();
  }

  @override
  Future<void> updateSession(CoupleSession session) async {
    _partnerId = session.partnerId;
    await super.updateSession(session);
  }

  @override
  Future<void> purgeCache() async {
    state = DailyMoodState(todayQuestion: _generateTodayQuestion(), isLoading: false);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_moodKey);
      await prefs.remove(_partnerMoodKey);
      await prefs.remove(_questionKey);
    } catch (_) {}
  }

  @override
  Future<void> syncInitialData() async {
    if (coupleId == null) return;
    try {
      final List<dynamic> moodsRes = await Supabase.instance.client.from('moods').select().eq('couple_id', coupleId!);
      final incomingMyMoods = <DailyMood>[];
      final incomingPartnerMoods = <DailyMood>[];
      for (final data in moodsRes) {
        final m = DailyMood(
          id: data['id'] as String?,
          userId: data['user_id'] as String?,
          date: data['date'] as String? ?? '',
          moodScore: data['mood_score'] as int? ?? 5,
          note: data['note'] as String?,
        );
        if (m.userId == sessionUserId) {
          incomingMyMoods.add(m);
        } else {
          incomingPartnerMoods.add(m);
        }
      }

      final qRes = await Supabase.instance.client
          .from('daily_questions')
          .select()
          .eq('couple_id', coupleId!)
          .eq('date', DailyMoodState.todayString)
          .maybeSingle();

      DailySyncQuestion todayQuestion;
      if (qRes != null) {
        final questionText = qRes['question'] as String? ?? '';
        final answers = Map<String, dynamic>.from(qRes['answers'] ?? {});
        final myAnswer = answers[sessionUserId];
        final partnerKey = _partnerId ?? answers.keys.firstWhere((k) => k != sessionUserId, orElse: () => 'partner_simulator');
        final partnerAnswer = answers[partnerKey];
        todayQuestion = DailySyncQuestion(
          question: questionText,
          myAnswer: myAnswer as String?,
          partnerAnswer: partnerAnswer as String?,
          date: DailyMoodState.todayString,
        );
      } else {
        todayQuestion = _generateTodayQuestion();
      }

      if (!ref.mounted) return;
      state = state.copyWith(moods: incomingMyMoods, partnerMoods: incomingPartnerMoods, todayQuestion: todayQuestion);
      await _persistLocalMoodsOnly();
      await _persistLocalQuestionOnly();
    } catch (e) {
      debugPrint('DailyMoodController.syncInitialData error: $e');
    }
  }

  @override
  void initRealtime() {
    if (coupleId == null || sessionUserId == null) return;
    if (_moodsSub != null && _questionSub != null) return;
    state = state.copyWith(isLoading: true);

    Future.delayed(const Duration(seconds: 5), () {
      if (!ref.mounted) return;
      if (state.isLoading) {
        state = state.copyWith(isLoading: false);
      }
    });

    _moodsSub?.cancel();
    _moodsSub = RealtimeSubscriptionManager.instance.getStream(tableName: 'moods', coupleId: coupleId!).listen(
      (dataList) {
        if (!ref.mounted) return;
        final allMoods = dataList.map((data) {
          return DailyMood(
            id: data['id'] as String,
            userId: data['user_id'] as String?,
            date: data['date'] ?? '',
            moodScore: data['mood_score'] ?? 5,
            note: data['note'] as String?,
            createdAt: data['created_at'] != null ? DateTime.parse(data['created_at'] as String) : DateTime.now(),
          );
        }).toList();

        final incomingPartnerMoods = allMoods.where((m) => m.userId != sessionUserId).toList();

        if (!state.isLoading) {
          for (final mood in incomingPartnerMoods) {
            final match = state.partnerMoods.where((old) => old.id == mood.id).isEmpty
                ? null
                : state.partnerMoods.firstWhere((old) => old.id == mood.id);
            if (match == null) {
              RecentActivityService.instance.logActivity(
                activityType: 'created',
                title: 'Partner logged a mood ${_getMoodEmoji(mood.moodScore)}',
                description: mood.note != null && mood.note!.isNotEmpty ? 'Feeling: "${mood.note}"' : 'Feeling changed',
                icon: _getMoodEmoji(mood.moodScore),
                referenceId: mood.id,
                route: 'mood',
              );
            } else if (match.moodScore != mood.moodScore || match.note != mood.note) {
              RecentActivityService.instance.logActivity(
                activityType: 'updated',
                title: 'Partner updated their mood ${_getMoodEmoji(mood.moodScore)}',
                description: mood.note != null && mood.note!.isNotEmpty ? 'Feeling: "${mood.note}"' : 'Feeling changed',
                icon: _getMoodEmoji(mood.moodScore),
                referenceId: mood.id,
                route: 'mood',
              );
            }
          }
        }

        state = state.copyWith(
          moods: allMoods.where((m) => m.userId == sessionUserId).toList(),
          partnerMoods: incomingPartnerMoods,
          isLoading: false,
        );
        _persistLocalMoodsOnly();
      },
      onError: (err) {
        debugPrint('DailyMoodController: moods Supabase error: $err');
        _loadLocalMoods();
        _loadLocalPartnerMoods();
      },
    );

    _questionSub?.cancel();
    _questionSub = RealtimeSubscriptionManager.instance
        .getStream(tableName: 'daily_questions', coupleId: coupleId!, primaryKey: ['date', 'couple_id'])
        .listen(
      (dataList) {
        if (!ref.mounted) return;
        final todayData = dataList.where((d) => d['date'] == DailyMoodState.todayString);
        DailySyncQuestion nextQuestion;
        if (todayData.isNotEmpty) {
          final data = todayData.first;
          final questionText = data['question'] as String? ?? '';
          final answers = Map<String, dynamic>.from(data['answers'] ?? {});
          final myAnswer = answers[sessionUserId];
          final partnerKey =
              _partnerId ?? answers.keys.firstWhere((k) => k != sessionUserId, orElse: () => 'partner_simulator');
          final partnerAnswer = answers[partnerKey];

          if (!state.isLoading &&
              partnerAnswer != null &&
              (state.todayQuestion == null || state.todayQuestion!.partnerAnswer == null)) {
            RecentActivityService.instance.logActivity(
              activityType: 'completed',
              title: "Partner answered today's question ❓",
              description: 'Answered: "$questionText"',
              icon: '❓',
              referenceId: DailyMoodState.todayString,
              route: 'mood',
            );
          }

          nextQuestion = DailySyncQuestion(
            question: questionText,
            myAnswer: myAnswer as String?,
            partnerAnswer: partnerAnswer as String?,
            date: DailyMoodState.todayString,
          );
        } else {
          nextQuestion = _generateTodayQuestion();
        }
        state = state.copyWith(todayQuestion: nextQuestion);
        _persistLocalQuestionOnly();
      },
      onError: (err) {
        debugPrint('DailyMoodController: question Supabase error: $err');
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
  void onRealtimeData(List<Map<String, dynamic>> dataList) {}

  @override
  void onRealtimeError(Object error) {}

  Future<void> _loadData() async {
    await _loadLocalMoods();
    await _loadLocalPartnerMoods();
    await _loadLocalQuestion();
    if (!ref.mounted) return;
    state = state.copyWith(isLoading: false);
  }

  Future<void> _loadLocalMoods() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final moodJson = prefs.getString(_moodKey);
      final moods = moodJson != null
          ? (jsonDecode(moodJson) as List).map((j) => DailyMood.fromJson(j)).toList()
          : <DailyMood>[];
      if (!ref.mounted) return;
      state = state.copyWith(moods: moods);
    } catch (e) {
      debugPrint('DailyMoodController._loadLocalMoods failed: $e');
    }
  }

  Future<void> _loadLocalPartnerMoods() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final moodJson = prefs.getString(_partnerMoodKey);
      final moods = moodJson != null
          ? (jsonDecode(moodJson) as List).map((j) => DailyMood.fromJson(j)).toList()
          : <DailyMood>[];
      if (!ref.mounted) return;
      state = state.copyWith(partnerMoods: moods);
    } catch (e) {
      debugPrint('DailyMoodController._loadLocalPartnerMoods failed: $e');
    }
  }

  Future<void> _loadLocalQuestion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final qJson = prefs.getString(_questionKey);
      DailySyncQuestion question;
      if (qJson != null) {
        question = DailySyncQuestion.fromJson(jsonDecode(qJson));
        if (question.date != DailyMoodState.todayString) {
          question = _generateTodayQuestion();
        }
      } else {
        question = _generateTodayQuestion();
      }
      if (!ref.mounted) return;
      state = state.copyWith(todayQuestion: question);
      await _persistLocalQuestionOnly();
    } catch (e) {
      debugPrint('DailyMoodController._loadLocalQuestion failed: $e');
    }
  }

  DailySyncQuestion _generateTodayQuestion() {
    final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year)).inDays;
    final questionIndex = dayOfYear % _defaultQuestions.length;
    return DailySyncQuestion(question: _defaultQuestions[questionIndex], date: DailyMoodState.todayString);
  }

  Future<void> logMood(int score, {String? note}) async {
    final nextMood = DailyMood(userId: sessionUserId, date: DailyMoodState.todayString, moodScore: score, note: note);

    if (coupleId != null && sessionUserId != null) {
      try {
        final moodId = '${sessionUserId}_${DailyMoodState.todayString}';
        await Supabase.instance.client.from('moods').upsert({
          'id': moodId,
          'couple_id': coupleId,
          'user_id': sessionUserId,
          'date': DailyMoodState.todayString,
          'mood_score': score,
          'note': note,
          'created_at': DateTime.now().toIso8601String(),
        });
        try {
          await NotificationService().sendPartnerNotification(
            title: 'Mood Shared 💖',
            body: 'Your partner shared their mood today.',
            feature: 'love_meter',
          );
        } catch (fcmError) {
          debugPrint('DailyMoodController: Failed to trigger push notification: $fcmError');
        }
      } catch (e) {
        debugPrint('DailyMoodController.logMood Supabase error: $e');
        if (!ref.mounted) return;
        await _logLocalMood(nextMood);
      }
    } else {
      await _logLocalMood(nextMood);
    }

    if (!ref.mounted) return;
    await RecentActivityService.instance.logActivity(
      activityType: 'updated',
      title: "Today's mood updated",
      description: "Shared today's mood score: $score/10",
      icon: '❤️',
      route: 'love_meter',
    );
  }

  Future<void> _logLocalMood(DailyMood mood) async {
    final moods = state.moods.where((m) => m.date != DailyMoodState.todayString).toList()..add(mood);
    state = state.copyWith(moods: moods);
    await _persistLocalMoodsOnly();
  }

  Future<void> answerDailyQuestion(String answer) async {
    if (coupleId != null && sessionUserId != null) {
      try {
        final response = await Supabase.instance.client
            .from('daily_questions')
            .select('answers')
            .eq('couple_id', coupleId!)
            .eq('date', DailyMoodState.todayString)
            .maybeSingle();

        final Map<String, dynamic> answers = {};
        if (response != null && response['answers'] != null) {
          answers.addAll(Map<String, dynamic>.from(response['answers']));
        }
        answers[sessionUserId!] = answer;

        await Supabase.instance.client.from('daily_questions').upsert({
          'couple_id': coupleId,
          'date': DailyMoodState.todayString,
          'question': state.todayQuestion?.question ?? _generateTodayQuestion().question,
          'answers': answers,
        });

        try {
          final partnerJoined = _partnerId != null;
          final partnerAnswered = response != null &&
              response['answers'] != null &&
              partnerJoined &&
              Map<String, dynamic>.from(response['answers']).containsKey(_partnerId);

          if (partnerAnswered) {
            await NotificationService().sendPartnerNotification(
              title: 'Connection Prompt Completed 💬',
              body: "Both of you have completed today's connection prompt!",
              feature: 'daily_prompt',
            );
          } else {
            await NotificationService().sendPartnerNotification(
              title: 'Connection Prompt Answered 💬',
              body: "Your partner answered today's connection prompt.",
              feature: 'daily_prompt',
            );
          }
        } catch (fcmError) {
          debugPrint('DailyMoodController: Failed to trigger push notification: $fcmError');
        }
      } catch (e) {
        debugPrint('DailyMoodController.answerDailyQuestion Supabase error: $e');
        if (!ref.mounted) return;
        await _answerLocal(answer);
      }
    } else {
      await _answerLocal(answer);
    }

    if (!ref.mounted) return;
    await RecentActivityService.instance.logActivity(
      activityType: 'updated',
      title: 'Connection prompt answered',
      description: "Answered today's sync question",
      icon: '❤️',
      route: 'love_meter',
    );
  }

  Future<void> _answerLocal(String answer) async {
    final current = state.todayQuestion;
    if (current == null) return;
    state = state.copyWith(
      todayQuestion: DailySyncQuestion(
        question: current.question,
        myAnswer: answer,
        partnerAnswer: current.partnerAnswer,
        date: current.date,
      ),
    );
    await _persistLocalQuestionOnly();
  }

  Future<void> _persistLocalMoodsOnly() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = state.moods.map((m) => m.toJson()).toList();
      await prefs.setString(_moodKey, jsonEncode(jsonList));

      final partnerJsonList = state.partnerMoods.map((m) => m.toJson()).toList();
      await prefs.setString(_partnerMoodKey, jsonEncode(partnerJsonList));
    } catch (e, st) {
      debugPrint('DailyMoodController._persistLocalMoodsOnly failed: $e\n$st');
    }
  }

  Future<void> _persistLocalQuestionOnly() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (state.todayQuestion != null) {
        await prefs.setString(_questionKey, jsonEncode(state.todayQuestion!.toJson()));
      }
    } catch (e, st) {
      debugPrint('DailyMoodController._persistLocalQuestionOnly failed: $e\n$st');
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

final dailyMoodControllerProvider = NotifierProvider.autoDispose<DailyMoodController, DailyMoodState>(
  DailyMoodController.new,
  dependencies: [coupleSessionProvider],
);
