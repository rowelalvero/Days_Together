import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:days_together/features/relationship/data/signature_codec.dart';
import 'package:days_together/features/relationship/presentation/license/painters/signature_painter.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/themes/theme_manager.dart';

/// One partner's editable license fields -- extracted out of
/// `EditLicenseSheet`'s `_buildForm` (Migration Phase 8), which built the
/// identical form twice (once per partner) as a ~430-line method closing
/// over `_EditLicenseSheetState`'s mutable fields directly. Made a real
/// stateless widget instead: every value it needs is passed in explicitly,
/// and every mutation goes back out through a callback -- `EditLicenseSheet`
/// still owns all the state, this just renders it.
class PersonLicenseForm extends StatelessWidget {
  const PersonLicenseForm({
    super.key,
    required this.theme,
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.addressCtrl,
    required this.nationalityCtrl,
    required this.weightCtrl,
    required this.heightCtrl,
    required this.bloodCtrl,
    required this.eyeCtrl,
    required this.conditionsCtrl,
    required this.gender,
    required this.onGenderChanged,
    required this.birthdate,
    required this.onBirthdateTap,
    required this.dateIssued,
    required this.onDateIssuedTap,
    required this.signatureStr,
    required this.onSignatureTap,
    required this.onSignatureClear,
  });

  final LoveStoryTheme theme;
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController addressCtrl;
  final TextEditingController nationalityCtrl;
  final TextEditingController weightCtrl;
  final TextEditingController heightCtrl;
  final TextEditingController bloodCtrl;
  final TextEditingController eyeCtrl;
  final TextEditingController conditionsCtrl;

  final String gender;
  final ValueChanged<String> onGenderChanged;

  final DateTime? birthdate;
  final VoidCallback onBirthdateTap;

  final DateTime? dateIssued;
  final VoidCallback onDateIssuedTap;

  final String signatureStr;
  final VoidCallback onSignatureTap;
  final VoidCallback onSignatureClear;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          // Name Field
          _buildFieldLabel('Full Name'),

          TextField(
            controller: nameCtrl,
            textInputAction: TextInputAction.next,
            style: AppTypography.body(color: theme.textColor),

            decoration: _inputDecoration('Enter full name'),
          ),

          const SizedBox(height: 16),

          // Gender Selector
          _buildFieldLabel('Sex / Gender'),

          Row(
            children: [
              _genderOption('Male', gender, onGenderChanged),

              const SizedBox(width: 12),

              _genderOption('Female', gender, onGenderChanged),
            ],
          ),

          const SizedBox(height: 16),

          // Birthdate Field
          _buildFieldLabel('Birthdate'),

          InkWell(
            onTap: onBirthdateTap,

            borderRadius: BorderRadius.circular(12),

            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),

              decoration: BoxDecoration(
                color: theme.textColor.withValues(alpha: 0.05),

                borderRadius: BorderRadius.circular(12),

                border: Border.all(
                  color: theme.textColor.withValues(alpha: 0.1),
                ),
              ),

              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,

                children: [
                  Text(
                    birthdate != null
                        ? DateFormat('MMMM dd, yyyy').format(birthdate!)
                        : 'Select Birthdate',

                    style: AppTypography.body(color: birthdate != null
                          ? theme.textColor
                          : theme.textColor.withValues(alpha: 0.5)),
                  ),

                  Icon(
                    Icons.calendar_month_rounded,
                    color: theme.accentColor,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Nationality
          _buildFieldLabel('Nationality'),

          TextField(
            controller: nationalityCtrl,
            textInputAction: TextInputAction.next,
            style: AppTypography.body(color: theme.textColor),

            decoration: _inputDecoration('Enter nationality'),
          ),

          const SizedBox(height: 16),

          // Height and Weight
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    _buildFieldLabel('Height'),

                    TextField(
                      controller: heightCtrl,
                      textInputAction: TextInputAction.next,
                      style: AppTypography.body(color: theme.textColor),

                      decoration: _inputDecoration('e.g., 175 cm'),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    _buildFieldLabel('Weight'),

                    TextField(
                      controller: weightCtrl,
                      textInputAction: TextInputAction.next,
                      style: AppTypography.body(color: theme.textColor),

                      decoration: _inputDecoration('e.g., 68 kg'),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Address Field
          _buildFieldLabel('Address'),

          TextField(
            controller: addressCtrl,
            textInputAction: TextInputAction.next,
            style: AppTypography.body(color: theme.textColor),

            decoration: _inputDecoration('Enter address'),
          ),

          const SizedBox(height: 16),

          // Date Issued
          _buildFieldLabel('Date Issued'),

          InkWell(
            onTap: onDateIssuedTap,

            borderRadius: BorderRadius.circular(12),

            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),

              decoration: BoxDecoration(
                color: theme.textColor.withValues(alpha: 0.05),

                borderRadius: BorderRadius.circular(12),

                border: Border.all(
                  color: theme.textColor.withValues(alpha: 0.1),
                ),
              ),

              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,

                children: [
                  Text(
                    dateIssued != null
                        ? DateFormat('MMMM dd, yyyy').format(dateIssued!)
                        : 'Default (Relationship Date)',

                    style: AppTypography.body(color:
                          dateIssued != null
                          ? theme.textColor
                          : theme.textColor.withValues(alpha: 0.5)),
                  ),

                  Icon(
                    Icons.calendar_month_rounded,
                    color: theme.accentColor,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Signature
          _buildFieldLabel('Signature'),

          GestureDetector(
            onTap: onSignatureTap,

            child: Container(
              width: double.infinity,

              height: 100,

              decoration: BoxDecoration(
                color: theme.textColor.withValues(alpha: 0.05),

                borderRadius: BorderRadius.circular(12),

                border: Border.all(
                  color: theme.textColor.withValues(alpha: 0.1),
                ),
              ),

              child: Stack(
                alignment: Alignment.center,

                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),

                      child: CustomPaint(
                        painter: ScaleSignaturePainter(
                          strokes: SignatureCodec.decode(signatureStr),

                          color: theme.accentColor,

                          strokeWidth: 2.5,
                        ),
                      ),
                    ),
                  ),

                  if (signatureStr.isEmpty)
                    Text(
                      'Tap to draw signature',

                      style: AppTypography.body(color: theme.textColor.withValues(alpha: 0.4), fontSize: 14),
                    ),

                  if (signatureStr.isNotEmpty)
                    Positioned(
                      top: 4,

                      right: 4,

                      child: IconButton(
                        icon: const Icon(Icons.clear, size: 18),

                        color: Colors.redAccent,

                        onPressed: onSignatureClear,
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Blood Type and Eye Color
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    _buildFieldLabel('Blood Type'),

                    TextField(
                      controller: bloodCtrl,
                      textInputAction: TextInputAction.next,
                      style: AppTypography.body(color: theme.textColor),

                      decoration: _inputDecoration('e.g., O+'),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    _buildFieldLabel('Eyes Color'),

                    TextField(
                      controller: eyeCtrl,
                      textInputAction: TextInputAction.next,
                      style: AppTypography.body(color: theme.textColor),

                      decoration: _inputDecoration('e.g., Brown'),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Conditions
          _buildFieldLabel('Conditions'),

          TextField(
            controller: conditionsCtrl,
            textInputAction: TextInputAction.next,
            style: AppTypography.body(color: theme.textColor),

            decoration: _inputDecoration('e.g., Head over heels'),
          ),

          const SizedBox(height: 16),

          // Phone Field (Emergency Contact Info)
          _buildFieldLabel('Emergency Phone Number'),

          TextField(
            controller: phoneCtrl,
            textInputAction: TextInputAction.done,
            keyboardType: TextInputType.phone,

            style: AppTypography.body(color: theme.textColor),

            decoration: _inputDecoration('Enter mobile number'),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 4),

      child: Text(
        label.toUpperCase(),

        style: AppTypography.body(fontSize: 11, fontWeight: FontWeight.bold, color: theme.textColor.withValues(alpha: 0.6)).copyWith(letterSpacing: 1),
      ),
    );
  }

  Widget _genderOption(
    String value,
    String current,
    ValueChanged<String> onChanged,
  ) {
    final isSelected = current == value;

    return Expanded(
      child: InkWell(
        onTap: () => onChanged(value),

        borderRadius: BorderRadius.circular(12),

        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),

          decoration: BoxDecoration(
            color: isSelected
                ? theme.accentColor.withValues(alpha: 0.1)
                : theme.textColor.withValues(alpha: 0.05),

            borderRadius: BorderRadius.circular(12),

            border: Border.all(
              color: isSelected
                  ? theme.accentColor
                  : theme.textColor.withValues(alpha: 0.1),

              width: 1.5,
            ),
          ),

          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,

            children: [
              Icon(
                value == 'Male' ? Icons.male_rounded : Icons.female_rounded,

                color: isSelected
                    ? theme.accentColor
                    : theme.textColor.withValues(alpha: 0.5),

                size: 20,
              ),

              const SizedBox(width: 8),

              Text(
                value,

                style: AppTypography.body(fontWeight: FontWeight.bold, color: isSelected
                      ? theme.accentColor
                      : theme.textColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,

      hintStyle: AppTypography.body(color: theme.textColor.withValues(alpha: 0.4)),

      filled: true,

      fillColor: theme.textColor.withValues(alpha: 0.05),

      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),

        borderSide: BorderSide.none,
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),

        borderSide: BorderSide(color: theme.accentColor, width: 1.5),
      ),
    );
  }
}
