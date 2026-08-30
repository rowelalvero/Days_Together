import 'package:flutter/material.dart';
import 'package:days_together/features/home_widgets/domain/home_widget_models.dart';

class WidgetContentEditor extends StatelessWidget {
  final HomeWidgetType widgetType;
  final HomeWidgetConfig config;
  final ValueChanged<HomeWidgetConfig> onConfigChanged;
  final VoidCallback onOpenNoteitCanvas;

  const WidgetContentEditor({
    super.key,
    required this.widgetType,
    required this.config,
    required this.onConfigChanged,
    required this.onOpenNoteitCanvas,
  });

  @override
  Widget build(BuildContext context) {
    if (widgetType == HomeWidgetType.noteit2x2) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.brush_rounded, color: Color(0xFFE8477E), size: 20),
                SizedBox(width: 8),
                Text(
                  'NoteIt Live Drawing Note',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Your home screen widget will automatically display the latest drawing note sent by your partner.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onOpenNoteitCanvas,
                icon: const Icon(Icons.edit_note_rounded, size: 18),
                label: const Text('Open NoteIt Canvas to Draw Note'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFE8477E),
                  side: const BorderSide(color: Color(0xFFE8477E)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Customize Widget Content',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          // Custom Title
          TextFormField(
            initialValue: config.customTitle,
            decoration: InputDecoration(
              labelText: 'Widget Title / Nicknames',
              labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              filled: true,
              fillColor: Colors.black.withValues(alpha: 0.25),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE8477E)),
              ),
            ),
            style: const TextStyle(color: Colors.white),
            onChanged: (val) => onConfigChanged(config.copyWith(customTitle: val)),
          ),
          const SizedBox(height: 12),
          // Custom Milestone Tag
          TextFormField(
            initialValue: config.customMilestoneTag,
            decoration: InputDecoration(
              labelText: 'Milestone / Subtitle Tag',
              labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              filled: true,
              fillColor: Colors.black.withValues(alpha: 0.25),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE8477E)),
              ),
            ),
            style: const TextStyle(color: Colors.white),
            onChanged: (val) => onConfigChanged(config.copyWith(customMilestoneTag: val)),
          ),
          const SizedBox(height: 14),
          // Counter Format options
          Row(
            children: [
              Expanded(
                child: _FormatOptionChip(
                  label: 'Total Days',
                  isSelected: config.counterFormat == DaysCounterFormat.totalDays,
                  onTap: () => onConfigChanged(config.copyWith(counterFormat: DaysCounterFormat.totalDays)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FormatOptionChip(
                  label: 'Yrs • Mos • Days',
                  isSelected: config.counterFormat == DaysCounterFormat.yearsMonthsDays,
                  onTap: () => onConfigChanged(config.copyWith(counterFormat: DaysCounterFormat.yearsMonthsDays)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Toggles
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Show Live Stopwatch Seconds', style: TextStyle(color: Colors.white, fontSize: 14)),
            value: config.showSeconds,
            activeThumbColor: Colors.white,
            activeTrackColor: const Color(0xFFE8477E),
            onChanged: (val) => onConfigChanged(config.copyWith(showSeconds: val)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Show Milestone Badge', style: TextStyle(color: Colors.white, fontSize: 14)),
            value: config.showMilestone,
            activeThumbColor: Colors.white,
            activeTrackColor: const Color(0xFFE8477E),
            onChanged: (val) => onConfigChanged(config.copyWith(showMilestone: val)),
          ),
        ],
      ),
    );
  }
}

class _FormatOptionChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FormatOptionChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFE8477E).withValues(alpha: 0.25)
              : Colors.black.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFFE8477E) : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
