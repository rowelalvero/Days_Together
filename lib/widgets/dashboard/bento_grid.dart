import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:days_together/widgets/glass_container.dart';

// Providers
import 'package:days_together/providers/noteit_provider.dart';
import 'package:days_together/models/noteit_model.dart';
import 'package:days_together/providers/calendar_provider.dart';
import 'package:days_together/providers/daily_mood_provider.dart';
import 'package:days_together/providers/bucket_list_provider.dart';
import 'package:days_together/providers/time_capsule_provider.dart';
import 'package:days_together/providers/vault_provider.dart';
import 'package:days_together/providers/love_chat_provider.dart';

// Screens
import 'package:days_together/screens/together/noteit_screen.dart';
import 'package:days_together/screens/together/calendar_screen.dart';
import 'package:days_together/screens/together/love_meter_screen.dart';
import 'package:days_together/screens/together/bucket_list_screen.dart';
import 'package:days_together/screens/studio/time_capsule_screen.dart';
import 'package:days_together/screens/together/vault_screen.dart';
import 'package:days_together/screens/together/love_chat_screen.dart';

class BentoGrid extends StatelessWidget {
  final dynamic theme;

  const BentoGrid({
    super.key,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildBentoRow(
          context,
          title: 'LOVE NOTES',
          subtitle: 'Latest shared doodles & letters',
          icon: Icons.favorite_rounded,
          color: Colors.pinkAccent,
          child: _buildNoteItContent(context),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NoteitScreen()),
          ),
        ),
        const SizedBox(height: 16),
        _buildBentoRow(
          context,
          title: 'SHARED CALENDAR',
          subtitle: 'Upcoming dates & milestones',
          icon: Icons.calendar_month_rounded,
          color: Colors.blueAccent,
          child: _buildCalendarContent(context),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CalendarScreen()),
          ),
        ),
        const SizedBox(height: 16),
        _buildBentoRow(
          context,
          title: 'DAILY MOOD',
          subtitle: 'Check in on each other\'s feelings',
          icon: Icons.emoji_emotions_rounded,
          color: Colors.amberAccent,
          child: _buildMoodContent(context),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LoveMeterScreen()),
          ),
        ),
        const SizedBox(height: 16),
        _buildBentoRow(
          context,
          title: 'EMOTIONAL MAP',
          subtitle: 'Mood trend analytics sparkline',
          icon: Icons.trending_up_rounded,
          color: Colors.greenAccent,
          child: _buildEmotionalMapContent(context),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LoveMeterScreen()),
          ),
        ),
        const SizedBox(height: 16),
        _buildBentoRow(
          context,
          title: 'DAILY SYNC QUESTION',
          subtitle: 'Today\'s relationship question',
          icon: Icons.question_answer_rounded,
          color: Colors.purpleAccent,
          child: _buildSyncQuestionContent(context),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LoveMeterScreen()),
          ),
        ),
        const SizedBox(height: 16),
        _buildBentoRow(
          context,
          title: 'BUCKET LIST',
          subtitle: 'Things you want to do together',
          icon: Icons.list_alt_rounded,
          color: Colors.orangeAccent,
          child: _buildBucketListContent(context),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BucketListScreen()),
          ),
        ),
        const SizedBox(height: 16),
        _buildBentoRow(
          context,
          title: 'TIME CAPSULES',
          subtitle: 'Lock messages for the future',
          icon: Icons.hourglass_bottom_rounded,
          color: Colors.tealAccent,
          child: _buildTimeCapsuleContent(context),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TimeCapsuleScreen()),
          ),
        ),
        const SizedBox(height: 16),
        _buildBentoRow(
          context,
          title: 'SECRET VAULT',
          subtitle: 'Private photos & letters storage',
          icon: Icons.lock_rounded,
          color: Colors.redAccent,
          child: _buildVaultContent(context),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const VaultScreen()),
          ),
        ),
        const SizedBox(height: 16),
        _buildBentoRow(
          context,
          title: 'LOVE CHAT',
          subtitle: 'Your private chat channel',
          icon: Icons.chat_bubble_rounded,
          color: Colors.cyanAccent,
          child: _buildLoveChatContent(context),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LoveChatScreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildBentoRow(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Widget child,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: GlassContainer(
        padding: const EdgeInsets.all(18),
        borderRadius: 24,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: Colors.white38,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  // NOTEIT PREVIEW CONTENT
  Widget _buildNoteItContent(BuildContext context) {
    final noteit = context.watch<NoteitProvider>();
    final notes = noteit.notes;

    if (notes.isEmpty) {
      return Text(
        'Send a love note, sketch, or photo directly to your partner\'s screen! 💌',
        style: GoogleFonts.inter(fontSize: 12, color: Colors.white70, height: 1.4),
      );
    }

    final latest = notes.first;
    final senderName = latest.sender == 'you' ? 'You' : 'Partner';

    String previewText = '';
    if (latest.type == NoteitType.text) {
      previewText = latest.content ?? '';
    } else if (latest.type == NoteitType.drawing) {
      previewText = 'Sent a beautiful drawing 🎨';
    } else if (latest.type == NoteitType.photo) {
      previewText = 'Shared a photo memory 📸';
    }

    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: latest.backgroundColor ?? Colors.pinkAccent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Icon(
              latest.type == NoteitType.photo
                  ? Icons.photo_rounded
                  : (latest.type == NoteitType.drawing
                      ? Icons.brush_rounded
                      : Icons.chat_bubble_outline_rounded),
              color: Colors.white,
              size: 16,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                senderName,
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: theme.accentColor),
              ),
              const SizedBox(height: 2),
              Text(
                previewText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontSize: 13, color: Colors.white70),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // CALENDAR PREVIEW CONTENT
  Widget _buildCalendarContent(BuildContext context) {
    final calendar = context.watch<CalendarProvider>();
    final events = calendar.events.toList();

    // Sort to find the next upcoming event
    final now = DateTime.now();
    events.sort((a, b) => a.date.compareTo(b.date));
    final upcoming = events.where((e) => e.date.isAfter(now) || (e.date.year == now.year && e.date.month == now.month && e.date.day == now.day)).toList();

    if (upcoming.isEmpty) {
      return Text(
        'No upcoming dates or anniversaries planned. Plan your next romantic date! 📅',
        style: GoogleFonts.inter(fontSize: 12, color: Colors.white70, height: 1.4),
      );
    }

    final event = upcoming.first;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.blueAccent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                DateFormat('MMM').format(event.date).toUpperCase(),
                style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueAccent),
              ),
              Text(
                DateFormat('dd').format(event.date),
                style: GoogleFonts.jetBrainsMono(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 2),
              Text(
                event.description != null && event.description!.isNotEmpty
                    ? event.description!
                    : 'Upcoming couple plans',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontSize: 11, color: Colors.white54),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // DAILY MOOD PREVIEW CONTENT
  Widget _buildMoodContent(BuildContext context) {
    final dailyMood = context.watch<DailyMoodProvider>();
    final myToday = dailyMood.todayMood;
    final moods = dailyMood.moods;

    if (moods.isEmpty) {
      return Text(
        'Start tracking your daily emotional score to synchronize maps! 😊',
        style: GoogleFonts.inter(fontSize: 12, color: Colors.white70, height: 1.4),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.circle, color: Colors.amberAccent, size: 8),
            const SizedBox(width: 6),
            Text(
              myToday != null 
                  ? 'Logged today: ${myToday.moodScore}/10 score'
                  : 'You haven\'t logged your mood today yet',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Tracking mood regularly builds a deeper understanding of emotional cycles.',
          style: GoogleFonts.inter(fontSize: 10, color: Colors.white38),
        ),
      ],
    );
  }

  // EMOTIONAL MAP CHART PREVIEW CONTENT
  Widget _buildEmotionalMapContent(BuildContext context) {
    final dailyMood = context.watch<DailyMoodProvider>();
    final recent = dailyMood.recentMoods;

    if (recent.length < 2) {
      return Container(
        height: 60,
        alignment: Alignment.center,
        child: Text(
          'Log mood for a few days to visualize your trend 📈',
          style: GoogleFonts.inter(fontSize: 11, color: Colors.white38, fontStyle: FontStyle.italic),
        ),
      );
    }

    final spots = List.generate(
      recent.length,
      (index) => FlSpot(
        index.toDouble(),
        recent[index].moodScore.toDouble(),
      ),
    );

    return SizedBox(
      height: 70,
      width: double.infinity,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (recent.length - 1).toDouble(),
          minY: 0,
          maxY: 11,
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Colors.greenAccent,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                checkToShowDot: (spot, barData) => spot.x == barData.spots.last.x,
                getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                  radius: 4,
                  color: Colors.greenAccent,
                  strokeWidth: 1.5,
                  strokeColor: Colors.white,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    Colors.greenAccent.withValues(alpha: 0.15),
                    Colors.greenAccent.withValues(alpha: 0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // SYNC QUESTION PREVIEW CONTENT
  Widget _buildSyncQuestionContent(BuildContext context) {
    final dailyMood = context.watch<DailyMoodProvider>();
    final question = dailyMood.todayQuestion;

    if (question == null) {
      return Text(
        'Waiting for today\'s relationship prompt...',
        style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
      );
    }

    final answered = question.myAnswer != null;
    final partnerAnswered = question.partnerAnswer != null;

    String statusText = 'Waiting for your answer';
    if (answered && partnerAnswered) {
      statusText = 'Both answered! Tap to read! 💬';
    } else if (answered) {
      statusText = 'You answered. Waiting for partner ⏳';
    } else if (partnerAnswered) {
      statusText = 'Partner answered! Answer to unlock! 👀';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '"${question.question}"',
          style: GoogleFonts.playfairDisplay(
            fontSize: 13,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(
              answered && partnerAnswered 
                  ? Icons.check_circle_rounded 
                  : Icons.pending_rounded,
              color: answered && partnerAnswered ? Colors.greenAccent : Colors.purpleAccent,
              size: 14,
            ),
            const SizedBox(width: 6),
            Text(
              statusText,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // BUCKET LIST PREVIEW CONTENT
  Widget _buildBucketListContent(BuildContext context) {
    final bucket = context.watch<BucketListProvider>();
    final items = bucket.items;

    if (items.isEmpty) {
      return Text(
        'Create a shared bucket list for future travels, goals, and dreams! 📋',
        style: GoogleFonts.inter(fontSize: 12, color: Colors.white70, height: 1.4),
      );
    }

    // Get the first uncompleted item
    final uncompleted = items.where((i) => !i.isCompleted).toList();
    final nextItem = uncompleted.isNotEmpty ? uncompleted.first : items.last;
    final progress = bucket.progress;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Next: ${nextItem.title}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${(progress * 100).toStringAsFixed(0)}%',
              style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orangeAccent),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 4,
            backgroundColor: Colors.white10,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.orangeAccent),
          ),
        ),
      ],
    );
  }

  // TIME CAPSULES PREVIEW CONTENT
  Widget _buildTimeCapsuleContent(BuildContext context) {
    final capsule = context.watch<TimeCapsuleProvider>();
    final capsules = capsule.capsules;

    if (capsules.isEmpty) {
      return Text(
        'Bury secret letters or photos that will only unlock on a specific date in the future! ⌛',
        style: GoogleFonts.inter(fontSize: 12, color: Colors.white70, height: 1.4),
      );
    }

    final locked = capsule.lockedCapsules.length;
    final openable = capsule.openableCapsules.length;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Icon(Icons.lock_clock_rounded, color: Colors.tealAccent, size: 14),
            const SizedBox(width: 6),
            Text(
              '$locked locked capsules',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        if (openable > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.greenAccent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$openable ready to open!',
              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.greenAccent),
            ),
          ),
      ],
    );
  }

  // SECRET VAULT PREVIEW CONTENT
  Widget _buildVaultContent(BuildContext context) {
    final vault = context.watch<VaultProvider>();
    final isUnlocked = vault.isUnlocked;
    final count = vault.allItems.length;

    return Row(
      children: [
        Icon(
          isUnlocked ? Icons.lock_open_rounded : Icons.lock_rounded,
          color: isUnlocked ? Colors.greenAccent : Colors.redAccent,
          size: 18,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isUnlocked ? 'Unlocked' : 'Locked',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              Text(
                isUnlocked 
                    ? '$count items visible' 
                    : '🔒 Enter PIN to access secret letters & photos',
                style: GoogleFonts.inter(fontSize: 10, color: Colors.white54),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // LOVE CHAT PREVIEW CONTENT
  Widget _buildLoveChatContent(BuildContext context) {
    final chat = context.watch<LoveChatProvider>();
    final messages = chat.messages;

    if (messages.isEmpty) {
      return Text(
        'Type your private messages and send real-time love taps! 💓',
        style: GoogleFonts.inter(fontSize: 12, color: Colors.white70, height: 1.4),
      );
    }

    final latest = messages.first;
    final isMe = latest.senderId == 'you';

    return Row(
      children: [
        const Icon(Icons.maps_ugc_rounded, color: Colors.cyanAccent, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isMe ? 'You' : latest.senderName,
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white54),
              ),
              Text(
                latest.content,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
