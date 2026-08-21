import 'package:intl/intl.dart';

import 'package:days_together/models/daily_mood_model.dart';

/// State for `DailyMoodController` (Phase 6a of the architecture migration)
/// -- a direct Riverpod port of `DailyMoodProvider`'s fields. `partnerId`
/// (needed for the daily-question partner-answer lookup, mirroring
/// `DailyMoodProvider._partnerId`) is deliberately controller-only
/// bookkeeping, not part of this state, matching the same convention
/// `_localMutations` follows in every other Phase 6a controller.
class DailyMoodState {
  final List<DailyMood> moods;
  final List<DailyMood> partnerMoods;
  final DailySyncQuestion? todayQuestion;
  final bool isLoading;

  const DailyMoodState({
    this.moods = const [],
    this.partnerMoods = const [],
    this.todayQuestion,
    this.isLoading = true,
  });

  DailyMoodState copyWith({
    List<DailyMood>? moods,
    List<DailyMood>? partnerMoods,
    Object? todayQuestion = _unset,
    bool? isLoading,
  }) {
    return DailyMoodState(
      moods: moods ?? this.moods,
      partnerMoods: partnerMoods ?? this.partnerMoods,
      todayQuestion: identical(todayQuestion, _unset) ? this.todayQuestion : todayQuestion as DailySyncQuestion?,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  static String get todayString => DateFormat('yyyy-MM-dd').format(DateTime.now());

  bool get hasLoggedToday => moods.any((m) => m.date == todayString);

  DailyMood? get todayMood {
    for (final m in moods) {
      if (m.date == todayString) return m;
    }
    return null;
  }

  DailyMood? get partnerTodayMood {
    for (final m in partnerMoods) {
      if (m.date == todayString) return m;
    }
    return null;
  }

  List<DailyMood> get recentMoods {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final cutoffStr = DateFormat('yyyy-MM-dd').format(cutoff);
    return moods.where((m) => m.date.compareTo(cutoffStr) >= 0).toList()..sort((a, b) => a.date.compareTo(b.date));
  }

  List<DailyMood> get partnerRecentMoods {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final cutoffStr = DateFormat('yyyy-MM-dd').format(cutoff);
    return partnerMoods.where((m) => m.date.compareTo(cutoffStr) >= 0).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }
}

const Object _unset = Object();
