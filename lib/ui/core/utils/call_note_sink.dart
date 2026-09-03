import 'package:admin/app/services.dart';
import 'package:admin/domain/entity_type.dart';

/// Returns a **thunk** that enqueues an activity note against `(type, id)`, or
/// null when that entity has no note path.
///
/// A factory rather than an already-running `Future`: the only caller hands it
/// to `runMutationWithNotify`, whose Retry button re-invokes what it was given.
/// Returning the future itself would make Retry re-await a future that has
/// already failed — it fails again instantly, for ever, and the note is never
/// re-enqueued.
///
/// The one place an [EntityType] is resolved back to a repository's
/// `addComment`. It exists because the post-call offer
/// (invoiceninja/flutter#120) is raised by an app-level widget that has no idea
/// which screen placed the call — every other caller already holds its own
/// repository and calls it directly.
///
/// A switch rather than a callback captured at dial time: the pending call is
/// held across an app-lifecycle round trip, and a closure there would pin the
/// widget tree that created it. See [PendingCallLog].
///
/// Ten entities, matching the ten that ship an "Add comment" action — the same
/// set `services_entity_wiring.dart` registers a `MutationKind.addComment`
/// handler for. Task and Project are accepted by the server's
/// `StoreNoteRequest` but have no `addComment` on their repositories, so they
/// return null here rather than pretending; a null means the caller must not
/// offer to log at all.
Future<void> Function()? enqueueCallNote(
  Services services, {
  required EntityType type,
  required String entityId,
  required String companyId,
  required String note,
}) => switch (type) {
  EntityType.client => () => services.clients.addComment(
    companyId: companyId,
    clientId: entityId,
    text: note,
  ),
  EntityType.vendor => () => services.vendors.addComment(
    companyId: companyId,
    vendorId: entityId,
    text: note,
  ),
  EntityType.invoice => () => services.invoices.addComment(
    companyId: companyId,
    invoiceId: entityId,
    text: note,
  ),
  EntityType.quote => () => services.quotes.addComment(
    companyId: companyId,
    quoteId: entityId,
    text: note,
  ),
  EntityType.credit => () => services.credits.addComment(
    companyId: companyId,
    creditId: entityId,
    text: note,
  ),
  EntityType.purchaseOrder => () => services.purchaseOrders.addComment(
    companyId: companyId,
    purchaseOrderId: entityId,
    text: note,
  ),
  EntityType.recurringInvoice => () => services.recurringInvoices.addComment(
    companyId: companyId,
    recurringInvoiceId: entityId,
    text: note,
  ),
  EntityType.payment => () => services.payments.addComment(
    companyId: companyId,
    paymentId: entityId,
    text: note,
  ),
  EntityType.expense => () => services.expenses.addComment(
    companyId: companyId,
    expenseId: entityId,
    text: note,
  ),
  EntityType.recurringExpense => () => services.recurringExpenses.addComment(
    companyId: companyId,
    recurringExpenseId: entityId,
    text: note,
  ),
  _ => null,
};

/// Whether [type] can carry an activity note — i.e. whether a surface should
/// offer to log a call against it at all.
bool canLogCallAgainst(EntityType type) => const {
  EntityType.client,
  EntityType.vendor,
  EntityType.invoice,
  EntityType.quote,
  EntityType.credit,
  EntityType.purchaseOrder,
  EntityType.recurringInvoice,
  EntityType.payment,
  EntityType.expense,
  EntityType.recurringExpense,
}.contains(type);
