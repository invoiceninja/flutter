import 'package:admin/data/models/domain/task_status.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/task_status_repository.dart';
import 'package:admin/ui/core/edit/generic_edit_view_model.dart';
import 'package:admin/ui/features/settings/widgets/accent_swatch_grid.dart'
    show kStatusSwatches;

/// Drives the `/settings/task_statuses/new` + `/:id` edit screen.
/// Optimistic — `save()` lands the draft in Drift via the repo; the
/// outbox handles the server round-trip.
///
/// Status order is **not** edited here — drag-reorder on the list
/// screen calls `repo.reorder(...)` directly, which renumbers every
/// affected row in one transaction.
class TaskStatusEditViewModel extends GenericEditViewModel<TaskStatus> {
  TaskStatusEditViewModel({
    required this.repo,
    required this.companyId,
    TaskStatus? existing,
    super.sync,
    super.connectivity,
  }) : super(
         initialDraft: existing ?? _emptyStatus(),
         original: existing,
         companyId: companyId,
       );

  final TaskStatusRepository repo;
  final String companyId;

  @override
  bool draftIsNonEmpty() {
    final d = draft;
    return d.name.isNotEmpty || d.color.isNotEmpty;
  }

  @override
  Future<SaveResult<TaskStatus>> performSave() async {
    if (savesAsCreate) {
      final result = await repo.create(
        companyId: companyId,
        draft: draft,
        existingTempId: recoveryTempId,
      );
      rememberCreateTempId(result.entity.id);
      return result;
    }
    return repo.save(companyId: companyId, status: draft);
  }

  void resetToEmpty() => reset(emptyDraft: _emptyStatus());

  void setName(String v) => updateDraft(draft.copyWith(name: v));
  void setColor(String v) => updateDraft(draft.copyWith(color: v));
}

TaskStatus _emptyStatus() => TaskStatus(
  id: '',
  name: '',
  // Neutral grey by default — communicates "set me up" without staking
  // out a workflow meaning the way blue/green/red would. Users almost
  // always change it; the default just ensures a newly created status
  // is visible on the kanban (zero-empty color renders as ink3 fallback).
  color: kStatusSwatches.first,
  statusOrder: 0,
  updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  archivedAt: null,
  isDeleted: false,
);
