import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/document_record.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/copy_entity_link.dart';
import 'package:admin/ui/core/detail/document_open_actions.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/detail/standard_entity_action_items.dart';
import 'package:admin/ui/core/detail/standard_entity_actions.dart';
import 'package:admin/ui/core/sync/require_synced.dart';
import 'package:admin/ui/core/widgets/notify_async.dart';

/// Everything that can be done to one uploaded file from the Documents list
/// or its record screen. No archive / restore: the server ignores both for a
/// document (`DocumentRepository::archive` is empty), so offering them would
/// be a button that does nothing. No create either — a file is uploaded on
/// its record.
enum DocumentAction { view, download, edit, toggleVisibility, copyLink, delete }

/// Whether [session]'s user may rename, re-publish or delete [document] — the
/// one rule the row menu, the record screen and the list's bulk Delete share.
///
/// The server authorizes all three against the DOCUMENT (`EntityPolicy::edit`):
/// an admin, `edit_document`, or the file's own uploader or assignee — not
/// against the record it is attached to. And attaching is an Enterprise
/// feature on hosted: a record's own Documents tab is read-only there, and
/// this list matches it.
bool documentEditable(AuthSession? session, DocumentRecord document) =>
    !document.isDeleted &&
    (session?.canAttachDocuments ?? false) &&
    (session?.canEditRecord(
          'document',
          createdBy: document.userId,
          assignedTo: document.assignedUserId,
          recordId: document.id,
        ) ??
        false);

/// Single source of truth for the Documents actions — the list row popup, the
/// record screen's bar and the edit screen's overflow all read it.
class DocumentActions {
  DocumentActions._();

  /// Actions an edit screen hides — none here change the record's lifecycle
  /// beyond delete, which the edit screen's overflow keeps.
  static bool isLifecycle(DocumentAction action) =>
      action == DocumentAction.delete;

  static List<EntityActionItem<DocumentAction>> itemsFor(
    BuildContext context,
    DocumentRecord document,
    void Function(DocumentAction) onTap,
  ) {
    final canEdit = documentEditable(
      context.read<Services>().auth.session.value,
      document,
    );
    return [
      EntityActionItem(
        kind: DocumentAction.view,
        icon: Icons.visibility_outlined,
        label: context.tr('view'),
        enabled: true,
        isPrimary: true,
        onTap: () => onTap(DocumentAction.view),
      ),
      EntityActionItem(
        kind: DocumentAction.download,
        icon: Icons.download_outlined,
        label: context.tr('download'),
        enabled: true,
        onTap: () => onTap(DocumentAction.download),
      ),
      if (canEdit)
        editActionItem(
          context: context,
          kind: DocumentAction.edit,
          isPrimary: false,
          onTap: () => onTap(DocumentAction.edit),
        ),
      if (canEdit)
        EntityActionItem(
          kind: DocumentAction.toggleVisibility,
          icon: document.isPublic
              ? Icons.lock_outline
              : Icons.lock_open_outlined,
          label: context.tr(document.isPublic ? 'set_private' : 'set_public'),
          enabled: true,
          onTap: () => onTap(DocumentAction.toggleVisibility),
        ),
      ?copyLinkActionItem(
        context: context,
        kind: DocumentAction.copyLink,
        entityId: document.id,
        onTap: () => onTap(DocumentAction.copyLink),
      ),
      ?deleteActionItem(
        context: context,
        kind: DocumentAction.delete,
        subject: document.displayName,
        canDelete: canEdit,
        onTap: () => onTap(DocumentAction.delete),
      ),
    ];
  }

  static Future<void> dispatch(
    BuildContext context,
    Services services,
    String companyId,
    DocumentRecord document,
    DocumentAction action,
  ) async {
    // A file the server no longer has (deleted on the web): drop the row so
    // the list stops offering it — see `DocumentRepository.forgetMissing`.
    Future<void> forget(_) => services.documents.forgetMissing(
      companyId: companyId,
      documentId: document.id,
    );
    switch (action) {
      case DocumentAction.view:
        await viewDocument(context, document.attachment, onMissing: forget);
      case DocumentAction.download:
        await downloadDocument(context, document.attachment, onMissing: forget);
      case DocumentAction.edit:
        goEntityEdit(context, '/documents', document.id);
      case DocumentAction.toggleVisibility:
        await runMutationWithNotify(
          context,
          () => services.documents.setVisibility(
            companyId: companyId,
            document: document,
            isPublic: !document.isPublic,
          ),
          successMsg: context.tr('updated_document'),
        );
      case DocumentAction.copyLink:
        await copyEntityLink(context, EntityType.document, document.id);
      case DocumentAction.delete:
        if (!requireSynced(context, document.id)) return;
        // No Undo: a document delete is permanent server-side.
        await StandardEntityActions.delete(
          context: context,
          wireName: 'document',
          op: () =>
              services.documents.delete(companyId: companyId, id: document.id),
        );
    }
  }
}
