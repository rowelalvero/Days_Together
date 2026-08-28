import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:days_together/themes/theme_manager.dart';

/// Floating bottom toolbar containing tool selection (select, pen, pencil,
/// marker, eraser, shapes) and content insertion (text, gallery, camera).
class NoteitFloatingToolbar extends StatelessWidget {
  final LoveStoryTheme theme;
  final String activeMode;
  final bool isPropertiesPanelExpanded;
  final ValueChanged<String> onModeChanged;
  final VoidCallback onToggleProperties;
  final VoidCallback onAddText;
  final void Function(ImageSource source) onImportImage;

  const NoteitFloatingToolbar({
    super.key,
    required this.theme,
    required this.activeMode,
    required this.isPropertiesPanelExpanded,
    required this.onModeChanged,
    required this.onToggleProperties,
    required this.onAddText,
    required this.onImportImage,
  });

  Widget _buildToolbarButton({
    required IconData icon,
    required String mode,
    required String tooltip,
  }) {
    final isSelected = activeMode == mode;

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () {
          if (activeMode == mode) {
            onToggleProperties();
          } else {
            onModeChanged(mode);
          }
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isSelected ? theme.accentColor : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: isSelected ? Colors.white : theme.textColor.withValues(alpha: 0.7),
            size: 18,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 12, top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.backgroundColor.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: theme.textColor.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Mode Selectors
              _buildToolbarButton(
                icon: Icons.near_me_rounded,
                mode: 'select',
                tooltip: 'Select Object',
              ),
              _buildToolbarButton(
                icon: Icons.edit_rounded,
                mode: 'pen',
                tooltip: 'Pen',
              ),
              _buildToolbarButton(
                icon: Icons.brush_rounded,
                mode: 'pencil',
                tooltip: 'Pencil',
              ),
              _buildToolbarButton(
                icon: Icons.border_color_rounded,
                mode: 'marker',
                tooltip: 'Marker',
              ),
              _buildToolbarButton(
                icon: Icons.cleaning_services_rounded,
                mode: 'eraser',
                tooltip: 'Eraser',
              ),
              _buildToolbarButton(
                icon: Icons.category_rounded,
                mode: 'shapes',
                tooltip: 'Shapes',
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Container(
                  width: 1,
                  height: 20,
                  color: theme.textColor.withValues(alpha: 0.15),
                ),
              ),

              // Content Actions
              IconButton(
                icon: const Icon(Icons.text_fields_rounded),
                onPressed: onAddText,
                tooltip: 'Add Text',
                color: theme.textColor,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.photo_library_rounded),
                onPressed: () => onImportImage(ImageSource.gallery),
                tooltip: 'Import Image',
                color: theme.textColor,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.photo_camera_rounded),
                onPressed: () => onImportImage(ImageSource.camera),
                tooltip: 'Take Photo',
                color: theme.textColor,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
