import 'dart:io';
import 'package:flutter/material.dart';
import 'package:days_together/providers/theme_provider.dart';
import 'package:days_together/providers/vault_provider.dart';
import 'package:provider/provider.dart';
import 'package:days_together/themes/app_typography.dart';

class VaultScreen extends StatelessWidget {
  const VaultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vault = context.watch<VaultProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final theme = themeProvider.currentLoveTheme;

    if (vault.isDecoyMode) {
      return _DecoyWeatherScreen(
        onReset: () => vault.resetDecoy(),
      );
    }

    if (!vault.hasPin) {
      return _SetPinScreen(theme: theme, gradient: themeProvider.currentGradient);
    }

    if (!vault.isUnlocked) {
      return _PinEntryScreen(theme: theme, gradient: themeProvider.currentGradient);
    }

    return _VaultContentScreen(theme: theme, gradient: themeProvider.currentGradient);
  }
}

// ── PIN SETUP ──
class _SetPinScreen extends StatefulWidget {
  final dynamic theme;
  final LinearGradient gradient;
  const _SetPinScreen({required this.theme, required this.gradient});

  @override
  State<_SetPinScreen> createState() => _SetPinScreenState();
}

class _SetPinScreenState extends State<_SetPinScreen> {
  String _pin = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(gradient: widget.gradient),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back_ios_new_rounded, color: widget.theme.textColor),
                  ),
                ],
              ),
              const Spacer(),
              Icon(Icons.lock_outline_rounded, color: widget.theme.textColor, size: 48),
              const SizedBox(height: 20),
              Text(
                'Create Your Secret PIN',
                style: AppTypography.cormorant(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: widget.theme.textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Keep your private memories, letters, and photos secure.',
                style: AppTypography.body(color: widget.theme.textColor.withValues(alpha: 0.6)),
              ),
              const SizedBox(height: 40),
              _buildPinDots(_pin, textColor: widget.theme.textColor),
              const SizedBox(height: 40),
              _buildKeypad(
                onDigit: (d) {
                  if (_pin.length < 4) setState(() => _pin += d);
                  if (_pin.length == 4) {
                    context.read<VaultProvider>().setPin(_pin);
                  }
                },
                onDelete: () {
                  if (_pin.isNotEmpty) {
                    setState(() => _pin = _pin.substring(0, _pin.length - 1));
                  }
                },
                textColor: widget.theme.textColor,
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

// ── PIN ENTRY ──
class _PinEntryScreen extends StatefulWidget {
  final dynamic theme;
  final LinearGradient gradient;
  const _PinEntryScreen({required this.theme, required this.gradient});

  @override
  State<_PinEntryScreen> createState() => _PinEntryScreenState();
}

class _PinEntryScreenState extends State<_PinEntryScreen> {
  String _pin = '';
  bool _error = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(gradient: widget.gradient),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back_ios_new_rounded, color: widget.theme.textColor),
                  ),
                ],
              ),
              const Spacer(),
              Icon(Icons.lock_outline_rounded, color: widget.theme.textColor, size: 48),
              const SizedBox(height: 20),
              Text(
                'Enter your Secret PIN',
                style: AppTypography.cormorant(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: widget.theme.textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error ? '❌ Incorrect PIN. Please try again.' : 'This keeps your private memories safe.',
                style: AppTypography.body(
                  color: _error ? Colors.redAccent : widget.theme.textColor.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 40),
              _buildPinDots(_pin, isError: _error, textColor: widget.theme.textColor),
              const SizedBox(height: 40),
              _buildKeypad(
                onDigit: (d) async {
                  if (_pin.length < 4) {
                    setState(() {
                      _pin += d;
                      _error = false;
                    });
                  }
                  if (_pin.length == 4) {
                    final success = await context.read<VaultProvider>().verifyPin(_pin);
                    if (!success && mounted) {
                      setState(() {
                        _error = true;
                        _pin = '';
                      });
                    }
                  }
                },
                onDelete: () {
                  if (_pin.isNotEmpty) {
                    setState(() => _pin = _pin.substring(0, _pin.length - 1));
                  }
                },
                textColor: widget.theme.textColor,
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

// ── VAULT CONTENT ──
class _VaultContentScreen extends StatelessWidget {
  final dynamic theme;
  final LinearGradient gradient;
  const _VaultContentScreen({required this.theme, required this.gradient});

  @override
  Widget build(BuildContext context) {
    final vault = context.watch<VaultProvider>();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          decoration: BoxDecoration(gradient: gradient),
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          vault.lock();
                          Navigator.pop(context);
                        },
                        icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.textColor),
                      ),
                      Expanded(
                        child: Text(
                          '🔒 The Vault',
                          style: AppTypography.cormorant(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: theme.textColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          vault.lock();
                        },
                        icon: Icon(Icons.lock_rounded, color: theme.textColor, size: 20),
                      ),
                    ],
                  ),
                ),
                TabBar(
                  indicatorColor: theme.accentColor,
                  labelColor: theme.textColor,
                  unselectedLabelColor: theme.textColor.withValues(alpha: 0.5),
                  tabs: const [
                    Tab(text: '📸 Photos'),
                    Tab(text: '💌 Letters'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildPhotosTab(context, vault),
                      _buildLettersTab(context, vault),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotosTab(BuildContext context, VaultProvider vault) {
    if (vault.photos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library_outlined, size: 48, color: theme.textColor.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text('Nothing here yet.', style: AppTypography.body(color: theme.textColor.withValues(alpha: 0.5))),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => vault.addPhoto(context),
              icon: const Icon(Icons.add_photo_alternate_rounded),
              label: Text('Add Photo', style: AppTypography.button(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.accentColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: vault.photos.length,
              itemBuilder: (context, index) {
                final item = vault.photos[index];
                return GestureDetector(
                  onLongPress: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: theme.primaryColor,
                        title: Text('Delete Photo?', style: AppTypography.cardTitle(color: theme.textColor)),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: AppTypography.button(color: theme.textColor.withValues(alpha: 0.5)))),
                          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Delete', style: AppTypography.button(color: Colors.red))),
                        ],
                      ),
                    );
                    if (confirmed == true) vault.deleteItem(item.id);
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: item.imagePath != null && File(item.imagePath!).existsSync()
                        ? Image.file(File(item.imagePath!), fit: BoxFit.cover)
                        : (item.imageUrl != null
                            ? Image.network(
                                item.imageUrl!,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return const Center(child: CircularProgressIndicator());
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return const Center(child: Icon(Icons.broken_image, color: Colors.grey));
                                },
                              )
                            : Container(color: Colors.grey)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => vault.addPhoto(context),
              icon: const Icon(Icons.add_photo_alternate_rounded),
              label: Text('Add Photo', style: AppTypography.button(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.accentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLettersTab(BuildContext context, VaultProvider vault) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: vault.letters.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.mail_outline_rounded, size: 48, color: theme.textColor.withValues(alpha: 0.3)),
                        const SizedBox(height: 16),
                        Text('No love letters yet.', style: AppTypography.body(color: theme.textColor.withValues(alpha: 0.5))),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: vault.letters.length,
                    itemBuilder: (context, index) {
                      final letter = vault.letters[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.textColor.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: theme.textColor.withValues(alpha: 0.1)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              letter.content ?? '',
                              style: AppTypography.lora(
                                color: theme.textColor,
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                                height: 1.5,
                              ),
                              maxLines: 5,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                  onPressed: () => vault.deleteItem(letter.id),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showWriteLetterDialog(context, vault),
              icon: const Icon(Icons.edit_rounded),
              label: Text('Write a Letter', style: AppTypography.button(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.accentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showWriteLetterDialog(BuildContext context, VaultProvider vault) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.primaryColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '💌 Write a Love Letter',
              style: AppTypography.cardTitle(
                color: theme.textColor,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 8,
              style: AppTypography.lora(color: theme.textColor),
              decoration: InputDecoration(
                hintText: 'Dear love...',
                hintStyle: AppTypography.lora(color: theme.textColor.withValues(alpha: 0.3)),
                filled: true,
                fillColor: theme.textColor.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: theme.textColor.withValues(alpha: 0.1)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (controller.text.trim().isNotEmpty) {
                    vault.addLetter(controller.text.trim());
                    Navigator.pop(ctx);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.accentColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('Save Letter', style: AppTypography.button(color: Colors.white, fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── DECOY WEATHER SCREEN ──
class _DecoyWeatherScreen extends StatelessWidget {
  final VoidCallback onReset;
  const _DecoyWeatherScreen({required this.onReset});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF4A90D9), Color(0xFF87CEEB)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                  ),
                ],
              ),
              const Spacer(),
              GestureDetector(
                onLongPress: () {
                  onReset();
                  Navigator.pop(context);
                },
                child: const Icon(Icons.wb_sunny_rounded, size: 80, color: Colors.yellow),
              ),
              const SizedBox(height: 20),
              Text(
                '28°C',
                style: AppTypography.body(fontSize: 60, fontWeight: FontWeight.w200, color: Colors.white),
              ),
              Text(
                'Sunny',
                style: AppTypography.body(fontSize: 20, color: Colors.white70),
              ),
              const SizedBox(height: 10),
              Text(
                'Manila, Philippines',
                style: AppTypography.body(fontSize: 16, color: Colors.white54),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

// ── SHARED WIDGETS ──
Widget _buildPinDots(String pin, {bool isError = false, Color textColor = Colors.white}) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: List.generate(4, (index) {
      final filled = index < pin.length;
      return Container(
        width: 16,
        height: 16,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: filled
              ? (isError ? Colors.redAccent : textColor)
              : Colors.transparent,
          border: Border.all(
            color: isError ? Colors.redAccent : textColor.withValues(alpha: 0.5),
            width: 2,
          ),
        ),
      );
    }),
  );
}

Widget _buildKeypad({
  required Function(String) onDigit,
  required VoidCallback onDelete,
  required Color textColor,
}) {
  final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '⌫'];
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 60),
    child: GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 15,
        crossAxisSpacing: 15,
      ),
      itemCount: keys.length,
      itemBuilder: (context, index) {
        final key = keys[index];
        if (key.isEmpty) return const SizedBox();
        return GestureDetector(
          onTap: () {
            if (key == '⌫') {
              onDelete();
            } else {
              onDigit(key);
            }
          },
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: textColor.withValues(alpha: 0.08),
            ),
            child: Center(
              child: Text(
                key,
                style: AppTypography.body(
                  color: textColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
