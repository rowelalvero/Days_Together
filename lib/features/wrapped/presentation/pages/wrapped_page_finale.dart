import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:confetti/confetti.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:days_together/features/wrapped/domain/wrapped_data.dart';
import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/features/wrapped/presentation/widgets/wrapped_share_card.dart';

class WrappedPageFinale extends StatefulWidget {
  final WrappedData data;
  final VoidCallback onReplay;

  const WrappedPageFinale({
    super.key,
    required this.data,
    required this.onReplay,
  });

  @override
  State<WrappedPageFinale> createState() => _WrappedPageFinaleState();
}

class _WrappedPageFinaleState extends State<WrappedPageFinale>
    with SingleTickerProviderStateMixin {
  late ConfettiController _confetti;
  late AnimationController _pulse;
  final GlobalKey _shareKey = GlobalKey();
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 6));
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _confetti.play();
    });
  }

  @override
  void dispose() {
    _confetti.dispose();
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _shareWrapped() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    try {
      final boundary =
          _shareKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        setState(() => _isSharing = false);
        return;
      }
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        setState(() => _isSharing = false);
        return;
      }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/wrapped_${widget.data.year}.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      await Share.shareXFiles(
        [XFile(file.path)],
        text:
            '❤️ ${widget.data.yourName} & ${widget.data.partnerDisplayName} — Days Together Wrapped ${widget.data.year}',
      );
    } catch (_) {
      // Silently fail — share is optional
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Pulsing heart
                ScaleTransition(
                  scale: Tween<double>(begin: 0.9, end: 1.1).animate(
                    CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
                  ),
                  child: const Text('❤️', style: TextStyle(fontSize: 72)),
                ),
                const SizedBox(height: 28),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 800),
                  builder: (_, v, c) => Opacity(opacity: v, child: c),
                  child: Text(
                    'Thank You',
                    style: AppTypography.display(
                      fontSize: 52,
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 1000),
                  builder: (_, v, c) => Opacity(opacity: v, child: c),
                  child: Text(
                    'for making ${widget.data.year} a year\nworth remembering.',
                    style: AppTypography.cormorant(
                      fontSize: 22,
                      color: Colors.white.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w400,
                      height: 1.5,
                    ).copyWith(fontStyle: FontStyle.italic),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 12),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 1200),
                  builder: (_, v, c) => Opacity(opacity: v, child: c),
                  child: Text(
                    'See you in ${widget.data.year + 1} ✨',
                    style: AppTypography.body(
                      fontSize: 18,
                      color: Colors.white.withValues(alpha: 0.55),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 52),
                // Share card preview (off-screen render boundary)
                RepaintBoundary(
                  key: _shareKey,
                  child: WrappedShareCard(data: widget.data),
                ),
                const SizedBox(height: 32),
                // Action buttons
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 1500),
                  builder: (_, v, c) => Opacity(opacity: v, child: c),
                  child: Row(
                    children: [
                      // Replay button
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: widget.onReplay,
                          icon: const Icon(Icons.replay_rounded, size: 18),
                          label: const Text('Replay'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Share button
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: _isSharing ? null : _shareWrapped,
                          icon: _isSharing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.share_rounded, size: 18),
                          label: Text(_isSharing ? 'Sharing…' : 'Share Story'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF43F5E),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Confetti
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confetti,
            blastDirectionality: BlastDirectionality.explosive,
            particleDrag: 0.04,
            emissionFrequency: 0.06,
            numberOfParticles: 20,
            gravity: 0.15,
            colors: const [
              Color(0xFFF43F5E),
              Color(0xFF7C3AED),
              Color(0xFF06B6D4),
              Color(0xFFF59E0B),
              Colors.white,
            ],
          ),
        ),
      ],
    );
  }
}
