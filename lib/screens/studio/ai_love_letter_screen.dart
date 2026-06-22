import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:days_together/providers/theme_provider.dart';
import 'package:days_together/providers/timeline_provider.dart';
import 'package:days_together/providers/vault_provider.dart';
import 'package:days_together/services/ai_service.dart';

class AILoveLetterScreen extends StatefulWidget {
  const AILoveLetterScreen({super.key});

  @override
  State<AILoveLetterScreen> createState() => _AILoveLetterScreenState();
}

class _AILoveLetterScreenState extends State<AILoveLetterScreen> {
  String? _selectedMemoryId;
  bool _isGenerating = false;
  String? _generatedLetter;

  void _generateLetter(dynamic theme) async {
    final timelineProvider = context.read<TimelineProvider>();
    if (_selectedMemoryId == null && timelineProvider.timelineItems.isNotEmpty) {
      _selectedMemoryId = timelineProvider.timelineItems.first.id;
    }

    if (_selectedMemoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or add a memory first.')),
      );
      return;
    }

    final selectedMemory = timelineProvider.timelineItems.firstWhere((item) => item.id == _selectedMemoryId);

    setState(() {
      _isGenerating = true;
      _generatedLetter = null;
    });

    try {
      final letter = await AIService.generateLoveLetter(
        memoryTitle: selectedMemory.title,
        mood: selectedMemory.mood,
      );
      if (mounted) {
        setState(() {
          _generatedLetter = letter;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  void _saveToVault(BuildContext context, dynamic theme) async {
    if (_generatedLetter == null) return;
    final vault = context.read<VaultProvider>();

    if (!vault.hasPin) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: theme.primaryColor,
          title: const Text('Vault Locked', style: TextStyle(color: Colors.white)),
          content: const Text(
            'You need to set up your Vault PIN under the "Together" tab first before you can save letters here.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK', style: TextStyle(color: theme.accentColor)),
            ),
          ],
        ),
      );
      return;
    }

    if (!vault.isUnlocked) {
      // Show pin verification dialog
      final pinController = TextEditingController();
      showDialog(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: theme.primaryColor,
            title: const Text('Enter Vault PIN', style: TextStyle(color: Colors.white)),
            content: TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 16),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                counterText: '',
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white38)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.pinkAccent)),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
              ),
              TextButton(
                onPressed: () async {
                  final correct = await vault.verifyPin(pinController.text);
                  if (!context.mounted) return;
                  if (correct) {
                    await vault.addLetter(_generatedLetter!);
                    if (!context.mounted) return;
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('🔒 Letter saved securely to the Vault!'),
                        backgroundColor: Colors.pinkAccent,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Incorrect PIN. Try again.'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                },
                child: Text('Unlock & Save', style: TextStyle(color: theme.accentColor)),
              ),
            ],
          );
        },
      );
    } else {
      await vault.addLetter(_generatedLetter!);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔒 Letter saved securely to the Vault!'),
          backgroundColor: Colors.pinkAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final theme = themeProvider.currentLoveTheme;
    final timelineProvider = context.watch<TimelineProvider>();
    final memories = timelineProvider.timelineItems;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(gradient: themeProvider.currentGradient),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAppBar(context),
                  const SizedBox(height: 12),
                  if (memories.isEmpty)
                    _buildNoMemoriesState(theme)
                  else ...[
                    _buildMemoryDropdown(memories, theme),
                    const SizedBox(height: 24),
                    _buildActionButtons(theme),
                    const SizedBox(height: 24),
                    if (_isGenerating)
                      _buildGeneratingState(theme)
                    else if (_generatedLetter != null)
                      _buildLetterCard(theme)
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI Love Letter',
                style: TextStyle(
                  fontFamily: 'Cormorant',
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                'Transform your shared memories into poetry.',
                style: TextStyle(
                  fontFamily: 'Spectral',
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoMemoriesState(dynamic theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          children: [
            const SizedBox(height: 40),
            Icon(Icons.palette_outlined, size: 64, color: Colors.white30),
            const SizedBox(height: 24),
            const Text(
              'No memories found!',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            const Text(
              'You need to log at least one memory in the Timeline tab to generate a love letter.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemoryDropdown(List<dynamic> memories, dynamic theme) {
    if (_selectedMemoryId == null && memories.isNotEmpty) {
      _selectedMemoryId = memories.first.id;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedMemoryId,
          dropdownColor: theme.primaryColor,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
          items: memories.map((m) {
            return DropdownMenuItem<String>(
              value: m.id,
              child: Row(
                children: [
                  Text(m.mood, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      m.title,
                      style: const TextStyle(color: Colors.white, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (val) {
            setState(() {
              _selectedMemoryId = val;
            });
          },
        ),
      ),
    );
  }

  Widget _buildActionButtons(dynamic theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: () => _generateLetter(theme),
          icon: const Icon(Icons.auto_awesome, color: Colors.white),
          label: const Text(
            'Write Love Letter',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.accentColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGeneratingState(dynamic theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            const CircularProgressIndicator(color: Colors.pinkAccent),
            const SizedBox(height: 24),
            Text(
              '✍️ Writing your love story...',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLetterCard(dynamic theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.copy_rounded, color: Colors.white70),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _generatedLetter!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied to clipboard!')),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.share_rounded, color: Colors.white70),
                onPressed: () {
                  Share.share(_generatedLetter!);
                },
              ),
              IconButton(
                icon: const Icon(Icons.lock_outline_rounded, color: Colors.white70),
                onPressed: () => _saveToVault(context, theme),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _generatedLetter!,
            style: const TextStyle(
              fontFamily: 'Lora',
              fontSize: 16,
              height: 1.6,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}
