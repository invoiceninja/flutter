import 'package:logging/logging.dart';

import 'package:admin/data/db/dao/task_dao.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/repositories/base_entity_repository.dart';
import 'package:admin/domain/sidebar_badge_modes.dart';
import 'package:admin/domain/tasks/task_schedule.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/repositories/task_repository.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/domain/columns/task_columns.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/core/list/standard_crud_bulk_actions.dart';

final _log = Logger('TaskListViewModel');

/// List ViewModel for the Tasks screen (list view only — the kanban board
/// has its own `KanbanViewModel` + `TaskFiltersMixin` state and does not
/// share this VM's filter chips).
class TaskListViewModel extends GenericListViewModel<Task> {
  TaskListViewModel({
    required this.repo,
    required super.companyId,
    required super.navStateDao,
    required super.userSettings,
    super.savedViews,
    super.searchDebounce,
    super.persistDebounce,
    super.now,
    this.clientId,
    this.projectId,
  });

  final TaskRepository repo;

  /// When non-null, scopes the watch + fetch to one client.
  final String? clientId;

  /// When non-null, scopes the watch + fetch to one project. Used by the
  /// embedded list inside `ProjectDetailScreen`'s Tasks tab.
  final String? projectId;

  @override
  Set<String> get lockedFilterKeyIds => {
    if (clientId != null) 'client',
    if (projectId != null) 'project',
  };

  @override
  EntityType get entityType => EntityType.task;

  @override
  List<ColumnDefinition<Task>> get allColumns => kAllTaskColumns;

  @override
  List<String> get defaultColumnIds => kDefaultTaskColumns;

  @override
  String get defaultSortField => TaskFieldIds.updatedAt;

  /// Newest first: last-updated ascending would bury every new record at the
  /// bottom of the list, off the first page.
  @override
  bool get defaultSortAscending => false;

  @override
  bool isValidColumnId(String field) =>
      isSortableColumnId(taskColumnsById, field) ||
      field == TaskFieldIds.updatedAt;

  @override
  String idOf(Task item) => item.id;

  @override
  bool isArchived(Task item) => item.archivedAt != null;

  @override
  bool isDeleted(Task item) => item.isDeleted;

  @override
  Stream<List<Task>> watchPage() => repo.watchPage(
    badgeModeId: activeBadgeModeId,
    companyId: companyId,
    loadedPages: loadedPages,
    search: search.isEmpty ? null : search,
    states: states,
    sortField: sortField,
    sortAscending: sortAscending,
    clientId: clientId,
    projectId: projectId,
    extraFilters: extraFilters,
    customFilters: customFilters,
  );

  @override
  int get pageSize => repo.pageSize;

  @override
  Future<bool> fetchPage({
    required int page,
    required String? search,
    required Set<EntityState> states,
    required Map<String, Set<String>> extraFilters,
    required bool ignoreCursor,
  }) async {
    if (page == 1) await _hydrateUpcoming();
    var filters = extraFilters;
    if (clientId != null) {
      filters = {
        ...filters,
        'client_id': {clientId!},
      };
    }
    if (projectId != null) {
      // Project scope reached only `watchPage`'s pre-LIMIT `WHERE project_id`,
      // never the fetch — so a project's embedded tab pulled the newest page
      // COMPANY-wide and filtered it locally to nothing: a permanent "No
      // records found" on a project that has records, with no pull-to-refresh
      // on an embedded list to escape it. `TaskFilters::project_tasks` is the server's own
      // filter for this.
      filters = {
        ...filters,
        'project_tasks': {projectId!},
      };
    }
    return repo.ensurePageLoaded(
      companyId: companyId,
      page: page,
      search: search,
      states: states,
      extraFilters: filters,
      ignoreCursor: ignoreCursor,
    );
  }

  /// One attempt per data generation at pulling the *dated* tasks the Upcoming
  /// tab needs into the local cache.
  ///
  /// That tab's predicate reads the payload, so it has no server mapping at
  /// all — which arms the auto-chain to page the whole task list hunting for
  /// future blocks. On a large account the tab then reads "Upcoming 3" over
  /// "No records found" while burning the page budget, the shape
  /// invoiceninja/flutter#119 documents for Clients → Overdue. The server
  /// *can* narrow by date, and `TaskCalendarViewModel.ensureMonthLoaded`
  /// already proves the filter, so ask for the window this tab is about.
  ///
  /// Deliberately awaited, not fired concurrently: the base clears
  /// `isLoadingPage` in its `finally`, so a late arrival paints "No records
  /// found" for a beat and the auto-chain meanwhile spends its whole budget
  /// scanning against a cache that hasn't landed. Failure is silent with the
  /// sidebar prefetch's log policy — the list the user actually asked for must
  /// still load.
  ///
  /// Known gap, not worth a second request: `calculated_start_date` is the
  /// task's EARLIEST entry start, so a task with past work *and* a future
  /// booking is outside this window. It arrives through ordinary paging.
  Future<void> _hydrateUpcoming() async {
    if (_hydratedUpcoming) return;
    // `activeBadgeModeId`, NOT the `extraFilters` this method used to be
    // handed: every caller passes `_serverExtraFilters()`, which *deletes*
    // `badge_mode` before the fetch because the key is app-private and never
    // goes on the wire. Reading it there made this whole method unreachable —
    // the tab silently fell back to the auto-chain paging the entire task list.
    if (activeBadgeModeId != kBadgeModeUpcoming) return;
    // Set BEFORE the first await: two page-1 fetches can overlap, and this is
    // a concurrency guard as much as a once-per-generation one.
    _hydratedUpcoming = true;
    final today = Date.today();
    final to = today.addDays(_kUpcomingHydrationDays);
    try {
      for (var page = 1; page <= _kUpcomingHydrationPages; page++) {
        final more = await repo.ensurePageLoaded(
          companyId: companyId,
          page: page,
          // A non-empty `extraFilters` already makes this a narrowed fetch, so
          // the shared delta cursor is neither read nor advanced. Explicit
          // anyway: the intent must not rest on `isNarrowedFetch`'s shape.
          ignoreCursor: true,
          extraFilters: {
            // ONE element: `ensurePageLoadedTemplate` joins a filter's values
            // with `,`, and a second would corrupt this 3-part value into a
            // 4-part one.
            'date_range': {
              'calculated_start_date,${today.toIso()},${to.toIso()}',
            },
          },
        );
        if (!more) break;
      }
    } on CompanySwitchedException catch (e) {
      // The company changed under the hydration — expected, same policy as
      // `ClientListViewModel`'s overdue hydration.
      _hydratedUpcoming = false;
      _log.fine('upcoming hydration abandoned: $e');
    } on NetworkException catch (e) {
      // Best-effort, the sidebar prefetch's policy: an offline blip must not
      // pollute the WARNING+ diagnostics log.
      _hydratedUpcoming = false;
      _log.fine('upcoming hydration skipped: ${e.message}');
    } catch (e, st) {
      _hydratedUpcoming = false;
      _log.warning('upcoming hydration failed', e, st);
    }
  }

  /// Ninety days: long enough to cover how far ahead a service business books,
  /// short enough that the fetch stays a handful of pages.
  static const int _kUpcomingHydrationDays = 90;
  static const int _kUpcomingHydrationPages = 5;

  bool _hydratedUpcoming = false;

  @override
  Future<void> refreshAll() async {
    await repo.refreshAll(companyId: companyId);
    // Re-arm: `repo.refreshAll` sweeps by the delta cursor, which is ordered by
    // `updated_at` — a job booked on another device for next month is not in
    // that window, and the latch would block the one fetch that finds it.
    // `ClientListViewModel` does exactly this for the same reason.
    _hydratedUpcoming = false;
    if (activeBadgeModeId == kBadgeModeUpcoming) await _hydrateUpcoming();
  }

  @override
  Iterable<BulkAction<Task>> get bulkActions => [
    BulkAction<Task>(
      id: 'start',
      labelKey: 'start',
      // Admits exactly what `startTimer` will write without a prompt:
      // `append` and `claim`. Excluding every booked task (the first cut) also
      // excluded the ordinary case — five jobs booked for today, the archetypal
      // use of the Upcoming tab — and bulk Start then did nothing for all five.
      //
      // The exclusion lives here rather than as a refusal in `apply` because
      // bulk cannot prompt, and `startTimer` without `confirmClaim` writes
      // nothing for a cross-day or late booking. Note the honest-count
      // rationale this comment used to give was wrong: `EntityListScreenScaffold`
      // always passes `ids`, so `applyBulkAction` short-circuits and `skipped`
      // is zero regardless — a genuinely un-startable row is dropped from the
      // selection silently, and fixing that means teaching the shared scaffold
      // to report it.
      eligible: (t) {
        if (t.isRunning || t.isInvoiced || t.isDeleted) return false;
        final outcome = planTaskStart(
          t.timeLog,
          now: DateTime.now(),
          dueDate: t.dueDate,
          estimatedSeconds: t.estimatedSeconds,
        ).outcome;
        return outcome == TaskStartOutcome.append ||
            outcome == TaskStartOutcome.claim;
      },
      apply: (id) async {
        await repo.startTimer(companyId: companyId, taskId: id);
      },
    ),
    BulkAction<Task>(
      id: 'stop',
      labelKey: 'stop',
      eligible: (t) => t.isRunning && !t.isDeleted,
      apply: (id) => repo.stopRunningTimer(companyId: companyId, taskId: id),
    ),
    ...standardCrudBulkActions(
      isArchived: isArchived,
      isDeleted: isDeleted,
      archive: (id) => repo.archive(companyId: companyId, id: id),
      restore: (id) => repo.restore(companyId: companyId, id: id),
      delete: (id) => repo.delete(companyId: companyId, id: id),
    ),
    // Selection-level actions: the per-id `apply` is a deliberate no-op — the
    // screen's `EntityListBulkAction.onSelection` builds one invoice from the
    // whole selection. `eligible` still drives the empty-selection guard.
    // A running task would bill a live-timer snapshot; an invoiced one would
    // double-bill; a `tmp_` row has no server id to reference.
    BulkAction<Task>(
      id: 'invoice_task',
      labelKey: 'invoice_task',
      eligible: _billable,
      apply: (_) async {},
    ),
    BulkAction<Task>(
      id: 'add_to_invoice',
      // `action_add_to_invoice`: `add_to_invoice` is "Add to invoice :invoice"
      // and nothing here can fill the token (invoiceninja/flutter#35).
      labelKey: 'action_add_to_invoice',
      // Plus a client — the invoice picker is client-scoped.
      eligible: (t) => _billable(t) && t.clientId.isNotEmpty,
      apply: (_) async {},
    ),
  ];

  static bool _billable(Task t) =>
      !t.isDeleted && !t.id.startsWith('tmp_') && !t.isRunning && !t.isInvoiced;
}
