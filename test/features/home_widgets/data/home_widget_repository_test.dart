import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:days_together/shared/models/app_settings.dart';
import 'package:days_together/core/platform/home_widget/home_widget_models.dart';
import 'package:days_together/features/home_widgets/data/home_widget_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late HomeWidgetRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repository = HomeWidgetRepository(prefs);
  });

  test('loadConfig returns default config when nothing is stored', () {
    final config = repository.loadConfig();
    expect(config.themeType, ThemeType.midnightRose);
    expect(config.customTitle, 'Days Together');
  });

  test('saveConfig persists config and loadConfig retrieves it', () async {
    const newConfig = HomeWidgetConfig(
      themeType: ThemeType.pink,
      customTitle: 'Ash & Wel Forever',
      counterFormat: DaysCounterFormat.yearsMonthsDays,
    );
    await repository.saveConfig(newConfig);

    final loaded = repository.loadConfig();
    expect(loaded.themeType, ThemeType.pink);
    expect(loaded.customTitle, 'Ash & Wel Forever');
    expect(loaded.counterFormat, DaysCounterFormat.yearsMonthsDays);
  });
}
