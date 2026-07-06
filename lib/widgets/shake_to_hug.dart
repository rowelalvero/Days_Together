import 'dart:async';
import 'dart:math';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:provider/provider.dart';
import 'package:days_together/providers/relationship_provider.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/services/notification_service.dart';

class ShakeToHugWrapper extends StatefulWidget {
  final Widget child;

  const ShakeToHugWrapper({super.key, required this.child});

  @override
  State<ShakeToHugWrapper> createState() => ShakeToHugWrapperState();
}

class ShakeToHugWrapperState extends State<ShakeToHugWrapper> with TickerProviderStateMixin {
  static ShakeToHugWrapperState? activeState;

  StreamSubscription? _subscription;
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isHugActive = false;
  bool _isReceived = false;
  static const double _shakeThreshold = 18.0; // Acceleration threshold

  @override
  void initState() {
    super.initState();
    activeState = this;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    _listenToShake();
  }

  @override
  void dispose() {
    if (activeState == this) {
      activeState = null;
    }
    _subscription?.cancel();
    _animController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _listenToShake() {
    _subscription = accelerometerEventStream().listen((AccelerometerEvent event) {
      if (_isHugActive) return;

      final double acceleration = sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );

      if (acceleration > _shakeThreshold) {
        _triggerHug(isReceived: false);
      }
    });
  }

  void _triggerHug({required bool isReceived}) {
    setState(() {
      _isHugActive = true;
      _isReceived = isReceived;
    });

    _pulseController.repeat(reverse: true);

    if (!isReceived) {
      NotificationService().sendPartnerNotification(
        title: '🤗 Virtual Hug!',
        body: 'Your partner sent you a warm squeeze! Open the app to feel the hug.',
        feature: 'hug',
      );
    }

    _animController.forward().then((_) {
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted && _isHugActive) {
          _dismissHug();
        }
      });
    });
  }

  void _dismissHug() {
    _animController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _isHugActive = false;
        });
        _pulseController.stop();
      }
    });
  }

  void showReceivedHug() {
    if (_isHugActive) return;
    _triggerHug(isReceived: true);
  }

  @override
  Widget build(BuildContext context) {
    final rp = context.watch<RelationshipProvider>();

    return Stack(
      children: [
        widget.child,
        if (_isHugActive)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _dismissHug,
              child: Container(
                color: Colors.black.withValues(alpha: 0.4),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Center(
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: GestureDetector(
                        onTap: () {}, // Prevent tap from dismissing when tapping on card itself
                        child: Container(
                          width: 290,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _isReceived
                                  ? [const Color(0xFF1E264F), const Color(0xFF111536)]
                                  : [const Color(0xFF381E4F), const Color(0xFF1E1136)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: (_isReceived ? Colors.blueAccent : Colors.pinkAccent).withValues(alpha: 0.35),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (_isReceived ? Colors.blueAccent : Colors.pinkAccent).withValues(alpha: 0.15),
                                blurRadius: 24,
                                spreadRadius: 2,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 110,
                                    height: 110,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          (_isReceived ? Colors.blueAccent : Colors.pinkAccent).withValues(alpha: 0.25),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                  ScaleTransition(
                                    scale: _pulseAnimation,
                                    child: Container(
                                      width: 84,
                                      height: 84,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white.withValues(alpha: 0.08),
                                        border: Border.all(
                                          color: Colors.white.withValues(alpha: 0.15),
                                          width: 1,
                                        ),
                                      ),
                                      child: const Center(
                                        child: Text(
                                          '🫂',
                                          style: TextStyle(fontSize: 48),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    right: 4,
                                    top: 4,
                                    child: ScaleTransition(
                                      scale: _pulseAnimation,
                                      child: const Text(
                                        '❤️',
                                        style: TextStyle(fontSize: 22),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              Text(
                                _isReceived ? 'Virtual Hug Received!' : 'Virtual Hug Sent!',
                                textAlign: TextAlign.center,
                                style: AppTypography.sectionHeader(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ).copyWith(letterSpacing: -0.5),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _isReceived
                                    ? '${rp.partnerName ?? 'Partner'} sent you a warm, cozy squeeze!'
                                    : 'You sent a warm, cozy squeeze to ${rp.partnerName ?? 'Partner'}!',
                                textAlign: TextAlign.center,
                                style: AppTypography.body(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 14.5,
                                ),
                              ),
                              const SizedBox(height: 28),
                              Text(
                                'TAP ANYWHERE TO DISMISS',
                                style: AppTypography.captionMono(
                                  fontSize: 9,
                                  color: Colors.white.withValues(alpha: 0.3),
                                  fontWeight: FontWeight.w700,
                                ).copyWith(letterSpacing: 1.0),
                              ),
                            ],
                          ),
                        ),
                      ),
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
