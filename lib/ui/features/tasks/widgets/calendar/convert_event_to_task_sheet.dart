import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/api/calendar_connection_api_model.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/features/tasks/view_models/calendar_connection_view_model.dart';
import 'package:admin/ui/features/tasks/view_models/task_edit_view_model.dart'
    show emptyTask;
import 'package:admin/ui/features/tasks/widgets/calendar/calendar_event_seed.dart';
import 'package:admin/utils/formatting.dart';

/// Build the seed task for a calendar event: description (title + body), a
/// single time-log entry derived from the event's start/end (rules in
/// [seedTimeLogForEvent]), and the dedupe `meta.calendar_event_id`.
Task seedTaskForEvent(CalendarEvent event) => emptyTask().copyWith(
  description: seedDescriptionForEvent(event),
  timeLog: seedTimeLogForEvent(event),
  meta: TaskMeta(calendarEventId: event.calendarEventId),
);

/// Open the in-context "convert event → task" sheet. Stays on the calendar:
/// **Convert** creates the task through the normal outbox path and removes the
/// event chip; **Edit full details** opens the full task editor seeded the same
/// way (for client/project/custom fields).
Future<void> showConvertEventSheet({
  required BuildContext context,
  required CalendarEvent event,
  required String companyId,
  required CalendarConnectionViewModel calendarVm,
  Formatter? formatter,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => _ConvertEventSheet(
      event: event,
      companyId: companyId,
      calendarVm: calendarVm,
      formatter: formatter,
      hostContext: context,
    ),
  );
}

class _ConvertEventSheet extends StatefulWidget {
  const _ConvertEventSheet({
    required this.event,
    required this.companyId,
    required this.calendarVm,
    required this.hostContext,
    this.formatter,
  });

  final CalendarEvent event;
  final String companyId;
  final CalendarConnectionViewModel calendarVm;

  /// The calendar screen's context — stays mounted while the sheet is open, so
  /// it drives the post-pop navigation for "Edit full details".
  final BuildContext hostContext;
  final Formatter? formatter;

  @override
  State<_ConvertEventSheet> createState() => _ConvertEventSheetState();
}

class _ConvertEventSheetState extends State<_ConvertEventSheet> {
  late final TextEditingController _description = TextEditingController(
    text: seedTaskForEvent(widget.event).description,
  );
  bool _billable = true;
  bool _busy = false;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Task _seed() {
    final base = seedTaskForEvent(widget.event);
    return base.copyWith(
      description: _description.text.trim(),
      timeLog: [
        for (final entry in base.timeLog) entry.copyWith(billable: _billable),
      ],
    );
  }

  Future<void> _convert() async {
    if (_busy) return;
    setState(() => _busy = true);
    final services = widget.hostContext.read<Services>();
    final navigator = Navigator.of(context);
    try {
      // Optimistic outbox create — the server's per-user dedup, if ever hit,
      // rides the existing outbox conflict path; the events endpoint already
      // excludes converted events so a duplicate is unlikely.
      await services.tasks.create(companyId: widget.companyId, draft: _seed());
      widget.calendarVm.removeEvent(widget.event.calendarEventId);
      // The sheet may have been swiped away mid-create — only pop if still
      // mounted, else `navigator.pop()` would pop the calendar route underneath.
      if (!mounted) return;
      Notify.success(context, context.tr('created_task'));
      navigator.pop();
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        Notify.error(context, context.tr('error'), error: error);
      }
    }
  }

  void _editFullDetails() {
    final seed = _seed();
    Navigator.of(context).pop();
    goEntityCreateFullWidth(widget.hostContext, '/tasks', extra: seed);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(
        left: InSpacing.lg(context),
        right: InSpacing.lg(context),
        bottom: InSpacing.lg(context) + viewInsets,
        top: InSpacing.sm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('convert_to_task'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(_subtitle(context), style: TextStyle(color: tokens.ink3)),
          SizedBox(height: InSpacing.lg(context)),
          TextField(
            controller: _description,
            minLines: 2,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: context.tr('description'),
              border: const OutlineInputBorder(),
            ),
          ),
          SizedBox(height: InSpacing.sm),
          SwitchListTile(
            value: _billable,
            onChanged: (v) => setState(() => _billable = v),
            title: Text(context.tr('billable')),
            contentPadding: EdgeInsets.zero,
          ),
          SizedBox(height: InSpacing.md(context)),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _busy ? null : _editFullDetails,
                child: Text(context.tr('edit')),
              ),
              SizedBox(width: InSpacing.md(context)),
              PrimaryDialogAction(
                label: context.tr('save'),
                onPressed: _convert,
                busy: _busy,
                // Has a name text field — don't steal focus or promise Enter.
                autofocus: false,
                showEnterHint: false,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _subtitle(BuildContext context) {
    final event = widget.event;
    final dateStr = widget.formatter?.date(event.dayKey) ?? event.dayKey;
    if (event.allDay) return dateStr;
    final s = event.startLocal;
    if (s == null) return dateStr;
    final military = widget.formatter?.settings.enableMilitaryTime ?? false;
    final st = formatTimeOfDay(s.hour, s.minute, military: military);
    final e = event.endLocal;
    if (e == null) return '$dateStr · $st';
    final et = formatTimeOfDay(e.hour, e.minute, military: military);
    return '$dateStr · $st – $et';
  }
}
