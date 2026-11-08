/// When a DocuNinja document may be sent, as React decides it
/// (`pages/documents/show/hooks/useIsSendable.ts`). React checks the
/// *Invoice Ninja* role and permissions here, not DocuNinja's, and the app
/// mirrors it (docs/docuninja.md).
library;

import 'package:admin/data/models/docuninja/dn_models.dart';

/// The statuses a document can be sent from: draft, pending approval,
/// approved, and sent (a resend).
const kDnSendableStatuses = {
  DnDocumentStatus.draft,
  DnDocumentStatus.pendingApproval,
  DnDocumentStatus.approved,
  DnDocumentStatus.sent,
};

bool dnIsSendable({
  required DnDocument document,
  required bool isAdminOrOwner,
  required bool requiresApproval,
  required bool canEdit,
  required bool canCreate,
  required bool isDocumentOwner,
}) {
  final allowed =
      kDnSendableStatuses.contains(document.status) && !document.isDeleted;
  final approved = document.status == DnDocumentStatus.approved;
  return (allowed && isAdminOrOwner) ||
      (approved && requiresApproval) ||
      (allowed && !requiresApproval && canEdit) ||
      (allowed && !requiresApproval && canCreate && isDocumentOwner);
}

/// Whether a signer's Resend is shown: not once the document is completed or
/// voided (`Invitations.tsx`).
bool dnShowsResend(DnDocument d) =>
    d.status != DnDocumentStatus.completed &&
    d.status != DnDocumentStatus.voided &&
    !d.isDeleted;

/// Whether [invitation]'s Resend is enabled (`canSendInvitation`): with
/// signing order, only the next signer who has not signed may be emailed.
bool dnCanResend(DnDocument d, DnInvitation invitation) {
  final ordered = d.invitations.any((i) => i.raw['signing_order'] != null);
  if (!ordered) return true;
  final unsigned = [
    for (final i in d.invitations)
      if (i.signedDate == null) i,
  ]..sort((a, b) => a.signingOrder.compareTo(b.signingOrder));
  return unsigned.isNotEmpty && unsigned.first.id == invitation.id;
}

/// Void only applies to a sent document (`VoidAction.tsx`).
bool dnCanVoid(DnDocument d) =>
    d.status == DnDocumentStatus.sent && !d.isDeleted;

/// The signed PDF and the audit log exist once the document is completed.
bool dnIsCompleted(DnDocument d) => d.status == DnDocumentStatus.completed;

/// Expiry can be changed until the document is sent (`DocumentSettingsModal`).
/// An unknown status is not editable.
bool dnCanSetExpiry(DnDocument d) {
  final status = d.status;
  return status != null && status.id <= DnDocumentStatus.sent.id;
}
