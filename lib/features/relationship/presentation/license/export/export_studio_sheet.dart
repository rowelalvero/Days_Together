import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ConsumerState, ConsumerStatefulWidget;

import 'package:days_together/features/relationship/data/image_export_service.dart';
import 'package:days_together/features/relationship/presentation/license/export/post_export_template.dart';
import 'package:days_together/features/relationship/presentation/license/export/story_export_template.dart';
import 'package:days_together/features/relationship/presentation/license/export/transparent_export_template.dart';
import 'package:days_together/providers/couple_session.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/themes/theme_manager.dart';

/// The bottom sheet for exporting the relationship license as a shareable
/// image (transparent PNG, Instagram Story template, or square post
/// template). Extracted out of relationship_license_screen.dart
/// (Migration Phase 8) -- renamed from `_ExportStudioBottomSheet` since
/// it now needs to be public to be shared across the license/ file split.
class ExportStudioBottomSheet extends ConsumerStatefulWidget {
  final CoupleSession rp;
  final LoveStoryTheme theme;
  final bool showBoth;
  final bool isYourLicense;
  final bool myShowingFront;
  final bool partnerShowingFront;
  final GlobalKey mainLicenseKey;

  const ExportStudioBottomSheet({
    super.key,
    required this.rp,
    required this.theme,
    required this.showBoth,
    required this.isYourLicense,
    required this.myShowingFront,
    required this.partnerShowingFront,
    required this.mainLicenseKey,
  });

  @override
  ConsumerState<ExportStudioBottomSheet> createState() =>
      _ExportStudioBottomSheetState();
}

enum ExportTemplate { transparent, story, post }

class _ExportStudioBottomSheetState extends ConsumerState<ExportStudioBottomSheet> {
  ExportTemplate _selectedTemplate = ExportTemplate.story;
  bool _exportFront = true;
  bool _isSharing = false;
  bool _isSaving = false;

  final GlobalKey _transparentKey = GlobalKey();
  final GlobalKey _storyKey = GlobalKey();
  final GlobalKey _postKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _exportFront = widget.isYourLicense
        ? widget.myShowingFront
        : widget.partnerShowingFront;
  }


  GlobalKey _activeKeyFor(ExportTemplate template) {
    switch (template) {
      case ExportTemplate.transparent:
        return _transparentKey;
      case ExportTemplate.story:
        return _storyKey;
      case ExportTemplate.post:
        return _postKey;
    }
  }

  String _filenamePrefixFor(ExportTemplate template) {
    switch (template) {
      case ExportTemplate.transparent:
        return 'transparent_license';
      case ExportTemplate.story:
        return 'story_license';
      case ExportTemplate.post:
        return 'post_license';
    }
  }

  Future<void> _shareImage() async {
    setState(() => _isSharing = true);
    try {
      await const ImageExportService().share(
        _activeKeyFor(_selectedTemplate),
        filenamePrefix: _filenamePrefixFor(_selectedTemplate),
        shareText: 'Look at our certified Relationship License! ❤️',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  Future<void> _saveToDevice() async {
    setState(() => _isSaving = true);
    try {
      await const ImageExportService().saveToGallery(
        _activeKeyFor(_selectedTemplate),
        filenamePrefix: _filenamePrefixFor(_selectedTemplate),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo saved to gallery successfully! 📸'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildPreviewFrame() {
    Widget activeTemplateWidget;
    double aspectRatio;

    switch (_selectedTemplate) {
      case ExportTemplate.transparent:
        aspectRatio = widget.showBoth ? (800 / 1040) : (800 / 504);
        activeTemplateWidget = RepaintBoundary(
          key: _transparentKey,
          child: TransparentExportTemplate(
            rp: widget.rp,
            showBoth: widget.showBoth,
            isYourLicense: widget.isYourLicense,
            exportFront: _exportFront,
          ),
        );
        break;
      case ExportTemplate.story:
        aspectRatio = 9 / 16;
        activeTemplateWidget = RepaintBoundary(
          key: _storyKey,
          child: StoryExportTemplate(
            theme: widget.theme,
            rp: widget.rp,
            showBoth: widget.showBoth,
            isYourLicense: widget.isYourLicense,
            exportFront: _exportFront,
          ),
        );
        break;
      case ExportTemplate.post:
        aspectRatio = 1 / 1;
        activeTemplateWidget = RepaintBoundary(
          key: _postKey,
          child: PostExportTemplate(
            theme: widget.theme,
            rp: widget.rp,
            showBoth: widget.showBoth,
            isYourLicense: widget.isYourLicense,
            exportFront: _exportFront,
          ),
        );
        break;
    }

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.theme.textColor.withValues(alpha: 0.1),
          ),
          color: Colors.black26,
        ),
        clipBehavior: Clip.antiAlias,
        child: FittedBox(fit: BoxFit.contain, child: activeTemplateWidget),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomSheetBg = widget.theme.isDark
        ? const Color(0xFF151833)
        : const Color(0xFFFFF4F8);

    return Container(
      decoration: BoxDecoration(
        color: bottomSheetBg,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: widget.theme.textColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'LICENSE EXPORT STUDIO',
            style: AppTypography.body(fontSize: 16, fontWeight: FontWeight.w900, color: widget.theme.textColor).copyWith(letterSpacing: 2),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose a style and share your license card',
            style: AppTypography.body(fontSize: 12, fontWeight: FontWeight.w500, color: widget.theme.textColor.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 20),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: _buildPreviewFrame(),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Show Card Side:',
                style: AppTypography.body(fontSize: 13, fontWeight: FontWeight.bold, color: widget.theme.textColor.withValues(alpha: 0.7)),
              ),
              Row(
                children: [
                  _exportSideButton(
                    label: 'Front',
                    isActive: _exportFront,
                    onTap: () => setState(() => _exportFront = true),
                  ),
                  const SizedBox(width: 8),
                  _exportSideButton(
                    label: 'Back',
                    isActive: !_exportFront,
                    onTap: () => setState(() => _exportFront = false),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _templateTab(
                  type: ExportTemplate.transparent,
                  title: 'Card Only',
                  icon: Icons.filter_none_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _templateTab(
                  type: ExportTemplate.story,
                  title: 'Story 9:16',
                  icon: Icons.stay_current_portrait_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _templateTab(
                  type: ExportTemplate.post,
                  title: 'Post 1:1',
                  icon: Icons.crop_square_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: (_isSaving || _isSharing) ? null : _saveToDevice,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : const Icon(Icons.save_alt_rounded, size: 20),
                    label: Text(
                      _isSaving ? 'Saving...' : 'Save Photo',
                      style: AppTypography.body(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: widget.theme.accentColor,
                      side: BorderSide(
                        color: widget.theme.accentColor,
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: (_isSaving || _isSharing) ? null : _shareImage,
                    icon: _isSharing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Icon(Icons.share_rounded, size: 20),
                    label: Text(
                      _isSharing ? 'Sharing...' : 'Share',
                      style: AppTypography.body(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.theme.accentColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _exportSideButton({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? widget.theme.accentColor
              : widget.theme.textColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? widget.theme.accentColor
                : widget.theme.textColor.withValues(alpha: 0.1),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.body(fontSize: 12, fontWeight: FontWeight.bold, color: isActive
                ? Colors.white
                : widget.theme.textColor.withValues(alpha: 0.7)),
        ),
      ),
    );
  }

  Widget _templateTab({
    required ExportTemplate type,
    required String title,
    required IconData icon,
  }) {
    final isSelected = _selectedTemplate == type;
    return GestureDetector(
      onTap: () => setState(() => _selectedTemplate = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? widget.theme.accentColor.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? widget.theme.accentColor
                : widget.theme.textColor.withValues(alpha: 0.15),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? widget.theme.accentColor
                  : widget.theme.textColor.withValues(alpha: 0.6),
              size: 20,
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: AppTypography.body(fontSize: 11, fontWeight: FontWeight.bold, color: isSelected
                    ? widget.theme.accentColor
                    : widget.theme.textColor),
            ),
          ],
        ),
      ),
    );
  }
}
