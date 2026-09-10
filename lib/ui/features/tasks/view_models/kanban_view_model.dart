import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/models/domain/task_status.dart';
import 'package:admin/data/repositories/task_repository.dart';
import 'package:admin/data/repositories/task_status_repository.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/ui/features/tasks/view_models/task_filters_mixin.dart';

/// State for the Kanban board view. Subscribes to:
///   * Every TaskStatus row → the column set (sorted by `status_order`).
///   * Every active Task grouped by `status_id` → the cards in each column.
///
/// Owns optimistic drag state: when the user drops a card the in-memory
/// `Map<String, List<Task>>` is mutated before the repo writes hit Drift,
/// so the board re-renders instantly. The repo write's watch-stream
/// emission then replaces the optimistic frame seamlessly.
class KanbanViewModel extends ChangeNotifier with TaskFiltersMixin {
  KanbanViewModel({
    required this.repo,
    required this.statusRepo,
    required this.companyId,
  }) {
    _statusesSub = statusRepo
        .watchAll(companyId: companyId)
        .listen(_onStatuses);
    _tasksSub = repo
        .watchAllByStatus(
          companyId: companyId,
          states: const {EntityState.active},
        )
        .listen(_onTasks);
  }

  final TaskRepository repo;
  final TaskStatusRepository statusRepo;
  final String companyId;

  StreamSubscription<List<TaskStatus>>? _statusesSub;
  StreamSubscription<Map<String, List<Task>>>? _tasksSub;

  List<TaskStatus> _statuses = const [];
  List<TaskStatus> get statuses => _statuses;

  Map<String, List<Task>> _tasksByStatus = const {};
  Map<String, List<Task>> get tasksByStatus => _tasksByStatus;

  /// Snapshot of the post-drop layout, set synchronously in
  /// [commitReorder] before the Drift write begins. Cleared in
  /// [_onTasks] once the next stream emission lands (which carries the
  /// persisted ordering). The board reads `tasksFor()` which prefers
  /// this override — drops the snap-back flicker between drop and the
  /// stream re-emission.
  Map<String, List<Task>>? _optimisticByStatus;

  // Client-side Project / Client / Assignee filters live in [TaskFiltersMixin]
  // (shared with the calendar / daily / weekly views). Applied in [tasksFor]
  // before the board groups/renders, so column card-counts reflect the filter
  // too. While any filter is active the board is read-only for reordering
  // (`filtersActive` gates `KanbanColumn.canEdit`) — a partial reorder would
  // drop hidden tasks from a status's persisted order. It deliberately stops
  // there: it does NOT reach `KanbanColumn.canCreate`, because a quick-add
  // writes one task's `status_id` and rewrites no order — and since the screen
  // has no FAB (invoiceninja/flutter#135) that footer is the board's only way
  // to add a task.

  bool _isResolving = true;
  bool get isResolving => _isResolving;

  bool _isReordering = false;
  bool get isReordering => _isReordering;

  bool _disposed = false;

  void _onStatuses(List<TaskStatus> next) {
    _statuses = next;
    _isResolving = false;
    // Guard against a Drift emission landing after dispose() (company switch /
    // nav-away while the watch is in flight) — notifyListeners() on a disposed
    // ChangeNotifier asserts in debug/test. Matches commitReorder's finally and
    // the GenericDetailViewModel convention (L10).
    if (!_disposed) notifyListeners();
  }

  void _onTasks(Map<String, List<Task>> next) {
    _tasksByStatus = next;
    // The stream's emission is the persisted truth. Drop the optimistic
    // override; the board re-reads from `_tasksByStatus` on the next
    // build. If the persisted state differs from optimistic (e.g.
    // another device wrote concurrently), the user sees the truth.
    _optimisticByStatus = null;
    if (!_disposed) notifyListeners();
  }

  /// Tasks for [statusId] in the order the user last saw them. Prefers
  /// the optimistic snapshot when a reorder is in flight; otherwise
  /// reads from the persisted `_tasksByStatus`.
  List<Task> tasksFor(String statusId) {
    final optimistic = _optimisticByStatus;
    final base = optimistic != null
        ? (optimistic[statusId] ?? const <Task>[])
        : (_tasksByStatus[statusId] ?? const <Task>[]);
    if (!filtersActive) return base;
    return base.where(matchesFilters).toList(growable: false);
  }

  /// Persist a card move. The board has already computed the optimistic
  /// rearrangement; this method paints it instantly, writes the new
  /// `(status_id, status_order)` for every affected task, and enqueues
  /// the bulk `reorder` outbox row.
  ///
  /// [orderedByStatus] is the *full* board layout — not just the changed
  /// column — so a drag from column A into column B writes both columns.
  Future<void> commitReorder({
    required Map<String, List<Task>> orderedByStatus,
  }) async {
    if (_isReordering) return;
    // Defensive: the board already gates drag on `!filtersActive`, but
    // never persist a reorder computed from a filtered (partial) set —
    // it would drop hidden tasks from the status's order.
    if (filtersActive) return;
    _isReordering = true;
    // Paint the optimistic layout synchronously before the await so the
    // dropped card doesn't snap back to its source position for a frame.
    _optimisticByStatus = orderedByStatus;
    notifyListeners();
    try {
      final statusIds = _statuses.map((s) => s.id).toList(growable: false);
      final taskIds = <String, List<String>>{
        for (final sid in statusIds)
          sid: (orderedByStatus[sid] ?? const <Task>[])
              .map((t) => t.id)
              .toList(growable: false),
      };
      await repo.reorder(
        companyId: companyId,
        statusIds: statusIds,
        orderedByStatus: taskIds,
      );
    } finally {
      _isReordering = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// Persist a column-header drag (status reordering on kanban).
  Future<void> commitStatusReorder(List<String> orderedStatusIds) async {
    await statusRepo.reorder(
      companyId: companyId,
      orderedStatusIds: orderedStatusIds,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _statusesSub?.cancel();
    _tasksSub?.cancel();
    super.dispose();
  }
}
