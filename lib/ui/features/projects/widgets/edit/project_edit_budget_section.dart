import 'package:flutter/material.dart';

import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/edit/entity_edit_field.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/ui/features/projects/view_models/project_edit_view_model.dart';
import 'package:admin/utils/formatting.dart';

/// Budgeted hours + budgeted amount + task rate. All numeric; render empty
/// for zero so the user isn't editing around a stray `0`.
///
/// `budgeted_amount` is an optional money budget independent of the hours
/// one — the server's project charts fall back to `budgeted_hours × task_rate`
/// when it is zero, so leaving it blank keeps the previous behavior.
class ProjectEditBudgetSection extends StatelessWidget {
  const ProjectEditBudgetSection({super.key, required this.vm});
  final ProjectEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    final budget = vm.draft.budgetedHours;
    final budgetText = budget == 0 ? '' : _formatHours(budget);
    return DashboardCardShell(
      title: context.tr('budget'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          EntityEditField(
            label: context.tr('budgeted_hours'),
            initial: budgetText,
            onChanged: vm.setBudgetedHours,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            errorText: vm.fieldErrorFor('budgeted_hours'),
          ),
          EntityEditField(
            label: context.tr('budgeted_amount'),
            initial: decimalInputText(vm.draft.budgetedAmount),
            onChanged: vm.setBudgetedAmount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            errorText: vm.fieldErrorFor('budgeted_amount'),
          ),
          EntityEditField(
            label: context.tr('task_rate'),
            initial: decimalInputText(vm.draft.taskRate),
            onChanged: vm.setTaskRate,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            errorText: vm.fieldErrorFor('task_rate'),
          ),
        ],
      ),
    );
  }
}

String _formatHours(double h) {
  if (h.truncate().toDouble() == h) return h.toInt().toString();
  return h.toStringAsFixed(1);
}
