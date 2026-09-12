import 'package:days_together/app/theme/theme_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:days_together/features/theme/theme_controller.dart';
import 'package:days_together/features/timeline/timeline_controller.dart';
import 'package:days_together/features/love_studio/data/ai_service.dart';
import 'package:days_together/features/love_studio/presentation/widgets/generate_letter_button.dart';
import 'package:days_together/features/love_studio/presentation/widgets/generating_letter_state.dart';
import 'package:days_together/features/love_studio/presentation/widgets/love_letter_app_bar.dart';
import 'package:days_together/features/love_studio/presentation/widgets/love_letter_card.dart';
import 'package:days_together/features/love_studio/presentation/widgets/memory_dropdown.dart';
import 'package:days_together/features/love_studio/presentation/widgets/no_memories_state.dart';

/// Turns a chosen timeline memory into an AI-authored love letter.
///
/// Its inline app bar, empty state, memory dropdown, action button,
/// generating state, and letter card were extracted into widgets under
/// `presentation/widgets/` (Migration audit item 6) -- this class still
/// owns the selected-memory/generating/generated-letter state and the
/// generation flow itself.
class AILoveLetterScreen extends ConsumerStatefulWidget {
  const AILoveLetterScreen({super.key});

  @override
  ConsumerState<AILoveLetterScreen> createState() => _AILoveLetterScreenState();
}

class _AILoveLetterScreenState extends ConsumerState<AILoveLetterScreen> {
  String? _selectedMemoryId;
  bool _isGenerating = false;
  String? _generatedLetter;

  void _generateLetter(LoveStoryTheme theme) async {
    final timelineProvider = ref.read(timelineControllerProvider);
    if (_selectedMemoryId == null && timelineProvider.items.isNotEmpty) {
      _selectedMemoryId = timelineProvider.items.first.id;
    }

    if (_selectedMemoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a memory to inspire your love letter.'),
        ),
      );
      return;
    }

    final selectedMemory = timelineProvider.items.firstWhere(
      (item) => item.id == _selectedMemoryId,
    );

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
          SnackBar(
            content: const Text(
              'We couldn\'t generate your letter. Please check your connection and try again.',
            ),
          ),
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

  @override
  Widget build(BuildContext context) {
    final themeProvider = ref.watch(themeControllerProvider);
    final theme = themeProvider.currentLoveTheme;
    final timelineProvider = ref.watch(timelineControllerProvider);
    final memories = timelineProvider.items;

    if (_selectedMemoryId == null && memories.isNotEmpty) {
      _selectedMemoryId = memories.first.id;
    }

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
                  LoveLetterAppBar(theme: theme),
                  const SizedBox(height: 12),
                  if (memories.isEmpty)
                    NoMemoriesState(theme: theme)
                  else ...[
                    MemoryDropdown(
                      memories: memories,
                      selectedMemoryId: _selectedMemoryId,
                      onChanged: (val) =>
                          setState(() => _selectedMemoryId = val),
                      theme: theme,
                    ),
                    const SizedBox(height: 24),
                    GenerateLetterButton(
                      onPressed: () => _generateLetter(theme),
                      theme: theme,
                    ),
                    const SizedBox(height: 24),
                    if (_isGenerating)
                      GeneratingLetterState(theme: theme)
                    else if (_generatedLetter != null)
                      LoveLetterCard(letter: _generatedLetter!, theme: theme),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
