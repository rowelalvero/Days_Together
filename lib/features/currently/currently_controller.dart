import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:days_together/core/riverpod/supabase_lifecycle_notifier.dart';
import 'package:days_together/features/currently/currently_state.dart';
import 'package:days_together/providers/couple_session.dart';

/// Riverpod port of `CurrentlyProvider` (Phase 6a of the architecture
/// migration, the eleventh of the 12 domain providers). Standard
/// single-table pattern, with one overridden method
/// (`updateSession`, mirroring the original, to capture `partnerId` for
/// the deterministic partner1/partner2 ordering) -- otherwise a
/// straightforward `SupabaseLifecycleNotifier` port.
class CurrentlyController extends Notifier<CurrentlyState> with SupabaseLifecycleNotifier<CurrentlyState> {
  String? _partnerId;

  @override
  String get tableName => 'love_taps';

  @override
  List<String> get primaryKey => const ['id'];

  @override
  CurrentlyState build() {
    initSessionLifecycle();
    return const CurrentlyState();
  }

  @override
  Future<void> updateSession(CoupleSession session) async {
    _partnerId = session.partnerId;
    await super.updateSession(session);
  }

  @override
  Future<void> purgeCache() async {
    state = const CurrentlyState();
  }

  @override
  Future<void> syncInitialData() async {
    await _loadHistory();
  }

  // Deterministically decide if the current user is Partner 1.
  bool get _isPartner1 {
    if (sessionUserId == null || _partnerId == null) return true;
    return sessionUserId!.compareTo(_partnerId!) < 0;
  }

  @override
  void onRealtimeData(List<Map<String, dynamic>> dataList) {
    if (!ref.mounted) return;
    final todayStr = _getLocalDateString(DateTime.now());

    Map<String, dynamic>? todayRow;
    for (final row in dataList) {
      if (row['date'] == todayStr) {
        todayRow = row;
        break;
      }
    }

    LoveTapState nextState;
    if (todayRow == null) {
      nextState = LoveTapState.idle;
    } else {
      final p1Tapped = todayRow['partner1_tapped'] as bool? ?? false;
      final p2Tapped = todayRow['partner2_tapped'] as bool? ?? false;

      if (p1Tapped && p2Tapped) {
        nextState = LoveTapState.mutual;
      } else if (_isPartner1) {
        nextState = p1Tapped ? LoveTapState.sent : (p2Tapped ? LoveTapState.received : LoveTapState.idle);
      } else {
        nextState = p2Tapped ? LoveTapState.sent : (p1Tapped ? LoveTapState.received : LoveTapState.idle);
      }
    }

    state = state.copyWith(isLoading: false, state: nextState);

    // Refresh history whenever updates occur, to keep streaks up to date.
    _loadHistory();
  }

  @override
  void onRealtimeError(Object error) {
    debugPrint('CurrentlyController realtime stream error: $error');
    if (!ref.mounted) return;
    state = state.copyWith(isLoading: false);
  }

  Future<void> _loadHistory() async {
    if (coupleId == null) return;

    try {
      final List<dynamic> rows = await Supabase.instance.client
          .from('love_taps')
          .select()
          .eq('couple_id', coupleId!)
          .order('date', ascending: false);

      if (!ref.mounted) return;

      if (rows.isEmpty) {
        state = state.copyWith(history: const LoveTapHistory());
        return;
      }

      int completedTaps = 0;
      DateTime? lastLoveTap;
      final completedDates = <String>{};

      for (final row in rows) {
        final p1Tapped = row['partner1_tapped'] as bool? ?? false;
        final p2Tapped = row['partner2_tapped'] as bool? ?? false;
        if (p1Tapped && p2Tapped) {
          completedTaps++;
          final dateStr = row['date'] as String;
          completedDates.add(dateStr);
          lastLoveTap ??= DateTime.parse(dateStr);
        }
      }

      int currentStreak = 0;
      DateTime checkDate = DateTime.now();
      String checkDateStr = _getLocalDateString(checkDate);

      if (completedDates.contains(checkDateStr)) {
        currentStreak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
        checkDateStr = _getLocalDateString(checkDate);
        while (completedDates.contains(checkDateStr)) {
          currentStreak++;
          checkDate = checkDate.subtract(const Duration(days: 1));
          checkDateStr = _getLocalDateString(checkDate);
        }
      } else {
        checkDate = checkDate.subtract(const Duration(days: 1));
        checkDateStr = _getLocalDateString(checkDate);
        if (completedDates.contains(checkDateStr)) {
          currentStreak++;
          checkDate = checkDate.subtract(const Duration(days: 1));
          checkDateStr = _getLocalDateString(checkDate);
          while (completedDates.contains(checkDateStr)) {
            currentStreak++;
            checkDate = checkDate.subtract(const Duration(days: 1));
            checkDateStr = _getLocalDateString(checkDate);
          }
        }
      }

      int longestStreak = 0;
      if (completedDates.isNotEmpty) {
        final sortedCompletedDates = completedDates.map((d) => DateTime.parse(d)).toList()
          ..sort((a, b) => a.compareTo(b));

        int tempStreak = 1;
        longestStreak = 1;
        for (int i = 1; i < sortedCompletedDates.length; i++) {
          final diff = sortedCompletedDates[i].difference(sortedCompletedDates[i - 1]).inDays;
          if (diff == 1) {
            tempStreak++;
            if (tempStreak > longestStreak) longestStreak = tempStreak;
          } else if (diff > 1) {
            tempStreak = 1;
          }
        }
      }

      state = state.copyWith(
        history: LoveTapHistory(
          completedTaps: completedTaps,
          currentStreak: currentStreak,
          longestStreak: longestStreak,
          lastLoveTap: lastLoveTap,
        ),
      );
    } catch (e) {
      debugPrint('Error loading Love Tap history: $e');
    }
  }

  Future<void> sendLoveTap() async {
    if (coupleId == null || sessionUserId == null) return;

    final todayStr = _getLocalDateString(DateTime.now());
    final isP1 = _isPartner1;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    final updateData = isP1
        ? {'partner1_tapped': true, 'partner1_timestamp': nowIso}
        : {'partner2_tapped': true, 'partner2_timestamp': nowIso};

    if (state.state == LoveTapState.received) {
      updateData['completed_at'] = nowIso;
    }

    try {
      await Supabase.instance.client.from('love_taps').upsert({
        'couple_id': coupleId!,
        'date': todayStr,
        ...updateData,
        'updated_at': nowIso,
      }, onConflict: 'couple_id,date');
    } catch (e) {
      debugPrint('Error sending Love Tap: $e');
    }
  }

  String _getLocalDateString(DateTime dt) {
    final year = dt.year.toString().padLeft(4, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}

final currentlyControllerProvider = NotifierProvider.autoDispose<CurrentlyController, CurrentlyState>(
  CurrentlyController.new,
  dependencies: [coupleSessionProvider],
);
