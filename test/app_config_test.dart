import 'package:flutter_test/flutter_test.dart';
import 'package:days_together/app_config.dart';

void main() {
  group('AppConfig Environment Configuration', () {
    test('provides non-empty fallback values for Supabase URL and anon key', () {
      expect(AppConfig.supabaseUrl, isNotEmpty);
      expect(AppConfig.supabaseUrl, startsWith('https://'));
      expect(AppConfig.supabaseAnonKey, isNotEmpty);
    });

    test('provides non-empty fallback for Google Client ID', () {
      expect(AppConfig.googleClientIdWeb, isNotEmpty);
      expect(AppConfig.googleClientIdWeb, contains('.apps.googleusercontent.com'));
    });
  });
}
