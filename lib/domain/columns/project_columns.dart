import 'package:admin/app/router.dart';
import 'package:admin/data/db/dao/project_dao.dart';
import 'package:admin/data/models/domain/project.dart';
import 'package:admin/domain/columns/column_cells.dart';
import 'package:admin/ui/core/widgets/party_money_cell.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/ui/core/widgets/client_name_label.dart';
import 'package:admin/ui/core/widgets/entity_tags_view.dart';
import 'package:admin/ui/core/widgets/user_name_label.dart';

typedef ProjectColumn = ColumnDefinition<Project>;

const List<String> kDefaultProjectColumns = <String>[
  ProjectFieldIds.name,
  ProjectFieldIds.clientId,
  ProjectFieldIds.dueDate,
  ProjectFieldIds.budgetedHours,
  ProjectFieldIds.currentHours,
  ProjectFieldIds.taskRate,
  ProjectFieldIds.updatedAt,
];

final List<ProjectColumn> kAllProjectColumns = <ProjectColumn>[
  ProjectColumn(
    id: ProjectFieldIds.name,
    labelKey: 'name',
    cellBuilder: (p, _) => cellText(p.name, bold: true),
    valueBuilder: (p) => cellNonZeroString(p.name),
  ),
  ProjectColumn(
    id: ProjectFieldIds.number,
    labelKey: 'number',
    width: 120,
    cellBuilder: (p, ctx) => cellLink(
      ctx,
      p.number,
      onTap: () => goEntityFullDetail(ctx, '/projects', p.id),
    ),
    valueBuilder: (p) => cellNonZeroString(p.number),
  ),
  ProjectColumn(
    id: ProjectFieldIds.clientId,
    labelKey: 'client',
    width: 180,
    // Subscribes to `services.clients.watch` and falls back to the raw
    // id while the watch is empty — same pattern as the Task list.
    cellBuilder: (p, _) => p.clientId.isEmpty
        ? cellEmpty()
        : ClientNameLabel(clientId: p.clientId, link: true),
    valueBuilder: (p) => cellNonZeroString(p.clientId),
  ),
  ProjectColumn(
    id: ProjectFieldIds.assignedUserId,
    labelKey: 'assigned_user',
    width: 160,
    // Resolve the assigned-user id to a display name from the local roster
    // (seeded via UserRepository.applyBundle); raw id fallback while empty.
    cellBuilder: (p, _) => p.assignedUserId.isEmpty
        ? cellEmpty()
        : UserNameLabel(userId: p.assignedUserId),
    valueBuilder: (p) => cellNonZeroString(p.assignedUserId),
  ),
  ProjectColumn(
    id: ProjectFieldIds.dueDate,
    labelKey: 'due_date',
    width: 120,
    // `cellDate` formats via the active locale's medium date pattern.
    // Threading the company's `Formatter.date` through column cells is
    // out of scope for this PR (would require changing ColumnDefinition's
    // signature); locale-aware formatting is the closest correct thing.
    cellBuilder: (p, ctx) => p.dueDate == null
        ? cellEmpty()
        : cellDate(p.dueDate!.toDateTime(), ctx),
    valueBuilder: (p) => p.dueDate?.toIso(),
  ),
  ProjectColumn(
    id: ProjectFieldIds.budgetedHours,
    labelKey: 'budgeted_hours',
    width: 140,
    align: ColumnAlign.end,
    cellBuilder: (p, _) => p.budgetedHours == 0
        ? cellEmpty()
        : cellText(_formatHours(p.budgetedHours)),
    valueBuilder: (p) =>
        p.budgetedHours == 0 ? null : p.budgetedHours.toString(),
  ),
  ProjectColumn(
    id: ProjectFieldIds.currentHours,
    labelKey: 'current_hours',
    width: 140,
    align: ColumnAlign.end,
    cellBuilder: (p, _) => p.currentHours == 0
        ? cellEmpty()
        : cellText(_formatHours(p.currentHours)),
    valueBuilder: (p) => p.currentHours == 0 ? null : p.currentHours.toString(),
  ),
  ProjectColumn(
    id: ProjectFieldIds.taskRate,
    labelKey: 'task_rate',
    width: 120,
    align: ColumnAlign.end,
    // Task rate is a per-client rate — format in the client's currency, not
    // the company's (matches invoices/quotes and legacy).
    cellBuilder: (p, context) =>
        cellPartyMoney(p.taskRate, context, clientId: p.clientId),
    valueBuilder: (p) => cellMoneyValue(p.taskRate),
  ),
  ProjectColumn(
    id: ProjectFieldIds.updatedAt,
    labelKey: 'last_updated',
    width: 120,
    cellBuilder: (p, ctx) => cellDate(p.updatedAt, ctx),
    valueBuilder: (p) => p.updatedAt.toIso8601String(),
  ),
  // Default-off — opt-in via the column picker. Header sort orders by the
  // denormalized `tag_names` column.
  ProjectColumn(
    id: ProjectFieldIds.tagIds,
    labelKey: 'tags',
    width: 200,
    cellBuilder: (p, _) => p.tagIds.isEmpty
        ? cellEmpty()
        : EntityTagsView(entityType: 'project', tagIds: p.tagIds),
    // No copy value — see the Tasks tags column.
    valueBuilder: (p) => '',
  ),
];

final Map<String, ProjectColumn> projectColumnsById = {
  for (final c in kAllProjectColumns) c.id: c,
};

String _formatHours(double h) {
  // Drop trailing .0 for whole-number hours; one decimal otherwise.
  final asInt = h.truncate();
  if (asInt.toDouble() == h) return '$asInt h';
  return '${h.toStringAsFixed(1)} h';
}
