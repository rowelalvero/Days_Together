// The reduced-motion helpers: decorative loops stop on a still frame and
// one-shot flourishes jump to their end when the OS asks for reduced motion
// (MediaQuery.disableAnimations), and follow the setting live.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:days_together/shared/widgets/reduced_motion.dart';

class _Pulse extends StatefulWidget {
  const _Pulse({required this.onController});
  final void Function(AnimationController) onController;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );

  @override
  void initState() {
    super.initState();
    widget.onController(_c);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _c.repeatUnlessReducedMotion(context, reverse: true, restValue: 0.25);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

Widget _app({required bool reduce, required Widget child}) => MediaQuery(
  data: MediaQueryData(disableAnimations: reduce),
  child: Directionality(textDirection: TextDirection.ltr, child: child),
);

void main() {
  testWidgets('loops normally when motion is allowed', (tester) async {
    late AnimationController c;
    await tester.pumpWidget(
      _app(reduce: false, child: _Pulse(onController: (x) => c = x)),
    );
    expect(c.isAnimating, isTrue);
    await tester.pump(const Duration(milliseconds: 300));
    expect(c.value, isNot(0.25));
  });

  testWidgets('parks on the rest frame under reduced motion', (tester) async {
    late AnimationController c;
    await tester.pumpWidget(
      _app(reduce: true, child: _Pulse(onController: (x) => c = x)),
    );
    expect(c.isAnimating, isFalse);
    expect(c.value, 0.25);
    await tester.pump(const Duration(seconds: 2));
    expect(c.value, 0.25);
  });

  testWidgets('follows the setting when it changes while open', (tester) async {
    late AnimationController c;
    final pulse = _Pulse(onController: (x) => c = x);
    await tester.pumpWidget(_app(reduce: false, child: pulse));
    expect(c.isAnimating, isTrue);

    await tester.pumpWidget(_app(reduce: true, child: pulse));
    expect(c.isAnimating, isFalse);
    expect(c.value, 0.25);

    await tester.pumpWidget(_app(reduce: false, child: pulse));
    expect(c.isAnimating, isTrue);
  });

  testWidgets('a one-shot flourish jumps to its end under reduced motion', (
    tester,
  ) async {
    final c = AnimationController(
      vsync: const TestVSync(),
      duration: const Duration(seconds: 3),
    );
    addTearDown(c.dispose);
    Future<void> play(bool reduce) => tester.pumpWidget(
      _app(
        reduce: reduce,
        child: Builder(
          builder: (context) {
            c.playUnlessReducedMotion(context, from: 0);
            return const SizedBox();
          },
        ),
      ),
    );

    await play(true);
    expect(c.isAnimating, isFalse);
    expect(c.value, 1.0);

    await play(false);
    expect(c.isAnimating, isTrue);
    expect(c.value, lessThan(1.0));
    c.stop();
  });
}
