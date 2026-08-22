import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/models/timeline_model.dart';
import 'package:days_together/providers/timeline_provider.dart';
import 'package:days_together/features/relationship/profile_controller.dart';
import 'package:days_together/providers/theme_provider.dart';
import 'package:days_together/widgets/glass_container.dart';
import 'package:days_together/widgets/cached_avatar.dart';

/// A premium, warm inline section replacing the Sidebar Chat.
/// Displays thoughts, letters, and reflections about a specific memory.
class MemoryNotesSection extends ConsumerStatefulWidget {
  final TimelineItemData item;
  final ScrollController scrollController;

  const MemoryNotesSection({
    super.key,
    required this.item,
    required this.scrollController,
  });

  @override
  ConsumerState<MemoryNotesSection> createState() => _MemoryNotesSectionState();
}

class _MemoryNotesSectionState extends ConsumerState<MemoryNotesSection> {
  final TextEditingController _noteController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  String _getRelativeTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 10) {
      return 'Just now';
    } else if (difference.inSeconds < 60) {
      return '${difference.inSeconds} seconds ago';
    } else if (difference.inMinutes < 60) {
      final mins = difference.inMinutes;
      return '$mins ${mins == 1 ? "minute" : "minutes"} ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? "hour" : "hours"} ago';
    } else if (difference.inDays == 1 || (difference.inDays < 2 && now.day != dateTime.day)) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('MMM d, yyyy').format(dateTime);
    }
  }

  void _submitNote(TimelineProvider provider, String authorName) async {
    final text = _noteController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);

    // Simulate slight delay for warm, premium optimistic UI feel
    await Future.delayed(const Duration(milliseconds: 250));

    provider.addCommentToItem(widget.item.id, text, authorName);
    _noteController.clear();

    if (mounted) {
      setState(() => _isSending = false);
    }

    // Scroll slightly to ensure the new note is visible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.scrollController.hasClients) {
        final currentPosition = widget.scrollController.position.pixels;
        widget.scrollController.animateTo(
          currentPosition + 80,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final theme = themeProvider.currentLoveTheme;
    final profile = ref.watch(profileControllerProvider);
    final tp = context.watch<TimelineProvider>();

    final currentItem = tp.timelineItems.firstWhere(
      (i) => i.id == widget.item.id,
      orElse: () => widget.item,
    );

    // Sort notes: pinned first, then by date descending (newest first)
    final sortedNotes = List<CommentData>.from(currentItem.comments)
      ..sort((a, b) {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        return b.date.compareTo(a.date);
      });

    final yourName = profile.yourName ?? 'Me';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        // Section Divider
        Divider(
          color: Colors.white.withValues(alpha: 0.12),
          thickness: 1.5,
        ),
        const SizedBox(height: 12),

        // Section Title
        Row(
          children: [
            Text(
              'Notes',
              style: AppTypography.sectionHeader(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.textColor,
              ),
            ),
            if (sortedNotes.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${sortedNotes.length}',
                  style: AppTypography.caption(
                    color: theme.accentColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ],
        ),

        // Notes List
        if (sortedNotes.isEmpty)
          _buildEmptyState(theme)
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sortedNotes.length,
            itemBuilder: (context, index) {
              final note = sortedNotes[index];
              final isMe = note.authorName == yourName;
              
              // Resolve name and avatar path
              final authorDisplayName = isMe ? yourName : note.authorName;
              final avatarPath = isMe ? profile.yourAvatarPath : profile.partnerAvatarPath;

              return TweenAnimationBuilder<double>(
                key: ValueKey(note.id),
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(0, 20 * (1 - value)),
                    child: Opacity(opacity: value, child: child),
                  );
                },
                child: _buildJournalCard(
                  context,
                  note,
                  isMe,
                  authorDisplayName,
                  avatarPath,
                  theme,
                  tp,
                ),
              );
            },
          ),

        const SizedBox(height: 24),
        // Composer Input Area
        _buildComposer(tp, yourName, theme),
      ],
    );
  }

  Widget _buildJournalCard(
    BuildContext context,
    CommentData note,
    bool isMe,
    String authorName,
    String? avatarPath,
    dynamic theme,
    TimelineProvider provider,
  ) {
    final isDark = theme.isDark;

    // Adaptive Colors based on light/dark mode
    final cardBgColor = note.isPinned
        ? (isDark
            ? theme.accentColor.withValues(alpha: 0.12)
            : theme.accentColor.withValues(alpha: 0.08))
        : (isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.white); // Solid white for better contrast in light mode

    final cardBorderColor = note.isPinned
        ? (isDark
            ? theme.accentColor.withValues(alpha: 0.45)
            : theme.accentColor.withValues(alpha: 0.35))
        : (isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.12)); // Darker border

    final paperLineColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.07); // Darker lines

    final paperMarginColor = isDark
        ? const Color(0xFFF43F5E).withValues(alpha: 0.15)
        : const Color(0xFFF43F5E).withValues(alpha: 0.3); // More visible margin

    final washiTapeColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.06);

    final washiTapeBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.12);

    final shadowColor = isDark
        ? Colors.black.withValues(alpha: 0.04)
        : Colors.black.withValues(alpha: 0.1); // Stronger shadow

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Semantics(
        label: 'Memory Note by $authorName',
        hint: 'Long press for options like pin or delete',
        child: GestureDetector(
          onLongPress: () => _showNoteActions(context, note, provider, theme),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Ruled lined paper keepsake container
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: cardBorderColor,
                    width: note.isPinned ? 1.5 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: shadowColor,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: CustomPaint(
                    painter: RuledPaperPainter(
                      lineColor: paperLineColor,
                      marginColor: paperMarginColor,
                      lineSpacing: 24.0,
                      verticalMarginX: 56.0,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Journal Header: Avatar + Author + Relative Timestamp
                          Row(
                            children: [
                              CachedAvatar(
                                path: avatarPath,
                                radius: 16,
                                borderWidth: 1,
                                borderColor: note.isPinned
                                    ? theme.accentColor
                                    : (isDark ? Colors.white24 : Colors.black26),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      authorName,
                                      style: AppTypography.bodyLarge(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: note.isPinned ? theme.accentColor : theme.textColor,
                                      ),
                                    ),
                                    if (note.isPinned) ...[
                                      const SizedBox(width: 6),
                                      Icon(
                                        Icons.push_pin_rounded,
                                        color: theme.accentColor,
                                        size: 11,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Text(
                                _getRelativeTimestamp(note.date),
                                style: AppTypography.caption(
                                  fontSize: 11,
                                  color: theme.textColor.withValues(alpha: 0.4),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          // Note Reflection Content - indented to line up past the margin line
                          Padding(
                            padding: const EdgeInsets.only(left: 44, right: 6),
                            child: Text(
                              note.content,
                              style: AppTypography.cormorant(
                                fontSize: 16,
                                color: theme.textColor.withValues(alpha: 0.85),
                                height: 1.55,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Scrapbook Decorative Attachment overlays
              if (note.isPinned)
                // Gold Paperclip for Pinned Notes
                Positioned(
                  top: -10,
                  left: 20,
                  child: Transform.rotate(
                    angle: -0.6,
                    child: const Icon(
                      Icons.attachment_rounded,
                      color: Color(0xFFE5A93B), // Warm keepsakes gold
                      size: 26,
                      shadows: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 2,
                          offset: Offset(1, 1),
                        )
                      ],
                    ),
                  ),
                )
              else
                // Translucent Washi Tape for regular notes
                Positioned(
                  top: -8,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Transform.rotate(
                      angle: -0.03,
                      child: Container(
                        width: 70,
                        height: 18,
                        decoration: BoxDecoration(
                          color: washiTapeColor,
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(
                            color: washiTapeBorderColor,
                            width: 0.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 1,
                              offset: const Offset(0, 1),
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComposer(TimelineProvider provider, String yourName, dynamic theme) {
    final isDark = theme.isDark;
    final composerBgColor = isDark
        ? Colors.white.withValues(alpha: 0.03)
        : Colors.black.withValues(alpha: 0.035);
    final composerBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);

    return Container(
      decoration: BoxDecoration(
        color: composerBgColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: composerBorderColor),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _noteController,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              style: AppTypography.body(
                color: theme.textColor,
                fontSize: 14.5,
              ),
              decoration: InputDecoration(
                hintText: 'Share what this memory means to you...',
                hintStyle: AppTypography.body(
                  color: theme.textColor.withValues(alpha: 0.3),
                  fontSize: 14,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _isSending
              ? Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.accentColor,
                    ),
                  ),
                )
              : GestureDetector(
                  onTap: () => _submitNote(provider, yourName),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 2, right: 2),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.accentColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  void _showNoteActions(
    BuildContext context,
    CommentData note,
    TimelineProvider provider,
    dynamic theme,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      builder: (ctx) => GlassContainer(
        borderRadius: 24,
        opacity: 0.15,
        blur: 20,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  note.isPinned ? Icons.pin_end_rounded : Icons.push_pin_rounded,
                  color: theme.accentColor,
                ),
                title: Text(
                  note.isPinned ? 'Unpin Reflection' : 'Pin Note to Top',
                  style: AppTypography.body(color: theme.textColor),
                ),
                onTap: () {
                  provider.togglePinComment(widget.item.id, note.id);
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                title: Text(
                  'Delete Note',
                  style: AppTypography.body(color: Colors.redAccent),
                ),
                onTap: () {
                  provider.deleteCommentFromItem(widget.item.id, note.id);
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(dynamic theme) {
    final isDark = theme.isDark;
    final emptyBgColor = isDark
        ? Colors.white.withValues(alpha: 0.02)
        : Colors.black.withValues(alpha: 0.02);
    final emptyBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.05);

    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
        decoration: BoxDecoration(
          color: emptyBgColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: emptyBorderColor),
        ),
        child: Column(
          children: [
            Icon(
              Icons.draw_rounded,
              color: theme.textColor.withValues(alpha: 0.2),
              size: 44,
            ),
            const SizedBox(height: 16),
            Text(
              'No notes have been written about this memory yet.',
              style: AppTypography.bodyLarge(
                color: theme.textColor.withValues(alpha: 0.8),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Leave the first heartfelt note and make this memory even more meaningful.',
              style: AppTypography.body(
                color: theme.textColor.withValues(alpha: 0.45),
                fontSize: 12.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// A CustomPainter that paints light ruled lines and a left red margin to simulate notebook loose leaf paper.
class RuledPaperPainter extends CustomPainter {
  final Color lineColor;
  final Color marginColor;
  final double lineSpacing;
  final double verticalMarginX;

  const RuledPaperPainter({
    required this.lineColor,
    required this.marginColor,
    required this.lineSpacing,
    required this.verticalMarginX,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 0.8;

    // Draw horizontal ruled lines starting from top
    for (double y = 48.0; y < size.height - 10; y += lineSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // Draw loose-leaf style red margin line on the left side
    final marginPaint = Paint()
      ..color = marginColor
      ..strokeWidth = 0.8;
    canvas.drawLine(
      Offset(verticalMarginX, 0),
      Offset(verticalMarginX, size.height),
      marginPaint,
    );
  }

  @override
  bool shouldRepaint(covariant RuledPaperPainter oldDelegate) {
    return oldDelegate.lineColor != lineColor ||
        oldDelegate.marginColor != marginColor ||
        oldDelegate.lineSpacing != lineSpacing ||
        oldDelegate.verticalMarginX != verticalMarginX;
  }
}
