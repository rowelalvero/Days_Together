import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';
import 'package:days_together/features/relationship/session_controller.dart';

/// The couple's encryption safety number, and -- when the server presents a
/// partner key that differs from the one this device pinned -- the warning
/// and explicit confirmation that resumes photo-key sharing (re-audit R-03 /
/// audit F-14).
///
/// The number is equal on both phones exactly when each holds the other's
/// real public key, so comparing it in person detects a substituted key,
/// including one swapped in by anyone with database admin access.
class PartnerKeySecurityCard extends ConsumerStatefulWidget {
  const PartnerKeySecurityCard({super.key, required this.theme});

  final LoveStoryTheme theme;

  @override
  ConsumerState<PartnerKeySecurityCard> createState() =>
      _PartnerKeySecurityCardState();
}

class _PartnerKeySecurityCardState
    extends ConsumerState<PartnerKeySecurityCard> {
  Future<String?>? _safetyNumber;
  bool _accepting = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _safetyNumber = ref
        .read(sessionControllerProvider.notifier)
        .loadSafetyNumber();
  }

  Future<void> _accept() async {
    setState(() => _accepting = true);
    try {
      await ref
          .read(sessionControllerProvider.notifier)
          .acceptPartnerKeyChange();
    } finally {
      if (mounted) {
        setState(() {
          _accepting = false;
          _reload();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final keyChanged = ref.watch(
      sessionControllerProvider.select((s) => s.partnerKeyChanged),
    );
    // A key change arriving while the screen is open must refresh the number
    // shown, since it is now computed from the new key.
    ref.listen(
      sessionControllerProvider.select((s) => s.partnerKeyChanged),
      (_, _) => setState(_reload),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: keyChanged
              ? theme.accentColor
              : theme.textColor.withValues(alpha: 0.15),
          width: keyChanged ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                keyChanged ? Icons.warning_amber_rounded : Icons.lock_rounded,
                color: keyChanged ? theme.accentColor : theme.textColor,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  keyChanged
                      ? 'Your partner\'s security key changed'
                      : 'Encryption safety number',
                  style: AppTypography.body(
                    color: theme.textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            keyChanged
                ? 'This happens when your partner reinstalls the app or uses a '
                      'new phone -- or if someone is trying to intercept your '
                      'photos. New photos won\'t be shared until you check that '
                      'the number below matches the one on your partner\'s phone.'
                : 'Compare this number with the one on your partner\'s phone. '
                      'If they match, only the two of you can see your photos.',
            style: AppTypography.body(
              color: theme.textColor.withValues(alpha: 0.7),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          FutureBuilder<String?>(
            future: _safetyNumber,
            builder: (context, snapshot) {
              final number = snapshot.data;
              return SelectableText(
                number ??
                    (snapshot.connectionState == ConnectionState.done
                        ? 'Not available yet'
                        : '…'),
                key: const ValueKey('safety-number'),
                style: AppTypography.bodyMono(
                  color: theme.textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ).copyWith(letterSpacing: 1.5),
              );
            },
          ),
          if (keyChanged) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _accepting ? null : _accept,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.accentColor,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  'Numbers match -- trust the new key',
                  style: AppTypography.button(fontSize: 14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
