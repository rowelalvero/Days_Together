// The scrapbook's bottom dock: tool selection, the fold-the-sheet toggle,
// the photo menu, and the pinned Send button with its saving state.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/features/scrapbook/presentation/components/noteit_floating_toolbar.dart';
import 'package:days_together/shared/models/app_settings.dart';

class _Calls {
  final modes = <String>[];
  int toggles = 0;
  int addText = 0;
  int sends = 0;
  final imports = <ImageSource>[];
}

Future<_Calls> _pump(
  WidgetTester tester, {
  String activeMode = 'pen',
  bool isSaving = false,
  ThemeType theme = ThemeType.liquidGlass,
}) async {
  final calls = _Calls();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: NoteitFloatingToolbar(
            theme: ThemeManager.getTheme(theme),
            activeMode: activeMode,
            isPropertiesPanelExpanded: true,
            isSaving: isSaving,
            onModeChanged: calls.modes.add,
            onToggleProperties: () => calls.toggles++,
            onAddText: () => calls.addText++,
            onImportImage: calls.imports.add,
            onSend: () => calls.sends++,
          ),
        ),
      ),
    ),
  );
  return calls;
}

void main() {
  testWidgets('tapping another tool switches mode', (tester) async {
    final calls = await _pump(tester);

    await tester.tap(find.byIcon(Icons.border_color_rounded));
    expect(calls.modes, ['marker']);
    expect(calls.toggles, 0);
  });

  testWidgets('tapping the active tool folds its sheet instead', (
    tester,
  ) async {
    final calls = await _pump(tester, activeMode: 'pen');

    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.gesture_rounded));
    expect(calls.toggles, 1);
    expect(calls.modes, isEmpty);
  });

  testWidgets('photo menu offers gallery and camera', (tester) async {
    final calls = await _pump(tester);

    await tester.tap(find.byIcon(Icons.add_photo_alternate_rounded));
    await tester.pumpAndSettle();
    expect(find.text('From gallery'), findsOneWidget);
    await tester.tap(find.text('Take a photo'));
    await tester.pumpAndSettle();
    expect(calls.imports, [ImageSource.camera]);
  });

  testWidgets('Send is pinned and calls back', (tester) async {
    final calls = await _pump(tester);

    await tester.tap(find.text('Send'));
    expect(calls.sends, 1);
  });

  testWidgets('Send is disabled and shows progress while saving', (
    tester,
  ) async {
    final calls = await _pump(tester, isSaving: true);

    expect(find.text('Sending'), findsOneWidget);
    expect(find.text('Send'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.text('Sending'));
    expect(calls.sends, 0);
  });

  testWidgets('the active tool icon uses ink readable on a pastel accent', (
    tester,
  ) async {
    // Azure Liquid's accent is a pale blue; white on it is ~1.3:1.
    await _pump(tester, activeMode: 'pen', theme: ThemeType.liquidGlass);

    final icon = tester.widget<Icon>(find.byIcon(Icons.gesture_rounded));
    expect(icon.color, ThemeContrast.darkInk);
    final inactive = tester.widget<Icon>(find.byIcon(Icons.edit_rounded));
    expect(inactive.color, isNot(ThemeContrast.darkInk));
  });
}
