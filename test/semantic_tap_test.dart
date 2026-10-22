// SemanticTap: the shared wrapper that makes a custom-drawn tap target a
// real control for screen readers (label, role, state, tap action) and can
// grow its hit area without changing its look.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:days_together/shared/widgets/semantic_tap.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

const _dot = SizedBox(
  width: 20,
  height: 20,
  child: ColoredBox(color: Colors.pink),
);

void main() {
  testWidgets('is one labeled button node that performs the tap', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(
      _host(
        SemanticTap(label: 'Send message', onTap: () => taps++, child: _dot),
      ),
    );

    expect(
      tester.getSemantics(find.byType(SemanticTap)),
      matchesSemantics(
        label: 'Send message',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    await tester.tap(find.byType(SemanticTap));
    expect(taps, 1);
    handle.dispose();
  });

  testWidgets('a checked value makes it a checkbox, not a button', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        SemanticTap(
          label: 'Visit Paris',
          checked: true,
          onTap: () {},
          child: _dot,
        ),
      ),
    );
    expect(
      tester.getSemantics(find.byType(SemanticTap)),
      matchesSemantics(
        label: 'Visit Paris',
        hasCheckedState: true,
        isChecked: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('reports selected state and is disabled without onTap', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        const SemanticTap(
          label: 'Show both licenses',
          selected: true,
          onTap: null,
          child: _dot,
        ),
      ),
    );
    expect(
      tester.getSemantics(find.byType(SemanticTap)),
      matchesSemantics(
        label: 'Show both licenses',
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
        hasEnabledState: true,
        isEnabled: false,
      ),
    );
    handle.dispose();
  });

  testWidgets('minTapTarget grows the hit area, not the visual', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        SemanticTap(
          label: 'Clear',
          minTapTarget: 48,
          onTap: () {},
          child: _dot,
        ),
      ),
    );
    expect(tester.getSize(find.byType(SemanticTap)), const Size(48, 48));
    expect(
      tester.getSize(
        find.descendant(
          of: find.byType(SemanticTap),
          matching: find.byType(ColoredBox),
        ),
      ),
      const Size(20, 20),
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });
}
