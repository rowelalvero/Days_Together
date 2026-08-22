import 'package:flutter/material.dart';
import 'package:days_together/providers/couple_session.dart';
import 'package:days_together/services/date_helper.dart';

export 'package:days_together/services/date_helper.dart' show MilestoneInfo;

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
/// The duration/milestone getters below (`startDateTime` through
/// `nextMilestones`) are now thin wrappers over plain `DateHelper` functions
/// (Phase 6b-3 of the architecture migration) -- ADR-009 called for this
/// extraction "during Phase 5"; it never happened until Phase 6b-1's
/// investigation found it stranded and blocking full `RelationshipProvider`
/// retirement. The getters stay here, unchanged in shape, purely so the
/// handful of UI files not yet converted (Phase 6b-2) keep working; any new
/// caller should read `WorkspaceController.startDate`/`startTime` and call
/// the `DateHelper` functions directly instead.
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

  // ---- Duration/milestone getters, delegating to DateHelper. ----

  DateTime get startDateTime => DateHelper.relationshipStartDateTime(_session.startDate, _session.startTime);

  Duration get relationshipDuration => DateTime.now().difference(startDateTime);

  int get totalDays => DateHelper.relationshipTotalDays(_session.startDate);

  int get totalHours => relationshipDuration.inHours;
  int get totalMinutes => relationshipDuration.inMinutes;
  int get totalSeconds => relationshipDuration.inSeconds;

  Map<String, int> get preciseAge => DateHelper.relationshipPreciseAge(_session.startDate, _session.startTime);

  int get totalMonths => DateHelper.relationshipTotalMonths(_session.startDate);

  String get relationshipAge => DateHelper.relationshipAgeLabel(_session.startDate, _session.startTime);

  int get years => preciseAge['years']!;

  List<MilestoneInfo> get nextMilestones =>
      DateHelper.nextRelationshipMilestones(_session.startDate, _session.startTime);

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    super.dispose();
  }
}
