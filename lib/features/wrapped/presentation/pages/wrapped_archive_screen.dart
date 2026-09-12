import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:days_together/app/router/route_names.dart';
import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/features/wrapped/domain/wrapped_data.dart';
import 'package:days_together/features/wrapped/data/wrapped_service.dart';
import 'package:days_together/features/wrapped/presentation/widgets/wrapped_archive_empty_state.dart';
import 'package:days_together/features/wrapped/presentation/widgets/wrapped_year_card.dart';

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
    // The fade transition (previously 500ms here vs. settings_tab.dart's
    // 600ms for the same destination) now lives once, on app_router.dart's
    // Routes.wrapped route -- go_router defines a transition per route, not
    // per call site, so the two calls' durations are consolidated to 600ms.
    context.push(Routes.wrapped, extra: data);
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
              titlePadding: const EdgeInsets.only(
                left: 20,
                bottom: 16,
                right: 20,
              ),
              title: Text(
                '❤️ Wrapped Archive',
                style: AppTypography.heading(
                  fontSize: 20,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white54,
                size: 20,
              ),
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
            const SliverFillRemaining(child: WrappedArchiveEmptyState())
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, i) {
                  final year = _archivedYears[i];
                  return WrappedYearCard(
                    year: year,
                    index: i,
                    onTap: () => _openYear(year),
                  );
                }, childCount: _archivedYears.length),
              ),
            ),
        ],
      ),
    );
  }
}
