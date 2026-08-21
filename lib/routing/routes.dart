/// The single named-route registry (Phase 3 of the architecture migration,
/// ADR-007) -- every screen-level navigation destination in the app has
/// exactly one path constant here. Sub-screen navigation that isn't a
/// distinct screen (dialogs, bottom sheets, `LoveStoryScreen`'s internal tab
/// switching) is deliberately not represented as a route -- see ADR-007's
/// "Options considered" for why.
class Routes {
  Routes._();

  // Onboarding / session-stage-driven routes. One of these is always the
  // redirect target when SessionStage isn't `ready` -- see
  // lib/routing/app_router.dart.
  static const String loading = '/loading';
  static const String welcome = '/welcome';
  static const String auth = '/auth';
  static const String pairing = '/pairing';
  static const String joinCode = '/pairing/join';
  static const String recover = '/pairing/recover';
  static const String workspace = '/workspace';
  static const String genesis = '/genesis';
  static const String avatar = '/avatar';

  /// The main app shell (`LoveStoryScreen`). Accepts an optional `tab` query
  /// parameter (see [home]) -- `LoveStoryScreenState` reads it to select the
  /// initial/target tab, replacing `notification_service.dart`'s old
  /// dual-strategy `setIndex`-if-mounted-else-relaunch logic with a single
  /// `context.go` call.
  static const String home = '/home';

  static String homeTab(int index) => '$home?tab=$index';

  // Couple-scoped feature screens, pushed on top of the home shell.
  static const String chat = '/chat';
  static const String bucketList = '/bucket-list';
  static const String loveMeter = '/love-meter';
  static const String notes = '/notes';
  static const String timeCapsule = '/time-capsule';
  static const String calendar = '/calendar';
  static const String vault = '/vault';
  static const String topicCards = '/topic-cards';
  static const String license = '/license';
  static const String gifts = '/gifts';
  static const String themeSelector = '/theme-selector';
  static const String notificationSettings = '/notification-settings';
  static const String profile = '/profile';
  static const String wrappedArchive = '/wrapped-archive';
  static const String wrapped = '/wrapped';
  static const String duration = '/duration';
  static const String studioLoveLetter = '/studio/love-letter';
  static const String studioInsights = '/studio/insights';

  /// A specific timeline memory, identified by [itemId]. The screen itself
  /// resolves the id to a `TimelineItemData` via `TimelineProvider` (see
  /// `app_router.dart`'s route builder) rather than the caller passing the
  /// full object, so a notification payload only needs to carry an id.
  static String memory(String itemId) => '/memories/$itemId';
  static const String memoryPattern = '/memories/:itemId';
}
