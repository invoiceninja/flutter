import 'package:admin/data/models/domain/enabled_modules.dart';
import 'package:admin/data/models/domain/report_definition.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/domain/reports/report_registry.dart';

/// Whether [definition] is a report [company] may open.
///
/// One rule for every way into a report — the gallery, the switcher, the
/// command palette and the route itself — because a report hidden from the
/// list and still reachable by its address is not hidden.
///
/// A per-entity report (Invoices, Quotes, Tasks…) needs its own permission
/// and its module switched on. A general financial report carries
/// `view_reports` and stays whatever its [ReportDefinition.icon] is: that
/// icon is a glyph hint, not a capability — profit and loss borrows the
/// invoice icon and is not an invoices-module feature.
///
/// A null company (no session yet) allows everything; the shell does not
/// reach this screen without one.
bool canOpenReport(ReportDefinition definition, AuthCompany? company) {
  if (company == null) return true;
  if (!company.can(definition.requiredPermission)) return false;
  if (definition.requiredPermission == 'view_reports') return true;
  return isEntityModuleEnabledForCompany(
    definition.icon,
    company.enabledModules,
  );
}

/// The reports [company] may open, in registry order.
List<ReportDefinition> availableReports(AuthCompany? company) => [
  for (final definition in kReportDefinitions)
    if (canOpenReport(definition, company)) definition,
];

/// The definition for [identifier] when it names a report [company] may
/// open; null for an unknown id or one that is not theirs — both of which a
/// route answers by going back to the gallery.
ReportDefinition? openableReport(String? identifier, AuthCompany? company) {
  if (identifier == null) return null;
  for (final definition in kReportDefinitions) {
    if (definition.identifier == identifier) {
      return canOpenReport(definition, company) ? definition : null;
    }
  }
  return null;
}

/// The order reports are shown in within a category: the ones reached for
/// most first, a document before its line items.
///
/// The registry is in identifier order — right for a lookup table, wrong for
/// a page a person scans, where it put Credits ahead of Invoices. A report
/// this list does not name keeps its registry position after the ones it
/// does, so a new report appears without an edit here.
const List<String> _kGalleryOrder = [
  'invoice',
  'payment',
  'quote',
  'credit',
  'recurring_invoice',
  'invoice_item',
  'quote_item',
  'recurring_invoice_item',
  'product_sales',
  'client_sales_report',
  'user_sales_report',
  'aged_receivable_summary_report',
  'aged_receivable_detailed_report',
  'client_balance_report',
  'expense',
  'purchase_order',
  'purchase_order_item',
  'vendor',
  'profitloss',
  'tax_summary_report',
  'tax_period_report',
  'task',
  'project',
  'client',
  'contact',
  'product',
  'document',
  'activity',
];

/// [definitions] in the order a gallery shows them — see [_kGalleryOrder].
List<ReportDefinition> reportsInGalleryOrder(
  Iterable<ReportDefinition> definitions,
) {
  final list = definitions.toList();
  int rank(ReportDefinition d) {
    final at = _kGalleryOrder.indexOf(d.identifier);
    return at < 0 ? _kGalleryOrder.length : at;
  }

  final indexed = [for (var i = 0; i < list.length; i++) (i, list[i])]
    ..sort((a, b) {
      final byRank = rank(a.$2).compareTo(rank(b.$2));
      return byRank != 0 ? byRank : a.$1.compareTo(b.$1);
    });
  return [for (final e in indexed) e.$2];
}
