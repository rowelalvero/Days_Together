import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ConsumerState, ConsumerStatefulWidget;
import 'package:provider/provider.dart';

import 'package:days_together/features/relationship/data/signature_codec.dart';
import 'package:days_together/features/relationship/license_controller.dart';
import 'package:days_together/features/relationship/license_details.dart';
import 'package:days_together/features/relationship/presentation/license/cards/flippable_license_card.dart';
import 'package:days_together/features/relationship/presentation/license/control_bar.dart';
import 'package:days_together/features/relationship/presentation/license/creation_license_form.dart';
import 'package:days_together/features/relationship/presentation/license/edit/edit_license_sheet.dart';
import 'package:days_together/features/relationship/presentation/license/enlarged_license_dialog.dart';
import 'package:days_together/features/relationship/presentation/license/export/export_studio_sheet.dart';
import 'package:days_together/features/relationship/presentation/license/first_time_welcome_screen.dart';
import 'package:days_together/features/relationship/presentation/license/flippable_license_preview.dart';
import 'package:days_together/features/relationship/presentation/license/license_loading_screen.dart';
import 'package:days_together/features/relationship/presentation/license/license_selector.dart';
import 'package:days_together/features/relationship/presentation/license/waiting_for_partner_screen.dart';
import 'package:days_together/features/relationship/presentation/license/signature/signature_drawing_dialog.dart';
import 'package:days_together/providers/couple_session.dart';
import 'package:days_together/features/theme/theme_controller.dart';
import 'package:days_together/services/permission_service.dart';
import 'package:days_together/shared/glass_container.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/themes/theme_manager.dart';

import 'package:image_picker/image_picker.dart';

class RelationshipLicenseScreen extends ConsumerStatefulWidget {
  const RelationshipLicenseScreen({super.key});

  @override
  ConsumerState<RelationshipLicenseScreen> createState() =>
      _RelationshipLicenseScreenState();
}

class _RelationshipLicenseScreenState extends ConsumerState<RelationshipLicenseScreen> {
  final GlobalKey _licenseKey = GlobalKey();

  bool _isYourLicense =
      true; // Selector between your license and partner's license (in single mode)

  bool _showBoth = false; // Display mode selector (single vs both)

  // Keys to trigger flips programmatically from the outer button if needed

  final GlobalKey<FlippableLicenseCardState> _myCardKey = GlobalKey();

  final GlobalKey<FlippableLicenseCardState> _partnerCardKey = GlobalKey();

  // Onboarding / First-time creation state
  bool _isCreating = false;
  bool _isLoading = false;
  int _loadingStep = 0;
  Timer? _loadingTimer;

  final List<String> _loadingMessages = [
    'Initializing Love Registry Database...',
    'Filing relationship credentials...',
    'Engraving digital gold seal...',
    'Generating QR verification modules...',
    'License Issued Successfully! ❤️'
  ];

  // Onboarding controllers
  final _createYourNameCtrl = TextEditingController();
  final _createPartnerNameCtrl = TextEditingController();
  final _createYourPhoneCtrl = TextEditingController();
  final _createPartnerPhoneCtrl = TextEditingController();
  final _createYourAddressCtrl = TextEditingController();
  final _createPartnerAddressCtrl = TextEditingController();
  final _createYourNationalityCtrl = TextEditingController(text: 'Love Land');
  final _createPartnerNationalityCtrl = TextEditingController(text: 'Love Land');
  final _createYourWeightCtrl = TextEditingController(text: '—');
  final _createPartnerWeightCtrl = TextEditingController(text: '—');
  final _createYourHeightCtrl = TextEditingController(text: '—');
  final _createPartnerHeightCtrl = TextEditingController(text: '—');
  final _createYourBloodCtrl = TextEditingController(text: '—');
  final _createPartnerBloodCtrl = TextEditingController(text: '—');
  final _createYourEyeColorCtrl = TextEditingController(text: '—');
  final _createPartnerEyeColorCtrl = TextEditingController(text: '—');
  final _createYourConditionsCtrl = TextEditingController(text: 'Madly in Love');
  final _createPartnerConditionsCtrl = TextEditingController(text: 'Madly in Love');

  String _createYourGender = 'Male';
  String _createPartnerGender = 'Female';
  DateTime? _createYourBirthdate;
  DateTime? _createPartnerBirthdate;
  String _createYourSignatureStr = '';
  String _createPartnerSignatureStr = '';

  void _flipVisibleCards() {
    if (_showBoth) {
      _myCardKey.currentState?.flipCard();

      _partnerCardKey.currentState?.flipCard();
    } else {
      if (_isYourLicense) {
        _myCardKey.currentState?.flipCard();
      } else {
        _partnerCardKey.currentState?.flipCard();
      }
    }
  }

  Future<void> _pickAvatar(CoupleSession rp, bool isYou) async {
    final hasPermission = await PermissionService().requestPhotosPermission(context);
    if (!hasPermission) return;

    final picker = ImagePicker();

    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
    );

    if (pickedFile != null) {
      try {
        if (isYou) {
          await rp.setAvatars(yourPath: pickedFile.path);
        } else {
          await rp.setAvatars(partnerPath: pickedFile.path);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Avatar updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update avatar: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }


  void _showEnlargedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => EnlargedLicenseDialog(isYourLicense: _isYourLicense),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rp = context.watch<CoupleSession>();
    final license = ref.watch(licenseControllerProvider).value ?? const LicenseDetails();
    final partnerJoined = rp.partnerId != null;

    if (!partnerJoined) {
      _showBoth = false;
      _isYourLicense = true;
    }

    final themeState = ref.watch(themeControllerProvider);

    final theme = themeState.currentLoveTheme;

    final isFirstTime = license.yourDateIssued == null;

    if (isFirstTime) {
      if (_isLoading) {
        return LicenseLoadingScreen(
          theme: theme,
          loadingMessage: _loadingMessages[_loadingStep],
          loadingStep: _loadingStep,
        );
      }
      if (_isCreating) {
        return _buildCreationForm(theme, rp);
      }
      return FirstTimeLicenseWelcomeScreen(
        theme: theme,
        onCreatePressed: () => setState(() => _isCreating = true),
      );
    }

    final partnerSetupCompleted = license.partnerDateIssued != null;

    if (!partnerJoined || !partnerSetupCompleted) {
      return WaitingForPartnerScreen(theme: theme, partnerJoined: partnerJoined);
    }

    return Scaffold(
      extendBodyBehindAppBar: true,

      appBar: AppBar(
        title: Text(
          'Relationship License',

          style: AppTypography.cormorant(fontWeight: FontWeight.bold, color: theme.textColor),
        ),

        backgroundColor: Colors.transparent,

        elevation: 0,

        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),

      body: Container(
        width: double.infinity,

        height: double.infinity,

        decoration: BoxDecoration(gradient: themeState.currentGradient),

        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),

            child: Column(
              children: [
                const SizedBox(height: 10),

                // Control Bar (Orientation + Display toggles)
                if (partnerJoined) ...[
                  ControlBar(
                    theme: theme,
                    showBoth: _showBoth,
                    onShowBothChanged: (val) => setState(() => _showBoth = val),
                  ),
                  const SizedBox(height: 16),
                ],

                // sliding selector if single mode is active
                if (partnerJoined && !_showBoth) ...[
                  LicenseSelector(
                    theme: theme,
                    rp: rp,
                    isYourLicense: _isYourLicense,
                    onChanged: (val) => setState(() => _isYourLicense = val),
                  ),
                  const SizedBox(height: 16),
                ],

                // Configure details button card
                GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,

                      isScrollControlled: true,

                      backgroundColor: Colors.transparent,

                      builder: (ctx) => EditLicenseSheet(rp: rp, theme: theme),
                    );
                  },

                  child: GlassContainer(
                    borderRadius: 16,

                    opacity: 0.06,

                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),

                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,

                      children: [
                        Icon(
                          Icons.edit_note_rounded,
                          color: theme.accentColor,
                          size: 20,
                        ),

                        const SizedBox(width: 10),

                        Text(
                          'Configure License Details',

                          style: AppTypography.body(fontSize: 14, color: theme.textColor.withValues(alpha: 0.8), fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Card Canvas to capture
                RepaintBoundary(
                  key: _licenseKey,
                  child: Container(
                    child: _showBoth
                        ? Column(
                            children: [
                              FlippableLicensePreview(
                                cardKey: _myCardKey,
                                isYourLicense: true,
                                rp: rp,
                                onAvatarTap: () => _pickAvatar(rp, true),
                              ),
                              const SizedBox(height: 20),
                              FlippableLicensePreview(
                                cardKey: _partnerCardKey,
                                isYourLicense: false,
                                rp: rp,
                                onAvatarTap: () => _pickAvatar(rp, false),
                              ),
                            ],
                          )
                        : _isYourLicense
                        ? FlippableLicensePreview(
                            cardKey: _myCardKey,
                            isYourLicense: true,
                            rp: rp,
                            onAvatarTap: () => _pickAvatar(rp, true),
                          )
                        : FlippableLicensePreview(
                            cardKey: _partnerCardKey,
                            isYourLicense: false,
                            rp: rp,
                            onAvatarTap: () => _pickAvatar(rp, false),
                          ),
                  ),
                ),

                const SizedBox(height: 24),

                // Helper text
                Text(
                  '💡 Tap any license card directly to flip it!',

                  style: AppTypography.body(fontSize: 12, fontWeight: FontWeight.w500, color: theme.textColor.withValues(alpha: 0.5)),
                ),

                const SizedBox(height: 16),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _flipVisibleCards,

                        icon: Icon(
                          Icons.flip_rounded,

                          color: theme.accentColor,
                        ),

                        label: Text(
                          'Flip Cards',

                          style: AppTypography.body(fontWeight: FontWeight.w700, color: theme.textColor),
                        ),

                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),

                          side: BorderSide(
                            color: theme.textColor.withValues(alpha: 0.15),
                          ),

                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _showEnlargedDialog,

                        icon: Icon(
                          Icons.zoom_in_rounded,

                          color: theme.accentColor,
                        ),

                        label: Text(
                          'Enlarge ID',

                          style: AppTypography.body(fontWeight: FontWeight.w700, color: theme.textColor),
                        ),

                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),

                          side: BorderSide(
                            color: theme.textColor.withValues(alpha: 0.15),
                          ),

                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (ctx) => ExportStudioBottomSheet(
                          rp: rp,
                          theme: theme,
                          showBoth: _showBoth,
                          isYourLicense: _isYourLicense,
                          myShowingFront:
                              _myCardKey.currentState?.showingFront ?? true,
                          partnerShowingFront:
                              _partnerCardKey.currentState?.showingFront ??
                              true,
                          mainLicenseKey: _licenseKey,
                        ),
                      );
                    },

                    icon: const Icon(Icons.share_rounded),

                    label: Text(
                      'Share License',

                      style: AppTypography.body(fontWeight: FontWeight.bold, fontSize: 15),
                    ),

                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),

                      backgroundColor: theme.accentColor,

                      foregroundColor: Colors.white,

                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),

                      elevation: 6,

                      shadowColor: theme.accentColor.withValues(alpha: 0.3),
                    ),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    _createYourNameCtrl.dispose();
    _createPartnerNameCtrl.dispose();
    _createYourPhoneCtrl.dispose();
    _createPartnerPhoneCtrl.dispose();
    _createYourAddressCtrl.dispose();
    _createPartnerAddressCtrl.dispose();
    _createYourNationalityCtrl.dispose();
    _createPartnerNationalityCtrl.dispose();
    _createYourWeightCtrl.dispose();
    _createPartnerWeightCtrl.dispose();
    _createYourHeightCtrl.dispose();
    _createPartnerHeightCtrl.dispose();
    _createYourBloodCtrl.dispose();
    _createPartnerBloodCtrl.dispose();
    _createYourEyeColorCtrl.dispose();
    _createPartnerEyeColorCtrl.dispose();
    _createYourConditionsCtrl.dispose();
    _createPartnerConditionsCtrl.dispose();
    super.dispose();
  }

  void _startLoadingAnimation(CoupleSession rp) {
    setState(() {
      _isLoading = true;
      _loadingStep = 0;
    });

    _loadingTimer = Timer.periodic(const Duration(milliseconds: 700), (timer) {
      if (_loadingStep < _loadingMessages.length - 1) {
        setState(() {
          _loadingStep++;
        });
      } else {
        timer.cancel();
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            _saveFirstTimeDetails(rp);
          }
        });
      }
    });
  }

  void _saveFirstTimeDetails(CoupleSession rp) {
    final now = DateTime.now();
    // Split across the two controllers that used to be one updateLicense
    // call: yourName is ProfileController's field (untouched by this
    // extraction), the rest are LicenseController's.
    rp.setYourName(_createYourNameCtrl.text.trim());
    ref.read(licenseControllerProvider.notifier).updateFields(
      yourGender: _createYourGender,
      yourPhone: _createYourPhoneCtrl.text.trim(),
      yourBirthdate: _createYourBirthdate,
      yourAddress: _createYourAddressCtrl.text.trim(),
      yourNationality: _createYourNationalityCtrl.text.trim(),
      yourWeight: _createYourWeightCtrl.text.trim(),
      yourHeight: _createYourHeightCtrl.text.trim(),
      yourBloodType: _createYourBloodCtrl.text.trim(),
      yourEyeColor: _createYourEyeColorCtrl.text.trim(),
      yourConditions: _createYourConditionsCtrl.text.trim(),
      yourDateIssued: now,
      yourSignature: _createYourSignatureStr.isNotEmpty ? _createYourSignatureStr : null,
    );

    setState(() {
      _isLoading = false;
      _isCreating = false;
    });
  }

  Widget _buildCreationForm(LoveStoryTheme theme, CoupleSession rp) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'License Application',
          style: AppTypography.heading(fontWeight: FontWeight.bold, color: theme.textColor),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.textColor),
          onPressed: () {
            setState(() {
              _isCreating = false;
            });
          },
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: ref.watch(themeControllerProvider).currentGradient),
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
                        children: _buildFormFields(isYou: true, theme: theme),
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
                    onPressed: () {
                      if (_createYourNameCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter Your Name first! ✍️'),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                        return;
                      }
                      _startLoadingAnimation(rp);
                    },
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
                      style: AppTypography.body(fontSize: 16, fontWeight: FontWeight.bold),
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

  List<Widget> _buildFormFields({required bool isYou, required LoveStoryTheme theme}) {
    return [
      CreationLicenseForm(
        isYou: isYou,
        theme: theme,
        nameCtrl: isYou ? _createYourNameCtrl : _createPartnerNameCtrl,
        phoneCtrl: isYou ? _createYourPhoneCtrl : _createPartnerPhoneCtrl,
        addressCtrl: isYou ? _createYourAddressCtrl : _createPartnerAddressCtrl,
        nationalityCtrl: isYou ? _createYourNationalityCtrl : _createPartnerNationalityCtrl,
        weightCtrl: isYou ? _createYourWeightCtrl : _createPartnerWeightCtrl,
        heightCtrl: isYou ? _createYourHeightCtrl : _createPartnerHeightCtrl,
        bloodCtrl: isYou ? _createYourBloodCtrl : _createPartnerBloodCtrl,
        eyeCtrl: isYou ? _createYourEyeColorCtrl : _createPartnerEyeColorCtrl,
        conditionsCtrl: isYou ? _createYourConditionsCtrl : _createPartnerConditionsCtrl,
        gender: isYou ? _createYourGender : _createPartnerGender,
        onGenderChanged: (val) {
          setState(() {
            if (isYou) {
              _createYourGender = val;
            } else {
              _createPartnerGender = val;
            }
          });
        },
        birthdate: isYou ? _createYourBirthdate : _createPartnerBirthdate,
        onBirthdateTap: () => _selectCreateDate(context, isYou),
        signatureStr: isYou ? _createYourSignatureStr : _createPartnerSignatureStr,
        onSignatureTap: () async {
          final signatureStr = isYou ? _createYourSignatureStr : _createPartnerSignatureStr;
          final strokes = SignatureCodec.decode(signatureStr.isNotEmpty ? signatureStr : null);
          // SignatureDrawingDialog stays a plain Navigator.push (both sites
          // in this file): it's a dialog with a typed return value, not a
          // navigational destination -- ADR-007's scope only covers "distinct
          // screens", and modeling a typed-result dialog as a go_router route
          // would be exactly the over-engineering ADR-007's rejected option 2
          // warns against.
          final result = await Navigator.push<List<List<Offset>>>(
            context,
            MaterialPageRoute(
              builder: (ctx) => SignatureDrawingDialog(
                initialStrokes: strokes,
                title: isYou ? 'Your Signature' : "Partner's Signature",
                theme: theme,
              ),
            ),
          );
          if (result != null) {
            setState(() {
              final serialized = SignatureCodec.encode(result);
              if (isYou) {
                _createYourSignatureStr = serialized;
              } else {
                _createPartnerSignatureStr = serialized;
              }
            });
          }
        },
        onSignatureClear: () {
          setState(() {
            if (isYou) {
              _createYourSignatureStr = '';
            } else {
              _createPartnerSignatureStr = '';
            }
          });
        },
      ),
    ];
  }

  Future<void> _selectCreateDate(BuildContext context, bool isYou) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 20)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        final theme = ref.read(themeControllerProvider).currentLoveTheme;
        final isDark = theme.isDark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? ColorScheme.dark(
                    primary: theme.accentColor,
                    onPrimary: Colors.white,
                    surface: theme.secondaryColor,
                    onSurface: theme.textColor,
                  )
                : ColorScheme.light(
                    primary: theme.accentColor,
                    onPrimary: Colors.white,
                    surface: theme.primaryColor,
                    onSurface: theme.textColor,
                  ),
            dialogTheme: DialogThemeData(backgroundColor: isDark ? theme.secondaryColor : theme.primaryColor),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isYou) {
          _createYourBirthdate = picked;
        } else {
          _createPartnerBirthdate = picked;
        }
      });
    }
  }

}
