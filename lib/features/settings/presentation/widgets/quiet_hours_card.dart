import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/features/settings/domain/entities/notification_preferences_model.dart';
import 'package:days_together/features/settings/presentation/widgets/notification_card_divider.dart';
import 'package:days_together/features/settings/presentation/widgets/notification_switch_tile.dart';
import 'package:days_together/shared/widgets/glass_container.dart';

/// The "Enable Quiet Hours" + start/end time card on
/// [NotificationSettingsScreen]. Extracted from its inline `build()`
/// (Migration audit item 6) -- the actual `showTimePicker` calls
/// (`_selectTime`) stay on the screen, since they're state mutations, not
/// rendering.
class QuietHoursCard extends StatelessWidget {
  const QuietHoursCard({
    super.key,
    required this.prefs,
    required this.theme,
    required this.onTogglePreference,
    required this.onSelectStartTime,
    required this.onSelectEndTime,
  });

  final NotificationPreferences prefs;
  final LoveStoryTheme theme;
  final ValueChanged<String> onTogglePreference;
  final VoidCallback onSelectStartTime;
  final VoidCallback onSelectEndTime;

  Widget _timeRow({
    required IconData icon,
    required String label,
    required String time,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.textColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: theme.textColor.withValues(alpha: 0.7),
          size: 20,
        ),
      ),
      title: Text(
        label,
        style: AppTypography.body(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: theme.textColor,
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: theme.accentColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.accentColor.withValues(alpha: 0.25)),
        ),
        child: Text(
          time,
          style: AppTypography.body(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: theme.accentColor,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 20,
      opacity: 0.03,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          NotificationSwitchTile(
            icon: Icons.bedtime_outlined,
            title: 'Enable Quiet Hours',
            subtitle: 'Silence alerts during specific hours',
            value: prefs.quietHoursEnabled,
            onChanged: prefs.muteAll
                ? null
                : (_) => onTogglePreference('quiet_hours_enabled'),
            theme: theme,
          ),
          if (prefs.quietHoursEnabled && !prefs.muteAll) ...[
            NotificationCardDivider(theme: theme),
            _timeRow(
              icon: Icons.nightlight_round,
              label: 'Start Time',
              time: prefs.quietHoursStart,
              onTap: onSelectStartTime,
            ),
            NotificationCardDivider(theme: theme),
            _timeRow(
              icon: Icons.wb_sunny_outlined,
              label: 'End Time',
              time: prefs.quietHoursEnd,
              onTap: onSelectEndTime,
            ),
          ],
        ],
      ),
    );
  }
}
