import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Canonical Supabase Storage bucket names.
///
/// Every object in every bucket follows the path convention
/// `couples/{coupleId}/{feature}/{file}`, which the storage RLS policies rely
/// on (`storage.foldername(name)[2]` is always the coupleId).
class StorageBuckets {
  StorageBuckets._();

  static const String avatars = 'avatars';
  static const String timeline = 'timeline';
  static const String vaultPhotos = 'vault-photos';
  static const String loveNotes = 'love-notes';
}

class _SignedEntry {
  final String url;
  final DateTime expiresAt;
  const _SignedEntry(this.url, this.expiresAt);
}

class _NegativeEntry {
  final DateTime until;

  /// True only when the object is definitively gone (HTTP 404). Callers may
  /// clear a stored ref on this; they must NOT clear on transient failures.
  final bool notFound;
  const _NegativeEntry(this.until, this.notFound);
}

/// Resolves a stored *storage ref* into a usable image URL.
///
/// The buckets are private, so images can only be fetched through short-lived
/// signed URLs. Those URLs must never be persisted — they expire, and they
/// embed a token. So the database and all local caches store a stable **path**,
/// and this service mints signed URLs on demand and holds them in memory only.
///
/// A "ref" is any of:
///  * a bare object path — `couples/{id}/vault_photos/{x}.jpg` (the current format)
///  * a legacy public URL — `https://…/storage/v1/object/public/{bucket}/{path}?t=1`
///  * a foreign absolute URL — e.g. a Google OAuth avatar; passed through as-is
///  * an absolute device file path — not a storage ref; the caller renders a [File]
class StorageUrlService {
  StorageUrlService._();

  static final StorageUrlService instance = StorageUrlService._();

  /// Signed-URL lifetime. Generous because the token never touches disk, so a
  /// short TTL buys little security while costing a round-trip per image.
  static const Duration ttl = Duration(hours: 4);

  /// A cached URL is treated as stale this long before it actually expires, so
  /// a slow or queued image fetch can never race the expiry.
  static const Duration refreshMargin = Duration(minutes: 30);

  /// How long a failed signing attempt is remembered, so a legitimately denied
  /// object (vault locked, unlinked partner) doesn't hammer the endpoint.
  static const Duration negativeTtl = Duration(seconds: 30);

  final Map<String, _SignedEntry> _cache = {};
  final Map<String, _NegativeEntry> _negative = {};
  final Map<String, Completer<String?>> _inFlight = {};
  final Map<String, Set<String>> _pending = {};
  Timer? _flushTimer;

  // ---------------------------------------------------------------------
  // Pure helpers. No I/O and no Supabase access, so they are unit-testable
  // without initialising the SDK.
  // ---------------------------------------------------------------------

  /// Every storage object path starts with this segment — see the convention
  /// documented on [StorageBuckets].
  static const String _storageRootSegment = 'couples';

  /// True when [ref] points at a file on this device rather than at storage.
  static bool isLocalFileRef(String? ref) {
    if (ref == null) return false;
    final value = ref.trim();
    if (value.isEmpty) return false;
    if (isHttpUrl(value)) return false;
    if (value.startsWith('file://')) return true;

    // A leading slash is ambiguous: Android file paths look like
    // `/data/user/0/…`, but a slightly malformed storage ref could arrive as
    // `/couples/…`. Disambiguate on the storage root segment, because the wrong
    // call in this direction is costly — a storage ref misread as a device path
    // makes the avatar sync try to re-upload a file that does not exist.
    final withoutLeadingSlashes = value.replaceFirst(RegExp(r'^/+'), '');
    if (withoutLeadingSlashes.startsWith('$_storageRootSegment/')) return false;

    if (value.startsWith('/')) return true;
    // Windows drive paths (C:\… or C:/…), used by tests and desktop builds.
    if (RegExp(r'^[A-Za-z]:[\\/]').hasMatch(value)) return true;
    return false;
  }

  /// True when [ref] is an absolute http(s) URL.
  static bool isHttpUrl(String? ref) {
    if (ref == null) return false;
    final value = ref.trim();
    return value.startsWith('http://') || value.startsWith('https://');
  }

  /// Extracts the object path for [bucket] from [ref], or null when [ref] is
  /// not an object in that bucket (local file, foreign URL, another bucket).
  static String? pathFrom(String? ref, {required String bucket}) {
    if (ref == null) return null;
    final value = ref.trim();
    if (value.isEmpty) return null;
    if (isLocalFileRef(value)) return null;

    if (!isHttpUrl(value)) {
      // Already a bare path. Normalise: drop any query, a leading slash, and a
      // redundant leading '{bucket}/' segment.
      var path = value.split('?').first;
      while (path.startsWith('/')) {
        path = path.substring(1);
      }
      if (path.startsWith('$bucket/')) {
        path = path.substring(bucket.length + 1);
      }
      return path.isEmpty ? null : path;
    }

    // An absolute URL. Look for the Supabase object route and confirm it points
    // at *this* bucket, so a URL for another bucket is rejected rather than
    // silently cross-keyed. Reading pathSegments also drops any `?t=` query and
    // percent-decodes each segment.
    final Uri uri;
    try {
      uri = Uri.parse(value);
    } catch (_) {
      return null;
    }

    final segments = uri.pathSegments;
    for (var i = 0; i + 4 < segments.length; i++) {
      final isObjectRoute = segments[i] == 'storage' &&
          segments[i + 1] == 'v1' &&
          segments[i + 2] == 'object';
      if (!isObjectRoute) continue;

      final scope = segments[i + 3];
      if (scope != 'public' && scope != 'sign' && scope != 'authenticated') {
        continue;
      }
      if (segments[i + 4] != bucket) return null; // different bucket

      final rest = segments.sublist(i + 5);
      if (rest.isEmpty) return null;
      return rest.join('/');
    }

    // A foreign URL (e.g. a Google OAuth avatar).
    return null;
  }

  /// Stable cache key for [ref]. Used as the explicit `cacheKey` for
  /// `CachedNetworkImage`, because the signed URL itself changes on every
  /// rotation and would otherwise defeat the disk cache entirely.
  static String cacheKeyFor({required String bucket, required String? ref}) {
    final path = pathFrom(ref, bucket: bucket);
    if (path != null) return '$bucket|$path';
    if (isHttpUrl(ref)) return ref!.trim();
    return '';
  }

  // ---------------------------------------------------------------------
  // Resolution
  // ---------------------------------------------------------------------

  /// Synchronous fast path: returns an already-signed, still-fresh URL, or null
  /// on a cache miss. Lets widgets render without a [FutureBuilder] flicker on
  /// rebuild.
  String? resolveCached({required String bucket, required String? ref}) {
    if (ref == null || ref.trim().isEmpty) return null;
    if (isLocalFileRef(ref)) return null;

    final path = pathFrom(ref, bucket: bucket);
    if (path == null) return isHttpUrl(ref) ? ref.trim() : null;

    final entry = _cache['$bucket|$path'];
    if (entry == null) return null;
    return DateTime.now().isBefore(entry.expiresAt.subtract(refreshMargin))
        ? entry.url
        : null;
  }

  /// Resolves [ref] to a usable URL, signing it if necessary.
  ///
  /// Returns null when the ref is a local file, is unresolvable, or signing
  /// failed. Never throws.
  Future<String?> resolve({
    required String bucket,
    required String? ref,
  }) async {
    if (ref == null || ref.trim().isEmpty) return null;
    if (isLocalFileRef(ref)) return null;

    final path = pathFrom(ref, bucket: bucket);
    if (path == null) return isHttpUrl(ref) ? ref.trim() : null;

    final key = '$bucket|$path';
    final now = DateTime.now();

    final cached = _cache[key];
    if (cached != null && now.isBefore(cached.expiresAt.subtract(refreshMargin))) {
      return cached.url;
    }

    final negative = _negative[key];
    if (negative != null && now.isBefore(negative.until)) return null;

    final existing = _inFlight[key];
    if (existing != null) return existing.future;

    final completer = Completer<String?>();
    _inFlight[key] = completer;
    _enqueue(bucket, path);
    return completer.future;
  }

  /// Signs many refs up front in one batched request. Call after a sync so a
  /// long list doesn't fire one signing request per row on first paint.
  Future<void> prewarm({
    required String bucket,
    required Iterable<String?> refs,
  }) async {
    final futures = <Future<String?>>[];
    for (final ref in refs) {
      futures.add(resolve(bucket: bucket, ref: ref));
    }
    await Future.wait(futures);
  }

  /// True when the last failure for [ref] was a definitive 404. Only then may a
  /// caller clear a stored ref — a transient network failure must never delete
  /// a user's avatar.
  bool lastFailureWasNotFound({required String bucket, required String? ref}) {
    final path = pathFrom(ref, bucket: bucket);
    if (path == null) return false;
    return _negative['$bucket|$path']?.notFound ?? false;
  }

  /// Drops the in-memory signed URL for [ref]. Callers that overwrite an object
  /// at the same path should also evict the `cached_network_image` entry using
  /// [cacheKeyFor].
  Future<void> evict({required String bucket, required String? ref}) async {
    final path = pathFrom(ref, bucket: bucket);
    if (path == null) return;
    final key = '$bucket|$path';
    _cache.remove(key);
    _negative.remove(key);
  }

  /// Clears every cached URL. Call on sign-out / unlink so a signed URL for the
  /// previous account cannot be reused.
  void clearAll() {
    _cache.clear();
    _negative.clear();
    _pending.clear();
    _flushTimer?.cancel();
    _flushTimer = null;
    for (final completer in _inFlight.values) {
      if (!completer.isCompleted) completer.complete(null);
    }
    _inFlight.clear();
  }

  // ---------------------------------------------------------------------
  // Batching
  // ---------------------------------------------------------------------

  void _enqueue(String bucket, String path) {
    (_pending[bucket] ??= <String>{}).add(path);
    // Coalesce every resolve() issued during this frame into one request per
    // bucket. Without this a 200-item timeline fires 200 signing requests.
    _flushTimer ??= Timer(Duration.zero, _flush);
  }

  Future<void> _flush() async {
    _flushTimer = null;
    if (_pending.isEmpty) return;

    final batches = Map<String, Set<String>>.from(_pending);
    _pending.clear();

    for (final entry in batches.entries) {
      await _signBatch(entry.key, entry.value.toList(growable: false));
    }
  }

  Future<void> _signBatch(String bucket, List<String> paths) async {
    if (paths.isEmpty) return;

    try {
      final results = await Supabase.instance.client.storage
          .from(bucket)
          .createSignedUrlsResult(paths, ttl.inSeconds);

      final now = DateTime.now();
      final resolved = <String>{};

      for (final result in results) {
        resolved.add(result.path);
        final key = '$bucket|${result.path}';
        switch (result) {
          case SignedUrlSuccess(:final signedUrl):
            _cache[key] = _SignedEntry(signedUrl, now.add(ttl));
            _negative.remove(key);
            _complete(key, signedUrl);
          case SignedUrlFailure(:final error):
            // Never log the URL itself; it carries a bearer token.
            debugPrint('StorageUrlService: could not sign $key ($error)');
            _negative[key] = _NegativeEntry(
              now.add(negativeTtl),
              _looksNotFound(error),
            );
            _complete(key, null);
        }
      }

      // Defensive: complete anything the server did not echo back, so a waiting
      // caller can never hang on an unfulfilled completer.
      for (final path in paths) {
        if (!resolved.contains(path)) {
          final key = '$bucket|$path';
          _negative[key] = _NegativeEntry(now.add(negativeTtl), false);
          _complete(key, null);
        }
      }
    } catch (e) {
      // The batch endpoint failed wholesale (offline, 5xx). Fall back to
      // signing individually so one bad path can't blank an entire screen.
      debugPrint('StorageUrlService: batch signing failed for $bucket ($e)');
      for (final path in paths) {
        await _signSingle(bucket, path);
      }
    }
  }

  Future<void> _signSingle(String bucket, String path) async {
    final key = '$bucket|$path';
    try {
      final url = await Supabase.instance.client.storage
          .from(bucket)
          .createSignedUrl(path, ttl.inSeconds);
      _cache[key] = _SignedEntry(url, DateTime.now().add(ttl));
      _negative.remove(key);
      _complete(key, url);
    } on StorageException catch (e) {
      final notFound = e.statusCode == '404' || _looksNotFound(e.message);
      debugPrint('StorageUrlService: could not sign $key (${e.message})');
      _negative[key] = _NegativeEntry(DateTime.now().add(negativeTtl), notFound);
      _complete(key, null);
    } catch (e) {
      debugPrint('StorageUrlService: could not sign $key ($e)');
      _negative[key] = _NegativeEntry(DateTime.now().add(negativeTtl), false);
      _complete(key, null);
    }
  }

  void _complete(String key, String? url) {
    final completer = _inFlight.remove(key);
    if (completer != null && !completer.isCompleted) {
      completer.complete(url);
    }
  }

  static bool _looksNotFound(String? error) {
    if (error == null) return false;
    final normalised = error.toLowerCase();
    return normalised.contains('not found') || normalised.contains('notfound');
  }
}
