import 'package:admin/data/models/api/document_api_model.dart';

/// A repository whose rows carry their attachments in a `documents` JSON
/// column — every parent a document can hang off.
///
/// The fourteen document-bearing repos already had exactly these two methods
/// (`documentMutationHandlers` takes them as tear-offs); declaring the
/// interface lets the Documents list patch a parent's embedded copy after a
/// rename, a visibility change or a delete made from the list itself, given
/// only the parent's [EntityType] — see `DocumentRepository.ownerFor`.
abstract interface class EmbeddedDocumentsOwner {
  /// Replace (or add) [document] in record [entityId]'s `documents` column.
  /// A no-op when the record isn't cached locally.
  Future<void> applyDocumentChanged({
    required String companyId,
    required String entityId,
    required DocumentApi document,
  });

  /// Drop [documentId] from record [entityId]'s `documents` column. A no-op
  /// when the record isn't cached locally.
  Future<void> applyDocumentDeleted({
    required String companyId,
    required String entityId,
    required String documentId,
  });
}
