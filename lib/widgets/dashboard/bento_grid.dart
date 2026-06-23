import 'dart:io';
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
        _buildDoodleNotesBentoCard(context),
        const SizedBox(height: 16),
        _buildSharedCalendarBentoCard(context),
        const SizedBox(height: 16),
        _buildDailyMoodBentoCard(context),
        const SizedBox(height: 16),
        _buildEmotionalMapBentoCard(context),
        const SizedBox(height: 16),
        _buildDailySyncBentoCard(context),
        const SizedBox(height: 16),
        _buildBucketListBentoCard(context),
        const SizedBox(height: 16),
        _buildTimeCapsuleBentoCard(context),
        const SizedBox(height: 16),
        _buildSecretVaultBentoCard(context),
        const SizedBox(height: 16),
        _buildLoveChatBentoCard(context),
      ],
    );
  }

  Widget _buildDoodleNotesBentoCard(BuildContext context) {
    final noteit = context.watch<NoteitProvider>();
    final notes = noteit.notes;
    final latest = notes.isNotEmpty ? notes.first : null;
    
    String footerText = 'No shared notes';
    if (latest != null) {
      final senderName = latest.sender == 'you' ? 'You' : 'Partner';
      footerText = '$senderName • ${_formatRelativeTime(latest.createdAt)}';
    }

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NoteitScreen()),
      ),
      borderRadius: BorderRadius.circular(24),
      child: GlassContainer(
        padding: const EdgeInsets.all(20),
        borderRadius: 24,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E1720), // Lighter dark pink/rose transparent capsule
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'DOODLE NOTES',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFF43F5E), // Pink
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFF43F5E).withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.draw_outlined,
                      color: Color(0xFFF43F5E),
                      size: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Doodle Notes',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFF43F5E),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
              ),
              child: _buildNoteItContent(context),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    footerText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      color: const Color(0xFFF43F5E),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  children: [
                    Text(
                      'Doodle Space',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFF43F5E),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 9,
                      color: Color(0xFFF43F5E),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSharedCalendarBentoCard(BuildContext context) {
    final calendar = context.watch<CalendarProvider>();
    final count = calendar.events.length;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CalendarScreen()),
      ),
      borderRadius: BorderRadius.circular(24),
      child: GlassContainer(
        padding: const EdgeInsets.all(20),
        borderRadius: 24,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF162235), // Lighter dark blue transparent capsule
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'CALENDAR',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF60A5FA), // Blue
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF60A5FA).withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.calendar_month_outlined,
                      color: Color(0xFF60A5FA),
                      size: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Shared Calendar',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF60A5FA),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
              ),
              child: _buildCalendarContent(context),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '$count Events Scheduled',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      color: const Color(0xFF60A5FA),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  children: [
                    Text(
                      'View Calendar',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF60A5FA),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 9,
                      color: Color(0xFF60A5FA),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyMoodBentoCard(BuildContext context) {
    final dailyMood = context.watch<DailyMoodProvider>();
    final myToday = dailyMood.todayMood;

    String statusText = myToday != null ? 'Synced Mood Logged' : 'Awaiting check-in';

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoveMeterScreen()),
      ),
      borderRadius: BorderRadius.circular(24),
      child: GlassContainer(
        padding: const EdgeInsets.all(20),
        borderRadius: 24,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2216), // Lighter dark amber transparent capsule
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'DAILY MOOD',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFF59E0B), // Amber
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.emoji_emotions_outlined,
                      color: Color(0xFFF59E0B),
                      size: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Daily Mood',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFF59E0B),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
              ),
              child: _buildMoodContent(context),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    statusText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      color: const Color(0xFFF59E0B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  children: [
                    Text(
                      'Track Mood',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFF59E0B),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 9,
                      color: Color(0xFFF59E0B),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmotionalMapBentoCard(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoveMeterScreen()),
      ),
      borderRadius: BorderRadius.circular(24),
      child: GlassContainer(
        padding: const EdgeInsets.all(20),
        borderRadius: 24,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF162E25), // Lighter dark emerald transparent capsule
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'EMOTIONAL MAP',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF10B981), // Emerald
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.trending_up_rounded,
                      color: Color(0xFF10B981),
                      size: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Emotional Map',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF10B981),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'You',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFC084FC),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Partner',
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
              ),
              child: _buildEmotionalMapContent(context),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '30-Day Trend Analysis',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      color: const Color(0xFF10B981),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  children: [
                    Text(
                      'Analyze Trends',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 9,
                      color: Color(0xFF10B981),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecretVaultBentoCard(BuildContext context) {
    final vault = context.watch<VaultProvider>();
    final isUnlocked = vault.isUnlocked;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const VaultScreen()),
      ),
      borderRadius: BorderRadius.circular(24),
      child: GlassContainer(
        padding: const EdgeInsets.all(20),
        borderRadius: 24,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D1818), // Lighter dark red transparent capsule
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'SECRET VAULT',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFEF4444), // Red
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.lock_outline_rounded,
                      color: Color(0xFFEF4444),
                      size: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Secret Vault',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFEF4444),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
              ),
              child: _buildVaultContent(context),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    isUnlocked ? 'Access Granted' : 'PIN Protected',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      color: const Color(0xFFEF4444),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  children: [
                    Text(
                      'Open Vault',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFEF4444),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 9,
                      color: Color(0xFFEF4444),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoveChatBentoCard(BuildContext context) {
    final chat = context.watch<LoveChatProvider>();
    final messages = chat.messages;
    final latest = messages.isNotEmpty ? messages.first : null;

    String footerText = 'Type your private messages';
    if (latest != null) {
      footerText = 'Last active: ${_formatRelativeTime(latest.createdAt)}';
    }

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoveChatScreen()),
      ),
      borderRadius: BorderRadius.circular(24),
      child: GlassContainer(
        padding: const EdgeInsets.all(20),
        borderRadius: 24,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF132225), // Lighter dark cyan transparent capsule
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'LOVE CHAT',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF06B6D4), // Cyan/Teal
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF06B6D4).withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: Color(0xFF06B6D4),
                      size: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Love Chat Space',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF06B6D4),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
              ),
              child: _buildLoveChatContent(context),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    footerText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      color: const Color(0xFF06B6D4),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  children: [
                    Text(
                      'Open Chat',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF06B6D4),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 9,
                      color: Color(0xFF06B6D4),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MM/dd').format(dateTime);
    }
  }

  // NOTEIT PREVIEW CONTENT
  Widget _buildNoteItContent(BuildContext context) {
    final noteit = context.watch<NoteitProvider>();
    final notes = noteit.notes;

    if (notes.isEmpty) {
      return Text(
        'Send a doodle note, sketch, or photo directly to your partner\'s screen! 💌',
        style: GoogleFonts.inter(fontSize: 12, color: Colors.white70, height: 1.4),
      );
    }

    final latest = notes.first;
    final senderName = latest.sender == 'you' ? 'You' : 'Partner';

    String previewText = '';
    Widget previewImage = const SizedBox.shrink();

    if (latest.type == NoteitType.text) {
      previewText = latest.content ?? '';
      previewImage = Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: latest.backgroundColor ?? Colors.pinkAccent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Center(
          child: Icon(
            Icons.chat_bubble_outline_rounded,
            color: Colors.white,
            size: 16,
          ),
        ),
      );
    } else if (latest.type == NoteitType.drawing) {
      previewText = 'Doodle Drawing 🎨';
      previewImage = Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: latest.backgroundColor ?? const Color(0xFF0F0B1A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: CustomPaint(
            painter: ScaleDrawingPainter(
              strokes: NoteitItem.deserializeStrokes(latest.content),
              color: Colors.white,
              strokeWidth: 2.0,
            ),
          ),
        ),
      );
    } else if (latest.type == NoteitType.photo) {
      previewText = 'Shared Photo 📸';
      previewImage = Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: latest.imagePath != null && File(latest.imagePath!).existsSync()
              ? Image.file(
                  File(latest.imagePath!),
                  fit: BoxFit.cover,
                )
              : const Icon(
                  Icons.photo_rounded,
                  color: Colors.white60,
                  size: 16,
                ),
        ),
      );
    }

    return Row(
      children: [
        previewImage,
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                previewText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.95),
                ),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Text(
                    senderName,
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: theme.accentColor,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 3,
                    height: 3,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatRelativeTime(latest.createdAt),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9,
                      color: Colors.white.withValues(alpha: 0.4),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
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
    final formattedDate = DateFormat('MMM dd, yyyy').format(event.date);
    
    // Calculate days remaining
    final eventDateOnly = DateTime(event.date.year, event.date.month, event.date.day);
    final nowDateOnly = DateTime(now.year, now.month, now.day);
    final daysUntil = eventDateOnly.difference(nowDateOnly).inDays;

    String daysText = daysUntil == 0 ? 'Today' : 'In $daysUntil Days';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                event.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // "SOON" Pill Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF43F5E), // Vibrant pink/rose accent
                borderRadius: BorderRadius.circular(100),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'SOON',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              formattedDate,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.35),
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              daysText,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11.5,
                color: const Color(0xFFF43F5E), // Vibrant pink/rose accent
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _getMoodEmoji(int? score) {
    if (score == null) return '🤔';
    if (score <= 2) return '😢';
    if (score <= 4) return '😐';
    if (score <= 6) return '🙂';
    if (score <= 8) return '😊';
    return '🥰';
  }

  // DAILY MOOD PREVIEW CONTENT
  Widget _buildMoodContent(BuildContext context) {
    final dailyMood = context.watch<DailyMoodProvider>();
    final myToday = dailyMood.todayMood;
    final partnerToday = dailyMood.partnerTodayMood;

    final myScore = myToday != null ? '${myToday.moodScore}/10' : 'Pending';
    final partnerScore = partnerToday != null ? '${partnerToday.moodScore}/10' : 'Pending';

    final myEmoji = myToday != null ? _getMoodEmoji(myToday.moodScore) : '🤔';
    final partnerEmoji = partnerToday != null ? _getMoodEmoji(partnerToday.moodScore) : '🤔';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // You mood box
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'YOU',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          myToday != null ? Icons.check_circle_rounded : Icons.pending_rounded,
                          color: myToday != null ? const Color(0xFFF59E0B) : Colors.white.withValues(alpha: 0.2),
                          size: 13,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$myEmoji $myScore',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Partner mood box
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PARTNER',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          partnerToday != null ? Icons.check_circle_rounded : Icons.pending_rounded,
                          color: partnerToday != null ? const Color(0xFFF59E0B) : Colors.white.withValues(alpha: 0.2),
                          size: 13,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$partnerEmoji $partnerScore',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // EMOTIONAL MAP CHART PREVIEW CONTENT
  Widget _buildEmotionalMapContent(BuildContext context) {
    final dailyMood = context.watch<DailyMoodProvider>();
    final recent = dailyMood.recentMoods;
    final partnerRecent = dailyMood.partnerRecentMoods;

    if (recent.length < 2 && partnerRecent.length < 2) {
      return Container(
        height: 60,
        alignment: Alignment.center,
        child: Text(
          'Log mood for a few days to visualize your trend 📈',
          style: GoogleFonts.inter(fontSize: 11, color: Colors.white38, fontStyle: FontStyle.italic),
        ),
      );
    }

    final now = DateTime.now();
    final dates = List.generate(7, (i) => DateFormat('yyyy-MM-dd').format(now.subtract(Duration(days: 6 - i))));

    final userMoodsMap = {for (var m in recent) m.date: m.moodScore};
    final partnerMoodsMap = {for (var m in partnerRecent) m.date: m.moodScore};

    final userSpots = <FlSpot>[];
    final partnerSpots = <FlSpot>[];

    for (int i = 0; i < dates.length; i++) {
      final date = dates[i];
      final uScore = userMoodsMap[date] ?? (recent.isNotEmpty ? recent.last.moodScore : 7);
      final pScore = partnerMoodsMap[date] ?? (partnerRecent.isNotEmpty ? partnerRecent.last.moodScore : 8);

      userSpots.add(FlSpot(i.toDouble(), uScore.toDouble()));
      partnerSpots.add(FlSpot(i.toDouble(), pScore.toDouble()));
    }

    return SizedBox(
      height: 70,
      width: double.infinity,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: 6,
          minY: 0,
          maxY: 11,
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            // User Line (Green)
            LineChartBarData(
              spots: userSpots,
              isCurved: true,
              color: const Color(0xFF10B981), // Emerald Green
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                checkToShowDot: (spot, barData) => spot.x == barData.spots.last.x,
                getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                  radius: 4,
                  color: const Color(0xFF10B981),
                  strokeWidth: 1.5,
                  strokeColor: Colors.white,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF10B981).withValues(alpha: 0.15),
                    const Color(0xFF10B981).withValues(alpha: 0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            // Partner Line (Purple)
            LineChartBarData(
              spots: partnerSpots,
              isCurved: true,
              color: const Color(0xFFC084FC), // Purple
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                checkToShowDot: (spot, barData) => spot.x == barData.spots.last.x,
                getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                  radius: 4,
                  color: const Color(0xFFC084FC),
                  strokeWidth: 1.5,
                  strokeColor: Colors.white,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFC084FC).withValues(alpha: 0.15),
                    const Color(0xFFC084FC).withValues(alpha: 0.0),
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

  // DAILY SYNC PREVIEW CONTENT
  Widget _buildDailySyncBentoCard(BuildContext context) {
    final dailyMood = context.watch<DailyMoodProvider>();
    final question = dailyMood.todayQuestion;

    final hasQuestion = question != null;
    final answered = question != null && question.myAnswer != null;
    final partnerAnswered = question != null && question.partnerAnswer != null;

    String statusText = 'Waiting for answers';
    if (answered && partnerAnswered) {
      statusText = 'Ready to read responses';
    } else if (answered) {
      statusText = 'Waiting for partner';
    } else if (partnerAnswered) {
      statusText = 'Partner answered! Unlock now';
    }

    final questionText = question != null ? '"${question.question}"' : 'Waiting for today\'s relationship prompt...';

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoveMeterScreen()),
      ),
      borderRadius: BorderRadius.circular(24),
      child: GlassContainer(
        padding: const EdgeInsets.all(20),
        borderRadius: 24,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Badge & Circular Question Icon
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // "DAILY SYNC" Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF251A35), // Dark purple transparent capsule
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'DAILY SYNC',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFC084FC), // Light purple
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                // Circular Question Icon
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFC084FC).withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.question_answer_outlined,
                      color: Color(0xFFC084FC),
                      size: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Title: Daily Sync Question
            Text(
              'Daily Sync Question',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFC084FC), // Purple title matching badge
              ),
            ),
            const SizedBox(height: 14),
            // Main center block: Question Box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.18), // Very dark grey/black transparent box
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    questionText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      fontStyle: hasQuestion ? FontStyle.italic : FontStyle.normal,
                      color: Colors.white,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Divider
                  Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                  const SizedBox(height: 12),
                  // Sync status header
                  Text(
                    'SYNC STATUS:',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withValues(alpha: 0.35),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Indicators row
                  Row(
                    children: [
                      // You status
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: answered ? const Color(0xFFC084FC) : Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'You',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: answered ? Colors.white : Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                      const SizedBox(width: 20),
                      // Partner status
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: partnerAnswered ? const Color(0xFFC084FC) : Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Partner',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: partnerAnswered ? Colors.white : Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Footer row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    statusText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      color: const Color(0xFFC084FC),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  children: [
                    Text(
                      'Sync Minds',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFC084FC),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 9,
                      color: Color(0xFFC084FC),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // BUCKET LIST PREVIEW CONTENT
  Widget _buildBucketListBentoCard(BuildContext context) {
    final bucketProvider = context.watch<BucketListProvider>();
    final items = bucketProvider.items;
    
    final completedItems = items.where((i) => i.isCompleted).toList();
    final uncompletedItems = items.where((i) => !i.isCompleted).toList();
    
    final total = items.isNotEmpty ? items.length : 5;
    final completedCount = items.isNotEmpty ? completedItems.length : 2;
    final progress = items.isNotEmpty ? (completedCount / total) : 0.40;
    
    final closestToConquer = uncompletedItems.isNotEmpty 
        ? uncompletedItems.first.title 
        : (items.isNotEmpty ? 'All goals achieved! 🎉' : 'Go hot air ballooning during a rose sunset');
        
    String completedText = 'Completed: Learn to cook h...';
    if (items.isNotEmpty) {
      if (completedItems.isNotEmpty) {
        final title = completedItems.first.title;
        final prefix = 'Completed: $title';
        if (prefix.length > 25) {
          completedText = '${prefix.substring(0, 22)}...';
        } else {
          completedText = prefix;
        }
      } else {
        completedText = 'No completed goals yet';
      }
    }

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BucketListScreen()),
      ),
      borderRadius: BorderRadius.circular(24),
      child: GlassContainer(
        padding: const EdgeInsets.all(20),
        borderRadius: 24,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Badge & Circular Compass Icon
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // "ADVENTURES" Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2D2F), // Lighter dark cyan/teal transparent capsule
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'ADVENTURES',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF06B6D4), // Cyan
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                // Circular Compass Icon
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF06B6D4).withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.explore_outlined,
                      color: Color(0xFF06B6D4),
                      size: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Title: Bucket List Goals
            Text(
              'Bucket List Goals',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF06B6D4), // Cyan title matching badge/progress
              ),
            ),
            const SizedBox(height: 14),
            // Main center block: Progress Box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.18), // Very dark grey/black transparent box
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Progress labels
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'CONQUER PROGRESS',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Colors.white.withValues(alpha: 0.35),
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        '${(progress * 100).toInt()}% ($completedCount/$total)',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF06B6D4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: Colors.white.withValues(alpha: 0.05),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF06B6D4)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Divider
                  Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                  const SizedBox(height: 12),
                  // Closest to conquer
                  Text(
                    'CLOSEST TO CONQUER:',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withValues(alpha: 0.35),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF06B6D4),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          closestToConquer,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Footer row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    completedText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      color: const Color(0xFF06B6D4), // Cyan completed text matching footer link
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  children: [
                    Text(
                      'Chase Objectives',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF06B6D4),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 9,
                      color: Color(0xFF06B6D4),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // TIME CAPSULES PREVIEW CONTENT
  Widget _buildTimeCapsuleBentoCard(BuildContext context) {
    final capsuleProvider = context.watch<TimeCapsuleProvider>();
    final lockedCapsules = capsuleProvider.lockedCapsules;

    final latestLockedMessage = lockedCapsules.isNotEmpty 
        ? lockedCapsules.first.message 
        : 'Post-Graduation Hopes & Fears';

    final openDate = lockedCapsules.isNotEmpty 
        ? lockedCapsules.first.openDate 
        : DateTime.now().add(const Duration(days: 294, hours: 22, minutes: 47));
    
    final duration = openDate.difference(DateTime.now());
    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;
    
    final displayDays = days > 0 ? days : 294;
    final displayHours = hours > 0 ? hours : 22;
    final displayMinutes = minutes > 0 ? minutes : 47;
    final countdownText = '${displayDays}d ${displayHours}h ${displayMinutes}m';

    final sealedCount = lockedCapsules.isNotEmpty ? lockedCapsules.length : 3;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TimeCapsuleScreen()),
      ),
      borderRadius: BorderRadius.circular(24),
      child: GlassContainer(
        padding: const EdgeInsets.all(20),
        borderRadius: 24,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Badge & Circular Hourglass Icon
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // "FUTURE LETTERS" Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E221E), // Lighter dark orange/brown transparent capsule
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'FUTURE LETTERS',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFE28743), // Warm orange
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                // Circular Hourglass icon
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFE28743).withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.hourglass_empty_rounded,
                      color: Color(0xFFE28743),
                      size: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Title: Time Capsules
            Text(
              'Time Capsules',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFFFDFB9), // warm orange-yellow tint
              ),
            ),
            const SizedBox(height: 14),
            // Main center block: Sealed Info Box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.18), // Very dark grey/black transparent box
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          latestLockedMessage,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // "SEALED" Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E221E), // Subtle dark orange/brown background
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'SEALED',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFE28743),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Divider
                  Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                  const SizedBox(height: 12),
                  // Countdown row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time_rounded,
                            color: Color(0xFFE28743),
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'REMAINING:',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.white.withValues(alpha: 0.35),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        countdownText,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFE28743),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Footer row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$sealedCount Sealed Lockboxes',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10.5,
                    color: Colors.white.withValues(alpha: 0.35),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      'Launch Capsule',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFE28743),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 9,
                      color: Color(0xFFE28743),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
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
