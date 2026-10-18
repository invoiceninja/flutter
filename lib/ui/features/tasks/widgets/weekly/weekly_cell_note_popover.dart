import 'package:flutter/material.dart';

import 'package:admin/data/models/value/date.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/features/tasks/view_models/task_weekly_view_model.dart';

/// Edit a weekly cell's description + billable flag. Routes through
/// `vm.editCell`, so a note edit collapses into the same per-task debounce as a
/// duration edit (one outbox save per window). Presented as a small dialog —
/// v2 has no headless popover primitive, and the edit is infrequent enough that
/// a centered card reads fine.
Future<void> showWeeklyCellNote(
  BuildContext context,
  TaskWeeklyViewModel vm,
  String taskId,
  Date day,
) => showDialog<void>(
  context: context,
  builder: (_) => _WeeklyCellNoteDialog(vm: vm, taskId: taskId, day: day),
);

/// Stateful so the `TextEditingController` is owned by an element and disposed
/// in `State.dispose()` — which runs after `finalizeRoute`. Disposing it after
/// `await showDialog(...)` would race the exit transition: `Route.didPop`
/// resolves that future immediately (routes deliberately "should not wait for
/// their exit animation"), leaving the autofocused field and its live
/// `TextInputConnection` mounted with a disposed controller behind them.
class _WeeklyCellNoteDialog extends StatefulWidget {
  const _WeeklyCellNoteDialog({
    required this.vm,
    required this.taskId,
    required this.day,
  });

  final TaskWeeklyViewModel vm;
  final String taskId;
  final Date day;

  @override
  State<_WeeklyCellNoteDialog> createState() => _WeeklyCellNoteDialogState();
}

class _WeeklyCellNoteDialogState extends State<_WeeklyCellNoteDialog> {
  late final _controller = TextEditingController(
    text: widget.vm.cellDescription(widget.taskId, widget.day),
  );
  late bool _billable = widget.vm.cellBillable(widget.taskId, widget.day);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr('description')),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              maxLines: 3,
              autofocus: true,
              decoration: InputDecoration(
                labelText: context.tr('description'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _billable,
              onChanged: (v) => setState(() => _billable = v),
              title: Text(context.tr('billable')),
            ),
          ],
        ),
      ),
      actions: [
        PrimaryDialogAction(
          label: context.tr('done'),
          autofocus: false,
          showEnterHint: false,
          onPressed: () {
            widget.vm.editCell(
              widget.taskId,
              widget.day,
              description: _controller.text,
              billable: _billable,
            );
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
