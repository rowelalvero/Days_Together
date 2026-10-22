// Android must not back up or device-transfer app data (audit F-22):
// SharedPreferences mirror the partner's PII and the feature caches, and a
// restored FlutterSecureStorage cannot decrypt on another device.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final manifest = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync();

  test('the <application> element disables backup', () {
    expect(manifest, contains('<application'));
    expect(manifest, contains('android:allowBackup="false"'));
    expect(
      manifest,
      contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
    );
  });

  test(
    'Android 12+ rules exclude every domain from cloud backup and transfer',
    () {
      final rules = File(
        'android/app/src/main/res/xml/data_extraction_rules.xml',
      ).readAsStringSync();
      for (final section in ['cloud-backup', 'device-transfer']) {
        final body = RegExp(
          '<$section>(.*?)</$section>',
          dotAll: true,
        ).firstMatch(rules)?.group(1);
        expect(body, isNotNull, reason: section);
        for (final domain in [
          'root',
          'file',
          'database',
          'sharedpref',
          'external',
        ]) {
          expect(
            body,
            contains('<exclude domain="$domain" path="." />'),
            reason: '$section/$domain',
          );
        }
      }
    },
  );
}
