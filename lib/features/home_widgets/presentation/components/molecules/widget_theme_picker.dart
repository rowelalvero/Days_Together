import 'package:flutter/material.dart';
import 'package:days_together/models/app_settings.dart';
import 'package:days_together/features/home_widgets/presentation/components/atoms/widget_theme_chip.dart';

class WidgetThemePicker extends StatelessWidget {
  final ThemeType selectedTheme;
  final ValueChanged<ThemeType> onThemeChanged;

  const WidgetThemePicker({
    super.key,
    required this.selectedTheme,
    required this.onThemeChanged,
  });

  static const List<ThemeType> supportedThemes = [
    ThemeType.midnightRose,
    ThemeType.pink,
    ThemeType.deepPurple,
    ThemeType.liquidGlass,
    ThemeType.offWhite,
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Widget Theme Palette',
          style: TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: supportedThemes.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final type = supportedThemes[index];
              return WidgetThemeChip(
                themeType: type,
                isSelected: selectedTheme == type,
                onSelected: () => onThemeChanged(type),
              );
            },
          ),
        ),
      ],
    );
  }
}
