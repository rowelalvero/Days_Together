import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/features/settings/domain/entities/notification_preferences_model.dart';
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

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 20,
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          NotificationSwitchTile(
            title: 'Enable Quiet Hours',
            subtitle: 'Silence alerts during specific hours',
            value: prefs.quietHoursEnabled,
            onChanged: prefs.muteAll
                ? null
                : (_) => onTogglePreference('quiet_hours_enabled'),
            theme: theme,
          ),
          if (prefs.quietHoursEnabled && !prefs.muteAll) ...[
            const Divider(height: 1),
            ListTile(
              title: Text(
                'Start Time',
                style: AppTypography.body(fontSize: 15, color: theme.textColor),
              ),
              trailing: Text(
                prefs.quietHoursStart,
                style: AppTypography.body(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: theme.accentColor,
                ),
              ),
              onTap: onSelectStartTime,
            ),
            const Divider(height: 1),
            ListTile(
              title: Text(
                'End Time',
                style: AppTypography.body(fontSize: 15, color: theme.textColor),
              ),
              trailing: Text(
                prefs.quietHoursEnd,
                style: AppTypography.body(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: theme.accentColor,
                ),
              ),
              onTap: onSelectEndTime,
            ),
          ],
        ],
      ),
    );
  }
}
