import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'package:days_together/services/auth_service.dart';
import 'package:days_together/services/key_management_service.dart';
import 'package:days_together/services/photo_encryption_service.dart';
import 'package:days_together/services/storage_url_service.dart';

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

/// Resolves a storage ref to an [ImageProvider] and hands it to [builder].
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
///  5. null, so the caller renders its own placeholder
///
/// Decryption failure (a legacy object uploaded before this feature existed,
/// which is genuinely plaintext, not ciphertext) falls back to treating the
/// fetched bytes as already-plaintext — see
/// [PhotoEncryptionService.tryDecryptBytes].
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

  final Widget Function(BuildContext context, ImageProvider? image) builder;

  @override
  State<StorageImageBuilder> createState() => _StorageImageBuilderState();
}

class _StorageImageBuilderState extends State<StorageImageBuilder> {
  ImageProvider? _image;
  bool _resolving = false;

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
      _image = null;
      _resolve();
    }
  }

  String get _cacheKey => StorageUrlService.cacheKeyFor(
        bucket: widget.bucket,
        ref: widget.storageRef,
      );

  void _resolve() {
    // 1. Local file wins outright. This is the user's own device copy, never
    // encrypted at rest on-device -- only the uploaded server copy is.
    final localPath = widget.localPath;
    if (localPath != null && localPath.isNotEmpty) {
      final file = File(localPath);
      if (file.existsSync()) {
        _image = FileImage(file);
        return;
      }
    }

    final ref = widget.storageRef;
    if (ref == null || ref.trim().isEmpty) {
      _image = null;
      return;
    }

    // A ref that is itself a device path (an un-synced local image).
    if (StorageUrlService.isLocalFileRef(ref)) {
      final file = File(ref);
      if (file.existsSync()) {
        _image = FileImage(file);
      }
      return;
    }

    // 2. Already-decrypted this session — avoids a placeholder flash on
    // rebuild, and avoids re-decrypting on every rebuild.
    final cachedBytes = _DecryptedBytesCache.instance.get(_cacheKey);
    if (cachedBytes != null) {
      _image = _imageFromBytes(cachedBytes);
      return;
    }

    // 3./4. Async: mint/reuse a signed URL, fetch, decrypt.
    if (_resolving) return;
    _resolving = true;
    _resolveAsync(ref);
  }

  Future<void> _resolveAsync(String ref) async {
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

    if (!mounted) return;
    setState(() {
      _image = resolvedImage;
      _resolving = false;
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

  Future<ImageProvider> _decryptFile(dynamic file) async {
    final rawBytes = await file.readAsBytes() as Uint8List;
    final userId = AuthService.instance.currentUserId;
    final coupleKey = userId == null ? null : await KeyManagementService.instance.loadCoupleKey(userId);
    // No couple key yet (key exchange still pending, or nobody signed in):
    // can't attempt decryption at all, so treat the bytes as-is. This still
    // renders correctly for a legacy pre-encryption plaintext object; a
    // genuinely encrypted object just fails to decode, same degrade path as
    // any other unresolvable image (errorWidget).
    final plaintext = coupleKey == null
        ? rawBytes
        : await PhotoEncryptionService.instance.tryDecryptBytes(rawBytes, coupleKey);
    _DecryptedBytesCache.instance.put(_cacheKey, plaintext);
    return _imageFromBytes(plaintext);
  }

  ImageProvider _imageFromBytes(Uint8List bytes) {
    final ImageProvider provider = MemoryImage(bytes);
    if (widget.maxWidth == null && widget.maxHeight == null) return provider;
    return ResizeImage(provider, width: widget.maxWidth, height: widget.maxHeight);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _image);
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
      builder: (context, image) {
        final Widget child;
        if (image == null) {
          final hasRef = storageRef != null && storageRef!.trim().isNotEmpty;
          child = hasRef
              ? (placeholder?.call(context) ?? _defaultPlaceholder(context))
              : (errorWidget?.call(context) ?? _defaultError(context));
        } else {
          child = Image(
            image: image,
            fit: fit,
            width: width,
            height: height,
            errorBuilder: (context, _, _) =>
                errorWidget?.call(context) ?? _defaultError(context),
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

  Widget _defaultError(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}
