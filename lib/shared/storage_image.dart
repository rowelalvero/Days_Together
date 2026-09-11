import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'package:days_together/core/network/auth_service.dart';
import 'package:days_together/core/security/key_management_service.dart';
import 'package:days_together/core/security/photo_encryption_service.dart';
import 'package:days_together/core/storage/storage_url_service.dart';

/// A dedicated disk cache, separate from `cached_network_image`'s
/// `DefaultCacheManager`, for objects fetched via [StorageImageBuilder].
///
/// Deliberately caches raw fetched bytes as-is -- ciphertext for anything
/// uploaded after E2EE photo encryption shipped, plaintext for anything
/// uploaded before it. Decryption always happens afterwards, in memory, in
/// [_StorageImageBuilderState]; this cache manager has no awareness of
/// encryption at all. That is what keeps ciphertext (not plaintext) on disk.
class _EncryptedPhotoCacheManager extends CacheManager {
  static const key = 'storageImageCache';

  static final _EncryptedPhotoCacheManager _instance = _EncryptedPhotoCacheManager._();

  factory _EncryptedPhotoCacheManager() => _instance;

  _EncryptedPhotoCacheManager._()
      : super(Config(key, stalePeriod: const Duration(days: 30), maxNrOfCacheObjects: 500));
}

/// A small in-memory (never disk) LRU cache of already-decrypted image bytes,
/// keyed by [StorageUrlService.cacheKeyFor]'s stable cache key.
///
/// Repeat renders within the same app session (e.g. scrolling a list back
/// into view) hit this instead of re-reading the on-disk ciphertext and
/// re-running AES-GCM decryption on every rebuild. Cleared on app restart,
/// which is fine -- the on-disk cache (ciphertext) still avoids re-fetching
/// from Supabase.
class _DecryptedBytesCache {
  _DecryptedBytesCache._();

  static final _DecryptedBytesCache instance = _DecryptedBytesCache._();

  static const int _maxEntries = 60;

  // A plain Map literal is a LinkedHashMap, so re-inserting a key moves it to
  // the end -- that plus "evict from the front" is a correct LRU with no
  // extra dependency.
  final Map<String, Uint8List> _entries = {};

  Uint8List? get(String key) {
    final value = _entries.remove(key);
    if (value != null) _entries[key] = value;
    return value;
  }

  void put(String key, Uint8List bytes) {
    if (key.isEmpty) return;
    _entries.remove(key);
    _entries[key] = bytes;
    while (_entries.length > _maxEntries) {
      _entries.remove(_entries.keys.first);
    }
  }

  void remove(String key) => _entries.remove(key);
}

/// Evicts any cached bytes for `[bucket]/[ref]` -- the on-disk ciphertext
/// (in [_EncryptedPhotoCacheManager]) and the in-memory decrypted plaintext
/// (in [_DecryptedBytesCache]). Call this whenever an object is overwritten
/// in place at the same storage path (an `upsert`), so the stale image
/// isn't shown until its cache entry would otherwise expire naturally.
///
/// This replaced direct `CachedNetworkImage.evictFromCache` calls once
/// [StorageImageBuilder] stopped using `CachedNetworkImageProvider` --
/// evicting that cache no longer has any effect on what this widget renders.
Future<void> evictStorageImageCache({required String bucket, required String? ref}) async {
  final key = StorageUrlService.cacheKeyFor(bucket: bucket, ref: ref);
  if (key.isEmpty) return;
  _DecryptedBytesCache.instance.remove(key);
  try {
    await _EncryptedPhotoCacheManager().removeFile(key);
  } catch (_) {
    // Best-effort; a miss here just means the entry expires naturally.
  }
}

/// Whether a [StorageImageBuilder]'s resolution is still in flight, produced
/// an image, or definitively failed.
///
/// The distinction matters because "no image yet" and "no image ever" want
/// opposite UI: a spinner for the first, an error affordance for the second.
/// Without it, an object that could not be resolved at all spun forever.
enum StorageImageStatus { resolving, resolved, failed }

/// Signature of [StorageImageBuilder.builder]. `retry` re-runs the whole
/// resolution ladder from the top -- useful after a [StorageImageStatus.failed]
/// caused by a transient condition (offline, or the couple's photo key not
/// having arrived yet).
typedef StorageImageWidgetBuilder =
    Widget Function(
      BuildContext context,
      ImageProvider? image,
      StorageImageStatus status,
      VoidCallback retry,
    );

/// Resolves a storage ref to an [ImageProvider] and hands it to [builder],
/// alongside a [StorageImageStatus] and a retry callback.
///
/// Use this where a raw provider is required — `CircleAvatar.backgroundImage`,
/// `DecorationImage`, and so on. For a plain image, prefer [StorageImage].
///
/// The resolution ladder, in order:
///  1. [localPath], when it exists on disk (an upload that has not synced yet)
///  2. already-decrypted bytes for this object, cached in memory from earlier
///     this session — resolved synchronously, so a rebuild never flashes a
///     placeholder
///  3. a signed URL (reusing a still-fresh one if available, else minting one),
///     then the object's bytes fetched (and disk-cached as ciphertext) via a
///     dedicated cache manager, decrypted with the couple's shared photo key,
///     and cached in-memory for next time
///  4. if no signed URL could be minted (offline, or denied), whatever
///     ciphertext already exists on disk under the stable cache key —
///     decrypted the same way — which is what keeps images working offline
///  5. null with [StorageImageStatus.failed], so the caller renders an error
///     affordance rather than a placeholder that never resolves
///
/// A legacy object uploaded before this feature existed is genuinely
/// plaintext, not ciphertext; decryption failing on one is expected and it
/// still renders. Ciphertext this device holds no key for is *not* treated
/// that way — it fails, and neither poisons the in-memory plaintext cache.
class StorageImageBuilder extends StatefulWidget {
  const StorageImageBuilder({
    super.key,
    required this.bucket,
    required this.storageRef,
    required this.builder,
    this.localPath,
    this.maxWidth,
    this.maxHeight,
  });

  /// One of the [StorageBuckets] constants.
  final String bucket;

  /// A bare object path, a legacy public URL, or a foreign URL. See
  /// [StorageUrlService].
  final String? storageRef;

  /// Optional on-device file to prefer over anything remote.
  final String? localPath;

  /// Optional decoding constraints to prevent decoding huge bitmaps into memory.
  final int? maxWidth;
  final int? maxHeight;

  final StorageImageWidgetBuilder builder;

  @override
  State<StorageImageBuilder> createState() => _StorageImageBuilderState();
}

class _StorageImageBuilderState extends State<StorageImageBuilder> {
  ImageProvider? _image;
  StorageImageStatus _status = StorageImageStatus.resolving;

  /// Incremented by every [_resolve] call. An in-flight [_resolveAsync]
  /// compares the token it captured against this before touching state, so a
  /// resolve that has been superseded -- the widget was recycled onto a
  /// different list row while its fetch was in flight -- discards its result
  /// instead of painting the previous row's photo onto the new one.
  ///
  /// This replaced a plain `_resolving` bool, which had the opposite effect:
  /// it made [didUpdateWidget] *skip* resolving the new ref entirely whenever
  /// a resolve was already running, so a recycled element kept showing (and
  /// then finished resolving to) the old image.
  int _resolveToken = 0;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(StorageImageBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storageRef != widget.storageRef ||
        oldWidget.bucket != widget.bucket ||
        oldWidget.localPath != widget.localPath) {
      _resolve();
    }
  }

  String get _cacheKey => StorageUrlService.cacheKeyFor(
        bucket: widget.bucket,
        ref: widget.storageRef,
      );

  void _retry() {
    if (!mounted) return;
    setState(_resolve);
  }

  void _resolve() {
    final token = ++_resolveToken;
    _image = null;
    _status = StorageImageStatus.resolving;

    // 1. Local file wins outright. This is the user's own device copy, never
    // encrypted at rest on-device -- only the uploaded server copy is.
    final localPath = widget.localPath;
    if (localPath != null && localPath.isNotEmpty) {
      final file = File(localPath);
      if (file.existsSync()) {
        _image = FileImage(file);
        _status = StorageImageStatus.resolved;
        return;
      }
    }

    final ref = widget.storageRef;
    if (ref == null || ref.trim().isEmpty) {
      _status = StorageImageStatus.failed;
      return;
    }

    // A ref that is itself a device path (an un-synced local image).
    if (StorageUrlService.isLocalFileRef(ref)) {
      final file = File(ref);
      if (file.existsSync()) {
        _image = FileImage(file);
        _status = StorageImageStatus.resolved;
      } else {
        _status = StorageImageStatus.failed;
      }
      return;
    }

    // 2. Already-decrypted this session — avoids a placeholder flash on
    // rebuild, and avoids re-decrypting on every rebuild.
    final cachedBytes = _DecryptedBytesCache.instance.get(_cacheKey);
    if (cachedBytes != null) {
      _image = _imageFromBytes(cachedBytes);
      _status = StorageImageStatus.resolved;
      return;
    }

    // 3./4. Async: mint/reuse a signed URL, fetch, decrypt.
    _resolveAsync(ref, token);
  }

  Future<void> _resolveAsync(String ref, int token) async {
    final url = StorageUrlService.instance.resolveCached(bucket: widget.bucket, ref: ref) ??
        await StorageUrlService.instance.resolve(bucket: widget.bucket, ref: ref);

    ImageProvider? resolvedImage;
    if (url != null) {
      resolvedImage = await _fetchAndDecrypt(url);
    }

    // Signing failed (offline, or denied), or the fetch itself failed —
    // fall back to whatever ciphertext is already on disk under the stable
    // cache key.
    resolvedImage ??= await _fromDiskCacheOnly();

    if (!mounted || token != _resolveToken) return;
    setState(() {
      _image = resolvedImage;
      _status = resolvedImage == null
          ? StorageImageStatus.failed
          : StorageImageStatus.resolved;
    });
  }

  Future<ImageProvider?> _fetchAndDecrypt(String url) async {
    try {
      final file = await _EncryptedPhotoCacheManager().getSingleFile(url, key: _cacheKey);
      return _decryptFile(file);
    } catch (_) {
      return null;
    }
  }

  Future<ImageProvider?> _fromDiskCacheOnly() async {
    final key = _cacheKey;
    if (key.isEmpty) return null;
    try {
      final cached = await _EncryptedPhotoCacheManager().getFileFromCache(key);
      if (cached != null) return _decryptFile(cached.file);
    } catch (_) {
      // Cache lookups are best-effort.
    }
    return null;
  }

  /// Returns a provider for [file]'s decrypted contents, or null when the
  /// bytes cannot be rendered at all -- which the caller reports as
  /// [StorageImageStatus.failed] rather than an endless placeholder.
  ///
  /// Only genuinely displayable bytes reach [_DecryptedBytesCache]. Two paths
  /// used to poison it with ciphertext for the rest of the session, leaving an
  /// image broken even after the couple key arrived: no key being available at
  /// all, and [PhotoEncryptionService.tryDecryptBytes]'s legacy-plaintext
  /// fallback silently returning the still-encrypted input. Decryption is
  /// therefore attempted via `decryptBytes`, whose thrown failure is
  /// distinguishable, rather than via the swallowing `tryDecryptBytes`.
  Future<ImageProvider?> _decryptFile(dynamic file) async {
    final rawBytes = await file.readAsBytes() as Uint8List;
    final userId = AuthService.instance.currentUserId;
    final coupleKey = userId == null ? null : await KeyManagementService.instance.loadCoupleKey(userId);

    if (coupleKey != null) {
      try {
        final plaintext = await PhotoEncryptionService.instance.decryptBytes(rawBytes, coupleKey);
        _DecryptedBytesCache.instance.put(_cacheKey, plaintext);
        return _imageFromBytes(plaintext);
      } catch (_) {
        // Not decryptable under this key. Falls through to the legacy check
        // below -- an object uploaded before E2EE shipped is genuinely
        // plaintext and must still render.
      }
    }

    // No couple key (exchange still in flight, or nobody signed in), or
    // decryption failed. Accept the bytes only if they actually are an image;
    // otherwise this is ciphertext this device cannot read *yet*, and treating
    // it as plaintext is exactly what used to cache ciphertext under the
    // plaintext cache key.
    if (!_looksLikeImageBytes(rawBytes)) return null;
    _DecryptedBytesCache.instance.put(_cacheKey, rawBytes);
    return _imageFromBytes(rawBytes);
  }

  ImageProvider _imageFromBytes(Uint8List bytes) {
    final ImageProvider provider = MemoryImage(bytes);
    if (widget.maxWidth == null && widget.maxHeight == null) return provider;
    return ResizeImage(provider, width: widget.maxWidth, height: widget.maxHeight);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _image, _status, _retry);
}

/// Whether [bytes] begin with the magic number of an image format Flutter can
/// decode. Used to tell a legacy (never-encrypted) object apart from
/// ciphertext this device holds no key for -- AES-GCM output is
/// indistinguishable from random, so it effectively never matches.
bool _looksLikeImageBytes(Uint8List bytes) {
  if (bytes.length < 12) return false;
  // JPEG
  if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return true;
  // PNG
  if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) {
    return true;
  }
  // GIF87a / GIF89a
  if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x38) {
    return true;
  }
  // BMP
  if (bytes[0] == 0x42 && bytes[1] == 0x4D) return true;
  // RIFF....WEBP
  if (bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return true;
  }
  // ISO base media (HEIC/AVIF): "ftyp" at offset 4.
  if (bytes[4] == 0x66 && bytes[5] == 0x74 && bytes[6] == 0x79 && bytes[7] == 0x70) {
    return true;
  }
  return false;
}

/// Displays an image stored in Supabase Storage.
///
/// Drop-in replacement for `Image.network` at any site that renders a storage
/// object. Handles signed-URL minting, the stable disk cache key, local-file
/// preference, and offline fallback — see [StorageImageBuilder].
class StorageImage extends StatelessWidget {
  const StorageImage({
    super.key,
    required this.bucket,
    required this.storageRef,
    this.localPath,
    this.fit,
    this.width,
    this.height,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.maxWidth,
    this.maxHeight,
  });

  final String bucket;
  final String? storageRef;
  final String? localPath;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final int? maxWidth;
  final int? maxHeight;

  /// Shown while resolving. Defaults to a neutral surface block.
  final WidgetBuilder? placeholder;

  /// Shown when the image cannot be resolved at all.
  final WidgetBuilder? errorWidget;

  @override
  Widget build(BuildContext context) {
    final effectiveMaxWidth = maxWidth ?? (width != null && width!.isFinite ? (width! * 2.5).toInt() : 800);
    final effectiveMaxHeight = maxHeight ?? (height != null && height!.isFinite ? (height! * 2.5).toInt() : null);

    return StorageImageBuilder(
      bucket: bucket,
      storageRef: storageRef,
      localPath: localPath,
      maxWidth: effectiveMaxWidth,
      maxHeight: effectiveMaxHeight,
      builder: (context, image, status, retry) {
        final Widget child;
        if (image == null) {
          // Keyed off the resolution status rather than "is there a ref":
          // a ref that exists but cannot be resolved is a *failure*, and
          // showing the placeholder for it left a spinner running forever
          // with no way out.
          final hasRef = storageRef != null && storageRef!.trim().isNotEmpty;
          child = switch (status) {
            StorageImageStatus.resolving =>
              placeholder?.call(context) ?? _defaultPlaceholder(context),
            _ => errorWidget?.call(context) ??
                _defaultError(context, hasRef ? retry : null),
          };
        } else {
          child = Image(
            image: image,
            fit: fit,
            width: width,
            height: height,
            errorBuilder: (context, _, _) =>
                errorWidget?.call(context) ?? _defaultError(context, retry),
          );
        }

        final sized = SizedBox(width: width, height: height, child: child);
        return borderRadius == null
            ? sized
            : ClipRRect(borderRadius: borderRadius!, child: sized);
      },
    );
  }

  Widget _defaultPlaceholder(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  /// Tappable, because the most common causes of failure here are transient:
  /// the device was offline when the signed URL was minted, or the couple's
  /// photo key had not finished exchanging yet. [retry] re-runs the full
  /// resolution ladder.
  Widget _defaultError(BuildContext context, VoidCallback? retry) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: retry,
      child: ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: Center(
          child: Icon(
            // Nothing to retry when there was never a ref to resolve.
            retry == null ? Icons.broken_image_outlined : Icons.refresh_rounded,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}
