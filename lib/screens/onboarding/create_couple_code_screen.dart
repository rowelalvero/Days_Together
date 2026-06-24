import 'package:days_together/screens/onboarding/genesis_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/providers/theme_provider.dart';
import 'package:days_together/providers/relationship_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

class CreateCoupleCodeScreen extends StatefulWidget {
  const CreateCoupleCodeScreen({super.key});

  @override
  State<CreateCoupleCodeScreen> createState() => _CreateCoupleCodeScreenState();
}

class _CreateCoupleCodeScreenState extends State<CreateCoupleCodeScreen>
    with SingleTickerProviderStateMixin {
  late String _code;
  late AnimationController _animController;
  bool _copied = false;

  @override
  void initState() {
    super.initState();
    _code = context.read<RelationshipProvider>().generateCoupleCode();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final theme = themeProvider.currentLoveTheme;

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(gradient: themeProvider.currentGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                ),
                const SizedBox(height: 40),
                Text(
                  'Your exclusive\ncouple code.',
                  style: AppTypography.cormorant(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: theme.textColor,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Share this with your partner so they can join your story.',
                  style: AppTypography.spectral(
                    fontSize: 16,
                    color: theme.textColor.withValues(alpha: 0.7),
                  ),
                ),
                const Spacer(),
                // Code Display
                ScaleTransition(
                  scale: CurvedAnimation(
                    parent: _animController,
                    curve: Curves.elasticOut,
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: theme.accentColor.withValues(alpha: 0.3),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.accentColor.withValues(alpha: 0.15),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          _code,
                          style: AppTypography.body(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ).copyWith(letterSpacing: 12),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'This code is unique to you. Keep it safe.',
                          style: AppTypography.caption(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.5),
                          ).copyWith(fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(
                      child: _buildButton(
                        label: _copied ? '✓ Copied' : 'Copy Code',
                        icon: Icons.copy_rounded,
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _code));
                          setState(() => _copied = true);
                          Future.delayed(const Duration(seconds: 2), () {
                            if (mounted) setState(() => _copied = false);
                          });
                        },
                        isPrimary: false,
                        accentColor: theme.accentColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildButton(
                        label: 'Share',
                        icon: Icons.share_rounded,
                        onPressed: () {
                          Share.share(
                            'Join me on Our Love Story! Use my couple code: $_code 💕',
                          );
                        },
                        isPrimary: false,
                        accentColor: theme.accentColor,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const GenesisScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.accentColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 5,
                    ),
                    child: Text(
                      'Continue',
                      style: AppTypography.button(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
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

  Widget _buildButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    required bool isPrimary,
    required Color accentColor,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }
}
