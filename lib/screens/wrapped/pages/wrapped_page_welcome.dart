import 'package:flutter/material.dart';
import 'package:days_together/screens/wrapped/wrapped_data.dart';
import 'package:days_together/themes/app_typography.dart';

class WrappedPageWelcome extends StatefulWidget {
  final WrappedData data;
  const WrappedPageWelcome({super.key, required this.data});

  @override
  State<WrappedPageWelcome> createState() => _WrappedPageWelcomeState();
}

class _WrappedPageWelcomeState extends State<WrappedPageWelcome>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Pulsing heart
            ScaleTransition(
              scale: Tween<double>(begin: 0.92, end: 1.08).animate(
                CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
              ),
              child: const Text('❤️', style: TextStyle(fontSize: 64)),
            ),
            const SizedBox(height: 32),
            // Label
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOut,
              builder: (_, v, child) =>
                  Opacity(opacity: v, child: child),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Text(
                  'DAYS TOGETHER',
                  style: AppTypography.captionMono(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w700,
                  ).copyWith(letterSpacing: 2.5),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Year
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOut,
              builder: (_, v, child) =>
                  Opacity(opacity: v, child: child),
              child: Text(
                'Wrapped ${widget.data.year}',
                style: AppTypography.display(
                  fontSize: 52,
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 1100),
              curve: Curves.easeOut,
              builder: (_, v, child) =>
                  Opacity(opacity: v, child: child),
              child: Text(
                '${widget.data.yourName} & ${widget.data.partnerDisplayName}',
                style: AppTypography.cormorant(
                  fontSize: 22,
                  color: Colors.white.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w400,
                ).copyWith(fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 56),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 1400),
              curve: Curves.easeOut,
              builder: (_, v, child) =>
                  Opacity(opacity: v, child: child),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.swipe_right_rounded,
                      color: Colors.white54, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Tap or swipe to begin your story',
                    style: AppTypography.body(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
