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
) async {
  final controller = TextEditingController(
    text: vm.cellDescription(taskId, day),
  );
  var billable = vm.cellBillable(taskId, day);

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setLocal) {
          return AlertDialog(
            title: Text(dialogContext.tr('description')),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    maxLines: 3,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: dialogContext.tr('description'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: billable,
                    onChanged: (v) => setLocal(() => billable = v),
                    title: Text(dialogContext.tr('billable')),
                  ),
                ],
              ),
            ),
            actions: [
              PrimaryDialogAction(
                label: dialogContext.tr('done'),
                autofocus: false,
                showEnterHint: false,
                onPressed: () {
                  vm.editCell(
                    taskId,
                    day,
                    description: controller.text,
                    billable: billable,
                  );
                  Navigator.of(dialogContext).pop();
                },
              ),
            ],
          );
        },
      );
    },
  );
  controller.dispose();
}
