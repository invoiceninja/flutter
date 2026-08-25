import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/models/domain/time_entry.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/tasks/line_item_task_seed.dart';
import 'package:admin/domain/tasks/task_day.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/entity_list_constants.dart';
import 'package:admin/ui/core/widgets/form_save_scope.dart';
import 'package:admin/ui/core/widgets/in_date_field.dart';
import 'package:admin/ui/core/widgets/in_time_field.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/features/tasks/view_models/task_edit_view_model.dart'
    show emptyTask;
import 'package:admin/utils/formatting.dart';

/// "Create Task" from an invoice / quote line item — schedule the work a line
/// describes onto a day, without leaving the document (invoiceninja/flutter#88).
///
/// A task carries no stored date: its calendar day is the local date of its
/// earliest time-entry start (`TaskDay.day`), so scheduling one means seeding a
/// single [TimeEntry]. The conversion rules live in `line_item_task_seed.dart`;
/// this widget owns the form, the day's existing bookings, and the save.
///
/// **The line item is left untouched.** Setting its `task_id` would be the
/// truer "convert", but the server's `InvoiceService::linkEntities()` stamps
/// `task.invoice_id` on every invoice save, and this app treats an invoiced
/// task as read-only and hides it from kanban — so the work just scheduled
/// could never be edited or time-logged. Consequence to know: running the
/// action twice creates two tasks. Reopening the sheet on the same date shows
/// the first one in the Schedule panel, which is the only signal there can be.
///
/// Deliberately no "Edit full details" escape hatch (unlike its sibling
/// `showConvertEventSheet`, whose host is the calendar): this one's host is a
/// dirty edit form, so navigating to `/tasks/new` would trip the
/// unsaved-changes guard and risk discarding the user's invoice. The success
/// toast gets no navigating action for the same reason.
Future<void> showCreateTaskFromLineItemSheet(
  BuildContext context, {
  required String companyId,
  required LineItem item,
  String clientId = '',
  String projectId = '',
  Date? documentDate,
  Formatter? formatter,
}) {
  final body = _CreateTaskFromLineItemSheet(
    companyId: companyId,
    item: item,
    clientId: clientId,
    projectId: projectId,
    documentDate: documentDate,
    formatter: formatter,
  );
  // Same responsive split as `TimeEntryEditorSheet.show`. The desktop row menu
  // is this sheet's primary entry point, so a bottom sheet on a wide window
  // would be wrong — that shape is right for the touch-first calendar, not here.
  if (MediaQuery.sizeOf(context).width >= 600) {
    return showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: body,
        ),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: body,
    ),
  );
}

/// Host-side wiring for a billing-doc edit layout: the callback to hand
/// `LineItemEditor` / `BillingDocItemsTabs` as `onCreateTaskFromLineItem`, or
/// **null** when the affordance shouldn't exist at all. Null hides it rather
/// than greying it, matching `EntityActionItem.isVisible`. Three gates:
///
///  * the company has the Tasks module switched off,
///  * this user can't create a task,
///  * the document has no client yet. Scheduling from a quote only means
///    anything if the work is *for that client*, and `Task.toApiJson` sends
///    `client_id` unconditionally — so without this the action would quietly
///    mint an unattached task. Nothing upstream covers it:
///    `LineItemEditor.disabledReasonKey` exists to gate the items section on a
///    client but has no caller anywhere, so the rows stay editable regardless.
///    The hosts rebuild this handler every frame, so the action appears the
///    moment a client is picked.
///
/// [context] is the layout's, which stays mounted for as long as the editor is
/// on screen — the same capture `onPickItems: () => _openPicker(context)` makes
/// right beside every call site.
ValueChanged<LineItem>? createTaskFromLineItemHandler(
  BuildContext context, {
  required String companyId,
  required String clientId,
  required String projectId,
  Date? documentDate,
}) {
  if (clientId.isEmpty) return null;
  final services = context.read<Services>();
  final me = services.auth.session.value?.currentCompany;
  if (!(me?.moduleEnabled(EntityType.task) ?? false)) return null;
  if (!(me?.can('create_task') ?? false)) return null;
  return (item) => showCreateTaskFromLineItemSheet(
    context,
    companyId: companyId,
    item: item,
    clientId: clientId,
    projectId: projectId,
    documentDate: documentDate,
    formatter: services.formatterIfReady(companyId),
  );
}

class _CreateTaskFromLineItemSheet extends StatefulWidget {
  const _CreateTaskFromLineItemSheet({
    required this.companyId,
    required this.item,
    required this.clientId,
    required this.projectId,
    required this.documentDate,
    required this.formatter,
  });

  final String companyId;
  final LineItem item;
  final String clientId;
  final String projectId;

  /// The host document's own date — the most contextual default for "when is
  /// this work happening". Falls back to today.
  final Date? documentDate;
  final Formatter? formatter;

  @override
  State<_CreateTaskFromLineItemSheet> createState() =>
      _CreateTaskFromLineItemSheetState();
}

class _CreateTaskFromLineItemSheetState
    extends State<_CreateTaskFromLineItemSheet> {
  late final Services _services = context.read<Services>();

  /// Cached, not built in `build()`: `watch*` returns a fresh stream per call
  /// and this sheet rebuilds on every keystroke, so a per-build stream would
  /// restart an unpaginated Drift query each time. Same trap `LineItemEditor`
  /// documents for `watchCompany`.
  late final Stream<List<Task>> _tasks = _services.tasks.watchAllActive(
    companyId: widget.companyId,
  );
  late final Stream<Company?> _company = _services.company.watchCompany(
    widget.companyId,
  );

  /// LOCAL wall-clock start. Every compose path reads its wall-clock fields, and
  /// `TimeEntry.encodeLog` serializes via `millisecondsSinceEpoch` so the local
  /// value still round-trips to the right instant.
  late DateTime _start;
  late Duration _duration;
  late final TextEditingController _description;
  late final TextEditingController _durationText;
  late final TextEditingController _rate;

  /// Blur is what reconciles the Duration field with [_duration] — see
  /// [_syncDurationText].
  final FocusNode _durationFocus = FocusNode();
  bool _billable = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _start = _seedStart(widget.documentDate);
    _duration = lineItemTaskDuration(widget.item);
    _description = TextEditingController(
      text: lineItemTaskDescription(widget.item),
    );
    _durationText = TextEditingController(
      // H:MM, not H:MM:SS — seconds are noise when scheduling a block, and
      // this matches the labels in the quick-pick menu below.
      text: formatDuration(_duration, compactDays: true, showSeconds: false),
    );
    // Raw decimal, NOT `Formatter.inputMoney`: that rounds to a currency's
    // precision, and with no `currencyId` it would resolve to the COMPANY
    // currency while this line's money is really in the client's — so a
    // 0-decimal company currency would silently save 150.75 as 151. Every
    // sibling seeds raw for the same reason: the task edit form
    // (`decimalInputText(vm.draft.rate)`), the desktop line-item table
    // (`_seedFor`), and the mobile line-item dialog (`_decimalText`).
    _rate = TextEditingController(text: decimalInputText(widget.item.cost));
    _durationFocus.addListener(() {
      if (!_durationFocus.hasFocus) _syncDurationText();
    });
  }

  /// Re-render the Duration field from the value that will actually be saved.
  ///
  /// [_onDurationChanged] ignores input it can't parse so a half-typed value
  /// doesn't destroy the committed one — but that left an emptied or `0` field
  /// showing one thing and saving another. Silent revert on blur is the same
  /// contract `InDateField` / `InTimeField` implement.
  void _syncDurationText() {
    final text = formatDuration(
      _duration,
      compactDays: true,
      showSeconds: false,
    );
    if (_durationText.text != text) _durationText.text = text;
  }

  @override
  void dispose() {
    _description.dispose();
    _durationText.dispose();
    _rate.dispose();
    _durationFocus.dispose();
    super.dispose();
  }

  /// 09:00 on the document's date — the same anchor `seedTimeLogForEvent` uses
  /// for an all-day event. When that date is today, start from now rounded up
  /// to the next quarter hour instead, so the seeded block isn't already past.
  ///
  /// That rounding deliberately carries into the next day past 23:45 (23:50 →
  /// tomorrow 00:00): clamping to 23:45 would seed a start that is already
  /// behind the clock, and everything downstream stays consistent because
  /// `_day` is derived from `_start`, so the Date field and the schedule panel
  /// both follow it.
  static DateTime _seedStart(Date? documentDate) {
    final now = DateTime.now();
    final today = Date.today();
    final day = documentDate ?? today;
    if (day != today) return DateTime(day.year, day.month, day.day, 9);
    final quarters = (now.minute / 15).ceil() * 15;
    return DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
    ).add(Duration(minutes: quarters));
  }

  Date get _day => Date(_start.year, _start.month, _start.day);
  DateTime get _blockEnd => _start.add(_duration);

  bool get _useComma =>
      widget.formatter?.settings.useCommaAsDecimalPlace ?? false;

  void _onDate(DateTime? picked) {
    if (picked == null) return;
    setState(() {
      // Keep the time of day; the duration rides along untouched because we
      // store start + duration rather than start/stop.
      _start = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _start.hour,
        _start.minute,
      );
    });
  }

  void _onTime(TimeOfDay? picked) {
    if (picked == null) return;
    setState(() {
      _start = DateTime(
        _start.year,
        _start.month,
        _start.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  void _onDurationChanged(String raw) {
    final parsed = parseDurationInput(raw);
    if (parsed == null || parsed <= Duration.zero) return;
    setState(() => _duration = parsed);
  }

  void _applyDurationPreset(int minutes) {
    final next = Duration(minutes: minutes);
    setState(() {
      _duration = next;
      _durationText.text = formatDuration(
        next,
        compactDays: true,
        showSeconds: false,
      );
    });
  }

  Task _seed() => emptyTask().copyWith(
    description: _description.text.trim(),
    rate:
        parseDecimal(_rate.text, useCommaAsDecimalPlace: _useComma) ??
        Decimal.zero,
    clientId: widget.clientId,
    // A project always belongs to a client; sending one without the other 422s.
    projectId: widget.clientId.isEmpty ? '' : widget.projectId,
    timeLog: seedTimeLogForLineItem(
      start: _start,
      duration: _duration,
      billable: _billable,
    ),
  );

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    final scheduled = widget.formatter?.date(_day.toIso());
    try {
      // Fire-and-forget through the outbox — nothing links back to this task,
      // so there is no id to wait for, and awaiting the row would just stall
      // the sheet for the full timeout while offline.
      await _services.tasks.create(companyId: widget.companyId, draft: _seed());
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      Notify.error(context, context.tr('error'), error: error);
      return;
    }
    // Outside the try on purpose: the task now exists, so a throw from the
    // toast or the pop must not surface as a save failure and re-arm Save —
    // that would invite a second, duplicate task.
    //
    // The sheet may have been dismissed mid-create; popping then would pop the
    // host route underneath it.
    if (!mounted) return;
    Notify.success(
      context,
      scheduled == null || scheduled.isEmpty
          ? context.tr('created_task')
          : '${context.tr('created_task')} · $scheduled',
    );
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return FormSaveScope(
      onSubmit: _save,
      enabled: !_busy,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(InSpacing.lg(context)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.tr('create_task'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(height: InSpacing.lg(context)),
              TextField(
                controller: _description,
                minLines: 2,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: context.tr('description'),
                ),
              ),
              SizedBox(height: InSpacing.md(context)),
              Row(
                children: [
                  Expanded(
                    child: InDateField(
                      value: _start,
                      onChanged: _onDate,
                      formatter: widget.formatter,
                      labelText: context.tr('date'),
                    ),
                  ),
                  const SizedBox(width: InSpacing.sm),
                  Expanded(
                    child: InTimeField(
                      value: TimeOfDay.fromDateTime(_start),
                      onChanged: _onTime,
                      formatter: widget.formatter,
                      labelText: context.tr('start_time'),
                    ),
                  ),
                ],
              ),
              SizedBox(height: InSpacing.md(context)),
              Row(
                children: [
                  Expanded(child: _durationField(context)),
                  const SizedBox(width: InSpacing.sm),
                  Expanded(
                    child: TextField(
                      controller: _rate,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) =>
                          FormSaveScope.maybeOf(context)?.trySubmit(),
                      decoration: InputDecoration(
                        labelText: context.tr('rate'),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: InSpacing.md(context)),
              _DaySchedule(
                tasks: _tasks,
                day: _day,
                blockStart: _start,
                blockEnd: _blockEnd,
                formatter: widget.formatter,
              ),
              StreamBuilder<Company?>(
                stream: _company,
                builder: (context, snap) {
                  // Default true before the company lands, matching the times
                  // section — the toggle is meaningless when the company keeps
                  // every entry billable.
                  final allow =
                      snap.data?.settings.allowBillableTaskItems ?? true;
                  if (!allow) return const SizedBox.shrink();
                  return SwitchListTile(
                    value: _billable,
                    onChanged: (v) => setState(() => _billable = v),
                    title: Text(context.tr('billable')),
                    contentPadding: EdgeInsets.zero,
                  );
                },
              ),
              SizedBox(height: InSpacing.lg(context)),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(64, 40),
                    ),
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
                    child: Text(context.tr('cancel')),
                  ),
                  SizedBox(width: InSpacing.md(context)),
                  PrimaryDialogAction(
                    label: context.tr('save'),
                    onPressed: _save,
                    busy: _busy,
                    // Multi-field form with a text field owning focus — don't
                    // steal it, and don't promise Enter-to-submit.
                    autofocus: false,
                    showEnterHint: false,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _durationField(BuildContext context) => TextField(
    controller: _durationText,
    focusNode: _durationFocus,
    onChanged: _onDurationChanged,
    textInputAction: TextInputAction.done,
    onSubmitted: (_) => FormSaveScope.maybeOf(context)?.trySubmit(),
    decoration: InputDecoration(
      labelText: context.tr('duration'),
      hintText: '1h 30m',
      // The same 15 → 120-minute presets the time-log table offers; scheduling
      // a service is exactly the "pick a round block" case they exist for.
      // Unlike that table this sheet also renders as a phone bottom sheet, so
      // the trigger is sized from the platform (44 on touch) rather than the
      // table's fixed 28 — see `actionButtonSize`.
      suffixIcon: PopupMenuButton<int>(
        tooltip: context.tr('duration'),
        icon: const Icon(Icons.arrow_drop_down, size: 18),
        padding: EdgeInsets.zero,
        iconSize: 18,
        onSelected: _applyDurationPreset,
        itemBuilder: (_) => [
          for (final m in const [15, 30, 45, 60, 75, 90, 105, 120])
            PopupMenuItem<int>(
              value: m,
              child: Text(
                formatDuration(Duration(minutes: m), showSeconds: false),
                style: const TextStyle(
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
        ],
      ),
      suffixIconConstraints: BoxConstraints(
        minWidth: actionButtonSize(),
        minHeight: actionButtonSize(),
      ),
    ),
  );
}

/// What is already booked on the chosen day, with anything that collides with
/// the chosen block flagged.
///
/// A flat list answers "what's on that day"; the flag answers "does *my* block
/// collide", which is what the feature request actually asked to see. Advisory
/// only — it never blocks Save.
class _DaySchedule extends StatelessWidget {
  const _DaySchedule({
    required this.tasks,
    required this.day,
    required this.blockStart,
    required this.blockEnd,
    required this.formatter,
  });

  final Stream<List<Task>> tasks;
  final Date day;
  final DateTime blockStart;
  final DateTime blockEnd;
  final Formatter? formatter;

  static const int _maxRows = 3;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return StreamBuilder<List<Task>>(
      stream: tasks,
      builder: (context, snap) {
        // Say nothing rather than claim the day is clear: the empty state here
        // reads "Available", which is an affirmative the app can't make when
        // the query failed.
        if (snap.hasError) return const SizedBox.shrink();
        // Entry-level, not task-level: "is 14:00 free?" is the real question,
        // and a task with two entries that day occupies two slots.
        final entries = entriesOnDay(snap.data ?? const <Task>[], day);
        final military = formatter?.settings.enableMilitaryTime ?? false;
        final shown = entries.take(_maxRows).toList(growable: false);
        final hidden = entries.length - shown.length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              entries.isEmpty
                  ? context.tr('available')
                  : '${context.tr('schedule')} · ${entries.length}',
              style: TextStyle(
                color: entries.isEmpty ? tokens.ink3 : tokens.ink,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            for (final row in shown)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: _row(
                  context,
                  label: taskPrimaryLabel(row.task, max: 40),
                  range: _range(row.entry, military: military),
                  clashes: _overlaps(row.entry),
                ),
              ),
            if (hidden > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+$hidden ${context.tr('more')}',
                  style: TextStyle(color: tokens.ink3, fontSize: 12),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _row(
    BuildContext context, {
    required String label,
    required String range,
    required bool clashes,
  }) {
    final tokens = context.inTheme;
    final color = clashes ? tokens.warning : tokens.ink3;
    return Row(
      children: [
        Expanded(
          child: Text(
            '$range · $label',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontSize: 12),
          ),
        ),
        if (clashes) ...[
          const SizedBox(width: 4),
          Semantics(
            label: context.tr('warning'),
            child: Icon(
              Icons.warning_amber_rounded,
              size: 14,
              color: tokens.warning,
            ),
          ),
        ],
      ],
    );
  }

  /// Half-open intersection with the chosen block. A running entry (no stop)
  /// is still occupying time, so it runs to now.
  bool _overlaps(TimeEntry entry) {
    final start = entry.start?.toLocal();
    if (start == null) return false;
    final stop = entry.stop?.toLocal() ?? DateTime.now();
    return start.isBefore(blockEnd) && stop.isAfter(blockStart);
  }

  String _range(TimeEntry entry, {required bool military}) {
    final start = entry.start!.toLocal();
    final from = formatTimeOfDay(start.hour, start.minute, military: military);
    final stop = entry.stop?.toLocal();
    if (stop == null) return from;
    final to = formatTimeOfDay(stop.hour, stop.minute, military: military);
    return '$from – $to';
  }
}
