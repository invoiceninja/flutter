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
/// **[DashboardKind.taskCalendar] carries a permission gate the other six do
/// not**, and that asymmetry is deliberate. The list panels render server-fed
/// dashboard data the API has already permission-scoped, so an empty card
/// honestly means "nothing to show". The task calendar renders the **local**
/// tasks table: a user without `view_task` has no tasks in Drift at all, so its
/// grid would paint every day unbooked — which is not an absence of data but a
/// positive claim that the user is free all month. Hiding it is the only
/// honest option. `RunningTimerPill` gates a global task surface on the same
/// key for the same reason.
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
};
