import 'package:admin/data/repositories/dashboard_repository.dart';
import 'package:admin/domain/entity_type.dart';

/// Which dashboard panels this company can render.
///
/// Extracted because the gate was copied three times — the wide `_bottomGrid`,
/// the mobile body's trailing list, and the manage sheet's Panels pane — and
/// those three copies are exactly where a new panel half-ships: visible on
/// desktop, missing on mobile, inert in the manage sheet, each failure looking
/// correct on its own screen. One source, one matrix test.
///
/// Takes predicates rather than an `AuthSession` so it stays a leaf and is
/// unit-testable across the whole module × permission matrix without building a
/// session. Callers pass `company.moduleEnabled` and `company.can`.
///
/// **The two Drift-backed panels carry a permission gate the six server-fed
/// ones do not**, and that asymmetry is deliberate. The list panels render
/// dashboard data the API has already permission-scoped, so an empty card
/// honestly means "nothing to show". [DashboardKind.taskCalendar] and
/// [DashboardKind.invoicesAndQuotes] read the **local** tables: a user without
/// `view_task` has no tasks in Drift at all, so the calendar would paint every
/// day unbooked — not an absence of data but a positive claim that the user is
/// free all month — and a user without `view_invoice` / `view_quote` would get
/// a strip of seven confident zeroes. Hiding them is the only honest option.
/// `RunningTimerPill` gates a global task surface on the same key for the same
/// reason.
Set<String> enabledPanelKinds({
  required bool Function(EntityType) moduleOn,
  required bool Function(String) can,
}) => <String>{
  if (moduleOn(EntityType.invoice)) DashboardKind.pastDue,
  if (moduleOn(EntityType.invoice)) DashboardKind.upcomingInvoices,
  if (moduleOn(EntityType.payment)) DashboardKind.recentPayments,
  if (moduleOn(EntityType.quote)) DashboardKind.upcomingQuotes,
  if (moduleOn(EntityType.quote)) DashboardKind.expiredQuotes,
  if (moduleOn(EntityType.recurringInvoice)) DashboardKind.upcomingRecurring,
  if (moduleOn(EntityType.task) && can('view_task')) DashboardKind.taskCalendar,
  if (billingPipelineHalves(moduleOn: moduleOn, can: can).isNotEmpty)
    DashboardKind.invoicesAndQuotes,
};

/// Which halves the Invoices & Quotes panel may read, as
/// `(invoices, quotes)`.
///
/// Lives here, beside the gate it feeds, so the module × permission rule stays
/// in **one** place: the panel needs to know not just *whether* to render but
/// *which* entities participate — which tabs exist, which streams to open,
/// which footer links to offer — and re-deriving that inside the widget would
/// be the fourth copy this file exists to prevent.
({bool invoices, bool quotes}) billingPipelineHalves({
  required bool Function(EntityType) moduleOn,
  required bool Function(String) can,
}) => (
  invoices: moduleOn(EntityType.invoice) && can('view_invoice'),
  quotes: moduleOn(EntityType.quote) && can('view_quote'),
);

extension BillingPipelineHalves on ({bool invoices, bool quotes}) {
  bool get isNotEmpty => invoices || quotes;
}
