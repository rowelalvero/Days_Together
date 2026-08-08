import 'package:flutter/material.dart';
import 'package:days_together/themes/app_typography.dart';
import 'package:days_together/widgets/glass_container.dart';
import 'wrapped_data.dart';
import 'wrapped_screen.dart';
import 'wrapped_service.dart';

/// Displays all archived Wrapped years and allows replaying any one of them.
class WrappedArchiveScreen extends StatefulWidget {
  const WrappedArchiveScreen({super.key});

  @override
  State<WrappedArchiveScreen> createState() => _WrappedArchiveScreenState();
}

class _WrappedArchiveScreenState extends State<WrappedArchiveScreen> {
  List<int> _archivedYears = [];
  final Map<int, WrappedData?> _dataCache = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadArchives();
  }

  Future<void> _loadArchives() async {
    final years = await WrappedService.getArchivedYears();
    if (!mounted) return;
    setState(() {
      _archivedYears = years;
      _isLoading = false;
    });
  }

  Future<void> _openYear(int year) async {
    WrappedData? data = _dataCache[year];
    if (data == null) {
      data = await WrappedService.loadArchive(year);
      if (data != null) _dataCache[year] = data;
    }
    if (!mounted || data == null) return;
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => WrappedScreen(data: data!),
        transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(
          opacity: animation,
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: const Color(0xFF0D0D1A),
            expandedHeight: 120,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding:
                  const EdgeInsets.only(left: 20, bottom: 16, right: 20),
              title: Text(
                '❤️ Wrapped Archive',
                style: AppTypography.sectionHeader(
                  fontSize: 20,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white54, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFFF43F5E)),
              ),
            )
          else if (_archivedYears.isEmpty)
            SliverFillRemaining(
              child: _emptyState(),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final year = _archivedYears[i];
                    return _buildYearCard(year, i);
                  },
                  childCount: _archivedYears.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildYearCard(int year, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + index * 80),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Transform.translate(
        offset: Offset(0, 20 * (1 - v)),
        child: Opacity(opacity: v, child: child),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: GestureDetector(
          onTap: () => _openYear(year),
          child: GlassContainer(
            borderRadius: 20,
            padding: EdgeInsets.zero,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _yearColor(index).withValues(alpha: 0.15),
                    _yearColor(index).withValues(alpha: 0.05),
                  ],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _yearColor(index).withValues(alpha: 0.15),
                      border: Border.all(
                          color: _yearColor(index).withValues(alpha: 0.3),
                          width: 1),
                    ),
                    child: Center(
                      child: Text(
                        _yearEmoji(index),
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Wrapped $year',
                          style: AppTypography.sectionHeader(
                            fontSize: 20,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Your year in review',
                          style: AppTypography.body(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.45),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.play_arrow_rounded,
                      color: Colors.white.withValues(alpha: 0.4), size: 28),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _yearColor(int index) {
    const colors = [
      Color(0xFFF43F5E),
      Color(0xFF7C3AED),
      Color(0xFF06B6D4),
      Color(0xFFF59E0B),
      Color(0xFF10B981),
    ];
    return colors[index % colors.length];
  }

  String _yearEmoji(int index) {
    const emojis = ['❤️', '💜', '💙', '💛', '💚'];
    return emojis[index % emojis.length];
  }

  Widget _emptyState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('📦', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 24),
              Text(
                'No archives yet',
                style: AppTypography.sectionHeader(
                  fontSize: 22,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Once you\'ve played through your Wrapped at\nyear\'s end, it will be saved here for you\nto revisit anytime.',
                style: AppTypography.body(
                  fontSize: 15,
                  color: Colors.white.withValues(alpha: 0.45),
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}
