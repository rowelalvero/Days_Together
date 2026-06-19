import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:days_together/models/timeline_model.dart';
import 'package:days_together/repositories/timeline_repository.dart';
import 'package:days_together/services/music_service.dart';

class MusicProvider with ChangeNotifier {
  final TimelineRepository _repository = TimelineRepository();
  final MusicService _musicService = MusicService();
  AppSettings _settings = AppSettings();
  bool _isPlaying = false;
  bool _disposed = false;

  bool get isPlaying => _isPlaying;
  double get volume => _settings.musicVolume;
  AppSettings get settings => _settings;

  MusicProvider() {
    // Fire-and-forget; UI shows defaults until the load completes.
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final loaded = await _repository.loadSettings();
      if (_disposed) return;
      _settings = loaded;
      if (_settings.backgroundMusicEnabled &&
          _settings.selectedMusicPath != null) {
        await _playMusic();
      } else {
        notifyListeners();
      }
    } catch (e, st) {
      debugPrint('MusicProvider._loadSettings failed: $e\n$st');
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> toggleMusic() async {
    _settings.backgroundMusicEnabled = !_settings.backgroundMusicEnabled;

    try {
      if (_settings.backgroundMusicEnabled) {
        await _playMusic();
      } else {
        await _musicService.stopMusic();
        _isPlaying = false;
      }
      await _repository.saveSettings(_settings);
    } catch (e, st) {
      debugPrint('MusicProvider.toggleMusic failed: $e\n$st');
      // Roll back the optimistic toggle so UI and persisted state stay in sync.
      _settings.backgroundMusicEnabled = !_settings.backgroundMusicEnabled;
      _isPlaying = _musicService.isPlaying;
    }

    if (!_disposed) notifyListeners();
  }

  Future<void> _playMusic() async {
    final path = _settings.selectedMusicPath;
    if (path == null) return;
    try {
      await _musicService.playMusic(path);
      _isPlaying = true;
    } catch (e, st) {
      debugPrint('MusicProvider._playMusic failed: $e\n$st');
      _isPlaying = false;
    }
  }

  Future<void> setMusicPath(String? path) async {
    _settings.selectedMusicPath = path;
    try {
      await _repository.saveSettings(_settings);
      if (_settings.backgroundMusicEnabled) {
        await _playMusic();
      }
    } catch (e, st) {
      debugPrint('MusicProvider.setMusicPath failed: $e\n$st');
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> setVolume(double volume) async {
    final clamped = volume.clamp(0.0, 1.0).toDouble();
    _settings.musicVolume = clamped;
    try {
      await _musicService.setVolume(clamped);
      await _repository.saveSettings(_settings);
    } catch (e, st) {
      debugPrint('MusicProvider.setVolume failed: $e\n$st');
    }
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    // ChangeNotifier.dispose() must be sync and call the overridden method.
    // The audio player release is fire-and-forget; the engine tears down the
    // isolate soon after dispose returns.
    unawaited(_musicService.dispose());
    super.dispose();
  }
}
