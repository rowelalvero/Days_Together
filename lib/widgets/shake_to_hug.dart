import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:provider/provider.dart';
import 'package:days_together/providers/relationship_provider.dart';
import 'package:days_together/themes/app_typography.dart';

class ShakeToHugWrapper extends StatefulWidget {
  final Widget child;

  const ShakeToHugWrapper({super.key, required this.child});

  @override
  State<ShakeToHugWrapper> createState() => _ShakeToHugWrapperState();
}

class _ShakeToHugWrapperState extends State<ShakeToHugWrapper> with SingleTickerProviderStateMixin {
  StreamSubscription? _subscription;
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  bool _isHugActive = false;
  static const double _shakeThreshold = 18.0; // Acceleration threshold

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );

    _listenToShake();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _listenToShake() {
    _subscription = accelerometerEventStream().listen((AccelerometerEvent event) {
      if (_isHugActive) return;

      final double acceleration = sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );

      if (acceleration > _shakeThreshold) {
        _triggerHug();
      }
    });
  }

  void _triggerHug() {
    setState(() {
      _isHugActive = true;
    });
    _animController.forward().then((_) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _animController.reverse().then((_) {
            if (mounted) {
              setState(() {
                _isHugActive = false;
              });
            }
          });
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final rp = context.watch<RelationshipProvider>();

    return Stack(
      children: [
        widget.child,
        if (_isHugActive)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.8),
              child: Center(
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
                    margin: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10122B),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.pinkAccent.withValues(alpha: 0.3)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.pinkAccent.withValues(alpha: 0.2),
                          blurRadius: 20,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '🤗',
                          style: AppTypography.body(fontSize: 80),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Virtual Hug Sent!',
                          style: AppTypography.sectionHeader(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'You sent a warm squeeze to ${rp.partnerName ?? 'Partner'}!',
                          textAlign: TextAlign.center,
                          style: AppTypography.body(
                            color: Colors.white70,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
