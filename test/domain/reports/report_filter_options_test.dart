import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/schedule_constants.dart';
import 'package:admin/domain/reports/report_filter_options.dart';

void main() {
  test('every email_report that shows a status field has report-aware status '
      'options (else it silently falls back to a free-text box)', () {
    final reportsWithStatus = kEmailReportFieldsByReport.entries
        .where((e) => e.value.contains(EmailReportField.status))
        .map((e) => e.key);
    // Guard against an empty filter masking a regression.
    expect(reportsWithStatus, isNotEmpty);
    for (final report in reportsWithStatus) {
      expect(
        reportStatusOptions(report),
        isNotNull,
        reason:
            'report "$report" declares a status field but reportStatusOptions '
            'returns null → the schedule editor shows free text, not chips',
      );
    }
  });

  test('scheduler "tasks" shares the reports-screen "task" status options', () {
    expect(reportStatusOptions('tasks'), isNotNull);
    expect(reportStatusOptions('tasks'), reportStatusOptions('task'));
  });

  // The quote report's status filter learned `cancelled` in 5.13.44
  // (`BaseExport::addQuoteStatusFilter`). On an older server the value matches
  // no arm and the filter drops out — every quote under a "Cancelled" heading.
  test('quote "cancelled" is offered only where the server filters it', () {
    for (final report in ['quote', 'quote_item']) {
      List<String> ids({required bool filters}) => [
        for (final o in reportStatusOptions(
          report,
          quoteCancelledFilters: filters,
        )!)
          o.id,
      ];
      expect(ids(filters: false), isNot(contains('cancelled')), reason: report);
      expect(ids(filters: true), contains('cancelled'), reason: report);
    }
  });
}
