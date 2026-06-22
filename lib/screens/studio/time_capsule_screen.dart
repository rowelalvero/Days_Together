import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:days_together/providers/theme_provider.dart';
import 'package:days_together/providers/time_capsule_provider.dart';
import 'package:days_together/models/time_capsule_model.dart';

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
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '✉️ Create Time Capsule',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _messageController,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Write a note, a secret, or a message to your future selves...\n\n"Dear future us..."',
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
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
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _selectedDate == null
                                  ? 'Select Unlock Date'
                                  : DateFormat('MMMM dd, yyyy').format(_selectedDate!),
                              style: TextStyle(
                                color: _selectedDate == null
                                    ? Colors.white.withValues(alpha: 0.4)
                                    : Colors.white,
                                fontSize: 16,
                              ),
                            ),
                            const Icon(Icons.calendar_today_rounded, color: Colors.white70),
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
                        child: const Text('Seal Time Capsule', style: TextStyle(fontWeight: FontWeight.bold)),
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
              const Text('Opened Capsule', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Created: ${DateFormat('MMMM dd, yyyy').format(capsule.createdAt)}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 16),
                Text(
                  capsule.message,
                  style: const TextStyle(
                    fontFamily: 'Lora',
                    fontSize: 16,
                    height: 1.5,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close', style: TextStyle(color: theme.accentColor)),
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
                _buildAppBar(context),
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
                'Time Capsules',
                style: TextStyle(
                  fontFamily: 'Cormorant',
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                'Write to your future selves. Seal them away.',
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

  Widget _buildCapsuleLists(TimeCapsuleProvider provider, dynamic theme) {
    final openable = provider.openableCapsules;
    final locked = provider.lockedCapsules;
    final opened = provider.openedCapsules;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 96),
      children: [
        if (openable.isNotEmpty) ...[
          _buildSectionHeader('🔓 Ready to Open'),
          const SizedBox(height: 8),
          ...openable.map((c) => _buildCapsuleCard(c, theme, provider, true)),
          const SizedBox(height: 20),
        ],
        if (locked.isNotEmpty) ...[
          _buildSectionHeader('🔒 Sealed & Waiting'),
          const SizedBox(height: 8),
          ...locked.map((c) => _buildCapsuleCard(c, theme, provider, false)),
          const SizedBox(height: 20),
        ],
        if (opened.isNotEmpty) ...[
          _buildSectionHeader('📖 Opened Memories'),
          const SizedBox(height: 8),
          ...opened.map((c) => _buildCapsuleCard(c, theme, provider, false)),
          const SizedBox(height: 20),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.white70,
      ),
    );
  }

  Widget _buildCapsuleCard(TimeCapsule capsule, dynamic theme, TimeCapsuleProvider provider, bool isOpenable) {
    final formattedOpenDate = DateFormat('MMMM dd, yyyy').format(capsule.openDate);
    final daysLeft = capsule.openDate.difference(DateTime.now()).inDays;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOpenable 
              ? Colors.green.withValues(alpha: 0.3) 
              : Colors.white.withValues(alpha: 0.1),
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
                : (isOpenable ? Colors.green : Colors.white60),
            size: 20,
          ),
        ),
        title: Text(
          capsule.isOpened ? capsule.message : 'Time Capsule',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontFamily: capsule.isOpened ? 'Lora' : null,
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
            style: TextStyle(
              color: isOpenable ? Colors.green : Colors.white60,
              fontSize: 12,
            ),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isOpenable || capsule.isOpened)
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 16),
                onPressed: () => _showCapsuleDetailDialog(context, capsule, theme, provider),
              )
            else
              const Icon(Icons.timer_outlined, color: Colors.white38, size: 18),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.white38),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: theme.primaryColor,
                    title: const Text('Delete Time Capsule?', style: TextStyle(color: Colors.white)),
                    content: const Text(
                      'Are you sure you want to delete this capsule? It will be gone forever.',
                      style: TextStyle(color: Colors.white70),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                      ),
                      TextButton(
                        onPressed: () {
                          provider.deleteCapsule(capsule.id);
                          Navigator.pop(context);
                        },
                        child: Text('Delete', style: TextStyle(color: theme.accentColor)),
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
                color: Colors.white.withValues(alpha: 0.03),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.markunread_mailbox_outlined,
                size: 64,
                color: theme.accentColor.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Write to your future selves.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Seal a letter today to unlock on a special anniversary or date in the future.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
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
