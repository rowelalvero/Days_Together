import 'package:flutter/material.dart';
import 'package:days_together/shared/models/noteit_model.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/shared/scale_drawing_painter.dart';

class Noteit2x2RenderCard extends StatelessWidget {
  final LoveStoryTheme theme;
  final String partnerName;
  final String? drawingContent;
  final String? timeAgo;

  const Noteit2x2RenderCard({
    super.key,
    required this.theme,
    required this.partnerName,
    this.drawingContent,
    this.timeAgo,
  });

  @override
  Widget build(BuildContext context) {
    final List<ColorfulStroke> strokes = drawingContent != null && drawingContent!.isNotEmpty
        ? NoteitItem.deserializeColorfulStrokes(drawingContent, Colors.white)
        : [];

    return Container(
      width: 320,
      height: 320,
      decoration: BoxDecoration(
        color: theme.backgroundColor,
        borderRadius: BorderRadius.circular(36),
        border: Border.all(
          color: theme.accentColor.withValues(alpha: 0.35),
          width: 2.5,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.primaryColor.withValues(alpha: 0.85),
            theme.secondaryColor.withValues(alpha: 0.95),
            theme.backgroundColor,
          ],
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.accentColor.withValues(alpha: 0.25),
                  border: Border.all(color: theme.accentColor, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    partnerName.isNotEmpty ? partnerName[0].toUpperCase() : '💖',
                    style: TextStyle(
                      color: theme.textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  partnerName,
                  style: TextStyle(
                    color: theme.textColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (timeAgo != null)
                Text(
                  timeAgo!,
                  style: TextStyle(
                    color: theme.textColor.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              clipBehavior: Clip.antiAlias,
              child: strokes.isNotEmpty
                  ? CustomPaint(
                      painter: ScaleDrawingPainter(
                        colorfulStrokes: strokes,
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                      size: Size.infinite,
                    )
                  : Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.edit_note_rounded,
                            color: theme.accentColor,
                            size: 36,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tap to draw first 💕',
                            style: TextStyle(
                              color: theme.textColor.withValues(alpha: 0.7),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
