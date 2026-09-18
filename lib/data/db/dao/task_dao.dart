import 'package:drift/drift.dart';

import 'package:admin/data/db/dao/_distinct_stream.dart';

import 'package:admin/domain/entity_state.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/base_entity_dao.dart';
import 'package:admin/data/db/dao/entity_query_helpers.dart';
import 'package:admin/data/db/tables/tasks_table.dart';
import 'package:admin/domain/sidebar_badge_modes.dart';

part 'task_dao.g.dart';

/// Stable field-id constants used by the list ViewModel for column +
/// sort selection. Keep in sync with `TaskRepository.watchPage`.
class TaskFieldIds {
  static const String number = 'number';
  static const String description = 'description';
  static const String rate = 'rate';
  static const String clientId = 'client_id';
  static const String projectId = 'project_id';
  static const String taskStatusId = 'task_status_id';
  static const String statusOrder = 'status_order';
  static const String updatedAt = 'updated_at';
  static const String createdAt = 'created_at';
  static const String invoiceId = 'invoice_id';
  static const String isRunning = 'is_running';
  static const String custom1 = 'custom1';
  static const String custom2 = 'custom2';
  static const String custom3 = 'custom3';
  static const String custom4 = 'custom4';

  /// `invoice_id` is non-empty. Derived in SQL, so it sorts.
  static const String isInvoiced = 'is_invoiced';

  /// First time-log entry's start. Derived from the payload — display-only.
  static const String date = 'date';

  /// The day the work is promised for (`tasks.due_date`). Payload-only here —
  /// no Drift column — so display-only, like [date] and `duration`.
  static const String dueDate = 'due_date';

  /// Allocated time in seconds (`tasks.estimated_duration`). Payload-only,
  /// and null on every task created before the field existed, so ordering by
  /// it would move nothing visible on a page — display-only.
  static const String estimatedDuration = 'estimated_duration';

  /// Column id only — the `tasks` table has no `assigned_user_id` column (the
  /// value lives in the payload JSON), so this is never a valid *sort* field.
  /// See the `assigned_user` column in `task_columns.dart`.
  static const String assignedUserId = 'assigned_user_id';

  /// Local approximation of the server's `task_tag_ids|asc` sort — orders by
  /// the denormalized, comma-joined tag names (`tasks.tag_names`).
  static const String tagIds = 'task_tag_ids';

  // ── Standard record metadata ────────────────────────────────────────
  /// Real Drift column (`EntityTimestampColumns`) — sortable.
  static const String archivedAt = 'archived_at';

  /// Real Drift column (`EntityFlagColumns`) — sortable.
  static const String isDeleted = 'is_deleted';

  /// Derived from `archived_at` + `is_deleted`; no column to order by, so the
  /// column is display-only.
  static const String entityState = 'entity_state';

  /// Attachment count, read from the `documents` JSON column. Display-only.
  static const String documents = 'documents';

  /// Creator. Payload-only on every table — display-only.
  static const String userId = 'user_id';
}

@DriftAccessor(tables: [Tasks])
class TaskDao extends BaseEntityDao<$TasksTable, TaskRow> with _$TaskDaoMixin {
  TaskDao(super.db);

  @override
  $TasksTable get table => tasks;
  @override
  GeneratedColumn<String> get idColumn => tasks.id;
  @override
  GeneratedColumn<String> get companyIdColumn => tasks.companyId;
  @override
  GeneratedColumn<bool> get isDeletedColumn => tasks.isDeleted;
  @override
  GeneratedColumn<bool> get isDirtyColumn => tasks.isDirty;

  @override
  GeneratedColumn<int>? get archivedAtColumn => tasks.archivedAt;

  @override
  GeneratedColumn<int>? get updatedAtColumn => tasks.updatedAt;

  @override
  Expression<bool>? badgeModePredicate(
    String modeId, {
    required String companyId,
    required String currentUserId,
  }) => switch (modeId) {
    // Same predicate as `watchRunningCount` — work literally in progress.
    'running' => tasks.isRunning.equals(true),
    // Booked but not started (invoiceninja/flutter#149).
    // `invoice_id = ''` to match `watchBooked`: an invoiced task is
    // server-immutable, so Start is a no-op on it — listing one under a tab
    // whose whole point is "these are startable" is a dead row.
    kBadgeModeUpcoming =>
      tasks.isRunning.equals(false) &
          tasks.invoiceId.equals('') &
          _startsInTheFuture(),
    // Time logged but not yet billed: the backlog to invoice.
    'uninvoiced' => tasks.invoiceId.equals(''),
    // No `assigned_user_id` column on this table — read it out of the payload.
    kBadgeModeAssignedToMe => assignedToUserFilter(currentUserId),
    _ => null,
  };

  /// "The last time-log entry **starts** after now" — the SQL half of
  /// `taskScheduleState`'s `upcoming` arm, and the tab's whole meaning:
  /// *booked ahead*.
  ///
  /// Reads the START, not the stop. `stop > now` looks like the more complete
  /// test and is the one this shipped with — but it also matches every
  /// ordinary forward-looking entry: the weekly grid synthesizes each cell at
  /// local 09:00, so "8" typed into today's column is `09:00–17:00` and sat in
  /// this tab all afternoon. A start in the future is unambiguous — nobody
  /// works in the future — and needs no `due_date` anchor, unlike the
  /// straddling case `_isBooking` has to disambiguate in Dart.
  ///
  /// The accepted cost is that a job whose slot is live *right now* is not in
  /// this tab; it surfaces on its own row (`Now`, warning-toned) and on the
  /// shell's "Due now" pill instead.
  ///
  /// Reads the **last** entry because the log is sorted by start on every save
  /// (`TaskRepository::save` server-side, `TaskRepository.save` here), so
  /// `\$[#-1][0]` is the greatest start — a far weaker premise than the max-stop
  /// one this replaces, which `roundTimeLog` could violate.
  ///
  /// **The nested `CASE` is load-bearing.** `TaskTransformer` emits
  /// `time_log: ''` for a task with no entries, and SQLite does not guarantee
  /// short-circuit evaluation of scalar functions — so `json_valid(x) AND
  /// json_extract(x, …)` in one condition can still raise `malformed JSON` and
  /// abort the whole list query. Nesting makes the guard structural.
  ///
  /// `now` is baked in when the stream is built, the same staleness every
  /// date-sensitive badge mode carries (CLAUDE.md § Sidebar counters),
  /// truncated to the minute so the badge's stream and the list's — built at
  /// different moments — agree unless a booking begins between them.
  Expression<bool> _startsInTheFuture() {
    final now = DateTime.now();
    final nowSeconds =
        DateTime(
          now.year,
          now.month,
          now.day,
          now.hour,
          now.minute,
        ).millisecondsSinceEpoch ~/
        1000;
    // `\$` is an escaped dollar: these are SQLite JSON paths, not Dart
    // interpolation. `\$nowSeconds` alone is interpolated.
    return CustomExpression<bool>(
      'CASE WHEN json_valid(payload) THEN '
      "CASE WHEN json_valid(json_extract(payload, '\$.time_log')) THEN "
      "CAST(json_extract(json_extract(payload, '\$.time_log'), "
      "'\$[#-1][0]') AS INTEGER) END END > $nowSeconds",
    );
  }

  Stream<List<TaskRow>> watchPage({
    required String companyId,
    required int offset,
    required int limit,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    String sortField = TaskFieldIds.updatedAt,
    bool sortAscending = false,
    String? clientId,
    String? projectId,
    Set<String> clientIds = const {},
    Set<String> statusIds = const {},
    Set<String> projectIds = const {},
    Set<String> customValues1 = const {},
    Set<String> customValues2 = const {},
    Set<String> customValues3 = const {},
    Set<String> customValues4 = const {},
    String? badgeModeId,
  }) {
    final q = select(tasks)..where((t) => t.companyId.equals(companyId));
    // Status-tab strip (#98): the SAME predicate the tab's count uses, so
    // the number above the list and the rows in it can't disagree. Applied
    // here (pre-LIMIT) rather than post-decode, so the Drift window stays
    // aligned with the page count.
    final badgeFilter = badgeModeListFilter(badgeModeId, companyId: companyId);
    if (badgeFilter != null) q.where((_) => badgeFilter);

    if (clientId != null && clientId.isNotEmpty) {
      q.where((t) => t.clientId.equals(clientId));
    }
    // `client_id` membership mirror — the standalone list's `client:` chips,
    // distinct from the single embedded [clientId] lock above. Without it the
    // chip narrows the server page but the local watch still returns every
    // cached row, so the list looks unfiltered.
    if (clientIds.isNotEmpty) {
      q.where((t) => t.clientId.isIn(clientIds.toList()));
    }
    // Workspace list: hide rows of soft-deleted clients (offline parity with
    // the server `without_deleted_clients` filter). Suppressed under an explicit
    // client scope; client-less tasks (empty client_id) are preserved.
    if (clientId == null || clientId.isEmpty) {
      q.where(
        (t) =>
            clientNotDeletedFilter(clientId: t.clientId, companyId: companyId),
      );
    }
    // Project-scoped embedded list (Project detail tab). Single FK equals,
    // in-memory only — not forwarded as a server filter.
    if (projectId != null && projectId.isNotEmpty) {
      q.where((t) => t.projectId.equals(projectId));
    }
    // `task_status` membership mirror. The server pairs this filter with
    // `whereNull(invoice_id)` (uninvoiced tasks only — TaskFilters::
    // task_status), so mirror that too or the local window diverges from the
    // server's filtered pages.
    if (statusIds.isNotEmpty) {
      q.where(
        (t) => t.taskStatusId.isIn(statusIds.toList()) & t.invoiceId.equals(''),
      );
    }
    // `project_tasks` membership mirror (the standalone list's `project:`
    // chips) — distinct from the single embedded [projectId] lock above.
    if (projectIds.isNotEmpty) {
      q.where((t) => t.projectId.isIn(projectIds.toList()));
    }
    // Custom-field filters mirror server `custom_value1..4` (exact-set local
    // predicate is source of truth — same idiom as ClientDao/InvoiceDao).
    if (customValues1.isNotEmpty) {
      q.where((t) => t.customValue1.isIn(customValues1.toList()));
    }
    if (customValues2.isNotEmpty) {
      q.where((t) => t.customValue2.isIn(customValues2.toList()));
    }
    if (customValues3.isNotEmpty) {
      q.where((t) => t.customValue3.isIn(customValues3.toList()));
    }
    if (customValues4.isNotEmpty) {
      q.where((t) => t.customValue4.isIn(customValues4.toList()));
    }

    if (states.isNotEmpty) {
      q.where(
        (t) => entityStateFilter(
          states: states,
          archivedAt: t.archivedAt,
          isDeleted: t.isDeleted,
        ),
      );
    }

    if (search != null && search.isNotEmpty) {
      final needle = '%${search.toLowerCase()}%';
      // Mirror the server's `TaskFilters::filter` field set so API matches
      // aren't filtered back out by the local watch (number, description,
      // custom_value1-4, client name, project name). `time_log` and client
      // contacts stay server-only.
      q.where(
        (t) =>
            t.taskNumber.lower().like(needle) |
            t.description.lower().like(needle) |
            t.customValue1.lower().like(needle) |
            t.customValue2.lower().like(needle) |
            t.customValue3.lower().like(needle) |
            t.customValue4.lower().like(needle) |
            clientNameMatchesFilter(
              clientId: t.clientId,
              companyId: companyId,
              needle: needle,
            ) |
            projectNameMatchesFilter(
              projectId: t.projectId,
              companyId: companyId,
              needle: needle,
            ),
      );
    }

    q.orderBy([
      (t) => OrderingTerm(
        expression: _sortExpression(t, sortField),
        mode: sortAscending ? OrderingMode.asc : OrderingMode.desc,
      ),
      (t) => OrderingTerm(expression: t.id),
    ]);

    q.limit(limit, offset: offset);
    return q.watch().distinctRows();
  }

  Expression _sortExpression(Tasks t, String field) {
    switch (field) {
      case TaskFieldIds.number:
        return t.taskNumber.lower();
      case TaskFieldIds.description:
        return t.description.lower();
      case TaskFieldIds.rate:
        return t.rate.cast<double>();
      case TaskFieldIds.clientId:
        return t.clientId;
      case TaskFieldIds.projectId:
        return t.projectId;
      case TaskFieldIds.taskStatusId:
        return t.taskStatusId;
      case TaskFieldIds.statusOrder:
        return t.statusOrder;
      case TaskFieldIds.tagIds:
        return t.tagNames;
      case TaskFieldIds.updatedAt:
        return t.updatedAt;
      case TaskFieldIds.createdAt:
        return t.createdAt;
      case TaskFieldIds.invoiceId:
        return t.invoiceId;
      // "Has an invoice", ordered as a boolean so the two buckets group.
      case TaskFieldIds.isInvoiced:
        return t.invoiceId.equals('').not();
      case TaskFieldIds.isRunning:
        return t.isRunning;
      case TaskFieldIds.custom1:
        return t.customValue1.lower();
      case TaskFieldIds.custom2:
        return t.customValue2.lower();
      case TaskFieldIds.custom3:
        return t.customValue3.lower();
      case TaskFieldIds.custom4:
        return t.customValue4.lower();
      case TaskFieldIds.archivedAt:
        return t.archivedAt;
      case TaskFieldIds.isDeleted:
        return t.isDeleted;
      default:
        // Silent fallback would mask real failures — see expense_dao.dart for
        // the rationale. It also blinded `sortable_columns_test`, which detects
        // an unmapped column by catching this throw: `duration` shipped with a
        // live sort arrow that quietly ordered by `updated_at`.
        throw ArgumentError(
          'Unknown sort field "$field" for Task — add a case in '
          '_sortExpression or stop exposing it as a sort option.',
        );
    }
  }

  /// Watch every active+non-deleted task for a company, sorted by
  /// `(status_order ASC, updated_at DESC)`. The repository groups by
  /// `task_status_id` in Dart for the kanban board.
  Stream<List<TaskRow>> watchAllForKanban({
    required String companyId,
    Set<EntityState> states = const {EntityState.active},
  }) {
    final q = select(tasks)..where((t) => t.companyId.equals(companyId));
    if (states.isNotEmpty) {
      q.where(
        (t) => entityStateFilter(
          states: states,
          archivedAt: t.archivedAt,
          isDeleted: t.isDeleted,
        ),
      );
    }
    q.orderBy([
      (t) => OrderingTerm(expression: t.statusOrder),
      (t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc),
      (t) => OrderingTerm(expression: t.id),
    ]);
    return q.watch().distinctRows();
  }

  /// Watch the single most-recently-updated running task for the company.
  /// O(1) thanks to the denormalized `is_running` column. Backs the global
  /// running-timer pill.
  Stream<TaskRow?> watchRunning({required String companyId}) {
    final q = select(tasks)
      ..where(
        (t) =>
            t.companyId.equals(companyId) &
            t.isRunning.equals(true) &
            t.isDeleted.equals(false),
      )
      ..orderBy([
        (t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc),
      ])
      ..limit(1);
    return q.watchSingleOrNull();
  }

  /// Active tasks holding an unfinished booking, with no timer running —
  /// the candidate set for the shell pill's "Due now".
  ///
  /// Returns the whole (small) set rather than the one row the pill shows,
  /// because "is the clock inside this block?" needs `taskScheduleState`, and
  /// that is Dart: the SQL half can only answer "does a block end after now",
  /// which is also true of a job booked for next Tuesday. Capped so a company
  /// that books months ahead can't hand the shell a thousand rows to decode.
  Stream<List<TaskRow>> watchBooked({required String companyId}) {
    final q = select(tasks)
      ..where(
        (t) =>
            t.companyId.equals(companyId) &
            t.isRunning.equals(false) &
            t.isDeleted.equals(false) &
            t.archivedAt.isNull() &
            t.invoiceId.equals('') &
            _startsInTheFuture(),
      )
      // DESC: the cap keeps the 50 most recently touched booked tasks. Ascending
      // threw away the job the user had just booked, which is the one the pill
      // exists to surface.
      ..orderBy([
        (t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc),
      ])
      ..limit(50);
    return q.watch().distinctRows();
  }

  /// Live count of running (non-deleted) timers for the company. Backs the
  /// global pill's "N running" affordance so concurrent timers stay visible
  /// even though [watchRunning] surfaces only the most-recent one.
  Stream<int> watchRunningCount({required String companyId}) {
    final count = tasks.id.count();
    final q = selectOnly(tasks)
      ..addColumns([count])
      ..where(
        tasks.companyId.equals(companyId) &
            tasks.isRunning.equals(true) &
            tasks.isDeleted.equals(false),
      );
    return q.map((row) => row.read(count) ?? 0).watchSingle();
  }

  /// Ids of every running (non-deleted) timer for the company — backs the
  /// pill's "Stop all".
  Future<List<String>> runningTaskIds({required String companyId}) {
    final q = selectOnly(tasks)
      ..addColumns([tasks.id])
      ..where(
        tasks.companyId.equals(companyId) &
            tasks.isRunning.equals(true) &
            tasks.isDeleted.equals(false),
      );
    return q.map((row) => row.read(tasks.id)!).get();
  }

  /// Active, non-deleted tasks belonging to one project. Used by the
  /// Project detail's Tasks card. Excludes archived rows — they belong on
  /// the parent Task list, not in a project's overview.
  Stream<List<TaskRow>> watchForProject({
    required String companyId,
    required String projectId,
  }) {
    final q = select(tasks)
      ..where(
        (t) =>
            t.companyId.equals(companyId) &
            t.projectId.equals(projectId) &
            t.isDeleted.equals(false) &
            t.archivedAt.isNull(),
      )
      ..orderBy([
        (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
        (t) => OrderingTerm(expression: t.id),
      ]);
    return q.watch().distinctRows();
  }

  /// One-shot batch read by id. Used by the reorder path so a single
  /// query replaces N `watchById(...).first` subscriptions inside a
  /// transaction. Empty input returns an empty list.
  Future<List<TaskRow>> getByIds({
    required String companyId,
    required Iterable<String> ids,
  }) {
    final list = ids.toList(growable: false);
    if (list.isEmpty) return Future.value(const <TaskRow>[]);
    final q = select(tasks)
      ..where((t) => t.companyId.equals(companyId) & t.id.isIn(list));
    return q.get();
  }
}
