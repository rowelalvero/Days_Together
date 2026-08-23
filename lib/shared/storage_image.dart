import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'package:days_together/services/storage_url_service.dart';

/// Resolves a storage ref to an [ImageProvider] and hands it to [builder].
///
/// Use this where a raw provider is required — `CircleAvatar.backgroundImage`,
/// `DecorationImage`, and so on. For a plain image, prefer [StorageImage].
///
/// The resolution ladder, in order:
///  1. [localPath], when it exists on disk (an upload that has not synced yet)
///  2. a still-fresh signed URL already in memory — resolved synchronously, so
///     a rebuild never flashes a placeholder
///  3. a freshly minted signed URL
///  4. the `cached_network_image` disk cache, keyed by the stable cache key —
///     this is what keeps images working offline, where signing fails
///  5. null, so the caller renders its own placeholder
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
    // 1. Local file wins outright.
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

    // 2. Synchronous hit — avoids a placeholder flash on rebuild.
    final cached = StorageUrlService.instance
        .resolveCached(bucket: widget.bucket, ref: ref);
    if (cached != null) {
      _image = CachedNetworkImageProvider(
        cached,
        cacheKey: _cacheKey,
        maxWidth: widget.maxWidth,
        maxHeight: widget.maxHeight,
      );
      return;
    }

    // 3. Mint one.
    if (_resolving) return;
    _resolving = true;
    StorageUrlService.instance
        .resolve(bucket: widget.bucket, ref: ref)
        .then((url) async {
      if (!mounted) return;
      if (url != null) {
        setState(() {
          _image = CachedNetworkImageProvider(
            url,
            cacheKey: _cacheKey,
            maxWidth: widget.maxWidth,
            maxHeight: widget.maxHeight,
          );
          _resolving = false;
        });
        return;
      }

      // 4. Signing failed (offline, or denied). Fall back to whatever is
      // already on disk under the stable cache key.
      final fallback = await _fileFromCache();
      if (!mounted) return;
      setState(() {
        _image = fallback;
        _resolving = false;
      });
    });
  }

  Future<ImageProvider?> _fileFromCache() async {
    final key = _cacheKey;
    if (key.isEmpty) return null;
    try {
      final cached = await DefaultCacheManager().getFileFromCache(key);
      if (cached != null) return FileImage(cached.file);
    } catch (_) {
      // Cache lookups are best-effort.
    }
    return null;
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
