import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:days_together/features/home_widgets/data/home_widget_repository.dart';
import 'package:days_together/features/home_widgets/presentation/screens/home_widget_studio_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('HomeWidgetStudioScreen renders live preview, theme picker, and pin button', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeWidgetRepositoryProvider.overrideWithValue(HomeWidgetRepository(prefs)),
        ],
        child: const MaterialApp(
          home: HomeWidgetStudioScreen(),
        ),
      ),
    );

    expect(find.text('Home Screen Widgets'), findsOneWidget);
    expect(find.text('NoteIt (2x2)'), findsOneWidget);
    expect(find.text('Days Counter (2x2)'), findsOneWidget);
    expect(find.text('Days Counter (4x2)'), findsOneWidget);
    expect(find.text('Add to Home Screen'), findsOneWidget);

    // Switch to Days Counter (2x2)
    await tester.tap(find.text('Days Counter (2x2)'));
    await tester.pumpAndSettle();

    expect(find.text('Customize Widget Content'), findsOneWidget);
    expect(find.text('Total Days'), findsOneWidget);
  });
}
