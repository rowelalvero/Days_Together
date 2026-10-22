import 'package:days_together/shared/models/timeline_model.dart';
import 'package:days_together/features/theme/theme_controller.dart';
import 'package:days_together/features/timeline/timeline_controller.dart';
import 'package:days_together/features/timeline/presentation/widgets/edit_item_dialog.dart';
import 'package:days_together/features/timeline/presentation/widgets/memory_description_card.dart';
import 'package:days_together/features/timeline/presentation/widgets/memory_detail_header.dart';
import 'package:days_together/features/timeline/presentation/widgets/memory_detail_sliver_app_bar.dart';
import 'package:days_together/features/timeline/presentation/widgets/memory_notes_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The full-screen view of one timeline memory: hero image, title/date/
/// mood/location header, story text, and shared notes. Its inline
/// SliverAppBar/hero-image/header blocks were extracted into widgets under
/// `presentation/widgets/` (Migration audit item 6) -- this class now only
/// owns the scroll-to-notes behavior.
class MemoryDetailScreen extends ConsumerStatefulWidget {
  final TimelineItemData item;

  const MemoryDetailScreen({super.key, required this.item});

  @override
  ConsumerState<MemoryDetailScreen> createState() => _MemoryDetailScreenState();
}

class _MemoryDetailScreenState extends ConsumerState<MemoryDetailScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToNotes() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _openEditDialog(BuildContext context, TimelineItemData item) {
    // EditItemDialog stays a plain Navigator.push -- it's a dialog (edits
    // then closes), not a navigational destination, despite using
    // Navigator.push instead of showDialog (ADR-007's scope only covers
    // "distinct screens").
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditItemDialog(item: item)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = ref.watch(themeControllerProvider);
    final theme = themeProvider.currentLoveTheme;
    final timelineProvider = ref.watch(timelineControllerProvider);
    // itemById also covers a memory loaded outside the page window (e.g.
    // opened from a notification), so live edits show for it too.
    final currentItem =
        timelineProvider.itemById(widget.item.id) ?? widget.item;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(gradient: themeProvider.currentGradient),
        child: Stack(
          children: [
            CustomScrollView(
              controller: _scrollController,
              slivers: [
                MemoryDetailSliverAppBar(
                  item: currentItem,
                  theme: theme,
                  onScrollToNotes: _scrollToNotes,
                  onEdit: () => _openEditDialog(context, currentItem),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MemoryDetailHeader(item: currentItem, theme: theme),
                        const SizedBox(height: 32),
                        MemoryDescriptionCard(
                          description: currentItem.description,
                          theme: theme,
                        ),
                        MemoryNotesSection(
                          item: currentItem,
                          scrollController: _scrollController,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
