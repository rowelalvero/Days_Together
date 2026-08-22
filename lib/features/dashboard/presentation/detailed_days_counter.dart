import 'package:days_together/themes/theme_manager.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:intl/intl.dart';
import 'package:days_together/routing/routes.dart';
import 'package:days_together/widgets/glass_container.dart';
import 'package:days_together/features/relationship/workspace_state.dart';
import 'package:days_together/services/date_helper.dart';

class DetailedDaysCounter extends StatefulWidget {
  final WorkspaceState workspace;
  final LoveStoryTheme theme;

  const DetailedDaysCounter({
    super.key,
    required this.workspace,
    required this.theme,
  });

  @override
  State<DetailedDaysCounter> createState() => _DetailedDaysCounterState();
}

class _DetailedDaysCounterState extends State<DetailedDaysCounter> {
  late Timer _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final workspace = widget.workspace;
    final age = DateHelper.relationshipPreciseAge(workspace.startDate, workspace.startTime);
    final totalDays = DateHelper.relationshipTotalDays(workspace.startDate);
    final startDate = workspace.startDate ?? DateTime.now();

    return InkWell(
      onTap: () {
        // The custom fade+slide transition moved to app_router.dart's
        // Routes.duration route (a CustomTransitionPage), so it still
        // applies here even though this call site no longer specifies it.
        context.push(Routes.duration);
      },
      borderRadius: BorderRadius.circular(28),
      child: GlassContainer(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        borderRadius: 28,
      child: Column(
        children: [
          // Top Badge
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.auto_awesome,
                color: Colors.pinkAccent,
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                'LOVED WITHOUT LIMITS SINCE ${startDate.year}',
                style: AppTypography.captionMono(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.pinkAccent,
                ).copyWith(letterSpacing: 1.5),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Large Counter
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [widget.theme.accentColor, Colors.amberAccent],
                ).createShader(bounds),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: totalDays.toDouble()),
                  duration: const Duration(milliseconds: 1600),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Text(
                      NumberFormat('#,###').format(value.toInt()),
                      style: AppTypography.display(
                        fontSize: 72,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Days Together',
                style: AppTypography.cormorant(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: widget.theme.textColor.withValues(alpha: 0.8),
                ).copyWith(letterSpacing: 1.2),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Ticking stopwatch horizontal bar
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            decoration: BoxDecoration(
              color: widget.theme.textColor.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: widget.theme.textColor.withValues(alpha: 0.05),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildAnimatedUnit('Yr', age['years'] ?? 0, delay: 0),
                _buildAnimatedUnit('Mo', age['months'] ?? 0, delay: 80),
                _buildAnimatedUnit('Day', age['days'] ?? 0, delay: 160),
                _buildAnimatedUnit('Hr', age['hours'] ?? 0, delay: 240),
                _buildAnimatedUnit('Min', age['minutes'] ?? 0, delay: 320),
                _buildLiveUnit('Sec', age['seconds'] ?? 0),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildAnimatedUnit(String label, int endValue, {int delay = 0}) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: endValue.toDouble()),
            duration: Duration(milliseconds: 1200 + delay),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return Text(
                value.toInt().toString(),
                style: AppTypography.body(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: widget.theme.textColor,
                ),
              );
            },
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: AppTypography.body(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: widget.theme.textColor.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveUnit(String label, int val) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            val.toString(),
            style: AppTypography.body(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: widget.theme.textColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: AppTypography.body(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: widget.theme.textColor.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}
