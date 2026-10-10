import 'package:days_together/features/theme/theme_controller.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/features/theme/presentation/widgets/custom_theme_designer.dart';
import 'package:days_together/features/theme/presentation/widgets/theme_card.dart';
import 'package:days_together/shared/models/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:days_together/app/theme/app_typography.dart';

/// The theme picker: a grid of preset themes plus a custom color designer
/// when the custom theme is selected.
///
/// Its already-proper `_ThemeCard`/`_CustomThemeDesigner`/`_ModeChip`
/// classes were moved out to their own files, and `_CustomThemeDesigner`'s
/// remaining `_buildX` methods were extracted into widgets alongside them
/// (Migration audit item 6).
class ThemeSelectorScreen extends ConsumerWidget {
  const ThemeSelectorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeProvider = ref.watch(themeControllerProvider);
    final theme = themeProvider.currentLoveTheme;
    final availableThemes = ThemeManager.themes.keys.toList()
      ..add(ThemeType.custom);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Themes',
          style: AppTypography.heading(
            fontWeight: FontWeight.bold,
            color: theme.textColor,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: theme.textColor),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: themeProvider.currentGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Theme Grid ---
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 24,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: availableThemes.length,
                  itemBuilder: (context, index) {
                    final themeType = availableThemes[index];
                    final previewTheme = ThemeManager.resolveTheme(
                      themeType,
                      themeProvider.settings,
                    );
                    final isSelected = themeProvider.currentTheme == themeType;

                    return ThemeCard(
                      theme: previewTheme,
                      isSelected: isSelected,
                      parentTheme: theme,
                      onTap: () => ref
                          .read(themeControllerProvider.notifier)
                          .changeTheme(themeType),
                    );
                  },
                ),
                const SizedBox(height: 40),

                // --- Custom Theme Designer ---
                if (themeProvider.currentTheme == ThemeType.custom) ...[
                  Text(
                    'CUSTOM DESIGNER',
                    style: AppTypography.caption(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: theme.textColor.withValues(alpha: 0.6),
                    ).copyWith(letterSpacing: 2),
                  ),
                  const SizedBox(height: 16),
                  CustomThemeDesigner(parentTheme: theme),
                  const SizedBox(height: 40),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
