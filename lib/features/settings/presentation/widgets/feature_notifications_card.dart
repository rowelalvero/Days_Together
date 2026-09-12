import 'package:flutter/material.dart';

import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/features/settings/domain/entities/notification_preferences_model.dart';
import 'package:days_together/features/settings/presentation/widgets/notification_card_divider.dart';
import 'package:days_together/features/settings/presentation/widgets/notification_switch_tile.dart';
import 'package:days_together/shared/widgets/glass_container.dart';

typedef _FeatureRow = ({
  IconData icon,
  String title,
  String subtitle,
  bool value,
  String key,
});

/// The per-feature notification toggle card on
/// [NotificationSettingsScreen] (Chat, Bucket List, Love Meter, ...).
/// Extracted from its inline `build()` (Migration audit item 6).
///
/// The twelve rows are built from a list rather than spelled out one by
/// one: they differ only in icon, copy, preference key, and current value,
/// and the hand-interleaved dividers between them were an easy thing to
/// get wrong when a row was added.
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
    final rows = <_FeatureRow>[
      (
        icon: Icons.chat_bubble_outline_rounded,
        title: 'Chat',
        subtitle: 'Private messaging notes',
        value: prefs.chatEnabled,
        key: 'chat_enabled',
      ),
      (
        icon: Icons.checklist_rounded,
        title: 'Bucket List',
        subtitle: 'Completed, updated, or added items',
        value: prefs.bucketListEnabled,
        key: 'bucket_list_enabled',
      ),
      (
        icon: Icons.favorite_outline_rounded,
        title: 'Love Meter',
        subtitle: 'Mood updates and feeling shares',
        value: prefs.loveMeterEnabled,
        key: 'love_meter_enabled',
      ),
      (
        icon: Icons.wb_twilight_rounded,
        title: 'Daily Prompt',
        subtitle: 'Sync prompt completed alerts',
        value: prefs.dailyPromptEnabled,
        key: 'daily_prompt_enabled',
      ),
      (
        icon: Icons.brush_outlined,
        title: 'Scrapbook',
        subtitle: 'New shared drawings, text & photos',
        value: prefs.doodleNotesEnabled,
        key: 'doodle_notes_enabled',
      ),
      (
        icon: Icons.auto_stories_outlined,
        title: 'Timeline',
        subtitle: 'New memory additions and comments',
        value: prefs.timelineEnabled,
        key: 'timeline_enabled',
      ),
      (
        icon: Icons.hourglass_bottom_rounded,
        title: 'Time Capsule',
        subtitle: 'Lock and ready-to-open alerts',
        value: prefs.timeCapsuleEnabled,
        key: 'time_capsule_enabled',
      ),
      (
        icon: Icons.calendar_today_rounded,
        title: 'Calendar',
        subtitle: 'Events, anniversaries, and reminders',
        value: prefs.calendarEnabled,
        key: 'calendar_enabled',
      ),
      (
        icon: Icons.mail_outline_rounded,
        title: 'Love Notes',
        subtitle: 'Voice, photo, or handwritten notes',
        value: prefs.loveNotesEnabled,
        key: 'love_notes_enabled',
      ),
      (
        icon: Icons.card_giftcard_rounded,
        title: 'Gifts',
        subtitle: 'Gifts ideas and reminders',
        value: prefs.giftsEnabled,
        key: 'gifts_enabled',
      ),
      (
        icon: Icons.workspace_premium_outlined,
        title: 'Relationship',
        subtitle: 'License or profile changes',
        value: prefs.relationshipEnabled,
        key: 'relationship_enabled',
      ),
      (
        icon: Icons.photo_library_outlined,
        title: 'Memories',
        subtitle: 'Shared album updates',
        value: prefs.memoriesEnabled,
        key: 'memories_enabled',
      ),
    ];

    return GlassContainer(
      borderRadius: 20,
      opacity: 0.03,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) NotificationCardDivider(theme: theme),
            NotificationSwitchTile(
              icon: rows[i].icon,
              title: rows[i].title,
              subtitle: rows[i].subtitle,
              value: rows[i].value,
              onChanged: prefs.muteAll
                  ? null
                  : (_) => onTogglePreference(rows[i].key),
              theme: theme,
            ),
          ],
        ],
      ),
    );
  }
}
