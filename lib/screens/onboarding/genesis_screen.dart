import 'package:days_together/screens/onboarding/avatar_creation_screen.dart';
import 'package:flutter/material.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/providers/theme_provider.dart';
import 'package:days_together/providers/relationship_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class GenesisScreen extends StatefulWidget {
  const GenesisScreen({super.key});

  @override
  State<GenesisScreen> createState() => _GenesisScreenState();
}

class _GenesisScreenState extends State<GenesisScreen> {
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final theme = themeProvider.currentLoveTheme;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: themeProvider.currentGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.textColor),
                ),
                const SizedBox(height: 20),
                Text(
                  'When did your\nstory begin?',
                  style: AppTypography.cormorant(
                    fontSize: 36,
                    color: theme.textColor,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Pick the exact day and time you became official.',
                  style: AppTypography.spectral(
                    fontSize: 16,
                    color: theme.textColor.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Don't worry—you can change this later.",
                  style: AppTypography.spectral(
                    fontSize: 13,
                    color: theme.textColor.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 40),
                // Date Picker
                _buildPickerTile(
                  icon: Icons.calendar_today_rounded,
                  label: 'DATE',
                  value: DateFormat('MMMM dd, yyyy').format(_selectedDate),
                  theme: theme,
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: ColorScheme.fromSeed(
                              seedColor: theme.accentColor,
                              brightness: theme.isDark ? Brightness.dark : Brightness.light,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (date != null) {
                      setState(() => _selectedDate = date);
                    }
                  },
                ),
                const SizedBox(height: 20),
                // Time Picker
                _buildPickerTile(
                  icon: Icons.access_time_rounded,
                  label: 'TIME',
                  value: _selectedTime.format(context),
                  theme: theme,
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: _selectedTime,
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: ColorScheme.fromSeed(
                              seedColor: theme.accentColor,
                              brightness: theme.isDark ? Brightness.dark : Brightness.light,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (time != null) {
                      setState(() => _selectedTime = time);
                    }
                  },
                ),
                const SizedBox(height: 60),
                // Continue Button
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: () async {
                      final provider = context.read<RelationshipProvider>();
                      await provider.setStartDate(_selectedDate);
                      await provider.setStartTime(_selectedTime);
                      if (!context.mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AvatarCreationScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.accentColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Continue',
                      style: AppTypography.button(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPickerTile({
    required IconData icon,
    required String label,
    required String value,
    required dynamic theme,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.textColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.textColor.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: theme.accentColor.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: theme.accentColor),
            ),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.caption(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: theme.textColor.withValues(alpha: 0.5),
                  ).copyWith(letterSpacing: 2),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: AppTypography.body(
                    color: theme.textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Icon(Icons.edit_rounded, color: theme.textColor.withValues(alpha: 0.3), size: 20),
          ],
        ),
      ),
    );
  }
}
