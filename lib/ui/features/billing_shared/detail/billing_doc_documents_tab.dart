import 'package:flutter/widgets.dart';

import 'package:admin/data/models/domain/billing/billing_doc_fields.dart';
import 'package:admin/data/repositories/document_bearing_repository.dart';
import 'package:admin/data/services/upload_source.dart';
import 'package:admin/ui/core/detail/build_standard_documents_tab.dart';
import 'package:admin/ui/core/detail/entity_detail_tabs.dart';
import 'package:admin/utils/formatting.dart';

typedef BillingDocUpload =
    Future<void> Function({
      required String companyId,
      required String entityId,
      required UploadSource source,
    });

typedef BillingDocDeleteDocument =
    Future<void> Function({
      required String companyId,
      required String entityId,
      required String documentId,
    });

typedef BillingDocSetDocumentVisibility =
    Future<void> Function({
      required String companyId,
      required String entityId,
      required String documentId,
      required bool isPublic,
    });

/// The Documents tab of a billing document's record screen — the standard
/// one, for a repository that has the three document mutations but does not
/// declare `DocumentBearingRepository`.
///
/// Four of the five billing repositories are in that position (the invoice's
/// is not), and each of their screens used to spell the tab out by hand: the
/// label, the icon and three closures, about thirty-five lines a screen. Pass
/// the repository's three methods as tear-offs.
///
/// A deleted document's attachments stay readable and nothing else is offered.
EntityDetailTab buildBillingDocumentsTab({
  required BuildContext context,
  required String companyId,
  required BillingDocFields doc,
  required BillingDocUpload upload,
  required BillingDocDeleteDocument delete,
  required BillingDocSetDocumentVisibility setVisibility,
  Formatter? formatter,
}) => buildStandardDocumentsTab(
  context: context,
  companyId: companyId,
  entityId: doc.id,
  documents: doc.documents,
  repo: _DocumentCalls(upload, delete, setVisibility),
  formatter: formatter,
  readOnly: doc.isDeleted,
);

class _DocumentCalls implements DocumentBearingRepository {
  const _DocumentCalls(this._upload, this._delete, this._setVisibility);

  final BillingDocUpload _upload;
  final BillingDocDeleteDocument _delete;
  final BillingDocSetDocumentVisibility _setVisibility;

  @override
  Future<void> uploadDocument({
    required String companyId,
    required String entityId,
    required UploadSource source,
  }) => _upload(companyId: companyId, entityId: entityId, source: source);

  @override
  Future<void> deleteDocument({
    required String companyId,
    required String entityId,
    required String documentId,
  }) =>
      _delete(companyId: companyId, entityId: entityId, documentId: documentId);

  @override
  Future<void> setDocumentVisibility({
    required String companyId,
    required String entityId,
    required String documentId,
    required bool isPublic,
  }) => _setVisibility(
    companyId: companyId,
    entityId: entityId,
    documentId: documentId,
    isPublic: isPublic,
  );
}
