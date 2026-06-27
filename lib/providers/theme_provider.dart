import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show LinearGradient;
import 'package:days_together/models/timeline_model.dart';
import 'package:days_together/repositories/timeline_repository.dart';
import 'package:days_together/themes/theme_manager.dart';

class ThemeProvider with ChangeNotifier {
  final TimelineRepository _repository = TimelineRepository();
  ThemeType _currentTheme = ThemeType.offWhite;
  AppSettings _settings = AppSettings();
  bool _disposed = false;

  ThemeType get currentTheme => _currentTheme;
  AppSettings get settings => _settings;

  LoveStoryTheme get currentLoveTheme =>
      ThemeManager.resolveTheme(_currentTheme, _settings);

  ThemeProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final loaded = await _repository.loadSettings();
      if (_disposed) return;
      _settings = loaded;
      _currentTheme = _settings.currentTheme;
      notifyListeners();
    } catch (e, st) {
      debugPrint('ThemeProvider._loadSettings failed: $e\n$st');
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> changeTheme(ThemeType newTheme) async {
    if (_currentTheme == newTheme && _settings.currentTheme == newTheme) return;
    _currentTheme = newTheme;
    _settings.currentTheme = newTheme;
    try {
      await _repository.saveSettings(_settings);
    } catch (e, st) {
      debugPrint('ThemeProvider.changeTheme save failed: $e\n$st');
    }
    if (!_disposed) notifyListeners();
  }

  /// Update a specific custom color slot and persist.
  Future<void> setCustomColor({
    int? primary,
    int? secondary,
    int? background,
    int? accent,
  }) async {
    _settings = _settings.copyWith(
      customPrimaryColor: primary,
      customSecondaryColor: secondary,
      customBackgroundColor: background,
      customAccentColor: accent,
    );
    try {
      await _repository.saveSettings(_settings);
    } catch (e, st) {
      debugPrint('ThemeProvider.setCustomColor save failed: $e\n$st');
    }
    if (!_disposed) notifyListeners();
  }

  /// Toggle custom theme dark/light mode.
  Future<void> setCustomIsDark(bool isDark) async {
    _settings = _settings.copyWith(customIsDark: isDark);
    try {
      await _repository.saveSettings(_settings);
    } catch (e, st) {
      debugPrint('ThemeProvider.setCustomIsDark save failed: $e\n$st');
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> toggleFavoriteTheme(String themeName) async {
    if (_settings.favoriteThemes.contains(themeName)) {
      _settings.favoriteThemes.remove(themeName);
    } else {
      _settings.favoriteThemes.add(themeName);
    }
    try {
      await _repository.saveSettings(_settings);
    } catch (e, st) {
      debugPrint('ThemeProvider.toggleFavoriteTheme save failed: $e\n$st');
    }
    if (!_disposed) notifyListeners();
  }

  LinearGradient get currentGradient =>
      ThemeManager.getGradient(_currentTheme, settings: _settings);

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
