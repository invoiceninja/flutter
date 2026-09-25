import 'package:admin/data/models/domain/tag.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/tag_repository.dart';
import 'package:admin/ui/core/edit/generic_edit_view_model.dart';
import 'package:admin/ui/features/settings/widgets/accent_swatch_grid.dart'
    show kStatusSwatches;

/// Drives the `/settings/tags/new` + `/:id` edit screen. Optimistic —
/// `save()` lands the draft in Drift via the repo; the outbox handles the
/// server round-trip. `entityType` (`task` / `project`) is fixed at create
/// time and read-only thereafter (the server ignores it on update).
class TagEditViewModel extends GenericEditViewModel<Tag> {
  TagEditViewModel({
    required this.repo,
    required this.companyId,
    required String entityType,
    Tag? existing,
    super.sync,
    super.connectivity,
  }) : super(
         initialDraft:
             existing ?? _emptyTag(existing?.entityType ?? entityType),
         original: existing,
         companyId: companyId,
       );

  final TagRepository repo;
  final String companyId;

  @override
  bool draftIsNonEmpty() => draft.name.isNotEmpty;

  @override
  Future<SaveResult<Tag>> performSave() async {
    if (savesAsCreate) {
      final result = await repo.create(
        companyId: companyId,
        draft: draft,
        existingTempId: recoveryTempId,
      );
      rememberCreateTempId(result.entity.id);
      return result;
    }
    return repo.save(companyId: companyId, tag: draft);
  }

  void setName(String v) => updateDraft(draft.copyWith(name: v));
  void setColor(String v) => updateDraft(draft.copyWith(color: v));
}

Tag _emptyTag(String entityType) => Tag(
  id: '',
  entityType: entityType,
  name: '',
  color: kStatusSwatches.first,
  updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  archivedAt: null,
  isDeleted: false,
);
