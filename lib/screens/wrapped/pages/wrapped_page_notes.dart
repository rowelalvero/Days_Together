import 'package:flutter/material.dart';
import 'package:days_together/screens/wrapped/wrapped_data.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/features/wrapped/presentation/wrapped_animated_counter.dart';

class WrappedPageNotes extends StatelessWidget {
  final WrappedData data;
  const WrappedPageNotes({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final hasNotes = data.notesThisYear > 0;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 600),
              builder: (_, v, child) => Opacity(opacity: v, child: child),
              child: const Text('💌', style: TextStyle(fontSize: 56)),
            ),
            const SizedBox(height: 24),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 700),
              builder: (_, v, child) => Opacity(opacity: v, child: child),
              child: Text(
                hasNotes ? 'You shared' : 'Love Notes',
                style: AppTypography.cormorant(
                  fontSize: 26,
                  color: Colors.white.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w400,
                ).copyWith(fontStyle: FontStyle.italic),
              ),
            ),
            if (hasNotes) ...[
              const SizedBox(height: 12),
              ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  colors: [Color(0xFFFF6B6B), Color(0xFFFF8E8E), Color(0xFFFFB3B3)],
                ).createShader(b),
                child: WrappedAnimatedCounter(
                  endValue: data.notesThisYear.toDouble(),
                  duration: const Duration(milliseconds: 1600),
                  style: AppTypography.display(
                    fontSize: 88,
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 900),
                builder: (_, v, child) => Opacity(opacity: v, child: child),
                child: Text(
                  data.notesThisYear == 1
                      ? 'heartfelt note in ${data.year}'
                      : 'heartfelt notes in ${data.year}',
                  style: AppTypography.cormorant(
                    fontSize: 26,
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              if (data.longestNoteExcerpt?.isNotEmpty ?? false) ...[
                const SizedBox(height: 36),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 1300),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, child) => Transform.translate(
                    offset: Offset(0, 20 * (1 - v)),
                    child: Opacity(opacity: v, child: child),
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.format_quote_rounded,
                                color: Colors.white38, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Your longest note',
                              style: AppTypography.caption(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.4),
                                fontWeight: FontWeight.w600,
                              ).copyWith(letterSpacing: 0.5),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '"${data.longestNoteExcerpt}"',
                          style: AppTypography.cormorant(
                            fontSize: 16,
                            color: Colors.white.withValues(alpha: 0.75),
                            fontWeight: FontWeight.w400,
                            height: 1.6,
                          ).copyWith(fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ] else ...[
              const SizedBox(height: 32),
              _emptyNotesState(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _emptyNotesState() => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 900),
        builder: (_, v, child) => Opacity(opacity: v, child: child),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            children: [
              Text(
                'No notes this year — yet.',
                style: AppTypography.heading(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Send a love note to your partner\nand watch this page come alive next year.',
                style: AppTypography.body(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.55),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}
