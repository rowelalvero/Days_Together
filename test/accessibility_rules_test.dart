// Accessibility rules, enforced as a ratchet in the style of
// architecture_test.dart: each rule is added only once lib/ satisfies it, so
// it guards against regression rather than describing an aspiration.
//
// Rule A1 -- every IconButton has a tooltip. An IconButton's tooltip is also
// its screen-reader label; without one TalkBack/VoiceOver announce only
// "button". (The UI audit found 57 of 74 unlabeled.)
//
// Rule A2 -- text styles use the contrast-safe tokens. Inside a TextStyle
// or AppTypography call, `textColor.withValues(alpha: 0.4-0.6)` and a bare
// `accentColor` measured below 4.5:1 on several themes (2.2:1 at worst);
// `secondaryTextColor` / `accentTextColor` are computed to meet it. Icons,
// borders and fills keep the raw colors -- they aren't text.
//
// Rule A3 -- every custom tap handler is accounted for in semantics. A
// GestureDetector/InkWell/InkResponse with onTap must sit inside Semantics,
// MergeSemantics, ExcludeSemantics or a Tooltip (or be a SemanticTap), or
// opt out explicitly with `excludeFromSemantics: true` when it is a
// pointer-only handler (tap-to-deselect, tap absorbers). Otherwise a screen
// reader meets an unlabeled "double tap to activate". (The audit found 60
// such handlers against 21 Semantics widgets.)
//
// Rule A4 -- endless animations respect reduced motion. A bare
// `AnimationController.repeat(` loops forever regardless of the OS
// "Reduce Motion" / "Remove animations" setting; loops go through
// `repeatUnlessReducedMotion` (lib/shared/widgets/reduced_motion.dart).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

List<File> _dartFilesUnder(String relativeDir) => Directory(relativeDir)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList();

/// The source of each `IconButton(...)` / `IconButton.filled(...)` etc.
/// constructor call in [source], up to its matching close paren.
Iterable<({int line, String body})> _iconButtonCalls(String source) sync* {
  // `\b` keeps helper names like `_buildIconButton(` and the static
  // `IconButton.styleFrom(` out; only constructors take the named variants.
  final opener = RegExp(r'\bIconButton(\.(filled|filledTonal|outlined))?\(');
  for (final m in opener.allMatches(source)) {
    if (m.start > 0 && RegExp(r'[\w.]').hasMatch(source[m.start - 1])) {
      continue;
    }
    var depth = 0;
    var i = m.end - 1;
    for (; i < source.length; i++) {
      final c = source[i];
      if (c == '(') depth++;
      if (c == ')' && --depth == 0) break;
    }
    yield (
      line: '\n'.allMatches(source.substring(0, m.start)).length + 1,
      body: source.substring(m.start, i + 1),
    );
  }
}

/// The text just before the innermost unclosed `(` preceding [pos] -- i.e.
/// the call whose argument list [pos] sits in.
String _enclosingCallee(String source, int pos) {
  var depth = 0;
  for (var i = pos - 1; i >= 0; i--) {
    final c = source[i];
    if (c == ')') depth++;
    if (c == '(') {
      if (depth == 0) return source.substring(i < 60 ? 0 : i - 60, i);
      depth--;
    }
  }
  return '';
}

/// Names of up to [levels] enclosing calls around [pos], innermost first.
List<String> _enclosingCalls(String source, int pos, {int levels = 4}) {
  final names = <String>[];
  var at = pos;
  for (var level = 0; level < levels; level++) {
    final head = _enclosingCallee(source, at);
    final name = RegExp(r'([\w.]+)\s*$').firstMatch(head)?.group(1);
    if (name == null) break;
    names.add(name);
    // Continue from the start of that call's name.
    at = source.lastIndexOf(name, at - 1);
    if (at <= 0) break;
  }
  return names;
}

void main() {
  test('A4 -- no endless animation bypasses reduced motion', () {
    var loops = 0;
    final violations = <String>[];
    for (final file in _dartFilesUnder('lib')) {
      final path = file.path.replaceAll('\\', '/');
      final source = file.readAsStringSync();
      loops += 'repeatUnlessReducedMotion('.allMatches(source).length;
      if (path.endsWith('reduced_motion.dart')) continue;
      for (final m in RegExp(r'\.repeat\(').allMatches(source)) {
        final line = '\n'.allMatches(source.substring(0, m.start)).length + 1;
        violations.add('$path:$line');
      }
    }

    expect(loops, greaterThanOrEqualTo(5));
    expect(
      violations,
      isEmpty,
      reason:
          'AnimationController.repeat() ignores the OS reduced-motion '
          'setting -- call repeatUnlessReducedMotion(context) from '
          'didChangeDependencies instead: $violations',
    );
  });

  test('A3 -- every custom tap handler is labeled or opted out', () {
    final opener = RegExp(r'\b(GestureDetector|InkWell|InkResponse)\(');
    final labeling = RegExp(
      r'^(Semantics|MergeSemantics|ExcludeSemantics|Tooltip|SemanticTap)$',
    );
    var handlers = 0;
    final violations = <String>[];
    for (final file in _dartFilesUnder('lib')) {
      final path = file.path.replaceAll('\\', '/');
      if (path.endsWith('semantic_tap.dart')) continue;
      final source = file.readAsStringSync();
      for (final m in opener.allMatches(source)) {
        var depth = 0;
        var end = m.end - 1;
        for (; end < source.length; end++) {
          if (source[end] == '(') depth++;
          if (source[end] == ')' && --depth == 0) break;
        }
        final body = source.substring(m.start, end + 1);
        if (!RegExp(r'\bon(Tap|LongPress|DoubleTap)\s*:').hasMatch(body)) {
          continue; // drag/pan-only gesture surfaces aren't controls
        }
        handlers++;
        if (body.contains('excludeFromSemantics: true')) continue;
        // Skip `child:`/`builder:` hops; the wrapper may be a few calls up.
        final calls = _enclosingCalls(source, m.start);
        if (calls.any(labeling.hasMatch)) continue;
        final line = '\n'.allMatches(source.substring(0, m.start)).length + 1;
        violations.add('$path:$line ${m.group(1)}');
      }
    }

    expect(handlers, greaterThan(60));
    expect(
      violations,
      isEmpty,
      reason:
          'Custom tap handler with no semantics. Use an IconButton/'
          'TextButton, wrap it (SemanticTap for icon-only, MergeSemantics + '
          'Semantics(button: true) when it has visible text), or set '
          'excludeFromSemantics: true if it is pointer-only: $violations',
    );
  });

  test('A2 -- text styles use secondaryTextColor / accentTextColor', () {
    final textCall = RegExp(r'(\bTextStyle|\bAppTypography\.\w+)\s*$');
    // Anywhere directly in a text style's arguments -- `color: x` and both
    // branches of `color: cond ? x : y` (a ternary adds no parens, so its
    // innermost enclosing call is still the text style).
    final dimText = RegExp(
      r'[\w.]*\btextColor\.withValues\(\s*alpha:\s*0?\.(4|45|5|55|6)\d*\s*,?\s*\)',
    );
    final bareAccent = RegExp(r'[\w.]*\baccentColor(?![\w.(])');
    var textStyles = 0;
    final violations = <String>[];
    for (final file in _dartFilesUnder('lib')) {
      final path = file.path.replaceAll('\\', '/');
      if (path.endsWith('theme_manager.dart')) continue;
      final source = file.readAsStringSync();
      textStyles += RegExp(r'\bAppTypography\.\w+\(').allMatches(source).length;
      for (final m in [
        ...dimText.allMatches(source),
        ...bareAccent.allMatches(source),
      ]) {
        if (textCall.hasMatch(_enclosingCallee(source, m.start))) {
          final line = '\n'.allMatches(source.substring(0, m.start)).length + 1;
          violations.add('$path:$line ${m.group(0)}');
        }
      }
    }

    expect(textStyles, greaterThan(500));
    expect(
      violations,
      isEmpty,
      reason:
          'Text colored with a low-contrast theme color -- use '
          'theme.secondaryTextColor or theme.accentTextColor: $violations',
    );
  });

  test('A1 -- every IconButton under lib/ has a tooltip', () {
    var total = 0;
    final violations = <String>[];
    for (final file in _dartFilesUnder('lib')) {
      for (final call in _iconButtonCalls(file.readAsStringSync())) {
        total++;
        if (!RegExp(r'\btooltip:').hasMatch(call.body)) {
          violations.add('${file.path.replaceAll('\\', '/')}:${call.line}');
        }
      }
    }

    // Guard against a vacuous pass (e.g. the scan matching nothing).
    expect(total, greaterThan(50));
    expect(
      violations,
      isEmpty,
      reason:
          'IconButton without a tooltip -- it doubles as the screen-reader '
          'label, so add one describing the action: $violations',
    );
  });
}
