import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:days_together/features/theme/theme_state.dart';
import 'package:days_together/models/app_settings.dart';
import 'package:days_together/services/local_persistence_service.dart';

/// Riverpod port of `ThemeProvider` (Item 3 gap-fix, Phase 2 -- front 3 of
/// the architecture migration's `provider`-removal item). Faithful behavior
/// port of the original `ChangeNotifier`, including its exact no-op guards
/// and its "swallow the load error but still notify" semantics.
///
/// Deliberately **not** `.autoDispose`, unlike every one of the 12 domain
/// controllers from front 1: those are couple-scoped and meant to reset on
/// logout/pairing; theme is device-local with no such reset trigger and
/// must be readable from the very first frame (`MyApp`'s `MaterialApp`) for
/// the app's entire process lifetime, independent of which screen is
/// mounted.
class ThemeController extends Notifier<ThemeState> {
  final LocalPersistenceService _repository = LocalPersistenceService();

  @override
  ThemeState build() {
    _loadSettings();
    return ThemeState();
  }

  Future<void> _loadSettings() async {
    try {
      final loaded = await _repository.loadSettings();
      if (!ref.mounted) return;
      state = ThemeState(currentTheme: loaded.currentTheme, settings: loaded);
    } catch (e, st) {
      debugPrint('ThemeController._loadSettings failed: $e\n$st');
      // Matches ThemeProvider._loadSettings: still notifies on failure
      // (a fresh ThemeState instance with the same, unchanged field values)
      // rather than leaving watchers waiting on a signal that never comes.
      // `ThemeState` has no `==` override, so Riverpod's default identity
      // check sees this as a genuine change and does notify, mirroring the
      // original's unconditional `notifyListeners()` in this catch branch.
      if (ref.mounted) {
        state = ThemeState(currentTheme: state.currentTheme, settings: state.settings);
      }
    }
  }

  Future<void> changeTheme(ThemeType newTheme) async {
    if (state.currentTheme == newTheme && state.settings.currentTheme == newTheme) {
      return;
    }
    final newSettings = state.settings.copyWith(currentTheme: newTheme);
    state = ThemeState(currentTheme: newTheme, settings: newSettings);
    try {
      await _repository.saveSettings(newSettings);
    } catch (e, st) {
      debugPrint('ThemeController.changeTheme save failed: $e\n$st');
    }
  }

  /// Update a specific custom color slot and persist.
  Future<void> setCustomColor({
    int? primary,
    int? secondary,
    int? background,
    int? accent,
  }) async {
    final newSettings = state.settings.copyWith(
      customPrimaryColor: primary,
      customSecondaryColor: secondary,
      customBackgroundColor: background,
      customAccentColor: accent,
    );
    state = state.copyWith(settings: newSettings);
    try {
      await _repository.saveSettings(newSettings);
    } catch (e, st) {
      debugPrint('ThemeController.setCustomColor save failed: $e\n$st');
    }
  }

  /// Toggle custom theme dark/light mode.
  Future<void> setCustomIsDark(bool isDark) async {
    final newSettings = state.settings.copyWith(customIsDark: isDark);
    state = state.copyWith(settings: newSettings);
    try {
      await _repository.saveSettings(newSettings);
    } catch (e, st) {
      debugPrint('ThemeController.setCustomIsDark save failed: $e\n$st');
    }
  }

  Future<void> toggleFavoriteTheme(String themeName) async {
    final updated = List<String>.from(state.settings.favoriteThemes);
    if (updated.contains(themeName)) {
      updated.remove(themeName);
    } else {
      updated.add(themeName);
    }
    final newSettings = state.settings.copyWith(favoriteThemes: updated);
    state = state.copyWith(settings: newSettings);
    try {
      await _repository.saveSettings(newSettings);
    } catch (e, st) {
      debugPrint('ThemeController.toggleFavoriteTheme save failed: $e\n$st');
    }
  }
}

final themeControllerProvider = NotifierProvider<ThemeController, ThemeState>(
  ThemeController.new,
);
