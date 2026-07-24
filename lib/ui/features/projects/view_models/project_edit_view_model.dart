import 'package:decimal/decimal.dart';

import 'package:admin/data/models/domain/project.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/project_repository.dart';
import 'package:admin/ui/core/edit/generic_edit_view_model.dart';
import 'package:admin/utils/formatting.dart';

/// Drives the Project edit + create screen. Optimistic — `save()` lands the
/// draft in Drift via the repo, returns the saved entity, and the outbox
/// handles the server round-trip.
class ProjectEditViewModel extends GenericEditViewModel<Project> {
  ProjectEditViewModel({
    required this.repo,
    required this.companyId,
    required this.nameRequiredMessage,
    required this.clientRequiredMessage,
    Project? existing,
    Project? cloneFrom,
    super.sync,
    super.connectivity,
    super.useCommaAsDecimalPlace,
  }) : super(
         initialDraft: cloneFrom ?? existing ?? emptyProject(),
         original: existing,
         companyId: companyId,
       );

  final ProjectRepository repo;
  final String companyId;

  /// Localized "please enter a name" — injected from the edit screen's
  /// `buildVm` (the VM has no `BuildContext` to localize with). Mirrors the
  /// billing VMs' `clientRequiredMessage` injection.
  final String nameRequiredMessage;

  /// Localized "please select a client" — same injection rationale.
  final String clientRequiredMessage;

  /// Create-only required-field guard. `StoreProjectRequest` requires `name`
  /// and `client_id`; `UpdateProjectRequest` drops the `name` rule and locks
  /// `client_id` to the original, so an edit must never block on either. Runs
  /// in `GenericEditViewModel.save` *before* the optimistic Drift write +
  /// outbox enqueue, surfacing inline via `fieldErrorFor('name')` /
  /// `fieldErrorFor('client_id')` instead of a deferred server 422 / dead row.
  @override
  Map<String, List<String>> validate() {
    if (!isCreate) return const {};
    return {
      if (draft.name.trim().isEmpty) 'name': [nameRequiredMessage],
      if (draft.clientId.isEmpty) 'client_id': [clientRequiredMessage],
    };
  }

  @override
  bool draftIsNonEmpty() {
    final d = draft;
    return d.name.isNotEmpty ||
        d.clientId.isNotEmpty ||
        d.dueDate != null ||
        d.budgetedHours != 0 ||
        d.taskRate != Decimal.zero ||
        d.publicNotes.isNotEmpty ||
        d.privateNotes.isNotEmpty;
  }

  @override
  Future<SaveResult<Project>> performSave() async {
    if (isCreate) {
      final result = await repo.create(
        companyId: companyId,
        draft: draft,
        existingTempId: recoveryTempId,
      );
      rememberCreateTempId(result.entity.id);
      return result;
    }
    return repo.save(companyId: companyId, project: draft);
  }

  void resetToEmpty() => reset(emptyDraft: emptyProject());

  /// Seed [rate] as the default task rate, but only on a fresh create where
  /// the user hasn't entered one yet. Backs the async company-default seed
  /// (company settings aren't on the synchronous `AuthCompany`, so the edit
  /// screen reads them off the company stream and calls this once they
  /// resolve). No-ops on edits or once a rate is present, so it can't clobber
  /// a value the user already typed or a client-derived rate.
  void seedDefaultTaskRate(Decimal rate) {
    if (isCreate && draft.taskRate == Decimal.zero) {
      updateDraft(draft.copyWith(taskRate: rate));
    }
  }

  // ── Field setters ──────────────────────────────────────────────────

  void setName(String v) => updateDraft(draft.copyWith(name: v));
  void setNumber(String v) => updateDraft(draft.copyWith(number: v));
  void setTagIds(List<String> ids) => updateDraft(draft.copyWith(tagIds: ids));
  void setClientId(String v) => updateDraft(draft.copyWith(clientId: v));
  void setAssignedUserId(String v) =>
      updateDraft(draft.copyWith(assignedUserId: v));
  void setDueDate(Date? d) => updateDraft(draft.copyWith(dueDate: d));
  void setBudgetedHours(String input) => updateDraft(
    draft.copyWith(
      budgetedHours:
          parseDouble(input, useCommaAsDecimalPlace: useCommaAsDecimalPlace) ??
          0.0,
    ),
  );
  void setBudgetedAmount(String input) =>
      setDec((d, v) => d.copyWith(budgetedAmount: v), input);
  void setTaskRate(String input) =>
      setDec((d, v) => d.copyWith(taskRate: v), input);
  void setColor(String v) => updateDraft(draft.copyWith(color: v));
  void setPublicNotes(String v) => updateDraft(draft.copyWith(publicNotes: v));
  void setPrivateNotes(String v) =>
      updateDraft(draft.copyWith(privateNotes: v));
  void setCustomValue1(String v) =>
      updateDraft(draft.copyWith(customValue1: v));
  void setCustomValue2(String v) =>
      updateDraft(draft.copyWith(customValue2: v));
  void setCustomValue3(String v) =>
      updateDraft(draft.copyWith(customValue3: v));
  void setCustomValue4(String v) =>
      updateDraft(draft.copyWith(customValue4: v));
}

Project emptyProject() => Project(
  id: '',
  userId: '',
  assignedUserId: '',
  clientId: '',
  number: '',
  name: '',
  taskRate: Decimal.zero,
  dueDate: null,
  privateNotes: '',
  publicNotes: '',
  budgetedHours: 0.0,
  budgetedAmount: Decimal.zero,
  currentHours: 0.0,
  customValue1: '',
  customValue2: '',
  customValue3: '',
  customValue4: '',
  color: '',
  updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  archivedAt: null,
  isDeleted: false,
);
