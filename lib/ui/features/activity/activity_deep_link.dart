import 'package:admin/data/models/domain/dashboard/dashboard_activity.dart';

/// Most-specific deep-link for an activity row, or null for system-only
/// activities with no entity reference. Top-level (not a screen method) so the
/// route mapping is directly testable. Document refs precede the party
/// (client/vendor) fallbacks — an "invoice created" row should open the
/// invoice, not the client.
String? activityDeepLinkTarget(DashboardActivity a) {
  if (a.invoiceId != null) return '/invoices/${a.invoiceId}';
  if (a.quoteId != null) return '/quotes/${a.quoteId}';
  if (a.creditId != null) return '/credits/${a.creditId}';
  if (a.paymentId != null) return '/payments/${a.paymentId}';
  if (a.recurringInvoiceId != null) {
    return '/recurring_invoices/${a.recurringInvoiceId}';
  }
  if (a.expenseId != null) return '/expenses/${a.expenseId}';
  if (a.recurringExpenseId != null) {
    return '/recurring_expenses/${a.recurringExpenseId}';
  }
  if (a.taskId != null) return '/tasks/${a.taskId}';
  if (a.purchaseOrderId != null) return '/purchase_orders/${a.purchaseOrderId}';
  // Payment links live under settings but have a real detail screen.
  if (a.subscriptionId != null) {
    return '/settings/payment_links/${a.subscriptionId}';
  }
  if (a.vendorId != null) return '/vendors/${a.vendorId}';
  if (a.clientId != null) return '/clients/${a.clientId}';
  return null;
}
