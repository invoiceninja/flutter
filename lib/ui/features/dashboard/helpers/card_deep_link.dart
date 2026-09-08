import 'package:admin/data/models/domain/dashboard/dashboard_card_config.dart';
import 'package:admin/domain/entity_type.dart';

/// Where a configured dashboard card navigates when tapped, and how to
/// pre-filter the destination list.
///
/// [extraFilters] uses the same flat server-param vocabulary the KPI
/// deep-links use (written verbatim into the list VM's `extraFilters` →
/// query params). An empty map means "open the relevant list unfiltered" —
/// task/expense metrics have no faithful list filter today (see
/// `docs`/the plan's documented limitation), so they land on the bare list.
class CardListTarget {
  const CardListTarget(this.entity, this.route, this.extraFilters);

  /// For the dashboard's `_moduleOn` (module-enabled) gate.
  final EntityType entity;

  /// Router path, e.g. `/invoices`.
  final String route;

  /// Server-param → values. `{}` = bare list.
  final Map<String, Set<String>> extraFilters;
}

/// Best-effort field → list mapping. Invoices/payments/quotes get a faithful
/// pre-filter; task/expense metrics open their list unfiltered (no faithful
/// filter key exists yet). Exhaustive over [kDashboardCardFields].
CardListTarget cardListTarget(DashboardCardConfig config) {
  switch (config.field) {
    case 'active_invoices':
      // sent / partial / paid (matches the server metric's status set).
      return const CardListTarget(EntityType.invoice, '/invoices', {
        'status_id': {'2', '3', '4'},
      });
    case 'outstanding_invoices':
      // Same vocabulary as the fixed "Outstanding" KPI deep-link.
      return const CardListTarget(EntityType.invoice, '/invoices', {
        'client_status': {'unpaid'},
      });
    case 'completed_payments':
      return const CardListTarget(EntityType.payment, '/payments', {
        'client_status': {'completed'},
      });
    case 'refunded_payments':
      return const CardListTarget(EntityType.payment, '/payments', {
        'client_status': {'refunded', 'partially_refunded'},
      });
    case 'active_quotes':
      return const CardListTarget(EntityType.quote, '/quotes', {
        'client_status': {'sent', 'approved'},
      });
    case 'unapproved_quotes':
      return const CardListTarget(EntityType.quote, '/quotes', {
        'client_status': {'sent'},
      });
    case 'logged_tasks':
    case 'invoiced_tasks':
    case 'paid_tasks':
    // The 2026-08 task metrics. `overdue_tasks` and `tasks_due` DO have server
    // filters (`TaskFilters::overdue`, and a due-date range), but pointing at
    // one before the list has a matching local Drift predicate gives a list
    // that narrows on the fetch and then widens again from cache — worse than
    // no filter. Upgrade `overdue_tasks` to `{'overdue': {'true'}}` when the
    // task due-date work lands its local predicate and status tab.
    case 'task_estimated_duration':
    case 'task_remaining_estimated_duration':
    case 'unestimated_tasks':
    case 'tasks_over_estimate':
    case 'overdue_tasks':
    case 'tasks_due':
      // No faithful task list filter today → bare list.
      return const CardListTarget(EntityType.task, '/tasks', {});
    case 'logged_expenses':
    case 'pending_expenses':
    case 'invoiced_expenses':
    case 'invoice_paid_expenses':
      // No faithful expense list filter today → bare list.
      return const CardListTarget(EntityType.expense, '/expenses', {});
    default:
      // Unreachable for kDashboardCardFields; default to a safe bare list.
      return const CardListTarget(EntityType.invoice, '/invoices', {});
  }
}
