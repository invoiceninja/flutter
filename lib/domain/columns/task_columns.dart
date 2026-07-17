import 'package:flutter/widgets.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/router.dart';
import 'package:admin/data/db/dao/task_dao.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/domain/columns/column_cells.dart';
import 'package:admin/ui/core/widgets/party_money_cell.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/ui/core/widgets/entity_tags_view.dart';
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
  TaskColumn(
    id: TaskFieldIds.updatedAt,
    labelKey: 'last_updated',
    width: 120,
    cellBuilder: (t, ctx) => cellDate(t.updatedAt, ctx),
    valueBuilder: (t) => t.updatedAt.toIso8601String(),
  ),
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
