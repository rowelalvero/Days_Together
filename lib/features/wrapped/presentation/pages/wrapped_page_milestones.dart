import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:days_together/features/wrapped/domain/wrapped_data.dart';
import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/features/wrapped/presentation/widgets/wrapped_milestone_tile.dart';
import 'package:days_together/features/wrapped/presentation/widgets/wrapped_milestones_empty_state.dart';

/// Its inline milestone tile and empty state were extracted into widgets
/// under `presentation/widgets/` (Migration audit item 6).
class WrappedPageMilestones extends StatefulWidget {
  final WrappedData data;
  const WrappedPageMilestones({super.key, required this.data});

  @override
  State<WrappedPageMilestones> createState() => _WrappedPageMilestonesState();
}

class _WrappedPageMilestonesState extends State<WrappedPageMilestones> {
  late ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 4));
    if (widget.data.milestonesAchievedThisYear.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) _confetti.play();
      });
    }
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final milestones = widget.data.milestonesAchievedThisYear;
    final hasMilestones = milestones.isNotEmpty;

    return Stack(
      children: [
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(36, 24, 36, 36),
            child: Column(
              children: [
                const SizedBox(height: 40),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 600),
                  builder: (_, v, c) => Opacity(opacity: v, child: c),
                  child: Text(
                    hasMilestones ? '🏆 Milestones Unlocked' : '🏆 Milestones',
                    style: AppTypography.display(
                      fontSize: 30,
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 8),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 700),
                  builder: (_, v, c) => Opacity(opacity: v, child: c),
                  child: Text(
                    hasMilestones
                        ? 'Achievements you reached in ${widget.data.year}'
                        : 'The next milestone is just around the corner',
                    style: AppTypography.cormorant(
                      fontSize: 18,
                      color: Colors.white.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w400,
                    ).copyWith(fontStyle: FontStyle.italic),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 36),
                if (hasMilestones)
                  ...milestones.asMap().entries.map(
                    (e) => WrappedMilestoneTile(title: e.value, index: e.key),
                  )
                else
                  const WrappedMilestonesEmptyState(),
                const SizedBox(height: 24),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 1400),
                  builder: (_, v, c) => Opacity(opacity: v, child: c),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Text(
                      '${widget.data.totalDays} days of unbroken love 💜',
                      style: AppTypography.body(
                        fontSize: 15,
                        color: Colors.white.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Confetti
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confetti,
            blastDirectionality: BlastDirectionality.explosive,
            particleDrag: 0.05,
            emissionFrequency: 0.08,
            numberOfParticles: 16,
            gravity: 0.2,
            colors: const [
              Color(0xFFF43F5E),
              Color(0xFF7C3AED),
              Color(0xFF06B6D4),
              Color(0xFFF59E0B),
              Colors.white,
            ],
          ),
        ),
      ],
    );
  }
}
