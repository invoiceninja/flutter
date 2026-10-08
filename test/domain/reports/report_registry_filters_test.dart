import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/report_definition.dart';
import 'package:admin/domain/reports/report_filter_options.dart';
import 'package:admin/domain/reports/report_registry.dart';

/// The filters each report offers, pinned against the export that reads them.
///
/// The server validates almost none of these parameters and ignores the ones
/// an export does not use, so an offered filter that does nothing is
/// indistinguishable on screen from one that happened to match every row.
/// This table is the audit: each line was checked against the class named in
/// `routes/api.php` for that report.
void main() {
  List<ReportFilterField> fields(String id) =>
      reportDefinitionFor(id).filterFields;

  test('every report offers exactly what its export reads', () {
    const f = ReportFilterField.values;
    ReportFilterField of(String name) => f.byName(name);
    final expected = <String, List<String>>{
      'activity': ['dateRange', 'activityType'],
      'client': ['dateRange', 'tagsMulti', 'includeDeleted'],
      // ContactExport and DocumentExport never read `include_deleted`.
      'contact': ['dateRange'],
      'document': ['dateRange'],
      'credit': [
        'dateRange',
        'status',
        'clientIdsMulti',
        'tagsMulti',
        'includeDeleted',
      ],
      'expense': [
        'dateRange',
        'status',
        'clientsMulti',
        'vendorsMulti',
        'categoriesMulti',
        'projectsMulti',
        'tagsMulti',
        'includeDeleted',
      ],
      'invoice': [
        'dateRange',
        'status',
        'clientIdsMulti',
        'template',
        'pdfEmailAttachment',
        'documentEmailAttachment',
        'tagsMulti',
        'includeDeleted',
      ],
      'invoice_item': [
        'dateRange',
        'status',
        'clientIdsMulti',
        'productKey',
        'tagsMulti',
        'includeDeleted',
      ],
      // PurchaseOrderExport filters on `client_id`; it never reads `vendors`.
      'purchase_order': ['dateRange', 'status', 'tagsMulti', 'includeDeleted'],
      'purchase_order_item': [
        'dateRange',
        'status',
        'productKey',
        'tagsMulti',
        'includeDeleted',
      ],
      'quote': [
        'dateRange',
        'status',
        'clientIdsMulti',
        'tagsMulti',
        'includeDeleted',
      ],
      'quote_item': [
        'dateRange',
        'status',
        'clientIdsMulti',
        'productKey',
        'tagsMulti',
        'includeDeleted',
      ],
      'recurring_invoice': [
        'dateRange',
        'status',
        'clientIdsMulti',
        'tagsMulti',
        'includeDeleted',
      ],
      'recurring_invoice_item': [
        'dateRange',
        'status',
        'clientIdsMulti',
        'productKey',
        'tagsMulti',
        'includeDeleted',
      ],
      // PaymentExport's only "include deleted" is about *applications*.
      'payment': ['dateRange', 'status', 'clientIdsMulti', 'tagsMulti'],
      'product': ['dateRange', 'tagsMulti', 'includeDeleted'],
      'product_sales': ['dateRange', 'clientSingle', 'productKey'],
      // TaskExport has no project filter.
      'task': [
        'dateRange',
        'status',
        'clientIdsMulti',
        'tagsMulti',
        'includeDeleted',
      ],
      'vendor': ['dateRange', 'tagsMulti', 'includeDeleted'],
      // ProjectReport never calls addDateRange.
      'project': ['clientsMulti', 'projectsMulti', 'tagsMulti'],
      // ProfitLoss stores the other two switches and never reads them.
      'profitloss': ['dateRange', 'isIncomeBilled'],
      // filterByClients decodes ONE hashed `client_id`; given a `clients`
      // string it calls count() on it, which is a TypeError in PHP 8.
      'aged_receivable_detailed_report': ['dateRange', 'clientSingle'],
      // ARSummaryReport reads neither a range nor a client.
      'aged_receivable_summary_report': [],
      'client_balance_report': ['dateRange'],
      'client_sales_report': ['dateRange'],
      'tax_summary_report': ['dateRange', 'clientSingle'],
      'tax_period_report': ['dateRange', 'clientSingle', 'isIncomeBilled'],
      'user_sales_report': ['dateRange', 'clientSingle'],
    };

    expect(
      kReportDefinitions.map((d) => d.identifier).toSet(),
      expected.keys.toSet(),
      reason: 'a report was added or removed — audit its filters here',
    );
    for (final entry in expected.entries) {
      expect(fields(entry.key), [
        for (final name in entry.value) of(name),
      ], reason: entry.key);
    }
  });

  test('a report without a date key still honours its own range', () {
    // Profit & loss and tax period apply the range with their own semantics;
    // project and aged-receivable summary do not apply one at all.
    expect(reportDefinitionFor('profitloss').honoursDateRange, isTrue);
    expect(reportDefinitionFor('tax_period_report').honoursDateRange, isTrue);
    expect(reportDefinitionFor('project').honoursDateRange, isFalse);
    expect(
      reportDefinitionFor('aged_receivable_summary_report').honoursDateRange,
      isFalse,
    );
  });

  test('a report that names the date it filters on applies the range', () {
    for (final d in kReportDefinitions) {
      if (d.dateRangeKey != null) {
        expect(d.honoursDateRange, isTrue, reason: d.identifier);
      }
    }
  });

  test('every report with a status filter has a fixed option list', () {
    for (final d in kReportDefinitions) {
      if (!d.filterFields.contains(ReportFilterField.status)) continue;
      expect(
        reportStatusOptions(d.identifier),
        isNotNull,
        reason: '${d.identifier} would fall back to a free-text status',
      );
    }
  });

  test('no status option the server has no arm for', () {
    // An unmatched value leaves the server's filter empty, so the option
    // returns every row under its own heading.
    List<String> ids(String report) => [
      for (final o in reportStatusOptions(report)!) o.id,
    ];
    expect(ids('recurring_invoice'), ['active', 'paused', 'completed']);
    expect(ids('expense'), ['logged', 'pending', 'invoiced', 'paid', 'unpaid']);
    expect(ids('invoice'), [
      'draft',
      'sent',
      'paid',
      'unpaid',
      'overdue',
      'cancelled',
    ]);
  });
}
