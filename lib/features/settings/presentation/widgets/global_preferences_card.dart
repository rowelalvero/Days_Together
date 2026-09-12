import 'package:flutter/material.dart';

import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/features/settings/domain/entities/notification_preferences_model.dart';
import 'package:days_together/features/settings/presentation/widgets/notification_card_divider.dart';
import 'package:days_together/features/settings/presentation/widgets/notification_switch_tile.dart';
import 'package:days_together/shared/widgets/glass_container.dart';

/// The "Mute All / Sound / Vibrate / Badge Count" card on
/// [NotificationSettingsScreen]. Extracted from its inline `build()`
/// (Migration audit item 6).
class GlobalPreferencesCard extends StatelessWidget {
  const GlobalPreferencesCard({
    super.key,
    required this.prefs,
    required this.theme,
    required this.onTogglePreference,
  });

  final NotificationPreferences prefs;
  final LoveStoryTheme theme;
  final ValueChanged<String> onTogglePreference;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: 20,
      opacity: 0.03,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          NotificationSwitchTile(
            icon: Icons.notifications_off_outlined,
            title: 'Mute All Notifications',
            subtitle: 'Silence all notifications temporarily',
            value: prefs.muteAll,
            onChanged: (_) => onTogglePreference('mute_all'),
            theme: theme,
          ),
          NotificationCardDivider(theme: theme),
          NotificationSwitchTile(
            icon: Icons.volume_up_outlined,
            title: 'Play Sound',
            subtitle: 'Play alert sound on arrival',
            value: prefs.soundEnabled,
            onChanged: prefs.muteAll
                ? null
                : (_) => onTogglePreference('sound_enabled'),
            theme: theme,
          ),
          NotificationCardDivider(theme: theme),
          NotificationSwitchTile(
            icon: Icons.vibration_rounded,
            title: 'Vibrate',
            subtitle: 'Haptic feedback on alerts',
            value: prefs.vibrationEnabled,
            onChanged: prefs.muteAll
                ? null
                : (_) => onTogglePreference('vibration_enabled'),
            theme: theme,
          ),
          NotificationCardDivider(theme: theme),
          NotificationSwitchTile(
            icon: Icons.numbers_rounded,
            title: 'App Badge Count',
            subtitle: 'Show unread message badge count',
            value: prefs.badgeCountEnabled,
            onChanged: prefs.muteAll
                ? null
                : (_) => onTogglePreference('badge_count_enabled'),
            theme: theme,
          ),
        ],
      ),
    );
  }
}
