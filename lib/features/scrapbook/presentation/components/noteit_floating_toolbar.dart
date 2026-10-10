import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';

/// Floating bottom dock: tool selection (select, pen, pencil, marker,
/// eraser, shapes), content insertion (text, photo), and the primary Send
/// action. Tools scroll horizontally on narrow screens; Send stays pinned
/// so it is always reachable and never overlaps the property sheets.
class NoteitFloatingToolbar extends StatelessWidget {
  final LoveStoryTheme theme;
  final String activeMode;
  final bool isPropertiesPanelExpanded;
  final bool isSaving;
  final ValueChanged<String> onModeChanged;
  final VoidCallback onToggleProperties;
  final VoidCallback onAddText;
  final void Function(ImageSource source) onImportImage;
  final VoidCallback onSend;

  const NoteitFloatingToolbar({
    super.key,
    required this.theme,
    required this.activeMode,
    required this.isPropertiesPanelExpanded,
    required this.isSaving,
    required this.onModeChanged,
    required this.onToggleProperties,
    required this.onAddText,
    required this.onImportImage,
    required this.onSend,
  });

  static const _tools = [
    (mode: 'select', icon: Icons.pan_tool_alt_rounded, label: 'Select'),
    (mode: 'pen', icon: Icons.gesture_rounded, label: 'Pen'),
    (mode: 'pencil', icon: Icons.edit_rounded, label: 'Pencil'),
    (mode: 'marker', icon: Icons.border_color_rounded, label: 'Marker'),
    (mode: 'eraser', icon: Icons.cleaning_services_rounded, label: 'Eraser'),
    (mode: 'shapes', icon: Icons.interests_rounded, label: 'Shapes'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
      decoration: BoxDecoration(
        color: theme.backgroundColor.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(theme.radii.pill),
        border: Border.all(color: theme.textColor.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final tool in _tools)
                    _ToolButton(
                      icon: tool.icon,
                      label: tool.label,
                      isSelected: activeMode == tool.mode,
                      isPanelOpen: isPropertiesPanelExpanded,
                      theme: theme,
                      onTap: () => activeMode == tool.mode
                          ? onToggleProperties()
                          : onModeChanged(tool.mode),
                    ),
                  Container(
                    width: 1,
                    height: 24,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    color: theme.textColor.withValues(alpha: 0.15),
                  ),
                  _ToolButton(
                    icon: Icons.text_fields_rounded,
                    label: 'Add text',
                    isSelected: activeMode == 'text',
                    isPanelOpen: isPropertiesPanelExpanded,
                    theme: theme,
                    onTap: onAddText,
                  ),
                  _PhotoMenu(theme: theme, onImportImage: onImportImage),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          _SendButton(theme: theme, isSaving: isSaving, onSend: onSend),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.isPanelOpen,
    required this.theme,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isPanelOpen;
  final LoveStoryTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isSelected
          ? '$label (tap to ${isPanelOpen ? 'hide' : 'show'} options)'
          : label,
      child: Semantics(
        button: true,
        selected: isSelected,
        label: label,
        excludeSemantics: true,
        onTap: onTap,
        child: InkResponse(
          onTap: onTap,
          radius: 24,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedContainer(
                  duration: theme.motion.fast,
                  curve: theme.motion.standard,
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSelected ? theme.accentColor : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: isSelected
                        ? theme.onAccentColor
                        : theme.textColor.withValues(alpha: 0.8),
                  ),
                ),
                // Shows that tapping the active tool again folds its sheet.
                if (isSelected)
                  Positioned(
                    bottom: -1,
                    child: Icon(
                      isPanelOpen
                          ? Icons.keyboard_arrow_down_rounded
                          : Icons.keyboard_arrow_up_rounded,
                      size: 12,
                      color: theme.onAccentColor,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoMenu extends StatelessWidget {
  const _PhotoMenu({required this.theme, required this.onImportImage});

  final LoveStoryTheme theme;
  final void Function(ImageSource source) onImportImage;

  @override
  Widget build(BuildContext context) {
    final itemStyle = AppTypography.body(color: theme.textColor);
    return PopupMenuButton<ImageSource>(
      tooltip: 'Add photo',
      color: theme.backgroundColor,
      position: PopupMenuPosition.over,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(theme.radii.md),
      ),
      onSelected: onImportImage,
      itemBuilder: (_) => [
        PopupMenuItem(
          value: ImageSource.gallery,
          child: Row(
            children: [
              Icon(Icons.photo_library_rounded, color: theme.textColor),
              const SizedBox(width: 12),
              Text('From gallery', style: itemStyle),
            ],
          ),
        ),
        PopupMenuItem(
          value: ImageSource.camera,
          child: Row(
            children: [
              Icon(Icons.photo_camera_rounded, color: theme.textColor),
              const SizedBox(width: 12),
              Text('Take a photo', style: itemStyle),
            ],
          ),
        ),
      ],
      child: SizedBox(
        width: 44,
        height: 44,
        child: Icon(
          Icons.add_photo_alternate_rounded,
          size: 20,
          color: theme.textColor.withValues(alpha: 0.8),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.theme,
    required this.isSaving,
    required this.onSend,
  });

  final LoveStoryTheme theme;
  final bool isSaving;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final onAccent = theme.onAccentColor;
    return Semantics(
      button: true,
      enabled: !isSaving,
      label: isSaving ? 'Sending canvas' : 'Send canvas to partner',
      excludeSemantics: true,
      onTap: isSaving ? null : onSend,
      child: Material(
        color: theme.accentColor,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isSaving ? null : onSend,
          child: AnimatedSize(
            duration: theme.motion.fast,
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSaving)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: onAccent,
                      ),
                    )
                  else
                    Icon(Icons.send_rounded, size: 18, color: onAccent),
                  const SizedBox(width: 8),
                  Text(
                    isSaving ? 'Sending' : 'Send',
                    style: AppTypography.button(
                      color: onAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
