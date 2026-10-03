import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/core/session/couple_session.dart'
    show isPlausiblePairingCode;
import 'package:days_together/features/relationship/session_controller.dart';
import 'package:days_together/features/relationship/workspace_controller.dart';
import 'package:days_together/shared/widgets/glass_container.dart';

/// The "share your code" / "join partner's code" cards shown on
/// [RelationshipProfileScreen] while waiting for a partner to join. Moved
/// out of relationship_profile_screen.dart into its own file as part of
/// Migration audit item 6 -- it was already a proper widget class, just
/// living inline in the 1000+ line screen file.
class PairingOptionsSection extends ConsumerStatefulWidget {
  const PairingOptionsSection({super.key, required this.theme});

  final LoveStoryTheme theme;

  @override
  ConsumerState<PairingOptionsSection> createState() =>
      _PairingOptionsSectionState();
}

class _PairingOptionsSectionState extends ConsumerState<PairingOptionsSection> {
  final TextEditingController _controller = TextEditingController();
  bool _isLinking = false;
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _linkCode() async {
    final code = _controller.text.trim().toUpperCase();
    if (!isPlausiblePairingCode(code)) {
      setState(() {
        _errorMessage = 'Enter the 8-character code from your partner.';
      });
      return;
    }

    setState(() {
      _isLinking = true;
      _errorMessage = null;
    });

    try {
      final success = await ref
          .read(sessionControllerProvider.notifier)
          .joinWithCode(code);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully linked with your partner! 💞'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() {
          _errorMessage =
              'Invalid connection code. Please check with your partner.';
          _isLinking = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          // Already user-facing: mapped from the RPC's error_code by
          // CoupleSession.joinWithCode (pairingFailureMessage).
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
          _isLinking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final code = ref.watch(workspaceControllerProvider).coupleCode ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Card 1: Share Your Code
        GlassContainer(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          opacity: 0.1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.share_rounded, color: theme.accentColor, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'PROVIDE YOUR CODE',
                    style: AppTypography.captionMono(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: theme.accentColor,
                    ).copyWith(letterSpacing: 1.5),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Let your partner enter this code on their device to connect.',
                style: AppTypography.body(
                  fontSize: 13,
                  color: theme.textColor.withValues(alpha: 0.6),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: theme.textColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.textColor.withValues(alpha: 0.1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      code,
                      style: AppTypography.bodyMono(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: theme.textColor,
                      ).copyWith(letterSpacing: 4),
                    ),
                    Row(
                      children: [
                        _buildIconButton(
                          icon: Icons.copy_rounded,
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: code));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Code copied to clipboard!'),
                              ),
                            );
                          },
                          theme: theme,
                        ),
                        const SizedBox(width: 8),
                        _buildIconButton(
                          icon: Icons.share_rounded,
                          onTap: () {
                            Share.share(
                              "Let's connect our Love Story! Here is my invitation code: $code 💕",
                            );
                          },
                          theme: theme,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Card 2: Enter Partner's Code
        GlassContainer(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          opacity: 0.1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.link_rounded, color: theme.accentColor, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'JOIN PARTNER\'S RELATIONSHIP',
                    style: AppTypography.captionMono(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: theme.accentColor,
                    ).copyWith(letterSpacing: 1.5),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Enter the 8-character connection code sent by your partner to link immediately.',
                style: AppTypography.body(
                  fontSize: 13,
                  color: theme.textColor.withValues(alpha: 0.6),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      maxLength: 8,
                      textCapitalization: TextCapitalization.characters,
                      style: AppTypography.bodyMono(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.textColor,
                      ).copyWith(letterSpacing: 2),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: 'CODE1234',
                        hintStyle: AppTypography.bodyMono(
                          fontSize: 18,
                          color: theme.textColor.withValues(alpha: 0.25),
                        ).copyWith(letterSpacing: 2),
                        filled: true,
                        fillColor: theme.textColor.withValues(alpha: 0.05),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: theme.textColor.withValues(alpha: 0.15),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: theme.textColor.withValues(alpha: 0.15),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: theme.accentColor,
                            width: 1.5,
                          ),
                        ),
                      ),
                      onChanged: (_) {
                        if (_errorMessage != null) {
                          setState(() {
                            _errorMessage = null;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isLinking ? null : _linkCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.accentColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: theme.accentColor.withValues(
                          alpha: 0.3,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                      ),
                      child: _isLinking
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Link',
                              style: AppTypography.body(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: AppTypography.body(
                    color: Colors.redAccent,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onTap,
    required LoveStoryTheme theme,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.accentColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: theme.accentColor, size: 18),
      ),
    );
  }
}
