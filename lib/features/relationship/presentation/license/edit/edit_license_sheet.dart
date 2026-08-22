import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ConsumerState, ConsumerStatefulWidget;

import 'package:days_together/features/relationship/data/signature_codec.dart';
import 'package:days_together/features/relationship/license_controller.dart';
import 'package:days_together/features/relationship/license_details.dart';
import 'package:days_together/features/relationship/presentation/license/edit/person_license_form.dart';
import 'package:days_together/features/relationship/presentation/license/signature/signature_drawing_dialog.dart';
import 'package:days_together/providers/couple_session.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/themes/theme_manager.dart';

/// The bottom sheet for editing every field on the relationship license
/// (both partners' vitals, emergency contact, and signature). Extracted
/// out of relationship_license_screen.dart (Migration Phase 8) --
/// renamed from `_EditLicenseSheet` since it now needs to be public to
/// be shared across the license/ file split.
class EditLicenseSheet extends ConsumerStatefulWidget {
  final CoupleSession rp;

  final LoveStoryTheme theme;

  const EditLicenseSheet({super.key, required this.rp, required this.theme});

  @override
  ConsumerState<EditLicenseSheet> createState() => _EditLicenseSheetState();
}

class _EditLicenseSheetState extends ConsumerState<EditLicenseSheet> {
  // Personal Controllers

  late TextEditingController _yourNameCtrl;

  late TextEditingController _partnerNameCtrl;

  late TextEditingController _yourPhoneCtrl;

  late TextEditingController _partnerPhoneCtrl;

  late TextEditingController _yourAddressCtrl;

  late TextEditingController _partnerAddressCtrl;

  late TextEditingController _yourNationalityCtrl;

  late TextEditingController _partnerNationalityCtrl;

  late TextEditingController _yourWeightCtrl;

  late TextEditingController _partnerWeightCtrl;

  late TextEditingController _yourHeightCtrl;

  late TextEditingController _partnerHeightCtrl;

  // Additional controllers

  late TextEditingController _yourBloodCtrl;

  late TextEditingController _partnerBloodCtrl;

  late TextEditingController _yourEyeColorCtrl;

  late TextEditingController _partnerEyeColorCtrl;

  late TextEditingController _yourConditionsCtrl;

  late TextEditingController _partnerConditionsCtrl;

  late String _yourGender;

  late String _partnerGender;

  DateTime? _yourBirthdate;

  DateTime? _partnerBirthdate;

  DateTime? _yourDateIssued;

  DateTime? _partnerDateIssued;

  late String _yourSignatureStr;

  late String _partnerSignatureStr;

  @override
  void initState() {
    super.initState();

    final license = ref.read(licenseControllerProvider).value ?? const LicenseDetails();

    _yourNameCtrl = TextEditingController(text: widget.rp.yourName ?? '');

    _partnerNameCtrl = TextEditingController(text: widget.rp.partnerName ?? '');

    _yourPhoneCtrl = TextEditingController(text: license.yourPhone ?? '');

    _partnerPhoneCtrl = TextEditingController(
      text: license.partnerPhone ?? '',
    );

    _yourAddressCtrl = TextEditingController(text: license.yourAddress ?? '');

    _partnerAddressCtrl = TextEditingController(
      text: license.partnerAddress ?? '',
    );

    _yourNationalityCtrl = TextEditingController(
      text: license.yourNationality ?? 'Love Land',
    );

    _partnerNationalityCtrl = TextEditingController(
      text: license.partnerNationality ?? 'Love Land',
    );

    _yourWeightCtrl = TextEditingController(text: license.yourWeight ?? '—');

    _partnerWeightCtrl = TextEditingController(text: license.partnerWeight ?? '—');

    _yourHeightCtrl = TextEditingController(text: license.yourHeight ?? '—');

    _partnerHeightCtrl = TextEditingController(text: license.partnerHeight ?? '—');

    _yourBloodCtrl = TextEditingController(text: license.yourBloodType ?? '—');

    _partnerBloodCtrl = TextEditingController(text: license.partnerBloodType ?? '—');

    _yourEyeColorCtrl = TextEditingController(text: license.yourEyeColor ?? '—');

    _partnerEyeColorCtrl = TextEditingController(
      text: license.partnerEyeColor ?? '—',
    );

    _yourConditionsCtrl = TextEditingController(text: license.yourConditions ?? 'Madly in Love');

    _partnerConditionsCtrl = TextEditingController(
      text: license.partnerConditions ?? 'Madly in Love',
    );

    _yourGender = license.yourGender ?? 'Male';

    _partnerGender = license.partnerGender ?? 'Female';

    _yourBirthdate = license.yourBirthdate;

    _partnerBirthdate = license.partnerBirthdate;

    _yourDateIssued = license.yourDateIssued;

    _partnerDateIssued = license.partnerDateIssued;

    _yourSignatureStr = license.yourSignature ?? '';

    _partnerSignatureStr = license.partnerSignature ?? '';
  }

  @override
  void dispose() {
    _yourNameCtrl.dispose();

    _partnerNameCtrl.dispose();

    _yourPhoneCtrl.dispose();

    _partnerPhoneCtrl.dispose();

    _yourAddressCtrl.dispose();

    _partnerAddressCtrl.dispose();

    _yourNationalityCtrl.dispose();

    _partnerNationalityCtrl.dispose();

    _yourWeightCtrl.dispose();

    _partnerWeightCtrl.dispose();

    _yourHeightCtrl.dispose();

    _partnerHeightCtrl.dispose();

    _yourBloodCtrl.dispose();

    _partnerBloodCtrl.dispose();

    _yourEyeColorCtrl.dispose();

    _partnerEyeColorCtrl.dispose();

    _yourConditionsCtrl.dispose();

    _partnerConditionsCtrl.dispose();

    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isYou) async {
    final initialDate =
        (isYou ? _yourBirthdate : _partnerBirthdate) ?? DateTime(2000, 1, 1);

    final picked = await showDatePicker(
      context: context,

      initialDate: initialDate,

      firstDate: DateTime(1900),

      lastDate: DateTime.now(),

      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: widget.theme.accentColor,

              brightness: widget.theme.isDark
                  ? Brightness.dark
                  : Brightness.light,
            ),
          ),

          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isYou) {
          _yourBirthdate = picked;
        } else {
          _partnerBirthdate = picked;
        }
      });
    }
  }

  Future<void> _selectIssuedDate(BuildContext context, bool isYou) async {
    final initialDate =
        (isYou ? _yourDateIssued : _partnerDateIssued) ??
        widget.rp.startDate ??
        DateTime.now();

    final picked = await showDatePicker(
      context: context,

      initialDate: initialDate,

      firstDate: DateTime(1900),

      lastDate: DateTime.now(),

      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: widget.theme.accentColor,

              brightness: widget.theme.isDark
                  ? Brightness.dark
                  : Brightness.light,
            ),
          ),

          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isYou) {
          _yourDateIssued = picked;
        } else {
          _partnerDateIssued = picked;
        }
      });
    }
  }

  void _save() {
    // Split across the two controllers that used to be one updateLicense
    // call: yourName is ProfileController's field (untouched by this
    // extraction), the rest are LicenseController's.
    widget.rp.setYourName(_yourNameCtrl.text.trim());
    ref.read(licenseControllerProvider.notifier).updateFields(
      yourGender: _yourGender,
      yourPhone: _yourPhoneCtrl.text.trim(),
      yourBirthdate: _yourBirthdate,
      yourAddress: _yourAddressCtrl.text.trim(),
      yourNationality: _yourNationalityCtrl.text.trim(),
      yourWeight: _yourWeightCtrl.text.trim(),
      yourHeight: _yourHeightCtrl.text.trim(),
      yourBloodType: _yourBloodCtrl.text.trim(),
      yourEyeColor: _yourEyeColorCtrl.text.trim(),
      yourConditions: _yourConditionsCtrl.text.trim(),
      yourDateIssued: _yourDateIssued,
      yourSignature: _yourSignatureStr.isNotEmpty ? _yourSignatureStr : null,
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,

      decoration: BoxDecoration(
        color: widget.theme.isDark
            ? const Color(0xFF10122B)
            : const Color(0xFFFFF0F5),

        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),

      child: Column(
        children: [
          const SizedBox(height: 12),

          Container(
            width: 40,

            height: 4,

            decoration: BoxDecoration(
              color: widget.theme.textColor.withValues(alpha: 0.2),

              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const SizedBox(height: 16),

          Text(
            'Edit ID Card Info',

            style: AppTypography.heading(fontSize: 22, fontWeight: FontWeight.bold, color: widget.theme.textColor),
          ),

          const SizedBox(height: 10),

          Expanded(
            child: _buildForm(isYou: true),
          ),

          Padding(
            padding: const EdgeInsets.all(24),

            child: SizedBox(
              width: double.infinity,

              height: 52,

              child: ElevatedButton(
                onPressed: _save,

                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.theme.accentColor,

                  foregroundColor: Colors.white,

                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),

                child: Text(
                  'Save Changes',

                  style: AppTypography.body(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm({required bool isYou}) {
    return PersonLicenseForm(
      theme: widget.theme,
      nameCtrl: isYou ? _yourNameCtrl : _partnerNameCtrl,
      phoneCtrl: isYou ? _yourPhoneCtrl : _partnerPhoneCtrl,
      addressCtrl: isYou ? _yourAddressCtrl : _partnerAddressCtrl,
      nationalityCtrl: isYou ? _yourNationalityCtrl : _partnerNationalityCtrl,
      weightCtrl: isYou ? _yourWeightCtrl : _partnerWeightCtrl,
      heightCtrl: isYou ? _yourHeightCtrl : _partnerHeightCtrl,
      bloodCtrl: isYou ? _yourBloodCtrl : _partnerBloodCtrl,
      eyeCtrl: isYou ? _yourEyeColorCtrl : _partnerEyeColorCtrl,
      conditionsCtrl: isYou ? _yourConditionsCtrl : _partnerConditionsCtrl,
      gender: isYou ? _yourGender : _partnerGender,
      onGenderChanged: (val) {
        setState(() {
          if (isYou) {
            _yourGender = val;
          } else {
            _partnerGender = val;
          }
        });
      },
      birthdate: isYou ? _yourBirthdate : _partnerBirthdate,
      onBirthdateTap: () => _selectDate(context, isYou),
      dateIssued: isYou ? _yourDateIssued : _partnerDateIssued,
      onDateIssuedTap: () => _selectIssuedDate(context, isYou),
      signatureStr: isYou ? _yourSignatureStr : _partnerSignatureStr,
      onSignatureTap: () async {
        final strokes = SignatureCodec.decode(
          isYou ? _yourSignatureStr : _partnerSignatureStr,
        );

        // See _buildSignatureBox's onTap above for why this stays a
        // plain Navigator.push.
        final result = await Navigator.push<List<List<Offset>>>(
          context,
          MaterialPageRoute(
            builder: (ctx) => SignatureDrawingDialog(
              initialStrokes: strokes,
              title: isYou ? 'Your Signature' : "Partner's Signature",
              theme: widget.theme,
            ),
          ),
        );

        if (result != null) {
          setState(() {
            final serialized = SignatureCodec.encode(result);
            if (isYou) {
              _yourSignatureStr = serialized;
            } else {
              _partnerSignatureStr = serialized;
            }
          });
        }
      },
      onSignatureClear: () {
        setState(() {
          if (isYou) {
            _yourSignatureStr = '';
          } else {
            _partnerSignatureStr = '';
          }
        });
      },
    );
  }
}
