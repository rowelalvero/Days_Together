import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:days_together/features/love_studio/presentation/sheets/create_time_capsule_sheet.dart';
import 'package:days_together/features/love_studio/presentation/widgets/time_capsule_app_bar.dart';
import 'package:days_together/features/love_studio/presentation/widgets/time_capsule_empty_state.dart';
import 'package:days_together/features/love_studio/presentation/widgets/time_capsule_lists.dart';
import 'package:days_together/features/love_studio/time_capsule_controller.dart';
import 'package:days_together/features/theme/theme_controller.dart';

/// The couple's shared time capsules: an add-capsule FAB and ready/sealed/
/// opened capsule lists.
///
/// Its `_buildX` methods, inline `_showCreateCapsuleSheet`, and
/// `_showCapsuleDetailDialog` were extracted into focused widgets under
/// `presentation/widgets/`, `presentation/sheets/`, and `presentation/
/// dialogs/` (Migration audit item 6) -- this class no longer owns any
/// screen-lifetime state of its own.
class TimeCapsuleScreen extends ConsumerWidget {
  const TimeCapsuleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeProvider = ref.watch(themeControllerProvider);
    final theme = themeProvider.currentLoveTheme;
    final capsuleState = ref.watch(timeCapsuleControllerProvider);
    final capsuleNotifier = ref.read(timeCapsuleControllerProvider.notifier);

    return Scaffold(
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(gradient: themeProvider.currentGradient),
          ),
          SafeArea(
            child: Column(
              children: [
                TimeCapsuleAppBar(theme: theme),
                Expanded(
                  child: capsuleState.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : capsuleState.capsules.isEmpty
                      ? TimeCapsuleEmptyState(theme: theme)
                      : TimeCapsuleLists(
                          state: capsuleState,
                          notifier: capsuleNotifier,
                          theme: theme,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) => CreateTimeCapsuleSheet(theme: theme),
        ),
        backgroundColor: theme.accentColor,
        child: const Icon(Icons.send_rounded, color: Colors.white),
      ),
    );
  }
}
