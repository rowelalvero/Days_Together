# Coding Conventions

**Analysis Date:** 2026-06-19

## Naming Patterns

**Files:**
- lowercase snake_case (e.g., `bucket_list_provider.dart`, `timeline_item.dart`).

**Classes:**
- PascalCase (e.g., `RelationshipProvider`, `TimelineItemData`, `LoveStoryScreen`).

**Methods & Functions:**
- camelCase (e.g., `loadTimelineItems()`, `copyWith()`, `_initFirebaseSync()`).
- Private methods are prefixed with an underscore (e.g., `_syncLicenseField()`).

**Variables:**
- camelCase (e.g., `coupleId`, `yourName`, `isFirebaseAvailable`).
- Private variables are prefixed with an underscore (e.g., `_timelineKey`, `_userSub`).

## Code Style

**Formatting:**
- Uses the standard Dart formatter (`dart format`).
- 2-space indentation.
- Aggressive use of `const` constructors for stateless widgets and constant widgets to optimize rendering.

**Linting:**
- Configured in `analysis_options.yaml` via standard lint packages (`package:flutter_lints`).

**Immutability:**
- Models use `final` property definitions. 
- Immutability is preserved using `copyWith` methods to return modified clones of original models.

## Import Organization

**Order:**
1. Core Dart packages (e.g., `import 'dart:convert';`).
2. Flutter framework packages (e.g., `import 'package:flutter/material.dart';`).
3. External dependencies (e.g., `import 'package:provider/provider.dart';`).
4. Internal project files (e.g., `import 'package:days_together/models/timeline_model.dart';`).

**Path Aliases:**
- Standard package paths used instead of relative paths (e.g. `package:days_together/screens/...`).

## Error Handling

**Patterns:**
- Asynchronous database transactions and network integrations are enclosed in try/catch blocks.
- Caught errors must be printed to the development console using `debugPrint` (preferred) or `print`, along with appropriate context details.
- Crucial transactional errors notify users through dialog boxes or toast messages.

## Logging

**Framework:**
- Flutter native `debugPrint` is used as the primary debugging output.
- Print statements are commonly prefix-labeled (e.g., `debugPrint('Supabase joinWithCode failed: $e');`).

## Comments

**When to Comment:**
- Business logic workarounds and configuration instructions.
- Section tags (e.g. `// Firebase Streams Subscriptions`).

---

*Convention analysis: 2026-06-19*
