import 'package:days_together/themes/theme_manager.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/shared/glass_container.dart';
import 'package:days_together/providers/couple_session.dart';
import 'package:days_together/features/relationship/profile_controller.dart';
import 'package:days_together/features/relationship/presence_controller.dart';
import 'package:days_together/providers/currently_provider.dart';
import 'package:days_together/providers/theme_provider.dart';
import 'package:days_together/services/storage_url_service.dart';
import 'package:days_together/shared/storage_image.dart';

class CurrentlyCard extends ConsumerStatefulWidget {
  const CurrentlyCard({super.key});

  @override
  ConsumerState<CurrentlyCard> createState() => _CurrentlyCardState();
}

class _CurrentlyCardState extends ConsumerState<CurrentlyCard> with TickerProviderStateMixin {
  late AnimationController _heartController;
  late AnimationController _celebrationController;
  late AnimationController _pulseController;
  
  final List<String> _presetActivities = [
    '☕ Making coffee...',
    '💻 Working hard...',
    '🎮 Gaming session...',
    '😴 Sleeping soundly...',
    '📖 Reading a book...',
    '🚗 Traveling...',
    '🏋️ Working out...',
    '🎵 Listening to music...',
    '🍿 Watching movies...',
  ];

  final List<String> _successMessages = [
    'You both thought of each other ❤️',
    'Love Tap completed.',
    'Connection made.',
    'Your hearts met today.',
    'Linked in love 💖',
    'Shared heartbeat captured!',
  ];

  late String _successMessage;

  @override
  void initState() {
    super.initState();
    _successMessage = _successMessages[Random().nextInt(_successMessages.length)];

    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _heartController.dispose();
    _celebrationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _triggerTap(CurrentlyProvider provider) {
    if (provider.state == LoveTapState.sent || provider.state == LoveTapState.mutual) return;

    HapticFeedback.mediumImpact();
    _heartController.forward(from: 0.0);

    provider.sendLoveTap().then((_) {
      if (provider.state == LoveTapState.mutual) {
        _celebrationController.forward(from: 0.0);
      }
    });
  }

  void _showEditActivitySheet(BuildContext context) {
    final theme = context.read<ThemeProvider>().currentLoveTheme;
    final controller = TextEditingController(text: ref.read(presenceControllerProvider).yourActivity);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: GlassContainer(
            borderRadius: 32,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Share what you're doing...",
                  style: AppTypography.title(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.textColor,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  maxLength: 40,
                  style: AppTypography.body(color: theme.textColor),
                  decoration: InputDecoration(
                    hintText: 'e.g. ☕ Making coffee...',
                    hintStyle: AppTypography.body(
                      color: theme.textColor.withValues(alpha: 0.4),
                    ),
                    counterStyle: AppTypography.caption(
                      color: theme.textColor.withValues(alpha: 0.4),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: theme.textColor.withValues(alpha: 0.1),
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: theme.accentColor),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _presetActivities.length,
                    itemBuilder: (context, idx) {
                      final act = _presetActivities[idx];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ActionChip(
                          label: Text(
                            act,
                            style: AppTypography.body(
                              fontSize: 12,
                              color: theme.textColor,
                            ),
                          ),
                          backgroundColor: theme.textColor.withValues(alpha: 0.05),
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          onPressed: () {
                            controller.text = act;
                          },
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        'Cancel',
                        style: AppTypography.body(color: theme.textColor.withValues(alpha: 0.6)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () {
                        ref.read(presenceControllerProvider.notifier).updateCurrentActivity(controller.text.trim());
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.accentColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: Text(
                        'Update',
                        style: AppTypography.body(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>().currentLoveTheme;
    final session = context.watch<CoupleSession>();
    final profile = ref.watch(profileControllerProvider);
    final presence = ref.watch(presenceControllerProvider);
    final currently = context.watch<CurrentlyProvider>();

    final partnerJoined = session.partnerId != null;
    final isOnline = presence.isPartnerOnline;
    final partnerActivity = presence.partnerActivity;

    // Trigger celebration when mutual becomes active
    if (currently.state == LoveTapState.mutual && !_celebrationController.isAnimating && _celebrationController.value == 0) {
      _celebrationController.forward();
    }

    return AnimatedBuilder(
      animation: Listenable.merge([_celebrationController, _pulseController]),
      builder: (context, child) {
        final celebrationVal = _celebrationController.value;

        // Custom borders and shadows for completion/glow states
        final borderSide = BorderSide(
          color: theme.textColor.withValues(alpha: 0.08),
          width: 1.5,
        );

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
          ),
          child: GlassContainer(
            padding: const EdgeInsets.all(18),
            borderRadius: 24,
            border: Border.fromBorderSide(borderSide),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Partner Avatar Stack
                    Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isOnline ? Colors.greenAccent : theme.textColor.withValues(alpha: 0.1),
                              width: 2,
                            ),
                          ),
                          child: StorageImageBuilder(
                            bucket: StorageBuckets.avatars,
                            storageRef: partnerJoined ? profile.partnerAvatarPath : null,
                            builder: (context, image) => CircleAvatar(
                              radius: 24,
                              backgroundColor: theme.textColor.withValues(alpha: 0.1),
                              foregroundImage: image,
                              child: image == null
                                  ? Icon(Icons.person, color: theme.textColor.withValues(alpha: 0.3))
                                  : null,
                            ),
                          ),
                        ),
                        Positioned(
                          right: 1,
                          bottom: 1,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: isOnline ? Colors.greenAccent : Colors.grey,
                              shape: BoxShape.circle,
                              border: Border.all(color: theme.backgroundColor, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    // Partner Name & Online Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.partnerName ?? 'Waiting for partner...',
                            style: AppTypography.body(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: theme.textColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isOnline ? 'Online • Just now' : 'Offline',
                            style: AppTypography.caption(
                              fontSize: 10,
                              color: theme.textColor.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Love Tap Button
                    _buildLoveTapButton(currently, theme),
                  ],
                ),
                const SizedBox(height: 14),
                // Current Status Activity Text
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: theme.textColor.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    (partnerActivity == null || partnerActivity.trim().isEmpty)
                        ? 'No activity shared yet'
                        : partnerActivity,
                    style: AppTypography.body(
                      fontSize: 13,
                      color: theme.textColor.withValues(alpha: 0.8),
                    ).copyWith(fontStyle: FontStyle.italic),
                  ),
                ),
                const Divider(color: Colors.white10, height: 20),
                // Bottom Controls: Self Activity Editor & Streaks
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Self status edit trigger
                    GestureDetector(
                      onTap: () => _showEditActivitySheet(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: theme.textColor.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.edit_note_rounded,
                              size: 14,
                              color: theme.accentColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              (presence.yourActivity == null || presence.yourActivity!.trim().isEmpty)
                                  ? "Share what you're doing..."
                                  : presence.yourActivity!,
                              style: AppTypography.caption(
                                fontSize: 11,
                                color: theme.textColor.withValues(alpha: 0.7),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Streak count
                    if (currently.history.currentStreak > 0)
                      Row(
                        children: [
                          Text(
                            '🔥',
                            style: AppTypography.caption(fontSize: 13),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${currently.history.currentStreak} Day Streak',
                            style: AppTypography.caption(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: theme.textColor.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        'Tap to connect today ❤️',
                        style: AppTypography.caption(
                          fontSize: 10,
                          color: theme.textColor.withValues(alpha: 0.4),
                        ),
                      ),
                  ],
                ),
                // Successful Completion Message
                if (currently.state == LoveTapState.mutual) ...[
                  const SizedBox(height: 12),
                  AnimatedOpacity(
                    opacity: celebrationVal > 0.1 ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 550),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: theme.accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _successMessage,
                          style: AppTypography.caption(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: theme.accentColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoveTapButton(CurrentlyProvider currently, LoveStoryTheme theme) {
    String label = 'Love Tap';
    IconData icon = Icons.favorite_border_rounded;
    Color buttonColor = theme.textColor.withValues(alpha: 0.06);
    Color iconColor = theme.textColor.withValues(alpha: 0.5);
    bool active = true;

    switch (currently.state) {
      case LoveTapState.idle:
        label = 'Love Tap';
        icon = Icons.favorite_border_rounded;
        break;
      case LoveTapState.sent:
        label = 'Tapped';
        icon = Icons.favorite_rounded;
        iconColor = Colors.pinkAccent;
        buttonColor = theme.accentColor.withValues(alpha: 0.15);
        active = false;
        break;
      case LoveTapState.received:
        label = 'Tap Back';
        icon = Icons.favorite_border_rounded;
        iconColor = Colors.pinkAccent;
        buttonColor = theme.accentColor.withValues(alpha: 0.1);
        break;
      case LoveTapState.mutual:
        label = 'Connected';
        icon = Icons.favorite_rounded;
        iconColor = Colors.pinkAccent;
        buttonColor = theme.accentColor.withValues(alpha: 0.18);
        active = false;
        break;
    }

    final celebrationVal = _celebrationController.value;
    final pulseVal = _pulseController.value;

    Border? buttonBorder;
    List<BoxShadow>? buttonShadows;

    if (currently.state == LoveTapState.mutual) {
      final pulseColor = theme.accentColor.withValues(alpha: 0.3 + 0.3 * sin(pulseVal * pi));
      buttonBorder = Border.all(
        color: pulseColor,
        width: 1.5,
      );
      buttonShadows = [
        BoxShadow(
          color: theme.accentColor.withValues(alpha: 0.1 + 0.1 * pulseVal),
          blurRadius: 8 + 6 * pulseVal,
          spreadRadius: 1,
        ),
      ];
    } else {
      buttonBorder = Border.all(
        color: theme.textColor.withValues(alpha: 0.04),
      );
    }

    Widget buttonContent = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: buttonColor,
        borderRadius: BorderRadius.circular(16),
        border: buttonBorder,
        boxShadow: buttonShadows,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: iconColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.body(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: theme.textColor.withValues(alpha: active ? 0.9 : 0.6),
            ),
          ),
        ],
      ),
    );

    Widget animatedButton = ScaleTransition(
      scale: Tween<double>(begin: 1.0, end: 1.2).animate(
        CurvedAnimation(
          parent: _heartController,
          curve: Curves.elasticOut,
        ),
      ),
      child: GestureDetector(
        onTap: active ? () => _triggerTap(currently) : null,
        child: buttonContent,
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        animatedButton,
        if (celebrationVal > 0 && celebrationVal < 1.0)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: FloatingHeartsPainter(progress: celebrationVal, accentColor: theme.accentColor),
              ),
            ),
          ),
        if (celebrationVal > 0 && celebrationVal < 1.0)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: SparkleParticlesPainter(progress: celebrationVal, accentColor: theme.accentColor),
              ),
            ),
          ),
      ],
    );
  }
}

// ──────────────────────────────────────────────
// CUSTOM PAINTERS FOR MUTUAL CELEBRATION
// ──────────────────────────────────────────────

class FloatingHeartsPainter extends CustomPainter {
  final double progress;
  final Color accentColor;

  FloatingHeartsPainter({required this.progress, required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = accentColor.withValues(alpha: (1.0 - progress).clamp(0.0, 1.0))
      ..style = PaintingStyle.fill;

    // Render 6 floating hearts rising up at different horizontal offsets
    final double centerX = size.width * 0.5;
    for (int i = 0; i < 6; i++) {
      final double wave = sin(progress * pi * 2 + i) * 30;
      final double startY = size.height - 20;
      final double endY = -40.0;
      final double currentY = startY + (endY - startY) * progress - (i * 15 * (1.0 - progress));
      final double currentX = centerX + wave + (i % 2 == 0 ? 50 : -50) * progress;

      final double scale = (0.5 + 0.5 * sin(progress * pi)) * (1.2 - i * 0.1);
      if (currentY > endY && scale > 0) {
        canvas.save();
        canvas.translate(currentX, currentY);
        canvas.scale(scale);
        _drawHeartShape(canvas, paint);
        canvas.restore();
      }
    }
  }

  void _drawHeartShape(Canvas canvas, Paint paint) {
    final path = Path();
    path.moveTo(0, 0);
    path.cubicTo(-6, -6, -12, -2, -12, 4);
    path.cubicTo(-12, 10, -6, 14, 0, 20);
    path.cubicTo(6, 14, 12, 10, 12, 4);
    path.cubicTo(12, -2, 6, -6, 0, 0);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class SparkleParticlesPainter extends CustomPainter {
  final double progress;
  final Color accentColor;

  SparkleParticlesPainter({required this.progress, required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.amberAccent.withValues(alpha: (1.0 - progress).clamp(0.0, 1.0))
      ..style = PaintingStyle.fill;

    final random = Random(42); // Seed to keep positions stable during frame repaints
    for (int i = 0; i < 15; i++) {
      final double angle = random.nextDouble() * pi * 2;
      final double distance = (30 + random.nextDouble() * 120) * progress;
      final double currentX = size.width * 0.5 + cos(angle) * distance;
      final double currentY = size.height * 0.5 + sin(angle) * distance;

      final double sparkleScale = (0.4 + 0.6 * sin(progress * pi));
      canvas.save();
      canvas.translate(currentX, currentY);
      canvas.scale(sparkleScale);
      _drawSparkle(canvas, paint);
      canvas.restore();
    }
  }

  void _drawSparkle(Canvas canvas, Paint paint) {
    final path = Path();
    path.moveTo(0, -8);
    path.quadraticBezierTo(0, 0, 8, 0);
    path.quadraticBezierTo(0, 0, 0, 8);
    path.quadraticBezierTo(0, 0, -8, 0);
    path.quadraticBezierTo(0, 0, 0, -8);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
