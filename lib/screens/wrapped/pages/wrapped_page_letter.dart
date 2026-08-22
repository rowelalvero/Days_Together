import 'package:flutter/material.dart';
import 'package:days_together/screens/wrapped/wrapped_data.dart';
import 'package:days_together/screens/wrapped/wrapped_service.dart';
import 'package:days_together/themes/app_typography.dart';

class WrappedPageLetter extends StatefulWidget {
  final WrappedData data;
  const WrappedPageLetter({super.key, required this.data});

  @override
  State<WrappedPageLetter> createState() => _WrappedPageLetterState();
}

class _WrappedPageLetterState extends State<WrappedPageLetter>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _headerAnim;
  late Animation<double> _bodyAnim;
  late Animation<double> _signatureAnim;
  late String _letter;

  @override
  void initState() {
    super.initState();
    _letter = WrappedService.generateLetter(widget.data);
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..forward();
    _headerAnim = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
    );
    _bodyAnim = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.25, 0.80, curve: Curves.easeOut),
    );
    _signatureAnim = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.70, 1.0, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final yourName = widget.data.yourName;
    final partnerName = widget.data.partnerDisplayName;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(36, 24, 36, 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            // Header
            FadeTransition(
              opacity: _headerAnim,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'A Letter',
                    style: AppTypography.display(
                      fontSize: 40,
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Dear $yourName & $partnerName,',
                    style: AppTypography.cormorant(
                      fontSize: 22,
                      color: Colors.white.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w400,
                    ).copyWith(fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Divider
            FadeTransition(
              opacity: _headerAnim,
              child: Divider(
                  color: Colors.white.withValues(alpha: 0.15), thickness: 1),
            ),
            const SizedBox(height: 28),
            // Body
            FadeTransition(
              opacity: _bodyAnim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.06),
                  end: Offset.zero,
                ).animate(_bodyAnim),
                child: Text(
                  _letter,
                  style: AppTypography.cormorant(
                    fontSize: 18,
                    color: Colors.white.withValues(alpha: 0.88),
                    fontWeight: FontWeight.w400,
                    height: 1.85,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 36),
            // Signature
            FadeTransition(
              opacity: _signatureAnim,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Divider(
                      color: Colors.white.withValues(alpha: 0.1),
                      thickness: 1),
                  const SizedBox(height: 20),
                  Text(
                    'With love,',
                    style: AppTypography.cormorant(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w400,
                    ).copyWith(fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Days Together ❤️',
                    style: AppTypography.heading(
                      fontSize: 22,
                      color: Colors.white.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
