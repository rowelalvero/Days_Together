// Secret scanning, run with every `flutter test`.
//
// A Firebase service-account private key was committed once (4c7e2f7, later
// rewritten out of history) and `.mcp.json`, which points at it, was tracked
// despite being in .gitignore. This fails the build if credential material is
// tracked again -- or is sitting untracked-but-not-ignored, i.e. one `git add
// .` away from being committed.
//
// Scans exactly what git would commit: `git ls-files` (tracked) plus
// `git ls-files --others --exclude-standard` (untracked, not ignored). The
// patterns are assembled from fragments so this file does not match itself.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

List<String> _git(List<String> args) {
  final result = Process.runSync('git', args, stdoutEncoding: utf8);
  if (result.exitCode != 0) {
    fail('git ${args.join(' ')} failed: ${result.stderr}');
  }
  return (result.stdout as String)
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
}

final _secretPatterns = <String, RegExp>{
  // The header followed by an actual base64 body -- raw newlines, or the
  // `\n` escapes a key has inside service-account JSON. A bare header string
  // (the edge function's PEM-parsing delimiter) is not key material.
  'PEM private key': RegExp(
    '-----BEGIN [A-Z ]*'
    r'PRIVATE KEY-----(?:\s|\\n)+[A-Za-z0-9+/=]{40,}',
  ),
  'Google service-account JSON': RegExp(
    r'"type"\s*:\s*"service_'
    'account"',
  ),
  'Supabase secret API key': RegExp(
    'sb_'
    r'secret_[A-Za-z0-9_-]{10,}',
  ),
  'AWS access key id': RegExp(
    'AKIA'
    r'[0-9A-Z]{16}',
  ),
};

const _skipExtensions = {
  '.png', '.jpg', '.jpeg', '.gif', '.webp', '.ico', '.ttf', '.otf', //
  '.mp3', '.wav', '.jar', '.zip', '.so', '.a', '.keystore', '.jks',
};

void main() {
  late List<String> committable;

  setUpAll(() {
    committable = {
      ..._git(['ls-files']),
      ..._git(['ls-files', '--others', '--exclude-standard']),
    }.toList();
  });

  test('scans a real file set (cannot pass vacuously)', () {
    expect(committable.length, greaterThan(300));
    expect(committable, contains('pubspec.yaml'));
    expect(committable, contains('lib/main.dart'));
  });

  test('credential files are not committable', () {
    for (final path in ['service-account.json', '.mcp.json', '.env']) {
      expect(committable, isNot(contains(path)), reason: path);
    }
    // ...and stay ignored even if recreated.
    final ignored = Process.runSync('git', [
      'check-ignore',
      'service-account.json',
      'prod-service-account.json',
      '.mcp.json',
      '.env',
      '.env.production',
      'android/key.properties',
    ]);
    expect(
      LineSplitter.split(ignored.stdout as String).length,
      6,
      reason: 'git check-ignore output:\n${ignored.stdout}',
    );
  });

  test('no committable file contains credential material', () {
    final hits = <String>[];
    for (final path in committable) {
      final dot = path.lastIndexOf('.');
      if (dot != -1 &&
          _skipExtensions.contains(path.substring(dot).toLowerCase())) {
        continue;
      }
      final file = File(path);
      if (!file.existsSync() || file.lengthSync() > 2 * 1024 * 1024) continue;
      final content = utf8.decode(file.readAsBytesSync(), allowMalformed: true);
      for (final entry in _secretPatterns.entries) {
        if (entry.value.hasMatch(content)) hits.add('$path: ${entry.key}');
      }
    }
    expect(hits, isEmpty, reason: hits.join('\n'));
  });
}
