import 'package:days_together/themes/theme_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:share_plus/share_plus.dart';
import 'package:days_together/providers/couple_session.dart';
import 'package:days_together/features/relationship/session_controller.dart';
import 'package:days_together/features/relationship/session_state.dart';
import 'package:days_together/features/relationship/profile_controller.dart';
import 'package:days_together/features/relationship/profile_state.dart';
import 'package:days_together/features/relationship/workspace_controller.dart';
import 'package:days_together/features/relationship/workspace_state.dart';
import 'package:days_together/services/date_helper.dart';
import 'package:days_together/features/theme/theme_controller.dart';
import 'package:days_together/shared/glass_container.dart';
import 'package:days_together/features/relationship/presentation/profile/delete_account_confirmation_dialog.dart';
import 'package:days_together/features/relationship/presentation/profile/edit_profile_dialog.dart';
import 'package:days_together/features/relationship/presentation/profile/regenerate_recovery_code_dialog.dart';
import 'package:days_together/features/relationship/presentation/profile/unlink_confirmation_dialog.dart';
import 'package:days_together/shared/cached_avatar.dart';

class RelationshipProfileScreen extends ConsumerWidget {
  const RelationshipProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeProvider = ref.watch(themeControllerProvider);
    final theme = themeProvider.currentLoveTheme;
    // Instance handle only -- never dereferenced for a field directly in
    // this build method, just threaded into several downstream dialogs
    // (EditProfileDialog, RegenerateRecoveryCodeDialog,
    // UnlinkConfirmationDialog, DeleteAccountConfirmationDialog -- all out of
    // this conversion's scope) that call mutation methods on it. Those
    // "prop-drilled" widgets depend only on CoupleSession's public method
    // surface, not on it being reactively watched, so a plain `ref.read`
    // (not `ref.watch`/`context.watch`) is correct here -- this widget's own
    // rebuild-on-change needs are covered by sessionControllerProvider/
    // profileControllerProvider/workspaceControllerProvider above, which are
    // properly watched.
    final rp = ref.read(coupleSessionProvider);
    final sessionState = ref.watch(sessionControllerProvider);
    final profileState = ref.watch(profileControllerProvider);
    final workspaceState = ref.watch(workspaceControllerProvider);
    final partnerJoined = sessionState.partnerId != null;

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
                      _buildHeaderSection(context, rp, sessionState, profileState, theme),
                      const SizedBox(height: 32),
                      _buildInfoCard(context, ref, workspaceState, profileState, theme),
                      const SizedBox(height: 32),
                      if (!partnerJoined && workspaceState.coupleCode != null) ...[
                        PairingOptionsSection(theme: theme),
                        const SizedBox(height: 32),
                      ],
                      const SizedBox(height: 16),
                      _buildRegenerateRecoveryCodeButton(context, rp, theme),
                      const SizedBox(height: 16),
                      _buildDangerZoneDivider(theme),
                      const SizedBox(height: 20),
                      _buildUnlinkButton(context, rp, sessionState, theme),
                      if (partnerJoined) const SizedBox(height: 16),
                      _buildDeleteAccountButton(context, rp, theme),
                      const SizedBox(height: 24),
                      _buildAuthDebugInfo(sessionState, theme),
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

  Widget _buildAuthDebugInfo(SessionState sessionState, LoveStoryTheme theme) {
    return Center(
      child: Opacity(
        opacity: 0.3,
        child: Text(
          'UID: ${sessionState.userId?.substring(0, 8) ?? "None"} • CID: ${sessionState.coupleId?.substring(0, 8) ?? "None"}',
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
    SessionState sessionState,
    ProfileState profileState,
    LoveStoryTheme theme,
  ) {
    final partnerJoined = sessionState.partnerId != null;
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
                profileState.yourAvatarPath,
                profileState.yourName ?? 'You',
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
                  profileState.partnerAvatarPath,
                  profileState.partnerName ?? 'Partner',
                  theme,
                )
              else
                _buildAvatarPlaceholder(theme),
            ],
          ),
          const SizedBox(height: 32),
          if (partnerJoined) ...[
            Text(
              '${profileState.yourName ?? 'You'} & ${profileState.partnerName ?? 'Partner'}',
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
              profileState.yourName ?? 'You',
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
            onPressed: () => EditProfileDialog.show(context, rp, theme),
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
    WidgetRef ref,
    WorkspaceState workspaceState,
    ProfileState profileState,
    LoveStoryTheme theme,
  ) {
    final start = workspaceState.startDate;
    final formattedStart = start != null
        ? DateFormat('MMMM dd, yyyy').format(start)
        : 'Not Set';
    final formattedTime = workspaceState.startTime != null
        ? workspaceState.startTime!.format(context)
        : '12:00 AM';
    final ageStr = DateHelper.relationshipAgeLabel(workspaceState.startDate, workspaceState.startTime);

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
              onTap: () => _editDate(context, ref, workspaceState, theme),
            ),
            _StatTile(
              icon: Icons.access_time_rounded,
              label: 'Time',
              value: formattedTime,
              theme: theme,
              onTap: () => _editTime(context, ref, workspaceState, theme),
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
              value: profileState.yourJoinDate != null
                  ? DateFormat('MMM dd, yyyy').format(profileState.yourJoinDate!)
                  : '...',
              theme: theme,
            ),
            _StatTile(
              icon: Icons.people_outline_rounded,
              label: 'Partner Join Date',
              value: profileState.partnerJoinDate != null
                  ? DateFormat('MMM dd, yyyy').format(profileState.partnerJoinDate!)
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
    WidgetRef ref,
    WorkspaceState workspaceState,
    LoveStoryTheme theme,
  ) async {
    final date = await showDatePicker(
      context: context,
      initialDate: workspaceState.startDate ?? DateTime.now(),
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
    if (date != null) {
      await ref.read(workspaceControllerProvider.notifier).setStartDate(date);
    }
  }

  Future<void> _editTime(
    BuildContext context,
    WidgetRef ref,
    WorkspaceState workspaceState,
    LoveStoryTheme theme,
  ) async {
    final time = await showTimePicker(
      context: context,
      initialTime: workspaceState.startTime ?? TimeOfDay.now(),
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
    if (time != null) {
      await ref.read(workspaceControllerProvider.notifier).setStartTime(time);
    }
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
        onPressed: () => RegenerateRecoveryCodeDialog.show(context, rp, theme),
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
    SessionState sessionState,
    LoveStoryTheme theme,
  ) {
    final partnerJoined = sessionState.partnerId != null;
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
        onPressed: () => UnlinkConfirmationDialog.show(context, rp, theme),
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
        onPressed: () => DeleteAccountConfirmationDialog.show(context, rp, theme),
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

class PairingOptionsSection extends ConsumerStatefulWidget {
  final LoveStoryTheme theme;

  const PairingOptionsSection({
    super.key,
    required this.theme,
  });

  @override
  ConsumerState<PairingOptionsSection> createState() => _PairingOptionsSectionState();
}

class _PairingOptionsSectionState extends ConsumerState<PairingOptionsSection> {
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
      final success = await ref.read(sessionControllerProvider.notifier).joinWithCode(code);
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
    final code = ref.watch(workspaceControllerProvider).coupleCode ?? '';

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

