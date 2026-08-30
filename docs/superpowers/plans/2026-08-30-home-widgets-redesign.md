# Home Screen Widgets Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the home screen widgets for *Days Together* with a single 2x2 NoteIt partner drawing widget, 2x2 & 4x2 Days Together relationship counters, an in-app Home Widget Studio with live editable preview and 1-tap launcher pinning, upgraded to `home_widget: ^0.9.3`.

**Architecture:** Feature-based modular architecture (`lib/features/home_widgets/`) adhering to ADR-001, ADR-008 (atomic presentation), ADR-009 (lightweight domain), and ADR-002 (Riverpod state). Uses `home_widget` offscreen Flutter widget rendering to generate pixel-perfect PNG cards for Android RemoteViews and iOS WidgetKit, coupled with contextual GoRouter deep-linking (`daystogether://noteit` and `daystogether://duration`).

**Tech Stack:** Flutter, Dart, `home_widget: ^0.9.3`, `flutter_riverpod: ^3.3.2`, `go_router: ^17.5.0`, Android Kotlin AppWidgets, iOS Swift WidgetKit.

**Spec:** `docs/superpowers/specs/2026-08-30-home-widgets-redesign.md`

## Global Constraints

- **Dependency floor:** `home_widget: ^0.9.3` in `pubspec.yaml`.
- **NoteIt Widget Size:** Dedicated single **2x2 (Small Square)** displaying partner's latest handwritten canvas drawing.
- **Days Together Widget Sizes:** **2x2 (Small)** and **4x2 (Medium)** romantic glassmorphic cards.
- **App Group identifier:** `group.com.szacheo.days_together` (iOS / Android shared preferences contract).
- **Deep link URI scheme:** `daystogether://noteit` (opens `/together/noteit`) and `daystogether://duration` (opens `/together`).
- **No Supabase imports in UI:** All UI strictly accesses repositories or providers (Architecture Rule 1).
- **Riverpod state management:** Studio state managed via Riverpod `NotifierProvider` (Architecture Rule 3).

---

### Task 1: Upgrade `home_widget` & Implement Domain Entities

**Files:**
- Modify: `pubspec.yaml:49`
- Create: `lib/features/home_widgets/domain/home_widget_models.dart`
- Create: `lib/features/home_widgets/domain/home_widget_constants.dart`
- Test: `test/features/home_widgets/domain/home_widget_models_test.dart`

**Interfaces:**
- Consumes: `ThemeType` from `lib/models/app_settings.dart`
- Produces: `HomeWidgetType`, `DaysCounterFormat`, `HomeWidgetConfig`, and `HomeWidgetConstants`

- [ ] **Step 1: Write the failing domain test**

```dart
// test/features/home_widgets/domain/home_widget_models_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:days_together/models/app_settings.dart';
import 'package:days_together/features/home_widgets/domain/home_widget_models.dart';
import 'package:days_together/features/home_widgets/domain/home_widget_constants.dart';

void main() {
  group('HomeWidgetConfig', () {
    test('default configuration has correct initial values', () {
      const config = HomeWidgetConfig();
      expect(config.themeType, ThemeType.midnightRose);
      expect(config.counterFormat, DaysCounterFormat.totalDays);
      expect(config.customTitle, 'Days Together');
      expect(config.customMilestoneTag, '4th Anniversary');
      expect(config.showSeconds, isTrue);
      expect(config.showMilestone, isTrue);
      expect(config.selectedDrawingId, isNull);
    });

    test('copyWith updates selected fields correctly', () {
      const config = HomeWidgetConfig();
      final updated = config.copyWith(
        themeType: ThemeType.roseQuartz,
        customTitle: 'Ash & Wel',
        counterFormat: DaysCounterFormat.yearsMonthsDays,
      );
      expect(updated.themeType, ThemeType.roseQuartz);
      expect(updated.customTitle, 'Ash & Wel');
      expect(updated.counterFormat, DaysCounterFormat.yearsMonthsDays);
      expect(updated.customMilestoneTag, '4th Anniversary');
    });

    test('toJson and fromJson preserves data integrity', () {
      const config = HomeWidgetConfig(
        themeType: ThemeType.neonViolet,
        counterFormat: DaysCounterFormat.compact,
        customTitle: 'Together in Love',
        customMilestoneTag: 'Year 5',
        selectedDrawingId: 'note_123',
        showSeconds: false,
        showMilestone: false,
      );
      final json = config.toJson();
      final deserialized = HomeWidgetConfig.fromJson(json);
      expect(deserialized.themeType, ThemeType.neonViolet);
      expect(deserialized.counterFormat, DaysCounterFormat.compact);
      expect(deserialized.customTitle, 'Together in Love');
      expect(deserialized.customMilestoneTag, 'Year 5');
      expect(deserialized.selectedDrawingId, 'note_123');
      expect(deserialized.showSeconds, isFalse);
      expect(deserialized.showMilestone, isFalse);
    });
  });

  group('HomeWidgetConstants', () {
    test('constants are properly defined', () {
      expect(HomeWidgetConstants.appGroupId, 'group.com.szacheo.days_together');
      expect(HomeWidgetConstants.noteitDeepLink, 'daystogether://noteit');
      expect(HomeWidgetConstants.durationDeepLink, 'daystogether://duration');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/home_widgets/domain/home_widget_models_test.dart`
Expected: FAIL with compilation errors (unresolved files and classes)

- [ ] **Step 3: Update `pubspec.yaml` and implement domain models**

In `pubspec.yaml`:
```yaml
  home_widget: ^0.9.3
```

In `lib/features/home_widgets/domain/home_widget_constants.dart`:
```dart
class HomeWidgetConstants {
  static const String appGroupId = 'group.com.szacheo.days_together';
  static const String androidNoteitWidgetName = 'NoteitWidgetProvider';
  static const String androidDaysTogetherWidgetName = 'DaysTogetherWidgetProvider';
  static const String iOSNoteitWidgetName = 'NoteitWidget';
  static const String iOSDaysTogetherWidgetName = 'DaysTogetherWidget';

  static const String keyNoteitRenderPath = 'noteit_render_path';
  static const String keyDaysTogetherRenderPath = 'days_together_render_path';
  static const String keyStartTimestamp = 'start_timestamp';
  static const String keyDurationText = 'duration_text';
  static const String keyWidgetConfigJson = 'widget_config_json';

  static const String noteitDeepLink = 'daystogether://noteit';
  static const String durationDeepLink = 'daystogether://duration';
}
```

In `lib/features/home_widgets/domain/home_widget_models.dart`:
```dart
import 'package:days_together/models/app_settings.dart';

enum HomeWidgetType {
  noteit2x2,
  daysTogether2x2,
  daysTogether4x2,
}

enum DaysCounterFormat {
  totalDays,
  yearsMonthsDays,
  compact,
}

class HomeWidgetConfig {
  final ThemeType themeType;
  final DaysCounterFormat counterFormat;
  final String customTitle;
  final String customMilestoneTag;
  final String? selectedDrawingId;
  final bool showSeconds;
  final bool showMilestone;

  const HomeWidgetConfig({
    this.themeType = ThemeType.midnightRose,
    this.counterFormat = DaysCounterFormat.totalDays,
    this.customTitle = 'Days Together',
    this.customMilestoneTag = '4th Anniversary',
    this.selectedDrawingId,
    this.showSeconds = true,
    this.showMilestone = true,
  });

  HomeWidgetConfig copyWith({
    ThemeType? themeType,
    DaysCounterFormat? counterFormat,
    String? customTitle,
    String? customMilestoneTag,
    String? selectedDrawingId,
    bool? showSeconds,
    bool? showMilestone,
  }) {
    return HomeWidgetConfig(
      themeType: themeType ?? this.themeType,
      counterFormat: counterFormat ?? this.counterFormat,
      customTitle: customTitle ?? this.customTitle,
      customMilestoneTag: customMilestoneTag ?? this.customMilestoneTag,
      selectedDrawingId: selectedDrawingId ?? this.selectedDrawingId,
      showSeconds: showSeconds ?? this.showSeconds,
      showMilestone: showMilestone ?? this.showMilestone,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'themeType': themeType.name,
      'counterFormat': counterFormat.name,
      'customTitle': customTitle,
      'customMilestoneTag': customMilestoneTag,
      'selectedDrawingId': selectedDrawingId,
      'showSeconds': showSeconds,
      'showMilestone': showMilestone,
    };
  }

  factory HomeWidgetConfig.fromJson(Map<String, dynamic> json) {
    ThemeType resolvedTheme = ThemeType.midnightRose;
    if (json['themeType'] != null) {
      resolvedTheme = ThemeType.values.firstWhere(
        (e) => e.name == json['themeType'],
        orElse: () => ThemeType.midnightRose,
      );
    }

    DaysCounterFormat resolvedFormat = DaysCounterFormat.totalDays;
    if (json['counterFormat'] != null) {
      resolvedFormat = DaysCounterFormat.values.firstWhere(
        (e) => e.name == json['counterFormat'],
        orElse: () => DaysCounterFormat.totalDays,
      );
    }

    return HomeWidgetConfig(
      themeType: resolvedTheme,
      counterFormat: resolvedFormat,
      customTitle: json['customTitle'] as String? ?? 'Days Together',
      customMilestoneTag: json['customMilestoneTag'] as String? ?? '4th Anniversary',
      selectedDrawingId: json['selectedDrawingId'] as String?,
      showSeconds: json['showSeconds'] as bool? ?? true,
      showMilestone: json['showMilestone'] as bool? ?? true,
    );
  }
}
```

- [ ] **Step 4: Run flutter pub get and tests to verify pass**

Run: `flutter pub get; flutter test test/features/home_widgets/domain/home_widget_models_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/features/home_widgets/domain/ test/features/home_widgets/domain/
git commit -m "feat(home_widgets): upgrade home_widget to 0.9.3 and add domain models"
```

---

### Task 2: Repository Layer for Widget Configuration Persistence

**Files:**
- Create: `lib/features/home_widgets/data/home_widget_repository.dart`
- Test: `test/features/home_widgets/data/home_widget_repository_test.dart`

**Interfaces:**
- Consumes: `HomeWidgetConfig`, `HomeWidgetConstants`
- Produces: `HomeWidgetRepository`, `homeWidgetRepositoryProvider`

- [ ] **Step 1: Write the failing repository test**

```dart
// test/features/home_widgets/data/home_widget_repository_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:days_together/models/app_settings.dart';
import 'package:days_together/features/home_widgets/domain/home_widget_models.dart';
import 'package:days_together/features/home_widgets/data/home_widget_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late HomeWidgetRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repository = HomeWidgetRepository(prefs);
  });

  test('loadConfig returns default config when nothing is stored', () {
    final config = repository.loadConfig();
    expect(config.themeType, ThemeType.midnightRose);
    expect(config.customTitle, 'Days Together');
  });

  test('saveConfig persists config and loadConfig retrieves it', () async {
    const newConfig = HomeWidgetConfig(
      themeType: ThemeType.pink,
      customTitle: 'Ash & Wel Forever',
      counterFormat: DaysCounterFormat.yearsMonthsDays,
    );
    await repository.saveConfig(newConfig);

    final loaded = repository.loadConfig();
    expect(loaded.themeType, ThemeType.pink);
    expect(loaded.customTitle, 'Ash & Wel Forever');
    expect(loaded.counterFormat, DaysCounterFormat.yearsMonthsDays);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/home_widgets/data/home_widget_repository_test.dart`
Expected: FAIL with "HomeWidgetRepository not found"

- [ ] **Step 3: Implement HomeWidgetRepository**

In `lib/features/home_widgets/data/home_widget_repository.dart`:
```dart
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:days_together/features/home_widgets/domain/home_widget_constants.dart';
import 'package:days_together/features/home_widgets/domain/home_widget_models.dart';

final homeWidgetRepositoryProvider = Provider<HomeWidgetRepository>((ref) {
  throw UnimplementedError('homeWidgetRepositoryProvider must be initialized with SharedPreferences');
});

class HomeWidgetRepository {
  final SharedPreferences _prefs;

  HomeWidgetRepository(this._prefs);

  HomeWidgetConfig loadConfig() {
    final raw = _prefs.getString(HomeWidgetConstants.keyWidgetConfigJson);
    if (raw == null || raw.isEmpty) {
      return const HomeWidgetConfig();
    }
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return HomeWidgetConfig.fromJson(decoded);
    } catch (_) {
      return const HomeWidgetConfig();
    }
  }

  Future<void> saveConfig(HomeWidgetConfig config) async {
    final encoded = jsonEncode(config.toJson());
    await _prefs.setString(HomeWidgetConstants.keyWidgetConfigJson, encoded);
  }
}
```

- [ ] **Step 4: Run tests to verify pass**

Run: `flutter test test/features/home_widgets/data/home_widget_repository_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/home_widgets/data/ test/features/home_widgets/data/
git commit -m "feat(home_widgets): implement HomeWidgetRepository and persistence"
```

---

### Task 3: Offscreen Render Cards & Atomic Templates

**Files:**
- Create: `lib/features/home_widgets/presentation/components/organisms/render_templates/noteit_2x2_render_card.dart`
- Create: `lib/features/home_widgets/presentation/components/organisms/render_templates/days_together_2x2_render_card.dart`
- Create: `lib/features/home_widgets/presentation/components/organisms/render_templates/days_together_4x2_render_card.dart`
- Test: `test/features/home_widgets/presentation/components/render_templates_test.dart`

**Interfaces:**
- Consumes: `HomeWidgetConfig`, `LoveStoryTheme`, `ThemeManager`, `ScaleDrawingPainter` / strokes
- Produces: Isolated, high-res render widgets for `HomeWidget.renderFlutterWidget`

- [ ] **Step 1: Write test for offscreen render widgets**

```dart
// test/features/home_widgets/presentation/components/render_templates_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:days_together/themes/theme_manager.dart';
import 'package:days_together/models/app_settings.dart';
import 'package:days_together/features/home_widgets/domain/home_widget_models.dart';
import 'package:days_together/features/home_widgets/presentation/components/organisms/render_templates/noteit_2x2_render_card.dart';
import 'package:days_together/features/home_widgets/presentation/components/organisms/render_templates/days_together_2x2_render_card.dart';
import 'package:days_together/features/home_widgets/presentation/components/organisms/render_templates/days_together_4x2_render_card.dart';

void main() {
  final theme = ThemeManager.getTheme(ThemeType.midnightRose);

  testWidgets('Noteit2x2RenderCard renders empty state and drawing state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Noteit2x2RenderCard(
            theme: theme,
            partnerName: 'Ashley',
            drawingContent: null,
          ),
        ),
      ),
    );
    expect(find.text('Ashley'), findsOneWidget);
    expect(find.text('Tap to draw first 💕'), findsOneWidget);
  });

  testWidgets('DaysTogether2x2RenderCard renders days count and title', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DaysTogether2x2RenderCard(
            theme: theme,
            config: const HomeWidgetConfig(customTitle: 'Our Story'),
            durationText: '1,468 Days',
            milestoneText: '4th Anniversary',
          ),
        ),
      ),
    );
    expect(find.text('Our Story'), findsOneWidget);
    expect(find.text('1,468 Days'), findsOneWidget);
    expect(find.text('4th Anniversary'), findsOneWidget);
  });

  testWidgets('DaysTogether4x2RenderCard renders couple details and time', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DaysTogether4x2RenderCard(
            theme: theme,
            config: const HomeWidgetConfig(customTitle: 'Ash & Wel'),
            daysCount: '1,468',
            timeText: '07:23:41',
            milestoneText: '4th Anniversary in 14d',
            partner1Name: 'Ashley',
            partner2Name: 'Rowel',
          ),
        ),
      ),
    );
    expect(find.text('Ash & Wel'), findsOneWidget);
    expect(find.text('1,468'), findsOneWidget);
    expect(find.text('07:23:41'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/home_widgets/presentation/components/render_templates_test.dart`
Expected: FAIL (templates not created yet)

- [ ] **Step 3: Implement render template cards**

Implement `Noteit2x2RenderCard`:
```dart
// lib/features/home_widgets/presentation/components/organisms/render_templates/noteit_2x2_render_card.dart
import 'package:flutter/material.dart';
import 'package:days_together/themes/theme_manager.dart';
import 'package:days_together/shared/scale_drawing_painter.dart';

class Noteit2x2RenderCard extends StatelessWidget {
  final LoveStoryTheme theme;
  final String partnerName;
  final String? drawingContent;
  final String? timeAgo;

  const Noteit2x2RenderCard({
    super.key,
    required this.theme,
    required this.partnerName,
    this.drawingContent,
    this.timeAgo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      height: 320,
      decoration: BoxDecoration(
        color: theme.backgroundColor,
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: theme.accentColor.withValues(alpha: 0.35), width: 2.5),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.primaryColor.withValues(alpha: 0.85),
            theme.secondaryColor.withValues(alpha: 0.95),
            theme.backgroundColor,
          ],
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.accentColor.withValues(alpha: 0.25),
                  border: Border.all(color: theme.accentColor, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    partnerName.isNotEmpty ? partnerName[0].toUpperCase() : '💖',
                    style: TextStyle(
                      color: theme.textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  partnerName,
                  style: TextStyle(
                    color: theme.textColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (timeAgo != null)
                Text(
                  timeAgo!,
                  style: TextStyle(
                    color: theme.textColor.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              clipBehavior: Clip.antiAlias,
              child: drawingContent != null && drawingContent!.isNotEmpty
                  ? CustomPaint(
                      painter: ScaleDrawingPainter.fromString(drawingContent!),
                      size: Size.infinite,
                    )
                  : Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit_note_rounded, color: theme.accentColor, size: 36),
                          const SizedBox(height: 6),
                          Text(
                            'Tap to draw first 💕',
                            style: TextStyle(
                              color: theme.textColor.withValues(alpha: 0.7),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
```

Implement `DaysTogether2x2RenderCard`:
```dart
// lib/features/home_widgets/presentation/components/organisms/render_templates/days_together_2x2_render_card.dart
import 'package:flutter/material.dart';
import 'package:days_together/themes/theme_manager.dart';
import 'package:days_together/features/home_widgets/domain/home_widget_models.dart';

class DaysTogether2x2RenderCard extends StatelessWidget {
  final LoveStoryTheme theme;
  final HomeWidgetConfig config;
  final String durationText;
  final String? milestoneText;

  const DaysTogether2x2RenderCard({
    super.key,
    required this.theme,
    required this.config,
    required this.durationText,
    this.milestoneText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      height: 320,
      decoration: BoxDecoration(
        color: theme.backgroundColor,
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: theme.accentColor.withValues(alpha: 0.35), width: 2.5),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.primaryColor.withValues(alpha: 0.85),
            theme.secondaryColor.withValues(alpha: 0.95),
            theme.backgroundColor,
          ],
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                config.customTitle,
                style: TextStyle(
                  color: theme.accentColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  letterSpacing: 0.5,
                ),
              ),
              Icon(Icons.favorite_rounded, color: theme.accentColor, size: 20),
            ],
          ),
          Center(
            child: Column(
              children: [
                Text(
                  durationText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.textColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 28,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
          if (config.showMilestone && milestoneText != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: theme.accentColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.accentColor.withValues(alpha: 0.3)),
              ),
              child: Center(
                child: Text(
                  milestoneText!,
                  style: TextStyle(
                    color: theme.textColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }
}
```

Implement `DaysTogether4x2RenderCard`:
```dart
// lib/features/home_widgets/presentation/components/organisms/render_templates/days_together_4x2_render_card.dart
import 'package:flutter/material.dart';
import 'package:days_together/themes/theme_manager.dart';
import 'package:days_together/features/home_widgets/domain/home_widget_models.dart';

class DaysTogether4x2RenderCard extends StatelessWidget {
  final LoveStoryTheme theme;
  final HomeWidgetConfig config;
  final String daysCount;
  final String timeText;
  final String? milestoneText;
  final String partner1Name;
  final String partner2Name;

  const DaysTogether4x2RenderCard({
    super.key,
    required this.theme,
    required this.config,
    required this.daysCount,
    required this.timeText,
    this.milestoneText,
    required this.partner1Name,
    required this.partner2Name,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 640,
      height: 320,
      decoration: BoxDecoration(
        color: theme.backgroundColor,
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: theme.accentColor.withValues(alpha: 0.35), width: 2.5),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.primaryColor.withValues(alpha: 0.85),
            theme.secondaryColor.withValues(alpha: 0.95),
            theme.backgroundColor,
          ],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
      child: Row(
        children: [
          // Left column: Avatars and names
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    _AvatarCircle(name: partner1Name, theme: theme),
                    Transform.translate(
                      offset: const Offset(-8, 0),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.primaryColor,
                        ),
                        child: Icon(Icons.favorite_rounded, color: theme.accentColor, size: 16),
                      ),
                    ),
                    Transform.translate(
                      offset: const Offset(-16, 0),
                      child: _AvatarCircle(name: partner2Name, theme: theme),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  config.customTitle,
                  style: TextStyle(
                    color: theme.textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                if (milestoneText != null && config.showMilestone)
                  Text(
                    milestoneText!,
                    style: TextStyle(
                      color: theme.accentColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          ),
          Container(width: 1.5, height: 180, color: Colors.white.withValues(alpha: 0.15)),
          const SizedBox(width: 24),
          // Right column: Big days and timer
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      daysCount,
                      style: TextStyle(
                        color: theme.textColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 38,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'DAYS',
                      style: TextStyle(
                        color: theme.accentColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                if (config.showSeconds) ...[
                  const SizedBox(height: 6),
                  Text(
                    timeText,
                    style: TextStyle(
                      color: theme.textColor.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  final String name;
  final LoveStoryTheme theme;

  const _AvatarCircle({required this.name, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.secondaryColor,
        border: Border.all(color: theme.accentColor, width: 2),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '💖',
          style: TextStyle(
            color: theme.textColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify pass**

Run: `flutter test test/features/home_widgets/presentation/components/render_templates_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/home_widgets/presentation/components/organisms/render_templates/ test/features/home_widgets/presentation/components/
git commit -m "feat(home_widgets): implement isolated offscreen render templates for 2x2 and 4x2 widgets"
```

---

### Task 4: Platform Service Engine (`HomeWidgetService`)

**Files:**
- Modify: `lib/services/home_widget_service.dart`
- Test: `test/services/home_widget_service_test.dart`

**Interfaces:**
- Consumes: `home_widget: ^0.9.3`, `HomeWidgetConfig`, `HomeWidgetConstants`, `Noteit2x2RenderCard`, `DaysTogether2x2RenderCard`, `DaysTogether4x2RenderCard`
- Produces: `HomeWidgetService.instance.renderAndSyncNoteit(...)`, `renderAndSyncDaysTogether(...)`, `requestPin(...)`

- [ ] **Step 1: Write test for HomeWidgetService**

```dart
// test/services/home_widget_service_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:days_together/services/home_widget_service.dart';
import 'package:days_together/features/home_widgets/domain/home_widget_models.dart';

void main() {
  test('formatDuration handles null, past, and format modes', () {
    final start = DateTime(2022, 6, 1, 12, 0);
    final now = DateTime(2026, 6, 1, 14, 30, 15);

    final standard = HomeWidgetService.formatDuration(
      start,
      now: now,
      format: DaysCounterFormat.totalDays,
    );
    expect(standard, contains('1461 Days'));

    final ymd = HomeWidgetService.formatDuration(
      start,
      now: now,
      format: DaysCounterFormat.yearsMonthsDays,
    );
    expect(ymd, contains('4 Yrs'));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/services/home_widget_service_test.dart`
Expected: FAIL with missing parameters/methods

- [ ] **Step 3: Update `HomeWidgetService` implementation**

Update `lib/services/home_widget_service.dart` to support rendering NoteIt and Days Together widgets offscreen via `HomeWidget.renderFlutterWidget()`, saving to App Group storage, triggering platform updates, and one-tap pinning via `HomeWidget.requestPinWidget()`.

- [ ] **Step 4: Run tests to verify pass**

Run: `flutter test test/services/home_widget_service_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/services/home_widget_service.dart test/services/home_widget_service_test.dart
git commit -m "feat(home_widgets): update HomeWidgetService with 0.9.3 render and sync APIs"
```

---

### Task 5: Native Android AppWidget Setup (NoteIt 2x2 & Days Together)

**Files:**
- Create: `android/app/src/main/kotlin/com/szacheo/days_together/NoteitWidgetProvider.kt`
- Create: `android/app/src/main/res/layout/noteit_widget.xml`
- Create: `android/app/src/main/res/xml/noteit_widget_info.xml`
- Modify: `android/app/src/main/res/layout/days_together_widget.xml`
- Modify: `android/app/src/main/res/xml/days_together_widget_info.xml`
- Modify: `android/app/src/main/kotlin/com/szacheo/days_together/DaysTogetherWidgetProvider.kt`
- Modify: `android/app/src/main/AndroidManifest.xml`

**Interfaces:**
- Consumes: Rendered bitmap image paths from SharedPreferences/App Group
- Produces: Native Android 2x2 NoteIt AppWidget and 2x2/4x2 Days Together AppWidgets with deep links

- [ ] **Step 1: Create NoteIt layout and XML configs**

`android/app/src/main/res/layout/noteit_widget.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<FrameLayout xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/noteit_widget_root"
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    android:background="@android:color/transparent">

    <ImageView
        android:id="@+id/widget_image"
        android:layout_width="match_parent"
        android:layout_height="match_parent"
        android:scaleType="fitCenter"
        android:adjustViewBounds="true"
        android:contentDescription="Partner NoteIt Drawing" />
</FrameLayout>
```

`android/app/src/main/res/xml/noteit_widget_info.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"
    android:minWidth="140dp"
    android:minHeight="140dp"
    android:targetCellWidth="2"
    android:targetCellHeight="2"
    android:updatePeriodMillis="1800000"
    android:initialLayout="@layout/noteit_widget"
    android:resizeMode="none"
    android:widgetCategory="home_screen" />
```

- [ ] **Step 2: Implement NoteitWidgetProvider.kt**

`android/app/src/main/kotlin/com/szacheo/days_together/NoteitWidgetProvider.kt`:
```kotlin
package com.szacheo.days_together

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import java.io.File

class NoteitWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.noteit_widget).apply {
                val imagePath = widgetData.getString("noteit_render_path", null)
                if (!imagePath.isNullOrEmpty() && File(imagePath).exists()) {
                    val bitmap = BitmapFactory.decodeFile(imagePath)
                    setImageViewBitmap(R.id.widget_image, bitmap)
                }

                // Deep-link click intent to NoteIt canvas
                val intent = Intent(Intent.ACTION_VIEW, Uri.parse("daystogether://noteit")).apply {
                    `package` = context.packageName
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val pendingIntent = PendingIntent.getActivity(
                    context,
                    widgetId,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                setOnClickPendingIntent(R.id.noteit_widget_root, pendingIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
```

- [ ] **Step 3: Update DaysTogetherWidgetProvider.kt and AndroidManifest.xml**

Update `DaysTogetherWidgetProvider.kt` to load rendered card image bitmap from `days_together_render_path` with fallback text and set deep link `daystogether://duration`.
Register `NoteitWidgetProvider` in `AndroidManifest.xml`.

- [ ] **Step 4: Commit**

```bash
git add android/app/src/main/
git commit -m "feat(android): add NoteitWidgetProvider and update DaysTogetherWidgetProvider with high-res bitmap and deep linking"
```

---

### Task 6: Native iOS WidgetKit Setup (NoteIt 2x2 & Days Together)

**Files:**
- Modify: `ios/Runner/DaysTogetherWidget.swift`
- Create: `ios/Runner/NoteitWidget.swift`

**Interfaces:**
- Consumes: Shared App Group `group.com.szacheo.days_together` image files
- Produces: iOS WidgetKit extensions for NoteIt and Days Together with WidgetURL

- [ ] **Step 1: Implement NoteitWidget.swift**

`ios/Runner/NoteitWidget.swift`:
```swift
import WidgetKit
import SwiftUI

struct NoteitProvider: TimelineProvider {
    func placeholder(in context: Context) -> NoteitEntry {
        NoteitEntry(date: Date(), imagePath: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (NoteitEntry) -> ()) {
        let entry = createEntry(for: Date())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NoteitEntry>) -> ()) {
        let currentDate = Date()
        let entry = createEntry(for: currentDate)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: currentDate) ?? currentDate.addingTimeInterval(1800)
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func createEntry(for date: Date) -> NoteitEntry {
        let userDefaults = UserDefaults(suiteName: "group.com.szacheo.days_together")
        let path = userDefaults?.string(forKey: "noteit_render_path")
        return NoteitEntry(date: date, imagePath: path)
    }
}

struct NoteitEntry: TimelineEntry {
    let date: Date
    let imagePath: String?
}

struct NoteitWidgetEntryView : View {
    var entry: NoteitProvider.Entry

    var body: some View {
        Group {
            if let path = entry.imagePath, let uiImage = UIImage(contentsOfFile: path) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                VStack {
                    Text("NoteIt")
                        .font(.headline)
                        .foregroundColor(.pink)
                    Text("Tap to draw note")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .widgetURL(URL(string: "daystogether://noteit"))
    }
}

struct NoteitWidget: Widget {
    let kind: String = "NoteitWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NoteitProvider()) { entry in
            NoteitWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("NoteIt Partner Drawing")
        .description("Displays your partner's latest live drawing note.")
        .supportedFamilies([.systemSmall])
    }
}
```

- [ ] **Step 2: Update DaysTogetherWidget.swift with WidgetBundle**

Add `@main struct DaysTogetherWidgetBundle: WidgetBundle` bundling both `DaysTogetherWidget` and `NoteitWidget`.

- [ ] **Step 3: Commit**

```bash
git add ios/Runner/
git commit -m "feat(ios): configure WidgetKit bundle with NoteitWidget and DaysTogetherWidget"
```

---

### Task 7: In-App Home Widget Studio Screen & Atomic Components

**Files:**
- Create: `lib/features/home_widgets/presentation/components/atoms/widget_theme_chip.dart`
- Create: `lib/features/home_widgets/presentation/components/atoms/widget_pin_button.dart`
- Create: `lib/features/home_widgets/presentation/components/atoms/widget_size_badge.dart`
- Create: `lib/features/home_widgets/presentation/components/molecules/widget_device_frame.dart`
- Create: `lib/features/home_widgets/presentation/components/molecules/widget_content_editor.dart`
- Create: `lib/features/home_widgets/presentation/components/molecules/widget_theme_picker.dart`
- Create: `lib/features/home_widgets/presentation/components/organisms/widget_live_preview_card.dart`
- Create: `lib/features/home_widgets/presentation/controllers/home_widget_studio_controller.dart`
- Create: `lib/features/home_widgets/presentation/screens/home_widget_studio_screen.dart`
- Modify: `lib/routing/routes.dart` & `lib/routing/app_router.dart`
- Modify: `lib/screens/settings_tab.dart` (add "Home Screen Widgets" menu item)
- Test: `test/features/home_widgets/presentation/screens/home_widget_studio_screen_test.dart`

**Interfaces:**
- Consumes: `HomeWidgetConfig`, `HomeWidgetRepository`, `HomeWidgetService`, `CoupleSession`
- Produces: `HomeWidgetStudioScreen`, `homeWidgetStudioControllerProvider`

- [ ] **Step 1: Write widget test for HomeWidgetStudioScreen**

```dart
// test/features/home_widgets/presentation/screens/home_widget_studio_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:days_together/features/home_widgets/data/home_widget_repository.dart';
import 'package:days_together/features/home_widgets/presentation/screens/home_widget_studio_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('HomeWidgetStudioScreen renders live preview, theme picker, and pin button', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeWidgetRepositoryProvider.overrideWithValue(HomeWidgetRepository(prefs)),
        ],
        child: const MaterialApp(
          home: HomeWidgetStudioScreen(),
        ),
      ),
    );

    expect(find.text('Home Screen Widgets'), findsOneWidget);
    expect(find.text('NoteIt (2x2)'), findsOneWidget);
    expect(find.text('Days Counter'), findsOneWidget);
    expect(find.text('Add to Home Screen'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/home_widgets/presentation/screens/home_widget_studio_screen_test.dart`
Expected: FAIL (components not created)

- [ ] **Step 3: Implement atomic components, controller, and screen**

Implement `home_widget_studio_controller.dart`, atomic components (`widget_theme_chip.dart`, `widget_pin_button.dart`, `widget_size_badge.dart`, `widget_device_frame.dart`, `widget_content_editor.dart`, `widget_theme_picker.dart`, `widget_live_preview_card.dart`), and `home_widget_studio_screen.dart`.
Register `/settings/widgets` in `lib/routing/routes.dart` and `lib/routing/app_router.dart`.
Add entry tile in `lib/screens/settings_tab.dart` (or Studio tab).

- [ ] **Step 4: Run test to verify pass**

Run: `flutter test test/features/home_widgets/presentation/screens/home_widget_studio_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/features/home_widgets/presentation/ lib/routing/ lib/screens/settings_tab.dart test/features/home_widgets/presentation/
git commit -m "feat(home_widgets): implement HomeWidgetStudioScreen with live editable preview and atomic components"
```

---

### Task 8: Deep Link Navigation & End-to-End Verification

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/services/noteit_sync_manager.dart` (trigger automatic widget update on note sent/received)
- Test: `test/architecture_test.dart` (or full test suite)

**Interfaces:**
- Consumes: `HomeWidget.initiallyLaunchedFromHomeWidget()`, `HomeWidget.widgetClicked`
- Produces: Direct GoRouter navigation on widget tap

- [ ] **Step 1: Connect deep linking in `main.dart`**

In `main.dart`:
```dart
// Check initial launch from widget
HomeWidget.initiallyLaunchedFromHomeWidget().then((uri) {
  if (uri != null) {
    _handleWidgetDeepLink(uri);
  }
});

// Listen to widget clicks during runtime
HomeWidget.widgetClicked.listen((uri) {
  if (uri != null) {
    _handleWidgetDeepLink(uri);
  }
});

void _handleWidgetDeepLink(Uri uri) {
  if (uri.scheme == 'daystogether') {
    if (uri.host == 'noteit') {
      appRouter.go(AppRoutes.noteit);
    } else if (uri.host == 'duration') {
      appRouter.go(AppRoutes.together);
    }
  }
}
```

- [ ] **Step 2: Trigger widget re-render on NoteIt sync and couple session update**

In `lib/services/noteit_sync_manager.dart`:
Whenever a new drawing note is synced or sent, invoke `HomeWidgetService.instance.renderAndSyncNoteit(...)` in the background.

- [ ] **Step 3: Run all unit and widget tests**

Run: `flutter test`
Expected: All tests PASS

- [ ] **Step 4: Commit**

```bash
git add lib/main.dart lib/services/noteit_sync_manager.dart
git commit -m "feat(home_widgets): connect deep linking and automated background sync"
```
