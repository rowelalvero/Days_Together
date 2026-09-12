import 'package:flutter/material.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/features/topic_cards/topic_cards_controller.dart';
import 'package:days_together/shared/widgets/glass_container.dart';

/// The bottom sheet for adding a custom topic card: a category picker and a
/// free-text question. Extracted from TopicCardsScreen's
/// `_showAddCardDialog` (Migration audit item 6) -- a proper `StatefulWidget`
/// in place of the inline `showModalBottomSheet` + `StatefulBuilder` pairing,
/// matching the pattern already used for this app's other sheets/dialogs
/// (e.g. `NoteitBackgroundDialog`).
///
/// Shown the same way those are, directly as a `showModalBottomSheet`
/// builder -- there is no `.show()` static helper by house convention.
class AddTopicCardSheet extends StatefulWidget {
  const AddTopicCardSheet({
    super.key,
    required this.theme,
    required this.notifier,
    required this.selectableCategories,
  });

  final LoveStoryTheme theme;
  final TopicCardsController notifier;

  /// The categories a custom card may be filed under -- the screen's full
  /// category list minus the two virtual ones ("All", "Favorites") that
  /// exist only as deck filters, not as a category a card can belong to.
  final List<String> selectableCategories;

  @override
  State<AddTopicCardSheet> createState() => _AddTopicCardSheetState();
}

class _AddTopicCardSheetState extends State<AddTopicCardSheet> {
  final _formKey = GlobalKey<FormState>();
  final _questionController = TextEditingController();
  late String _selectedCategory = widget.selectableCategories.first;

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    widget.notifier.addCustomCard(
      _questionController.text.trim(),
      _selectedCategory,
    );
    // Captured before the pop: this sheet's own context is deactivated by
    // Navigator.pop, but the messenger belongs to the screen underneath, so
    // it must be resolved first.
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Custom prompt added to your deck! 🃏'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: GlassContainer(
        borderRadius: 24,
        opacity: 0.15,
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Create Custom Card',
                    style: AppTypography.heading(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: theme.textColor,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: theme.textColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'CATEGORY',
                style: AppTypography.caption(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: theme.textColor.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: theme.textColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.textColor.withValues(alpha: 0.1),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCategory,
                    dropdownColor: theme.backgroundColor,
                    style: AppTypography.body(
                      color: theme.textColor,
                      fontWeight: FontWeight.bold,
                    ),
                    icon: Icon(Icons.arrow_drop_down, color: theme.accentColor),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedCategory = val);
                    },
                    items: widget.selectableCategories
                        .map(
                          (cat) => DropdownMenuItem<String>(
                            value: cat,
                            child: Text(cat),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'YOUR CONVERSATION PROMPT',
                style: AppTypography.caption(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: theme.textColor.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _questionController,
                maxLines: 4,
                style: AppTypography.body(color: theme.textColor),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please share a question or prompt.';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  hintText:
                      "e.g., What is a dream you've always wanted to share with me?",
                  hintStyle: AppTypography.body(
                    color: theme.textColor.withValues(alpha: 0.4),
                  ),
                  filled: true,
                  fillColor: theme.textColor.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: theme.textColor.withValues(alpha: 0.1),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: theme.textColor.withValues(alpha: 0.1),
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
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.accentColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                  ),
                  child: Text(
                    'Add to Deck',
                    style: AppTypography.body(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
