import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:days_together/providers/relationship_provider.dart';

enum LoveTapState {
  idle,
  sent,
  received,
  mutual,
}

class LoveTapHistory {
  final int completedTaps;
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastLoveTap;

  const LoveTapHistory({
    this.completedTaps = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastLoveTap,
  });
}

class CurrentlyProvider with ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  LoveTapState _state = LoveTapState.idle;
  LoveTapState get state => _state;

  LoveTapHistory _history = const LoveTapHistory();
  LoveTapHistory get history => _history;

  String? _coupleId;
  String? _userId;
  String? _partnerId;
  StreamSubscription? _tapSub;

  CurrentlyProvider();

  void updateRelationship(RelationshipProvider relationship) {
    final bool credentialsChanged = _coupleId != relationship.coupleId || _userId != relationship.userId;
    final bool shouldSubscribe = _tapSub == null && relationship.coupleId != null && relationship.userId != null;

    if (credentialsChanged || shouldSubscribe) {
      _coupleId = relationship.coupleId;
      _userId = relationship.userId;
      _partnerId = relationship.partnerId;

      _tapSub?.cancel();
      _tapSub = null;

      if (_coupleId != null && _userId != null) {
        _initSupabaseSync();
        _loadHistory();
      } else {
        _state = LoveTapState.idle;
        _history = const LoveTapHistory();
        notifyListeners();
      }
    }
  }

  // Deterministically decide if current user is Partner 1
  bool get _isPartner1 {
    if (_userId == null || _partnerId == null) return true;
    return _userId!.compareTo(_partnerId!) < 0;
  }

  void _initSupabaseSync() {
    if (_coupleId == null) return;
    _isLoading = true;

    final todayStr = _getLocalDateString(DateTime.now());

    _tapSub = Supabase.instance.client
        .from('love_taps')
        .stream(primaryKey: ['id'])
        .eq('couple_id', _coupleId!)
        .listen(
          (dataList) {
            _isLoading = false;
            // Find today's row
            Map<String, dynamic>? todayRow;
            for (final row in dataList) {
              if (row['date'] == todayStr) {
                todayRow = row;
                break;
              }
            }

            if (todayRow == null) {
              _state = LoveTapState.idle;
            } else {
              final p1Tapped = todayRow['partner1_tapped'] as bool? ?? false;
              final p2Tapped = todayRow['partner2_tapped'] as bool? ?? false;

              if (p1Tapped && p2Tapped) {
                _state = LoveTapState.mutual;
              } else if (_isPartner1) {
                if (p1Tapped) {
                  _state = LoveTapState.sent;
                } else if (p2Tapped) {
                  _state = LoveTapState.received;
                } else {
                  _state = LoveTapState.idle;
                }
              } else {
                if (p2Tapped) {
                  _state = LoveTapState.sent;
                } else if (p1Tapped) {
                  _state = LoveTapState.received;
                } else {
                  _state = LoveTapState.idle;
                }
              }
            }
            notifyListeners();

            // Refresh history whenever updates occur (to keep streaks up to date)
            _loadHistory();
          },
          onError: (err) {
            debugPrint('CurrentlyProvider realtime stream error: $err');
            _isLoading = false;
          },
        );
  }

  Future<void> _loadHistory() async {
    if (_coupleId == null) return;

    try {
      final List<dynamic> rows = await Supabase.instance.client
          .from('love_taps')
          .select()
          .eq('couple_id', _coupleId!)
          .order('date', ascending: false);

      if (rows.isEmpty) {
        _history = const LoveTapHistory();
        notifyListeners();
        return;
      }

      int completedTaps = 0;
      DateTime? lastLoveTap;
      final Set<String> completedDates = {};

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

      // Compute Streaks
      int currentStreak = 0;
      DateTime checkDate = DateTime.now();
      String checkDateStr = _getLocalDateString(checkDate);

      // If today is completed, streak starts today.
      // If today is not completed but yesterday was, streak starts yesterday.
      // Otherwise, streak is 0.
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
        // Check yesterday
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

      // Longest Streak
      int longestStreak = 0;
      if (completedDates.isNotEmpty) {
        final List<DateTime> sortedCompletedDates = completedDates
            .map((d) => DateTime.parse(d))
            .toList()
          ..sort((a, b) => a.compareTo(b));

        int tempStreak = 1;
        longestStreak = 1;
        for (int i = 1; i < sortedCompletedDates.length; i++) {
          final diff = sortedCompletedDates[i].difference(sortedCompletedDates[i - 1]).inDays;
          if (diff == 1) {
            tempStreak++;
            if (tempStreak > longestStreak) {
              longestStreak = tempStreak;
            }
          } else if (diff > 1) {
            tempStreak = 1;
          }
        }
      }

      _history = LoveTapHistory(
        completedTaps: completedTaps,
        currentStreak: currentStreak,
        longestStreak: longestStreak,
        lastLoveTap: lastLoveTap,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading Love Tap history: $e');
    }
  }

  Future<void> sendLoveTap() async {
    if (_coupleId == null || _userId == null) return;

    final todayStr = _getLocalDateString(DateTime.now());
    final isP1 = _isPartner1;
    final nowIso = DateTime.now().toUtc().toIso8601String();

    final updateData = isP1
        ? {
            'partner1_tapped': true,
            'partner1_timestamp': nowIso,
          }
        : {
            'partner2_tapped': true,
            'partner2_timestamp': nowIso,
          };

    // If this tap completes the session, set completed_at
    if (_state == LoveTapState.received) {
      updateData['completed_at'] = nowIso;
    }

    try {
      await Supabase.instance.client.from('love_taps').upsert({
        'couple_id': _coupleId!,
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

  @override
  void dispose() {
    _tapSub?.cancel();
    super.dispose();
  }
}
