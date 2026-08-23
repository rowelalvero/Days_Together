// Tests for ThemeController (Item 3 gap-fix, Phase 2 -- front 3 of the
// architecture migration's `provider`-removal item, "ThemeController
// real"). Unlike every one of the 12 domain controllers from front 1, this
// one has no CoupleSession/Supabase dependency at all -- it is purely
// device-local (SharedPreferences via LocalPersistenceService), so no
// coupleSessionProvider override is needed anywhere below.

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderContainer;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:days_together/features/theme/theme_controller.dart';
import 'package:days_together/models/app_settings.dart';

/// `themeControllerProvider` is not `.autoDispose`, but `build()` kicks off
/// an async `_loadSettings()` -- if nothing reads the provider until after
/// an `await Future.delayed(Duration.zero)`, `build()` (and so the load)
/// hasn't even started yet, since Riverpod providers are lazy until first
/// read. `container.listen` here eagerly triggers `build()` the moment the
/// container is created, so the delay below actually gives the in-flight
/// load time to resolve.
ProviderContainer _readyContainer() {
  final container = ProviderContainer();
  container.listen(themeControllerProvider, (prev, next) {});
  return container;
}

void main() {
  group('ThemeController', () {
    test('build() starts with the default ThemeState before load resolves', () {
      SharedPreferences.setMockInitialValues({});
      final container = _readyContainer();
      addTearDown(container.dispose);

      final state = container.read(themeControllerProvider);
      expect(state.currentTheme, ThemeType.offWhite);
      expect(state.settings.currentTheme, ThemeType.offWhite);
    });

    test('build() adopts persisted settings once the async load resolves', () async {
      final persisted = AppSettings(currentTheme: ThemeType.pink, musicVolume: 0.2);
      SharedPreferences.setMockInitialValues({
        'app_settings': jsonEncode(persisted.toJson()),
      });
      final container = _readyContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);

      final state = container.read(themeControllerProvider);
      expect(state.currentTheme, ThemeType.pink);
      expect(state.settings.musicVolume, 0.2);
    });

    test('a missing or malformed settings cache falls back to defaults without crashing', () async {
      SharedPreferences.setMockInitialValues({'app_settings': 'not valid json'});
      final container = _readyContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);

      final state = container.read(themeControllerProvider);
      expect(state.currentTheme, ThemeType.offWhite);
    });

    test('changeTheme is a no-op when the theme is already active', () async {
      SharedPreferences.setMockInitialValues({});
      final container = _readyContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);
      final notifier = container.read(themeControllerProvider.notifier);

      final before = container.read(themeControllerProvider);
      await notifier.changeTheme(ThemeType.offWhite);
      final after = container.read(themeControllerProvider);
      expect(identical(before, after), true);
    });

    test('changeTheme updates state and persists the new theme', () async {
      SharedPreferences.setMockInitialValues({});
      final container = _readyContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);
      final notifier = container.read(themeControllerProvider.notifier);

      await notifier.changeTheme(ThemeType.deepPurple);

      final state = container.read(themeControllerProvider);
      expect(state.currentTheme, ThemeType.deepPurple);
      expect(state.settings.currentTheme, ThemeType.deepPurple);

      final prefs = await SharedPreferences.getInstance();
      final saved = AppSettings.fromJson(jsonDecode(prefs.getString('app_settings')!));
      expect(saved.currentTheme, ThemeType.deepPurple);
    });

    test('setCustomColor updates only the given slots and persists', () async {
      SharedPreferences.setMockInitialValues({});
      final container = _readyContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);
      final notifier = container.read(themeControllerProvider.notifier);
      final originalAccent = container.read(themeControllerProvider).settings.customAccentColor;

      await notifier.setCustomColor(primary: 0xFF123456);

      final state = container.read(themeControllerProvider);
      expect(state.settings.customPrimaryColor, 0xFF123456);
      expect(state.settings.customAccentColor, originalAccent);
    });

    test('setCustomIsDark updates and persists the dark/light flag', () async {
      SharedPreferences.setMockInitialValues({});
      final container = _readyContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);
      final notifier = container.read(themeControllerProvider.notifier);

      await notifier.setCustomIsDark(false);

      expect(container.read(themeControllerProvider).settings.customIsDark, false);
      final prefs = await SharedPreferences.getInstance();
      final saved = AppSettings.fromJson(jsonDecode(prefs.getString('app_settings')!));
      expect(saved.customIsDark, false);
    });

    test('toggleFavoriteTheme adds then removes a theme name', () async {
      SharedPreferences.setMockInitialValues({});
      final container = _readyContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);
      final notifier = container.read(themeControllerProvider.notifier);

      await notifier.toggleFavoriteTheme('Midnight Glass');
      expect(container.read(themeControllerProvider).settings.favoriteThemes, ['Midnight Glass']);

      await notifier.toggleFavoriteTheme('Midnight Glass');
      expect(container.read(themeControllerProvider).settings.favoriteThemes, isEmpty);
    });

    test('currentLoveTheme and currentGradient resolve the custom theme from settings', () async {
      SharedPreferences.setMockInitialValues({});
      final container = _readyContainer();
      addTearDown(container.dispose);
      await Future.delayed(Duration.zero);
      final notifier = container.read(themeControllerProvider.notifier);

      await notifier.changeTheme(ThemeType.custom);
      await notifier.setCustomColor(primary: 0xFFABCDEF);

      final state = container.read(themeControllerProvider);
      expect(state.currentLoveTheme.primaryColor.toARGB32(), 0xFFABCDEF);
      expect(state.currentGradient.colors.first.toARGB32(), 0xFFABCDEF);
    });
  });
}
