import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:days_together/providers/theme_provider.dart';
import 'package:days_together/providers/time_capsule_provider.dart';
import 'package:days_together/models/time_capsule_model.dart';
import 'package:days_together/themes/app_typography.dart';

class TimeCapsuleScreen extends StatefulWidget {
  const TimeCapsuleScreen({super.key});

  @override
  State<TimeCapsuleScreen> createState() => _TimeCapsuleScreenState();
}

class _TimeCapsuleScreenState extends State<TimeCapsuleScreen> {
  final TextEditingController _messageController = TextEditingController();
  DateTime? _selectedDate;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _showCreateCapsuleSheet(BuildContext context, dynamic theme) {
    _messageController.clear();
    _selectedDate = null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '✉️ Create Time Capsule',
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
                      controller: _messageController,
                      style: AppTypography.body(color: theme.textColor),
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Write a letter, share a secret, or send a message to your future selves...\n\n"Dear future us..."',
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
                    InkWell(
                      onTap: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: now.add(const Duration(days: 7)),
                          firstDate: now.add(const Duration(days: 1)),
                          lastDate: DateTime(now.year + 50),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: ColorScheme.dark(
                                  primary: theme.accentColor,
                                  onPrimary: Colors.white,
                                  surface: theme.secondaryColor,
                                  onSurface: Colors.white,
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
                          Text(
                            _selectedDate == null
                                ? 'Select Unlock Date'
                                : DateFormat('MMMM dd, yyyy').format(_selectedDate!),
                            style: AppTypography.body(
                              color: _selectedDate == null
                                  ? theme.textColor.withValues(alpha: 0.4)
                                  : theme.textColor,
                              fontSize: 16,
                            ),
                          ),
                          Icon(Icons.calendar_today_rounded, color: theme.textColor.withValues(alpha: 0.7)),
                        ],
                      ),
                    ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          if (_messageController.text.trim().isNotEmpty && _selectedDate != null) {
                            context.read<TimeCapsuleProvider>().createCapsule(
                                  _messageController.text.trim(),
                                  _selectedDate!,
                                );
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('🔒 Time Capsule sealed and locked away!'),
                                backgroundColor: Colors.pinkAccent,
                              ),
                            );
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
                          'Seal Time Capsule',
                          style: AppTypography.button(color: Colors.white, fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showCapsuleDetailDialog(BuildContext context, TimeCapsule capsule, dynamic theme, TimeCapsuleProvider provider) {
    if (!capsule.isOpened && capsule.canOpen) {
      provider.openCapsule(capsule.id);
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.primaryColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              const Icon(Icons.drafts_rounded, color: Colors.pinkAccent),
              const SizedBox(width: 12),
              Text('Opened Capsule', style: AppTypography.cardTitle(color: theme.textColor)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Created: ${DateFormat('MMMM dd, yyyy').format(capsule.createdAt)}',
                  style: AppTypography.bodyMedium(color: theme.textColor.withValues(alpha: 0.54)),
                ),
                const SizedBox(height: 16),
                Text(
                  capsule.message,
                  style: AppTypography.lora(
                    fontSize: 16,
                    height: 1.5,
                    color: theme.textColor,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close', style: AppTypography.button(color: theme.accentColor)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final theme = themeProvider.currentLoveTheme;
    final provider = context.watch<TimeCapsuleProvider>();

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
                _buildAppBar(context, theme),
                Expanded(
                  child: provider.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : provider.capsules.isEmpty
                          ? _buildEmptyState(theme)
                          : _buildCapsuleLists(provider, theme),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateCapsuleSheet(context, theme),
        backgroundColor: theme.accentColor,
        child: const Icon(Icons.send_rounded, color: Colors.white),
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
                  'Time Capsules',
                  style: AppTypography.cormorant(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: theme.textColor,
                  ),
                ),
                Text(
                  'Write to your future selves. Seal them away.',
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

  Widget _buildCapsuleLists(TimeCapsuleProvider provider, dynamic theme) {
    final openable = provider.openableCapsules;
    final locked = provider.lockedCapsules;
    final opened = provider.openedCapsules;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 96),
      children: [
        if (openable.isNotEmpty) ...[
          _buildSectionHeader('🔓 Ready to Open', theme),
          const SizedBox(height: 8),
          ...openable.map((c) => _buildCapsuleCard(c, theme, provider, true)),
          const SizedBox(height: 20),
        ],
        if (locked.isNotEmpty) ...[
          _buildSectionHeader('🔒 Sealed & Waiting', theme),
          const SizedBox(height: 8),
          ...locked.map((c) => _buildCapsuleCard(c, theme, provider, false)),
          const SizedBox(height: 20),
        ],
        if (opened.isNotEmpty) ...[
          _buildSectionHeader('📖 Opened Memories', theme),
          const SizedBox(height: 8),
          ...opened.map((c) => _buildCapsuleCard(c, theme, provider, false)),
          const SizedBox(height: 20),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, dynamic theme) {
    return Text(
      title,
      style: AppTypography.sectionHeader(
        fontSize: 16,
        color: theme.textColor.withValues(alpha: 0.7),
      ),
    );
  }

  Widget _buildCapsuleCard(TimeCapsule capsule, dynamic theme, TimeCapsuleProvider provider, bool isOpenable) {
    final formattedOpenDate = DateFormat('MMMM dd, yyyy').format(capsule.openDate);
    final daysLeft = capsule.openDate.difference(DateTime.now()).inDays;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.textColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOpenable 
              ? Colors.green.withValues(alpha: 0.3) 
              : theme.textColor.withValues(alpha: 0.1),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (capsule.isOpened 
                    ? Colors.pinkAccent 
                    : (isOpenable ? Colors.green : Colors.grey))
                .withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            capsule.isOpened 
                ? Icons.drafts_rounded 
                : (isOpenable ? Icons.lock_open_rounded : Icons.lock_rounded),
            color: capsule.isOpened 
                ? Colors.pinkAccent 
                : (isOpenable ? Colors.green : theme.textColor.withValues(alpha: 0.6)),
            size: 20,
          ),
        ),
        title: Text(
          capsule.isOpened ? capsule.message : 'Time Capsule',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: capsule.isOpened
              ? AppTypography.lora(
                  color: theme.textColor,
                  fontWeight: FontWeight.bold,
                )
              : AppTypography.body(
                  color: theme.textColor,
                  fontWeight: FontWeight.bold,
                ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            capsule.isOpened
                ? 'Opened: $formattedOpenDate'
                : (isOpenable
                    ? 'Ready to open now!'
                    : 'Unlocks: $formattedOpenDate ($daysLeft days)'),
            style: AppTypography.bodyMedium(
              color: isOpenable ? Colors.green : theme.textColor.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isOpenable || capsule.isOpened)
              IconButton(
                icon: Icon(Icons.arrow_forward_ios_rounded, color: theme.textColor.withValues(alpha: 0.7), size: 16),
                onPressed: () => _showCapsuleDetailDialog(context, capsule, theme, provider),
              )
            else
              Icon(Icons.timer_outlined, color: theme.textColor.withValues(alpha: 0.38), size: 18),
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, color: theme.textColor.withValues(alpha: 0.38)),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: theme.primaryColor,
                    title: Text('Delete Time Capsule?', style: AppTypography.cardTitle(color: theme.textColor)),
                    content: Text(
                      'Are you sure you want to delete this time capsule? Its contents will be permanently lost.',
                      style: AppTypography.body(color: theme.textColor.withValues(alpha: 0.7)),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Cancel', style: AppTypography.button(color: theme.textColor.withValues(alpha: 0.7))),
                      ),
                      TextButton(
                        onPressed: () {
                          provider.deleteCapsule(capsule.id);
                          Navigator.pop(context);
                        },
                        child: Text('Delete', style: AppTypography.button(color: theme.accentColor)),
                      ),
                    ],
                  ),
                );
              },
            ),
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
                Icons.markunread_mailbox_outlined,
                size: 64,
                color: theme.accentColor.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Send a message to the future.',
              style: AppTypography.pageTitle(
                color: theme.textColor,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Seal a letter today to be unlocked on a special date or milestone in your future.',
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
