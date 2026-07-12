import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/in_date_field.dart';
import 'package:admin/ui/core/widgets/in_time_field.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/utils/formatting.dart';

/// Modal that lets the user pick a future date + time at which to send an
/// email. Returns the chosen `DateTime` (local time) or null if cancelled.
///
/// Used by [BillingDocEmailSheet]'s "Schedule for later" path. The caller
/// converts to UTC + ISO 8601 before enqueuing the outbox row, so the
/// server stores in UTC.
Future<DateTime?> showScheduleEmailPicker(
  BuildContext context, {
  required Formatter? formatter,
  DateTime? initial,
}) {
  return showDialog<DateTime>(
    context: context,
    builder: (_) =>
        _ScheduleEmailDialog(formatter: formatter, initial: initial),
  );
}

class _ScheduleEmailDialog extends StatefulWidget {
  const _ScheduleEmailDialog({required this.formatter, this.initial});

  final Formatter? formatter;
  final DateTime? initial;

  @override
  State<_ScheduleEmailDialog> createState() => _ScheduleEmailDialogState();
}

class _ScheduleEmailDialogState extends State<_ScheduleEmailDialog> {
  late DateTime? _date;
  late TimeOfDay? _time;

  @override
  void initState() {
    super.initState();
    final start =
        widget.initial ?? DateTime.now().add(const Duration(hours: 1));
    _date = DateTime(start.year, start.month, start.day);
    _time = TimeOfDay(hour: start.hour, minute: start.minute);
  }

  DateTime? get _composed {
    final d = _date;
    final t = _time;
    if (d == null || t == null) return null;
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  bool get _isInFuture {
    final composed = _composed;
    if (composed == null) return false;
    return composed.isAfter(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr('schedule_email')),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InDateField(
              value: _date,
              onChanged: (d) => setState(() => _date = d),
              formatter: widget.formatter,
              labelText: context.tr('date'),
              firstDate: DateTime.now().subtract(const Duration(days: 1)),
            ),
            SizedBox(height: InSpacing.md(context)),
            InTimeField(
              value: _time,
              onChanged: (t) => setState(() => _time = t),
              formatter: widget.formatter,
              labelText: context.tr('time'),
            ),
          ],
        ),
      ),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.tr('cancel')),
            ),
            const SizedBox(width: 8),
            PrimaryDialogAction(
              label: context.tr('schedule'),
              onPressed: () => Navigator.of(context).pop(_composed),
              enabled: _isInFuture,
            ),
          ],
        ),
      ],
    );
  }
}
