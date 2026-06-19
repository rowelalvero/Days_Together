# Testing Patterns

**Analysis Date:** 2026-06-19

## Test Framework

**Runner:**
- Flutter Test (built-in Flutter unit test runner)
- Config: `pubspec.yaml` (specifies `flutter_test` dependency)

**Assertion Library:**
- `package:flutter_test/flutter_test.dart` matcher asserts (`expect`, `equals`, `isNull`, `isTrue`).

**Run Commands:**
```bash
flutter test                         # Run all tests
flutter test test/models_test.dart   # Run specific test file
flutter test --coverage              # Run tests and collect coverage report
```

## Test File Organization

**Location:**
- Located in the root `test/` folder, replicating structure parallel to `lib/` when needed.

**Naming:**
- Suffix `_test.dart` (e.g., `test/models_test.dart`).

**Structure:**
```text
test/
└── models_test.dart      # Focuses on unit verification of model serialization and DTOs
```

## Test Structure

**Suite Organization:**
Tests are grouped logically by classes and functionalities using standard nested `group` structures:
```dart
void main() {
  group('TimelineItemData', () {
    test('fromJson tolerates missing optional fields', () {
      // Setup & Assert
    });
    
    test('copyWith preserves untouched fields', () {
      // Setup & Assert
    });
  });
}
```

## Mocking

**Framework:**
- Mockito or Mocktail (though not currently declared in active `pubspec.yaml` dev dependencies). 
- State mocks are typically handled in-memory using static constructors or pure Dart mock classes.

## Fixtures and Factories

**Test Data:**
- Handled inline using custom model constructors.
- Example:
```dart
final original = TimelineItemData(
  id: 'x',
  title: 'T',
  description: 'D',
  date: DateTime(2024, 1, 1),
);
```

## Coverage

**Requirements:**
- None enforced currently.

---

*Testing analysis: 2026-06-19*
