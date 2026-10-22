// Covers StorageImage/StorageImageBuilder's resolution *status*, the fix for
// an unresolvable object rendering the placeholder spinner forever with no
// way out (it now reports StorageImageStatus.failed, which StorageImage
// renders as a tappable retry affordance).
//
// Scope note: the two other storage_image fixes -- the resolve-generation
// token that stops a recycled list element from painting the previous row's
// photo, and refusing to cache undecryptable ciphertext as if it were
// plaintext -- are not exercised here. Both live behind
// `StorageUrlService.instance` and `_EncryptedPhotoCacheManager`, which are
// hard-wired singletons with no injection seam, so reaching them from a test
// would mean refactoring production code purely for testability. What is
// covered below is everything decidable without network or platform
// channels.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:days_together/shared/widgets/storage_image.dart';

void main() {
  group('StorageImage -- no ref', () {
    testWidgets('renders the error widget, never a placeholder spinner', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: StorageImage(
            bucket: 'timeline',
            storageRef: null,
            width: 40,
            height: 40,
          ),
        ),
      );

      // Regression: a null/empty ref left _image null, and StorageImage chose
      // its child on "is there a ref" rather than on the resolution status.
      // That was correct here but wrong for a ref that failed to resolve --
      // the two cases are now one status check.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    });

    testWidgets('offers no retry when there was never anything to resolve', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: StorageImage(
            bucket: 'timeline',
            storageRef: '   ',
            width: 40,
            height: 40,
          ),
        ),
      );

      expect(find.byIcon(Icons.refresh_rounded), findsNothing);
      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    });

    testWidgets('honors a caller-supplied errorWidget', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: StorageImage(
            bucket: 'timeline',
            storageRef: null,
            width: 40,
            height: 40,
            errorWidget: (_) => const Text('gone'),
          ),
        ),
      );

      expect(find.text('gone'), findsOneWidget);
    });
  });

  group('StorageImageBuilder -- status reporting', () {
    testWidgets('a missing ref resolves synchronously to failed', (
      tester,
    ) async {
      final statuses = <StorageImageStatus>[];

      await tester.pumpWidget(
        MaterialApp(
          home: StorageImageBuilder(
            bucket: 'timeline',
            storageRef: null,
            builder: (context, image, status, _) {
              statuses.add(status);
              expect(image, isNull);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(statuses, isNotEmpty);
      expect(statuses.last, StorageImageStatus.failed);
    });

    testWidgets(
      'a local ref that does not exist on disk is failed, not resolving',
      (tester) async {
        final missing =
            '${Directory.systemTemp.path}${Platform.pathSeparator}nope_${DateTime.now().microsecondsSinceEpoch}.jpg';
        StorageImageStatus? last;

        await tester.pumpWidget(
          MaterialApp(
            home: StorageImageBuilder(
              bucket: 'timeline',
              storageRef: missing,
              builder: (context, image, status, _) {
                last = status;
                return const SizedBox();
              },
            ),
          ),
        );

        expect(last, StorageImageStatus.failed);
      },
    );
  });

  group('StorageImageBuilder -- local files', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('storage_image_test');
    });

    tearDown(() async {
      if (dir.existsSync()) await dir.delete(recursive: true);
    });

    File writeFile(String name) {
      final file = File('${dir.path}${Platform.pathSeparator}$name');
      // Contents are irrelevant -- nothing decodes them; FileImage is only
      // constructed, never resolved, because no Image widget is built here.
      file.writeAsBytesSync(List<int>.filled(16, 0));
      return file;
    }

    testWidgets('localPath wins outright and resolves synchronously', (
      tester,
    ) async {
      final file = writeFile('a.jpg');
      ImageProvider? resolved;
      StorageImageStatus? status;

      await tester.pumpWidget(
        MaterialApp(
          home: StorageImageBuilder(
            bucket: 'timeline',
            storageRef: 'couples/c1/photos/remote.jpg',
            localPath: file.path,
            builder: (context, image, s, _) {
              resolved = image;
              status = s;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(status, StorageImageStatus.resolved);
      expect((resolved as FileImage).file.path, file.path);
    });

    testWidgets(
      'a changed localPath re-resolves instead of keeping the old image',
      (tester) async {
        final first = writeFile('first.jpg');
        final second = writeFile('second.jpg');
        ImageProvider? resolved;

        Widget build(String path) => MaterialApp(
          home: StorageImageBuilder(
            bucket: 'timeline',
            storageRef: null,
            localPath: path,
            builder: (context, image, _, _) {
              resolved = image;
              return const SizedBox();
            },
          ),
        );

        await tester.pumpWidget(build(first.path));
        expect((resolved as FileImage).file.path, first.path);

        // The same element, pointed at a different object -- what happens when
        // a list recycles a row.
        await tester.pumpWidget(build(second.path));
        expect((resolved as FileImage).file.path, second.path);
      },
    );
  });
}
