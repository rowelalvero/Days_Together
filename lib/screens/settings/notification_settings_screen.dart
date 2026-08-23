import 'package:days_together/themes/theme_manager.dart';
import 'package:days_together/features/settings/notification_preferences_controller.dart';
import 'package:days_together/features/theme/theme_controller.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/shared/glass_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  Future<void> _selectTime(BuildContext context, NotificationPreferencesController notifier, String key, String currentTime) async {
    final parts = currentTime.split(':');
    final initialHour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
    final initialMin = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initialHour, minute: initialMin),
    );

    if (picked != null) {
      final hourStr = picked.hour.toString().padLeft(2, '0');
      final minStr = picked.minute.toString().padLeft(2, '0');
      await notifier.updatePreference(key, '$hourStr:$minStr');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeProvider = ref.watch(themeControllerProvider);
    final theme = themeProvider.currentLoveTheme;
    final state = ref.watch(notificationPreferencesControllerProvider);
    final notifier = ref.read(notificationPreferencesControllerProvider.notifier);
    final prefs = state.preferences;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: AppTypography.heading(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: theme.textColor,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: themeProvider.currentGradient),
        child: prefs == null || state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Global Preferences Card
                      _buildSectionHeader('Global Preferences', theme),
                      const SizedBox(height: 12),
                      GlassContainer(
                        borderRadius: 20,
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          children: [
                            _buildSwitchTile(
                              title: 'Mute All Notifications',
                              subtitle: 'Silence all notifications temporarily',
                              value: prefs.muteAll,
                              onChanged: (_) => notifier.togglePreference('mute_all'),
                              theme: theme,
                            ),
                            const Divider(height: 1),
                            _buildSwitchTile(
                              title: 'Play Sound',
                              subtitle: 'Play alert sound on arrival',
                              value: prefs.soundEnabled,
                              onChanged: prefs.muteAll ? null : (_) => notifier.togglePreference('sound_enabled'),
                              theme: theme,
                            ),
                            const Divider(height: 1),
                            _buildSwitchTile(
                              title: 'Vibrate',
                              subtitle: 'Haptic feedback on alerts',
                              value: prefs.vibrationEnabled,
                              onChanged: prefs.muteAll ? null : (_) => notifier.togglePreference('vibration_enabled'),
                              theme: theme,
                            ),
                            const Divider(height: 1),
                            _buildSwitchTile(
                              title: 'App Badge Count',
                              subtitle: 'Show unread message badge count',
                              value: prefs.badgeCountEnabled,
                              onChanged: prefs.muteAll ? null : (_) => notifier.togglePreference('badge_count_enabled'),
                              theme: theme,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Quiet Hours Card
                      _buildSectionHeader('Quiet Hours', theme),
                      const SizedBox(height: 12),
                      GlassContainer(
                        borderRadius: 20,
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          children: [
                            _buildSwitchTile(
                              title: 'Enable Quiet Hours',
                              subtitle: 'Silence alerts during specific hours',
                              value: prefs.quietHoursEnabled,
                              onChanged: prefs.muteAll ? null : (_) => notifier.togglePreference('quiet_hours_enabled'),
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
                                onTap: () => _selectTime(context, notifier, 'quiet_hours_start', prefs.quietHoursStart),
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
                                onTap: () => _selectTime(context, notifier, 'quiet_hours_end', prefs.quietHoursEnd),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Features Card
                      _buildSectionHeader('Feature Notifications', theme),
                      const SizedBox(height: 12),
                      GlassContainer(
                        borderRadius: 20,
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          children: [
                            _buildSwitchTile(
                              title: 'Chat',
                              subtitle: 'Private messaging notes',
                              value: prefs.chatEnabled,
                              onChanged: prefs.muteAll ? null : (_) => notifier.togglePreference('chat_enabled'),
                              theme: theme,
                            ),
                            const Divider(height: 1),
                            _buildSwitchTile(
                              title: 'Bucket List',
                              subtitle: 'Completed, updated, or added items',
                              value: prefs.bucketListEnabled,
                              onChanged: prefs.muteAll ? null : (_) => notifier.togglePreference('bucket_list_enabled'),
                              theme: theme,
                            ),
                            const Divider(height: 1),
                            _buildSwitchTile(
                              title: 'Love Meter',
                              subtitle: 'Mood updates and feeling shares',
                              value: prefs.loveMeterEnabled,
                              onChanged: prefs.muteAll ? null : (_) => notifier.togglePreference('love_meter_enabled'),
                              theme: theme,
                            ),
                            const Divider(height: 1),
                            _buildSwitchTile(
                              title: 'Daily Prompt',
                              subtitle: 'Sync prompt completed alerts',
                              value: prefs.dailyPromptEnabled,
                              onChanged: prefs.muteAll ? null : (_) => notifier.togglePreference('daily_prompt_enabled'),
                              theme: theme,
                            ),
                            const Divider(height: 1),
                            _buildSwitchTile(
                              title: 'Scrapbook',
                              subtitle: 'New shared drawings, text & photos',
                              value: prefs.doodleNotesEnabled,
                              onChanged: prefs.muteAll ? null : (_) => notifier.togglePreference('doodle_notes_enabled'),
                              theme: theme,
                            ),
                            const Divider(height: 1),
                            _buildSwitchTile(
                              title: 'Timeline',
                              subtitle: 'New memory additions and comments',
                              value: prefs.timelineEnabled,
                              onChanged: prefs.muteAll ? null : (_) => notifier.togglePreference('timeline_enabled'),
                              theme: theme,
                            ),
                            const Divider(height: 1),
                            _buildSwitchTile(
                              title: 'Time Capsule',
                              subtitle: 'Lock and ready-to-open alerts',
                              value: prefs.timeCapsuleEnabled,
                              onChanged: prefs.muteAll ? null : (_) => notifier.togglePreference('time_capsule_enabled'),
                              theme: theme,
                            ),
                            const Divider(height: 1),
                            _buildSwitchTile(
                              title: 'Calendar',
                              subtitle: 'Events, anniversaries, and reminders',
                              value: prefs.calendarEnabled,
                              onChanged: prefs.muteAll ? null : (_) => notifier.togglePreference('calendar_enabled'),
                              theme: theme,
                            ),
                            const Divider(height: 1),
                            _buildSwitchTile(
                              title: 'Love Notes',
                              subtitle: 'Voice, photo, or handwritten notes',
                              value: prefs.loveNotesEnabled,
                              onChanged: prefs.muteAll ? null : (_) => notifier.togglePreference('love_notes_enabled'),
                              theme: theme,
                            ),
                            const Divider(height: 1),
                            _buildSwitchTile(
                              title: 'Vault',
                              subtitle: 'Secure uploads (details kept private)',
                              value: prefs.vaultEnabled,
                              onChanged: prefs.muteAll ? null : (_) => notifier.togglePreference('vault_enabled'),
                              theme: theme,
                            ),
                            const Divider(height: 1),
                            _buildSwitchTile(
                              title: 'Gifts',
                              subtitle: 'Gifts ideas and reminders',
                              value: prefs.giftsEnabled,
                              onChanged: prefs.muteAll ? null : (_) => notifier.togglePreference('gifts_enabled'),
                              theme: theme,
                            ),
                            const Divider(height: 1),
                            _buildSwitchTile(
                              title: 'Relationship',
                              subtitle: 'License or profile changes',
                              value: prefs.relationshipEnabled,
                              onChanged: prefs.muteAll ? null : (_) => notifier.togglePreference('relationship_enabled'),
                              theme: theme,
                            ),
                            const Divider(height: 1),
                            _buildSwitchTile(
                              title: 'Memories',
                              subtitle: 'Shared album updates',
                              value: prefs.memoriesEnabled,
                              onChanged: prefs.muteAll ? null : (_) => notifier.togglePreference('memories_enabled'),
                              theme: theme,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, LoveStoryTheme theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: AppTypography.bodyLarge(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: theme.textColor.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required void Function(bool)? onChanged,
    required LoveStoryTheme theme,
  }) {
    return SwitchListTile(
      title: Text(
        title,
        style: AppTypography.body(fontSize: 15, fontWeight: FontWeight.w600, color: theme.textColor),
      ),
      subtitle: Text(
        subtitle,
        style: AppTypography.caption(fontSize: 12, color: theme.textColor.withValues(alpha: 0.54)),
      ),
      value: value,
      onChanged: onChanged,
      activeThumbColor: theme.accentColor,
      inactiveTrackColor: theme.textColor.withValues(alpha: 0.1),
    );
  }
}
