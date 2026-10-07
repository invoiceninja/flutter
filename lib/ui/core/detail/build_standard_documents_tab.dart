import 'package:flutter/material.dart';

import 'package:admin/data/models/domain/document.dart';
import 'package:admin/data/repositories/document_bearing_repository.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/detail_tab_indices.dart';
import 'package:admin/ui/core/detail/entity_detail_tabs.dart';
import 'package:admin/ui/core/detail/entity_documents_tab.dart';
import 'package:admin/utils/formatting.dart';

/// Builds the standard Documents tab used on every document-bearing entity's
/// detail screen (Client / Product / Project / Vendor / Expense /
/// RecurringExpense / Invoice). Wraps [EntityDocumentsTab] with the
/// `documents` label and its count badge, the description icon, and the
/// three callback closures that route through [repo]'s uniform
/// `uploadDocument` / `deleteDocument` / `setDocumentVisibility` methods.
///
/// Each detail screen used to inline ~35 LOC of boilerplate for this tab;
/// after the [DocumentBearingRepository] interface unified the per-entity
/// signatures, the call site collapses to one line.
EntityDetailTab buildStandardDocumentsTab({
  required BuildContext context,
  required String companyId,
  required String entityId,
  required List<Document> documents,
  required DocumentBearingRepository repo,
  Formatter? formatter,
  bool readOnly = false,
}) {
  return EntityDetailTab(
    id: DetailTabIds.documents,
    label: context.tr('documents'),
    // The badge every counted tab wears, in place of a "(2)" in the label.
    // Exact — the documents ride on the record — and left off at none: an
    // empty Documents tab is the usual case, not news.
    count: documents.isEmpty ? null : documents.length,
    icon: Icons.description_outlined,
    bodyBuilder: (_) => EntityDocumentsTab(
      entityId: entityId,
      documents: documents,
      formatter: formatter,
      // A soft-deleted record cannot take a new document or lose one, but the
      // ones it has stay readable.
      readOnly: readOnly,
      onUpload: (sources) async {
        for (final s in sources) {
          await repo.uploadDocument(
            companyId: companyId,
            entityId: entityId,
            source: s,
          );
        }
      },
      onDelete: (doc) => repo.deleteDocument(
        companyId: companyId,
        entityId: entityId,
        documentId: doc.id,
      ),
      onToggleVisibility: (doc) => repo.setDocumentVisibility(
        companyId: companyId,
        entityId: entityId,
        documentId: doc.id,
        isPublic: !doc.isPublic,
      ),
    ),
  );
}
