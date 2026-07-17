import 'package:decimal/decimal.dart';

import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/data/models/domain/billing/line_item_type.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/expense.dart';
import 'package:admin/data/models/domain/group_setting.dart';
import 'package:admin/data/models/domain/project.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/domain/expense_invoice_line_item.dart';
import 'package:admin/domain/tasks/task_rate.dart';

/// Pure task/expense → [LineItem] conversion for the "Add unbilled items"
/// sheet. Kept free of widgets so it's unit-testable; mirrors admin-portal's
/// `convertTaskToInvoiceItem` / `convertExpenseToInvoiceItem` semantics.

/// Billable time-log hours, 3-decimal `Decimal`. Falls back to `1` when the
/// task has no logged time so the appended row is a sane editable default
/// rather than a zero-quantity ghost.
Decimal taskBillableHours(Task task, {DateTime? now}) {
  final seconds = task.billableDuration(now).inSeconds;
  if (seconds <= 0) return Decimal.one;
  return Decimal.parse((seconds / 3600).toStringAsFixed(3));
}

LineItem taskToLineItem(
  Task task, {
  DateTime? now,
  Project? project,
  Client? client,
  GroupSetting? group,
  Company? company,
}) {
  final notes = task.description.trim().isNotEmpty
      ? task.description.trim()
      : (task.number.isNotEmpty ? '#${task.number}' : '');
  return emptyLineItem().copyWith(
    notes: notes,
    // task → project → client → group → company rate cascade. Falls back to
    // `task.rate` when no related entities are passed (no regression).
    cost: resolveTaskRate(
      task: task,
      project: project,
      client: client,
      group: group,
      company: company,
    ),
    quantity: taskBillableHours(task, now: now),
    typeId: LineItemType.task,
    taskId: task.id,
  );
}

LineItem expenseToLineItem(Expense expense, {required bool invoiceInclusive}) {
  final notes = expense.publicNotes.trim().isNotEmpty
      ? expense.publicNotes.trim()
      : (expense.number.isNotEmpty ? '#${expense.number}' : '');
  // Delegate the money math to the canonical converter so the billed cost
  // honors the TARGET DOC's inclusive/exclusive tax mode (gross when the
  // doc extracts tax from the line, net when it adds tax on top) plus the
  // currency conversion and by-amount-tax rules. Billing the raw amount
  // with the raw rates overbilled an inclusive-tax expense by its full VAT
  // on an exclusive invoice (and underbilled the reverse) — diverging from
  // the Expense "Add to invoice" action, which already used the canonical
  // path.
  return expenseInvoiceLineItem(
    expense,
    invoiceInclusive: invoiceInclusive,
  ).copyWith(notes: notes);
}

/// Line items for the "Invoice Project" action: pending (uninvoiced, billable)
/// project expenses first, then stopped + uninvoiced tasks that have logged
/// billable time — mirroring admin-portal's project→invoice conversion. Skips
/// unsynced (`tmp_`) rows. Callers pass the project's active tasks/expenses
/// (e.g. via `watchForProject`, which already excludes archived/deleted).
List<LineItem> projectInvoiceLineItems({
  required List<Task> tasks,
  required List<Expense> expenses,
  required bool invoiceInclusive,
  DateTime? now,
  Project? project,
  Client? client,
  GroupSetting? group,
  Company? company,
}) {
  return <LineItem>[
    for (final e in expenses)
      if (!e.id.startsWith('tmp_') && e.isPending)
        expenseToLineItem(e, invoiceInclusive: invoiceInclusive),
    for (final t in tasks)
      if (!t.id.startsWith('tmp_') &&
          !t.isRunning &&
          !t.isInvoiced &&
          t.billableDuration(now).inSeconds > 0)
        taskToLineItem(
          t,
          now: now,
          project: project,
          client: client,
          // Client's group tier of the rate cascade (was omitted, so
          // group-configured clients billed at the company rate).
          group: group,
          company: company,
        ),
  ];
}
