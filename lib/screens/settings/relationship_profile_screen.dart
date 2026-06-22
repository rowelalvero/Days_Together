import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:days_together/providers/relationship_provider.dart';
import 'package:days_together/providers/theme_provider.dart';
import 'package:days_together/widgets/glass_container.dart';

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
                      const SizedBox(height: 24),
                      _buildInfoCard(context, rp, theme),
                      const SizedBox(height: 24),
                      if (!partnerJoined && rp.coupleCode != null) ...[
                        _buildInvitationCodeSection(context, rp, theme),
                        const SizedBox(height: 24),
                      ],
                      _buildUnlinkButton(context, rp, theme),
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

  Widget _buildAppBar(BuildContext context, dynamic theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: GlassContainer(
              padding: const EdgeInsets.all(12),
              borderRadius: 14,
              opacity: 0.1,
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: theme.textColor,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'Relationship Profile',
            style: GoogleFonts.playfairDisplay(
              fontSize: 22,
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
      padding: const EdgeInsets.all(32),
      opacity: 0.1,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildAvatarWidget(rp.yourAvatarPath, rp.yourName ?? 'You', theme),
              Icon(
                Icons.favorite_rounded,
                color: theme.accentColor,
                size: 36,
              ),
              if (partnerJoined)
                _buildAvatarWidget(rp.partnerAvatarPath, rp.partnerName ?? 'Partner', theme)
              else
                _buildAvatarPlaceholder(theme),
            ],
          ),
          const SizedBox(height: 24),
          if (partnerJoined) ...[
            Text(
              '${rp.yourName ?? 'You'} & ${rp.partnerName ?? 'Partner'}',
              style: GoogleFonts.playfairDisplay(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: theme.textColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Connected & in Love',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: theme.textColor.withValues(alpha: 0.5),
                fontWeight: FontWeight.w500,
              ),
            ),
          ] else ...[
            Text(
              rp.yourName ?? 'You',
              style: GoogleFonts.playfairDisplay(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: theme.textColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Waiting for partner to join...',
              style: GoogleFonts.inter(
                fontSize: 13,
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
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: theme.accentColor.withValues(alpha: 0.6),
              width: 2.5,
            ),
          ),
          child: CircleAvatar(
            radius: 36,
            backgroundColor: Colors.white12,
            backgroundImage: path != null
                ? (path.startsWith('http')
                    ? NetworkImage(path) as ImageProvider
                    : (File(path).existsSync()
                        ? FileImage(File(path))
                        : null))
                : null,
            child: path == null || (!path.startsWith('http') && !File(path).existsSync())
                ? const Icon(Icons.person, color: Colors.white70, size: 36)
                : null,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 85,
          child: Text(
            name,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
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
        Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white24,
              width: 2.5,
            ),
          ),
          child: Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
              child: Icon(
                Icons.person_add_rounded,
                color: theme.textColor.withValues(alpha: 0.3),
                size: 28,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Waiting...',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white38,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(BuildContext context, RelationshipProvider rp, dynamic theme) {
    final partnerJoined = rp.partnerId != null;
    final start = rp.startDate;
    final formattedStart = start != null ? DateFormat('MMMM dd, yyyy').format(start) : 'Not Set';
    final formattedTime = rp.startTime != null ? rp.startTime!.format(context) : '12:00 AM';
    final ageStr = rp.relationshipAge;

    final yJoin = rp.yourJoinDate;
    final pJoin = rp.partnerJoinDate;

    return GlassContainer(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      opacity: 0.08,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow(
            icon: Icons.calendar_today_rounded,
            title: 'Anniversary Date',
            value: formattedStart,
            theme: theme,
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: start ?? DateTime.now(),
                firstDate: DateTime(1900),
                lastDate: DateTime.now(),
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
              if (date != null) {
                await rp.setStartDate(date);
              }
            },
          ),
          _buildDivider(),
          _buildInfoRow(
            icon: Icons.access_time_rounded,
            title: 'Anniversary Time',
            value: formattedTime,
            theme: theme,
            onTap: () async {
              final time = await showTimePicker(
                context: context,
                initialTime: rp.startTime ?? TimeOfDay.now(),
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
              if (time != null) {
                await rp.setStartTime(time);
              }
            },
          ),
          _buildDivider(),
          _buildInfoRow(
            icon: Icons.hourglass_empty_rounded,
            title: 'Duration',
            value: ageStr,
            theme: theme,
          ),
          _buildDivider(),
          _buildInfoRow(
            icon: Icons.link_rounded,
            title: 'Registry Status',
            valueWidget: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: partnerJoined ? Colors.greenAccent : Colors.orangeAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  partnerJoined ? 'Connected' : 'Unpaired / Waiting',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            theme: theme,
          ),
          _buildDivider(),
          _buildInfoRow(
            icon: Icons.person_pin_rounded,
            title: 'Your Registry Date',
            value: yJoin != null ? DateFormat('MMMM dd, yyyy').format(yJoin) : 'Not joined yet',
            theme: theme,
          ),
          _buildDivider(),
          _buildInfoRow(
            icon: Icons.people_outline_rounded,
            title: "Partner's Registry Date",
            value: partnerJoined
                ? (pJoin != null ? DateFormat('MMMM dd, yyyy').format(pJoin) : 'Connected')
                : 'Waiting for partner...',
            theme: theme,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    String? value,
    Widget? valueWidget,
    required dynamic theme,
    VoidCallback? onTap,
  }) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: theme.accentColor, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white38,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                if (valueWidget != null)
                  valueWidget
                else
                  Text(
                    value ?? '',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 8),
            Icon(
              Icons.mode_edit_outline_rounded,
              color: Colors.white.withValues(alpha: 0.4),
              size: 16,
            ),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: content,
      );
    }
    return content;
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Divider(
        color: Colors.white.withValues(alpha: 0.05),
        height: 1,
      ),
    );
  }

  Widget _buildInvitationCodeSection(BuildContext context, RelationshipProvider rp, dynamic theme) {
    final code = rp.coupleCode ?? '';
    return GlassContainer(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      opacity: 0.08,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PAIRING CODE',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: theme.accentColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Share this invitation code with your partner so they can join your registry.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.white54,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  code,
                  style: GoogleFonts.montserrat(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 4,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, color: Colors.white70),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: code));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Code copied to clipboard!'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      tooltip: 'Copy Code',
                    ),
                    IconButton(
                      icon: const Icon(Icons.share_rounded, color: Colors.white70),
                      onPressed: () {
                        Share.share(
                          "Let's connect our Days Together app! Here is my invitation code: $code",
                        );
                      },
                      tooltip: 'Share Code',
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

  Widget _buildUnlinkButton(BuildContext context, RelationshipProvider rp, dynamic theme) {
    final partnerJoined = rp.partnerId != null;
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: OutlinedButton(
        onPressed: () => _showUnlinkConfirmation(context, rp, theme),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.redAccent, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          partnerJoined ? 'Unlink Relationship' : 'Cancel Relationship Request',
          style: GoogleFonts.inter(
            color: Colors.redAccent,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.redAccent,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                partnerJoined ? 'Unlink Relationship' : 'Cancel Registry Request',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                partnerJoined
                    ? 'Are you sure you want to unlink? This will disconnect your profile from your partner and return you to the pairing setup screen.'
                    : 'Are you sure you want to cancel? This will deactivate the current invitation code.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.white70,
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
                        partnerJoined ? 'Keep Connected' : 'Keep Request',
                        style: GoogleFonts.inter(
                          color: Colors.white54,
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
                        'Unlink',
                        style: GoogleFonts.inter(
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
