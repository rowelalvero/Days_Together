import 'package:flutter/material.dart';
import 'package:days_together/features/relationship/workspace_state.dart';
import 'package:days_together/services/date_helper.dart';
import 'package:days_together/shared/glass_container.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/themes/theme_manager.dart';

/// Bento card row showing the precise duration breakdown in Years, Months, and Days.
class DurationBreakdownSection extends StatelessWidget {
  final WorkspaceState workspace;
  final LoveStoryTheme theme;

  const DurationBreakdownSection({
    super.key,
    required this.workspace,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final age = DateHelper.relationshipPreciseAge(workspace.startDate, workspace.startTime);
    final years = age['years'] ?? 0;
    final months = age['months'] ?? 0;
    final days = age['days'] ?? 0;

    Widget buildTile(int targetValue, String label, String icon) {
      return Expanded(
        child: GlassContainer(
          padding: const EdgeInsets.all(16),
          borderRadius: 20,
          child: Column(
            children: [
              Text(
                icon,
                style: const TextStyle(fontSize: 22),
              ),
              const SizedBox(height: 8),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: targetValue.toDouble()),
                duration: const Duration(milliseconds: 1400),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  return Text(
                    '${value.toInt()}',
                    style: AppTypography.heading(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: theme.textColor,
                    ),
                  );
                },
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTypography.caption(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: theme.textColor.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        buildTile(years, years == 1 ? 'Year' : 'Years', '🎉'),
        const SizedBox(width: 12),
        buildTile(months, months == 1 ? 'Month' : 'Months', '🗓'),
        const SizedBox(width: 12),
        buildTile(days, days == 1 ? 'Day' : 'Days', '💖'),
      ],
    );
  }
}
