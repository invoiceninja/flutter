import 'package:admin/ui/features/billing_shared/billing_doc_type.dart';

/// Which document the send-email composer's live preview should render
/// against, as the `entity` / `entity_id` pair `POST /api/v1/templates`
/// expects.
///
/// The server binds the real record only when **both** are non-empty
/// (`TemplateEngine::setEntity()`). Otherwise it sniffs the template name for
/// a `quote` / `purchase` / `payment` substring and falls back to
/// `<Model>::whereHas('invitations')->withTrashed()->company()->first()` — an
/// unordered pick of the company's oldest matching record, soft-deleted rows
/// included. That fallback is what made the composer preview show another
/// client's name, a `0001_Deleted` number and a 0.00 amount
/// (invoiceninja/flutter#31).
///
/// Two cases stay **unbound** on purpose. Neither degrades server-side — both
/// are a hard 500, verified against the demo API:
///
/// * **No invitations.** `TemplateEngine::replaceValues()` does
///   `new HtmlEngine($entity->invitations->first())` with no null check (its
///   own fallback branches all filter `whereHas('invitations')`, the
///   real-entity branch doesn't). Recurring invoices are the usual victim —
///   invitations are only materialized by `service()->createInvitations()`.
/// * **An unsaved `tmp_` id.** It doesn't decode to a row, and the resulting
///   null is assigned to a non-nullable typed property. Defensive only: the
///   route redirects unsaved ids to the detail screen before the composer is
///   built.
///
/// Falling back to the generic sample in those two cases is no worse than the
/// pre-fix behavior, and Send is already disabled for both.
({String entity, String entityId}) emailPreviewBinding({
  required BillingDocType type,
  required String entityId,
  required bool hasInvitations,
}) {
  const unbound = (entity: '', entityId: '');
  if (entityId.isEmpty || entityId.startsWith('tmp_')) return unbound;
  if (!hasInvitations) return unbound;
  return (entity: type.wireName, entityId: entityId);
}
