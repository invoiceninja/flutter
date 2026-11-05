import 'package:admin/data/services/upload_source.dart';

/// Interface every entity repository implements when it supports document
/// attachments. Lets UI helpers (e.g. `buildStandardDocumentsTab`) take a
/// typed repo without knowing the concrete entity type — every doc-bearing
/// repo (Client / Product / Project / Vendor / Expense / RecurringExpense /
/// Invoice) honors this contract, with uniform `entityId:` parameter names.
///
/// Dart's implicit-interface model means the 7 concrete repos already
/// satisfy this — declaring `implements DocumentBearingRepository` on each
/// just adds a static type assertion the compiler can use to enforce the
/// shape stays uniform.
abstract class DocumentBearingRepository {
  Future<void> uploadDocument({
    required String companyId,
    required String entityId,
    required UploadSource source,
  });

  Future<void> deleteDocument({
    required String companyId,
    required String entityId,
    required String documentId,
  });

  Future<void> setDocumentVisibility({
    required String companyId,
    required String entityId,
    required String documentId,
    required bool isPublic,
  });
}

/// A [DocumentBearingRepository] whose NEW records can take documents before
/// they exist: the create form queues the files as uploads under the record's
/// `tmp_` id, behind its create, and the outbox rewrites the id once the
/// create lands (invoiceninja/flutter#173, docs/attaching-documents.md).
///
/// The two outbox methods are `BaseEntityRepository`'s; declaring them here
/// is what lets `GenericEditViewModel` reach them without knowing the entity.
abstract class PendingUploadsRepository implements DocumentBearingRepository {
  /// See `BaseEntityRepository.replaceUnsentDocumentUploads`.
  Future<List<String>> replaceUnsentDocumentUploads({
    required String companyId,
    required String tempId,
    required Future<void> Function() enqueue,
  });

  /// See `BaseEntityRepository.requeueUnsentDocumentUploads`.
  Future<int> requeueUnsentDocumentUploads({
    required String companyId,
    required String tempId,
  });
}
