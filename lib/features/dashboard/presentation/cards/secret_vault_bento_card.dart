import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:days_together/routing/routes.dart';
import 'package:days_together/features/vault/vault_controller.dart';
import 'package:days_together/features/vault/vault_state.dart';
import 'package:days_together/shared/glass_container.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/themes/theme_manager.dart';

/// Bento card for the Secret Vault feature on the dashboard.
/// Displays vault PIN lock status and items count.
class SecretVaultBentoCard extends StatelessWidget {
  final LoveStoryTheme theme;

  const SecretVaultBentoCard({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final vault = ref.watch(vaultControllerProvider);
        final isUnlocked = vault.isUnlocked;

        return InkWell(
          onTap: () => context.push(Routes.vault),
          borderRadius: BorderRadius.circular(24),
          child: GlassContainer(
            padding: const EdgeInsets.all(20),
            borderRadius: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: theme.accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'SECRET VAULT',
                        style: AppTypography.cardCategory(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: theme.accentColor,
                        ).copyWith(letterSpacing: 0.5),
                      ),
                    ),
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.accentColor.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.lock_outline_rounded,
                          color: theme.accentColor,
                          size: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Secret Vault',
                  style: AppTypography.title(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: theme.textColor,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.textColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: _buildVaultContent(context, vault),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        isUnlocked ? 'Vault Unlocked' : 'Vault Secured',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.captionMono(
                          fontSize: 10,
                          color: theme.textColor.withValues(alpha: 0.35),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      children: [
                        Text(
                          'Unlock Vault',
                          style: AppTypography.button(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: theme.accentColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 9,
                          color: theme.accentColor,
                        ),
                      ],
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

  Widget _buildVaultContent(BuildContext context, VaultState vault) {
    final isUnlocked = vault.isUnlocked;
    final count = vault.visibleItems.length;

    return Row(
      children: [
        Icon(
          isUnlocked ? Icons.lock_open_rounded : Icons.lock_rounded,
          color: isUnlocked ? Colors.greenAccent : theme.accentColor,
          size: 18,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isUnlocked ? 'Unlocked' : 'Locked',
                style: AppTypography.bodyMedium(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: theme.textColor,
                ),
              ),
              Text(
                isUnlocked
                    ? '$count items visible'
                    : '🔒 Enter PIN to access secret letters & photos',
                style: AppTypography.caption(
                  fontSize: 10,
                  color: theme.textColor.withValues(alpha: 0.54),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
