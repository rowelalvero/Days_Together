import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:days_together/models/daily_mood_model.dart';
import 'package:days_together/providers/relationship_provider.dart';

class DailyMoodProvider with ChangeNotifier {
  static const String _moodKey = 'daily_moods';
  static const String _questionKey = 'daily_sync_questions';

  List<DailyMood> _moods = [];
  DailySyncQuestion? _todayQuestion;
  bool _isLoading = true;
  bool _disposed = false;

  String? _coupleId;
  String? _userId;
  String? _partnerId;
  StreamSubscription? _moodsSub;
  StreamSubscription? _questionSub;

  List<DailyMood> get moods => List.unmodifiable(_moods);
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

  List<DailyMood> get recentMoods {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final cutoffStr = DateFormat('yyyy-MM-dd').format(cutoff);
    return _moods.where((m) => m.date.compareTo(cutoffStr) >= 0).toList()
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

  DailyMoodProvider() {
    _loadData();
  }

  void updateRelationship(RelationshipProvider relationship) {
    if (_coupleId != relationship.coupleId || _userId != relationship.userId || _partnerId != relationship.partnerId) {
      _coupleId = relationship.coupleId;
      _userId = relationship.userId;
      _partnerId = relationship.partnerId;

      _moodsSub?.cancel();
      _questionSub?.cancel();
      _moodsSub = null;
      _questionSub = null;

      if (_coupleId != null && _userId != null && relationship.isFirebaseAvailable) {
        if (hasListeners) {
          _initSupabaseSync();
        }
      } else {
        _loadData();
      }
    }
  }

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    if (hasListeners && _moodsSub == null && _questionSub == null && _coupleId != null && _userId != null) {
      _initSupabaseSync();
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners) {
      _moodsSub?.cancel();
      _questionSub?.cancel();
      _moodsSub = null;
      _questionSub = null;
    }
  }

  void _initSupabaseSync() {
    if (_coupleId == null || _userId == null) return;
    _isLoading = true;
    if (!_disposed) notifyListeners();

    _moodsSub = Supabase.instance.client
        .from('moods')
        .stream(primaryKey: ['id'])
        .eq('user_id', _userId!)
        .listen((dataList) {
      _moods = dataList.map((data) {
        return DailyMood(
          id: data['id'] as String,
          date: data['date'] ?? '',
          moodScore: data['mood_score'] ?? 5,
          note: data['note'] as String?,
          createdAt: data['created_at'] != null ? DateTime.parse(data['created_at'] as String) : DateTime.now(),
        );
      }).toList();
      _isLoading = false;
      if (!_disposed) notifyListeners();
      _persistLocalMoodsOnly();
    }, onError: (err) {
      debugPrint('DailyMoodProvider: moods Supabase error: $err');
      _loadLocalMoods();
    });

    _questionSub = Supabase.instance.client
        .from('daily_questions')
        .stream(primaryKey: ['date', 'couple_id'])
        .eq('couple_id', _coupleId!)
        .listen((dataList) {
      final todayData = dataList.where((d) => d['date'] == _todayString);
      if (todayData.isNotEmpty) {
        final data = todayData.first;
        final questionText = data['question'] as String? ?? '';
        final answers = Map<String, dynamic>.from(data['answers'] ?? {});
        
        final myAnswer = answers[_userId];
        final partnerKey = _partnerId ?? answers.keys.firstWhere((k) => k != _userId, orElse: () => 'partner_simulator');
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
      if (!_disposed) notifyListeners();
      _persistLocalQuestionOnly();
    }, onError: (err) {
      debugPrint('DailyMoodProvider: question Supabase error: $err');
      _loadLocalQuestion();
    });
  }

  Future<void> _loadData() async {
    _isLoading = true;
    if (!_disposed) notifyListeners();
    await _loadLocalMoods();
    await _loadLocalQuestion();
    _isLoading = false;
    if (!_disposed) notifyListeners();
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
    final dayOfYear = DateTime.now().difference(DateTime(DateTime.now().year)).inDays;
    final questionIndex = dayOfYear % _defaultQuestions.length;
    return DailySyncQuestion(
      question: _defaultQuestions[questionIndex],
      date: _todayString,
    );
  }

  Future<void> logMood(int score, {String? note}) async {
    final nextMood = DailyMood(date: _todayString, moodScore: score, note: note);

    if (_coupleId != null && _userId != null) {
      try {
        final moodId = '${_userId}_$_todayString';
        await Supabase.instance.client
            .from('moods')
            .upsert({
          'id': moodId,
          'couple_id': _coupleId,
          'user_id': _userId,
          'date': _todayString,
          'mood_score': score,
          'note': note,
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        debugPrint('DailyMoodProvider.logMood Supabase error: $e');
        _logLocalMood(nextMood);
      }
    } else {
      _logLocalMood(nextMood);
    }
  }

  void _logLocalMood(DailyMood mood) {
    _moods.removeWhere((m) => m.date == _todayString);
    _moods.add(mood);
    _persistMoods();
  }

  Future<void> answerDailyQuestion(String answer) async {
    if (_coupleId != null && _userId != null) {
      try {
        final response = await Supabase.instance.client
            .from('daily_questions')
            .select('answers')
            .eq('couple_id', _coupleId!)
            .eq('date', _todayString)
            .maybeSingle();

        final Map<String, dynamic> answers = {};
        if (response != null && response['answers'] != null) {
          answers.addAll(Map<String, dynamic>.from(response['answers']));
        }
        answers[_userId!] = answer;

        await Supabase.instance.client
            .from('daily_questions')
            .upsert({
          'couple_id': _coupleId,
          'date': _todayString,
          'question': _todayQuestion?.question ?? _generateTodayQuestion().question,
          'answers': answers,
        });
      } catch (e) {
        debugPrint('DailyMoodProvider.answerDailyQuestion Supabase error: $e');
        _answerLocal(answer);
      }
    } else {
      _answerLocal(answer);
    }
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

  Future<void> simulatePartnerAnswer(String answer) async {
    if (_coupleId != null) {
      try {
        final partnerKey = _partnerId ?? 'partner_simulator';
        final response = await Supabase.instance.client
            .from('daily_questions')
            .select('answers')
            .eq('couple_id', _coupleId!)
            .eq('date', _todayString)
            .maybeSingle();

        final Map<String, dynamic> answers = {};
        if (response != null && response['answers'] != null) {
          answers.addAll(Map<String, dynamic>.from(response['answers']));
        }
        answers[partnerKey] = answer;

        await Supabase.instance.client
            .from('daily_questions')
            .upsert({
          'couple_id': _coupleId,
          'date': _todayString,
          'question': _todayQuestion?.question ?? _generateTodayQuestion().question,
          'answers': answers,
        });
      } catch (e) {
        debugPrint('DailyMoodProvider.simulatePartnerAnswer Supabase error: $e');
        _simulateLocalPartnerAnswer(answer);
      }
    } else {
      _simulateLocalPartnerAnswer(answer);
    }
  }

  void _simulateLocalPartnerAnswer(String answer) {
    if (_todayQuestion == null) return;
    _todayQuestion = DailySyncQuestion(
      question: _todayQuestion!.question,
      myAnswer: _todayQuestion!.myAnswer,
      partnerAnswer: answer,
      date: _todayQuestion!.date,
    );
    _persistQuestion();
  }

  Future<void> _persistMoods() async {
    await _persistLocalMoodsOnly();
    if (!_disposed) notifyListeners();
  }

  Future<void> _persistQuestion() async {
    await _persistLocalQuestionOnly();
    if (!_disposed) notifyListeners();
  }

  Future<void> _persistLocalMoodsOnly() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _moods.map((m) => m.toJson()).toList();
      await prefs.setString(_moodKey, jsonEncode(jsonList));
    } catch (e, st) {
      debugPrint('DailyMoodProvider._persistLocalMoodsOnly failed: $e\n$st');
    }
  }

  Future<void> _persistLocalQuestionOnly() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_todayQuestion != null) {
        await prefs.setString(_questionKey, jsonEncode(_todayQuestion!.toJson()));
      }
    } catch (e, st) {
      debugPrint('DailyMoodProvider._persistLocalQuestionOnly failed: $e\n$st');
    }
  }

  @override
  void dispose() {
    _moodsSub?.cancel();
    _questionSub?.cancel();
    _disposed = true;
    super.dispose();
  }
}
