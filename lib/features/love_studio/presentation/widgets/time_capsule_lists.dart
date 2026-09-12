import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/features/love_studio/domain/entities/time_capsule_model.dart';
import 'package:days_together/features/love_studio/presentation/dialogs/capsule_detail_dialog.dart';
import 'package:days_together/features/love_studio/presentation/widgets/time_capsule_card.dart';
import 'package:days_together/features/love_studio/time_capsule_controller.dart';
import 'package:days_together/features/love_studio/time_capsule_state.dart';

/// The ready/sealed/opened capsule sections on [TimeCapsuleScreen].
/// Extracted from its `_buildCapsuleLists`/`_buildSectionHeader`
/// (Migration audit item 6).
class TimeCapsuleLists extends StatelessWidget {
  const TimeCapsuleLists({
    super.key,
    required this.state,
    required this.notifier,
    required this.theme,
  });

  final TimeCapsuleState state;
  final TimeCapsuleController notifier;
  final LoveStoryTheme theme;

  void _openCapsule(BuildContext context, TimeCapsule capsule) {
    if (!capsule.isOpened && capsule.canOpen) {
      notifier.openCapsule(capsule.id);
    }
    showDialog(
      context: context,
      builder: (ctx) => CapsuleDetailDialog(capsule: capsule, theme: theme),
    );
  }

  @override
  Widget build(BuildContext context) {
    final openable = state.openableCapsules;
    final locked = state.lockedCapsules;
    final opened = state.openedCapsules;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 96),
      children: [
        if (openable.isNotEmpty) ...[
          _SectionHeader(title: '🔓 Ready to Open', theme: theme),
          const SizedBox(height: 8),
          ...openable.map(
            (c) => TimeCapsuleCard(
              capsule: c,
              theme: theme,
              isOpenable: true,
              onOpen: () => _openCapsule(context, c),
              onDelete: () => notifier.deleteCapsule(c.id),
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (locked.isNotEmpty) ...[
          _SectionHeader(title: '🔒 Sealed & Waiting', theme: theme),
          const SizedBox(height: 8),
          ...locked.map(
            (c) => TimeCapsuleCard(
              capsule: c,
              theme: theme,
              isOpenable: false,
              onOpen: () => _openCapsule(context, c),
              onDelete: () => notifier.deleteCapsule(c.id),
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (opened.isNotEmpty) ...[
          _SectionHeader(title: '📖 Opened Memories', theme: theme),
          const SizedBox(height: 8),
          ...opened.map(
            (c) => TimeCapsuleCard(
              capsule: c,
              theme: theme,
              isOpenable: false,
              onOpen: () => _openCapsule(context, c),
              onDelete: () => notifier.deleteCapsule(c.id),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.theme});

  final String title;
  final LoveStoryTheme theme;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: AppTypography.heading(
        fontSize: 16,
        color: theme.textColor.withValues(alpha: 0.7),
      ),
    );
  }
}
