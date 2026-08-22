import 'package:shared_preferences/shared_preferences.dart';
import 'package:days_together/features/relationship/workspace_state.dart';
import 'package:days_together/features/relationship/profile_state.dart';
import 'package:days_together/providers/timeline_provider.dart';
import 'package:days_together/providers/noteit_provider.dart';
import 'package:days_together/providers/bucket_list_provider.dart';
import 'package:days_together/providers/daily_mood_provider.dart';
import 'package:days_together/providers/calendar_provider.dart';
import 'package:days_together/providers/time_capsule_provider.dart';
import 'package:days_together/providers/vault_provider.dart';
import 'package:days_together/models/noteit_model.dart';
import 'package:days_together/services/date_helper.dart';
import 'wrapped_data.dart';

/// Pure data aggregation service — no UI.
/// Computes a [WrappedData] snapshot from live providers and persists/loads
/// yearly archives via SharedPreferences.
class WrappedService {
  static const String _archivePrefix = 'wrapped_archive_';

  // ─── Archive Persistence ────────────────────────────────────────────────────

  /// Returns all years for which an archived Wrapped exists, sorted descending.
  static Future<List<int>> getArchivedYears() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs
        .getKeys()
        .where((k) => k.startsWith(_archivePrefix))
        .map((k) => int.tryParse(k.replaceFirst(_archivePrefix, '')) ?? 0)
        .where((y) => y > 0)
        .toList()
      ..sort((a, b) => b.compareTo(a));
  }

  /// Loads an archived [WrappedData] for [year], or null if none exists.
  static Future<WrappedData?> loadArchive(int year) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_archivePrefix$year');
    if (raw == null) return null;
    try {
      return WrappedData.fromJsonString(raw);
    } catch (_) {
      return null;
    }
  }

  /// Persists [data] as the immutable archive for its year.
  /// Subsequent data changes do not affect the archived snapshot.
  static Future<void> saveArchive(WrappedData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_archivePrefix${data.year}', data.toJsonString());
  }

  /// Returns true if an archive already exists for [year].
  static Future<bool> hasArchive(int year) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('$_archivePrefix$year');
  }

  // ─── Data Aggregation ───────────────────────────────────────────────────────

  /// Aggregates all provider data for [year] into an immutable [WrappedData].
  /// Call this once before navigating to [WrappedScreen].
  static WrappedData aggregate({
    required int year,
    required WorkspaceState workspace,
    required ProfileState profile,
    required TimelineProvider tp,
    required NoteitProvider np,
    required BucketListProvider bp,
    required DailyMoodProvider mp,
    required CalendarProvider cp,
    required TimeCapsuleProvider cap,
    required VaultProvider vp,
  }) {
    final now = DateTime.now();
    final startDate = workspace.startDate;
    final age = startDate != null
        ? DateHelper.getPreciseAge(startDate, now)
        : <String, int>{'years': 0, 'months': 0, 'days': 0};
    final computedTotalDays = startDate != null
        ? DateHelper.calendarDaysBetween(startDate, now)
        : DateHelper.relationshipTotalDays(startDate);

    // ── Memories ──────────────────────────────────────────────────────────────
    final allMemories = tp.timelineItems;
    final memoriesThisYear =
        allMemories.where((m) => m.date.year == year).toList();

    // Featured: pinned first, then with photo, then any from this year
    final featured = memoriesThisYear
            .where((m) => m.isPinned)
            .firstOrNull ??
        memoriesThisYear
            .where((m) =>
                (m.networkImageUrl?.isNotEmpty ?? false) ||
                (m.imagePath?.isNotEmpty ?? false) ||
                m.photoUrls.isNotEmpty)
            .firstOrNull ??
        memoriesThisYear.firstOrNull;

    String? featuredImgUrl;
    if (featured != null) {
      if (featured.networkImageUrl?.isNotEmpty ?? false) {
        featuredImgUrl = featured.networkImageUrl;
      } else if (featured.photoUrls.isNotEmpty) {
        featuredImgUrl = featured.photoUrls.first;
      }
    }

    // ── Notes ─────────────────────────────────────────────────────────────────
    final allNotes = np.notes;
    final notesThisYear =
        allNotes.where((n) => n.createdAt.year == year).toList();
    final textNotes = notesThisYear
        .where((n) =>
            n.type == NoteitType.text && (n.content?.isNotEmpty ?? false))
        .toList()
      ..sort((a, b) => (b.content?.length ?? 0).compareTo(a.content?.length ?? 0));

    String? longestExcerpt;
    if (textNotes.isNotEmpty) {
      final content = textNotes.first.content ?? '';
      longestExcerpt =
          content.length > 130 ? '${content.substring(0, 130)}…' : content;
    }

    // ── Bucket List ───────────────────────────────────────────────────────────
    final completedThisYear = bp.items
        .where((i) =>
            i.isCompleted &&
            i.completedAt != null &&
            i.completedAt!.year == year)
        .toList();

    // ── Mood ──────────────────────────────────────────────────────────────────
    final allMoods = mp.moods.where((m) {
      final d = DateTime.tryParse(m.date);
      return d != null && d.year == year;
    }).toList();

    final List<MonthlyMood> monthlyMoods = [];
    for (int month = 1; month <= 12; month++) {
      final entries = allMoods.where((m) {
        final d = DateTime.tryParse(m.date);
        return d != null && d.month == month;
      }).toList();
      if (entries.isNotEmpty) {
        final avg =
            entries.map((m) => m.moodScore).reduce((a, b) => a + b) /
                entries.length;
        monthlyMoods
            .add(MonthlyMood(month: month, avgScore: avg, count: entries.length));
      }
    }

    double avgMoodScore = 0;
    int topMoodScore = 0;
    String? bestMoodMonth;
    if (allMoods.isNotEmpty) {
      avgMoodScore = allMoods.map((m) => m.moodScore).reduce((a, b) => a + b) /
          allMoods.length;
      final scoreCounts = <int, int>{};
      for (final m in allMoods) {
        scoreCounts[m.moodScore] = (scoreCounts[m.moodScore] ?? 0) + 1;
      }
      topMoodScore = scoreCounts.entries
          .reduce((a, b) => a.value >= b.value ? a : b)
          .key;
      if (monthlyMoods.isNotEmpty) {
        const monthNames = [
          '', 'January', 'February', 'March', 'April', 'May', 'June',
          'July', 'August', 'September', 'October', 'November', 'December'
        ];
        final best = monthlyMoods
            .reduce((a, b) => a.avgScore >= b.avgScore ? a : b);
        bestMoodMonth = monthNames[best.month];
      }
    }

    // ── Calendar ──────────────────────────────────────────────────────────────
    final eventsThisYear =
        cp.events.where((e) => e.date.year == year).toList();
    final specialDates =
        eventsThisYear.take(5).map((e) => e.title).toList();

    // ── Capsules ──────────────────────────────────────────────────────────────
    final allCapsules = cap.capsules;
    final capCreated =
        allCapsules.where((c) => c.createdAt.year == year).length;
    final capOpened =
        allCapsules.where((c) => c.isOpened && c.openDate.year == year).length;
    final capUpcoming =
        allCapsules.where((c) => !c.isOpened && c.openDate.isAfter(now)).length;

    // ── Milestones ────────────────────────────────────────────────────────────
    const milestoneMap = {
      30: '30 Days Together 🎉',
      100: '100 Days Together 💫',
      365: '1 Year Anniversary 🌹',
      500: '500 Days Together ✨',
      730: '2 Year Anniversary 💍',
      1000: '1,000 Days Together 👑',
      1095: '3 Year Anniversary 🏹',
      1461: '4 Year Anniversary 🥂',
      1500: '1,500 Days Together 🌟',
      1826: '5 Year Anniversary 🪐',
      2000: '2,000 Days Together 🌈',
      2500: '2,500 Days Together 🛸',
      3000: '3,000 Days Together 🎊',
    };

    final achievedThisYear = <String>[];
    if (startDate != null) {
      for (final entry in milestoneMap.entries) {
        final achieveDate = startDate.add(Duration(days: entry.key));
        if (achieveDate.year == year &&
            achieveDate.isBefore(now.add(const Duration(days: 1)))) {
          achievedThisYear.add(entry.value);
        }
      }
    }

    return WrappedData(
      year: year,
      yourName: profile.yourName ?? 'You',
      partnerName: profile.partnerName,
      yourAvatarUrl: profile.yourAvatarPath,
      partnerAvatarUrl: profile.partnerAvatarPath,
      totalDays: computedTotalDays,
      durationYears: age['years'] ?? 0,
      durationMonths: age['months'] ?? 0,
      durationDays: age['days'] ?? 0,
      startDate: startDate,
      totalMemories: allMemories.length,
      memoriesThisYear: memoriesThisYear.length,
      featuredMemoryTitle: featured?.title,
      featuredMemoryDescription: featured?.description,
      featuredMemoryImageUrl: featuredImgUrl,
      featuredMemoryImagePath: featured?.imagePath,
      featuredMemoryDate: featured?.date,
      totalNotes: allNotes.length,
      notesThisYear: notesThisYear.length,
      longestNoteExcerpt: longestExcerpt,
      bucketTotal: bp.totalItems,
      bucketCompleted: bp.completedItems,
      bucketCompletedThisYear: completedThisYear.length,
      favoriteBucketItem:
          completedThisYear.isNotEmpty ? completedThisYear.first.title : null,
      monthlyMoods: monthlyMoods,
      avgMoodScore: avgMoodScore,
      topMoodScore: topMoodScore,
      bestMoodMonth: bestMoodMonth,
      calendarEventsThisYear: eventsThisYear.length,
      specialDatesThisYear: specialDates,
      capsulesCreated: capCreated,
      capsulesOpened: capOpened,
      upcomingCapsules: capUpcoming,
      totalPhotos: vp.allItems.length,
      totalCapsules: allCapsules.length,
      milestonesAchievedThisYear: achievedThisYear,
      letterTemplateIndex: year % 4,
    );
  }

  // ─── Letter Generation ──────────────────────────────────────────────────────

  /// Generates a heartfelt letter from one of 4 rotating templates.
  static String generateLetter(WrappedData data) {
    final partner = data.partnerDisplayName;
    final year = data.year;
    final days = data.totalDays;
    final memories = data.memoriesThisYear;
    final bucket = data.bucketCompletedThisYear;
    final notes = data.notesThisYear;
    final milestones = data.milestonesAchievedThisYear;
    final hasMilestone = milestones.isNotEmpty;

    switch (data.letterTemplateIndex) {
      case 0:
        return '$year was more than a calendar year — '
            'it was a collection of quiet mornings, shared laughter, and small '
            'moments that became everything.\n\n'
            'Together with $partner, you created $memories new '
            '${memories == 1 ? 'memory' : 'memories'} this year'
            '${bucket > 0 ? ', checked off $bucket ${bucket == 1 ? 'dream' : 'dreams'} from your bucket list' : ''}'
            '${notes > 0 ? ', and exchanged $notes heartfelt ${notes == 1 ? 'note' : 'notes'}' : ''}.\n\n'
            '${hasMilestone ? 'You celebrated ${milestones.first} — a milestone worth every single day. ' : ''}'
            'At $days days together, your story continues to grow more '
            'beautiful with every passing season.\n\n'
            'Here\'s to everything $year held — and everything the next year promises.';

      case 1:
        return 'If $year could speak, it would tell a story of two people '
            'who chose each other, again and again, through every ordinary Tuesday '
            'and every extraordinary night.\n\n'
            'This year brought $memories shared '
            '${memories == 1 ? 'memory' : 'memories'} between you and $partner'
            '${bucket > 0 ? ' — $bucket ${bucket == 1 ? 'dream' : 'dreams'} crossed off your list together' : ''}'
            '${notes > 0 ? ', and $notes ${notes == 1 ? 'note' : 'notes'} written from the heart' : ''}.\n\n'
            '${hasMilestone ? '${milestones.first} — a milestone that speaks to the depth of your commitment. ' : ''}'
            '$days days of choosing love. That number will keep growing, '
            'and so will everything you build together.\n\n'
            'Thank you for making this year unforgettable.';

      case 2:
        return 'Some years leave marks on your heart. $year is one of them.\n\n'
            'You and $partner spent this year writing chapters '
            'that only the two of you will ever fully understand — '
            '$memories new ${memories == 1 ? 'memory' : 'memories'} captured'
            '${bucket > 0 ? ', $bucket ${bucket == 1 ? 'adventure' : 'adventures'} completed together' : ''}'
            '${notes > 0 ? ', and $notes ${notes == 1 ? 'love note' : 'love notes'} sent' : ''}.\n\n'
            '${hasMilestone ? 'Along the way, you reached ${milestones.first}. ' : ''}'
            'At $days days together, you\'ve proven that love isn\'t just a feeling '
            '— it\'s a daily practice, and you\'re both remarkable at it.\n\n'
            'May the next chapter be even more beautiful than this one.';

      case 3:
      default:
        return 'There is something sacred about looking back at a year '
            'well-loved, and $year was exactly that.\n\n'
            'Between you and $partner: $memories '
            '${memories == 1 ? 'memory' : 'memories'} woven into your story'
            '${bucket > 0 ? ', $bucket shared ${bucket == 1 ? 'dream' : 'dreams'} brought to life' : ''}'
            '${notes > 0 ? ', and $notes ${notes == 1 ? 'note' : 'notes'} that carried your hearts' : ''}.\n\n'
            '${hasMilestone ? '${milestones.first} — a number that represents real, lived love. ' : ''}'
            '$days days. That\'s how long you\'ve been choosing this, '
            'choosing each other, and it shows in every beautiful detail.\n\n'
            'Here\'s to more of everything that made this year worth remembering.';
    }
  }
}
