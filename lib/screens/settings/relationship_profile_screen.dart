import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:share_plus/share_plus.dart';
import 'package:days_together/providers/relationship_provider.dart';
import 'package:days_together/providers/theme_provider.dart';
import 'package:days_together/widgets/glass_container.dart';
import 'package:days_together/widgets/app_avatar.dart';

class RelationshipProfileScreen extends StatelessWidget {
  const RelationshipProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final theme = themeProvider.currentLoveTheme;
    final rp = context.watch<RelationshipProvider>();
    final partnerJoined = rp.partnerId != null;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: themeProvider.currentGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context, theme),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderSection(context, rp, theme),
                      const SizedBox(height: 32),
                      _buildInfoCard(context, rp, theme),
                      const SizedBox(height: 32),
                      if (!partnerJoined && rp.coupleCode != null) ...[
                        _buildInvitationCodeSection(context, rp, theme),
                        const SizedBox(height: 32),
                      ],
                      _buildUnlinkButton(context, rp, theme),
                      if (partnerJoined) const SizedBox(height: 16),
                      _buildDeleteAccountButton(context, rp, theme),
                      const SizedBox(height: 24),
                      _buildAuthDebugInfo(rp, theme),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAuthDebugInfo(RelationshipProvider rp, dynamic theme) {
    return Center(
      child: Opacity(
        opacity: 0.3,
        child: Text(
          'UID: ${rp.userId?.substring(0, 8) ?? "None"} • CID: ${rp.coupleId?.substring(0, 8) ?? "None"}',
          style: AppTypography.captionMono(fontSize: 10, color: theme.textColor),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, dynamic theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 20, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: theme.textColor,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'Relationship Profile',
            style: AppTypography.cormorant(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: theme.textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection(BuildContext context, RelationshipProvider rp, dynamic theme) {
    final partnerJoined = rp.partnerId != null;
    return GlassContainer(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      opacity: 0.1,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildAvatarWidget(rp.yourAvatarPath, rp.yourName ?? 'You', theme),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.accentColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.favorite_rounded,
                  color: theme.accentColor,
                  size: 24,
                ),
              ),
              if (partnerJoined)
                _buildAvatarWidget(rp.partnerAvatarPath, rp.partnerName ?? 'Partner', theme)
              else
                _buildAvatarPlaceholder(theme),
            ],
          ),
          const SizedBox(height: 32),
          if (partnerJoined) ...[
            Text(
              '${rp.yourName ?? 'You'} & ${rp.partnerName ?? 'Partner'}',
              style: AppTypography.cormorant(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: theme.textColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: theme.accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                'CONNECTED & IN LOVE',
                style: AppTypography.captionMono(
                  fontSize: 9,
                  color: theme.accentColor,
                  fontWeight: FontWeight.w800,
                ).copyWith(letterSpacing: 1),
              ),
            ),
          ] else ...[
            Text(
              rp.yourName ?? 'You',
              style: AppTypography.sectionHeader(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: theme.textColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Waiting for your partner to connect...',
              style: AppTypography.body(
                fontSize: 14,
                color: theme.textColor.withValues(alpha: 0.5),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatarWidget(String? path, String name, dynamic theme) {
    return Column(
      children: [
        AppAvatar(
          path: path,
          radius: 44,
          backgroundColor: theme.textColor.withValues(alpha: 0.1),
          iconColor: theme.textColor.withValues(alpha: 0.3),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: 90,
          child: Text(
            name,
            style: AppTypography.body(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: theme.textColor,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarPlaceholder(dynamic theme) {
    return Column(
      children: [
        AppAvatar(
          radius: 44,
          backgroundColor: theme.textColor.withValues(alpha: 0.1),
          iconColor: theme.textColor.withValues(alpha: 0.3),
        ),
        const SizedBox(height: 12),
        Text(
          'Waiting...',
          style: AppTypography.body(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: theme.textColor.withValues(alpha: 0.38),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(BuildContext context, RelationshipProvider rp, dynamic theme) {
    final start = rp.startDate;
    final formattedStart = start != null ? DateFormat('MMMM dd, yyyy').format(start) : 'Not Set';
    final formattedTime = rp.startTime != null ? rp.startTime!.format(context) : '12:00 AM';
    final ageStr = rp.relationshipAge;

    return Column(
      children: [
        _buildBentoSection(
          title: 'Foundation',
          theme: theme,
          items: [
            _StatTile(
              icon: Icons.calendar_today_rounded,
              label: 'Anniversary',
              value: formattedStart,
              theme: theme,
              onTap: () => _editDate(context, rp, theme),
            ),
            _StatTile(
              icon: Icons.access_time_rounded,
              label: 'Time',
              value: formattedTime,
              theme: theme,
              onTap: () => _editTime(context, rp, theme),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildBentoSection(
          title: 'Duration',
          theme: theme,
          items: [
            _StatTile(
              icon: Icons.hourglass_empty_rounded,
              label: 'Time Together',
              value: ageStr,
              theme: theme,
              isFullWidth: true,
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildBentoSection(
          title: 'Registry Details',
          theme: theme,
          items: [
            _StatTile(
              icon: Icons.person_pin_rounded,
              label: 'Your Join Date',
              value: rp.yourJoinDate != null ? DateFormat('MMM dd, yyyy').format(rp.yourJoinDate!) : '...',
              theme: theme,
            ),
            _StatTile(
              icon: Icons.people_outline_rounded,
              label: 'Partner Join Date',
              value: rp.partnerJoinDate != null ? DateFormat('MMM dd, yyyy').format(rp.partnerJoinDate!) : 'Waiting...',
              theme: theme,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBentoSection({required String title, required List<Widget> items, bool isFullWidth = false, required dynamic theme}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 12),
          child: Text(
            title.toUpperCase(),
            style: AppTypography.captionMono(fontSize: 10, fontWeight: FontWeight.w800, color: theme.accentColor).copyWith(letterSpacing: 1.5),
          ),
        ),
        if (items.length > 1 && !isFullWidth)
          Row(
            children: items.map((item) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: item))).toList(),
          )
        else
          ...items,
      ],
    );
  }

  Future<void> _editDate(BuildContext context, RelationshipProvider rp, dynamic theme) async {
    final date = await showDatePicker(
      context: context,
      initialDate: rp.startDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.fromSeed(seedColor: theme.accentColor, brightness: theme.isDark ? Brightness.dark : Brightness.light),
        ),
        child: child!,
      ),
    );
    if (date != null) await rp.setStartDate(date);
  }

  Future<void> _editTime(BuildContext context, RelationshipProvider rp, dynamic theme) async {
    final time = await showTimePicker(
      context: context,
      initialTime: rp.startTime ?? TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.fromSeed(seedColor: theme.accentColor, brightness: theme.isDark ? Brightness.dark : Brightness.light),
        ),
        child: child!,
      ),
    );
    if (time != null) await rp.setStartTime(time);
  }

  Widget _buildInvitationCodeSection(BuildContext context, RelationshipProvider rp, dynamic theme) {
    final code = rp.coupleCode ?? '';
    return GlassContainer(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      opacity: 0.1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.link_rounded, color: theme.accentColor, size: 20),
              const SizedBox(width: 10),
              Text(
                'PAIRING CODE',
                style: AppTypography.captionMono(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: theme.accentColor,
                ).copyWith(letterSpacing: 1.5),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Share this unique code with your partner to link your stories together.',
            style: AppTypography.body(
              fontSize: 13,
              color: theme.textColor.withValues(alpha: 0.6),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: theme.textColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.textColor.withValues(alpha: 0.1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  code,
                  style: AppTypography.bodyMono(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: theme.textColor,
                  ).copyWith(letterSpacing: 4),
                ),
                Row(
                  children: [
                    _buildIconButton(
                      icon: Icons.copy_rounded,
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: code));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Code copied to clipboard!')),
                        );
                      },
                      theme: theme,
                    ),
                    const SizedBox(width: 8),
                    _buildIconButton(
                      icon: Icons.share_rounded,
                      onTap: () {
                        Share.share("Let's connect our Love Story! Here is my invitation code: $code 💕");
                      },
                      theme: theme,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton({required IconData icon, required VoidCallback onTap, required dynamic theme}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.accentColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: theme.accentColor, size: 18),
      ),
    );
  }

  Widget _buildUnlinkButton(BuildContext context, RelationshipProvider rp, dynamic theme) {
    final partnerJoined = rp.partnerId != null;
    if (!partnerJoined) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
      ),
      child: TextButton(
        onPressed: () => _showUnlinkConfirmation(context, rp, theme),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(
          partnerJoined ? 'Unlink Relationship' : 'Cancel Relationship Request',
          style: AppTypography.body(
            color: Colors.redAccent,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteAccountButton(BuildContext context, RelationshipProvider rp, dynamic theme) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.textColor.withValues(alpha: 0.15)),
      ),
      child: TextButton(
        onPressed: () => _showDeleteAccountConfirmation(context, rp, theme),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(
          'Delete Account',
          style: AppTypography.body(
            color: Colors.redAccent,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  void _showDeleteAccountConfirmation(BuildContext context, RelationshipProvider rp, dynamic theme) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'Delete Account',
            style: AppTypography.sectionHeader(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.textColor,
            ),
            textAlign: TextAlign.center,
          ),
          content: Text(
            'Are you absolutely sure you want to delete your account? This action is permanent. All your personal data will be erased immediately. If you are paired, your partner will be returned to a single state and all shared memories and notes will be deleted forever.',
            style: AppTypography.body(
              fontSize: 14,
              color: theme.textColor.withValues(alpha: 0.6),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: Text(
                      'Cancel',
                      style: AppTypography.body(
                        color: theme.textColor.withValues(alpha: 0.4),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(dialogContext); // Close confirmation dialog
                      
                      // Show loading spinner dialog
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => const Center(
                          child: CircularProgressIndicator(color: Colors.redAccent),
                        ),
                      );

                      try {
                        await rp.deleteAccount();
                        if (context.mounted) {
                          Navigator.pop(context); // Dismiss loading spinner
                          Navigator.of(context).popUntil((route) => route.isFirst);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          Navigator.pop(context); // Dismiss loading
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to delete account: $e')),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Delete',
                      style: AppTypography.body(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _showUnlinkConfirmation(BuildContext context, RelationshipProvider rp, dynamic theme) {
    final partnerJoined = rp.partnerId != null;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassContainer(
          borderRadius: 28,
          padding: const EdgeInsets.all(28),
          opacity: 0.1,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.redAccent,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                partnerJoined ? 'Disconnect Relationship' : 'Cancel Invitation',
                style: AppTypography.sectionHeader(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: theme.textColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                partnerJoined
                    ? 'Are you sure you want to disconnect? This will unlink your profile from your partner and return you to the pairing setup.'
                    : 'Are you sure you want to cancel? This will deactivate your current connection code.',
                style: AppTypography.body(
                  fontSize: 14,
                  color: theme.textColor.withValues(alpha: 0.6),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Stay Connected',
                        style: AppTypography.body(
                          color: theme.textColor.withValues(alpha: 0.4),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context); // close dialog
                        await rp.unlinkPartner();
                        if (context.mounted) Navigator.pop(context); // exit profile screen
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        partnerJoined ? 'Disconnect' : 'Cancel Code',
                        style: AppTypography.body(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final dynamic theme;
  final VoidCallback? onTap;
  final bool isFullWidth;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.theme,
    this.onTap,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        width: isFullWidth ? double.infinity : null,
        padding: const EdgeInsets.all(20),
        borderRadius: 20,
        opacity: 0.05,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.accentColor, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.captionMono(fontSize: 9, fontWeight: FontWeight.bold, color: theme.textColor.withValues(alpha: 0.4)).copyWith(letterSpacing: 0.5),
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.edit_rounded, color: theme.accentColor.withValues(alpha: 0.5), size: 14),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: AppTypography.body(fontSize: 15, fontWeight: FontWeight.bold, color: theme.textColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
