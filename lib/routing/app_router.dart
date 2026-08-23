import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:days_together/models/timeline_model.dart';
import 'package:days_together/providers/couple_session.dart'
    show SessionStage, computeSessionStage, coupleSessionProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:days_together/features/timeline/timeline_controller.dart';
import 'package:days_together/routing/routes.dart';
import 'package:days_together/screens/love_story_screen.dart';
import 'package:days_together/screens/onboarding/auth_screen.dart';
import 'package:days_together/screens/onboarding/avatar_creation_screen.dart';
import 'package:days_together/screens/onboarding/create_couple_code_screen.dart';
import 'package:days_together/screens/onboarding/genesis_screen.dart';
import 'package:days_together/screens/onboarding/join_couple_code_screen.dart';
import 'package:days_together/screens/onboarding/loading_screen.dart';
import 'package:days_together/screens/onboarding/pairing_selection_screen.dart';
import 'package:days_together/screens/onboarding/recover_relationship_screen.dart';
import 'package:days_together/screens/onboarding/welcome_screen.dart';
import 'package:days_together/screens/settings/notification_settings_screen.dart';
import 'package:days_together/screens/settings/relationship_profile_screen.dart';
import 'package:days_together/screens/settings/theme_selector_screen.dart';
import 'package:days_together/screens/studio/ai_love_letter_screen.dart';
import 'package:days_together/screens/studio/relationship_insights_screen.dart';
import 'package:days_together/screens/studio/time_capsule_screen.dart';
import 'package:days_together/screens/timeline/memory_detail_screen.dart';
import 'package:days_together/screens/together/bucket_list_screen.dart';
import 'package:days_together/screens/together/calendar_screen.dart';
import 'package:days_together/screens/together/gift_reminders_screen.dart';
import 'package:days_together/screens/together/love_chat_screen.dart';
import 'package:days_together/screens/together/love_meter_screen.dart';
import 'package:days_together/screens/together/noteit_screen.dart';
import 'package:days_together/screens/together/relationship_duration_screen.dart';
import 'package:days_together/features/relationship/presentation/license/license_screen.dart';
import 'package:days_together/screens/together/topic_cards_screen.dart';
import 'package:days_together/screens/together/vault_screen.dart';
import 'package:days_together/screens/wrapped/wrapped_archive_screen.dart';
import 'package:days_together/screens/wrapped/wrapped_data.dart';
import 'package:days_together/screens/wrapped/wrapped_screen.dart';

/// The set of onboarding/session-stage-driven routes -- these are the ones
/// [computeSessionStage] can redirect *to*. Once `stage == ready`, landing on
/// any of these is invalid and the redirect bounces to [Routes.home].
const Set<String> _onboardingRoutes = {
  Routes.loading,
  Routes.welcome,
  Routes.auth,
  Routes.pairing,
  Routes.joinCode,
  Routes.recover,
  Routes.workspace,
  Routes.genesis,
  Routes.avatar,
};

/// For each non-ready stage, every route the redirect must leave alone --
/// not just the stage's single canonical screen, but every forward sub-step
/// reachable from it *without* changing any field [computeSessionStage]
/// reads (so the identity fields are still exactly what put the user in this
/// stage). `unauthenticated` allows both [Routes.welcome] and [Routes.auth]:
/// tapping "Begin Your Story" pushes `auth` before sign-in has happened, so
/// `userId` is still null and the stage hasn't changed -- without this
/// entry, the redirect would immediately bounce the push straight back to
/// `welcome`. Same reasoning for `needsCouple` allowing [Routes.joinCode]/
/// [Routes.recover] (chosen from `PairingSelectionScreen` before a code is
/// validated).
///
/// A stage not listed here has no such sub-steps -- its allowed set is just
/// [_routeForStage]'s single target (see [appRedirect]).
const Map<SessionStage, Set<String>> _allowedRoutesForStage = {
  SessionStage.unauthenticated: {Routes.welcome, Routes.auth},
  SessionStage.needsCouple: {Routes.pairing, Routes.joinCode, Routes.recover},
};

/// Maps a non-ready [SessionStage] to the one route the redirect forces a
/// disallowed location back to (see [_allowedRoutesForStage] for the
/// sub-steps that *don't* count as disallowed).
String? _routeForStage(SessionStage stage) {
  switch (stage) {
    case SessionStage.loading:
      return Routes.loading;
    case SessionStage.unauthenticated:
      return Routes.welcome;
    case SessionStage.needsCouple:
      return Routes.pairing;
    case SessionStage.needsWorkspace:
      return Routes.workspace;
    case SessionStage.needsGenesis:
      return Routes.genesis;
    case SessionStage.needsAvatar:
      return Routes.avatar;
    case SessionStage.ready:
      return null;
  }
}

/// The one function that decides where an in-flight navigation should
/// actually land, replacing the four independent readiness checks ADR-007
/// found (`main.dart`'s old `AppHome` switch, `notification_service.dart`,
/// `avatar_creation_screen.dart`, `recover_relationship_screen.dart`).
///
/// **Reads [SessionController]/[WorkspaceController] via
/// `ProviderScope.containerOf`, not `CoupleSession` directly** (Item 3
/// gap-fix Phase 3, front 4 of the architecture migration's
/// `provider`-removal item). This function is a top-level function, not a
/// widget, so there is no `WidgetRef` in scope -- `ProviderScope.containerOf
/// (context, listen: false)` is the established pattern for reading Riverpod
/// state from a raw `BuildContext` outside a `ConsumerWidget`, already used
/// once elsewhere in this migration (an `app_router.dart` `GoRoute` builder
/// callback). Both hub controllers mirror `CoupleSession`'s fields
/// synchronously on every change (via `main.dart`'s session bridge), so this
/// reads exactly as current as reading `CoupleSession` itself would.
/// Originally read `RelationshipProvider`, then `CoupleSession` directly once
/// `RelationshipProvider` was deleted (item 4 of the Definition-of-Done
/// sweep) -- see git history for that migration's reasoning, no longer
/// relevant now that neither `provider`-package object is read here at all.
///
/// **Simplification vs. ADR-007's original text:** the ADR called for a
/// second, separate redirect clause guarding every couple-scoped route
/// (returning [Routes.pairing] when `coupleId == null`) in addition to the
/// stage-based redirect below. That clause is unreachable dead code given
/// [computeSessionStage]'s actual definition: `SessionStage.ready` requires
/// `coupleId != null` by construction (see `couple_session.dart`), and every
/// real code path that clears `coupleId` (`unlinkPartner`, `logout`,
/// `deleteAccount`) also clears `onboardingCompleted` in the same operation
/// (verified against `relationship_provider.dart`), so `ready` is never
/// reachable with a null `coupleId` -- the stage-based redirect below already
/// forces navigation away from *any* current location, couple-scoped or not,
/// the moment a disconnect flips the stage away from `ready`. Implementing
/// the extra clause would be provably-redundant logic, which
/// `Days_Together_Architecture_Design_Specification.md` section 6.3
/// explicitly asks this migration to avoid.
/// The one deep link that arrived while `stage == loading`, captured so it
/// can be replayed once hydration finishes instead of being silently
/// dropped -- the risk ADR-007 calls out explicitly. A newer pending link
/// (a second notification tap before hydration finishes) overwrites an
/// older one; there is only ever one app-wide router, so module-level state
/// mirrors [_router]'s own singleton shape rather than threading this
/// through every call site.
String? _pendingLocation;

String? appRedirect(BuildContext context, GoRouterState state) {
  final container = ProviderScope.containerOf(context, listen: false);
  // Reads the raw CoupleSession instance, not sessionControllerProvider/
  // workspaceControllerProvider: this function is GoRouter's
  // refreshListenable callback, invoked synchronously the instant
  // CoupleSession.notifyListeners() fires. The hub controllers only learn
  // about that same change one frame later, via main.dart's
  // _CoupleSessionBridge deferring its push to a postFrameCallback -- reading
  // them here would race that deferral and could compute a stage against
  // stale data with nothing left to re-trigger the redirect once the mirror
  // catches up (GoRouter only re-evaluates on its own Listenable firing
  // again, not on a Riverpod provider changing). CoupleSession itself has no
  // such delay: it's the exact same object GoRouter is already listening to,
  // so reading it directly is always as fresh as the redirect call itself.
  final session = container.read(coupleSessionProvider);

  final stage = computeSessionStage(
    isInitialized: session.isInitialized,
    userId: session.userId,
    coupleId: session.coupleId,
    isCreator: session.isCreator,
    isPaired: session.isPaired,
    onboardingCompleted: session.onboardingCompleted,
    startDate: session.startDate,
  );

  final pending = _pendingLocation;
  final result = computeRedirectTarget(
    stage: stage,
    here: state.matchedLocation,
    pendingLocation: pending,
  );

  // Capture/clear the pending deep link around the pure decision above:
  // a location arriving while still loading is remembered (overwriting any
  // earlier one), and is forgotten once it's been handed to
  // computeRedirectTarget for replay -- whether or not that replay was
  // ultimately honored (an invalid replay still consumes the pending link;
  // it doesn't keep retrying).
  if (stage == SessionStage.loading) {
    if (state.matchedLocation != Routes.loading) {
      _pendingLocation = state.matchedLocation;
    }
  } else if (pending != null) {
    _pendingLocation = null;
  }

  return result;
}

/// The redirect's actual decision logic, pulled out of [appRedirect] as a
/// pure function -- `GoRouterState` has no public constructor usable outside
/// the go_router package (its one constructor takes a private
/// `RouteConfiguration`), so this is what `test/app_router_test.dart`
/// exercises directly instead. [pendingLocation] is the deep link (if any)
/// that arrived during an earlier `loading` stage, passed in by
/// [appRedirect]'s stateful capture above -- once `stage` has resolved, it's
/// re-validated here (via [here] being swapped out for it) rather than
/// forced unconditionally, so an invalid replay (e.g. the resolved stage
/// turned out to be `unauthenticated`, not `ready`) still lands on the
/// correct onboarding screen instead of a couple-scoped route it has no
/// business reaching.
String? computeRedirectTarget({
  required SessionStage stage,
  required String here,
  String? pendingLocation,
}) {
  if (stage == SessionStage.loading) {
    return here == Routes.loading ? null : Routes.loading;
  }

  if (pendingLocation != null) {
    return computeRedirectTarget(stage: stage, here: pendingLocation) ?? pendingLocation;
  }

  final target = _routeForStage(stage);
  if (target != null) {
    final allowed = _allowedRoutesForStage[stage] ?? {target};
    return allowed.contains(here) ? null : target;
  }

  // stage == ready: never allow parking on an onboarding screen.
  if (_onboardingRoutes.contains(here)) {
    return Routes.home;
  }

  return null;
}

GoRouter? _router;

/// The app's single `GoRouter` instance -- the "go_router's own
/// router-scoped navigation" ADR-007 names as the direct replacement for the
/// deleted `navigator_key.dart`. `notification_service.dart` (a non-widget
/// singleton) reaches it through this getter rather than a `BuildContext`,
/// exactly as it previously reached `navigatorKey`.
GoRouter get appRouter {
  assert(
    _router != null,
    'appRouter read before ensureAppRouter() built it -- call it from '
    'MyApp.build before anything navigates.',
  );
  return _router!;
}

/// Builds the router on first call and reuses it on every subsequent call,
/// so `MyApp.build` (which runs on every `themeControllerProvider` change,
/// not just once) can call this unconditionally without recreating the router --
/// `MaterialApp.router` requires the exact same `GoRouter` instance across
/// rebuilds.
GoRouter ensureAppRouter({required Listenable refreshListenable}) {
  return _router ??= GoRouter(
    initialLocation: Routes.loading,
    refreshListenable: refreshListenable,
    redirect: appRedirect,
    routes: [
      GoRoute(path: Routes.loading, builder: (_, _) => const LoadingScreen()),
      GoRoute(path: Routes.welcome, builder: (_, _) => const WelcomeScreen()),
      GoRoute(
        path: Routes.auth,
        // Preserves welcome_screen.dart's original fade transition rather
        // than falling back to the platform default -- ADR-007 scopes this
        // migration to navigation structure, not visual identity (see
        // Days_Together_Architecture_Design_Specification.md's "Out of
        // scope": "no visual redesign").
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const AuthScreen(),
          transitionDuration: const Duration(milliseconds: 500),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
      GoRoute(path: Routes.pairing, builder: (_, _) => const PairingSelectionScreen()),
      GoRoute(path: Routes.joinCode, builder: (_, _) => const JoinCoupleCodeScreen()),
      GoRoute(path: Routes.recover, builder: (_, _) => const RecoverRelationshipScreen()),
      GoRoute(path: Routes.workspace, builder: (_, _) => const CreateCoupleCodeScreen()),
      GoRoute(path: Routes.genesis, builder: (_, _) => const GenesisScreen()),
      GoRoute(path: Routes.avatar, builder: (_, _) => const AvatarCreationScreen()),
      GoRoute(
        path: Routes.home,
        builder: (context, state) {
          final tab = int.tryParse(state.uri.queryParameters['tab'] ?? '');
          return LoveStoryScreen(initialIndex: tab ?? 0);
        },
      ),
      GoRoute(path: Routes.chat, builder: (_, _) => const LoveChatScreen()),
      GoRoute(path: Routes.bucketList, builder: (_, _) => const BucketListScreen()),
      GoRoute(path: Routes.loveMeter, builder: (_, _) => const LoveMeterScreen()),
      GoRoute(path: Routes.notes, builder: (_, _) => const NoteitScreen()),
      GoRoute(path: Routes.timeCapsule, builder: (_, _) => const TimeCapsuleScreen()),
      GoRoute(path: Routes.calendar, builder: (_, _) => const CalendarScreen()),
      GoRoute(path: Routes.vault, builder: (_, _) => const VaultScreen()),
      GoRoute(path: Routes.topicCards, builder: (_, _) => const TopicCardsScreen()),
      GoRoute(path: Routes.license, builder: (_, _) => const RelationshipLicenseScreen()),
      GoRoute(path: Routes.gifts, builder: (_, _) => const GiftRemindersScreen()),
      GoRoute(path: Routes.themeSelector, builder: (_, _) => const ThemeSelectorScreen()),
      GoRoute(path: Routes.notificationSettings, builder: (_, _) => const NotificationSettingsScreen()),
      GoRoute(path: Routes.profile, builder: (_, _) => const RelationshipProfileScreen()),
      GoRoute(path: Routes.wrappedArchive, builder: (_, _) => const WrappedArchiveScreen()),
      GoRoute(
        path: Routes.wrapped,
        // Preserves settings_tab.dart's/wrapped_archive_screen.dart's original
        // fade transition -- see the Routes.auth route above for why.
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: WrappedScreen(data: state.extra as WrappedData),
          transitionDuration: const Duration(milliseconds: 600),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ),
      GoRoute(
        path: Routes.duration,
        // Preserves detailed_days_counter.dart's original fade+slide
        // transition -- see the Routes.auth route above for why.
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const RelationshipDurationScreen(),
          transitionDuration: const Duration(milliseconds: 350),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: animation.drive(
                  Tween<Offset>(
                    begin: const Offset(0.0, 0.05),
                    end: Offset.zero,
                  ).chain(CurveTween(curve: Curves.easeOutCubic)),
                ),
                child: child,
              ),
            );
          },
        ),
      ),
      GoRoute(path: Routes.studioLoveLetter, builder: (_, _) => const AILoveLetterScreen()),
      GoRoute(path: Routes.studioInsights, builder: (_, _) => const RelationshipInsightsScreen()),
      GoRoute(
        path: Routes.memoryPattern,
        builder: (context, state) {
          final itemId = state.pathParameters['itemId']!;
          final items = ProviderScope.containerOf(context, listen: false)
              .read(timelineControllerProvider)
              .items;
          TimelineItemData? item;
          try {
            item = items.firstWhere((i) => i.id == itemId);
          } catch (_) {
            item = null;
          }
          // The item may not be loaded yet (deep link arriving before
          // TimelineController syncs) or may no longer exist (deleted since
          // the notification was sent) -- fall back to the home timeline
          // tab rather than crashing, matching the try/catch discard the
          // old notification_service.dart call site used.
          if (item == null) {
            return LoveStoryScreen(initialIndex: 1);
          }
          return MemoryDetailScreen(item: item);
        },
      ),
    ],
  );
}
