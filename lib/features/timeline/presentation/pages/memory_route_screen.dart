import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:days_together/app/router/route_names.dart';
import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/features/theme/theme_controller.dart';
import 'package:days_together/features/timeline/presentation/pages/memory_detail_screen.dart';
import 'package:days_together/features/timeline/timeline_controller.dart';

/// The `/memories/:itemId` destination (a tapped notification, a dashboard
/// card). The timeline only keeps a page of memories loaded, so the memory
/// may not be in memory yet: this shows it straight away when it is, and
/// otherwise fetches it -- with a spinner, a "no longer exists" state if it
/// was deleted, and a retry if the fetch failed.
class MemoryRouteScreen extends ConsumerStatefulWidget {
  const MemoryRouteScreen({super.key, required this.itemId});

  final String itemId;

  @override
  ConsumerState<MemoryRouteScreen> createState() => _MemoryRouteScreenState();
}

enum _Lookup { loading, notFound, failed }

class _MemoryRouteScreenState extends ConsumerState<MemoryRouteScreen> {
  _Lookup _lookup = _Lookup.loading;

  @override
  void initState() {
    super.initState();
    if (ref.read(timelineControllerProvider).itemById(widget.itemId) == null) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _lookup = _Lookup.loading);
    try {
      final item = await ref
          .read(timelineControllerProvider.notifier)
          .loadMemory(widget.itemId);
      if (!mounted) return;
      if (item == null) setState(() => _lookup = _Lookup.notFound);
    } catch (_) {
      if (!mounted) return;
      setState(() => _lookup = _Lookup.failed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = ref.watch(
      timelineControllerProvider.select((s) => s.itemById(widget.itemId)),
    );
    if (item != null) return MemoryDetailScreen(item: item);

    final themeState = ref.watch(themeControllerProvider);
    final theme = themeState.currentLoveTheme;
    final Widget body = switch (_lookup) {
      _Lookup.loading => CircularProgressIndicator(color: theme.accentColor),
      _Lookup.notFound => _Message(
        color: theme.textColor,
        text: 'This memory no longer exists.',
        actionLabel: 'Go to timeline',
        onAction: () => context.go(Routes.homeTab(1)),
      ),
      _Lookup.failed => _Message(
        color: theme.textColor,
        text: "Couldn't load this memory.",
        actionLabel: 'Try again',
        onAction: _load,
      ),
    };
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: themeState.currentGradient),
        child: SafeArea(
          child: Stack(
            children: [
              Center(child: body),
              Align(
                alignment: Alignment.topLeft,
                child: BackButton(
                  color: theme.textColor,
                  onPressed: () => context.canPop()
                      ? context.pop()
                      : context.go(Routes.homeTab(1)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.color,
    required this.text,
    required this.actionLabel,
    required this.onAction,
  });

  final Color color;
  final String text;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          style: AppTypography.body(color: color, fontSize: 16),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: onAction,
          child: Text(
            actionLabel,
            style: AppTypography.body(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
