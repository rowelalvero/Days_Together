import 'package:days_together/themes/theme_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:share_plus/share_plus.dart';
import 'package:days_together/providers/couple_session.dart';
import 'package:days_together/services/date_helper.dart';
import 'package:days_together/providers/theme_provider.dart';
import 'package:days_together/shared/glass_container.dart';
import 'package:days_together/shared/safe_loading_dialog.dart';
import 'package:image_picker/image_picker.dart';
import 'package:days_together/services/permission_service.dart';
import 'package:days_together/shared/cached_avatar.dart';

class RelationshipProfileScreen extends StatelessWidget {
  const RelationshipProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final theme = themeProvider.currentLoveTheme;
    final rp = context.watch<CoupleSession>();
    final partnerJoined = rp.partnerId != null;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: themeProvider.currentGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context, theme),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderSection(context, rp, theme),
                      const SizedBox(height: 32),
                      _buildInfoCard(context, rp, theme),
                      const SizedBox(height: 32),
                      if (!partnerJoined && rp.coupleCode != null) ...[
                        PairingOptionsSection(rp: rp, theme: theme),
                        const SizedBox(height: 32),
                      ],
                      const SizedBox(height: 16),
                      _buildRegenerateRecoveryCodeButton(context, rp, theme),
                      const SizedBox(height: 16),
                      _buildDangerZoneDivider(theme),
                      const SizedBox(height: 20),
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

  Widget _buildAuthDebugInfo(CoupleSession rp, LoveStoryTheme theme) {
    return Center(
      child: Opacity(
        opacity: 0.3,
        child: Text(
          'UID: ${rp.userId?.substring(0, 8) ?? "None"} • CID: ${rp.coupleId?.substring(0, 8) ?? "None"}',
          style: AppTypography.captionMono(
            fontSize: 10,
            color: theme.textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, LoveStoryTheme theme) {
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

  Widget _buildHeaderSection(
    BuildContext context,
    CoupleSession rp,
    LoveStoryTheme theme,
  ) {
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
              _buildAvatarWidget(
                rp.yourAvatarPath,
                rp.yourName ?? 'You',
                theme,
              ),
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
                _buildAvatarWidget(
                  rp.partnerAvatarPath,
                  rp.partnerName ?? 'Partner',
                  theme,
                )
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
              style: AppTypography.heading(
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
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => _editProfileDialog(context, rp, theme),
            icon: Icon(Icons.edit_rounded, color: theme.textColor, size: 16),
            label: Text(
              'Edit Profile',
              style: AppTypography.body(
                color: theme.textColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: theme.textColor.withValues(alpha: 0.2)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarWidget(String? path, String name, LoveStoryTheme theme) {
    return Column(
      children: [
        CachedAvatar(
          path: path,
          radius: 44,
          // iconSize matches AppAvatar's old default (radius * 1.2) before
          // the Phase 7b merge into CachedAvatar, whose own default is
          // just radius -- passed explicitly here to keep this call site's
          // rendered icon size unchanged.
          iconSize: 44 * 1.2,
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

  Widget _buildAvatarPlaceholder(LoveStoryTheme theme) {
    return Column(
      children: [
        CachedAvatar(
          radius: 44,
          iconSize: 44 * 1.2,
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

  Widget _buildInfoCard(
    BuildContext context,
    CoupleSession rp,
    LoveStoryTheme theme,
  ) {
    final start = rp.startDate;
    final formattedStart = start != null
        ? DateFormat('MMMM dd, yyyy').format(start)
        : 'Not Set';
    final formattedTime = rp.startTime != null
        ? rp.startTime!.format(context)
        : '12:00 AM';
    final ageStr = DateHelper.relationshipAgeLabel(rp.startDate, rp.startTime);

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
              value: rp.yourJoinDate != null
                  ? DateFormat('MMM dd, yyyy').format(rp.yourJoinDate!)
                  : '...',
              theme: theme,
            ),
            _StatTile(
              icon: Icons.people_outline_rounded,
              label: 'Partner Join Date',
              value: rp.partnerJoinDate != null
                  ? DateFormat('MMM dd, yyyy').format(rp.partnerJoinDate!)
                  : 'Waiting...',
              theme: theme,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBentoSection({
    required String title,
    required List<Widget> items,
    bool isFullWidth = false,
    required LoveStoryTheme theme,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 12),
          child: Text(
            title.toUpperCase(),
            style: AppTypography.captionMono(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: theme.accentColor,
            ).copyWith(letterSpacing: 1.5),
          ),
        ),
        if (items.length > 1 && !isFullWidth)
          Row(
            children: items
                .map(
                  (item) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: item,
                    ),
                  ),
                )
                .toList(),
          )
        else
          ...items,
      ],
    );
  }

  Future<void> _editDate(
    BuildContext context,
    CoupleSession rp,
    LoveStoryTheme theme,
  ) async {
    final date = await showDatePicker(
      context: context,
      initialDate: rp.startDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: theme.accentColor,
            brightness: theme.isDark ? Brightness.dark : Brightness.light,
          ),
        ),
        child: child!,
      ),
    );
    if (date != null) await rp.setStartDate(date);
  }

  Future<void> _editTime(
    BuildContext context,
    CoupleSession rp,
    LoveStoryTheme theme,
  ) async {
    final time = await showTimePicker(
      context: context,
      initialTime: rp.startTime ?? TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: theme.accentColor,
            brightness: theme.isDark ? Brightness.dark : Brightness.light,
          ),
        ),
        child: child!,
      ),
    );
    if (time != null) await rp.setStartTime(time);
  }



    Widget _buildRegenerateRecoveryCodeButton(
    BuildContext context,
    CoupleSession rp,
    LoveStoryTheme theme,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.textColor.withValues(alpha: 0.15)),
      ),
      child: TextButton.icon(
        onPressed: () => _showRegenerateRecoveryCodeDialog(context, rp, theme),
        icon: Icon(Icons.security_rounded, color: theme.textColor, size: 20),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        label: Text(
          'Regenerate Recovery Code',
          style: AppTypography.body(
            color: theme.textColor,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  void _showRegenerateRecoveryCodeDialog(
    BuildContext profileContext,
    CoupleSession rp,
    LoveStoryTheme theme,
  ) {
    showDialog(
      context: profileContext,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassContainer(
          borderRadius: 28,
          padding: const EdgeInsets.all(28),
          opacity: theme.isDark ? 0.1 : 0.85,
          gradient: theme.isDark
              ? null
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.95),
                    Colors.white.withValues(alpha: 0.85),
                  ],
                ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.accentColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.security_rounded,
                  color: theme.accentColor,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Regenerate Recovery Code',
                style: AppTypography.heading(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: theme.textColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Regenerating your recovery code will permanently invalidate all previously issued recovery codes. You will only be shown the new code once.',
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
                        Navigator.pop(dialogContext); // Close warning dialog

                        final success = await SafeLoadingDialog.run<bool>(
                          context: profileContext,
                          future: () async {
                            await rp.regenerateRecoveryCode();
                            return true;
                          },
                          timeoutSeconds: 15,
                          loadingMessage: 'Regenerating code...',
                        );

                        if (success == true && profileContext.mounted) {
                          _showNewRecoveryCodeDialog(profileContext, rp, theme);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.accentColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Regenerate',
                        style: AppTypography.body(fontWeight: FontWeight.bold),
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

  void _showNewRecoveryCodeDialog(
    BuildContext context,
    CoupleSession rp,
    LoveStoryTheme theme,
  ) {
    bool saved = false;
    showDialog(
      context: context,
      barrierDismissible: false, // Force them to save and check the box
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          backgroundColor: Colors.transparent,
          child: GlassContainer(
            borderRadius: 28,
            padding: const EdgeInsets.all(28),
            opacity: theme.isDark ? 0.1 : 0.85,
            gradient: theme.isDark
                ? null
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.95),
                      Colors.white.withValues(alpha: 0.85),
                    ],
                  ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Text(
                    'Your New Recovery Code',
                    style: AppTypography.heading(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: theme.textColor,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.textColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.textColor.withValues(alpha: 0.15)),
                  ),
                  child: Center(
                    child: SelectableText(
                      rp.recoveryCode ?? '—',
                      style: AppTypography.body(
                        color: theme.accentColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    '⚠️ This code will never be shown again.',
                    style: AppTypography.caption(
                      color: Colors.redAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: rp.recoveryCode ?? ''));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Recovery code copied!')),
                      );
                    },
                    icon: Icon(Icons.copy_rounded, color: theme.textColor, size: 16),
                    label: Text(
                      'Copy Code',
                      style: AppTypography.body(color: theme.textColor, fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Checkbox(
                      value: saved,
                      onChanged: (val) => setState(() => saved = val ?? false),
                      activeColor: theme.accentColor,
                    ),
                    Expanded(
                      child: Text(
                        'I have saved my recovery code securely.',
                        style: AppTypography.body(color: theme.textColor, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: saved
                        ? () {
                            rp.clearRecoveryCode();
                            Navigator.pop(context);
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.accentColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Continue',
                      style: AppTypography.button(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

Widget _buildDangerZoneDivider(LoveStoryTheme theme) {
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: Colors.redAccent.withValues(alpha: 0.15),
            thickness: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.redAccent,
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                'DANGER ZONE',
                style: AppTypography.captionMono(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.redAccent,
                ).copyWith(letterSpacing: 1.5),
              ),
            ],
          ),
        ),
        Expanded(
          child: Divider(
            color: Colors.redAccent.withValues(alpha: 0.15),
            thickness: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildUnlinkButton(
    BuildContext context,
    CoupleSession rp,
    LoveStoryTheme theme,
  ) {
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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

  Widget _buildDeleteAccountButton(
    BuildContext context,
    CoupleSession rp,
    LoveStoryTheme theme,
  ) {
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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

  void _showDeleteAccountConfirmation(
    BuildContext context,
    CoupleSession rp,
    LoveStoryTheme theme,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: GlassContainer(
            borderRadius: 28,
            padding: const EdgeInsets.all(28),
            opacity: theme.isDark ? 0.1 : 0.85,
            gradient: theme.isDark
                ? null
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.95),
                      Colors.white.withValues(alpha: 0.85),
                    ],
                  ),
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
                    Icons.delete_forever_rounded,
                    color: Colors.redAccent,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Delete Account',
                  style: AppTypography.heading(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.textColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Are you absolutely sure you want to delete your account? This action is permanent. All your personal data will be erased immediately. If you are paired, your partner will be returned to a single state and all shared memories and notes will be deleted forever.',
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

                          // No explicit navigation after this: deleteAccount()
                          // ends in logout(wipeAll: true), which clears
                          // CoupleSession's identity fields -- the
                          // router's single redirect (app_router.dart) picks
                          // that up via refreshListenable and recomputes the
                          // correct destination, replacing the old
                          // popUntil(isFirst)-to-root strategy (ADR-007
                          // found this used a different "return to root"
                          // mechanism than settings_tab.dart's logout did).
                          await SafeLoadingDialog.run<bool>(
                            context: context,
                            future: () async {
                              await rp.deleteAccount();
                              return true;
                            },
                            timeoutSeconds: 20,
                            loadingMessage: 'Deleting account...',
                            indicatorColor: Colors.redAccent,
                          );
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
                          style: AppTypography.body(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showUnlinkConfirmation(
    BuildContext profileContext,
    CoupleSession rp,
    LoveStoryTheme theme,
  ) {
    final partnerJoined = rp.partnerId != null;
    showDialog(
      context: profileContext,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassContainer(
          borderRadius: 28,
          padding: const EdgeInsets.all(28),
          opacity: theme.isDark ? 0.1 : 0.85,
          gradient: theme.isDark
              ? null
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.95),
                    Colors.white.withValues(alpha: 0.85),
                  ],
                ),
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
                style: AppTypography.heading(
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
                      onPressed: () => Navigator.pop(dialogContext),
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
                        Navigator.pop(dialogContext); // close dialog
                        await rp.unlinkPartner();
                        if (profileContext.mounted) {
                          Navigator.pop(profileContext); // exit profile screen
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
                        partnerJoined ? 'Disconnect' : 'Cancel Code',
                        style: AppTypography.body(fontWeight: FontWeight.bold),
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

  void _editProfileDialog(
    BuildContext context,
    CoupleSession rp,
    LoveStoryTheme theme,
  ) {
    final yourController = TextEditingController(text: rp.yourName);
    final partnerController = TextEditingController(text: rp.partnerName);
    final partnerJoined = rp.partnerId != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      builder: (context) {
        return GlassContainer(
          borderRadius: 32,
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 30,
            top: 30,
            left: 24,
            right: 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Edit Your Profiles',
                  style: AppTypography.heading(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: theme.textColor,
                  ),
                ),
                const SizedBox(height: 32),
                _buildAvatarRow(context, rp, theme, true),
                const SizedBox(height: 20),
                _buildNameField(yourController, 'Your Name', theme),
                if (partnerJoined) ...[
                  const SizedBox(height: 32),
                  _buildAvatarRow(context, rp, theme, false),
                  const SizedBox(height: 20),
                  _buildNameField(partnerController, "Partner's Name", theme),
                ],
                const SizedBox(height: 40),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Discard Changes',
                          style: AppTypography.body(
                            color: theme.textColor.withValues(alpha: 0.54),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          if (partnerJoined) {
                            await rp.setNames(
                              yourController.text.trim(),
                              partnerController.text.trim(),
                            );
                          } else {
                            await rp.setYourName(yourController.text.trim());
                          }
                          if (context.mounted) Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.accentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Save Profile Details',
                          style: AppTypography.body(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvatarRow(
    BuildContext context,
    CoupleSession rp,
    LoveStoryTheme theme,
    bool isYou,
  ) {
    final path = isYou ? rp.yourAvatarPath : rp.partnerAvatarPath;
    return GestureDetector(
      onTap: () => _pickAvatar(context, rp, isYou),
      child: Stack(
        children: [
          CachedAvatar(
            path: path,
            radius: 40,
            backgroundColor: theme.textColor.withValues(alpha: 0.1),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.accentColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameField(
    TextEditingController controller,
    String label,
    LoveStoryTheme theme,
  ) {
    return GlassContainer(
      opacity: 0.05,
      borderRadius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        controller: controller,
        style: AppTypography.body(color: theme.textColor),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: AppTypography.caption(
            color: theme.textColor.withValues(alpha: 0.3),
            fontSize: 12,
          ),
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }

  Future<void> _pickAvatar(
    BuildContext context,
    CoupleSession rp,
    bool isYou,
  ) async {
    final hasPermission = await PermissionService().requestPhotosPermission(
      context,
    );
    if (!hasPermission) return;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
    );
    if (pickedFile != null) {
      try {
        if (isYou) {
          await rp.setAvatars(yourPath: pickedFile.path);
        } else {
          await rp.setAvatars(partnerPath: pickedFile.path);
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile image updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update profile image: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final LoveStoryTheme theme;
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
                    style: AppTypography.captionMono(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: theme.textColor.withValues(alpha: 0.4),
                    ).copyWith(letterSpacing: 0.5),
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.edit_rounded,
                    color: theme.accentColor.withValues(alpha: 0.5),
                    size: 14,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: AppTypography.body(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: theme.textColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class PairingOptionsSection extends StatefulWidget {
  final CoupleSession rp;
  final LoveStoryTheme theme;

  const PairingOptionsSection({
    super.key,
    required this.rp,
    required this.theme,
  });

  @override
  State<PairingOptionsSection> createState() => _PairingOptionsSectionState();
}

class _PairingOptionsSectionState extends State<PairingOptionsSection> {
  final TextEditingController _controller = TextEditingController();
  bool _isLinking = false;
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _linkCode() async {
    final code = _controller.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() {
        _errorMessage = 'Code must be exactly 6 characters.';
      });
      return;
    }

    setState(() {
      _isLinking = true;
      _errorMessage = null;
    });

    try {
      final success = await widget.rp.joinWithCode(code);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully linked with your partner! 💞'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        setState(() {
          _errorMessage = 'Invalid connection code. Please check with your partner.';
          _isLinking = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Connection error: ${e.toString().replaceAll('Exception: ', '')}';
          _isLinking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final code = widget.rp.coupleCode ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Card 1: Share Your Code
        GlassContainer(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          opacity: 0.1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.share_rounded, color: theme.accentColor, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'PROVIDE YOUR CODE',
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
                'Let your partner enter this code on their device to connect.',
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
                              const SnackBar(
                                content: Text('Code copied to clipboard!'),
                              ),
                            );
                          },
                          theme: theme,
                        ),
                        const SizedBox(width: 8),
                        _buildIconButton(
                          icon: Icons.share_rounded,
                          onTap: () {
                            Share.share(
                              "Let's connect our Love Story! Here is my invitation code: $code 💕",
                            );
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
        ),
        const SizedBox(height: 24),
        // Card 2: Enter Partner's Code
        GlassContainer(
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
                    'JOIN PARTNER\'S RELATIONSHIP',
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
                'Enter the 6-character connection code sent by your partner to link immediately.',
                style: AppTypography.body(
                  fontSize: 13,
                  color: theme.textColor.withValues(alpha: 0.6),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      maxLength: 6,
                      textCapitalization: TextCapitalization.characters,
                      style: AppTypography.bodyMono(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.textColor,
                      ).copyWith(letterSpacing: 2),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: 'CODE12',
                        hintStyle: AppTypography.bodyMono(
                          fontSize: 18,
                          color: theme.textColor.withValues(alpha: 0.25),
                        ).copyWith(letterSpacing: 2),
                        filled: true,
                        fillColor: theme.textColor.withValues(alpha: 0.05),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: theme.textColor.withValues(alpha: 0.15),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: theme.textColor.withValues(alpha: 0.15),
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
                      onChanged: (_) {
                        if (_errorMessage != null) {
                          setState(() {
                            _errorMessage = null;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isLinking ? null : _linkCode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.accentColor,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            theme.accentColor.withValues(alpha: 0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                      ),
                      child: _isLinking
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Link',
                              style: AppTypography.body(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: AppTypography.body(
                    color: Colors.redAccent,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onTap,
    required LoveStoryTheme theme,
  }) {
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
}

