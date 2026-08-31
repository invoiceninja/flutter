import 'package:flutter/widgets.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/router.dart';
import 'package:admin/data/db/dao/task_dao.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/domain/columns/column_cells.dart';
import 'package:admin/ui/core/widgets/party_money_cell.dart';
import 'package:admin/domain/columns/column_factories.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/domain/columns/custom_field_columns.dart';
import 'package:admin/ui/core/widgets/invoice_name_label.dart';
import 'package:admin/ui/core/widgets/entity_tags_view.dart';
import 'package:admin/ui/core/widgets/user_name_label.dart';
import 'package:admin/ui/features/projects/widgets/project_name_label.dart';
import 'package:admin/ui/core/widgets/client_name_label.dart';
import 'package:admin/ui/features/tasks/widgets/running_duration_label.dart';
import 'package:admin/ui/features/tasks/widgets/task_status_pill.dart';
import 'package:admin/utils/formatting.dart';

typedef TaskColumn = ColumnDefinition<Task>;

// Out-of-box columns mirror admin-portal / React (status, number, client,
// description, duration) so the wide table is useful without configuration;
// rate / project / etc. stay flippable via the column picker.
const List<String> kDefaultTaskColumns = <String>[
  TaskFieldIds.taskStatusId,
  TaskFieldIds.number,
  TaskFieldIds.clientId,
  TaskFieldIds.description,
  'duration',
  TaskFieldIds.updatedAt,
];

final List<TaskColumn> kAllTaskColumns = <TaskColumn>[
  TaskColumn(
    id: TaskFieldIds.number,
    labelKey: 'number',
    width: 120,
    cellBuilder: (t, ctx) => cellLink(
      ctx,
      t.number,
      bold: true,
      onTap: () => goEntityFullDetail(ctx, '/tasks', t.id),
    ),
    valueBuilder: (t) => cellNonZeroString(t.number),
  ),
  TaskColumn(
    id: TaskFieldIds.description,
    labelKey: 'description',
    cellBuilder: (t, _) => cellText(t.description),
    valueBuilder: (t) => cellNonZeroString(t.description),
  ),
  TaskColumn(
    id: TaskFieldIds.clientId,
    labelKey: 'client',
    width: 180,
    // Subscribes to `services.clients.watch` and falls back to the raw
    // id while the watch is empty — see `ClientNameLabel`.
    cellBuilder: (t, _) => t.clientId.isEmpty
        ? cellEmpty()
        : ClientNameLabel(clientId: t.clientId, link: true),
    valueBuilder: (t) => cellNonZeroString(t.clientId),
  ),
  // Default-off — Tasks already shows Client by default, and surfacing
  // Project too clutters the wide table for the majority of users who
  // don't use Projects. Flippable via the column picker.
  TaskColumn(
    id: TaskFieldIds.projectId,
    labelKey: 'project',
    width: 180,
    cellBuilder: (t, _) => t.projectId.isEmpty
        ? cellEmpty()
        : ProjectNameLabel(projectId: t.projectId, link: true),
    valueBuilder: (t) => cellNonZeroString(t.projectId),
  ),
  TaskColumn(
    id: TaskFieldIds.rate,
    labelKey: 'rate',
    width: 120,
    align: ColumnAlign.end,
    // Task rate is a per-client rate — format in the client's currency.
    cellBuilder: (t, context) =>
        cellPartyMoney(t.rate, context, clientId: t.clientId),
    valueBuilder: (t) => cellMoneyValue(t.rate),
  ),
  TaskColumn(
    id: 'duration',
    labelKey: 'duration',
    width: 120,
    align: ColumnAlign.end,
    // Derived from `time_log` (and ticks live while a timer runs) — there is
    // no column or payload key to order by, so `TaskDao._sortExpression` fell
    // through to its silent `updated_at` default: the header showed a sort
    // arrow and the rows didn't move.
    sortable: false,
    // Ticks live + accent while a timer runs — this is the row's primary
    // running signal now that the trailing slot is an icon-only toggle. The
    // `base` (sum of already-stopped entries) makes it tick the full
    // cumulative TOTAL, a smooth continuation of the static total rather
    // than a reset to 0. `loggedDuration(runningStart)` yields exactly that
    // sum: the running entry's `durationUpTo(runningStart)` collapses to 0.
    cellBuilder: (t, ctx) => (t.isRunning && t.timeLog.isNotEmpty)
        ? RunningDurationLabel(
            start: t.timeLog.last.start!,
            base: t.loggedDuration(t.timeLog.last.start!),
            precision: const Duration(seconds: 1),
            showDot: false,
            style: TextStyle(
              color: ctx.inTheme.accent,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          )
        : cellText(formatDuration(t.loggedDuration(), compactDays: true)),
    valueBuilder: (t) => formatDuration(t.loggedDuration(), compactDays: true),
  ),
  TaskColumn(
    id: TaskFieldIds.taskStatusId,
    labelKey: 'status',
    width: 140,
    // Subscribes to `services.taskStatuses.watch` — renders the color
    // dot + name. Falls back to the raw id while the watch is empty.
    cellBuilder: (t, _) =>
        t.statusId.isEmpty ? cellEmpty() : TaskStatusPill(statusId: t.statusId),
    valueBuilder: (t) => cellNonZeroString(t.statusId),
  ),
  // Default-off — the row's leading avatar already carries the at-a-glance
  // signal; this column is for when the user wants the name spelled out.
  TaskColumn(
    id: TaskFieldIds.assignedUserId,
    labelKey: 'assigned_user',
    width: 160,
    // Unlike Projects / Invoices / Quotes, the `tasks` table has no
    // `assigned_user_id` column — the value is read out of the payload JSON
    // (`BaseEntityDao.assignedToUserFilter`), so `TaskDao._sortExpression` has
    // no case for it and would throw the moment the header was clicked. A real
    // column would cost a schema bump + forward migration to buy ordering by
    // hashed id, which nobody wants. Same reasoning as `duration` above.
    sortable: false,
    // Resolves the id against the local roster (seeded by
    // `UserRepository.applyBundle`); muted em-dash for an id it can't resolve.
    cellBuilder: (t, _) => t.assignedUserId.isEmpty
        ? cellEmpty()
        : UserNameLabel(userId: t.assignedUserId),
    valueBuilder: (t) => cellNonZeroString(t.assignedUserId),
  ),
  colUpdatedAt<Task>(TaskFieldIds.updatedAt, (t) => t.updatedAt),
  // Linked invoice — real `invoice_id` column, so both this and the derived
  // "is invoiced" flag sort.
  TaskColumn(
    id: TaskFieldIds.invoiceId,
    labelKey: 'invoice',
    width: 160,
    cellBuilder: (t, _) => t.invoiceId.isEmpty
        ? cellEmpty()
        : InvoiceNameLabel(invoiceId: t.invoiceId, link: true),
    valueBuilder: (t) => cellNonZeroString(t.invoiceId),
  ),
  colFlag<Task>(
    TaskFieldIds.isInvoiced,
    (t) => t.isInvoiced,
    labelKey: 'is_invoiced',
  ),
  colFlag<Task>(
    TaskFieldIds.isRunning,
    (t) => t.isRunning,
    labelKey: 'is_running',
  ),
  // The first logged entry's start date. Derived from `time_log` in the
  // payload — no column to order by, like `duration` above.
  TaskColumn(
    id: TaskFieldIds.date,
    labelKey: 'date',
    width: 120,
    sortable: false,
    cellBuilder: (t, ctx) {
      final start = _firstStart(t);
      return start == null ? cellEmpty() : cellDate(start, ctx);
    },
    valueBuilder: (t) => _firstStart(t)?.toIso8601String(),
  ),
  // The company's own labels ('Region'), type-aware values and the hiding
  // of unconfigured slots are applied by `decorateCustomFieldColumns`.
  ...customFieldColumns<Task>(
    prefix: 'task',
    ids: const [
      TaskFieldIds.custom1,
      TaskFieldIds.custom2,
      TaskFieldIds.custom3,
      TaskFieldIds.custom4,
    ],
    values: [
      (t) => t.customValue1,
      (t) => t.customValue2,
      (t) => t.customValue3,
      (t) => t.customValue4,
    ],
  ),
  // ── Standard record metadata ──────────────────────────────────────────
  // Shared across every entity list; see `column_factories.dart`. Created /
  // archived / deleted are real Drift columns and sort; state, documents and
  // the two user columns are derived or payload-only and don't.
  colCreatedAt<Task>(TaskFieldIds.createdAt, (t) => t.createdAt),
  colArchivedAt<Task>(TaskFieldIds.archivedAt, (t) => t.archivedAt),
  colEntityState<Task>(
    TaskFieldIds.entityState,
    archivedAt: (t) => t.archivedAt,
    isDeleted: (t) => t.isDeleted,
  ),
  colFlag<Task>(
    TaskFieldIds.isDeleted,
    (t) => t.isDeleted,
    labelKey: 'is_deleted',
  ),
  colDocumentsCount<Task>(TaskFieldIds.documents, (t) => t.documents.length),
  // Created by. `labelKey: 'user'` — NOT `created_by`, which is
  // "Created by :name" and would leak the raw placeholder.
  colUserName<Task>(TaskFieldIds.userId, (t) => t.userId, labelKey: 'user'),
  // Default-off (not in kDefaultTaskColumns) — opt-in via the column picker.
  // Header sort orders by the denormalized `tag_names` column.
  TaskColumn(
    id: TaskFieldIds.tagIds,
    labelKey: 'tags',
    width: 200,
    cellBuilder: (t, _) => t.tagIds.isEmpty
        ? cellEmpty()
        : EntityTagsView(entityType: 'task', tagIds: t.tagIds),
    // No copy value — names aren't resolvable synchronously here, and copying
    // raw hashed ids isn't useful. '' suppresses the hover-copy affordance.
    valueBuilder: (t) => '',
  ),
];

final Map<String, TaskColumn> taskColumnsById = {
  for (final c in kAllTaskColumns) c.id: c,
};

/// The task's own date: when the first logged entry started. `time_log` is
/// stored oldest-first, and an entry with no start round-trips as null (see
/// `TimeEntry.parseLog`), so this is the first entry that actually has one.
DateTime? _firstStart(Task t) {
  for (final entry in t.timeLog) {
    if (entry.start != null) return entry.start;
  }
  return null;
}
