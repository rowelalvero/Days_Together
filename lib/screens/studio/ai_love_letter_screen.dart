import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:days_together/providers/theme_provider.dart';
import 'package:days_together/providers/timeline_provider.dart';
import 'package:days_together/providers/vault_provider.dart';
import 'package:days_together/services/ai_service.dart';
import 'package:days_together/themes/app_typography.dart';

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
        const SnackBar(content: Text('Please select a memory to inspire your love letter.')),
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
          SnackBar(content: const Text('We couldn\'t generate your letter. Please check your connection and try again.')),
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
          title: Text('Vault Locked', style: AppTypography.cardTitle(color: theme.textColor)),
          content: Text(
            'Please set up a Secret Vault PIN under the Together tab first to save your letters securely.',
            style: AppTypography.body(color: theme.textColor.withValues(alpha: 0.7)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Okay', style: AppTypography.button(color: theme.accentColor)),
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
            title: Text('Enter Vault PIN', style: AppTypography.cardTitle(color: theme.textColor)),
            content: TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              style: AppTypography.bodyMono(color: theme.textColor, fontSize: 24).copyWith(letterSpacing: 16),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                counterText: '',
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: theme.textColor.withValues(alpha: 0.38))),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: theme.accentColor)),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text('Cancel', style: AppTypography.button(color: theme.textColor.withValues(alpha: 0.7))),
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
                        content: Text('🔒 Saved securely to your Secret Vault!'),
                        backgroundColor: Colors.pinkAccent,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Incorrect PIN. Please try again.'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                },
                child: Text('Unlock & Save', style: AppTypography.button(color: theme.accentColor)),
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
          content: Text('🔒 Saved securely to your Secret Vault!'),
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
                  _buildAppBar(context, theme),
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

  Widget _buildAppBar(BuildContext context, dynamic theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.textColor),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Love Letter Writer',
                  style: AppTypography.cormorant(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: theme.textColor,
                  ),
                ),
                Text(
                  'Transform your shared memories into a beautiful letter.',
                  style: AppTypography.spectral(
                    fontSize: 12,
                    color: theme.textColor.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
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
            Icon(Icons.palette_outlined, size: 64, color: theme.textColor.withValues(alpha: 0.3)),
            const SizedBox(height: 24),
            Text(
              'No memories logged yet',
              style: AppTypography.cardTitle(color: theme.textColor),
            ),
            const SizedBox(height: 8),
            Text(
              'Share a memory in the Timeline first, and we\'ll help you turn it into a beautiful love letter.',
              textAlign: TextAlign.center,
              style: AppTypography.body(color: theme.textColor.withValues(alpha: 0.54)),
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
        color: theme.textColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.textColor.withValues(alpha: 0.1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedMemoryId,
          dropdownColor: theme.primaryColor,
          isExpanded: true,
          icon: Icon(Icons.arrow_drop_down, color: theme.textColor),
          items: memories.map((m) {
            return DropdownMenuItem<String>(
              value: m.id,
              child: Row(
                children: [
                  Text(m.mood, style: AppTypography.body(fontSize: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      m.title,
                      style: AppTypography.body(color: theme.textColor),
                      overflow: TextOverflow.ellipsis,
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
          label: Text(
            'Write Love Letter',
            style: AppTypography.button(color: Colors.white, fontSize: 16),
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
            CircularProgressIndicator(color: theme.accentColor),
            const SizedBox(height: 24),
            Text(
              '✍️ Writing your love story...',
              style: AppTypography.body(
                color: theme.textColor.withValues(alpha: 0.7),
                fontSize: 16,
              ).copyWith(fontStyle: FontStyle.italic),
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
        color: theme.textColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: theme.textColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: Icon(Icons.copy_rounded, color: theme.textColor.withValues(alpha: 0.7)),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _generatedLetter!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied to clipboard!')),
                  );
                },
              ),
              IconButton(
                icon: Icon(Icons.share_rounded, color: theme.textColor.withValues(alpha: 0.7)),
                onPressed: () {
                  Share.share(_generatedLetter!);
                },
              ),
              IconButton(
                icon: Icon(Icons.lock_outline_rounded, color: theme.textColor.withValues(alpha: 0.7)),
                onPressed: () => _saveToVault(context, theme),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _generatedLetter!,
            style: AppTypography.lora(
              fontSize: 16,
              height: 1.6,
              color: theme.textColor.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
