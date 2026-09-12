import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:days_together/features/gift_reminders/domain/entities/gift_reminder_model.dart';
import 'package:days_together/features/gift_reminders/gift_reminder_controller.dart';
import 'package:days_together/features/gift_reminders/presentation/sheets/add_gift_reminder_sheet.dart';
import 'package:days_together/features/gift_reminders/presentation/widgets/gift_reminders_app_bar.dart';
import 'package:days_together/features/gift_reminders/presentation/widgets/gift_reminders_empty_state.dart';
import 'package:days_together/features/gift_reminders/presentation/widgets/gift_reminders_list_view.dart';
import 'package:days_together/features/theme/theme_controller.dart';

/// The couple's gift/date reminders: an add-reminder FAB and a list of
/// upcoming reminders, each toggleable, editable, and deletable.
///
/// Its `_buildX` methods and inline `_showReminderSheet` were extracted
/// into focused widgets under `presentation/widgets/` and `presentation/
/// sheets/` (Migration audit item 6) -- this class no longer owns any
/// screen-lifetime state of its own.
class GiftRemindersScreen extends ConsumerWidget {
  const GiftRemindersScreen({super.key});

  void _showReminderSheet(
    BuildContext context, {
    GiftReminder? existingReminder,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          AddGiftReminderSheet(existingReminder: existingReminder),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeControllerProvider);
    final theme = themeState.currentLoveTheme;
    final giftState = ref.watch(giftReminderControllerProvider);
    final giftNotifier = ref.read(giftReminderControllerProvider.notifier);

    return Scaffold(
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(gradient: themeState.currentGradient),
          ),
          SafeArea(
            child: Column(
              children: [
                GiftRemindersAppBar(theme: theme),
                Expanded(
                  child: giftState.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : giftState.reminders.isEmpty
                      ? GiftRemindersEmptyState(theme: theme)
                      : GiftRemindersListView(
                          state: giftState,
                          notifier: giftNotifier,
                          theme: theme,
                          onEditReminder: (reminder) => _showReminderSheet(
                            context,
                            existingReminder: reminder,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showReminderSheet(context),
        backgroundColor: theme.accentColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
