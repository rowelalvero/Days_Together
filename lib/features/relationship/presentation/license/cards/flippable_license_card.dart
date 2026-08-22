import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:days_together/features/relationship/presentation/license/cards/license_back.dart';
import 'package:days_together/features/relationship/presentation/license/cards/license_front.dart';

/// The relationship license's flip animation between its front
/// (`LicenseFront`) and back (`LicenseBack`) faces. Extracted out of
/// relationship_license_screen.dart (Migration Phase 8).
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
  State<FlippableLicenseCard> createState() => FlippableLicenseCardState();
}

class FlippableLicenseCardState extends State<FlippableLicenseCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _flipController;

  late Animation<double> _flipAnimation;

  bool showingFront = true;

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

  void flipCard() {
    if (_flipController.isAnimating) return;

    if (showingFront) {
      _flipController.forward();
    } else {
      _flipController.reverse();
    }

    setState(() => showingFront = !showingFront);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: flipCard,

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
                ? LicenseFront(
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

                    child: LicenseBack(
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
