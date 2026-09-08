import 'package:flutter/material.dart';

import 'package:admin/l10n/localization.dart';
import 'package:admin/utils/formatting.dart';

/// Single time-of-day input with typed shortcuts + a clock-picker
/// fallback.
///
/// Wraps a `TextField` whose [InputDecoration.suffixIcon] opens the
/// standard Material `showTimePicker`. The user can also type values
/// directly: full `HH:mm` / `h:mm a` forms, bare hour `9` → 9:00,
/// compact `930` → 9:30, AM/PM suffix `9p` → 21:00. Parsing rules live
/// in `parseTimeInput` (`lib/utils/formatting.dart`).
///
/// **Always use this** for single time-of-day inputs in the app's UI.
/// Don't reach for `showTimePicker` directly. Commit-on-blur + Enter;
/// silent revert on parse failure so the user can keep typing without
/// "errored field" noise.
class InTimeField extends StatefulWidget {
  const InTimeField({
    super.key,
    required this.value,
    required this.onChanged,
    this.formatter,
    this.labelText,
    this.hintText,
    this.enabled = true,
    this.autofocus = false,
    this.focusNode,
    this.clearable = false,
  });

  /// The currently-set time-of-day. Null renders the placeholder hint.
  final TimeOfDay? value;

  /// Fires with the committed time-of-day. Pass `null` when the user
  /// clears the field (only reachable when [clearable] is true).
  final ValueChanged<TimeOfDay?> onChanged;

  /// Active company `Formatter`. When provided, the placeholder hint
  /// follows the company's `enableMilitaryTime` setting (`HH:MM` vs
  /// `h:MM AM`).
  final Formatter? formatter;

  /// Floating label rendered above the field via `InputDecoration.labelText`.
  /// Pass this instead of wrapping the widget in an outer `InputDecorator`
  /// — nesting two decorations stacks borders and breaks the visual.
  final String? labelText;

  /// Override the placeholder hint. Defaults to a worked example time —
  /// `13:45` (military) or `1:45 PM` (12-hour) — based on the formatter.
  final String? hintText;

  final bool enabled;
  final bool autofocus;
  final FocusNode? focusNode;

  /// When true and [value] is non-null, render a trailing `×` to clear
  /// the field (fires `onChanged(null)`).
  ///
  /// Adds ~28 px of width to the trailing suffix when a value is set
  /// (clear + picker buttons side-by-side). Avoid in tight table cells
  /// where the suffix would crowd the value.
  final bool clearable;

  @override
  State<InTimeField> createState() => _InTimeFieldState();
}

class _InTimeFieldState extends State<InTimeField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _ownsFocusNode = false;
  String _externalText = '';

  @override
  void initState() {
    super.initState();
    _externalText = _format(widget.value);
    _controller = TextEditingController(text: _externalText);
    if (widget.focusNode != null) {
      _focusNode = widget.focusNode!;
    } else {
      _focusNode = FocusNode();
      _ownsFocusNode = true;
    }
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant InTimeField old) {
    super.didUpdateWidget(old);
    final next = _format(widget.value);
    if (next != _externalText && next != _controller.text) {
      _externalText = next;
      _controller.text = next;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    if (_ownsFocusNode) _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  bool get _military => widget.formatter?.settings.enableMilitaryTime ?? true;

  String _format(TimeOfDay? value) {
    if (value == null) return '';
    return formatTimeOfDay(value.hour, value.minute, military: _military);
  }

  /// Placeholder for an empty field: a worked example clock time, not a
  /// format pattern — the sibling of `InDateField`'s example hint
  /// (invoiceninja/flutter#127). Shares [formatTimeOfDay] with [_format], so
  /// the hint is exactly the shape a committed value takes.
  String _hint() => widget.hintText ?? timeFormatSample(military: _military);

  void _onFocusChange() {
    if (_focusNode.hasFocus) return;
    _commitTyped();
  }

  void _commitTyped() {
    if (_controller.text.isEmpty && widget.clearable && widget.value != null) {
      _externalText = '';
      widget.onChanged(null);
      return;
    }
    // Nothing typed since the last commit — skip the parse + `onChanged`
    // round-trip. Without this, a focus-loss after `+ Add time` (or any
    // blur without a real edit) fires a no-op `onChanged`, the parent
    // VM rebuilds, and the row's `×` IconButton is torn down between
    // pointer-down and pointer-up → the tap is lost and the user has
    // to click twice.
    if (_controller.text == _externalText) return;
    final parsed = parseTimeInput(_controller.text);
    if (parsed == null) {
      _controller.text = _externalText;
      return;
    }
    _externalText = _format(parsed);
    // Refresh the visible field to the canonical render. The cursor-
    // stable guard in `didUpdateWidget` would otherwise short-circuit
    // the re-seed (since `_externalText == next`) and leave the user's
    // raw input (`20`) on screen instead of the formatted `20:00`.
    _controller.text = _externalText;
    widget.onChanged(parsed);
  }

  Future<void> _openPicker() async {
    if (!widget.enabled) return;
    final picked = await showTimePicker(
      context: context,
      initialTime: widget.value ?? TimeOfDay.now(),
    );
    if (picked == null) return;
    _externalText = _format(picked);
    _controller.text = _externalText;
    widget.onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final suffixChildren = <Widget>[];
    if (widget.clearable && widget.value != null && widget.enabled) {
      suffixChildren.add(
        IconButton(
          iconSize: 16,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          icon: const Icon(Icons.close),
          tooltip: context.tr('clear'),
          onPressed: () {
            _controller.clear();
            _externalText = '';
            widget.onChanged(null);
          },
        ),
      );
    }
    suffixChildren.add(
      IconButton(
        iconSize: 16,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
        icon: const Icon(Icons.schedule),
        tooltip: context.tr('select_time'),
        onPressed: widget.enabled ? _openPicker : null,
      ),
    );

    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      textAlignVertical: TextAlignVertical.center,
      style: const TextStyle(fontSize: 12),
      decoration: InputDecoration(
        isDense: true,
        labelText: widget.labelText,
        hintText: _hint(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: suffixChildren,
        ),
        suffixIconConstraints: const BoxConstraints(
          minWidth: 28,
          minHeight: 28,
        ),
      ),
      onSubmitted: (_) => _commitTyped(),
    );
  }
}
