import 'dart:io';
import 'dart:async';

import 'dart:math' as math;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:flutter/rendering.dart';

import 'package:provider/provider.dart';

import 'package:days_together/themes/app_typography.dart';

import 'package:intl/intl.dart';

import 'package:path_provider/path_provider.dart';

import 'package:share_plus/share_plus.dart';

import 'package:qr_flutter/qr_flutter.dart';

import 'package:image_picker/image_picker.dart';

import 'package:gal/gal.dart';

import 'package:days_together/providers/relationship_provider.dart';
import 'package:days_together/providers/theme_provider.dart';
import 'package:days_together/services/permission_service.dart';

import 'package:days_together/widgets/glass_container.dart';

class RelationshipLicenseScreen extends StatefulWidget {
  const RelationshipLicenseScreen({super.key});

  @override
  State<RelationshipLicenseScreen> createState() =>
      _RelationshipLicenseScreenState();
}

class _RelationshipLicenseScreenState extends State<RelationshipLicenseScreen> {
  final GlobalKey _licenseKey = GlobalKey();

  bool _isYourLicense =
      true; // Selector between your license and partner's license (in single mode)

  bool _showBoth = false; // Display mode selector (single vs both)

  // Keys to trigger flips programmatically from the outer button if needed

  final GlobalKey<_FlippableLicenseCardState> _myCardKey = GlobalKey();

  final GlobalKey<_FlippableLicenseCardState> _partnerCardKey = GlobalKey();

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
      _myCardKey.currentState?._flipCard();

      _partnerCardKey.currentState?._flipCard();
    } else {
      if (_isYourLicense) {
        _myCardKey.currentState?._flipCard();
      } else {
        _partnerCardKey.currentState?._flipCard();
      }
    }
  }

  Future<void> _pickAvatar(RelationshipProvider rp, bool isYou) async {
    final hasPermission = await PermissionService().requestPhotosPermission(context);
    if (!hasPermission) return;

    final picker = ImagePicker();

    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
    );

    if (pickedFile != null) {
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
    }
  }

  int? _calculateAge(DateTime? birthdate) {
    if (birthdate == null) return null;

    final today = DateTime.now();

    int age = today.year - birthdate.year;

    if (today.month < birthdate.month ||
        (today.month == birthdate.month && today.day < birthdate.day)) {
      age--;
    }

    return age;
  }

  void _showEnlargedDialog() {
    final rp = context.read<RelationshipProvider>();
    final myName = rp.yourName ?? 'You';
    final partnerName = rp.partnerName ?? 'Partner';
    final myPhone = rp.yourPhone?.isNotEmpty == true
        ? rp.yourPhone!
        : 'Not provided';
    final partnerPhone = rp.partnerPhone?.isNotEmpty == true
        ? rp.partnerPhone!
        : 'Not provided';

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              InteractiveViewer(
                minScale: 1.0,
                maxScale: 3.5,
                child: SizedBox(
                  width: double.infinity,
                  child: AspectRatio(
                    aspectRatio: 85.60 / 53.98,
                    child: _isYourLicense
                        ? FlippableLicenseCard(
                            holderName: myName,
                            holderGender: rp.yourGender,
                            holderAvatar: rp.yourAvatarPath,
                            holderBirthdate: rp.yourBirthdate,
                            holderAddress: rp.yourAddress,
                            holderNationality: rp.yourNationality,
                            holderWeight: rp.yourWeight,
                            holderHeight: rp.yourHeight,
                            holderBloodType: rp.yourBloodType,
                            holderEyeColor: rp.yourEyeColor,
                            holderConditions: rp.yourConditions,
                            holderDateIssued: rp.yourDateIssued,
                            holderSignature: rp.yourSignature,
                            startDate: rp.startDate,
                            calculatedAge: _calculateAge(rp.yourBirthdate),
                            isYourLicense: true,
                            onAvatarTap: () {},
                            emergencyName: partnerName,
                            emergencyPhone: partnerPhone,
                            emergencyAddress: rp.partnerAddress,
                          )
                        : FlippableLicenseCard(
                            holderName: partnerName,
                            holderGender: rp.partnerGender,
                            holderAvatar: rp.partnerAvatarPath,
                            holderBirthdate: rp.partnerBirthdate,
                            holderAddress: rp.partnerAddress,
                            holderNationality: rp.partnerNationality,
                            holderWeight: rp.partnerWeight,
                            holderHeight: rp.partnerHeight,
                            holderBloodType: rp.partnerBloodType,
                            holderEyeColor: rp.partnerEyeColor,
                            holderConditions: rp.partnerConditions,
                            holderDateIssued: rp.partnerDateIssued,
                            holderSignature: rp.partnerSignature,
                            startDate: rp.startDate,
                            calculatedAge: _calculateAge(rp.partnerBirthdate),
                            isYourLicense: false,
                            onAvatarTap: () {},
                            emergencyName: myName,
                            emergencyPhone: myPhone,
                            emergencyAddress: rp.yourAddress,
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '💡 Pinch to zoom • Tap card to flip',
                style: AppTypography.body(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white70),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final rp = context.watch<RelationshipProvider>();
    final partnerJoined = rp.partnerId != null;

    if (!partnerJoined) {
      _showBoth = false;
      _isYourLicense = true;
    }

    final themeProvider = context.watch<ThemeProvider>();

    final theme = themeProvider.currentLoveTheme;

    final isFirstTime = rp.yourDateIssued == null;

    if (isFirstTime) {
      if (_isLoading) {
        return _buildLoadingScreen(theme);
      }
      if (_isCreating) {
        return _buildCreationForm(theme, rp);
      }
      return _buildFirstTimeWelcomeScreen(theme);
    }

    final partnerSetupCompleted = rp.partnerDateIssued != null;

    if (!partnerJoined || !partnerSetupCompleted) {
      return _buildWaitingForPartnerScreen(theme, rp);
    }

    // Resolve values for both cards

    final myName = rp.yourName ?? 'You';

    final partnerName = rp.partnerName ?? 'Partner';

    final myPhone = rp.yourPhone?.isNotEmpty == true
        ? rp.yourPhone!
        : 'Not provided';

    final partnerPhone = rp.partnerPhone?.isNotEmpty == true
        ? rp.partnerPhone!
        : 'Not provided';

    return Scaffold(
      extendBodyBehindAppBar: true,

      appBar: AppBar(
        title: Text(
          'Relationship License',

          style: AppTypography.sectionHeader(fontWeight: FontWeight.bold, color: theme.textColor),
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
            padding: const EdgeInsets.all(20),

            child: Column(
              children: [
                const SizedBox(height: 10),

                // Control Bar (Orientation + Display toggles)
                if (partnerJoined) ...[
                  _buildControlBar(theme),
                  const SizedBox(height: 16),
                ],

                // sliding selector if single mode is active
                if (partnerJoined && !_showBoth) ...[
                  _buildLicenseSelector(theme, rp),
                  const SizedBox(height: 16),
                ],

                // Configure details button card
                GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,

                      isScrollControlled: true,

                      backgroundColor: Colors.transparent,

                      builder: (ctx) => _EditLicenseSheet(rp: rp, theme: theme),
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
                              FlippableLicenseCard(
                                key: _myCardKey,

                                holderName: myName,

                                holderGender: rp.yourGender,

                                holderAvatar: rp.yourAvatarPath,

                                holderBirthdate: rp.yourBirthdate,

                                holderAddress: rp.yourAddress,

                                holderNationality: rp.yourNationality,

                                holderWeight: rp.yourWeight,

                                holderHeight: rp.yourHeight,

                                holderBloodType: rp.yourBloodType,

                                holderEyeColor: rp.yourEyeColor,

                                holderConditions: rp.yourConditions,

                                holderDateIssued: rp.yourDateIssued,

                                holderSignature: rp.yourSignature,

                                startDate: rp.startDate,

                                calculatedAge: _calculateAge(rp.yourBirthdate),

                                isYourLicense: true,

                                onAvatarTap: () => _pickAvatar(rp, true),

                                emergencyName: partnerName,

                                emergencyPhone: partnerPhone,

                                emergencyAddress: rp.partnerAddress,
                              ),

                              const SizedBox(height: 20),

                              FlippableLicenseCard(
                                key: _partnerCardKey,

                                holderName: partnerName,

                                holderGender: rp.partnerGender,

                                holderAvatar: rp.partnerAvatarPath,

                                holderBirthdate: rp.partnerBirthdate,

                                holderAddress: rp.partnerAddress,

                                holderNationality: rp.partnerNationality,

                                holderWeight: rp.partnerWeight,

                                holderHeight: rp.partnerHeight,

                                holderBloodType: rp.partnerBloodType,

                                holderEyeColor: rp.partnerEyeColor,

                                holderConditions: rp.partnerConditions,

                                holderDateIssued: rp.partnerDateIssued,

                                holderSignature: rp.partnerSignature,

                                startDate: rp.startDate,

                                calculatedAge: _calculateAge(
                                  rp.partnerBirthdate,
                                ),

                                isYourLicense: false,

                                onAvatarTap: () => _pickAvatar(rp, false),

                                emergencyName: myName,

                                emergencyPhone: myPhone,

                                emergencyAddress: rp.yourAddress,
                              ),
                            ],
                          )
                        : _isYourLicense
                        ? FlippableLicenseCard(
                            key: _myCardKey,

                            holderName: myName,

                            holderGender: rp.yourGender,

                            holderAvatar: rp.yourAvatarPath,

                            holderBirthdate: rp.yourBirthdate,

                            holderAddress: rp.yourAddress,

                            holderNationality: rp.yourNationality,

                            holderWeight: rp.yourWeight,

                            holderHeight: rp.yourHeight,

                            holderBloodType: rp.yourBloodType,

                            holderEyeColor: rp.yourEyeColor,

                            holderConditions: rp.yourConditions,

                            holderDateIssued: rp.yourDateIssued,

                            holderSignature: rp.yourSignature,

                            startDate: rp.startDate,

                            calculatedAge: _calculateAge(rp.yourBirthdate),

                            isYourLicense: true,

                            onAvatarTap: () => _pickAvatar(rp, true),

                            emergencyName: partnerName,

                            emergencyPhone: partnerPhone,

                            emergencyAddress: rp.partnerAddress,
                          )
                        : FlippableLicenseCard(
                            key: _partnerCardKey,

                            holderName: partnerName,

                            holderGender: rp.partnerGender,

                            holderAvatar: rp.partnerAvatarPath,

                            holderBirthdate: rp.partnerBirthdate,

                            holderAddress: rp.partnerAddress,

                            holderNationality: rp.partnerNationality,

                            holderWeight: rp.partnerWeight,

                            holderHeight: rp.partnerHeight,

                            holderBloodType: rp.partnerBloodType,

                            holderEyeColor: rp.partnerEyeColor,

                            holderConditions: rp.partnerConditions,

                            holderDateIssued: rp.partnerDateIssued,

                            holderSignature: rp.partnerSignature,

                            startDate: rp.startDate,

                            calculatedAge: _calculateAge(rp.partnerBirthdate),

                            isYourLicense: false,

                            onAvatarTap: () => _pickAvatar(rp, false),

                            emergencyName: myName,

                            emergencyPhone: myPhone,

                            emergencyAddress: rp.yourAddress,
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
                        builder: (ctx) => _ExportStudioBottomSheet(
                          rp: rp,
                          theme: theme,
                          showBoth: _showBoth,
                          isYourLicense: _isYourLicense,
                          myShowingFront:
                              _myCardKey.currentState?._showingFront ?? true,
                          partnerShowingFront:
                              _partnerCardKey.currentState?._showingFront ??
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

  Widget _buildControlBar(dynamic theme) {
    return GlassContainer(
      borderRadius: 20,

      opacity: 0.05,

      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),

      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,

        children: [
          _miniToggleButton(
            icon: Icons.person_rounded,

            isActive: !_showBoth,

            theme: theme,

            onTap: () => setState(() => _showBoth = false),
          ),

          const SizedBox(width: 12),

          _miniToggleButton(
            icon: Icons.people_rounded,

            isActive: _showBoth,

            theme: theme,

            onTap: () => setState(() => _showBoth = true),
          ),
        ],
      ),
    );
  }

  Widget _miniToggleButton({
    required IconData icon,

    required bool isActive,

    required dynamic theme,

    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,

      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),

        padding: const EdgeInsets.all(8),

        decoration: BoxDecoration(
          color: isActive
              ? theme.accentColor
              : theme.textColor.withValues(alpha: 0.05),

          borderRadius: BorderRadius.circular(12),
        ),

        child: Icon(
          icon,

          color: isActive
              ? Colors.white
              : theme.textColor.withValues(alpha: 0.6),

          size: 20,
        ),
      ),
    );
  }

  Widget _buildLicenseSelector(dynamic theme, RelationshipProvider rp) {
    final myName = rp.yourName?.isNotEmpty == true ? rp.yourName! : "My";

    final partnerName = rp.partnerName?.isNotEmpty == true
        ? rp.partnerName!
        : "Partner";

    return Container(
      padding: const EdgeInsets.all(4),

      decoration: BoxDecoration(
        color: theme.textColor.withValues(alpha: 0.05),

        borderRadius: BorderRadius.circular(25),

        border: Border.all(color: theme.textColor.withValues(alpha: 0.1)),
      ),

      child: Row(
        children: [
          Expanded(
            child: _selectorTab(
              title: "$myName's License",

              isActive: _isYourLicense,

              theme: theme,

              onTap: () {
                if (!_isYourLicense) {
                  setState(() {
                    _isYourLicense = true;
                  });
                }
              },
            ),
          ),

          Expanded(
            child: _selectorTab(
              title: "$partnerName's License",

              isActive: !_isYourLicense,

              theme: theme,

              onTap: () {
                if (_isYourLicense) {
                  setState(() {
                    _isYourLicense = false;
                  });
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectorTab({
    required String title,

    required bool isActive,

    required dynamic theme,

    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,

      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),

        curve: Curves.easeInOut,

        padding: const EdgeInsets.symmetric(vertical: 12),

        decoration: BoxDecoration(
          color: isActive ? theme.accentColor : Colors.transparent,

          borderRadius: BorderRadius.circular(20),

          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: theme.accentColor.withValues(alpha: 0.3),

                    blurRadius: 8,

                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),

        child: Center(
          child: Text(
            title,

            maxLines: 1,

            overflow: TextOverflow.ellipsis,

            style: AppTypography.body(fontSize: 13, fontWeight: FontWeight.bold, color: isActive
                  ? Colors.white
                  : theme.textColor.withValues(alpha: 0.6)),
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

  void _startLoadingAnimation(RelationshipProvider rp) {
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

  void _saveFirstTimeDetails(RelationshipProvider rp) {
    final now = DateTime.now();
    rp.updateLicense(
      yourName: _createYourNameCtrl.text.trim(),
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

  Widget _buildFirstTimeWelcomeScreen(dynamic theme) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Relationship License',
          style: AppTypography.sectionHeader(fontWeight: FontWeight.bold, color: theme.textColor),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: context.watch<ThemeProvider>().currentGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 280,
                    height: 176,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.accentColor.withValues(alpha: 0.3),
                        width: 2.0,
                        style: BorderStyle.solid,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.accentColor.withValues(alpha: 0.1),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: CustomPaint(painter: _WatermarkPainter()),
                          ),
                        ),
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.favorite_rounded,
                                size: 48,
                                color: theme.accentColor.withValues(alpha: 0.8),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'OFFICIAL LOVE LICENSE',
                                style: AppTypography.body(fontSize: 12, fontWeight: FontWeight.w900, color: const Color(0xFFD4AF37)).copyWith(letterSpacing: 2),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    'No License Found',
                    style: AppTypography.sectionHeader(fontSize: 26, fontWeight: FontWeight.bold, color: theme.textColor),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Create your official Relationship License to certify your bond! Fill in your details, draw your signatures, and generate printable & shareable license cards.',
                      textAlign: TextAlign.center,
                      style: AppTypography.body(fontSize: 14, fontWeight: FontWeight.w500, color: theme.textColor.withValues(alpha: 0.6), height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _isCreating = true;
                        });
                      },
                      icon: const Icon(Icons.add_card_rounded, size: 22),
                      label: Text(
                        'Create License ID',
                        style: AppTypography.body(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.accentColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWaitingForPartnerScreen(dynamic theme, RelationshipProvider rp) {
    final partnerJoined = rp.partnerId != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Relationship License',
          style: AppTypography.sectionHeader(fontWeight: FontWeight.bold, color: theme.textColor),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: theme.textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: context.watch<ThemeProvider>().currentGradient),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: GlassContainer(
                borderRadius: 24,
                padding: const EdgeInsets.all(32),
                opacity: 0.1,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.hourglass_empty_rounded,
                        size: 48,
                        color: theme.accentColor,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      partnerJoined ? 'Waiting for Partner' : 'Waiting for Partner to Join',
                      style: AppTypography.sectionHeader(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      partnerJoined
                          ? "We are waiting for your partner to complete their license setup before details can be shared and viewed."
                          : "Please connect with your partner first. Once they join and complete their setup, your licenses will be synced and visible here.",
                      style: AppTypography.body(fontSize: 14, color: Colors.white70, height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingScreen(dynamic theme) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: context.watch<ThemeProvider>().currentGradient),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 90,
                    height: 90,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(theme.accentColor),
                      strokeWidth: 3.5,
                    ),
                  ),
                  Icon(
                    Icons.favorite_rounded,
                    color: theme.accentColor,
                    size: 38,
                  ),
                ],
              ),
              const SizedBox(height: 48),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _loadingMessages[_loadingStep],
                  key: ValueKey<int>(_loadingStep),
                  textAlign: TextAlign.center,
                  style: AppTypography.body(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textColor),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 140,
                child: LinearProgressIndicator(
                  backgroundColor: theme.textColor.withValues(alpha: 0.1),
                  color: theme.accentColor,
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreationForm(dynamic theme, RelationshipProvider rp) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'License Application',
          style: AppTypography.sectionHeader(fontWeight: FontWeight.bold, color: theme.textColor),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: theme.textColor),
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
        decoration: BoxDecoration(gradient: context.watch<ThemeProvider>().currentGradient),
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

  List<Widget> _buildFormFields({required bool isYou, required dynamic theme}) {
    final nameCtrl = isYou ? _createYourNameCtrl : _createPartnerNameCtrl;
    final phoneCtrl = isYou ? _createYourPhoneCtrl : _createPartnerPhoneCtrl;
    final addressCtrl = isYou ? _createYourAddressCtrl : _createPartnerAddressCtrl;
    final nationalityCtrl = isYou ? _createYourNationalityCtrl : _createPartnerNationalityCtrl;
    final weightCtrl = isYou ? _createYourWeightCtrl : _createPartnerWeightCtrl;
    final heightCtrl = isYou ? _createYourHeightCtrl : _createPartnerHeightCtrl;
    final bloodCtrl = isYou ? _createYourBloodCtrl : _createPartnerBloodCtrl;
    final eyeCtrl = isYou ? _createYourEyeColorCtrl : _createPartnerEyeColorCtrl;
    final conditionsCtrl = isYou ? _createYourConditionsCtrl : _createPartnerConditionsCtrl;
    final gender = isYou ? _createYourGender : _createPartnerGender;
    final birthdate = isYou ? _createYourBirthdate : _createPartnerBirthdate;

    return [
      _createFieldLabel('Full Name *', theme),
      TextField(
        controller: nameCtrl,
        style: AppTypography.body(color: theme.textColor),
        decoration: _createInputDecoration('Enter full name', theme),
      ),
      const SizedBox(height: 16),
      _createFieldLabel('Sex / Gender', theme),
      Row(
        children: [
          _createGenderOption('Male', gender, (val) {
            setState(() {
              if (isYou) {
                _createYourGender = val;
              } else {
                _createPartnerGender = val;
              }
            });
          }, theme),
          const SizedBox(width: 12),
          _createGenderOption('Female', gender, (val) {
            setState(() {
              if (isYou) {
                _createYourGender = val;
              } else {
                _createPartnerGender = val;
              }
            });
          }, theme),
        ],
      ),
      const SizedBox(height: 16),
      _createFieldLabel('Birthdate', theme),
      InkWell(
        onTap: () => _selectCreateDate(context, isYou),
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
                    ? DateFormat('MMMM dd, yyyy').format(birthdate)
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
      _createFieldLabel('Signature', theme),
      _buildSignatureBox(isYou, theme),
      const SizedBox(height: 16),
      _createFieldLabel('Nationality', theme),
      TextField(
        controller: nationalityCtrl,
        style: AppTypography.body(color: theme.textColor),
        decoration: _createInputDecoration('e.g., Love Land', theme),
      ),
      const SizedBox(height: 16),
      _createFieldLabel('Address', theme),
      TextField(
        controller: addressCtrl,
        style: AppTypography.body(color: theme.textColor),
        decoration: _createInputDecoration('Enter address details', theme),
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _createFieldLabel('Height', theme),
                TextField(
                  controller: heightCtrl,
                  style: AppTypography.body(color: theme.textColor),
                  decoration: _createInputDecoration('e.g., 5\'7"', theme),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _createFieldLabel('Weight', theme),
                TextField(
                  controller: weightCtrl,
                  style: AppTypography.body(color: theme.textColor),
                  decoration: _createInputDecoration('e.g., 65 kg', theme),
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
                _createFieldLabel('Blood Type', theme),
                TextField(
                  controller: bloodCtrl,
                  style: AppTypography.body(color: theme.textColor),
                  decoration: _createInputDecoration('e.g., O+', theme),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _createFieldLabel('Eyes Color', theme),
                TextField(
                  controller: eyeCtrl,
                  style: AppTypography.body(color: theme.textColor),
                  decoration: _createInputDecoration('e.g., Brown', theme),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      _createFieldLabel('Conditions', theme),
      TextField(
        controller: conditionsCtrl,
        style: AppTypography.body(color: theme.textColor),
        decoration: _createInputDecoration('e.g., Head over heels', theme),
      ),
      const SizedBox(height: 16),
      _createFieldLabel('Phone / Emergency Mobile', theme),
      TextField(
        controller: phoneCtrl,
        keyboardType: TextInputType.phone,
        style: AppTypography.body(color: theme.textColor),
        decoration: _createInputDecoration('Enter phone number', theme),
      ),
    ];
  }

  InputDecoration _createInputDecoration(String hint, dynamic theme) {
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

  Widget _createGenderOption(
    String value,
    String current,
    ValueChanged<String> onChanged,
    dynamic theme,
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

  Widget _createFieldLabel(String label, dynamic theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 4),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.body(fontSize: 11, fontWeight: FontWeight.bold, color: theme.textColor.withValues(alpha: 0.6)).copyWith(letterSpacing: 1),
      ),
    );
  }

  Future<void> _selectCreateDate(BuildContext context, bool isYou) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 20)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: context.read<ThemeProvider>().currentLoveTheme.accentColor,
              onPrimary: Colors.white,
              surface: const Color(0xFF1B072B),
              onSurface: Colors.white,
            ),
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

  Widget _buildSignatureBox(bool isYou, dynamic theme) {
    final signatureStr = isYou ? _createYourSignatureStr : _createPartnerSignatureStr;
    return GestureDetector(
      onTap: () async {
        final strokes = _deserializeSignature(signatureStr.isNotEmpty ? signatureStr : null);
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
            final serialized = _serializeSignature(result);
            if (isYou) {
              _createYourSignatureStr = serialized;
            } else {
              _createPartnerSignatureStr = serialized;
            }
          });
        }
      },
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
                      strokes: _deserializeSignature(signatureStr),
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
                  onPressed: () {
                    setState(() {
                      if (isYou) {
                        _createYourSignatureStr = '';
                      } else {
                        _createPartnerSignatureStr = '';
                      }
                    });
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════

// REUSABLE FLIPPABLE LICENSE CARD

// ════════════════════════════════════════

class FlippableLicenseCard extends StatefulWidget {
  final String holderName;

  final String? holderGender;

  final String? holderAvatar;

  final DateTime? holderBirthdate;

  final String? holderAddress;

  final String holderNationality;

  final String holderWeight;

  final String holderHeight;

  final String holderBloodType;

  final String holderEyeColor;

  final String holderConditions;

  final DateTime? holderDateIssued;

  final String? holderSignature;

  final DateTime? startDate;

  final int? calculatedAge;

  final bool isYourLicense;

  final VoidCallback onAvatarTap;

  final String emergencyName;

  final String emergencyPhone;

  final String? emergencyAddress;

  const FlippableLicenseCard({
    super.key,

    required this.holderName,

    required this.holderGender,

    required this.holderAvatar,

    required this.holderBirthdate,

    required this.holderAddress,

    required this.holderNationality,

    required this.holderWeight,

    required this.holderHeight,

    required this.holderBloodType,

    required this.holderEyeColor,

    required this.holderConditions,

    required this.holderDateIssued,

    required this.holderSignature,

    required this.startDate,

    required this.calculatedAge,

    required this.isYourLicense,

    required this.onAvatarTap,

    required this.emergencyName,

    required this.emergencyPhone,

    this.emergencyAddress,
  });

  @override
  State<FlippableLicenseCard> createState() => _FlippableLicenseCardState();
}

class _FlippableLicenseCardState extends State<FlippableLicenseCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _flipController;

  late Animation<double> _flipAnimation;

  bool _showingFront = true;

  @override
  void initState() {
    super.initState();

    _flipController = AnimationController(
      vsync: this,

      duration: const Duration(milliseconds: 600),
    );

    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutBack),
    );
  }

  @override
  void dispose() {
    _flipController.dispose();

    super.dispose();
  }

  void _flipCard() {
    if (_flipController.isAnimating) return;

    if (_showingFront) {
      _flipController.forward();
    } else {
      _flipController.reverse();
    }

    setState(() => _showingFront = !_showingFront);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _flipCard,

      child: AnimatedBuilder(
        animation: _flipAnimation,

        builder: (context, child) {
          final angle = _flipAnimation.value * math.pi;

          final isFront = angle < math.pi / 2;

          return Transform(
            alignment: Alignment.center,

            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),

            child: isFront
                ? _LicenseFront(
                    holderName: widget.holderName,

                    holderGender: widget.holderGender,

                    holderAvatar: widget.holderAvatar,

                    holderBirthdate: widget.holderBirthdate,

                    holderAddress: widget.holderAddress,

                    holderNationality: widget.holderNationality,

                    holderWeight: widget.holderWeight,

                    holderHeight: widget.holderHeight,

                    holderBloodType: widget.holderBloodType,

                    holderEyeColor: widget.holderEyeColor,

                    holderConditions: widget.holderConditions,

                    holderDateIssued: widget.holderDateIssued,

                    holderSignature: widget.holderSignature,

                    startDate: widget.startDate,

                    calculatedAge: widget.calculatedAge,

                    isYourLicense: widget.isYourLicense,

                    onAvatarTap: widget.onAvatarTap,
                  )
                : Transform(
                    alignment: Alignment.center,

                    transform: Matrix4.identity()..rotateY(math.pi),

                    child: _LicenseBack(
                      holderName: widget.holderName,

                      holderGender: widget.holderGender,

                      holderBirthdate: widget.holderBirthdate,

                      holderAddress: widget.holderAddress,

                      holderNationality: widget.holderNationality,

                      holderWeight: widget.holderWeight,

                      holderHeight: widget.holderHeight,

                      holderBloodType: widget.holderBloodType,

                      holderEyeColor: widget.holderEyeColor,

                      holderConditions: widget.holderConditions,

                      holderDateIssued: widget.holderDateIssued,

                      emergencyName: widget.emergencyName,

                      emergencyPhone: widget.emergencyPhone,

                      emergencyAddress: widget.emergencyAddress,

                      startDate: widget.startDate,
                    ),
                  ),
          );
        },
      ),
    );
  }
}

// ════════════════════════════════════════

// FRONT OF LICENSE CARD VIEW (ID CARD LAYOUT)

// ════════════════════════════════════════

class _LicenseFront extends StatelessWidget {
  final String holderName;

  final String? holderGender;

  final String? holderAvatar;

  final DateTime? holderBirthdate;

  final String? holderAddress;

  final String holderNationality;

  final String holderWeight;

  final String holderHeight;

  final String holderBloodType;

  final String holderEyeColor;

  final String holderConditions;

  final DateTime? holderDateIssued;

  final String? holderSignature;

  final DateTime? startDate;

  final int? calculatedAge;

  final bool isYourLicense;

  final VoidCallback onAvatarTap;

  const _LicenseFront({
    required this.holderName,

    required this.holderGender,

    required this.holderAvatar,

    required this.holderBirthdate,

    required this.holderAddress,

    required this.holderNationality,

    required this.holderWeight,

    required this.holderHeight,

    required this.holderBloodType,

    required this.holderEyeColor,

    required this.holderConditions,

    required this.holderDateIssued,

    required this.holderSignature,

    required this.startDate,

    required this.calculatedAge,

    required this.isYourLicense,

    required this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy');

    final dobStr = holderBirthdate != null
        ? dateFormat.format(holderBirthdate!)
        : 'Not set';

    final relDateStr = startDate != null
        ? dateFormat.format(startDate!)
        : 'Not set';

    final issuedDateStr = holderDateIssued != null
        ? dateFormat.format(holderDateIssued!)
        : (startDate != null ? dateFormat.format(startDate!) : 'Not set');

    return _CardShell(
      child: _buildLandscapeLayout(
        dateFormat,
        dobStr,
        relDateStr,
        issuedDateStr,
      ),
    );
  }

  Widget _buildLandscapeLayout(
    DateFormat dateFormat,
    String dobStr,
    String relDateStr,
    String issuedDateStr,
  ) {
    final strokes = _deserializeSignature(holderSignature);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(isCompact: true),
        const SizedBox(height: 4),
        _goldDivider(),
        const SizedBox(height: 6),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 70,
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: onAvatarTap,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            width: 70,
                            height: 85,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFD4AF37),
                                width: 1.2,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6.8),
                              child: holderAvatar != null
                                  ? (holderAvatar!.startsWith('http')
                                      ? Image.network(
                                          holderAvatar!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => Container(
                                            color: Colors.white10,
                                            child: const Icon(
                                              Icons.broken_image,
                                              color: Colors.white30,
                                              size: 28,
                                            ),
                                          ),
                                        )
                                      : (File(holderAvatar!).existsSync()
                                          ? Image.file(
                                              File(holderAvatar!),
                                              fit: BoxFit.cover,
                                            )
                                          : Container(
                                              color: Colors.white10,
                                              child: const Icon(
                                                Icons.broken_image,
                                                color: Colors.white30,
                                                size: 28,
                                              ),
                                            )))
                                  : Container(
                                      color: Colors.white10,
                                      child: const Icon(
                                        Icons.person,
                                        color: Colors.white30,
                                        size: 28,
                                      ),
                                    ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Color(0xFFD4AF37),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              color: Color(0xFF1A0A2E),
                              size: 8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 70,
                      height: 22,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.02),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: const Color(0xFFD4AF37).withValues(alpha: 0.1),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3.5),
                        child: CustomPaint(
                          painter: ScaleSignaturePainter(
                            strokes: strokes,
                            color: const Color(0xFFD4AF37),
                            strokeWidth: 1.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'SIGNATURE',
                      style: AppTypography.body(fontSize: 5, fontWeight: FontWeight.w900, color: Colors.white.withValues(alpha: 0.35)).copyWith(letterSpacing: 0.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 1,
                color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      holderName.toUpperCase(),
                      style: AppTypography.sectionHeader(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white).copyWith(letterSpacing: 0.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _infoField(
                            'NATIONALITY',
                            holderNationality,
                            isCompact: true,
                          ),
                        ),
                        Expanded(
                          child: _infoField(
                            'SEX',
                            holderGender ?? '—',
                            isCompact: true,
                          ),
                        ),
                        Expanded(
                          child: _infoField(
                            'BLOOD TYPE',
                            holderBloodType,
                            isCompact: true,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _infoField(
                            'DATE OF BIRTH',
                            dobStr,
                            isCompact: true,
                          ),
                        ),
                        Expanded(
                          child: _infoField(
                            'AGE',
                            calculatedAge != null ? '$calculatedAge YRS' : '—',
                            isCompact: true,
                          ),
                        ),
                        Expanded(
                          child: _infoField(
                            'EYE COLOR',
                            holderEyeColor,
                            isCompact: true,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _infoField(
                            'HEIGHT',
                            holderHeight,
                            isCompact: true,
                          ),
                        ),
                        Expanded(
                          child: _infoField(
                            'WEIGHT',
                            holderWeight,
                            isCompact: true,
                          ),
                        ),
                        Expanded(
                          child: _infoField(
                            'CONDITIONS',
                            holderConditions,
                            isCompact: true,
                          ),
                        ),
                      ],
                    ),
                    _infoField(
                      'ADDRESS',
                      holderAddress?.isNotEmpty == true
                          ? holderAddress!
                          : 'NOT SET',
                      isCompact: true,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _infoField(
                            'RELATIONSHIP DATE',
                            relDateStr,
                            isCompact: true,
                          ),
                        ),
                        Expanded(
                          child: _infoField(
                            'DATE ISSUED',
                            issuedDateStr,
                            isCompact: true,
                          ),
                        ),
                        Expanded(
                          child: _infoField(
                            'EXPIRATION DATE',
                            'NO EXPIRY ∞',
                            isCompact: true,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader({required bool isCompact}) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_rounded,
              color: const Color(0xFFD4AF37),
              size: isCompact ? 10 : 12,
            ),
            const SizedBox(width: 8),
            Text(
              'OFFICIAL RELATIONSHIP ID CARD',
              style: AppTypography.body(fontSize: isCompact ? 8 : 9, fontWeight: FontWeight.w900, color: const Color(0xFFD4AF37)).copyWith(letterSpacing: isCompact ? 2 : 3),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.favorite_rounded,
              color: const Color(0xFFD4AF37),
              size: isCompact ? 10 : 12,
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          'CERTIFIED BY THE DEPARTMENT OF LOVE',
          style: AppTypography.body(fontSize: isCompact ? 6 : 7, fontWeight: FontWeight.w800, color: const Color(0xFFD4AF37).withValues(alpha: 0.6)).copyWith(letterSpacing: 1),
        ),
      ],
    );
  }

  Widget _infoField(String label, String value, {required bool isCompact}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTypography.body(fontSize: isCompact ? 5.5 : 7, fontWeight: FontWeight.w800, color: const Color(0xFFD4AF37).withValues(alpha: 0.65)).copyWith(letterSpacing: 0.6),
        ),
        const SizedBox(height: 1),
        Text(
          value.toUpperCase(),
          style: AppTypography.body(fontSize: isCompact ? 8.5 : 10.5, fontWeight: FontWeight.bold, color: Colors.white),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ════════════════════════════════════════

// BACK OF LICENSE CARD VIEW

// ════════════════════════════════════════

class _LicenseBack extends StatelessWidget {
  final String holderName;

  final String? holderGender;

  final DateTime? holderBirthdate;

  final String? holderAddress;

  final String holderNationality;

  final String holderWeight;

  final String holderHeight;

  final String holderBloodType;

  final String holderEyeColor;

  final String holderConditions;

  final DateTime? holderDateIssued;

  final String emergencyName;

  final String emergencyPhone;

  final String? emergencyAddress;

  final DateTime? startDate;

  const _LicenseBack({
    required this.holderName,

    required this.holderGender,

    required this.holderBirthdate,

    required this.holderAddress,

    required this.holderNationality,

    required this.holderWeight,

    required this.holderHeight,

    required this.holderBloodType,

    required this.holderEyeColor,

    required this.holderConditions,

    required this.holderDateIssued,

    required this.emergencyName,

    required this.emergencyPhone,

    this.emergencyAddress,

    required this.startDate,
  });

  String _buildQrData() {
    final dateFormat = DateFormat('yyyy-MM-dd');

    final startDateStr = startDate != null
        ? dateFormat.format(startDate!)
        : 'Not set';

    final birthdateStr = holderBirthdate != null
        ? dateFormat.format(holderBirthdate!)
        : 'Not set';

    final issuedDateStr = holderDateIssued != null
        ? dateFormat.format(holderDateIssued!)
        : (startDate != null ? dateFormat.format(startDate!) : 'Not set');

    final buf = StringBuffer();

    buf.writeln('═══ RELATIONSHIP LICENSE ═══');

    buf.writeln('HOLDER: ${holderName.toUpperCase()}');

    buf.writeln('SEX: ${(holderGender ?? "—").toUpperCase()}');

    buf.writeln('BIRTHDATE: $birthdateStr');

    buf.writeln('NATIONALITY: ${holderNationality.toUpperCase()}');

    buf.writeln('WEIGHT: ${holderWeight.toUpperCase()}');

    buf.writeln('HEIGHT: ${holderHeight.toUpperCase()}');

    buf.writeln('ADDRESS: ${holderAddress ?? "Not set"}');

    buf.writeln('');

    buf.writeln('EMERGENCY CONTACT (PARTNER):');

    buf.writeln('Name: ${emergencyName.toUpperCase()}');

    buf.writeln('Phone: $emergencyPhone');

    buf.writeln('');

    buf.writeln('BLOOD TYPE: ${holderBloodType.toUpperCase()}');

    buf.writeln('EYES COLOR: ${holderEyeColor.toUpperCase()}');

    buf.writeln('CONDITIONS: ${holderConditions.toUpperCase()}');

    buf.writeln('');

    buf.writeln('TOGETHER SINCE: $startDateStr');

    buf.writeln('DATE ISSUED: $issuedDateStr');

    buf.writeln('STATUS: VALID FOREVER');

    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,

        children: [
          // Left portion: Rotated Emergency Details
          SizedBox(
            width: 125,
            height: double.infinity,
            child: RotatedBox(
              quarterTurns: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'EMERGENCY INFORMATION',
                    style: AppTypography.body(fontSize: 8, fontWeight: FontWeight.w900, color: const Color(0xFFD4AF37)).copyWith(letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 4),
                  _goldDivider(),
                  const SizedBox(height: 4),
                  Text(
                    'IN CASE OF EMERGENCY CONTACT:',
                    style: AppTypography.body(fontSize: 7, fontWeight: FontWeight.w800, color: Colors.white.withValues(alpha: 0.5)),
                  ),
                  const SizedBox(height: 4),
                  _emergencyContact(
                    name: emergencyName,
                    phone: emergencyPhone,
                    address: emergencyAddress,
                    icon: Icons.favorite_rounded,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Divider line (runs vertically)
          Container(
            width: 1,
            height: double.infinity,
            color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
          ),

          const SizedBox(width: 12),

          // Right portion: QR Code
          Expanded(
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(6),

                decoration: BoxDecoration(
                  color: Colors.white,

                  borderRadius: BorderRadius.circular(12),

                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.2),

                      blurRadius: 10,
                    ),
                  ],
                ),

                child: QrImageView(
                  data: _buildQrData(),

                  version: QrVersions.auto,

                  size: 150, // Enlarged size

                  backgroundColor: Colors.white,

                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,

                    color: Color(0xFF1A0A2E),
                  ),

                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,

                    color: Color(0xFF1A0A2E),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emergencyContact({
    required String name,
    required String phone,
    String? address,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),

      decoration: BoxDecoration(
        color: const Color(0xFFD4AF37).withValues(alpha: 0.08),

        borderRadius: BorderRadius.circular(12),

        border: Border.all(
          color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
        ),
      ),

      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),

            decoration: BoxDecoration(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.15),

              shape: BoxShape.circle,
            ),

            child: Icon(icon, color: const Color(0xFFD4AF37), size: 16),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              mainAxisSize: MainAxisSize.min,

              children: [
                Text(
                  name.toUpperCase(),

                  style: AppTypography.body(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white).copyWith(letterSpacing: 1),
                ),

                if (address != null && address.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    address.toUpperCase(),

                    style: AppTypography.body(fontSize: 8, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.6)),
                  ),
                ],

                const SizedBox(height: 4),

                Text(
                  phone,

                  style: AppTypography.bodyMono(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFFD4AF37)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════

// SHARED CARD SHELL

// ════════════════════════════════════════

class _CardShell extends StatelessWidget {
  final Widget child;

  const _CardShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 85.60 / 53.98,

      child: Container(
        width: double.infinity,

        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),

          gradient: const LinearGradient(
            begin: Alignment.topLeft,

            end: Alignment.bottomRight,

            colors: [Color(0xFF1A0A2E), Color(0xFF2D1B4E), Color(0xFF1A0A2E)],
          ),

          border: Border.all(color: const Color(0xFFD4AF37), width: 2),

          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.2),

              blurRadius: 20,

              spreadRadius: 2,
            ),
          ],
        ),

        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),

                child: CustomPaint(painter: _WatermarkPainter()),
              ),
            ),

            Padding(padding: const EdgeInsets.all(12), child: child),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════

// SHARED HELPERS

// ════════════════════════════════════════

Widget _goldDivider() {
  return Container(
    height: 1,

    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          Colors.transparent,

          const Color(0xFFD4AF37).withValues(alpha: 0.6),

          const Color(0xFFD4AF37),

          const Color(0xFFD4AF37).withValues(alpha: 0.6),

          Colors.transparent,
        ],
      ),
    ),
  );
}

// ════════════════════════════════════════

// WATERMARK PAINTER

// ════════════════════════════════════════

class _WatermarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.02)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    for (double i = -size.height; i < size.width + size.height; i += 20) {
      canvas.drawLine(
        Offset(i, 0),

        Offset(i + size.height, size.height),

        paint,
      );
    }

    final cornerPaint = Paint()
      ..color = const Color(0xFFD4AF37).withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawArc(
      const Rect.fromLTWH(8, 8, 40, 40),
      3.14,
      1.57,
      false,
      cornerPaint,
    );

    canvas.drawArc(
      Rect.fromLTWH(size.width - 48, 8, 40, 40),
      -1.57,
      1.57,

      false,
      cornerPaint,
    );

    canvas.drawArc(
      Rect.fromLTWH(8, size.height - 48, 40, 40),
      1.57,
      1.57,

      false,
      cornerPaint,
    );

    canvas.drawArc(
      Rect.fromLTWH(size.width - 48, size.height - 48, 40, 40),
      0,

      1.57,
      false,
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ════════════════════════════════════════

// INTEGRATED LICENSE INFORMATION EDITOR

// ════════════════════════════════════════

class _EditLicenseSheet extends StatefulWidget {
  final RelationshipProvider rp;

  final dynamic theme;

  const _EditLicenseSheet({required this.rp, required this.theme});

  @override
  State<_EditLicenseSheet> createState() => _EditLicenseSheetState();
}

class _EditLicenseSheetState extends State<_EditLicenseSheet> {
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

    _yourNameCtrl = TextEditingController(text: widget.rp.yourName ?? '');

    _partnerNameCtrl = TextEditingController(text: widget.rp.partnerName ?? '');

    _yourPhoneCtrl = TextEditingController(text: widget.rp.yourPhone ?? '');

    _partnerPhoneCtrl = TextEditingController(
      text: widget.rp.partnerPhone ?? '',
    );

    _yourAddressCtrl = TextEditingController(text: widget.rp.yourAddress ?? '');

    _partnerAddressCtrl = TextEditingController(
      text: widget.rp.partnerAddress ?? '',
    );

    _yourNationalityCtrl = TextEditingController(
      text: widget.rp.yourNationality,
    );

    _partnerNationalityCtrl = TextEditingController(
      text: widget.rp.partnerNationality,
    );

    _yourWeightCtrl = TextEditingController(text: widget.rp.yourWeight);

    _partnerWeightCtrl = TextEditingController(text: widget.rp.partnerWeight);

    _yourHeightCtrl = TextEditingController(text: widget.rp.yourHeight);

    _partnerHeightCtrl = TextEditingController(text: widget.rp.partnerHeight);

    _yourBloodCtrl = TextEditingController(text: widget.rp.yourBloodType);

    _partnerBloodCtrl = TextEditingController(text: widget.rp.partnerBloodType);

    _yourEyeColorCtrl = TextEditingController(text: widget.rp.yourEyeColor);

    _partnerEyeColorCtrl = TextEditingController(
      text: widget.rp.partnerEyeColor,
    );

    _yourConditionsCtrl = TextEditingController(text: widget.rp.yourConditions);

    _partnerConditionsCtrl = TextEditingController(
      text: widget.rp.partnerConditions,
    );

    _yourGender = widget.rp.yourGender ?? 'Male';

    _partnerGender = widget.rp.partnerGender ?? 'Female';

    _yourBirthdate = widget.rp.yourBirthdate;

    _partnerBirthdate = widget.rp.partnerBirthdate;

    _yourDateIssued = widget.rp.yourDateIssued;

    _partnerDateIssued = widget.rp.partnerDateIssued;

    _yourSignatureStr = widget.rp.yourSignature ?? '';

    _partnerSignatureStr = widget.rp.partnerSignature ?? '';
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
    widget.rp.updateLicense(
      yourName: _yourNameCtrl.text.trim(),
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

            style: AppTypography.sectionHeader(fontSize: 22, fontWeight: FontWeight.bold, color: widget.theme.textColor),
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
    final nameCtrl = isYou ? _yourNameCtrl : _partnerNameCtrl;

    final phoneCtrl = isYou ? _yourPhoneCtrl : _partnerPhoneCtrl;

    final addressCtrl = isYou ? _yourAddressCtrl : _partnerAddressCtrl;

    final nationalityCtrl = isYou
        ? _yourNationalityCtrl
        : _partnerNationalityCtrl;

    final weightCtrl = isYou ? _yourWeightCtrl : _partnerWeightCtrl;

    final heightCtrl = isYou ? _yourHeightCtrl : _partnerHeightCtrl;

    final bloodCtrl = isYou ? _yourBloodCtrl : _partnerBloodCtrl;

    final eyeCtrl = isYou ? _yourEyeColorCtrl : _partnerEyeColorCtrl;

    final conditionsCtrl = isYou ? _yourConditionsCtrl : _partnerConditionsCtrl;

    final gender = isYou ? _yourGender : _partnerGender;

    final birthdate = isYou ? _yourBirthdate : _partnerBirthdate;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          // Name Field
          _buildFieldLabel('Full Name'),

          TextField(
            controller: nameCtrl,

            style: AppTypography.body(color: widget.theme.textColor),

            decoration: _inputDecoration('Enter full name'),
          ),

          const SizedBox(height: 16),

          // Gender Selector
          _buildFieldLabel('Sex / Gender'),

          Row(
            children: [
              _genderOption('Male', gender, (val) {
                setState(() {
                  if (isYou) {
                    _yourGender = val;
                  } else {
                    _partnerGender = val;
                  }
                });
              }),

              const SizedBox(width: 12),

              _genderOption('Female', gender, (val) {
                setState(() {
                  if (isYou) {
                    _yourGender = val;
                  } else {
                    _partnerGender = val;
                  }
                });
              }),
            ],
          ),

          const SizedBox(height: 16),

          // Birthdate Field
          _buildFieldLabel('Birthdate'),

          InkWell(
            onTap: () => _selectDate(context, isYou),

            borderRadius: BorderRadius.circular(12),

            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),

              decoration: BoxDecoration(
                color: widget.theme.textColor.withValues(alpha: 0.05),

                borderRadius: BorderRadius.circular(12),

                border: Border.all(
                  color: widget.theme.textColor.withValues(alpha: 0.1),
                ),
              ),

              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,

                children: [
                  Text(
                    birthdate != null
                        ? DateFormat('MMMM dd, yyyy').format(birthdate)
                        : 'Select Birthdate',

                    style: AppTypography.body(color: birthdate != null
                          ? widget.theme.textColor
                          : widget.theme.textColor.withValues(alpha: 0.5)),
                  ),

                  Icon(
                    Icons.calendar_month_rounded,
                    color: widget.theme.accentColor,
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

            style: AppTypography.body(color: widget.theme.textColor),

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

                      style: AppTypography.body(color: widget.theme.textColor),

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

                      style: AppTypography.body(color: widget.theme.textColor),

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

            style: AppTypography.body(color: widget.theme.textColor),

            decoration: _inputDecoration('Enter address'),
          ),

          const SizedBox(height: 16),

          // Date Issued
          _buildFieldLabel('Date Issued'),

          InkWell(
            onTap: () => _selectIssuedDate(context, isYou),

            borderRadius: BorderRadius.circular(12),

            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),

              decoration: BoxDecoration(
                color: widget.theme.textColor.withValues(alpha: 0.05),

                borderRadius: BorderRadius.circular(12),

                border: Border.all(
                  color: widget.theme.textColor.withValues(alpha: 0.1),
                ),
              ),

              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,

                children: [
                  Text(
                    (isYou ? _yourDateIssued : _partnerDateIssued) != null
                        ? DateFormat('MMMM dd, yyyy').format(
                            (isYou ? _yourDateIssued : _partnerDateIssued)!,
                          )
                        : 'Default (Relationship Date)',

                    style: AppTypography.body(color:
                          (isYou ? _yourDateIssued : _partnerDateIssued) != null
                          ? widget.theme.textColor
                          : widget.theme.textColor.withValues(alpha: 0.5)),
                  ),

                  Icon(
                    Icons.calendar_month_rounded,
                    color: widget.theme.accentColor,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Signature
          _buildFieldLabel('Signature'),

          GestureDetector(
            onTap: () async {
              final strokes = _deserializeSignature(
                isYou ? _yourSignatureStr : _partnerSignatureStr,
              );

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
                  final serialized = _serializeSignature(result);

                  if (isYou) {
                    _yourSignatureStr = serialized;
                  } else {
                    _partnerSignatureStr = serialized;
                  }
                });
              }
            },

            child: Container(
              width: double.infinity,

              height: 100,

              decoration: BoxDecoration(
                color: widget.theme.textColor.withValues(alpha: 0.05),

                borderRadius: BorderRadius.circular(12),

                border: Border.all(
                  color: widget.theme.textColor.withValues(alpha: 0.1),
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
                          strokes: _deserializeSignature(
                            isYou ? _yourSignatureStr : _partnerSignatureStr,
                          ),

                          color: widget.theme.accentColor,

                          strokeWidth: 2.5,
                        ),
                      ),
                    ),
                  ),

                  if ((isYou ? _yourSignatureStr : _partnerSignatureStr)
                      .isEmpty)
                    Text(
                      'Tap to draw signature',

                      style: AppTypography.body(color: widget.theme.textColor.withValues(alpha: 0.4), fontSize: 14),
                    ),

                  if ((isYou ? _yourSignatureStr : _partnerSignatureStr)
                      .isNotEmpty)
                    Positioned(
                      top: 4,

                      right: 4,

                      child: IconButton(
                        icon: const Icon(Icons.clear, size: 18),

                        color: Colors.redAccent,

                        onPressed: () {
                          setState(() {
                            if (isYou) {
                              _yourSignatureStr = '';
                            } else {
                              _partnerSignatureStr = '';
                            }
                          });
                        },
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

                      style: AppTypography.body(color: widget.theme.textColor),

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

                      style: AppTypography.body(color: widget.theme.textColor),

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

            style: AppTypography.body(color: widget.theme.textColor),

            decoration: _inputDecoration('e.g., Head over heels'),
          ),

          const SizedBox(height: 16),

          // Phone Field (Emergency Contact Info)
          _buildFieldLabel('Emergency Phone Number'),

          TextField(
            controller: phoneCtrl,

            keyboardType: TextInputType.phone,

            style: AppTypography.body(color: widget.theme.textColor),

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

        style: AppTypography.body(fontSize: 11, fontWeight: FontWeight.bold, color: widget.theme.textColor.withValues(alpha: 0.6)).copyWith(letterSpacing: 1),
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
                ? widget.theme.accentColor.withValues(alpha: 0.1)
                : widget.theme.textColor.withValues(alpha: 0.05),

            borderRadius: BorderRadius.circular(12),

            border: Border.all(
              color: isSelected
                  ? widget.theme.accentColor
                  : widget.theme.textColor.withValues(alpha: 0.1),

              width: 1.5,
            ),
          ),

          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,

            children: [
              Icon(
                value == 'Male' ? Icons.male_rounded : Icons.female_rounded,

                color: isSelected
                    ? widget.theme.accentColor
                    : widget.theme.textColor.withValues(alpha: 0.5),

                size: 20,
              ),

              const SizedBox(width: 8),

              Text(
                value,

                style: AppTypography.body(fontWeight: FontWeight.bold, color: isSelected
                      ? widget.theme.accentColor
                      : widget.theme.textColor),
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

      hintStyle: AppTypography.body(color: widget.theme.textColor.withValues(alpha: 0.4)),

      filled: true,

      fillColor: widget.theme.textColor.withValues(alpha: 0.05),

      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),

        borderSide: BorderSide.none,
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),

        borderSide: BorderSide(color: widget.theme.accentColor, width: 1.5),
      ),
    );
  }
}

// ════════════════════════════════════════

// SIGNATURE DRAWING & RENDERING COMPONENT

// ════════════════════════════════════════

List<List<Offset>> _deserializeSignature(String? data) {
  if (data == null || data.isEmpty) return [];

  try {
    return data.split('|').map((strokeStr) {
      if (strokeStr.isEmpty) return <Offset>[];

      return strokeStr.split(';').map((pointStr) {
        final parts = pointStr.split(',');

        return Offset(double.parse(parts[0]), double.parse(parts[1]));
      }).toList();
    }).toList();
  } catch (e) {
    return [];
  }
}

String _serializeSignature(List<List<Offset>> strokes) {
  return strokes
      .map((stroke) {
        return stroke
            .map((p) => '${p.dx.toStringAsFixed(1)},${p.dy.toStringAsFixed(1)}')
            .join(';');
      })
      .join('|');
}

class SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;

  final Color color;

  final double strokeWidth;

  SignaturePainter({
    required this.strokes,

    required this.color,

    this.strokeWidth = 3.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;

      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);

      for (int i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant SignaturePainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

class ScaleSignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;

  final Color color;

  final double strokeWidth;

  ScaleSignaturePainter({
    required this.strokes,

    required this.color,

    this.strokeWidth = 2.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (strokes.isEmpty) return;

    // 1. Find bounding box of all points

    double minX = double.infinity;

    double maxX = double.negativeInfinity;

    double minY = double.infinity;

    double maxY = double.negativeInfinity;

    bool hasPoints = false;

    for (final stroke in strokes) {
      for (final p in stroke) {
        if (p.dx < minX) minX = p.dx;

        if (p.dx > maxX) maxX = p.dx;

        if (p.dy < minY) minY = p.dy;

        if (p.dy > maxY) maxY = p.dy;

        hasPoints = true;
      }
    }

    if (!hasPoints) return;

    final w = maxX - minX;

    final h = maxY - minY;

    if (w == 0 || h == 0) return;

    // Apply padding of 4.0 pixels around the signature

    const padding = 4.0;

    final targetW = size.width - 2 * padding;

    final targetH = size.height - 2 * padding;

    final scaleX = targetW / w;

    final scaleY = targetH / h;

    final scale = scaleX < scaleY ? scaleX : scaleY;

    final targetCenterX = size.width / 2;

    final targetCenterY = size.height / 2;

    final sourceCenterX = minX + w / 2;

    final sourceCenterY = minY + h / 2;

    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.isEmpty) continue;

      final firstPoint = stroke.first;

      final startX = targetCenterX + (firstPoint.dx - sourceCenterX) * scale;

      final startY = targetCenterY + (firstPoint.dy - sourceCenterY) * scale;

      final path = Path()..moveTo(startX, startY);

      for (int i = 1; i < stroke.length; i++) {
        final p = stroke[i];

        final px = targetCenterX + (p.dx - sourceCenterX) * scale;

        final py = targetCenterY + (p.dy - sourceCenterY) * scale;

        path.lineTo(px, py);
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant ScaleSignaturePainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

class SignatureDrawingDialog extends StatefulWidget {
  final List<List<Offset>> initialStrokes;

  final String title;

  final dynamic theme;

  const SignatureDrawingDialog({
    super.key,

    required this.initialStrokes,

    required this.title,

    required this.theme,
  });

  @override
  State<SignatureDrawingDialog> createState() => _SignatureDrawingDialogState();
}

class _SignatureDrawingDialogState extends State<SignatureDrawingDialog> {
  late List<List<Offset>> _strokes;

  @override
  void initState() {
    super.initState();

    // Create deep copy

    _strokes = widget.initialStrokes
        .map((stroke) => List<Offset>.from(stroke))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.theme.isDark
          ? const Color(0xFF10122B)
          : const Color(0xFFFFF0F5),

      appBar: AppBar(
        title: Text(
          widget.title,

          style: AppTypography.sectionHeader(fontWeight: FontWeight.bold, color: widget.theme.textColor),
        ),

        backgroundColor: Colors.transparent,

        elevation: 0,

        leading: IconButton(
          icon: Icon(Icons.close, color: widget.theme.textColor),

          onPressed: () => Navigator.pop(context),
        ),

        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _strokes.clear();
              });
            },

            child: Text(
              'Clear',

              style: AppTypography.body(color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
          ),

          const SizedBox(width: 8),
        ],
      ),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),

          child: Column(
            children: [
              Text(
                'Draw your signature inside the box below',

                style: AppTypography.body(fontSize: 14, color: widget.theme.textColor.withValues(alpha: 0.6)),
              ),

              const SizedBox(height: 20),

              Expanded(
                child: Container(
                  width: double.infinity,

                  decoration: BoxDecoration(
                    color: widget.theme.isDark
                        ? Colors.black26
                        : Colors.white24,

                    borderRadius: BorderRadius.circular(16),

                    border: Border.all(
                      color: widget.theme.accentColor.withValues(alpha: 0.3),

                      width: 2,
                    ),
                  ),

                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),

                    child: GestureDetector(
                      onPanStart: (details) {
                        setState(() {
                          _strokes.add([details.localPosition]);
                        });
                      },

                      onPanUpdate: (details) {
                        setState(() {
                          if (_strokes.isNotEmpty) {
                            _strokes.last.add(details.localPosition);
                          }
                        });
                      },

                      child: CustomPaint(
                        painter: SignaturePainter(
                          strokes: _strokes,

                          color: widget.theme.accentColor,

                          strokeWidth: 4.0,
                        ),

                        size: Size.infinite,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,

                height: 52,

                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, _strokes);
                  },

                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.theme.accentColor,

                    foregroundColor: Colors.white,

                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),

                  child: Text(
                    'Save Signature',

                    style: AppTypography.body(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExportStudioBottomSheet extends StatefulWidget {
  final RelationshipProvider rp;
  final dynamic theme;
  final bool showBoth;
  final bool isYourLicense;
  final bool myShowingFront;
  final bool partnerShowingFront;
  final GlobalKey mainLicenseKey;

  const _ExportStudioBottomSheet({
    required this.rp,
    required this.theme,
    required this.showBoth,
    required this.isYourLicense,
    required this.myShowingFront,
    required this.partnerShowingFront,
    required this.mainLicenseKey,
  });

  @override
  State<_ExportStudioBottomSheet> createState() =>
      _ExportStudioBottomSheetState();
}

enum ExportTemplate { transparent, story, post }

class _ExportStudioBottomSheetState extends State<_ExportStudioBottomSheet> {
  ExportTemplate _selectedTemplate = ExportTemplate.story;
  bool _exportFront = true;
  bool _isSharing = false;
  bool _isSaving = false;

  final GlobalKey _transparentKey = GlobalKey();
  final GlobalKey _storyKey = GlobalKey();
  final GlobalKey _postKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _exportFront = widget.isYourLicense
        ? widget.myShowingFront
        : widget.partnerShowingFront;
  }

  int? _calculateAge(DateTime? birthdate) {
    if (birthdate == null) return null;
    final today = DateTime.now();
    int age = today.year - birthdate.year;
    if (today.month < birthdate.month ||
        (today.month == birthdate.month && today.day < birthdate.day)) {
      age--;
    }
    return age;
  }

  Future<void> _shareImage() async {
    setState(() => _isSharing = true);
    try {
      GlobalKey activeKey;
      String filenamePrefix;

      switch (_selectedTemplate) {
        case ExportTemplate.transparent:
          activeKey = _transparentKey;
          filenamePrefix = 'transparent_license';
          break;
        case ExportTemplate.story:
          activeKey = _storyKey;
          filenamePrefix = 'story_license';
          break;
        case ExportTemplate.post:
          activeKey = _postKey;
          filenamePrefix = 'post_license';
          break;
      }

      final boundary =
          activeKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Preview capture layer not ready. Please try again.');
      }

      final image = await boundary.toImage(pixelRatio: 4.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Failed to generate PNG bytes');

      final pngBytes = byteData.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = await File(
        '${tempDir.path}/${filenamePrefix}_${DateTime.now().millisecondsSinceEpoch}.png',
      ).create();
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Look at our certified Relationship License! ❤️');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  Future<void> _saveToDevice() async {
    setState(() => _isSaving = true);
    try {
      GlobalKey activeKey;
      String filenamePrefix;

      switch (_selectedTemplate) {
        case ExportTemplate.transparent:
          activeKey = _transparentKey;
          filenamePrefix = 'transparent_license';
          break;
        case ExportTemplate.story:
          activeKey = _storyKey;
          filenamePrefix = 'story_license';
          break;
        case ExportTemplate.post:
          activeKey = _postKey;
          filenamePrefix = 'post_license';
          break;
      }

      final boundary =
          activeKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Preview capture layer not ready. Please try again.');
      }

      final image = await boundary.toImage(pixelRatio: 4.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Failed to generate PNG bytes');

      final pngBytes = byteData.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = await File(
        '${tempDir.path}/${filenamePrefix}_${DateTime.now().millisecondsSinceEpoch}.png',
      ).create();
      await file.writeAsBytes(pngBytes);

      await Gal.putImage(file.path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo saved to gallery successfully! 📸'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildCard({
    required bool isYourLicense,
    required bool showFront,
    required RelationshipProvider rp,
  }) {
    final myName = rp.yourName ?? 'You';
    final partnerName = rp.partnerName ?? 'Partner';
    final myPhone = rp.yourPhone?.isNotEmpty == true
        ? rp.yourPhone!
        : 'Not provided';
    final partnerPhone = rp.partnerPhone?.isNotEmpty == true
        ? rp.partnerPhone!
        : 'Not provided';

    final name = isYourLicense ? myName : partnerName;
    final gender = isYourLicense ? rp.yourGender : rp.partnerGender;
    final avatar = isYourLicense ? rp.yourAvatarPath : rp.partnerAvatarPath;
    final birthdate = isYourLicense ? rp.yourBirthdate : rp.partnerBirthdate;
    final address = isYourLicense ? rp.yourAddress : rp.partnerAddress;
    final nationality = isYourLicense
        ? rp.yourNationality
        : rp.partnerNationality;
    final weight = isYourLicense ? rp.yourWeight : rp.partnerWeight;
    final height = isYourLicense ? rp.yourHeight : rp.partnerHeight;
    final bloodType = isYourLicense ? rp.yourBloodType : rp.partnerBloodType;
    final eyeColor = isYourLicense ? rp.yourEyeColor : rp.partnerEyeColor;
    final conditions = isYourLicense ? rp.yourConditions : rp.partnerConditions;
    final dateIssued = isYourLicense ? rp.yourDateIssued : rp.partnerDateIssued;
    final signature = isYourLicense ? rp.yourSignature : rp.partnerSignature;

    final age = isYourLicense
        ? _calculateAge(rp.yourBirthdate)
        : _calculateAge(rp.partnerBirthdate);
    final emergencyN = isYourLicense ? partnerName : myName;
    final emergencyP = isYourLicense ? partnerPhone : myPhone;
    final emergencyA = isYourLicense ? rp.partnerAddress : rp.yourAddress;

    if (showFront) {
      return _LicenseFront(
        holderName: name,
        holderGender: gender,
        holderAvatar: avatar,
        holderBirthdate: birthdate,
        holderAddress: address,
        holderNationality: nationality,
        holderWeight: weight,
        holderHeight: height,
        holderBloodType: bloodType,
        holderEyeColor: eyeColor,
        holderConditions: conditions,
        holderDateIssued: dateIssued,
        holderSignature: signature,
        startDate: rp.startDate,
        calculatedAge: age,
        isYourLicense: isYourLicense,
        onAvatarTap: () {},
      );
    } else {
      return _LicenseBack(
        holderName: name,
        holderGender: gender,
        holderBirthdate: birthdate,
        holderAddress: address,
        holderNationality: nationality,
        holderWeight: weight,
        holderHeight: height,
        holderBloodType: bloodType,
        holderEyeColor: eyeColor,
        holderConditions: conditions,
        holderDateIssued: dateIssued,
        emergencyName: emergencyN,
        emergencyPhone: emergencyP,
        emergencyAddress: emergencyA,
        startDate: rp.startDate,
      );
    }
  }

  Widget _buildScaledCard({
    required bool isYourLicense,
    required bool showFront,
    required RelationshipProvider rp,
    required double targetWidth,
  }) {
    final double targetHeight = targetWidth / (85.60 / 53.98);
    return SizedBox(
      width: targetWidth,
      height: targetHeight,
      child: FittedBox(
        fit: BoxFit.fill,
        child: SizedBox(
          width: 350,
          height: 350 / (85.60 / 53.98),
          child: _buildCard(
            isYourLicense: isYourLicense,
            showFront: showFront,
            rp: rp,
          ),
        ),
      ),
    );
  }

  Widget _buildTransparentTemplate(RelationshipProvider rp) {
    return Container(
      width: 800,
      height: widget.showBoth ? 1040 : 504,
      color: Colors.transparent,
      child: widget.showBoth
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildScaledCard(
                  isYourLicense: true,
                  showFront: _exportFront,
                  rp: rp,
                  targetWidth: 760,
                ),
                const SizedBox(height: 32),
                _buildScaledCard(
                  isYourLicense: false,
                  showFront: _exportFront,
                  rp: rp,
                  targetWidth: 760,
                ),
              ],
            )
          : _buildScaledCard(
              isYourLicense: widget.isYourLicense,
              showFront: _exportFront,
              rp: rp,
              targetWidth: 800,
            ),
    );
  }

  Widget _buildStoryTemplate(RelationshipProvider rp) {
    final dateFormat = DateFormat('MMMM dd, yyyy');
    final startDateStr = rp.startDate != null
        ? dateFormat.format(rp.startDate!)
        : 'FOREVER';

    return Container(
      width: 1080,
      height: 1920,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0A0314),
            Color(0xFF1B072B),
            Color(0xFF2E0942),
            Color(0xFF0A0314),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 200,
            left: -150,
            child: Container(
              width: 600,
              height: 600,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    widget.theme.accentColor.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 300,
            right: -150,
            child: Container(
              width: 600,
              height: 600,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFD4AF37).withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 60),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 40,
                      height: 1,
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Icon(
                        Icons.favorite_rounded,
                        color: Color(0xFFD4AF37),
                        size: 24,
                      ),
                    ),
                    Container(
                      width: 40,
                      height: 1,
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'OFFICIAL RELATIONSHIP LICENSE',
                  textAlign: TextAlign.center,
                  style: AppTypography.body(fontSize: 22, fontWeight: FontWeight.w900, color: const Color(0xFFD4AF37)).copyWith(letterSpacing: 4),
                ),
                const SizedBox(height: 10),
                Text(
                  'CERTIFIED BY THE DEPARTMENT OF LOVE',
                  textAlign: TextAlign.center,
                  style: AppTypography.body(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFFD4AF37).withValues(alpha: 0.6)).copyWith(letterSpacing: 1.5),
                ),
                const Spacer(),
                widget.showBoth
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  blurRadius: 40,
                                  offset: const Offset(0, 20),
                                ),
                              ],
                            ),
                            child: _buildScaledCard(
                              isYourLicense: true,
                              showFront: _exportFront,
                              rp: rp,
                              targetWidth: 920,
                            ),
                          ),
                          const SizedBox(height: 60),
                          Container(
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  blurRadius: 40,
                                  offset: const Offset(0, 20),
                                ),
                              ],
                            ),
                            child: _buildScaledCard(
                              isYourLicense: false,
                              showFront: _exportFront,
                              rp: rp,
                              targetWidth: 920,
                            ),
                          ),
                        ],
                      )
                    : Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.6),
                              blurRadius: 40,
                              offset: const Offset(0, 20),
                            ),
                          ],
                        ),
                        child: _buildScaledCard(
                          isYourLicense: widget.isYourLicense,
                          showFront: _exportFront,
                          rp: rp,
                          targetWidth: 920,
                        ),
                      ),
                const Spacer(),
                _goldDivider(),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.verified_rounded,
                      color: Color(0xFFD4AF37),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'STATUS: VALID FOREVER',
                      style: AppTypography.body(fontSize: 12, fontWeight: FontWeight.w900, color: const Color(0xFFD4AF37)).copyWith(letterSpacing: 2),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'TOGETHER SINCE $startDateStr',
                  style: AppTypography.body(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.5)).copyWith(letterSpacing: 1.5),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostTemplate(RelationshipProvider rp) {
    final dateFormat = DateFormat('MMMM dd, yyyy');
    final startDateStr = rp.startDate != null
        ? dateFormat.format(rp.startDate!)
        : 'FOREVER';

    return Container(
      width: 1080,
      height: 1080,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F051D), Color(0xFF260D3E), Color(0xFF0F051D)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 140,
            top: 140,
            child: Container(
              width: 800,
              height: 800,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    widget.theme.accentColor.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 50),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  children: [
                    Text(
                      'DEPARTMENT OF LOVE',
                      style: AppTypography.body(fontSize: 12, fontWeight: FontWeight.w900, color: const Color(0xFFD4AF37)).copyWith(letterSpacing: 5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'OFFICIAL RELATIONSHIP CERTIFICATE',
                      style: AppTypography.body(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white.withValues(alpha: 0.4)).copyWith(letterSpacing: 2),
                    ),
                  ],
                ),
                widget.showBoth
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 30,
                                  offset: const Offset(0, 15),
                                ),
                              ],
                            ),
                            child: _buildScaledCard(
                              isYourLicense: true,
                              showFront: _exportFront,
                              rp: rp,
                              targetWidth: 660,
                            ),
                          ),
                          const SizedBox(height: 30),
                          Container(
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  blurRadius: 30,
                                  offset: const Offset(0, 15),
                                ),
                              ],
                            ),
                            child: _buildScaledCard(
                              isYourLicense: false,
                              showFront: _exportFront,
                              rp: rp,
                              targetWidth: 660,
                            ),
                          ),
                        ],
                      )
                    : Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.55),
                              blurRadius: 35,
                              offset: const Offset(0, 20),
                            ),
                          ],
                        ),
                        child: _buildScaledCard(
                          isYourLicense: widget.isYourLicense,
                          showFront: _exportFront,
                          rp: rp,
                          targetWidth: 860,
                        ),
                      ),
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.favorite_rounded,
                          color: Color(0xFFD4AF37),
                          size: 14,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'VALID FOREVER',
                          style: AppTypography.body(fontSize: 11, fontWeight: FontWeight.w900, color: const Color(0xFFD4AF37)).copyWith(letterSpacing: 3),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.favorite_rounded,
                          color: Color(0xFFD4AF37),
                          size: 14,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ANNIVERSARY DATE: $startDateStr',
                      style: AppTypography.body(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white.withValues(alpha: 0.4)).copyWith(letterSpacing: 1.5),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewFrame() {
    Widget activeTemplateWidget;
    double aspectRatio;

    switch (_selectedTemplate) {
      case ExportTemplate.transparent:
        aspectRatio = widget.showBoth ? (800 / 1040) : (800 / 504);
        activeTemplateWidget = RepaintBoundary(
          key: _transparentKey,
          child: _buildTransparentTemplate(widget.rp),
        );
        break;
      case ExportTemplate.story:
        aspectRatio = 9 / 16;
        activeTemplateWidget = RepaintBoundary(
          key: _storyKey,
          child: _buildStoryTemplate(widget.rp),
        );
        break;
      case ExportTemplate.post:
        aspectRatio = 1 / 1;
        activeTemplateWidget = RepaintBoundary(
          key: _postKey,
          child: _buildPostTemplate(widget.rp),
        );
        break;
    }

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.theme.textColor.withValues(alpha: 0.1),
          ),
          color: Colors.black26,
        ),
        clipBehavior: Clip.antiAlias,
        child: FittedBox(fit: BoxFit.contain, child: activeTemplateWidget),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomSheetBg = widget.theme.isDark
        ? const Color(0xFF151833)
        : const Color(0xFFFFF4F8);

    return Container(
      decoration: BoxDecoration(
        color: bottomSheetBg,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: widget.theme.textColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'LICENSE EXPORT STUDIO',
            style: AppTypography.body(fontSize: 16, fontWeight: FontWeight.w900, color: widget.theme.textColor).copyWith(letterSpacing: 2),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose a style and share your license card',
            style: AppTypography.body(fontSize: 12, fontWeight: FontWeight.w500, color: widget.theme.textColor.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 20),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: _buildPreviewFrame(),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Show Card Side:',
                style: AppTypography.body(fontSize: 13, fontWeight: FontWeight.bold, color: widget.theme.textColor.withValues(alpha: 0.7)),
              ),
              Row(
                children: [
                  _exportSideButton(
                    label: 'Front',
                    isActive: _exportFront,
                    onTap: () => setState(() => _exportFront = true),
                  ),
                  const SizedBox(width: 8),
                  _exportSideButton(
                    label: 'Back',
                    isActive: !_exportFront,
                    onTap: () => setState(() => _exportFront = false),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _templateTab(
                  type: ExportTemplate.transparent,
                  title: 'Card Only',
                  icon: Icons.filter_none_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _templateTab(
                  type: ExportTemplate.story,
                  title: 'Story 9:16',
                  icon: Icons.stay_current_portrait_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _templateTab(
                  type: ExportTemplate.post,
                  title: 'Post 1:1',
                  icon: Icons.crop_square_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: (_isSaving || _isSharing) ? null : _saveToDevice,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : const Icon(Icons.save_alt_rounded, size: 20),
                    label: Text(
                      _isSaving ? 'Saving...' : 'Save Photo',
                      style: AppTypography.body(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: widget.theme.accentColor,
                      side: BorderSide(
                        color: widget.theme.accentColor,
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: (_isSaving || _isSharing) ? null : _shareImage,
                    icon: _isSharing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Icon(Icons.share_rounded, size: 20),
                    label: Text(
                      _isSharing ? 'Sharing...' : 'Share',
                      style: AppTypography.body(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.theme.accentColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _exportSideButton({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? widget.theme.accentColor
              : widget.theme.textColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? widget.theme.accentColor
                : widget.theme.textColor.withValues(alpha: 0.1),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.body(fontSize: 12, fontWeight: FontWeight.bold, color: isActive
                ? Colors.white
                : widget.theme.textColor.withValues(alpha: 0.7)),
        ),
      ),
    );
  }

  Widget _templateTab({
    required ExportTemplate type,
    required String title,
    required IconData icon,
  }) {
    final isSelected = _selectedTemplate == type;
    return GestureDetector(
      onTap: () => setState(() => _selectedTemplate = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? widget.theme.accentColor.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? widget.theme.accentColor
                : widget.theme.textColor.withValues(alpha: 0.15),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? widget.theme.accentColor
                  : widget.theme.textColor.withValues(alpha: 0.6),
              size: 20,
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: AppTypography.body(fontSize: 11, fontWeight: FontWeight.bold, color: isSelected
                    ? widget.theme.accentColor
                    : widget.theme.textColor),
            ),
          ],
        ),
      ),
    );
  }
}
