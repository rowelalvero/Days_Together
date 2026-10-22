import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:days_together/app/theme/app_typography.dart';
import 'package:days_together/app/theme/theme_manager.dart';

/// External validation feedback for [OtpInput]: [error] shakes the slots and
/// tints them with the semantic error color, [success] tints them green and
/// shows a check beside the message.
enum OtpStatus { idle, error, success }

/// Which characters [OtpInput] accepts. [alphanumeric] upper-cases letters,
/// matching server-issued pairing codes (`isPlausiblePairingCode`).
enum OtpCharset { digits, alphanumeric }

/// A fixed-length code entry: one slot per character, backed by a single
/// hidden [TextField] that owns focus, the soft keyboard, paste and SMS
/// autofill. The slots are purely presentational.
///
/// The source of truth is a fixed-length slot list rather than a string, so
/// clearing a middle slot leaves an in-place hole instead of shifting the
/// characters after it left. The hidden field always holds a single
/// zero-width sentinel: anything typed or pasted appears next to it and is
/// spread across the slots from the active one, and the sentinel vanishing
/// means backspace.
class OtpInput extends StatefulWidget {
  const OtpInput({
    super.key,
    required this.theme,
    this.length = 6,
    this.charset = OtpCharset.digits,
    this.initialValue = '',
    this.onChanged,
    this.onCompleted,
    this.label,
    this.hint,
    this.successMessage,
    this.errorMessage,
    this.status = OtpStatus.idle,
    this.obscure = false,
    this.enabled = true,
    this.autofocus = false,
    this.semanticLabel = 'One-time passcode',
    this.groupSize,
  });

  final LoveStoryTheme theme;

  /// Number of slots.
  final int length;
  final OtpCharset charset;
  final String initialValue;

  /// Every edit, with the filled characters joined (holes are skipped, so the
  /// code is complete exactly when its length equals [length]).
  final ValueChanged<String>? onChanged;

  /// Fires on the transition from incomplete to every-slot-filled, not on
  /// every edit of an already-full code.
  final ValueChanged<String>? onCompleted;

  /// Optional label above the slots.
  final String? label;

  /// Helper text below the slots while [status] is idle.
  final String? hint;
  final String? successMessage;
  final String? errorMessage;
  final OtpStatus status;

  /// Render dots instead of the typed characters.
  final bool obscure;
  final bool enabled;
  final bool autofocus;

  /// What a screen reader announces for the field.
  final String semanticLabel;

  /// Splits the slots into chunks of this size with a dash between them
  /// (8 -> 4-4), which makes long codes easier to read off another screen.
  final int? groupSize;

  @override
  State<OtpInput> createState() => _OtpInputState();
}

const _sentinel = '​';

class _OtpInputState extends State<OtpInput>
    with SingleTickerProviderStateMixin {
  late List<String> _slots;
  int _active = 0;
  bool _caretOn = true;
  Timer? _blink;

  late final TextEditingController _controller = TextEditingController();
  late final FocusNode _focusNode = FocusNode(onKeyEvent: _onKeyEvent);

  // Replays on every transition into OtpStatus.error.
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  late final Animation<double> _shakeOffset = TweenSequence<double>([
    for (final (a, b) in const [
      (0.0, -5.0),
      (-5.0, 5.0),
      (5.0, -3.0),
      (-3.0, 3.0),
      (3.0, -1.0),
      (-1.0, 0.0),
    ])
      TweenSequenceItem(
        tween: Tween(begin: a, end: b),
        weight: 1,
      ),
  ]).animate(CurvedAnimation(parent: _shake, curve: Curves.easeOut));

  @override
  void initState() {
    super.initState();
    _slots = _toSlots(widget.initialValue);
    final firstEmpty = _slots.indexOf('');
    _active = firstEmpty == -1 ? widget.length - 1 : firstEmpty;
    _resetField();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(OtpInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.length != oldWidget.length) {
      _slots = _toSlots(_slots.join());
      _active = _active.clamp(0, widget.length - 1);
    }
    if (widget.status == OtpStatus.error &&
        oldWidget.status != OtpStatus.error &&
        !_reduceMotion) {
      _shake.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _blink?.cancel();
    _shake.dispose();
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  bool get _reduceMotion =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  String _sanitize(String raw) {
    final pattern = widget.charset == OtpCharset.digits
        ? RegExp(r'[^0-9]')
        : RegExp(r'[^A-Z0-9]');
    return raw.toUpperCase().replaceAll(pattern, '');
  }

  List<String> _toSlots(String raw) {
    final chars = _sanitize(raw);
    return List.generate(
      widget.length,
      (i) => i < chars.length ? chars[i] : '',
    );
  }

  void _resetField() {
    _controller.value = const TextEditingValue(
      text: _sentinel,
      selection: TextSelection.collapsed(offset: _sentinel.length),
    );
  }

  void _onFocusChange() {
    _blink?.cancel();
    _caretOn = true;
    if (_focusNode.hasFocus && !_reduceMotion) {
      // A Timer rather than a repeating AnimationController, so
      // pumpAndSettle in widget tests still settles while focused.
      _blink = Timer.periodic(const Duration(milliseconds: 530), (_) {
        if (mounted) setState(() => _caretOn = !_caretOn);
      });
    }
    setState(() {});
  }

  void _commit(List<String> next) {
    final wasComplete = !_slots.contains('');
    setState(() => _slots = next);
    final code = next.join();
    widget.onChanged?.call(code);
    if (!wasComplete && !next.contains('')) widget.onCompleted?.call(code);
  }

  void _setActive(int index) {
    setState(() {
      _active = index.clamp(0, widget.length - 1);
      _caretOn = true;
    });
  }

  /// One character overwrites the active slot and advances; a longer chunk
  /// (paste) fills forward from the active slot. A chunk as long as the whole
  /// code (SMS autofill, pasting the full code) fills from the start.
  void _insert(String raw) {
    final chars = _sanitize(raw);
    if (chars.isEmpty) return;
    final next = [..._slots];
    var i = chars.length >= widget.length ? 0 : _active;
    for (final ch in chars.split('')) {
      if (i >= widget.length) break;
      next[i++] = ch;
    }
    _commit(next);
    _setActive(i);
  }

  /// A filled slot clears in place; an empty one steps back and clears there.
  void _backspace() {
    if (_slots[_active].isNotEmpty) {
      _commit([..._slots]..[_active] = '');
    } else if (_active > 0) {
      _commit([..._slots]..[_active - 1] = '');
      _setActive(_active - 1);
    }
  }

  void _onFieldChanged(String value) {
    if (!widget.enabled) return _resetField();
    final typed = value.replaceAll(_sentinel, '');
    if (typed.isNotEmpty) {
      _insert(typed);
    } else if (!value.contains(_sentinel)) {
      _backspace();
    }
    _resetField();
  }

  // Hardware keys the sentinel can't express. Runs before the app-wide text
  // editing shortcuts, which would otherwise move the hidden field's caret.
  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (!widget.enabled || event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      _setActive(_active - 1);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      _setActive(_active + 1);
    } else if (key == LogicalKeyboardKey.home) {
      _setActive(0);
    } else if (key == LogicalKeyboardKey.end) {
      _setActive(widget.length - 1);
    } else if (key == LogicalKeyboardKey.delete) {
      _commit([..._slots]..[_active] = '');
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  /// A tap picks the slot under the finger, capped at the first empty slot so
  /// it can't jump ahead of progress.
  void _onPointerDown(Offset local, double slotWidth, double gap) {
    if (!widget.enabled) return;
    var tapped = widget.length - 1;
    var left = 0.0;
    for (var i = 0; i < widget.length; i++) {
      if (_separatorBefore(i)) left += _separatorWidth;
      if (local.dx < left + slotWidth + gap / 2) {
        tapped = i;
        break;
      }
      left += slotWidth + gap;
    }
    final firstEmpty = _slots.indexOf('');
    final cap = firstEmpty == -1 ? widget.length - 1 : firstEmpty;
    _setActive(tapped < cap ? tapped : cap);
  }

  static const _separatorWidth = 16.0;

  bool _separatorBefore(int i) {
    final group = widget.groupSize;
    return group != null && i > 0 && i < widget.length && i % group == 0;
  }

  Color _borderColor(String char, bool isActive) {
    final theme = widget.theme;
    return switch (widget.status) {
      OtpStatus.success => theme.semantic.success,
      OtpStatus.error => theme.semantic.error,
      OtpStatus.idle when isActive => theme.accentColor,
      OtpStatus.idle => theme.textColor.withValues(
        alpha: char.isEmpty ? 0.15 : 0.4,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final reduce = _reduceMotion;
    final filled = _slots.where((c) => c.isNotEmpty).length;
    final message = switch (widget.status) {
      OtpStatus.success => widget.successMessage,
      OtpStatus.error => widget.errorMessage,
      OtpStatus.idle => widget.hint,
    };
    final messageColor = switch (widget.status) {
      OtpStatus.success => theme.semantic.success,
      OtpStatus.error => theme.semantic.error,
      OtpStatus.idle => theme.textColor.withValues(alpha: 0.7),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: AppTypography.body(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.textColor,
            ),
          ),
          SizedBox(height: theme.spacing.sm),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 6.0;
            final separators = List.generate(
              widget.length,
              _separatorBefore,
            ).where((s) => s).length;
            final fit =
                (constraints.maxWidth -
                    gap * (widget.length - 1) -
                    separators * _separatorWidth) /
                widget.length;
            final slotWidth = fit.clamp(24.0, 52.0);
            final slotHeight = (slotWidth * 1.3).clamp(52.0, 64.0);

            return AnimatedBuilder(
              animation: _shakeOffset,
              builder: (context, child) => Transform.translate(
                offset: Offset(_shakeOffset.value, 0),
                child: child,
              ),
              child: Listener(
                onPointerDown: (e) =>
                    _onPointerDown(e.localPosition, slotWidth, gap),
                child: Stack(
                  children: [
                    ExcludeSemantics(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < widget.length; i++) ...[
                            if (i > 0) const SizedBox(width: gap),
                            if (_separatorBefore(i)) _separator(),
                            _slot(i, slotWidth, slotHeight, reduce),
                          ],
                        ],
                      ),
                    ),
                    // Transparent overlay: owns focus, the keyboard, paste
                    // and autofill. Sits on top so a tap focuses it.
                    Positioned.fill(
                      child: Semantics(
                        label: widget.semanticLabel,
                        hint: '$filled of ${widget.length} entered',
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          autofocus: widget.autofocus,
                          enabled: widget.enabled,
                          onChanged: _onFieldChanged,
                          keyboardType: widget.charset == OtpCharset.digits
                              ? TextInputType.number
                              : TextInputType.visiblePassword,
                          textCapitalization: TextCapitalization.characters,
                          autofillHints: const [AutofillHints.oneTimeCode],
                          autocorrect: false,
                          enableSuggestions: false,
                          showCursor: false,
                          style: const TextStyle(
                            color: Colors.transparent,
                            fontSize: 1,
                          ),
                          decoration: const InputDecoration.collapsed(
                            hintText: null,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        if (message != null) ...[
          SizedBox(height: theme.spacing.sm),
          Semantics(
            liveRegion: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedScale(
                  scale: widget.status == OtpStatus.success ? 1 : 0,
                  duration: reduce ? Duration.zero : theme.motion.normal,
                  curve: Curves.easeOutBack,
                  child: widget.status == OtpStatus.success
                      ? Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Icon(
                            Icons.check_circle_rounded,
                            size: 18,
                            color: messageColor,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                Expanded(
                  child: Text(
                    message,
                    style: AppTypography.body(
                      fontSize: 14,
                      color: messageColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _separator() => SizedBox(
    width: _separatorWidth,
    child: Center(
      child: Container(
        width: 8,
        height: 2,
        decoration: BoxDecoration(
          color: widget.theme.textColor.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    ),
  );

  Widget _slot(int i, double width, double height, bool reduce) {
    final theme = widget.theme;
    final char = _slots[i];
    final isActive = _focusNode.hasFocus && i == _active;
    final showCaret = isActive && widget.status != OtpStatus.success;
    // A near-solid surface so the character reads against any gradient,
    // rather than a 5% tint of the text color.
    final fill = theme.isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.white.withValues(alpha: 0.7);
    // Monospace, sized to the slot: every character gets the same width and
    // 0/O, 1/I stay distinct.
    final glyphSize = (width * 0.62).clamp(18.0, 28.0);

    return AnimatedOpacity(
      opacity: widget.enabled ? 1 : 0.5,
      duration: theme.motion.fast,
      child: AnimatedContainer(
        duration: reduce ? Duration.zero : theme.motion.fast,
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _borderColor(char, isActive),
            width: isActive || widget.status != OtpStatus.idle ? 2 : 1.5,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // A new character fades and scales in. No sliding and no
            // clipping: the glyph always paints whole inside its slot.
            AnimatedSwitcher(
              duration: reduce
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOutBack,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween(begin: 0.7, end: 1.0).animate(animation),
                  child: child,
                ),
              ),
              child: SizedBox(
                key: ValueKey('$i-$char'),
                width: width,
                child: Text(
                  char.isEmpty ? '' : (widget.obscure ? '•' : char),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  // Already sized to the slot; unbounded system scaling
                  // would push it past the border.
                  textScaler: MediaQuery.textScalerOf(
                    context,
                  ).clamp(maxScaleFactor: 1.2),
                  style: AppTypography.bodyMono(
                    fontSize: glyphSize,
                    fontWeight: FontWeight.w700,
                    color: theme.textColor,
                    height: 1.0,
                  ),
                ),
              ),
            ),
            // Blinking caret: a bar when the slot is empty, an underline
            // beneath the character when it is filled.
            if (showCaret)
              Align(
                alignment: char.isEmpty
                    ? Alignment.center
                    : const Alignment(0, 0.72),
                child: Opacity(
                  opacity: _caretOn ? 1 : 0,
                  child: Container(
                    width: char.isEmpty ? 2 : glyphSize * 0.7,
                    height: char.isEmpty ? glyphSize : 2,
                    decoration: BoxDecoration(
                      color: theme.accentColor,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
