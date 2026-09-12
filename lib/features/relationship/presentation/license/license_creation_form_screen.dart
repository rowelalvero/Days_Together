import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/features/theme/theme_controller.dart';
import 'package:days_together/shared/widgets/glass_container.dart';

/// The Scaffold shell around the first-time license application form:
/// title bar, scrollable form card, and the submit button. Extracted from
/// [RelationshipLicenseScreen]'s `_buildCreationForm` (Migration audit item
/// 6).
///
/// [formFields] is built by the screen (via its existing
/// `_buildFormFields`, unchanged) and passed straight through -- all the
/// underlying `TextEditingController`s/gender/birthdate/signature state
/// stay owned by the screen's State, matching the reasoning
/// `CreationLicenseForm`'s own doc comment already gives for this
/// screen's other extracted pieces.
class LicenseCreationFormScreen extends ConsumerWidget {
  const LicenseCreationFormScreen({
    super.key,
    required this.theme,
    required this.formFields,
    required this.onSubmit,
    required this.onCancel,
  });

  final LoveStoryTheme theme;
  final List<Widget> formFields;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'License Application',
          style: AppTypography.heading(
            fontWeight: FontWeight.bold,
            color: theme.textColor,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.textColor),
          onPressed: onCancel,
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: ref.watch(themeControllerProvider).currentGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GlassContainer(
                    borderRadius: 20,
                    opacity: 0.04,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: formFields,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: onSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.accentColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                    child: Text(
                      'Generate Relationship License ID',
                      style: AppTypography.body(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
