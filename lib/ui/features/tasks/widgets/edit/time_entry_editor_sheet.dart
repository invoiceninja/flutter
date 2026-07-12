import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/time_entry.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/in_date_field.dart';
import 'package:admin/ui/core/widgets/in_time_field.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/utils/formatting.dart';

/// Full editor for a single `TimeEntry`. Modal — opens as a bottom sheet on
/// narrow screens (`<600 px`) and an `AlertDialog` on wide. Returns the
/// committed entry to the caller, or `null` if the user cancelled.
///
/// Returns the literal value `_kRemoveSentinel` (a special TimeEntry value
/// produced by [_RemoveSentinel]) when the user taps Remove — the caller
/// distinguishes via the static helper [isRemoveSignal].
class TimeEntryEditorSheet extends StatefulWidget {
  const TimeEntryEditorSheet({
    super.key,
    required this.initial,
    this.allowBillableToggle = true,
    this.showEndDate = false,
    this.showItemDescription = true,
    this.allowRemove = true,
    this.formatter,
  });

  final TimeEntry initial;
  final bool allowBillableToggle;

  /// When true, surface a stop-DATE field so a single entry can span
  /// multiple days (company `show_task_end_date`). Default false: the stop
  /// date follows the start date and only the stop time is editable.
  final bool showEndDate;

  /// When false, hide the per-entry description field (company
  /// `show_task_item_description`).
  final bool showItemDescription;
  final bool allowRemove;

  /// Resolved company `Formatter` for the start-date button label.
  /// Falls back to ISO when null.
  final Formatter? formatter;

  /// Public entry point — shows the modal and resolves with the committed
  /// entry, `null` if cancelled, or a sentinel that the caller can detect
  /// via [isRemoveSignal] (Remove was tapped).
  static Future<TimeEntry?> show(
    BuildContext context, {
    required TimeEntry initial,
    bool allowBillableToggle = true,
    bool showEndDate = false,
    bool showItemDescription = true,
    bool allowRemove = true,
    Formatter? formatter,
  }) async {
    final isWide = MediaQuery.sizeOf(context).width >= 600;
    if (isWide) {
      return showDialog<TimeEntry>(
        context: context,
        builder: (ctx) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: TimeEntryEditorSheet(
              initial: initial,
              allowBillableToggle: allowBillableToggle,
              showEndDate: showEndDate,
              showItemDescription: showItemDescription,
              allowRemove: allowRemove,
              formatter: formatter,
            ),
          ),
        ),
      );
    }
    return showModalBottomSheet<TimeEntry>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: TimeEntryEditorSheet(
          initial: initial,
          allowBillableToggle: allowBillableToggle,
          showEndDate: showEndDate,
          showItemDescription: showItemDescription,
          allowRemove: allowRemove,
          formatter: formatter,
        ),
      ),
    );
  }

  /// Sentinel detection — the Remove button resolves with a `TimeEntry`
  /// whose start AND stop are both `_removeFlag` (a fixed epoch second
  /// in the year 1970). Callers check via this helper.
  static bool isRemoveSignal(TimeEntry? value) =>
      value != null &&
      value.start != null &&
      value.start!.millisecondsSinceEpoch == _removeMillis &&
      value.stop != null &&
      value.stop!.millisecondsSinceEpoch == _removeMillis;

  static const int _removeMillis = -1;
  static final TimeEntry removeSentinel = TimeEntry(
    start: DateTime.fromMillisecondsSinceEpoch(_removeMillis, isUtc: true),
    stop: DateTime.fromMillisecondsSinceEpoch(_removeMillis, isUtc: true),
    description: '',
    billable: false,
  );

  @override
  State<TimeEntryEditorSheet> createState() => _TimeEntryEditorSheetState();
}

class _TimeEntryEditorSheetState extends State<TimeEntryEditorSheet> {
  late DateTime _start;
  late DateTime _stop;
  late bool _isRunning;
  late TextEditingController _description;
  late TextEditingController _duration;
  late bool _billable;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // Keep _start/_stop in LOCAL time throughout: the date/time pickers and
    // every compose path read their wall-clock fields (`_start.hour`,
    // `_start.year`, …), so a UTC-backed value would mix zones and shift the
    // entry for non-UTC users. `TimeEntry.encodeLog` serializes via
    // `millisecondsSinceEpoch`, so the local value still round-trips to the
    // correct instant. Mirrors the desktop time-table cells.
    _start = (widget.initial.start ?? now.subtract(const Duration(minutes: 30)))
        .toLocal();
    _isRunning = widget.initial.isRunning;
    _stop = (widget.initial.stop ?? now).toLocal();
    _description = TextEditingController(text: widget.initial.description);
    _duration = TextEditingController(
      text: formatDuration(_stop.difference(_start), compactDays: true),
    );
    _billable = widget.initial.billable;
  }

  @override
  void dispose() {
    _description.dispose();
    _duration.dispose();
    super.dispose();
  }

  void _onDurationChanged(String raw) {
    final parsed = parseDurationInput(raw);
    if (parsed == null) return;
    setState(() {
      _stop = _start.add(parsed);
      _isRunning = false;
    });
  }

  void _onStartDate(DateTime? picked) {
    if (picked == null) return;
    setState(() {
      // Mirror the desktop table's `_DateCell._commit`: moving the entry to
      // another day shifts the stop by the same delta so the duration is
      // preserved. Leaving the stop anchored silently inflated the entry by
      // whole days (date moved backward) or had `_clamp` collapse it to
      // zero (date moved past the old stop) — while the stale duration text
      // masked either.
      final delta = _stop.difference(_start);
      _start = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _start.hour,
        _start.minute,
      );
      if (!_isRunning) {
        _stop = _start.add(delta);
        _duration.text = formatDuration(delta, compactDays: true);
      }
    });
  }

  void _onStartTime(TimeOfDay? picked) {
    if (picked == null) return;
    setState(() {
      _start = DateTime(
        _start.year,
        _start.month,
        _start.day,
        picked.hour,
        picked.minute,
      );
      // Desktop parity: a start-time change keeps the stop anchored (the
      // duration absorbs it) — but the duration text must follow, or the
      // sheet shows the pre-edit value until some other field is touched.
      if (!_isRunning) {
        _duration.text = formatDuration(
          _stop.difference(_start),
          compactDays: true,
        );
      }
    });
  }

  void _onStopTime(TimeOfDay? picked) {
    if (picked == null) return;
    setState(() {
      _stop = DateTime(
        _stop.year,
        _stop.month,
        _stop.day,
        picked.hour,
        picked.minute,
      );
      _isRunning = false;
      _duration.text = formatDuration(
        _stop.difference(_start),
        compactDays: true,
      );
    });
  }

  void _onStopDate(DateTime? picked) {
    if (picked == null) return;
    setState(() {
      _stop = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _stop.hour,
        _stop.minute,
      );
      _isRunning = false;
      _duration.text = formatDuration(
        _stop.difference(_start),
        compactDays: true,
      );
    });
  }

  void _commit() {
    Navigator.of(context).pop(
      TimeEntry(
        start: _start,
        stop: _isRunning ? null : _stop,
        description: _description.text,
        billable: _billable,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(InSpacing.lg(context)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.tr('time_entry'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: tokens.ink,
              ),
            ),
            SizedBox(height: InSpacing.lg(context)),
            // Typed date + time fields with picker fallback. Same shared
            // widgets the desktop time-log table uses — short forms like
            // `today`, `+1`, `9p`, `930` work here too.
            Row(
              children: [
                Expanded(
                  child: InDateField(
                    value: _start,
                    onChanged: _onStartDate,
                    formatter: widget.formatter,
                  ),
                ),
                const SizedBox(width: InSpacing.sm),
                Expanded(
                  child: InTimeField(
                    value: TimeOfDay.fromDateTime(_start.toLocal()),
                    onChanged: _onStartTime,
                    formatter: widget.formatter,
                  ),
                ),
              ],
            ),
            if (widget.showEndDate && !_isRunning) ...[
              SizedBox(height: InSpacing.md(context)),
              InDateField(
                value: _stop,
                onChanged: _onStopDate,
                formatter: widget.formatter,
              ),
            ],
            SizedBox(height: InSpacing.md(context)),
            Row(
              children: [
                Expanded(
                  child: InTimeField(
                    value: _isRunning
                        ? null
                        : TimeOfDay.fromDateTime(_stop.toLocal()),
                    onChanged: _onStopTime,
                    formatter: widget.formatter,
                    enabled: !_isRunning,
                    hintText: _isRunning ? context.tr('running') : null,
                  ),
                ),
                const SizedBox(width: InSpacing.sm),
                Expanded(
                  child: TextField(
                    controller: _duration,
                    decoration: InputDecoration(
                      labelText: context.tr('duration'),
                      hintText: '1h 30m',
                    ),
                    onChanged: _onDurationChanged,
                  ),
                ),
              ],
            ),
            if (widget.showItemDescription) ...[
              SizedBox(height: InSpacing.md(context)),
              TextField(
                controller: _description,
                maxLines: 3,
                minLines: 1,
                decoration: InputDecoration(
                  labelText: context.tr('description'),
                ),
              ),
            ],
            if (widget.allowBillableToggle) ...[
              const SizedBox(height: InSpacing.sm),
              SwitchListTile(
                title: Text(context.tr('billable')),
                value: _billable,
                onChanged: (v) => setState(() => _billable = v),
                contentPadding: EdgeInsets.zero,
              ),
            ],
            SizedBox(height: InSpacing.lg(context)),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (widget.allowRemove) ...[
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(64, 40),
                      foregroundColor: tokens.overdue,
                    ),
                    onPressed: () => Navigator.of(
                      context,
                    ).pop(TimeEntryEditorSheet.removeSentinel),
                    child: Text(context.tr('remove')),
                  ),
                  SizedBox(width: InSpacing.md(context)),
                ],
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(64, 40),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(context.tr('cancel')),
                ),
                SizedBox(width: InSpacing.md(context)),
                PrimaryDialogAction(
                  label: context.tr('done'),
                  onPressed: _commit,
                  // Multi-field editor — don't grab focus from the fields or
                  // promise Enter-to-submit.
                  autofocus: false,
                  showEnterHint: false,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
