import 'package:flutter/material.dart';
import 'package:days_together/features/dashboard/presentation/cards/bucket_list_bento_card.dart';
import 'package:days_together/features/dashboard/presentation/cards/daily_mood_bento_card.dart';
import 'package:days_together/features/dashboard/presentation/cards/daily_sync_bento_card.dart';
import 'package:days_together/features/dashboard/presentation/cards/doodle_notes_bento_card.dart';
import 'package:days_together/features/dashboard/presentation/cards/emotional_map_bento_card.dart';
import 'package:days_together/features/dashboard/presentation/cards/love_chat_bento_card.dart';
import 'package:days_together/features/dashboard/presentation/cards/secret_vault_bento_card.dart';
import 'package:days_together/features/dashboard/presentation/cards/shared_calendar_bento_card.dart';
import 'package:days_together/features/dashboard/presentation/cards/time_capsule_bento_card.dart';
import 'package:days_together/themes/theme_manager.dart';

/// Bento Grid dashboard layout orchestrator.
/// Arranges responsive glassmorphic cards for all core couple experiences.
class BentoGrid extends StatelessWidget {
  final LoveStoryTheme theme;

  const BentoGrid({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DoodleNotesBentoCard(theme: theme),
        const SizedBox(height: 16),
        SharedCalendarBentoCard(theme: theme),
        const SizedBox(height: 16),
        DailyMoodBentoCard(theme: theme),
        const SizedBox(height: 16),
        EmotionalMapBentoCard(theme: theme),
        const SizedBox(height: 16),
        DailySyncBentoCard(theme: theme),
        const SizedBox(height: 16),
        BucketListBentoCard(theme: theme),
        const SizedBox(height: 16),
        TimeCapsuleBentoCard(theme: theme),
        const SizedBox(height: 16),
        SecretVaultBentoCard(theme: theme),
        const SizedBox(height: 16),
        LoveChatBentoCard(theme: theme),
      ],
    );
  }
}
