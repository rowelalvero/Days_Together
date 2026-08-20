import 'package:flutter_test/flutter_test.dart';
import 'package:days_together/services/storage_url_service.dart';

/// These cover the pure classification/parsing surface of [StorageUrlService],
/// which is where a subtle bug would silently corrupt every stored image ref.
/// They deliberately avoid the async signing path, which needs a live Supabase
/// client.
void main() {
  const proj = 'https://mfyfbzyfzlhrpcfxtlmu.supabase.co';

  group('isLocalFileRef', () {
    test('recognises POSIX, Windows and file:// paths', () {
      expect(
        StorageUrlService.isLocalFileRef('/data/user/0/com.app/cache/img.jpg'),
        isTrue,
      );
      expect(StorageUrlService.isLocalFileRef(r'C:\Users\me\img.jpg'), isTrue);
      expect(StorageUrlService.isLocalFileRef('C:/Users/me/img.jpg'), isTrue);
      expect(StorageUrlService.isLocalFileRef('file:///tmp/img.jpg'), isTrue);
    });

    test('does not treat a storage path or URL as a local file', () {
      // This is the regression that would break every image: once columns hold
      // bare paths, the old `startsWith('http')` test inverted and classified
      // storage paths as local files.
      expect(
        StorageUrlService.isLocalFileRef('couples/abc/avatars/u_1.jpg'),
        isFalse,
      );
      expect(
        StorageUrlService.isLocalFileRef('$proj/storage/v1/object/public/avatars/x.jpg'),
        isFalse,
      );
    });

    test('handles null and empty', () {
      expect(StorageUrlService.isLocalFileRef(null), isFalse);
      expect(StorageUrlService.isLocalFileRef(''), isFalse);
      expect(StorageUrlService.isLocalFileRef('   '), isFalse);
    });
  });

  group('pathFrom — legacy URLs', () {
    test('extracts the path from a legacy public URL', () {
      final url =
          '$proj/storage/v1/object/public/vault-photos/couples/c1/vault_photos/p1.jpg';
      expect(
        StorageUrlService.pathFrom(url, bucket: StorageBuckets.vaultPhotos),
        'couples/c1/vault_photos/p1.jpg',
      );
    });

    test('strips the legacy ?t= cache-buster', () {
      final url =
          '$proj/storage/v1/object/public/avatars/couples/c1/avatars/u1_1700000000.jpg?t=1700000000';
      expect(
        StorageUrlService.pathFrom(url, bucket: StorageBuckets.avatars),
        'couples/c1/avatars/u1_1700000000.jpg',
      );
    });

    test('handles an already-signed URL that was persisted by mistake', () {
      final url =
          '$proj/storage/v1/object/sign/timeline/couples/c1/timeline/t1.jpg?token=abc.def';
      expect(
        StorageUrlService.pathFrom(url, bucket: StorageBuckets.timeline),
        'couples/c1/timeline/t1.jpg',
      );
    });

    test('handles the authenticated route', () {
      final url =
          '$proj/storage/v1/object/authenticated/love-notes/couples/c1/love_notes/n1.jpg';
      expect(
        StorageUrlService.pathFrom(url, bucket: StorageBuckets.loveNotes),
        'couples/c1/love_notes/n1.jpg',
      );
    });

    test('rejects a URL belonging to a different bucket', () {
      // Must not cross-key: signing this against `avatars` would fail anyway,
      // but a wrong cacheKey would collide across buckets.
      final url =
          '$proj/storage/v1/object/public/vault-photos/couples/c1/vault_photos/p1.jpg';
      expect(
        StorageUrlService.pathFrom(url, bucket: StorageBuckets.avatars),
        isNull,
      );
    });

    test('returns null for a foreign host (Google OAuth avatar)', () {
      const url = 'https://lh3.googleusercontent.com/a/ACg8ocK=s96-c';
      expect(
        StorageUrlService.pathFrom(url, bucket: StorageBuckets.avatars),
        isNull,
      );
      expect(StorageUrlService.isHttpUrl(url), isTrue);
    });
  });

  group('pathFrom — bare paths', () {
    test('passes a bare path through unchanged', () {
      expect(
        StorageUrlService.pathFrom(
          'couples/c1/timeline/t1.jpg',
          bucket: StorageBuckets.timeline,
        ),
        'couples/c1/timeline/t1.jpg',
      );
    });

    test('strips a leading slash from a storage ref', () {
      // A leading slash is ambiguous against Android file paths. It resolves in
      // favour of storage only because of the `couples/` root segment; see
      // isLocalFileRef. Getting this backwards would make the avatar sync try
      // to re-upload a file that does not exist.
      expect(
        StorageUrlService.pathFrom(
          '/couples/c1/timeline/t1.jpg',
          bucket: StorageBuckets.timeline,
        ),
        'couples/c1/timeline/t1.jpg',
      );
      expect(
        StorageUrlService.isLocalFileRef('/couples/c1/timeline/t1.jpg'),
        isFalse,
      );
    });

    test('still treats a real device path as a local file', () {
      expect(
        StorageUrlService.isLocalFileRef('/storage/emulated/0/DCIM/img.jpg'),
        isTrue,
      );
      expect(
        StorageUrlService.pathFrom(
          '/storage/emulated/0/DCIM/img.jpg',
          bucket: StorageBuckets.timeline,
        ),
        isNull,
      );
    });

    test('strips a redundant leading bucket segment', () {
      expect(
        StorageUrlService.pathFrom(
          'vault-photos/couples/c1/vault_photos/p1.jpg',
          bucket: StorageBuckets.vaultPhotos,
        ),
        'couples/c1/vault_photos/p1.jpg',
      );
    });

    test('returns null for a local file path', () {
      expect(
        StorageUrlService.pathFrom(
          '/data/user/0/com.app/cache/img.jpg',
          bucket: StorageBuckets.vaultPhotos,
        ),
        isNull,
      );
    });

    test('returns null for null and empty refs', () {
      expect(
        StorageUrlService.pathFrom(null, bucket: StorageBuckets.avatars),
        isNull,
      );
      expect(
        StorageUrlService.pathFrom('', bucket: StorageBuckets.avatars),
        isNull,
      );
      expect(
        StorageUrlService.pathFrom('   ', bucket: StorageBuckets.avatars),
        isNull,
      );
    });
  });

  group('cacheKeyFor', () {
    test('is stable across the legacy URL and the bare path for one object', () {
      // The whole point: a signed URL rotates, but the cacheKey must not, or
      // cached_network_image re-downloads every image on every rotation.
      const path = 'couples/c1/avatars/u1_1700000000.jpg';
      final legacy =
          '$proj/storage/v1/object/public/avatars/$path?t=1700000000';

      final fromPath = StorageUrlService.cacheKeyFor(
        bucket: StorageBuckets.avatars,
        ref: path,
      );
      final fromLegacy = StorageUrlService.cacheKeyFor(
        bucket: StorageBuckets.avatars,
        ref: legacy,
      );

      expect(fromPath, fromLegacy);
      expect(fromPath, 'avatars|$path');
    });

    test('does not collide across buckets for identical sub-paths', () {
      const path = 'couples/c1/shared/x.jpg';
      expect(
        StorageUrlService.cacheKeyFor(bucket: StorageBuckets.timeline, ref: path),
        isNot(
          StorageUrlService.cacheKeyFor(
            bucket: StorageBuckets.vaultPhotos,
            ref: path,
          ),
        ),
      );
    });

    test('falls back to the URL itself for a foreign avatar', () {
      const url = 'https://lh3.googleusercontent.com/a/ACg8ocK=s96-c';
      expect(
        StorageUrlService.cacheKeyFor(bucket: StorageBuckets.avatars, ref: url),
        url,
      );
    });

    test('is empty for a local file ref', () {
      expect(
        StorageUrlService.cacheKeyFor(
          bucket: StorageBuckets.avatars,
          ref: '/data/user/0/com.app/cache/img.jpg',
        ),
        '',
      );
    });
  });

  group('resolveCached', () {
    test('passes a foreign URL straight through without signing', () {
      const url = 'https://lh3.googleusercontent.com/a/ACg8ocK=s96-c';
      expect(
        StorageUrlService.instance
            .resolveCached(bucket: StorageBuckets.avatars, ref: url),
        url,
      );
    });

    test('returns null for an unsigned storage path (cache miss)', () {
      expect(
        StorageUrlService.instance.resolveCached(
          bucket: StorageBuckets.avatars,
          ref: 'couples/c1/avatars/u1_1.jpg',
        ),
        isNull,
      );
    });

    test('returns null for a local file ref', () {
      expect(
        StorageUrlService.instance.resolveCached(
          bucket: StorageBuckets.vaultPhotos,
          ref: '/data/user/0/com.app/cache/img.jpg',
        ),
        isNull,
      );
    });
  });
}
