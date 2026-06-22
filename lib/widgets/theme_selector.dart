import 'package:days_together/providers/theme_provider.dart';
import 'package:days_together/themes/theme_manager.dart';
import 'package:days_together/models/timeline_model.dart';
import 'package:days_together/widgets/glass_container.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

class ThemeSelectorScreen extends StatelessWidget {
  const ThemeSelectorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final theme = themeProvider.currentLoveTheme;
    final availableThemes = ThemeManager.themes.keys.toList()
      ..add(ThemeType.custom);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Themes',
          style: GoogleFonts.playfairDisplay(
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

                    return _ThemeCard(
                      theme: previewTheme,
                      isSelected: isSelected,
                      parentTheme: theme,
                      onTap: () => themeProvider.changeTheme(themeType),
                    );
                  },
                ),
                const SizedBox(height: 40),

                // --- Custom Theme Designer ---
                if (themeProvider.currentTheme == ThemeType.custom) ...[
                  Text(
                    'CUSTOM DESIGNER',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      color: theme.textColor.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _CustomThemeDesigner(parentTheme: theme),
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

// ──────────────────────────────────────
// THEME CARD
// ──────────────────────────────────────
class _ThemeCard extends StatelessWidget {
  final LoveStoryTheme theme;
  final LoveStoryTheme parentTheme;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.theme,
    required this.isSelected,
    required this.parentTheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isSelected
                      ? parentTheme.textColor
                      : parentTheme.textColor.withValues(alpha: 0.1),
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: theme.accentColor.withValues(alpha: 0.3),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ]
                    : [],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              theme.primaryColor,
                              theme.secondaryColor,
                              theme.backgroundColor,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: -20,
                      left: -20,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (theme.isDark ? Colors.white : Colors.black)
                              .withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                    // Accent dot
                    Positioned(
                      bottom: 12,
                      left: 12,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: theme.accentColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.isDark ? Colors.white24 : Colors.black12,
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                    if (isSelected)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: parentTheme.textColor,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check,
                            size: 14,
                            color: theme.primaryColor,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            theme.name,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? parentTheme.textColor
                  : parentTheme.textColor.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────
// CUSTOM THEME DESIGNER
// ──────────────────────────────────────
class _CustomThemeDesigner extends StatefulWidget {
  final LoveStoryTheme parentTheme;

  const _CustomThemeDesigner({required this.parentTheme});

  @override
  State<_CustomThemeDesigner> createState() => _CustomThemeDesignerState();
}

class _CustomThemeDesignerState extends State<_CustomThemeDesigner> {
  String _activeSlot = 'primary';
  final TextEditingController _hexController = TextEditingController();

  // Curated romantic color palette
  static const List<int> _paletteColors = [
    0xFFFF4D6D, 0xFFC9184A, 0xFFFF85A1, 0xFFFFC4D6, 0xFFFF6B9D,
    0xFF7B2CBF, 0xFF9D4EDD, 0xFFE0AAFF, 0xFFBB86FC, 0xFF6200EA,
    0xFF00B4D8, 0xFF0077B6, 0xFFADE8F4, 0xFF48CAE4, 0xFF03045E,
    0xFF2D6A4F, 0xFF52B788, 0xFF95D5B2, 0xFFFFB703, 0xFFE8477E,
    0xFF10122B, 0xFF1A1B41, 0xFF0A0B1A, 0xFF2C003E, 0xFF590D22,
    0xFFFFF0F5, 0xFFFFE4EC, 0xFFFFF8FA, 0xFFF8EDEB, 0xFFE8E0D8,
  ];

  // Available fonts
  static const List<String> _availableFonts = [
    'Montserrat',
    'Inter',
    'Playfair Display',
    'Roboto',
    'Lato',
    'Poppins',
    'Raleway',
    'Outfit',
    'Cormorant Garamond',
    'Spectral',
    'Dancing Script',
    'Pacifico',
    'Lobster',
    'Great Vibes',
    'Quicksand',
    'Nunito',
  ];

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

  void _applyColor(ThemeProvider provider, int colorValue) {
    switch (_activeSlot) {
      case 'primary':
        provider.setCustomColor(primary: colorValue);
        break;
      case 'secondary':
        provider.setCustomColor(secondary: colorValue);
        break;
      case 'background':
        provider.setCustomColor(background: colorValue);
        break;
      case 'accent':
        provider.setCustomColor(accent: colorValue);
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
    final themeProvider = context.watch<ThemeProvider>();
    final settings = themeProvider.settings;
    final theme = widget.parentTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Color Slot Selector
        _buildSectionLabel('Color Slots', theme),
        const SizedBox(height: 8),
        _buildColorSlots(settings, theme),
        const SizedBox(height: 24),

        // Color Palette
        _buildSectionLabel('Pick a Color', theme),
        const SizedBox(height: 8),
        _buildColorPalette(themeProvider, settings),
        const SizedBox(height: 24),

        // Hex Input
        _buildHexInput(themeProvider, theme),
        const SizedBox(height: 32),

        // Dark / Light toggle
        _buildSectionLabel('Mode', theme),
        const SizedBox(height: 8),
        _buildDarkLightToggle(themeProvider, settings, theme),
        const SizedBox(height: 32),

        // Font Selector
        _buildSectionLabel('Font Family', theme),
        const SizedBox(height: 8),
        _buildFontSelector(themeProvider, settings, theme),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildSectionLabel(String text, LoveStoryTheme theme) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
        color: theme.textColor.withValues(alpha: 0.35),
      ),
    );
  }

  Widget _buildColorSlots(AppSettings settings, LoveStoryTheme theme) {
    final slots = [
      _SlotData('primary', 'Primary', settings.customPrimaryColor),
      _SlotData('secondary', 'Secondary', settings.customSecondaryColor),
      _SlotData('background', 'Background', settings.customBackgroundColor),
      _SlotData('accent', 'Accent', settings.customAccentColor),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: slots.map((slot) {
        final isActive = _activeSlot == slot.key;
        return GestureDetector(
          onTap: () => setState(() => _activeSlot = slot.key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isActive
                  ? theme.accentColor.withValues(alpha: 0.2)
                  : theme.textColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isActive
                    ? theme.accentColor
                    : theme.textColor.withValues(alpha: 0.1),
                width: isActive ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Color(slot.colorValue),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.textColor.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  slot.label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive
                        ? theme.accentColor
                        : theme.textColor.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildColorPalette(ThemeProvider provider, AppSettings settings) {
    final activeColor = _getActiveColor(settings);

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _paletteColors.map((colorValue) {
        final isSelected = activeColor == colorValue;
        return GestureDetector(
          onTap: () => _applyColor(provider, colorValue),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Color(colorValue),
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.white : Colors.transparent,
                width: isSelected ? 3 : 0,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Color(colorValue).withValues(alpha: 0.5),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ]
                  : [],
            ),
            child: isSelected
                ? const Center(
                    child: Icon(Icons.check, color: Colors.white, size: 18),
                  )
                : null,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildHexInput(ThemeProvider provider, LoveStoryTheme theme) {
    return GlassContainer(
      borderRadius: 18,
      opacity: 0.06,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Text(
            '#',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: theme.accentColor,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _hexController,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 14,
                color: theme.textColor,
              ),
              decoration: InputDecoration(
                hintText: 'Enter hex (e.g. FF4D6D)',
                hintStyle: GoogleFonts.jetBrainsMono(
                  fontSize: 14,
                  color: theme.textColor.withValues(alpha: 0.25),
                ),
                border: InputBorder.none,
              ),
              maxLength: 6,
              buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
              onSubmitted: (value) {
                final hex = value.replaceAll('#', '').trim();
                if (hex.length == 6) {
                  final colorInt = int.tryParse('FF$hex', radix: 16);
                  if (colorInt != null) {
                    _applyColor(provider, colorInt);
                    _hexController.clear();
                  }
                }
              },
            ),
          ),
          IconButton(
            onPressed: () {
              final hex = _hexController.text.replaceAll('#', '').trim();
              if (hex.length == 6) {
                final colorInt = int.tryParse('FF$hex', radix: 16);
                if (colorInt != null) {
                  _applyColor(provider, colorInt);
                  _hexController.clear();
                }
              }
            },
            icon: Icon(
              Icons.check_circle_rounded,
              color: theme.accentColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDarkLightToggle(
    ThemeProvider provider,
    AppSettings settings,
    LoveStoryTheme theme,
  ) {
    return GlassContainer(
      borderRadius: 18,
      opacity: 0.06,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: _ModeChip(
              label: 'Dark',
              icon: Icons.dark_mode_rounded,
              isSelected: settings.customIsDark,
              theme: theme,
              onTap: () => provider.setCustomIsDark(true),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ModeChip(
              label: 'Light',
              icon: Icons.light_mode_rounded,
              isSelected: !settings.customIsDark,
              theme: theme,
              onTap: () => provider.setCustomIsDark(false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFontSelector(
    ThemeProvider provider,
    AppSettings settings,
    LoveStoryTheme theme,
  ) {
    return GlassContainer(
      borderRadius: 18,
      opacity: 0.06,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _availableFonts.contains(settings.customFont)
              ? settings.customFont
              : 'Montserrat',
          isExpanded: true,
          dropdownColor: theme.secondaryColor,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: theme.textColor.withValues(alpha: 0.5),
          ),
          items: _availableFonts.map((font) {
            TextStyle fontStyle;
            try {
              fontStyle = GoogleFonts.getFont(
                font,
                fontSize: 15,
                color: theme.textColor,
              );
            } catch (_) {
              fontStyle = TextStyle(
                fontSize: 15,
                color: theme.textColor,
              );
            }
            return DropdownMenuItem<String>(
              value: font,
              child: Text(font, style: fontStyle),
            );
          }).toList(),
          onChanged: (font) {
            if (font != null) {
              provider.setCustomFont(font);
            }
          },
        ),
      ),
    );
  }
}

class _SlotData {
  final String key;
  final String label;
  final int colorValue;
  const _SlotData(this.key, this.label, this.colorValue);
}

class _ModeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final LoveStoryTheme theme;
  final VoidCallback onTap;

  const _ModeChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.accentColor.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? theme.accentColor
                : theme.textColor.withValues(alpha: 0.08),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? theme.accentColor
                  : theme.textColor.withValues(alpha: 0.4),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? theme.accentColor
                    : theme.textColor.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
