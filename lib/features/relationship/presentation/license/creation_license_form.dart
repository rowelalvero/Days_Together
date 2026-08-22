import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:days_together/features/relationship/data/signature_codec.dart';
import 'package:days_together/features/relationship/presentation/license/painters/signature_painter.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/themes/theme_manager.dart';

/// The first-time license creation form -- extracted out of
/// `RelationshipLicenseScreenState._buildFormFields`/`_buildSignatureBox`
/// (Migration Phase 8), which built the whole form as a ~375-line method
/// pair closing over the screen state's mutable fields directly. Made a
/// real stateless widget instead: every value it needs is passed in
/// explicitly, and every mutation goes back out through a callback --
/// `RelationshipLicenseScreenState` still owns all the state, this just
/// renders it.
///
/// [isYou] is preserved from the original method's signature even though
/// only `true` is passed at the current call site (this is a single-person
/// creation flow) -- not narrowed here, since that would be an opinionated
/// scope change unrelated to the file-size reduction this extraction is
/// for.
class CreationLicenseForm extends StatelessWidget {
  const CreationLicenseForm({
    super.key,
    required this.isYou,
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
    required this.signatureStr,
    required this.onSignatureTap,
    required this.onSignatureClear,
  });

  final bool isYou;
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

  final String signatureStr;
  final VoidCallback onSignatureTap;
  final VoidCallback onSignatureClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Full Name *'),
        TextField(
          controller: nameCtrl,
          textInputAction: TextInputAction.next,
          style: AppTypography.body(color: theme.textColor),
          decoration: _inputDecoration('Enter full name'),
        ),
        const SizedBox(height: 16),
        _fieldLabel('Sex / Gender'),
        Row(
          children: [
            _genderOption('Male', gender, onGenderChanged),
            const SizedBox(width: 12),
            _genderOption('Female', gender, onGenderChanged),
          ],
        ),
        const SizedBox(height: 16),
        _fieldLabel('Birthdate'),
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
        _fieldLabel('Signature'),
        _buildSignatureBox(),
        const SizedBox(height: 16),
        _fieldLabel('Nationality'),
        TextField(
          controller: nationalityCtrl,
          textInputAction: TextInputAction.next,
          style: AppTypography.body(color: theme.textColor),
          decoration: _inputDecoration('e.g., Love Land'),
        ),
        const SizedBox(height: 16),
        _fieldLabel('Address'),
        TextField(
          controller: addressCtrl,
          textInputAction: TextInputAction.next,
          style: AppTypography.body(color: theme.textColor),
          decoration: _inputDecoration('Enter address details'),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _fieldLabel('Height'),
                  TextField(
                    controller: heightCtrl,
                    textInputAction: TextInputAction.next,
                    style: AppTypography.body(color: theme.textColor),
                    decoration: _inputDecoration('e.g., 5\'7"'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _fieldLabel('Weight'),
                  TextField(
                    controller: weightCtrl,
                    textInputAction: TextInputAction.next,
                    style: AppTypography.body(color: theme.textColor),
                    decoration: _inputDecoration('e.g., 65 kg'),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _fieldLabel('Blood Type'),
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
                  _fieldLabel('Eyes Color'),
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
        _fieldLabel('Conditions'),
        TextField(
          controller: conditionsCtrl,
          textInputAction: TextInputAction.next,
          style: AppTypography.body(color: theme.textColor),
          decoration: _inputDecoration('e.g., Head over heels'),
        ),
        const SizedBox(height: 16),
        _fieldLabel('Phone / Emergency Mobile'),
        TextField(
          controller: phoneCtrl,
          textInputAction: TextInputAction.done,
          keyboardType: TextInputType.phone,
          style: AppTypography.body(color: theme.textColor),
          decoration: _inputDecoration('Enter phone number'),
        ),
      ],
    );
  }

  Widget _buildSignatureBox() {
    return GestureDetector(
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
            if (signatureStr.isNotEmpty)
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: CustomPaint(
                    painter: ScaleSignaturePainter(
                      strokes: SignatureCodec.decode(signatureStr),
                      color: theme.accentColor,
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
        borderSide: BorderSide(color: theme.textColor.withValues(alpha: 0.1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.textColor.withValues(alpha: 0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.accentColor, width: 1.5),
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? theme.accentColor : theme.textColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? theme.accentColor : theme.textColor.withValues(alpha: 0.1),
            ),
          ),
          child: Text(
            value,
            style: AppTypography.body(fontWeight: FontWeight.bold, color: isSelected ? Colors.white : theme.textColor.withValues(alpha: 0.8)),
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 4),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.body(fontSize: 11, fontWeight: FontWeight.bold, color: theme.textColor.withValues(alpha: 0.6)).copyWith(letterSpacing: 1),
      ),
    );
  }
}
