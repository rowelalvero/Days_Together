import 'package:flutter/material.dart';

class WidgetDeviceFrame extends StatelessWidget {
  final Widget child;

  const WidgetDeviceFrame({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1123),
        borderRadius: BorderRadius.circular(36),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Home screen mock status bar / indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '9:41',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
                  Icon(Icons.wifi, color: Colors.white.withValues(alpha: 0.6), size: 14),
                  const SizedBox(width: 4),
                  Icon(Icons.battery_full_rounded, color: Colors.white.withValues(alpha: 0.6), size: 16),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
          const SizedBox(height: 18),
          // Home bar indicator
          Container(
            width: 100,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}
