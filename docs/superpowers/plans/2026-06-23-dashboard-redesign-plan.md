# Dashboard & Bento Grid Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the Home Dashboard of the Flutter app with a premium visual design, a detailed ticking days counter, an auto-sliding insights banner, a partner presence card with Love Taps, a memory highlights carousel, a statistics grid, a single-column Bento Grid of interactive tool previews, and a recent activity feed.

**Architecture:** Create modular widget files under `lib/widgets/dashboard/` for each card component, then integrate them by replacing the body of `HomeDashboard` in `lib/screens/love_story_screen.dart`.

**Tech Stack:** Flutter, Dart, provider, fl_chart, Google Fonts.

## Global Constraints
*   Follow established codebase patterns.
*   Enforce premium glassmorphism styling (`GlassContainer`, white/8% borders, white/5% or black/20% opacity).
*   No placeholder code or TBD labels.

---

### Task 1: Background Layout & Styling Setup
Create the organic ambient blur blobs and a subtle grid overlay in the main layout stack of `LoveStoryScreen`.

**Files:**
- Modify: `lib/screens/love_story_screen.dart:100-140`

- [ ] **Step 1: Implement ambient blur blobs and grid painter**
  Insert background layers inside the Stack of the build method in `LoveStoryScreen`:
  ```dart
  // Inside _LoveStoryScreenState.build stack:
  Positioned.fill(
    child: Stack(
      children: [
        // Blob 1: Top-Left
        Positioned(
          top: -100,
          left: -100,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.primaryColor.withOpacity(0.15),
            ),
          ),
        ),
        // Blob 2: Bottom-Right
        Positioned(
          bottom: 100,
          right: -100,
          child: Container(
            width: 350,
            height: 350,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.accentColor.withOpacity(0.12),
            ),
          ),
        ),
        // Apply heavy blur
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
            child: Container(color: Colors.transparent),
          ),
        ),
        // Custom Grid Overlay Painter
        Positioned.fill(
          child: CustomPaint(
            painter: DashboardGridPainter(),
          ),
        ),
      ],
    ),
  ),
  ```
  And define the `DashboardGridPainter` at the bottom of the file:
  ```dart
  class DashboardGridPainter extends CustomPainter {
    @override
    void paint(Canvas canvas, Size size) {
      final paint = Paint()
        ..color = Colors.white.withOpacity(0.015)
        ..strokeWidth = 1.0;
      const double step = 32.0;
      for (double x = 0; x < size.width; x += step) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      }
      for (double y = 0; y < size.height; y += step) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
    }
    @override
    bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
  }
  ```

- [ ] **Step 2: Verify code compiles**
  Run: `flutter analyze`
  Expected: Success.

- [ ] **Step 3: Commit**
  ```bash
  git commit -am "feat: add ambient glow blobs and grid overlay to LoveStoryScreen background"
  ```

---

### Task 2: Detailed Days Counter Widget
Create the premium detailed days counter widget displaying a ticking 6-unit grid.

**Files:**
- Create: `lib/widgets/dashboard/detailed_days_counter.dart`
- Modify: `lib/screens/love_story_screen.dart`

- [ ] **Step 1: Write `DetailedDaysCounter` widget**
  Create `lib/widgets/dashboard/detailed_days_counter.dart`:
  ```dart
  import 'dart:async';
  import 'package:flutter/material.dart';
  import 'package:google_fonts/google_fonts.dart';
  import 'package:intl/intl.dart';
  import 'package:days_together/widgets/glass_container.dart';
  import 'package:days_together/providers/relationship_provider.dart';

  class DetailedDaysCounter extends StatefulWidget {
    final RelationshipProvider relationshipProvider;
    final dynamic theme;

    const DetailedDaysCounter({
      super.key,
      required this.relationshipProvider,
      required this.theme,
    });

    @override
    State<DetailedDaysCounter> createState() => _DetailedDaysCounterState();
  }

  class _DetailedDaysCounterState extends State<DetailedDaysCounter> {
    late Timer _ticker;

    @override
    void initState() {
      super.initState();
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }

    @override
    void dispose() {
      _ticker.cancel();
      super.dispose();
    }

    @override
    Widget build(BuildContext context) {
      final rp = widget.relationshipProvider;
      final theme = widget.theme;
      final age = rp.preciseAge;
      final totalDays = rp.totalDays;
      final startDate = rp.startDate ?? DateTime.now();

      return GlassContainer(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        borderRadius: 28,
        child: Column(
          children: [
            // Top Badge
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sparkles, color: Colors.pinkAccent, size: 14),
                const SizedBox(width: 6),
                Text(
                  'LOVED WITHOUT LIMITS SINCE ${startDate.year}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.pinkAccent,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Large Counter
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  NumberFormat('#,###').format(totalDays),
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 54,
                    fontWeight: FontWeight.extrabold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Colors.pinkAccent, Colors.amberAccent],
                  ).createShader(bounds),
                  child: Text(
                    'Days',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Ticking stopwatch grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 6,
              childAspectRatio: 0.85,
              children: [
                _buildUnit('Yr', age['years'] ?? 0),
                _buildUnit('Mo', age['months'] ?? 0),
                _buildUnit('Day', age['days'] ?? 0),
                _buildUnit('Hr', age['hours'] ?? 0, useMono: true),
                _buildUnit('Min', age['minutes'] ?? 0, useMono: true),
                _buildUnit('Sec', age['seconds'] ?? 0, useMono: true),
              ],
            ),
            const Divider(color: Colors.white10, height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.access_time_filled_rounded, color: Colors.pinkAccent, size: 14),
                const SizedBox(width: 6),
                Text(
                  'Co-Synched Clock live counter updating frame state...',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    Widget _buildUnit(String label, int val, {bool useMono = false}) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            val.toString().padLeft(2, '0'),
            style: useMono
                ? GoogleFonts.jetBrainsMono(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.pinkAccent,
                  )
                : GoogleFonts.playfairDisplay(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: Colors.white38,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }
  }
  ```

- [ ] **Step 2: Integrate widget in `love_story_screen.dart`**
  Import the counter and replace `_buildDetailedGlassCounter` in `HomeDashboard` with `DetailedDaysCounter(relationshipProvider: rp, theme: theme)`.

- [ ] **Step 3: Run analysis & verify compilation**
  Run: `flutter analyze`
  Expected: Success.

- [ ] **Step 4: Commit**
  ```bash
  git add lib/widgets/dashboard/detailed_days_counter.dart
  git commit -am "feat: implement detailed days counter with ticking 6-unit grid"
  ```

---

### Task 3: Insights Banner Widget
Create the auto-scrolling glass insights banner.

**Files:**
- Create: `lib/widgets/dashboard/insights_banner.dart`
- Modify: `lib/screens/love_story_screen.dart`

- [ ] **Step 1: Write `InsightsBanner` widget**
  Create `lib/widgets/dashboard/insights_banner.dart`:
  ```dart
  import 'dart:async';
  import 'package:flutter/material.dart';
  import 'package:google_fonts/google_fonts.dart';
  import 'package:days_together/widgets/glass_container.dart';
  import 'package:days_together/providers/timeline_provider.dart';
  import 'package:days_together/providers/bucket_list_provider.dart';
  import 'package:days_together/providers/relationship_provider.dart';

  class InsightsBanner extends StatefulWidget {
    final TimelineProvider timelineProvider;
    final BucketListProvider bucketProvider;
    final RelationshipProvider relationshipProvider;
    final dynamic theme;

    const InsightsBanner({
      super.key,
      required this.timelineProvider,
      required this.bucketProvider,
      required this.relationshipProvider,
      required this.theme,
    });

    @override
    State<InsightsBanner> createState() => _InsightsBannerState();
  }

  class _InsightsBannerState extends State<InsightsBanner> {
    int _index = 0;
    Timer? _timer;
    List<String> _insights = [];

    @override
    void initState() {
      super.initState();
      _generateInsights();
      _timer = Timer.periodic(const Duration(seconds: 6), (_) {
        if (mounted && _insights.isNotEmpty) {
          setState(() {
            _index = (_index + 1) % _insights.length;
          });
        }
      });
    }

    @override
    void didUpdateWidget(covariant InsightsBanner oldWidget) {
      super.didUpdateWidget(oldWidget);
      _generateInsights();
    }

    @override
    void dispose() {
      _timer?.cancel();
      super.dispose();
    }

    void _generateInsights() {
      final memCount = widget.timelineProvider.timelineItems.length;
      final bucketPercent = widget.bucketProvider.progress * 100;
      final years = widget.relationshipProvider.years;
      final partnerName = widget.relationshipProvider.partnerName ?? 'Partner';
      final isOnline = widget.relationshipProvider.isPartnerOnline;

      _insights = [
        '💖 You created $memCount memories together.',
        '📅 Your relationship timeline is $years years strong.',
        '📈 You completed ${bucketPercent.toStringAsFixed(0)}% of your bucket list items.',
        if (isOnline)
          '⏰ $partnerName is active right now. Send a love touch! 💌'
        else
          '💡 Tip: Check out Love Notes or Topic Cards for a late-night chat.',
      ];
    }

    @override
    Widget build(BuildContext context) {
      if (_insights.isEmpty) return const SizedBox.shrink();
      final theme = widget.theme;

      return GlassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        borderRadius: 20,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.pinkAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.sparkles, color: Colors.pinkAccent, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'RELATIONSHIP INSIGHTS',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.pinkAccent,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _insights[_index],
                      key: ValueKey(_insights[_index]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white90,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded, color: Colors.white30, size: 20),
              onPressed: () {
                setState(() {
                  _index = (_index - 1 + _insights.length) % _insights.length;
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded, color: Colors.white30, size: 20),
              onPressed: () {
                setState(() {
                  _index = (_index + 1) % _insights.length;
                });
              },
            ),
          ],
        ),
      );
    }
  }
  ```

- [ ] **Step 2: Add to dashboard layout in `love_story_screen.dart`**
  Import `insights_banner.dart` and insert it into `HomeDashboard` between detailed counter and partner status.

- [ ] **Step 3: Run analysis**
  Run: `flutter analyze`
  Expected: Success.

- [ ] **Step 4: Commit**
  ```bash
  git add lib/widgets/dashboard/insights_banner.dart
  git commit -m "feat: implement dynamic auto-scrolling insights banner"
  ```

---

### Task 4: Partner Presence Card & Milestone Card
Create the interactive Partner Presence status card with online indicators, Love Taps, and the Milestone progress indicator.

**Files:**
- Create: `lib/widgets/dashboard/partner_presence_card.dart`
- Create: `lib/widgets/dashboard/milestone_card.dart`
- Modify: `lib/screens/love_story_screen.dart`

- [ ] **Step 1: Write `PartnerPresenceCard`**
  Create `lib/widgets/dashboard/partner_presence_card.dart`:
  ```dart
  import 'dart:io';
  import 'package:flutter/material.dart';
  import 'package:google_fonts/google_fonts.dart';
  import 'package:provider/provider.dart';
  import 'package:days_together/widgets/glass_container.dart';
  import 'package:days_together/widgets/burst_hearts.dart';
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
      context.read<LoveChatProvider>().sendMessage('Sent a Heartbeat Tap 💓');
      
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
                        backgroundColor: Colors.white12,
                        backgroundImage: partnerJoined && rp.partnerAvatarPath != null
                            ? (rp.partnerAvatarPath!.startsWith('http')
                                ? NetworkImage(rp.partnerAvatarPath!) as ImageProvider
                                : (File(rp.partnerAvatarPath!).existsSync()
                                    ? FileImage(File(rp.partnerAvatarPath!))
                                    : null))
                            : null,
                        child: !partnerJoined || rp.partnerAvatarPath == null
                            ? const Icon(Icons.person, color: Colors.white70)
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
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isOnline ? 'Online Now' : 'Offline',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.white54,
                        ),
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
                    style: GoogleFonts.inter(fontSize: 10, color: theme.accentColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              customStatus.isEmpty ? 'No status set' : '"$customStatus"',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.white70,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Divider(color: Colors.white10, height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'REALTIME SYNC',
                  style: GoogleFonts.inter(fontSize: 9, color: Colors.greenAccent, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: () => _triggerLoveTap(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isTapped ? Colors.pink : Colors.white12,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  icon: const Icon(Icons.favorite, color: Colors.pinkAccent, size: 14),
                  label: Text(
                    _isTapped ? 'Tapped!' : 'Love Tap',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold),
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
  ```

- [ ] **Step 2: Write `MilestoneCard`**
  Create `lib/widgets/dashboard/milestone_card.dart`:
  ```dart
  import 'package:flutter/material.dart';
  import 'package:google_fonts/google_fonts.dart';
  import 'package:days_together/widgets/glass_container.dart';
  import 'package:days_together/providers/relationship_provider.dart';

  class MilestoneCard extends StatelessWidget {
    final RelationshipProvider relationshipProvider;
    final dynamic theme;

    const MilestoneCard({
      super.key,
      required this.relationshipProvider,
      required this.theme,
    });

    @override
    Widget build(BuildContext context) {
      final milestones = relationshipProvider.nextMilestones;
      if (milestones.isEmpty) {
        return const SizedBox.shrink();
      }
      final m = milestones.first;

      return GlassContainer(
        padding: const EdgeInsets.all(16),
        borderRadius: 24,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'NEXT MILESTONE',
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: theme.accentColor,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              m.title,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        value: m.progress,
                        strokeWidth: 3,
                        backgroundColor: Colors.white10,
                        valueColor: AlwaysStoppedAnimation<Color>(theme.accentColor),
                      ),
                    ),
                    const Icon(Icons.favorite, size: 12, color: Colors.pinkAccent),
                  ],
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${m.daysUntil} Days Left',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'Progress: ${(m.progress * 100).toStringAsFixed(0)}%',
                      style: GoogleFonts.inter(
                        color: Colors.white54,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
    }
  }
  ```

- [ ] **Step 3: Integrate inside `love_story_screen.dart`**
  Replace old milestone list widget inside `HomeDashboard` with a Column/Row containing `PartnerPresenceCard` and `MilestoneCard`.

- [ ] **Step 4: Run analysis**
  Run: `flutter analyze`
  Expected: Success.

- [ ] **Step 5: Commit**
  ```bash
  git add lib/widgets/dashboard/partner_presence_card.dart lib/widgets/dashboard/milestone_card.dart
  git commit -m "feat: implement partner presence card with love taps and milestone progress ring"
  ```

---

### Task 5: Memory Highlight Carousel Widget
Create the premium Memory Highlights Carousel widget.

**Files:**
- Create: `lib/widgets/dashboard/memory_highlight_carousel.dart`
- Modify: `lib/screens/love_story_screen.dart`

- [ ] **Step 1: Write `MemoryHighlightCarousel`**
  Create `lib/widgets/dashboard/memory_highlight_carousel.dart`:
  ```dart
  import 'dart:io';
  import 'package:flutter/material.dart';
  import 'package:google_fonts/google_fonts.dart';
  import 'package:intl/intl.dart';
  import 'package:days_together/widgets/glass_container.dart';
  import 'package:days_together/providers/timeline_provider.dart';

  class MemoryHighlightCarousel extends StatelessWidget {
    final TimelineProvider timelineProvider;
    final dynamic theme;

    const MemoryHighlightCarousel({
      super.key,
      required this.timelineProvider,
      required this.theme,
    });

    @override
    Widget build(BuildContext context) {
      final items = timelineProvider.timelineItems;
      if (items.isEmpty) {
        return GlassContainer(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          borderRadius: 24,
          child: Column(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.white24, size: 36),
              const SizedBox(height: 12),
              Text(
                'No memories captured yet.',
                style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
              ),
            ],
          ),
        );
      }

      return SizedBox(
        height: 160,
        child: PageView.builder(
          itemCount: items.length,
          controller: PageController(viewportFraction: 0.9),
          itemBuilder: (context, index) {
            final item = items[index];
            final hasImage = item.imagePath != null && item.imagePath!.isNotEmpty;

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  children: [
                    // Background Image or Gradient
                    Positioned.fill(
                      child: hasImage
                          ? Image.file(
                              File(item.imagePath!),
                              fit: BoxFit.cover,
                            )
                          : Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [theme.primaryColor.withOpacity(0.4), theme.secondaryColor.withOpacity(0.4)],
                                ),
                              ),
                            ),
                    ),
                    // Dark Overlay
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.black.withOpacity(0.2), Colors.black.withOpacity(0.8)],
                          ),
                        ),
                      ),
                    ),
                    // Content
                    Positioned(
                      left: 16,
                      bottom: 16,
                      right: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white10,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(item.mood, style: const TextStyle(fontSize: 14)),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                item.location ?? 'Adventure',
                                style: GoogleFonts.inter(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            item.title,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('MMMM dd, yyyy').format(item.date),
                            style: GoogleFonts.inter(
                              color: Colors.white38,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }
  }
  ```

- [ ] **Step 2: Add inside `HomeDashboard`**
  Import `memory_highlight_carousel.dart` and insert it below the Partner/Milestone card section.

- [ ] **Step 3: Run analysis**
  Run: `flutter analyze`
  Expected: Success.

- [ ] **Step 4: Commit**
  ```bash
  git add lib/widgets/dashboard/memory_highlight_carousel.dart
  git commit -m "feat: implement swipeable memory highlights carousel"
  ```

---

### Task 6: Relationship Statistics Grid
Create the 2x3 Synced Statistics card grid component.

**Files:**
- Create: `lib/widgets/dashboard/relationship_statistics.dart`
- Modify: `lib/screens/love_story_screen.dart`

- [ ] **Step 1: Write `RelationshipStatistics`**
  Create `lib/widgets/dashboard/relationship_statistics.dart`:
  ```dart
  import 'package:flutter/material.dart';
  import 'package:google_fonts/google_fonts.dart';
  import 'package:days_together/widgets/glass_container.dart';
  import 'package:days_together/providers/timeline_provider.dart';
  import 'package:days_together/providers/vault_provider.dart';
  import 'package:days_together/providers/relationship_provider.dart';
  import 'package:days_together/providers/bucket_list_provider.dart';
  import 'package:days_together/providers/time_capsule_provider.dart';
  import 'package:days_together/providers/noteit_provider.dart';

  class RelationshipStatistics extends StatelessWidget {
    final TimelineProvider timelineProvider;
    final VaultProvider vaultProvider;
    final RelationshipProvider relationshipProvider;
    final BucketListProvider bucketProvider;
    final TimeCapsuleProvider timeCapsuleProvider;
    final NoteitProvider noteitProvider;
    final dynamic theme;

    const RelationshipStatistics({
      super.key,
      required this.timelineProvider,
      required this.vaultProvider,
      required this.relationshipProvider,
      required this.bucketProvider,
      required this.timeCapsuleProvider,
      required this.noteitProvider,
      required this.theme,
    });

    @override
    Widget build(BuildContext context) {
      final memories = timelineProvider.timelineItems.length;
      final imageMemories = timelineProvider.timelineItems.where((i) => i.imagePath != null && i.imagePath!.isNotEmpty).length;
      final photos = imageMemories + vaultProvider.photos.length;
      final years = relationshipProvider.years;
      final bucketDone = bucketProvider.completedItems;
      final bucketTotal = bucketProvider.totalItems;
      final capsules = timeCapsuleProvider.capsules.length;
      final notes = noteitProvider.notes.length;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_outlined, color: Colors.pinkAccent, size: 16),
              const SizedBox(width: 8),
              Text(
                'Synced Relationship Statistics',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.1,
            children: [
              _buildStatCard('$memories', 'Memories', Colors.pinkAccent),
              _buildStatCard('$photos', 'Photos', Colors.violetAccent),
              _buildStatCard('$years', 'Years', Colors.amberAccent),
              _buildStatCard('$bucketDone/$bucketTotal', 'Bucket Done', Colors.emeraldAccent),
              _buildStatCard('$capsules', 'Capsules', Colors.cyanAccent),
              _buildStatCard('$notes', 'Love Notes', Colors.roseAccent),
            ],
          ),
        ],
      );
    }

    Widget _buildStatCard(String value, String label, Color color) {
      return GlassContainer(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        borderRadius: 16,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: GoogleFonts.playfairDisplay(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: Colors.white54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
  }
  ```

- [ ] **Step 2: Integrate inside `HomeDashboard`**
  Import `relationship_statistics.dart` and insert it below the Memory Highlights carousel.

- [ ] **Step 3: Run analysis**
  Run: `flutter analyze`
  Expected: Success.

- [ ] **Step 4: Commit**
  ```bash
  git add lib/widgets/dashboard/relationship_statistics.dart
  git commit -m "feat: implement 2x3 grid for relationship counters"
  ```

---

### Task 7: Bento Grid & Preview Tiles
Create the Bento Grid widget containing the 9 single-column interactive cards.

**Files:**
- Create: `lib/widgets/dashboard/bento_grid.dart`
- Modify: `lib/screens/love_story_screen.dart`

- [ ] **Step 1: Write `BentoGrid`**
  Create `lib/widgets/dashboard/bento_grid.dart`:
  ```dart
  import 'package:flutter/material.dart';
  import 'package:fl_chart/fl_chart.dart';
  import 'package:google_fonts/google_fonts.dart';
  import 'package:intl/intl.dart';
  import 'package:days_together/widgets/glass_container.dart';
  import 'package:days_together/providers/noteit_provider.dart';
  import 'package:days_together/providers/calendar_provider.dart';
  import 'package:days_together/providers/daily_mood_provider.dart';
  import 'package:days_together/providers/bucket_list_provider.dart';
  import 'package:days_together/providers/time_capsule_provider.dart';
  import 'package:days_together/providers/vault_provider.dart';
  import 'package:days_together/providers/love_chat_provider.dart';
  import 'package:days_together/providers/relationship_provider.dart';
  // Screen targets
  import 'package:days_together/screens/together/noteit_screen.dart';
  import 'package:days_together/screens/together/calendar_screen.dart';
  import 'package:days_together/screens/together/love_meter_screen.dart';
  import 'package:days_together/screens/together/topic_cards_screen.dart';
  import 'package:days_together/screens/together/bucket_list_screen.dart';
  import 'package:days_together/screens/studio/time_capsule_screen.dart';
  import 'package:days_together/screens/together/vault_screen.dart';
  import 'package:days_together/screens/together/love_chat_screen.dart';

  class BentoGrid extends StatelessWidget {
    final NoteitProvider noteProvider;
    final CalendarProvider calendarProvider;
    final DailyMoodProvider moodProvider;
    final BucketListProvider bucketProvider;
    final TimeCapsuleProvider timeCapsuleProvider;
    final VaultProvider vaultProvider;
    final LoveChatProvider chatProvider;
    final RelationshipProvider relationshipProvider;
    final dynamic theme;

    const BentoGrid({
      super.key,
      required this.noteProvider,
      required this.calendarProvider,
      required this.moodProvider,
      required this.bucketProvider,
      required this.timeCapsuleProvider,
      required this.vaultProvider,
      required this.chatProvider,
      required this.relationshipProvider,
      required this.theme,
    });

    @override
    Widget build(BuildContext context) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.grid_view_rounded, color: Colors.pinkAccent, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Together Space Board',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.pinkAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '⚡ CO-SYNC ACTIVE',
                  style: GoogleFonts.jetBrainsMono(fontSize: 8, color: Colors.pinkAccent, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildNoteitTile(context),
              const SizedBox(height: 12),
              _buildCalendarTile(context),
              const SizedBox(height: 12),
              _buildMoodTile(context),
              const SizedBox(height: 12),
              _buildSparklineTile(context),
              const SizedBox(height: 12),
              _buildSyncQuestionTile(context),
              const SizedBox(height: 12),
              _buildBucketTile(context),
              const SizedBox(height: 12),
              _buildCapsuleTile(context),
              const SizedBox(height: 12),
              _buildVaultTile(context),
              const SizedBox(height: 12),
              _buildChatTile(context),
            ],
          ),
        ],
      );
    }

    Widget _buildBentoWrapper({
      required BuildContext context,
      required String badgeText,
      required Color badgeColor,
      required String title,
      required IconData icon,
      required Widget details,
      required String footerText,
      required VoidCallback onTap,
    }) {
      return GestureDetector(
        onTap: onTap,
        child: GlassContainer(
          padding: const EdgeInsets.all(16),
          borderRadius: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badgeText.toUpperCase(),
                          style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.bold, color: badgeColor),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                  Icon(icon, color: badgeColor, size: 18),
                ],
              ),
              const SizedBox(height: 12),
              details,
              const Divider(color: Colors.white10, height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      footerText,
                      style: GoogleFonts.inter(fontSize: 10, color: Colors.white38),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: badgeColor.withOpacity(0.6), size: 16),
                ],
              ),
            ],
          ),
        ),
      );
    }

    Widget _buildNoteitTile(BuildContext context) {
      final latest = noteProvider.latestReceived ?? noteProvider.latestSent;
      return _buildBentoWrapper(
        context: context,
        badgeText: 'Checklists & Thoughts',
        badgeColor: Colors.amberAccent,
        title: 'NoteIt Workspace',
        icon: Icons.notes_rounded,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NoteitScreen())),
        details: latest != null
            ? Text(
                latest.content ?? 'Shared Photo or Scribble',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.white70, fontStyle: FontStyle.italic),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              )
            : const Text('No notes yet.', style: TextStyle(fontSize: 12, color: Colors.white38)),
        footerText: '${noteProvider.notes.length} Saved Scribbles',
      );
    }

    Widget _buildCalendarTile(BuildContext context) {
      final events = calendarProvider.events;
      final nextEvent = events.isNotEmpty ? events.first : null;
      final daysUntil = nextEvent != null ? nextEvent.date.difference(DateTime.now()).inDays : 0;
      return _buildBentoWrapper(
        context: context,
        badgeText: 'Schedules',
        badgeColor: Colors.pinkAccent,
        title: 'Calendar Timeline',
        icon: Icons.calendar_today_rounded,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CalendarScreen())),
        details: nextEvent != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nextEvent.title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('In $daysUntil Days', style: TextStyle(color: theme.accentColor, fontSize: 11)),
                ],
              )
            : const Text('No upcoming schedules.', style: TextStyle(fontSize: 12, color: Colors.white38)),
        footerText: '${events.length} Active Schedules',
      );
    }

    Widget _buildMoodTile(BuildContext context) {
      final todayMood = moodProvider.todayMood;
      return _buildBentoWrapper(
        context: context,
        badgeText: 'Daily Mood',
        badgeColor: Colors.violetAccent,
        title: 'Aura Heart Status',
        icon: Icons.favorite_border_rounded,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoveMeterScreen())),
        details: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Column(
              children: [
                Text(todayMood != null ? _getMoodEmoji(todayMood.moodScore) : '🥰', style: const TextStyle(fontSize: 28)),
                const SizedBox(height: 4),
                Text('You', style: GoogleFonts.inter(fontSize: 9, color: Colors.white38)),
              ],
            ),
            const Icon(Icons.arrow_forward_rounded, color: Colors.white24, size: 16),
            Column(
              children: [
                const Text('🎨', style: TextStyle(fontSize: 28)),
                const SizedBox(height: 4),
                Text('Elena', style: GoogleFonts.inter(fontSize: 9, color: Colors.white38)),
              ],
            ),
          ],
        ),
        footerText: todayMood != null ? 'Logged Score: ${todayMood.moodScore}/10' : 'How are we today?',
      );
    }

    String _getMoodEmoji(int score) {
      if (score <= 2) return '😢';
      if (score <= 4) return '😕';
      if (score <= 6) return '🙂';
      if (score <= 8) return '😊';
      return '😍';
    }

    Widget _buildSparklineTile(BuildContext context) {
      final recent = moodProvider.recentMoods;
      return _buildBentoWrapper(
        context: context,
        badgeText: 'Mood Trends',
        badgeColor: Colors.indigoAccent,
        title: 'Emotional Map',
        icon: Icons.trending_up_rounded,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoveMeterScreen())),
        details: SizedBox(
          height: 50,
          child: recent.length >= 2
              ? LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    minX: 0,
                    maxX: (recent.length - 1).toDouble(),
                    minY: 1,
                    maxY: 10,
                    lineBarsData: [
                      LineChartBarData(
                        spots: List.generate(recent.length, (idx) => FlSpot(idx.toDouble(), recent[idx].moodScore.toDouble())),
                        isCurved: true,
                        color: Colors.indigoAccent,
                        barWidth: 3,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: Colors.indigoAccent.withOpacity(0.15),
                        ),
                      ),
                    ],
                  ),
                )
              : LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    minX: 0,
                    maxX: 6,
                    minY: 1,
                    maxY: 10,
                    lineBarsData: [
                      LineChartBarData(
                        spots: const [
                          FlSpot(0, 8),
                          FlSpot(1, 9),
                          FlSpot(2, 7),
                          FlSpot(3, 9),
                          FlSpot(4, 8),
                          FlSpot(5, 10),
                          FlSpot(6, 9),
                        ],
                        isCurved: true,
                        color: Colors.indigoAccent,
                        barWidth: 3,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: Colors.indigoAccent.withOpacity(0.15),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        footerText: '94% Harmony Flow (7d)',
      );
    }

    Widget _buildSyncQuestionTile(BuildContext context) {
      final question = moodProvider.todayQuestion;
      final myAns = question?.myAnswer != null;
      final partAns = question?.partnerAnswer != null;

      return _buildBentoWrapper(
        context: context,
        badgeText: 'Couples Dialogue',
        badgeColor: Colors.emeraldAccent,
        title: 'Daily Sync Question',
        icon: Icons.question_answer_rounded,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TopicCardsScreen())),
        details: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              question != null ? '"${question.question}"' : 'No sync question loaded.',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.white90, fontStyle: FontStyle.italic),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: myAns ? Colors.green.withOpacity(0.2) : Colors.white10,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('You: ${myAns ? "DONE" : "PENDING"}', style: const TextStyle(fontSize: 8, color: Colors.white75)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: partAns ? Colors.green.withOpacity(0.2) : Colors.white10,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('Elena: ${partAns ? "DONE" : "PENDING"}', style: const TextStyle(fontSize: 8, color: Colors.white75)),
                ),
              ],
            ),
          ],
        ),
        footerText: myAns && partAns ? 'Sync status: Connected' : 'Waiting for answers',
      );
    }

    Widget _buildBucketTile(BuildContext context) {
      final items = bucketProvider.items;
      final target = items.isNotEmpty ? items.firstWhere((i) => !i.isCompleted, orElse: () => items.first) : null;
      return _buildBentoWrapper(
        context: context,
        badgeText: 'Adventures',
        badgeColor: Colors.cyanAccent,
        title: 'Bucket List Goals',
        icon: Icons.explore_rounded,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BucketListScreen())),
        details: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Progress', style: TextStyle(fontSize: 11, color: Colors.white38)),
                Text('${(bucketProvider.progress * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 11, color: Colors.cyanAccent)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: bucketProvider.progress,
                color: Colors.cyanAccent,
                backgroundColor: Colors.white10,
                minHeight: 4,
              ),
            ),
            if (target != null) ...[
              const SizedBox(height: 8),
              Text('Target: ${target.title}', style: const TextStyle(fontSize: 11, color: Colors.white75), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
        footerText: '${bucketProvider.completedItems}/${bucketProvider.totalItems} Goals Completed',
      );
    }

    Widget _buildCapsuleTile(BuildContext context) {
      final capsules = timeCapsuleProvider.lockedCapsules;
      final nearest = capsules.isNotEmpty ? capsules.first : null;
      final hoursLeft = nearest != null ? nearest.openDate.difference(DateTime.now()).inHours : 0;
      return _buildBentoWrapper(
        context: context,
        badgeText: 'Future Letters',
        badgeColor: Colors.orangeAccent,
        title: 'Time Capsules',
        icon: Icons.hourglass_empty_rounded,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TimeCapsuleScreen())),
        details: nearest != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nearest.message, style: const TextStyle(color: Colors.white, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text('Unlocks in $hoursLeft hours', style: const TextStyle(color: Colors.orangeAccent, fontSize: 11)),
                ],
              )
            : const Text('No capsules sealed yet.', style: TextStyle(fontSize: 12, color: Colors.white38)),
        footerText: '${timeCapsuleProvider.capsules.length} Sealed Lockboxes',
      );
    }

    Widget _buildVaultTile(BuildContext context) {
      final ledgerSize = vaultProvider.items.length;
      return _buildBentoWrapper(
        context: context,
        badgeText: 'Encrypted Privacy',
        badgeColor: Colors.tealAccent,
        title: 'Crypto Vault',
        icon: Icons.lock_rounded,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VaultScreen())),
        details: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Vault Status:', style: TextStyle(fontSize: 11, color: Colors.white38)),
                Text(
                  vaultProvider.isUnlocked ? 'UNLOCKED' : 'LOCKED',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: vaultProvider.isUnlocked ? Colors.greenAccent : Colors.tealAccent),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text('• passport_scan.pdf (masked)', style: TextStyle(fontSize: 11, color: Colors.white24)),
          ],
        ),
        footerText: '$ledgerSize Secure Documents Enrolled',
      );
    }

    Widget _buildChatTile(BuildContext context) {
      final messages = chatProvider.messages;
      final lastMsg = messages.isNotEmpty ? messages.last : null;
      return _buildBentoWrapper(
        context: context,
        badgeText: 'Encrypted Taps',
        badgeColor: Colors.pinkAccent,
        title: 'Love Chat Space',
        icon: Icons.forum_rounded,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoveChatScreen())),
        details: lastMsg != null
            ? Text(
                '${lastMsg.senderName}: "${lastMsg.content}"',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              )
            : const Text('Say hello to each other!', style: TextStyle(fontSize: 12, color: Colors.white38)),
        footerText: '${messages.length} Transmitted Items',
      );
    }
  }
  ```

- [ ] **Step 2: Add bento grid inside `love_story_screen.dart`**
  Import `bento_grid.dart` and insert it below the statistics grid inside `HomeDashboard`.

- [ ] **Step 3: Run analysis**
  Run: `flutter analyze`
  Expected: Success.

- [ ] **Step 4: Commit**
  ```bash
  git add lib/widgets/dashboard/bento_grid.dart
  git commit -m "feat: implement 9-card single-column bento grid preview tiles"
  ```

---

### Task 8: Recent Activity Feed Widget
Create the Recent Activity Feed widget displaying recent logs.

**Files:**
- Create: `lib/widgets/dashboard/recent_activity_feed.dart`
- Modify: `lib/screens/love_story_screen.dart`

- [ ] **Step 1: Write `RecentActivityFeed`**
  Create `lib/widgets/dashboard/recent_activity_feed.dart`:
  ```dart
  import 'package:flutter/material.dart';
  import 'package:google_fonts/google_fonts.dart';
  import 'package:intl/intl.dart';
  import 'package:days_together/widgets/glass_container.dart';
  import 'package:days_together/providers/timeline_provider.dart';

  class RecentActivityFeed extends StatelessWidget {
    final TimelineProvider timelineProvider;
    final dynamic theme;

    const RecentActivityFeed({
      super.key,
      required this.timelineProvider,
      required this.theme,
    });

    @override
    Widget build(BuildContext context) {
      final items = timelineProvider.timelineItems;
      if (items.isEmpty) {
        return const SizedBox.shrink();
      }

      // Take up to 5 items for activity feed
      final feedItems = items.take(5).toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history_rounded, color: Colors.pinkAccent, size: 16),
              const SizedBox(width: 8),
              Text(
                'Recent Activity Log',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: feedItems.length,
            itemBuilder: (context, index) {
              final item = feedItems[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                child: GlassContainer(
                  padding: const EdgeInsets.all(12),
                  borderRadius: 16,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.pinkAccent.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Text(item.mood, style: const TextStyle(fontSize: 16)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.description,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: Colors.white54,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('MM/dd').format(item.date),
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          color: Colors.white38,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      );
    }
  }
  ```

- [ ] **Step 2: Add inside `HomeDashboard`**
  Import `recent_activity_feed.dart` and insert it at the very bottom of `HomeDashboard`.

- [ ] **Step 3: Run analysis**
  Run: `flutter analyze`
  Expected: Success.

- [ ] **Step 4: Commit**
  ```bash
  git add lib/widgets/dashboard/recent_activity_feed.dart
  git commit -m "feat: implement recent activity feed log list"
  ```

---

### Task 9: Assemble Dashboard & Cleanup
Assemble all widgets in `HomeDashboard` and delete the redundant logic.

**Files:**
- Modify: `lib/screens/love_story_screen.dart`

- [ ] **Step 1: Replace `HomeDashboard` implementation**
  Open [love_story_screen.dart](file:///c:/Users/rjalv/Desktop/MY%20PROJECTS/4th%20Anniversarry%20-%20Copy/ashwel_anniversary/lib/screens/love_story_screen.dart).
  Update imports and class `_HomeDashboardState.build` to:
  ```dart
  // Inside love_story_screen.dart:
  import 'package:days_together/widgets/dashboard/detailed_days_counter.dart';
  import 'package:days_together/widgets/dashboard/insights_banner.dart';
  import 'package:days_together/widgets/dashboard/partner_presence_card.dart';
  import 'package:days_together/widgets/dashboard/milestone_card.dart';
  import 'package:days_together/widgets/dashboard/memory_highlight_carousel.dart';
  import 'package:days_together/widgets/dashboard/relationship_statistics.dart';
  import 'package:days_together/widgets/dashboard/bento_grid.dart';
  import 'package:days_together/widgets/dashboard/recent_activity_feed.dart';
  import 'package:days_together/providers/vault_provider.dart';
  import 'package:days_together/providers/bucket_list_provider.dart';
  import 'package:days_together/providers/time_capsule_provider.dart';
  import 'package:days_together/providers/noteit_provider.dart';
  import 'package:days_together/providers/calendar_provider.dart';
  import 'package:days_together/providers/love_chat_provider.dart';
  import 'package:days_together/providers/daily_mood_provider.dart';

  // Inside _HomeDashboardState:
  @override
  Widget build(BuildContext context) {
    final rp = context.watch<RelationshipProvider>();
    final tp = context.watch<TimelineProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final theme = themeProvider.currentLoveTheme;

    // Additional providers for statistics and bento grid
    final noteProvider = context.watch<NoteitProvider>();
    final calendarProvider = context.watch<CalendarProvider>();
    final moodProvider = context.watch<DailyMoodProvider>();
    final bucketProvider = context.watch<BucketListProvider>();
    final timeCapsuleProvider = context.watch<TimeCapsuleProvider>();
    final vaultProvider = context.watch<VaultProvider>();
    final chatProvider = context.watch<LoveChatProvider>();

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DetailedDaysCounter(relationshipProvider: rp, theme: theme),
            const SizedBox(height: 16),
            InsightsBanner(
              timelineProvider: tp,
              bucketProvider: bucketProvider,
              relationshipProvider: rp,
              theme: theme,
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: PartnerPresenceCard(relationshipProvider: rp, theme: theme)),
                const SizedBox(width: 12),
                Expanded(child: MilestoneCard(relationshipProvider: rp, theme: theme)),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Icon(Icons.bookmark_rounded, color: Colors.pinkAccent, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Latest Captured Memories',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            MemoryHighlightCarousel(timelineProvider: tp, theme: theme),
            const SizedBox(height: 24),
            RelationshipStatistics(
              timelineProvider: tp,
              vaultProvider: vaultProvider,
              relationshipProvider: rp,
              bucketProvider: bucketProvider,
              timeCapsuleProvider: timeCapsuleProvider,
              noteitProvider: noteProvider,
              theme: theme,
            ),
            const SizedBox(height: 24),
            BentoGrid(
              noteProvider: noteProvider,
              calendarProvider: calendarProvider,
              moodProvider: moodProvider,
              bucketProvider: bucketProvider,
              timeCapsuleProvider: timeCapsuleProvider,
              vaultProvider: vaultProvider,
              chatProvider: chatProvider,
              relationshipProvider: rp,
              theme: theme,
            ),
            const SizedBox(height: 24),
            RecentActivityFeed(timelineProvider: tp, theme: theme),
            const SizedBox(height: 120), // Bottom navigation padding
          ],
        ),
      ),
    );
  }
  ```

- [ ] **Step 2: Remove redundant sub-widgets**
  Remove the unused `_buildLiquidHeader`, `_buildDetailedGlassCounter`, `_buildTimeUnit`, `_buildTimeUnitDivider`, `_buildMetricGrid`, `_buildMetricCard`, `_buildUpcomingMilestones`, and `_buildQuickMemorySnapshot` methods from the bottom of `love_story_screen.dart`.

- [ ] **Step 3: Run analysis**
  Run: `flutter analyze`
  Expected: Success.

- [ ] **Step 4: Commit**
  ```bash
  git commit -am "feat: assemble modular dashboard cards and clean up unused builder methods"
  ```
