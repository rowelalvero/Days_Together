import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Renders whatever's under a `RepaintBoundary`'s [GlobalKey] to a PNG and
/// either saves it to the device gallery or shares it. Extracted out of
/// `_ExportStudioBottomSheetState`'s `_saveToDevice`/`_shareImage`
/// (Migration Phase 8), which duplicated the identical capture-to-temp-file
/// sequence inline in both methods, differing only in the final action.
///
/// Generic over any widget with a `RepaintBoundary` ancestor -- nothing
/// here is license-specific, so this is reusable if another feature ever
/// needs "export this widget as an image."
class ImageExportService {
  const ImageExportService();

  Future<Uint8List> _capturePng(GlobalKey key, {double pixelRatio = 4.0}) async {
    final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      throw Exception('Preview capture layer not ready. Please try again.');
    }

    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) throw Exception('Failed to generate PNG bytes');

    return byteData.buffer.asUint8List();
  }

  Future<File> _writeTempPng(Uint8List bytes, String filenamePrefix) async {
    final tempDir = await getTemporaryDirectory();
    final file = await File(
      '${tempDir.path}/${filenamePrefix}_${DateTime.now().millisecondsSinceEpoch}.png',
    ).create();
    await file.writeAsBytes(bytes);
    return file;
  }

  /// Captures [key]'s RepaintBoundary and saves it to the device gallery.
  Future<void> saveToGallery(GlobalKey key, {required String filenamePrefix}) async {
    final bytes = await _capturePng(key);
    final file = await _writeTempPng(bytes, filenamePrefix);
    await Gal.putImage(file.path);
  }

  /// Captures [key]'s RepaintBoundary and opens the platform share sheet.
  Future<void> share(GlobalKey key, {required String filenamePrefix, required String shareText}) async {
    final bytes = await _capturePng(key);
    final file = await _writeTempPng(bytes, filenamePrefix);
    await Share.shareXFiles([XFile(file.path)], text: shareText);
  }
}
