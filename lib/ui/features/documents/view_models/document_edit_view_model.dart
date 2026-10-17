import 'package:admin/data/models/domain/document_record.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/document_repository.dart';
import 'package:admin/ui/core/edit/generic_edit_view_model.dart';

/// Drives the document edit screen: a rename and the public / private
/// switch — the two fields `PUT /documents/{id}` accepts. There is no
/// create: a file is uploaded on its record, so [existing] is required.
class DocumentEditViewModel extends GenericEditViewModel<DocumentRecord> {
  DocumentEditViewModel({
    required this.repo,
    required this.companyId,
    required DocumentRecord existing,
    super.sync,
    super.connectivity,
  }) : super(initialDraft: existing, original: existing, companyId: companyId);

  final DocumentRepository repo;
  final String companyId;

  @override
  bool draftIsNonEmpty() => draft.name.trim().isNotEmpty;

  @override
  Future<SaveResult<DocumentRecord>> performSave() =>
      repo.save(companyId: companyId, document: draft);

  // Closure params are `n` (next value) to avoid shadowing the argument.
  void setName(String v) => setStr((d, n) => d.copyWith(name: n), v);
  void setPublic(bool v) => setBool((d, n) => d.copyWith(isPublic: n), v);
}
