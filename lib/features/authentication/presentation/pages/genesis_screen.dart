import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/features/theme/theme_controller.dart';
import 'package:days_together/features/relationship/workspace_controller.dart';
import 'package:days_together/app/router/route_names.dart';
import 'package:days_together/features/authentication/presentation/widgets/continue_button.dart';
import 'package:days_together/features/authentication/presentation/widgets/date_time_picker_tile.dart';
import 'package:intl/intl.dart';

/// Onboarding screen where a couple's creator sets when their story
/// began.
///
/// Its inline date/time picker tiles were extracted into
/// DateTimePickerTile under `presentation/widgets/` (Migration audit
/// item 6); the "Continue" button reuses the same ContinueButton widget
/// CreateCoupleCodeScreen uses, since both render an identical style.
class GenesisScreen extends ConsumerStatefulWidget {
  const GenesisScreen({super.key});

  @override
  ConsumerState<GenesisScreen> createState() => _GenesisScreenState();
}

class _GenesisScreenState extends ConsumerState<GenesisScreen> {
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  @override
  Widget build(BuildContext context) {
    final themeProvider = ref.watch(themeControllerProvider);
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
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: theme.textColor,
                  ),
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
                  'Select the day and time your beautiful journey began.',
                  style: AppTypography.spectral(
                    fontSize: 16,
                    color: theme.textColor.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You can always adjust this date later in settings.',
                  style: AppTypography.spectral(
                    fontSize: 13,
                    color: theme.textColor.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 40),
                // Date Picker
                DateTimePickerTile(
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
                              brightness: theme.isDark
                                  ? Brightness.dark
                                  : Brightness.light,
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
                DateTimePickerTile(
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
                              brightness: theme.isDark
                                  ? Brightness.dark
                                  : Brightness.light,
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
                ContinueButton(
                  theme: theme,
                  onPressed: () async {
                    final workspace = ref.read(
                      workspaceControllerProvider.notifier,
                    );
                    await workspace.setStartDate(_selectedDate);
                    await workspace.setStartTime(_selectedTime);
                    if (!context.mounted) return;
                    context.push(Routes.avatar);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
