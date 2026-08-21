// Validates Phase 3 of the architecture migration (ADR-007): the single
// redirect function that replaces main.dart's old AppHome switch and the
// three other independent readiness checks the audit found. GoRouterState
// has no public constructor usable outside the go_router package, so these
// tests exercise computeRedirectTarget directly -- the pure decision logic
// app_router.dart's appRedirect calls -- rather than pumping a real
// GoRouter (which would also hit the GoogleFonts-in-tests gap documented in
// test/couple_session_test.dart's Phase 1 history, since every real
// destination screen renders themed text).

import 'package:flutter_test/flutter_test.dart';
import 'package:days_together/providers/couple_session.dart';
import 'package:days_together/routing/app_router.dart';
import 'package:days_together/routing/routes.dart';

void main() {
  group('computeRedirectTarget -- loading', () {
    test('holds at Routes.loading', () {
      expect(
        computeRedirectTarget(stage: SessionStage.loading, here: Routes.loading),
        isNull,
      );
    });

    test('redirects any other location to Routes.loading', () {
      expect(
        computeRedirectTarget(stage: SessionStage.loading, here: Routes.calendar),
        Routes.loading,
      );
    });
  });

  group('computeRedirectTarget -- unauthenticated', () {
    test('allows Routes.welcome', () {
      expect(
        computeRedirectTarget(stage: SessionStage.unauthenticated, here: Routes.welcome),
        isNull,
      );
    });

    test('allows Routes.auth (a forward step reached before userId is set)', () {
      expect(
        computeRedirectTarget(stage: SessionStage.unauthenticated, here: Routes.auth),
        isNull,
      );
    });

    test('redirects a couple-scoped route to Routes.welcome', () {
      expect(
        computeRedirectTarget(stage: SessionStage.unauthenticated, here: Routes.calendar),
        Routes.welcome,
      );
    });
  });

  group('computeRedirectTarget -- needsCouple', () {
    test('allows Routes.pairing, Routes.joinCode, and Routes.recover', () {
      for (final route in [Routes.pairing, Routes.joinCode, Routes.recover]) {
        expect(
          computeRedirectTarget(stage: SessionStage.needsCouple, here: route),
          isNull,
          reason: '$route should be allowed while needsCouple',
        );
      }
    });

    test('redirects anything else to Routes.pairing', () {
      expect(
        computeRedirectTarget(stage: SessionStage.needsCouple, here: Routes.home),
        Routes.pairing,
      );
    });
  });

  group('computeRedirectTarget -- needsWorkspace/needsGenesis/needsAvatar', () {
    test('needsWorkspace only allows Routes.workspace', () {
      expect(
        computeRedirectTarget(stage: SessionStage.needsWorkspace, here: Routes.workspace),
        isNull,
      );
      expect(
        computeRedirectTarget(stage: SessionStage.needsWorkspace, here: Routes.genesis),
        Routes.workspace,
        reason: 'jumping ahead to the next stage\'s screen must still redirect back',
      );
    });

    test('needsGenesis only allows Routes.genesis', () {
      expect(
        computeRedirectTarget(stage: SessionStage.needsGenesis, here: Routes.genesis),
        isNull,
      );
      expect(
        computeRedirectTarget(stage: SessionStage.needsGenesis, here: Routes.avatar),
        Routes.genesis,
      );
    });

    test('needsAvatar only allows Routes.avatar', () {
      expect(
        computeRedirectTarget(stage: SessionStage.needsAvatar, here: Routes.avatar),
        isNull,
      );
      expect(
        computeRedirectTarget(stage: SessionStage.needsAvatar, here: Routes.home),
        Routes.avatar,
      );
    });
  });

  group('computeRedirectTarget -- ready', () {
    test('allows Routes.home and any non-onboarding route', () {
      expect(computeRedirectTarget(stage: SessionStage.ready, here: Routes.home), isNull);
      expect(computeRedirectTarget(stage: SessionStage.ready, here: Routes.calendar), isNull);
      expect(computeRedirectTarget(stage: SessionStage.ready, here: Routes.license), isNull);
    });

    test('bounces every onboarding route to Routes.home', () {
      for (final route in [
        Routes.loading,
        Routes.welcome,
        Routes.auth,
        Routes.pairing,
        Routes.joinCode,
        Routes.recover,
        Routes.workspace,
        Routes.genesis,
        Routes.avatar,
      ]) {
        expect(
          computeRedirectTarget(stage: SessionStage.ready, here: route),
          Routes.home,
          reason: '$route must not be reachable once ready',
        );
      }
    });
  });

  group('computeRedirectTarget -- pending deep link replay', () {
    test('a valid pending location for the resolved stage is honored', () {
      // e.g. a notification tap for /calendar arrived while stage was
      // loading; stage has now resolved to ready.
      expect(
        computeRedirectTarget(
          stage: SessionStage.ready,
          here: Routes.loading,
          pendingLocation: Routes.calendar,
        ),
        Routes.calendar,
      );
    });

    test('an invalid pending location is redirected to the resolved stage\'s target instead', () {
      // e.g. a notification tap for /calendar arrived while stage was
      // loading, but hydration resolved to unauthenticated (the user was
      // never actually signed in) -- the deep link must not leak through.
      expect(
        computeRedirectTarget(
          stage: SessionStage.unauthenticated,
          here: Routes.loading,
          pendingLocation: Routes.calendar,
        ),
        Routes.welcome,
      );
    });

    test('a pending location that is itself already correct still resolves, not null', () {
      // Replaying /home when ready must actually navigate there -- the
      // router is still sitting at /loading, so "no redirect needed" (null)
      // would strand it, unlike the non-replay case where null means "stay
      // put" is already correct.
      expect(
        computeRedirectTarget(
          stage: SessionStage.ready,
          here: Routes.loading,
          pendingLocation: Routes.home,
        ),
        Routes.home,
      );
    });
  });
}
