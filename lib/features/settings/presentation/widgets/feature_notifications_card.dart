import 'package:flutter/material.dart';

import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/features/settings/domain/entities/notification_preferences_model.dart';
import 'package:days_together/features/settings/presentation/widgets/notification_switch_tile.dart';
import 'package:days_together/shared/widgets/glass_container.dart';

/// The per-feature notification toggle card on
/// [NotificationSettingsScreen] (Chat, Bucket List, Love Meter, ...).
/// Extracted from its inline `build()` (Migration audit item 6).
class FeatureNotificationsCard extends StatelessWidget {
  const FeatureNotificationsCard({
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
    ValueChanged<bool>? toggle(String key) =>
        prefs.muteAll ? null : (_) => onTogglePreference(key);

    return GlassContainer(
      borderRadius: 20,
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          NotificationSwitchTile(
            title: 'Chat',
            subtitle: 'Private messaging notes',
            value: prefs.chatEnabled,
            onChanged: toggle('chat_enabled'),
            theme: theme,
          ),
          const Divider(height: 1),
          NotificationSwitchTile(
            title: 'Bucket List',
            subtitle: 'Completed, updated, or added items',
            value: prefs.bucketListEnabled,
            onChanged: toggle('bucket_list_enabled'),
            theme: theme,
          ),
          const Divider(height: 1),
          NotificationSwitchTile(
            title: 'Love Meter',
            subtitle: 'Mood updates and feeling shares',
            value: prefs.loveMeterEnabled,
            onChanged: toggle('love_meter_enabled'),
            theme: theme,
          ),
          const Divider(height: 1),
          NotificationSwitchTile(
            title: 'Daily Prompt',
            subtitle: 'Sync prompt completed alerts',
            value: prefs.dailyPromptEnabled,
            onChanged: toggle('daily_prompt_enabled'),
            theme: theme,
          ),
          const Divider(height: 1),
          NotificationSwitchTile(
            title: 'Scrapbook',
            subtitle: 'New shared drawings, text & photos',
            value: prefs.doodleNotesEnabled,
            onChanged: toggle('doodle_notes_enabled'),
            theme: theme,
          ),
          const Divider(height: 1),
          NotificationSwitchTile(
            title: 'Timeline',
            subtitle: 'New memory additions and comments',
            value: prefs.timelineEnabled,
            onChanged: toggle('timeline_enabled'),
            theme: theme,
          ),
          const Divider(height: 1),
          NotificationSwitchTile(
            title: 'Time Capsule',
            subtitle: 'Lock and ready-to-open alerts',
            value: prefs.timeCapsuleEnabled,
            onChanged: toggle('time_capsule_enabled'),
            theme: theme,
          ),
          const Divider(height: 1),
          NotificationSwitchTile(
            title: 'Calendar',
            subtitle: 'Events, anniversaries, and reminders',
            value: prefs.calendarEnabled,
            onChanged: toggle('calendar_enabled'),
            theme: theme,
          ),
          const Divider(height: 1),
          NotificationSwitchTile(
            title: 'Love Notes',
            subtitle: 'Voice, photo, or handwritten notes',
            value: prefs.loveNotesEnabled,
            onChanged: toggle('love_notes_enabled'),
            theme: theme,
          ),
          const Divider(height: 1),
          NotificationSwitchTile(
            title: 'Gifts',
            subtitle: 'Gifts ideas and reminders',
            value: prefs.giftsEnabled,
            onChanged: toggle('gifts_enabled'),
            theme: theme,
          ),
          const Divider(height: 1),
          NotificationSwitchTile(
            title: 'Relationship',
            subtitle: 'License or profile changes',
            value: prefs.relationshipEnabled,
            onChanged: toggle('relationship_enabled'),
            theme: theme,
          ),
          const Divider(height: 1),
          NotificationSwitchTile(
            title: 'Memories',
            subtitle: 'Shared album updates',
            value: prefs.memoriesEnabled,
            onChanged: toggle('memories_enabled'),
            theme: theme,
          ),
        ],
      ),
    );
  }
}
