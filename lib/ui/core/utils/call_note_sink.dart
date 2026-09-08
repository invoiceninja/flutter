import 'package:admin/app/services.dart';
import 'package:admin/data/repositories/entity_comment_mutations.dart';
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
}) {
  final select = _noteRepoSelector(type);
  if (select == null) return null;
  // `select(services)` runs inside the thunk, not here: `enqueueCallNote` is
  // called to decide whether to OFFER logging, and must not touch `Services`
  // until the user actually submits.
  return () => select(
    services,
  ).addComment(companyId: companyId, entityId: entityId, text: note);
}

/// Selects the repository that owns [type]'s activity notes, or null when it
/// has none. A selector rather than the repository itself so the caller can
/// decide whether to offer logging without resolving anything off [Services].
///
/// One arm per entity because the repositories are distinct concrete types;
/// `Services` exposes no lookup by [EntityType]. The arms are otherwise
/// identical now that `addComment` comes from the shared
/// `EntityCommentMutations` mixin with a uniform `entityId` parameter — before
/// that each arm spelled the id differently (`clientId`, `quoteId`, …) and the
/// whole call had to be repeated ten times.
EntityCommentMutations<dynamic, dynamic> Function(Services)? _noteRepoSelector(
  EntityType type,
) => switch (type) {
  EntityType.client => (s) => s.clients,
  EntityType.vendor => (s) => s.vendors,
  EntityType.invoice => (s) => s.invoices,
  EntityType.quote => (s) => s.quotes,
  EntityType.credit => (s) => s.credits,
  EntityType.purchaseOrder => (s) => s.purchaseOrders,
  EntityType.recurringInvoice => (s) => s.recurringInvoices,
  EntityType.payment => (s) => s.payments,
  EntityType.expense => (s) => s.expenses,
  EntityType.recurringExpense => (s) => s.recurringExpenses,
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
