// Startup must not wait on notification setup (performance, Phase 5):
// NotificationService.init() brings up Firebase and requests notification
// permission -- on Android 13+ a system dialog -- and used to run, awaited,
// before runApp, holding the app's first frame behind it.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'runApp comes before NotificationService.init(), which is post-frame',
    () {
      final source = File('lib/main.dart').readAsStringSync();
      final runApp = source.indexOf('runApp(');
      final init = source.indexOf('NotificationService().init()');
      final postFrame = source.indexOf('addPostFrameCallback((_) async {');

      expect(runApp, greaterThan(-1));
      expect(init, greaterThan(-1));
      expect(
        runApp,
        lessThan(init),
        reason: 'init must not gate the first frame',
      );
      expect(postFrame, inInclusiveRange(runApp, init));
    },
  );
}
