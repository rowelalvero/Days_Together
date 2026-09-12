import 'package:days_together/features/settings/notification_preferences_controller.dart';
import 'package:days_together/features/settings/presentation/widgets/feature_notifications_card.dart';
import 'package:days_together/features/settings/presentation/widgets/global_preferences_card.dart';
import 'package:days_together/features/settings/presentation/widgets/notification_section_header.dart';
import 'package:days_together/features/settings/presentation/widgets/quiet_hours_card.dart';
import 'package:days_together/features/theme/theme_controller.dart';
import 'package:days_together/app/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The notification preferences screen: global toggles, quiet hours, and
/// per-feature notification switches.
///
/// Its inline section cards and `_buildX` methods were extracted into
/// widgets under `presentation/widgets/` (Migration audit item 6).
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  Future<void> _selectTime(
    BuildContext context,
    NotificationPreferencesController notifier,
    String key,
    String currentTime,
  ) async {
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
    final notifier = ref.read(
      notificationPreferencesControllerProvider.notifier,
    );
    final prefs = state.preferences;

    // A failed toggle leaves the switch where it was -- the Supabase write
    // runs before the local state update -- so without this the tap looked
    // like it simply did nothing. The controller publishes the failure and
    // this reports it, then clears it so the same error cannot reappear on
    // an unrelated rebuild.
    ref.listen(notificationPreferencesControllerProvider, (previous, next) {
      final failure = next.failure;
      if (failure == null || previous?.failure == failure) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Couldn't save that setting. ${failure.message}"),
          backgroundColor: Colors.redAccent,
        ),
      );
      notifier.clearFailure();
    });

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
        // Only spin when there is genuinely nothing to show. With a cached
        // copy in hand the refresh happens behind the existing values rather
        // than behind a spinner.
        child: prefs == null
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      NotificationSectionHeader(
                        title: 'Global Preferences',
                        theme: theme,
                      ),
                      const SizedBox(height: 12),
                      GlobalPreferencesCard(
                        prefs: prefs,
                        theme: theme,
                        onTogglePreference: notifier.togglePreference,
                      ),
                      const SizedBox(height: 32),
                      NotificationSectionHeader(
                        title: 'Quiet Hours',
                        theme: theme,
                      ),
                      const SizedBox(height: 12),
                      QuietHoursCard(
                        prefs: prefs,
                        theme: theme,
                        onTogglePreference: notifier.togglePreference,
                        onSelectStartTime: () => _selectTime(
                          context,
                          notifier,
                          'quiet_hours_start',
                          prefs.quietHoursStart,
                        ),
                        onSelectEndTime: () => _selectTime(
                          context,
                          notifier,
                          'quiet_hours_end',
                          prefs.quietHoursEnd,
                        ),
                      ),
                      const SizedBox(height: 32),
                      NotificationSectionHeader(
                        title: 'Feature Notifications',
                        theme: theme,
                      ),
                      const SizedBox(height: 12),
                      FeatureNotificationsCard(
                        prefs: prefs,
                        theme: theme,
                        onTogglePreference: notifier.togglePreference,
                      ),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
