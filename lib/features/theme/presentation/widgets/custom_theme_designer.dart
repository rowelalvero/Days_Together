import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/features/theme/presentation/widgets/color_palette.dart';
import 'package:days_together/features/theme/presentation/widgets/color_slot_selector.dart';
import 'package:days_together/features/theme/presentation/widgets/dark_light_toggle.dart';
import 'package:days_together/features/theme/presentation/widgets/hex_color_input.dart';
import 'package:days_together/features/theme/presentation/widgets/section_label.dart';
import 'package:days_together/features/theme/theme_controller.dart';
import 'package:days_together/shared/models/app_settings.dart';

/// The custom-theme color designer on [ThemeSelectorScreen], shown when
/// [ThemeType.custom] is selected. Moved out of the screen file into its
/// own file, and its `_buildX` methods extracted into widgets under this
/// same directory (Migration audit item 6) -- this class still owns which
/// color slot is active and the hex input's controller, matching how this
/// app's other extracted forms keep state on their own State.
class CustomThemeDesigner extends ConsumerStatefulWidget {
  const CustomThemeDesigner({super.key, required this.parentTheme});

  final LoveStoryTheme parentTheme;

  @override
  ConsumerState<CustomThemeDesigner> createState() =>
      _CustomThemeDesignerState();
}

class _CustomThemeDesignerState extends ConsumerState<CustomThemeDesigner> {
  String _activeSlot = 'primary';
  final TextEditingController _hexController = TextEditingController();

  int _getActiveColor(AppSettings settings) {
    switch (_activeSlot) {
      case 'primary':
        return settings.customPrimaryColor;
      case 'secondary':
        return settings.customSecondaryColor;
      case 'background':
        return settings.customBackgroundColor;
      case 'accent':
        return settings.customAccentColor;
      default:
        return settings.customPrimaryColor;
    }
  }

  void _applyColor(int colorValue) {
    final notifier = ref.read(themeControllerProvider.notifier);
    switch (_activeSlot) {
      case 'primary':
        notifier.setCustomColor(primary: colorValue);
        break;
      case 'secondary':
        notifier.setCustomColor(secondary: colorValue);
        break;
      case 'background':
        notifier.setCustomColor(background: colorValue);
        break;
      case 'accent':
        notifier.setCustomColor(accent: colorValue);
        break;
    }
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeControllerProvider);
    final settings = themeState.settings;
    final theme = widget.parentTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Color Slot Selector
        SectionLabel(text: 'Color Slots', theme: theme),
        const SizedBox(height: 8),
        ColorSlotSelector(
          settings: settings,
          theme: theme,
          activeSlot: _activeSlot,
          onSlotSelected: (slot) => setState(() => _activeSlot = slot),
        ),
        const SizedBox(height: 24),

        // Color Palette
        SectionLabel(text: 'Pick a Color', theme: theme),
        const SizedBox(height: 8),
        ColorPalette(
          activeColor: _getActiveColor(settings),
          onColorSelected: _applyColor,
        ),
        const SizedBox(height: 24),

        // Hex Input
        HexColorInput(
          controller: _hexController,
          theme: theme,
          onColorSubmitted: _applyColor,
        ),
        const SizedBox(height: 32),

        // Dark / Light toggle
        SectionLabel(text: 'Mode', theme: theme),
        const SizedBox(height: 8),
        DarkLightToggle(
          isDark: settings.customIsDark,
          theme: theme,
          onChanged: (isDark) => ref
              .read(themeControllerProvider.notifier)
              .setCustomIsDark(isDark),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}
