import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:days_together/app/router/route_names.dart';
import 'package:days_together/features/theme/theme_controller.dart';
import 'package:days_together/features/wrapped/domain/wrapped_data.dart';
import 'package:days_together/features/wrapped/data/wrapped_service.dart';
import 'package:days_together/features/wrapped/presentation/widgets/wrapped_archive_app_bar.dart';
import 'package:days_together/features/wrapped/presentation/widgets/wrapped_archive_empty_state.dart';
import 'package:days_together/features/wrapped/presentation/widgets/wrapped_year_card.dart';

/// Displays all archived Wrapped years and allows replaying any one of them.
///
/// Painted with the active [LoveStoryTheme]'s gradient and text colors like
/// every other pushed screen. It used to hardcode a dark palette
/// (`0xFF0D0D1A` behind white type) borrowed from the cinematic Wrapped
/// playback, which read as a different app on this app's light themes --
/// and this screen is reached from Settings, not from inside that playback.
class WrappedArchiveScreen extends ConsumerStatefulWidget {
  const WrappedArchiveScreen({super.key});

  @override
  ConsumerState<WrappedArchiveScreen> createState() =>
      _WrappedArchiveScreenState();
}

class _WrappedArchiveScreenState extends ConsumerState<WrappedArchiveScreen> {
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
    final themeProvider = ref.watch(themeControllerProvider);
    final theme = themeProvider.currentLoveTheme;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: themeProvider.currentGradient),
        child: SafeArea(
          child: Column(
            children: [
              WrappedArchiveAppBar(theme: theme),
              Expanded(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: theme.accentColor,
                        ),
                      )
                    : _archivedYears.isEmpty
                    ? WrappedArchiveEmptyState(theme: theme)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                        itemCount: _archivedYears.length,
                        itemBuilder: (context, i) {
                          final year = _archivedYears[i];
                          return WrappedYearCard(
                            year: year,
                            index: i,
                            theme: theme,
                            onTap: () => _openYear(year),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
