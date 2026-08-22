import 'package:flutter/material.dart';
import 'package:days_together/providers/couple_session.dart';
import 'package:days_together/services/date_helper.dart';

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

/// A thin, pass-through facade over the live [CoupleSession] instance
/// (Phase 6b-1 of the architecture migration, "make CoupleSession real").
///
/// CURRENT STATE: every getter below reads straight through to [_session];
/// every write method delegates straight through to it. `RelationshipProvider`
/// no longer runs its own Supabase auth listener or holds any of its own
/// engine state -- [CoupleSession] is now the sole owner of that (see its
/// own doc comment for why: `removeAllChannels()` firing on every auth event
/// means only one listener can safely exist). This facade exists purely so
/// the ~24 UI files that still call `context.watch<RelationshipProvider>()`
/// keep working unchanged; they are converted to read [CoupleSession]
/// directly in a later migration step (Phase 6b-2), at which point this
/// class is deleted outright.
///
/// The subscription to [_session] is a plain [ChangeNotifier.addListener]
/// call, not a `ChangeNotifierProxyProvider` -- `addListener` callbacks run
/// synchronously in the same call stack as `_session.notifyListeners()`,
/// whereas a `ChangeNotifierProxyProvider`'s `update` callback only runs on
/// the *next* frame (Flutter's `InheritedWidget` dependency propagation).
/// `app_router.dart`'s `appRedirect` depends on this: `await
/// provider.joinWithCode(code); context.push(...)` must see the just-set
/// fields immediately, with no one-frame lag (see Phase 3's correction #2,
/// which this facade design deliberately does not reintroduce).
///
/// The one thing that stays genuinely local to this class -- not delegated
/// -- is the pure duration/milestone math below (`startDateTime` through
/// `nextMilestones`). ADR-009 called for this to become plain `DateHelper`
/// functions "during Phase 5"; that extraction never happened (confirmed
/// zero matches in `date_helper.dart`), so it remains here, reading
/// [_session]'s dates, exactly as before this phase. It is out of this
/// step's scope (tracked as Phase 6b-3 in migration-roadmap.md).
class RelationshipProvider with ChangeNotifier {
  final CoupleSession _session;

  RelationshipProvider(this._session) {
    _session.addListener(_onSessionChanged);
  }

  void _onSessionChanged() => notifyListeners();

  RelationshipStatus get status => _session.status;
  String? get recoveryCode => _session.recoveryCode;
  String? get relationshipId => _session.relationshipId;

  bool get isInitialized => _session.isInitialized;

  /// Safety valve: allows LoadingScreen to unblock the user after a timeout.
  /// The auth listener will correct state once connectivity returns.
  void forceInitialized() => _session.forceInitialized();

  DateTime? get startDate => _session.startDate;
  TimeOfDay? get startTime => _session.startTime;
  String? get partnerName => _session.partnerName;
  String? get yourName => _session.yourName;
  String? get yourAvatarPath => _session.yourAvatarPath;
  String? get partnerAvatarPath => _session.partnerAvatarPath;
  String? get coupleCode => _session.coupleCode;
  bool get isPaired => _session.isPaired;
  bool get isOnboardingComplete => _session.isOnboardingComplete;
  /// The raw persisted flag, distinct from [isOnboardingComplete] which also
  /// requires a non-null [coupleId].
  bool get onboardingCompleted => _session.onboardingCompleted;
  bool get isPremium => _session.isPremium;
  String get storyTitle => _session.storyTitle;
  String? get coupleId => _session.coupleId;
  String? get userId => _session.userId;
  String? get partnerId => _session.partnerId;
  bool get isCreator => _session.isCreator;

  bool get isPartnerOnline => _session.isPartnerOnline;
  DateTime? get yourJoinDate => _session.yourJoinDate;
  DateTime? get partnerJoinDate => _session.partnerJoinDate;
  String? get yourActivity => _session.yourActivity;
  String? get partnerActivity => _session.partnerActivity;

  bool get isSupabaseAvailable => _session.isSupabaseAvailable;

  Future<void> updateCurrentActivity(String? activity) => _session.updateCurrentActivity(activity);

  Future<void> setYourName(String name) => _session.setYourName(name);

  Future<void> setStoryTitle(String title) => _session.setStoryTitle(title);

  Future<void> setStartDate(DateTime date) => _session.setStartDate(date);

  Future<void> setStartTime(TimeOfDay time) => _session.setStartTime(time);

  Future<void> setNames(String yours, String partner) => _session.setNames(yours, partner);

  Future<void> setAvatars({String? yourPath, String? partnerPath}) =>
      _session.setAvatars(yourPath: yourPath, partnerPath: partnerPath);

  Future<void> createRelationshipWorkspace() => _session.createRelationshipWorkspace();

  String generateCoupleCode({bool forceRegenerate = false}) =>
      _session.generateCoupleCode(forceRegenerate: forceRegenerate);

  Future<String?> refreshPairingCode({bool forceRotate = false}) =>
      _session.refreshPairingCode(forceRotate: forceRotate);

  Future<bool> joinWithCode(String code) => _session.joinWithCode(code);

  Future<void> completeOnboarding() => _session.completeOnboarding();

  Future<void> setPremium(bool value) => _session.setPremium(value);

  Future<bool> recoverRelationship(String code) => _session.recoverRelationship(code);

  Future<void> regenerateRecoveryCode() => _session.regenerateRecoveryCode();

  void clearRecoveryCode() => _session.clearRecoveryCode();

  Future<void> unlinkPartner() => _session.unlinkPartner();

  bool get showPartnerDeletedNotice => _session.showPartnerDeletedNotice;

  void clearPartnerDeletedNotice() => _session.clearPartnerDeletedNotice();

  Future<void> deleteAccount() => _session.deleteAccount();

  Future<void> signUpWithEmail(String email, String password) =>
      _session.signUpWithEmail(email, password);

  Future<void> signInWithEmail(String email, String password) =>
      _session.signInWithEmail(email, password);

  Future<void> signInWithGoogle() => _session.signInWithGoogle();

  Future<void> logout({bool wipeAll = false}) => _session.logout(wipeAll: wipeAll);

  // ---- Pure duration/milestone math. Not delegated -- see class doc. ----

  DateTime get startDateTime {
    final date = _session.startDate;
    if (date == null) return DateTime.now();
    final time = _session.startTime;
    return DateTime(
      date.year,
      date.month,
      date.day,
      time?.hour ?? 0,
      time?.minute ?? 0,
    );
  }

  Duration get relationshipDuration {
    return DateTime.now().difference(startDateTime);
  }

  int get totalDays {
    final date = _session.startDate;
    if (date == null) return 0;
    return DateHelper.calendarDaysBetween(date, DateTime.now());
  }

  int get totalHours => relationshipDuration.inHours;
  int get totalMinutes => relationshipDuration.inMinutes;
  int get totalSeconds => relationshipDuration.inSeconds;

  Map<String, int> get preciseAge {
    if (_session.startDate == null) {
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
    final date = _session.startDate;
    if (date == null) return 0;
    final now = DateTime.now();
    return (now.year - date.year) * 12 + now.month - date.month;
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
    final startDate = _session.startDate;
    if (startDate == null) return [];
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

    if (milestones.length < 5) {
      final nextYear = years + 1;
      final anniversaryDate = DateHelper.getAnniversaryDate(startDate, nextYear);
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
    _session.removeListener(_onSessionChanged);
    super.dispose();
  }
}
