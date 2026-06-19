import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class MusicService {
  static final MusicService _instance = MusicService._internal();
  factory MusicService() => _instance;
  MusicService._internal();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  String? _currentMusicPath;

  Future<void> playMusic(String? musicPath) async {
    if (musicPath == null) return;

    // Already loaded and playing this track — nothing to do.
    if (_currentMusicPath == musicPath && _isPlaying) return;

    try {
      _currentMusicPath = musicPath;
      await _audioPlayer.setSourceDeviceFile(musicPath);
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.resume();
      _isPlaying = true;
    } catch (e, st) {
      _isPlaying = false;
      debugPrint('MusicService.playMusic failed for $musicPath: $e\n$st');
      rethrow;
    }
  }

  Future<void> stopMusic() async {
    try {
      await _audioPlayer.stop();
    } catch (e, st) {
      debugPrint('MusicService.stopMusic failed: $e\n$st');
    } finally {
      _isPlaying = false;
    }
  }

  Future<void> pauseMusic() async {
    try {
      await _audioPlayer.pause();
    } catch (e, st) {
      debugPrint('MusicService.pauseMusic failed: $e\n$st');
    } finally {
      _isPlaying = false;
    }
  }

  /// Resumes a previously-paused track. Falls back to a full re-source only
  /// if the underlying player actually lost its source (e.g. after a system
  /// audio interruption).
  Future<void> resumeMusic() async {
    if (_currentMusicPath == null) return;
    try {
      await _audioPlayer.resume();
      _isPlaying = true;
    } catch (e, st) {
      debugPrint(
          'MusicService.resumeMusic fast-path failed, re-sourcing: $e\n$st');
      await playMusic(_currentMusicPath);
    }
  }

  Future<void> setVolume(double volume) async {
    final clamped = volume.clamp(0.0, 1.0).toDouble();
    try {
      await _audioPlayer.setVolume(clamped);
    } catch (e, st) {
      debugPrint('MusicService.setVolume failed: $e\n$st');
    }
  }

  bool get isPlaying => _isPlaying;
  String? get currentMusicPath => _currentMusicPath;

  Future<void> dispose() async {
    try {
      await _audioPlayer.dispose();
    } catch (e, st) {
      debugPrint('MusicService.dispose failed: $e\n$st');
    }
  }
}
