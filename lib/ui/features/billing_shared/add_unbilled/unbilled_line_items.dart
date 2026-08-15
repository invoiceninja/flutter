import 'package:decimal/decimal.dart';
import 'package:flutter/widgets.dart';

import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/data/models/domain/billing/line_item_type.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/company_custom_fields.dart';
import 'package:admin/data/models/domain/expense.dart';
import 'package:admin/data/models/domain/group_setting.dart';
import 'package:admin/data/models/domain/project.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/domain/expense_invoice_line_item.dart';
import 'package:admin/domain/tasks/task_invoice_notes.dart';
import 'package:admin/domain/tasks/task_rate.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/utils/formatting.dart';

/// Pure task/expense → [LineItem] conversion for the "Add unbilled items"
/// sheet. Kept free of widgets so it's unit-testable; mirrors admin-portal's
/// `convertTaskToInvoiceItem` / `convertExpenseToInvoiceItem` semantics.

/// The three localized strings the task→line-item conversion needs.
///
/// The converters are pure so they unit-test without a `BuildContext`; every
/// call site sits behind at least one `await` (loading the company, the rate
/// cascade, the picked invoice), so the strings are read up front via
/// [TaskNoteLabels.of] and carried through instead of touching `context`
/// after the gap.
class TaskNoteLabels {
  const TaskNoteLabels({
    required this.hour,
    required this.hours,
    required this.project,
  });

  /// Read the labels synchronously, before any `await`.
  factory TaskNoteLabels.of(BuildContext context) => TaskNoteLabels(
    hour: context.tr('hour'),
    hours: context.tr('hours'),
    project: context.tr('project'),
  );

  final String hour;
  final String hours;

  /// Compared against the company's *product* custom-field labels — a field
  /// literally named "Project" already shows the project, so the header is
  /// suppressed. See [tasksToLineItems].
  final String project;
}

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
  Formatter? formatter,
  bool includeProjectHeader = false,
  String hourLabel = 'hour',
  String hoursLabel = 'hours',
}) {
  // With every Task Setting off (the default) this collapses to the task's
  // own description — the behaviour before the notes builder existed.
  final composed = company == null
      ? task.description.trim()
      : taskInvoiceNotes(
          task,
          company: company,
          formatter: formatter,
          project: project,
          includeProjectHeader: includeProjectHeader,
          now: now,
          hourLabel: hourLabel,
          hoursLabel: hoursLabel,
        );
  final notes = composed.isNotEmpty
      ? composed
      : (task.number.isNotEmpty ? '#${task.number}' : '');
  return emptyLineItem().copyWith(
    notes: notes,
    // "Project Location = Service" — the other half of `invoice_task_project`.
    // When the project isn't going into the description it goes here, into the
    // item/service column (`product_key`). Mirrors v1's `productKey` ternary.
    productKey:
        (company?.invoiceTaskProject ?? false) &&
            !(company?.invoiceTaskProjectHeader ?? false)
        ? (project?.name.trim() ?? '')
        : '',
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
    // The server's own converter copies these across
    // (`ProjectRepository::invoice`), and v1 does too — without them a
    // client-built line drops whatever the task's custom fields held.
    customValue1: task.customValue1,
    customValue2: task.customValue2,
    customValue3: task.customValue3,
    customValue4: task.customValue4,
  );
}

/// Convert a set of tasks that may span **several projects** into line items,
/// grouped so a shared invoice can tell the projects apart.
///
/// An invoice carries one `project_id` and a line item carries none, so the
/// only place the project can be recorded is the first line of each project's
/// run — see [taskInvoiceNotes]. That requires the tasks be clustered by
/// project first, which is what the sort here does (project, then
/// chronologically within it, matching admin-portal's
/// `task_actions.dart:415-435`).
///
/// [alreadyHeadedProjectIds] suppresses the header for projects the target
/// invoice already shows — otherwise appending more of a project's tasks to an
/// invoice that already has some prints a second header mid-document.
List<LineItem> tasksToLineItems(
  List<Task> tasks, {
  Map<String, Project> projectsById = const {},

  /// Used when [projectsById] has no entry for a task's `projectId` — the
  /// single-project callers (Invoice Project / Add project to invoice) already
  /// hold the one project and shouldn't have to depend on the tasks' own FK
  /// being populated.
  Project? fallbackProject,
  Company? company,
  Formatter? formatter,
  Client? client,
  GroupSetting? group,
  DateTime? now,
  Set<String> alreadyHeadedProjectIds = const {},
  String hourLabel = 'hour',
  String hoursLabel = 'hours',
  String projectFieldLabel = 'Project',
}) {
  // Cluster by project, then run chronologically inside each. Ordered by
  // project *name*, not id: the id is a hash, so sorting on it puts the
  // projects in an order that looks random — and disagrees with the Add-items
  // picker, which groups its rows by name. Same selection, same order, whether
  // the user is looking at the picker or the finished document.
  String projectSortKey(Task t) {
    final project = projectsById[t.projectId] ?? fallbackProject;
    final name = project?.name.trim() ?? '';
    // Leading digit orders the buckets: named projects first, then anything
    // unresolved, then the project-less tail — matching the picker, which
    // renders its "No project" group last. The id suffix keeps two projects
    // sharing a name in separate clusters.
    if (name.isNotEmpty) return '0${name.toLowerCase()} ${project!.id}';
    return t.projectId.isEmpty ? '2' : '1${t.projectId}';
  }

  final sorted = [...tasks]
    ..sort((a, b) {
      final byProject = projectSortKey(a).compareTo(projectSortKey(b));
      if (byProject != 0) return byProject;
      return _firstStart(a).compareTo(_firstStart(b));
    });

  // v1 skips the header when a *product* custom field is literally labelled
  // "Project" — that field already carries the project name, so a header would
  // print it twice.
  final headersEnabled =
      (company?.invoiceTaskProject ?? false) &&
      !_hasProjectLabelledProductField(company, projectFieldLabel);

  final seenProjectIds = <String>{...alreadyHeadedProjectIds};
  return <LineItem>[
    for (final task in sorted)
      () {
        final project = projectsById[task.projectId] ?? fallbackProject;
        final headerKey = project?.id ?? task.projectId;
        return taskToLineItem(
          task,
          now: now,
          project: project,
          client: client,
          group: group,
          company: company,
          formatter: formatter,
          hourLabel: hourLabel,
          hoursLabel: hoursLabel,
          includeProjectHeader:
              headersEnabled &&
              project != null &&
              seenProjectIds.add(headerKey),
        );
      }(),
  ];
}

/// Sort key inside a project: the first logged start, falling back to the
/// task's creation time when it has no time entries yet.
DateTime _firstStart(Task task) {
  for (final entry in task.timeLog) {
    final start = entry.start;
    if (start != null) return start;
  }
  return task.createdAt;
}

bool _hasProjectLabelledProductField(Company? company, String projectLabel) {
  if (company == null) return false;
  final needle = projectLabel.trim().toLowerCase();
  if (needle.isEmpty) return false;
  for (var i = 1; i <= 4; i++) {
    if (company.customFieldLabel('product$i').trim().toLowerCase() == needle) {
      return true;
    }
  }
  return false;
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
///
/// [excludedTaskIds] / [excludedExpenseIds] drop rows already present on the
/// target document — required when appending to an *existing* invoice, where
/// re-running the action would otherwise bill the same task twice.
List<LineItem> projectInvoiceLineItems({
  required List<Task> tasks,
  required List<Expense> expenses,
  required bool invoiceInclusive,
  DateTime? now,
  Project? project,
  Client? client,
  GroupSetting? group,
  Company? company,
  Formatter? formatter,
  Set<String> excludedTaskIds = const {},
  Set<String> excludedExpenseIds = const {},
  Set<String> alreadyHeadedProjectIds = const {},
  String hourLabel = 'hour',
  String hoursLabel = 'hours',
  String projectFieldLabel = 'Project',
}) {
  final billableTasks = [
    for (final t in tasks)
      if (!t.id.startsWith('tmp_') &&
          !t.isRunning &&
          !t.isInvoiced &&
          !excludedTaskIds.contains(t.id) &&
          t.billableDuration(now).inSeconds > 0)
        t,
  ];
  return <LineItem>[
    for (final e in expenses)
      if (!e.id.startsWith('tmp_') &&
          e.isPending &&
          !excludedExpenseIds.contains(e.id))
        expenseToLineItem(e, invoiceInclusive: invoiceInclusive),
    ...tasksToLineItems(
      billableTasks,
      fallbackProject: project,
      company: company,
      formatter: formatter,
      client: client,
      // Client's group tier of the rate cascade (was omitted, so
      // group-configured clients billed at the company rate).
      group: group,
      now: now,
      alreadyHeadedProjectIds: alreadyHeadedProjectIds,
      hourLabel: hourLabel,
      hoursLabel: hoursLabel,
      projectFieldLabel: projectFieldLabel,
    ),
  ];
}
