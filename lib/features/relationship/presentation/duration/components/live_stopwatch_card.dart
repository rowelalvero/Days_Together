import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:days_together/shared/glass_container.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/themes/theme_manager.dart';

/// Live counting stopwatch card displaying hours, minutes, seconds, and total elapsed duration.
class LiveStopwatchCard extends StatefulWidget {
  final DateTime startDate;
  final LoveStoryTheme theme;

  const LiveStopwatchCard({
    super.key,
    required this.startDate,
    required this.theme,
  });

  @override
  State<LiveStopwatchCard> createState() => _LiveStopwatchCardState();
}

class _LiveStopwatchCardState extends State<LiveStopwatchCard>
    with SingleTickerProviderStateMixin {
  late Timer _timer;
  late Duration _difference;
  late AnimationController _introController;
  late Animation<double> _hoursAnimation;

  @override
  void initState() {
    super.initState();
    _difference = DateTime.now().difference(widget.startDate);

    // Animate hours count-up on first load
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _hoursAnimation = Tween<double>(
      begin: 0,
      end: _difference.inHours.toDouble(),
    ).animate(CurvedAnimation(
      parent: _introController,
      curve: Curves.easeOutCubic,
    ));
    _introController.forward();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _difference = DateTime.now().difference(widget.startDate);
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _introController.dispose();
    super.dispose();
  }

  Widget _buildUnit(String val, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            val,
            style: AppTypography.heading(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: widget.theme.textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTypography.caption(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: widget.theme.textColor.withValues(alpha: 0.35),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hours = _difference.inHours;
    final minutes = _difference.inMinutes % 60;
    final seconds = _difference.inSeconds % 60;

    final hourStr = NumberFormat('#,###').format(hours);
    final minStr = minutes.toString().padLeft(2, '0');
    final secStr = seconds.toString().padLeft(2, '0');

    return GlassContainer(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      borderRadius: 24,
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.timer_outlined,
                color: widget.theme.textColor.withValues(alpha: 0.4),
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                'LIVE TIME STOPWATCH',
                style: AppTypography.cardCategory(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  color: widget.theme.textColor.withValues(alpha: 0.4),
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AnimatedBuilder(
            animation: _introController,
            builder: (context, _) {
              final displayHours = _introController.isCompleted
                  ? hourStr
                  : NumberFormat('#,###').format(_hoursAnimation.value.toInt());
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildUnit(displayHours, 'Hours'),
                  Text(
                    ':',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: widget.theme.textColor.withValues(alpha: 0.4),
                    ),
                  ),
                  _buildUnit(minStr, 'Minutes'),
                  Text(
                    ':',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: widget.theme.textColor.withValues(alpha: 0.4),
                    ),
                  ),
                  _buildUnit(secStr, 'Seconds'),
                ],
              );
            },
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            child: Divider(
              height: 1,
              thickness: 0.5,
              color: Colors.white10,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      NumberFormat('#,###').format(_difference.inMinutes),
                      style: AppTypography.heading(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: widget.theme.textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Total Minutes Passed',
                      style: AppTypography.caption(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: widget.theme.textColor.withValues(alpha: 0.35),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 0.5,
                height: 32,
                color: Colors.white10,
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      NumberFormat('#,###').format(_difference.inSeconds),
                      style: AppTypography.heading(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: widget.theme.textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Total Seconds Passed',
                      style: AppTypography.caption(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: widget.theme.textColor.withValues(alpha: 0.35),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
