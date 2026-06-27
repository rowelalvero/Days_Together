import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:days_together/providers/theme_provider.dart';
import 'package:days_together/providers/bucket_list_provider.dart';
import 'package:days_together/models/bucket_list_model.dart';
import 'package:confetti/confetti.dart';
import 'package:days_together/themes/app_typography.dart';

import 'package:intl/intl.dart';

class BucketListScreen extends StatefulWidget {
  const BucketListScreen({super.key});

  @override
  State<BucketListScreen> createState() => _BucketListScreenState();
}

class _BucketListScreenState extends State<BucketListScreen> {
  late ConfettiController _confettiController;
  final TextEditingController _textController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _showAddItemSheet(BuildContext context, {BucketListItem? existingItem}) {
    _textController.text = existingItem?.title ?? '';
    _selectedDate = existingItem?.scheduledAt;
    _selectedTime = existingItem?.scheduledAt != null ? TimeOfDay.fromDateTime(existingItem!.scheduledAt!) : null;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final themeProvider = context.watch<ThemeProvider>();
        final theme = themeProvider.currentLoveTheme;

        return StatefulBuilder(builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: theme.primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
                border: Border.all(color: theme.textColor.withValues(alpha: 0.1)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        existingItem == null ? '✨ Add New Adventure' : '📝 Edit Adventure',
                        style: AppTypography.cardTitle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: theme.textColor,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: theme.textColor.withValues(alpha: 0.7)),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _textController,
                    autofocus: true,
                    style: AppTypography.body(color: theme.textColor),
                    decoration: InputDecoration(
                      hintText: 'e.g. Watch the sunset in Santorini 🌅',
                      hintStyle: AppTypography.body(color: theme.textColor.withValues(alpha: 0.3)),
                      filled: true,
                      fillColor: theme.textColor.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(color: theme.textColor.withValues(alpha: 0.1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(color: theme.accentColor),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final now = DateTime.now();
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate ?? now,
                              firstDate: now,
                              lastDate: DateTime(now.year + 50),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: ColorScheme.fromSeed(
                                      seedColor: theme.accentColor,
                                      brightness: theme.isDark ? Brightness.dark : Brightness.light,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) {
                              setModalState(() {
                                _selectedDate = picked;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            decoration: BoxDecoration(
                              color: theme.textColor.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: theme.textColor.withValues(alpha: 0.1)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    _selectedDate == null
                                        ? 'Set a Date'
                                        : DateFormat('MMM dd, yyyy').format(_selectedDate!),
                                    style: AppTypography.body(
                                      color: _selectedDate == null
                                          ? theme.textColor.withValues(alpha: 0.3)
                                          : theme.textColor,
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (_selectedDate != null)
                                  GestureDetector(
                                    onTap: () => setModalState(() {
                                      _selectedDate = null;
                                      _selectedTime = null;
                                    }),
                                    child: Icon(Icons.clear, size: 18, color: theme.textColor.withValues(alpha: 0.38)),
                                  )
                                else
                                  Icon(Icons.calendar_month, size: 18, color: theme.textColor.withValues(alpha: 0.7)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (_selectedDate != null) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: _selectedTime ?? TimeOfDay.now(),
                                builder: (context, child) {
                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: ColorScheme.fromSeed(
                                        seedColor: theme.accentColor,
                                        brightness: theme.isDark ? Brightness.dark : Brightness.light,
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (picked != null) {
                                setModalState(() {
                                  _selectedTime = picked;
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              decoration: BoxDecoration(
                                color: theme.textColor.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: theme.textColor.withValues(alpha: 0.1)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      _selectedTime == null
                                          ? 'Set Time'
                                          : _selectedTime!.format(context),
                                      style: AppTypography.body(
                                        color: _selectedTime == null
                                            ? theme.textColor.withValues(alpha: 0.3)
                                            : theme.textColor,
                                        fontSize: 14,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (_selectedTime != null)
                                    GestureDetector(
                                      onTap: () => setModalState(() => _selectedTime = null),
                                      child: Icon(Icons.clear, size: 18, color: theme.textColor.withValues(alpha: 0.38)),
                                    )
                                  else
                                    Icon(Icons.access_time_rounded, size: 18, color: theme.textColor.withValues(alpha: 0.7)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_textController.text.trim().isNotEmpty) {
                          DateTime? scheduledAt;
                          if (_selectedDate != null) {
                            scheduledAt = DateTime(
                              _selectedDate!.year,
                              _selectedDate!.month,
                              _selectedDate!.day,
                              _selectedTime?.hour ?? 0,
                              _selectedTime?.minute ?? 0,
                            );
                          }

                          if (existingItem == null) {
                            context.read<BucketListProvider>().addItem(
                                  _textController.text.trim(),
                                  scheduledAt: scheduledAt,
                                );
                          } else {
                            context.read<BucketListProvider>().updateItem(
                                  existingItem.id,
                                  title: _textController.text.trim(),
                                  scheduledAt: scheduledAt,
                                  clearDate: scheduledAt == null,
                                );
                          }
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.accentColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: Text(
                        existingItem == null ? 'Add to List' : 'Update Adventure',
                        style: AppTypography.button(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final theme = themeProvider.currentLoveTheme;
    final bucketProvider = context.watch<BucketListProvider>();

    return Scaffold(
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(gradient: themeProvider.currentGradient),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(context, theme, bucketProvider),
                _buildProgressCard(theme, bucketProvider),
                Expanded(
                  child: bucketProvider.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : bucketProvider.items.isEmpty
                          ? _buildEmptyState(theme)
                          : _buildListView(bucketProvider, theme),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [Colors.pink, Colors.red, Colors.orange, Colors.amber, Colors.lightBlue],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddItemSheet(context),
        backgroundColor: theme.accentColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, dynamic theme, BucketListProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.textColor),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Our Bucket List',
                style: AppTypography.cormorant(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: theme.textColor,
                ),
              ),
              Text(
                'Dreams we promise to live together.',
                style: AppTypography.spectral(
                  fontSize: 12,
                  color: theme.textColor.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(dynamic theme, BucketListProvider provider) {
    if (provider.totalItems == 0) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.textColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.textColor.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${provider.completedItems} of ${provider.totalItems} adventures completed',
                  style: AppTypography.body(
                    color: theme.textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: provider.progress,
                    minHeight: 10,
                    backgroundColor: theme.textColor.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(theme.accentColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 50,
                height: 50,
                child: CircularProgressIndicator(
                  value: provider.progress,
                  strokeWidth: 4,
                  backgroundColor: theme.textColor.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(theme.accentColor),
                ),
              ),
              Text(
                '${(provider.progress * 100).toInt()}%',
                style: AppTypography.caption(
                  color: theme.textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildListView(BucketListProvider provider, dynamic theme) {
    return Theme(
      data: ThemeData(
        canvasColor: Colors.transparent,
      ),
      child: ReorderableListView.builder(
        itemCount: provider.items.length,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
        onReorder: provider.reorderItems,
        itemBuilder: (context, index) {
          final item = provider.items[index];
          return _buildListItem(item, theme, provider);
        },
      ),
    );
  }

  Widget _buildListItem(BucketListItem item, dynamic theme, BucketListProvider provider) {
    return Container(
      key: ValueKey(item.id),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.textColor.withValues(alpha: item.isCompleted ? 0.02 : 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: item.isCompleted 
              ? theme.accentColor.withValues(alpha: 0.2) 
              : theme.textColor.withValues(alpha: 0.1),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: GestureDetector(
          onTap: () {
            provider.toggleItem(item.id);
            if (!item.isCompleted) {
              _confettiController.play();
            }
          },
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: item.isCompleted ? theme.accentColor : theme.textColor.withValues(alpha: 0.38),
                width: 2,
              ),
              color: item.isCompleted ? theme.accentColor.withValues(alpha: 0.2) : Colors.transparent,
            ),
            child: item.isCompleted
                ? Icon(Icons.favorite, size: 16, color: theme.accentColor)
                : null,
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.title,
              style: AppTypography.body(
                color: item.isCompleted ? theme.textColor.withValues(alpha: 0.54) : theme.textColor,
                fontSize: 16,
                fontWeight: item.isCompleted ? FontWeight.normal : FontWeight.w500,
              ).copyWith(
                decoration: item.isCompleted ? TextDecoration.lineThrough : null,
              ),
            ),
            if (item.scheduledAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 10, color: theme.accentColor.withValues(alpha: 0.7)),
                    const SizedBox(width: 4),
                    Text(
                      '${DateFormat('MMM dd, yyyy').format(item.scheduledAt!)}${item.scheduledAt!.hour != 0 || item.scheduledAt!.minute != 0 ? ' at ${DateFormat.jm().format(item.scheduledAt!)}' : ''}',
                      style: AppTypography.caption(
                        fontSize: 11,
                        color: theme.accentColor.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.edit_outlined, color: theme.textColor.withValues(alpha: 0.38)),
              onPressed: () => _showAddItemSheet(context, existingItem: item),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, color: theme.textColor.withValues(alpha: 0.38)),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: theme.primaryColor,
                    title: Text('Delete Adventure?', style: AppTypography.cardTitle(color: theme.textColor)),
                    content: Text(
                      'Are you sure you want to remove this dream from your bucket list?',
                      style: AppTypography.body(color: theme.textColor.withValues(alpha: 0.7)),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Cancel', style: AppTypography.button(color: theme.textColor.withValues(alpha: 0.7))),
                      ),
                      TextButton(
                        onPressed: () {
                          provider.deleteItem(item.id);
                          Navigator.pop(context);
                        },
                        child: Text('Delete', style: AppTypography.button(color: theme.accentColor)),
                      ),
                    ],
                  ),
                );
              },
            ),
            Icon(Icons.drag_indicator_rounded, color: theme.textColor.withValues(alpha: 0.38)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(dynamic theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.textColor.withValues(alpha: 0.03),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.hotel_class_outlined,
                size: 64,
                color: theme.accentColor.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Dream big.',
              style: AppTypography.pageTitle(
                color: theme.textColor,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first adventure together.',
              textAlign: TextAlign.center,
              style: AppTypography.spectral(
                color: theme.textColor.withValues(alpha: 0.5),
                fontSize: 15,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
