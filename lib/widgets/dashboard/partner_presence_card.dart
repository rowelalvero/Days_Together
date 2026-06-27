import 'dart:io';
import 'package:flutter/material.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:provider/provider.dart';
import 'package:days_together/widgets/glass_container.dart';
import 'package:days_together/providers/relationship_provider.dart';
import 'package:days_together/providers/love_chat_provider.dart';

class PartnerPresenceCard extends StatefulWidget {
  final RelationshipProvider relationshipProvider;
  final dynamic theme;

  const PartnerPresenceCard({
    super.key,
    required this.relationshipProvider,
    required this.theme,
  });

  @override
  State<PartnerPresenceCard> createState() => _PartnerPresenceCardState();
}

class _PartnerPresenceCardState extends State<PartnerPresenceCard> with SingleTickerProviderStateMixin {
  bool _isTapped = false;
  bool _isOnlineSimulated = false;

  @override
  void initState() {
    super.initState();
    _isOnlineSimulated = widget.relationshipProvider.isPartnerOnline;
  }

  void _triggerLoveTap(BuildContext context) {
    setState(() {
      _isTapped = true;
    });
    // Append heart chat message in provider
    final rp = context.read<RelationshipProvider>();
    context.read<LoveChatProvider>().sendMessage('Sent a Heartbeat Tap 💓', rp.yourName ?? 'Partner');
    
    // Floating animation trigger
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (_) => const HeartBurstOverlay(),
    );

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isTapped = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final rp = widget.relationshipProvider;
    final theme = widget.theme;
    final partnerJoined = rp.partnerId != null;
    final isOnline = _isOnlineSimulated;
    final customStatus = rp.partnerConditions;

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar Stack with pulse ring
              Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isOnline ? Colors.greenAccent : Colors.white10,
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 26,
                      backgroundColor: widget.theme.textColor.withValues(alpha: 0.1),
                      foregroundImage: partnerJoined && rp.partnerAvatarPath != null
                          ? (rp.partnerAvatarPath!.startsWith('http')
                              ? NetworkImage(rp.partnerAvatarPath!) as ImageProvider
                              : (File(rp.partnerAvatarPath!).existsSync()
                                  ? FileImage(File(rp.partnerAvatarPath!))
                                  : null))
                          : null,
                      child: (!partnerJoined ||
                              rp.partnerAvatarPath == null ||
                              (rp.partnerAvatarPath!.startsWith('http') == false &&
                                  !File(rp.partnerAvatarPath!).existsSync()))
                          ? Icon(Icons.person, color: widget.theme.textColor.withValues(alpha: 0.3))
                          : null,
                      onForegroundImageError: (rp.partnerAvatarPath != null &&
                              rp.partnerAvatarPath!.startsWith('http'))
                          ? (exception, stackTrace) {
                              debugPrint('Error loading partner presence avatar: $exception');
                            }
                          : null,
                    ),
                  ),
                  Positioned(
                    right: 1,
                    bottom: 1,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: isOnline ? Colors.greenAccent : Colors.grey,
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.backgroundColor, width: 2.5),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rp.partnerName ?? 'Waiting for partner...',
                      style: AppTypography.body(fontSize: 16, fontWeight: FontWeight.bold, color: widget.theme.textColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isOnline ? 'Online Now' : 'Offline',
                      style: AppTypography.caption(fontSize: 11, color: widget.theme.textColor.withValues(alpha: 0.54)),
                    ),
                  ],
                ),
              ),
              // Demo Status Toggle
              TextButton(
                onPressed: () {
                  setState(() {
                    _isOnlineSimulated = !_isOnlineSimulated;
                  });
                },
                child: Text(
                  'Demo',
                  style: AppTypography.caption(fontSize: 10, color: theme.accentColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            customStatus.isEmpty ? 'No status set' : '"$customStatus"',
            style: AppTypography.bodyMedium(fontSize: 12, color: widget.theme.textColor.withValues(alpha: 0.7)).copyWith(fontStyle: FontStyle.italic),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Divider(color: Colors.white10, height: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'REALTIME SYNC',
                style: AppTypography.caption(fontSize: 9, color: Colors.greenAccent, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _triggerLoveTap(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isTapped ? Colors.pink : Colors.white12,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  icon: const Icon(Icons.favorite, color: Colors.pinkAccent, size: 14),
                  label: Text(
                    _isTapped ? 'Tapped!' : 'Love Tap',
                    style: AppTypography.caption(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class HeartBurstOverlay extends StatefulWidget {
  const HeartBurstOverlay({super.key});
  @override
  State<HeartBurstOverlay> createState() => _HeartBurstOverlayState();
}

class _HeartBurstOverlayState extends State<HeartBurstOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _ctrl.forward().then((_) => Navigator.pop(context));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final progress = _ctrl.value;
          return Stack(
            children: List.generate(15, (i) {
              final double top = MediaQuery.of(context).size.height * (1.0 - progress) + (i * 12) - 100;
              final double left = MediaQuery.of(context).size.width * 0.5 + (progress * (i % 2 == 0 ? 50 : -50));
              return Positioned(
                top: top,
                left: left,
                child: Opacity(
                  opacity: (1.0 - progress).clamp(0.0, 1.0),
                  child: const Icon(Icons.favorite, color: Colors.pinkAccent, size: 28),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
