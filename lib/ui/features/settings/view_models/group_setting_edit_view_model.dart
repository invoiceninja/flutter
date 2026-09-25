import 'dart:async';

import 'package:admin/data/models/domain/group_setting.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/group_setting_repository.dart';
import 'package:admin/ui/core/edit/generic_edit_view_model.dart';

/// Drives the group_settings edit + create screen. Optimistic — `save()`
/// lands the draft in Drift via the repo and the outbox handles the
/// server round-trip.
///
/// Watches the group list to validate the name client-side. The server
/// requires `name` to be present and unique-per-company on create
/// (`StoreGroupSettingRequest`), and saves here are optimistic — without a
/// pre-check an empty / duplicate name is accepted locally and only bounces
/// later as a sync error. [nameIsValid] gates the Save button (and Enter,
/// via `FormSaveScope`); [nameErrorKey] surfaces the duplicate inline.
class GroupSettingEditViewModel extends GenericEditViewModel<GroupSetting> {
  GroupSettingEditViewModel({
    required this.repo,
    required this.companyId,
    GroupSetting? existing,
    super.sync,
    super.connectivity,
  }) : super(
         initialDraft: existing ?? _emptyGroup(),
         original: existing,
         companyId: companyId,
       ) {
    // Active + archived names (the closest match to the server's uniqueness
    // scope — soft-deleted rows it also counts are a rare reuse edge that
    // still surfaces as a server error). Exclude this entity so editing it
    // doesn't flag its own name; `recoveryTempId` is read live so the
    // just-created row that re-emits here after an optimistic create is
    // excluded too.
    _namesSub = repo
        .watchAllIncludingArchived(companyId: companyId)
        .listen(_onGroupsEmitted);
  }

  final GroupSettingRepository repo;
  final String companyId;

  StreamSubscription<List<GroupSetting>>? _namesSub;
  Set<String> _takenNames = const {};

  void _onGroupsEmitted(List<GroupSetting> groups) {
    final names = <String>{};
    for (final g in groups) {
      // Exclude this entity. `recoveryTempId` is timing-safe to read here:
      // `performSave` sets it synchronously right after `repo.create()`
      // returns (no await between), so it's already populated before any
      // post-create watch emission is delivered — the just-created row never
      // flags its own name as a duplicate.
      if (g.id == original?.id || g.id == recoveryTempId) continue;
      final n = g.name.trim().toLowerCase();
      if (n.isNotEmpty) names.add(n);
    }
    _takenNames = names;
    if (!isDisposed) notifyListeners();
  }

  bool get _nameIsBlank => draft.name.trim().isEmpty;

  /// The server enforces `unique` only on create; an update can rename
  /// freely (`UpdateGroupSettingRequest` doesn't re-check), so the duplicate
  /// guard is create-only — it never blocks a server-permitted rename.
  bool get _nameIsDuplicate =>
      isCreate &&
      !_nameIsBlank &&
      _takenNames.contains(draft.name.trim().toLowerCase());

  /// Gate for the Save button + Enter-to-save (see the scaffold's `canSave`).
  bool get nameIsValid => !_nameIsBlank && !_nameIsDuplicate;

  /// Localization key for the inline name error, or null. Only the duplicate
  /// case shows a message — a blank name just disables Save (no red error on
  /// an untouched create form).
  String? get nameErrorKey => _nameIsDuplicate ? 'group_name_taken' : null;

  @override
  bool draftIsNonEmpty() {
    // Create mode: only `name` can make the draft dirty — cascade `settings`
    // are configured post-save via "Configure Settings". The `settings`
    // branch only matters in edit mode, where a saved group may carry them.
    final d = draft;
    return d.name.isNotEmpty || (d.settings?.isNotEmpty ?? false);
  }

  @override
  Future<SaveResult<GroupSetting>> performSave() async {
    if (savesAsCreate) {
      final result = await repo.create(
        companyId: companyId,
        draft: draft,
        existingTempId: recoveryTempId,
      );
      rememberCreateTempId(result.entity.id);
      return result;
    }
    return repo.save(companyId: companyId, group: draft);
  }

  void resetToEmpty() => reset(emptyDraft: _emptyGroup());

  void setName(String v) => updateDraft(draft.copyWith(name: v));

  @override
  void dispose() {
    _namesSub?.cancel();
    super.dispose();
  }
}

GroupSetting _emptyGroup() => GroupSetting(
  id: '',
  name: '',
  customValue1: '',
  customValue2: '',
  customValue3: '',
  customValue4: '',
  updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  archivedAt: null,
  isDeleted: false,
);
