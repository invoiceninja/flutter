import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/utils/formatting.dart';

/// Single-date input with typed shortcuts + a calendar-picker fallback.
///
/// Wraps a `TextField` whose [InputDecoration.suffixIcon] opens the
/// standard Material `showDatePicker`. The user can also type values
/// directly: ISO `2026-05-14`, the company's active date format (when
/// [formatter] is provided), short forms (`today`, `tomorrow`, `+1`,
/// `5/14`, `14`), or compact digit strings (`051426`). Parsing rules
/// live in `parseDateInput` (`lib/utils/formatting.dart`).
///
/// **Always use this** for single-date inputs in the app's UI. Don't
/// reach for `showDatePicker` directly except for one-tap range filters
/// (see `DateRangePickerButton`). Commit-on-blur + Enter; silent revert
/// on parse failure so the user can keep typing without "errored
/// field" noise.
class InDateField extends StatefulWidget {
  const InDateField({
    super.key,
    required this.value,
    required this.onChanged,
    this.formatter,
    this.labelText,
    this.hintText,
    this.enabled = true,
    this.autofocus = false,
    this.focusNode,
    this.firstDate,
    this.lastDate,
    this.clearable = false,
    this.dense = false,
    this.semanticLabel,
    this.errorText,
    this.helperText,
  });

  /// The currently-set date (calendar date — any time-of-day is ignored
  /// for display purposes). Null renders the placeholder hint.
  final DateTime? value;

  /// Fires with the committed calendar date. Pass `null` when the user
  /// clears the field (only reachable when [clearable] is true).
  final ValueChanged<DateTime?> onChanged;

  /// Active company `Formatter`. When provided, both the displayed value and
  /// the placeholder example are rendered by `formatter.date(...)`, so they
  /// share a format by construction. Without it the field falls back to ISO.
  final Formatter? formatter;

  /// Floating label rendered above the field via `InputDecoration.labelText`.
  /// Pass this instead of wrapping the widget in an outer `InputDecorator`
  /// — nesting two decorations stacks borders and breaks the visual.
  final String? labelText;

  /// Override the placeholder hint. Defaults to a worked example date in the
  /// company's active format (e.g. `Jan 31, 2000`), or the ISO
  /// [kDateFormatSampleIso] if no formatter.
  final String? hintText;

  final bool enabled;
  final bool autofocus;
  final FocusNode? focusNode;

  /// Earliest date the modal picker accepts. Defaults to year 2000 — the
  /// same lower bound `time_entry_table.dart` used previously.
  final DateTime? firstDate;

  /// Latest date the modal picker accepts. Defaults to today + 5 years.
  final DateTime? lastDate;

  /// When true and [value] is non-null, render a trailing `×` to clear
  /// the field (fires `onChanged(null)`). Useful for optional fields
  /// like project due-date; leave false for required ones.
  ///
  /// Adds ~28 px of width to the trailing suffix when a value is set
  /// (clear + picker buttons side-by-side). Avoid in tight table cells
  /// where the suffix would crowd the value.
  final bool clearable;

  /// Render as a cell of an inline-editable table rather than a form field:
  /// borderless at rest with an accent underline on focus, 13 px text, 8 px
  /// padding — the look of the line-item table's text cells, which this sits
  /// between — and only the calendar glyph, kept out of the Tab order so the
  /// cell costs one stop like its neighbours.
  ///
  /// A dense field never draws the `×`; with [clearable] set, emptying the
  /// text and leaving the cell clears the date instead. The outlined field is
  /// ~49 px tall and its two suffix buttons are 56 px wide, which is most of a
  /// table column.
  ///
  /// The calendar button sits beside the text field rather than in its
  /// decoration — outside [semanticLabel]'s merge, so a screen reader can still
  /// reach it — and is shrink-wrapped to 28 px: on touch the padded target
  /// would lay it out at 40 and push the row past its neighbours.
  final bool dense;

  /// With [dense], announced as the text field's name: a dense cell has no
  /// [labelText] — its column header names it. An empty field still reads its
  /// example-date hint, as a hint.
  final String? semanticLabel;

  /// Inline error under the field — a server 422 or a form's own validation,
  /// keyed by the field's API name (`vm.fieldErrorFor('due_date')`).
  final String? errorText;

  /// A line under the field — what a blank value will become (the billing
  /// due date's "Net 30"). An [errorText] takes its place.
  final String? helperText;

  @override
  State<InDateField> createState() => _InDateFieldState();
}

class _InDateFieldState extends State<InDateField> {
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
  void didUpdateWidget(covariant InDateField old) {
    super.didUpdateWidget(old);
    final next = _format(widget.value);
    // Re-seed only when the external value changed and the user isn't
    // currently typing (controller text out of sync). Matches the
    // cursor-stable pattern used in the duration / description cells.
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

  String _format(DateTime? value) {
    if (value == null) return '';
    final local = value.toLocal();
    final iso =
        '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
    final f = widget.formatter;
    return f == null ? iso : f.date(iso);
  }

  /// Placeholder for an empty field: a worked example of the company's date
  /// format, NOT the format's intl pattern. Rendering the pattern is what
  /// invoiceninja/flutter#127 was — `dd/MMM/yyyy` (the server's default) read
  /// as a typo, since `MMM` is an abbreviated month name rather than a
  /// two-digit number. `Formatter.dateExample` renders it through the same
  /// path as a committed value, so the hint always matches what the field
  /// will show once the user picks a date.
  String _hint() =>
      widget.hintText ?? widget.formatter?.dateExample ?? kDateFormatSampleIso;

  String? _activePattern() {
    final f = widget.formatter;
    return f?.dateFormats[f.settings.dateFormatId]?.format;
  }

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
    final parsed = parseDateInput(
      _controller.text,
      activePattern: _activePattern(),
    );
    if (parsed == null) {
      // Silent revert: restore the last valid render. The picker icon is
      // the fallback for users who don't want to type.
      _controller.text = _externalText;
      return;
    }
    _externalText = _format(parsed);
    // Refresh the visible field to the canonical render. The cursor-
    // stable guard in `didUpdateWidget` would otherwise short-circuit
    // the re-seed (since `_externalText == next`) and leave the user's
    // raw input (`+7`, `today`, `5/14`) on screen instead of the
    // formatted company-date.
    _controller.text = _externalText;
    widget.onChanged(parsed);
  }

  Future<void> _openPicker() async {
    if (!widget.enabled) return;
    final first = widget.firstDate ?? DateTime(2000);
    final last =
        widget.lastDate ?? DateTime.now().add(const Duration(days: 365 * 5));
    // Clamp into [first, last]: a stored value outside the picker bounds
    // (e.g. a pre-2000 date) would otherwise trip showDatePicker's
    // `!initialDate.isBefore(firstDate)` assertion and the picker would
    // never open.
    var initial = widget.value?.toLocal() ?? DateTime.now();
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked == null) return;
    _externalText = _format(picked);
    _controller.text = _externalText;
    widget.onChanged(picked);
  }

  OutlineInputBorder _border(BuildContext context) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(InRadii.r1),
    borderSide: BorderSide(color: context.inTheme.border),
  );

  @override
  Widget build(BuildContext context) {
    final suffixChildren = <Widget>[];
    if (widget.clearable &&
        !widget.dense &&
        widget.value != null &&
        widget.enabled) {
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
    final dense = widget.dense;
    final calendar = IconButton(
      iconSize: 16,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      style: dense
          ? IconButton.styleFrom(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            )
          : null,
      icon: const Icon(Icons.date_range),
      tooltip: context.tr('select_date'),
      onPressed: widget.enabled ? _openPicker : null,
    );
    if (!dense) suffixChildren.add(calendar);
    final field = TextField(
      controller: _controller,
      focusNode: _focusNode,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      textAlignVertical: TextAlignVertical.center,
      style: TextStyle(fontSize: dense ? 13 : 14),
      decoration: InputDecoration(
        isDense: true,
        labelText: widget.labelText,
        hintText: _hint(),
        errorText: widget.errorText,
        helperText: widget.helperText,
        contentPadding: dense
            ? const EdgeInsets.all(8)
            : EdgeInsets.symmetric(
                horizontal: InSpacing.md(context),
                vertical: 14,
              ),
        border: dense ? InputBorder.none : _border(context),
        enabledBorder: dense ? InputBorder.none : _border(context),
        focusedBorder: dense
            ? UnderlineInputBorder(
                borderSide: BorderSide(color: context.inTheme.accent, width: 2),
              )
            : null,
        suffixIcon: dense
            ? null
            : Row(mainAxisSize: MainAxisSize.min, children: suffixChildren),
        suffixIconConstraints: const BoxConstraints(
          minWidth: 28,
          minHeight: 28,
        ),
      ),
      onSubmitted: (_) => _commitTyped(),
    );
    if (!dense) return field;
    final label = widget.semanticLabel;
    return Row(
      children: [
        Expanded(
          child: label == null
              ? field
              : MergeSemantics(
                  child: Semantics(label: label, child: field),
                ),
        ),
        // Kept out of the Tab order so the cell costs one stop like its
        // neighbours; typing a date is the keyboard path.
        ExcludeFocus(child: calendar),
      ],
    );
  }
}
