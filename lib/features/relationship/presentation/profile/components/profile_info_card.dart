import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/core/utils/date_helper.dart';
import 'package:days_together/features/relationship/profile_state.dart';
import 'package:days_together/features/relationship/workspace_controller.dart';
import 'package:days_together/features/relationship/workspace_state.dart';
import 'package:days_together/shared/widgets/glass_container.dart';

/// The "Foundation" / "Duration" / "Registry Details" bento sections on
/// [RelationshipProfileScreen]. Extracted from its `_buildInfoCard` (plus
/// its `_buildBentoSection`/`_editDate`/`_editTime` helpers and the
/// `_StatTile` row widget) as part of Migration audit item 6.
class ProfileInfoCard extends ConsumerWidget {
  const ProfileInfoCard({
    super.key,
    required this.workspaceState,
    required this.profileState,
    required this.theme,
  });

  final WorkspaceState workspaceState;
  final ProfileState profileState;
  final LoveStoryTheme theme;

  Future<void> _editDate(BuildContext context, WidgetRef ref) async {
    final date = await showDatePicker(
      context: context,
      initialDate: workspaceState.startDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: theme.accentColor,
            brightness: theme.isDark ? Brightness.dark : Brightness.light,
          ),
        ),
        child: child!,
      ),
    );
    if (date != null) {
      await ref.read(workspaceControllerProvider.notifier).setStartDate(date);
    }
  }

  Future<void> _editTime(BuildContext context, WidgetRef ref) async {
    final time = await showTimePicker(
      context: context,
      initialTime: workspaceState.startTime ?? TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: theme.accentColor,
            brightness: theme.isDark ? Brightness.dark : Brightness.light,
          ),
        ),
        child: child!,
      ),
    );
    if (time != null) {
      await ref.read(workspaceControllerProvider.notifier).setStartTime(time);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final start = workspaceState.startDate;
    final formattedStart = start != null
        ? DateFormat('MMMM dd, yyyy').format(start)
        : 'Not Set';
    final formattedTime = workspaceState.startTime != null
        ? workspaceState.startTime!.format(context)
        : '12:00 AM';
    final ageStr = DateHelper.relationshipAgeLabel(
      workspaceState.startDate,
      workspaceState.startTime,
    );

    return Column(
      children: [
        _BentoSection(
          title: 'Foundation',
          theme: theme,
          items: [
            _StatTile(
              icon: Icons.calendar_today_rounded,
              label: 'Anniversary',
              value: formattedStart,
              theme: theme,
              onTap: () => _editDate(context, ref),
            ),
            _StatTile(
              icon: Icons.access_time_rounded,
              label: 'Time',
              value: formattedTime,
              theme: theme,
              onTap: () => _editTime(context, ref),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _BentoSection(
          title: 'Duration',
          theme: theme,
          items: [
            _StatTile(
              icon: Icons.hourglass_empty_rounded,
              label: 'Time Together',
              value: ageStr,
              theme: theme,
              isFullWidth: true,
            ),
          ],
        ),
        const SizedBox(height: 24),
        _BentoSection(
          title: 'Registry Details',
          theme: theme,
          items: [
            _StatTile(
              icon: Icons.person_pin_rounded,
              label: 'Your Join Date',
              value: profileState.yourJoinDate != null
                  ? DateFormat(
                      'MMM dd, yyyy',
                    ).format(profileState.yourJoinDate!)
                  : '...',
              theme: theme,
            ),
            _StatTile(
              icon: Icons.people_outline_rounded,
              label: 'Partner Join Date',
              value: profileState.partnerJoinDate != null
                  ? DateFormat(
                      'MMM dd, yyyy',
                    ).format(profileState.partnerJoinDate!)
                  : 'Waiting...',
              theme: theme,
            ),
          ],
        ),
      ],
    );
  }
}

class _BentoSection extends StatelessWidget {
  const _BentoSection({
    required this.title,
    required this.items,
    required this.theme,
  });

  final String title;
  final List<Widget> items;
  final LoveStoryTheme theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 12),
          child: Text(
            title.toUpperCase(),
            style: AppTypography.captionMono(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: theme.accentColor,
            ).copyWith(letterSpacing: 1.5),
          ),
        ),
        if (items.length > 1)
          Row(
            children: items
                .map(
                  (item) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: item,
                    ),
                  ),
                )
                .toList(),
          )
        else
          ...items,
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.theme,
    this.onTap,
    this.isFullWidth = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final LoveStoryTheme theme;
  final VoidCallback? onTap;
  final bool isFullWidth;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        width: isFullWidth ? double.infinity : null,
        padding: const EdgeInsets.all(20),
        borderRadius: 20,
        opacity: 0.05,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.accentColor, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.captionMono(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: theme.textColor.withValues(alpha: 0.4),
                    ).copyWith(letterSpacing: 0.5),
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.edit_rounded,
                    color: theme.accentColor.withValues(alpha: 0.5),
                    size: 14,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: AppTypography.body(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: theme.textColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
