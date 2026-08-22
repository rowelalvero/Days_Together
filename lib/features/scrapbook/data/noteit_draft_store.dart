import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:days_together/models/canvas_document.dart';

/// Owns the noteit canvas's local draft persistence, extracted out of
/// `NoteitScreen`'s state (Migration Phase 8) so the SharedPreferences key
/// has a single owner instead of being read/written inline in a widget.
///
/// This only handles the already-serialized [CanvasDocument] -- converting
/// a live `PainterController`'s drawables to/from a [CanvasDocument] stays
/// in the screen via `CanvasMapping`, since that conversion is inherently
/// tied to the rendering layer, not persistence.
class NoteitDraftStore {
  const NoteitDraftStore();

  static const _draftKey = 'noteit_draft_canvas';

  Future<void> save(CanvasDocument doc) async {
    try {
      final jsonStr = jsonEncode(doc.toJson());
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_draftKey, jsonStr);
    } catch (e) {
      debugPrint('NoteitDraftStore: Error saving draft: $e');
    }
  }

  Future<CanvasDocument?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_draftKey);
      if (jsonStr == null || jsonStr.isEmpty) return null;
      return CanvasDocument.fromJson(jsonDecode(jsonStr));
    } catch (e) {
      debugPrint('NoteitDraftStore: Error loading draft: $e');
      return null;
    }
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftKey);
    } catch (e) {
      debugPrint('NoteitDraftStore: Error clearing draft: $e');
    }
  }
}
