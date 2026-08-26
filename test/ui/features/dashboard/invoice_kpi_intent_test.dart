import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/invoice_status.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/ui/features/dashboard/views/dashboard_screen.dart';

void main() {
  group('buildInvoiceKpiIntent', () {
    const start = Date(2026, 5, 1);
    const end = Date(2026, 5, 31);

    test('overdue carries only overdue=true — never a date_range window', () {
      // Regression: the Overdue KPI deep-link used to attach the
      // dashboard period as a `date_range` on the invoice *issue* date,
      // so the destination list filtered every overdue invoice out
      // (overdue invoices are old; their issue date rarely falls inside
      // the current window) and showed nothing — while a manual
      // `overdue:true` filter showed them. Overdue is as-of-today and
      // period-independent, matching the Past Due panel.
      final intent = buildInvoiceKpiIntent(
        overdue: true,
        isAllTimeRange: false,
        start: start,
        end: end,
      );

      expect(intent.extraFilters, {
        'overdue': {'true'},
      });
      expect(intent.extraFilters.containsKey('date_range'), isFalse);
      // Parity with `_pastDueInvoicesIntent` / the `sort=due_date|asc`
      // dashboard query.
      expect(intent.sortField, 'due_date');
      expect(intent.sortAscending, isTrue);
    });

    // Regression: this used to emit `client_status: {unpaid}`, which the
    // invoices list registers no key for and `InvoiceRepository.watchPage` has
    // no local mirror for — so it narrowed only the network fetch while the
    // Drift watch the list renders from ignored it. The user landed on an
    // unfiltered list (paid / draft / cancelled included) with no chip and a
    // lit "clear filters" icon, and the phantom filter persisted to nav_state.
    test('outstanding carries a renderable status_id + the date window', () {
      final intent = buildInvoiceKpiIntent(
        overdue: false,
        isAllTimeRange: false,
        start: start,
        end: end,
      );

      // Sent + partial IS "unpaid" — the same definition `InvoiceDao`'s own
      // `unpaid` badge mode uses — and `status_id` is a real, chip-rendering,
      // locally-mirrored filter.
      expect(intent.extraFilters['status_id'], {
        InvoiceStatus.sent.wireId,
        InvoiceStatus.partial.wireId,
      });
      expect(intent.extraFilters.containsKey('client_status'), isFalse);
      expect(intent.extraFilters['date_range'], {'date,2026-05-01,2026-05-31'});
    });

    test('outstanding omits the window on the all-time preset', () {
      final intent = buildInvoiceKpiIntent(
        overdue: false,
        isAllTimeRange: true,
        start: start,
        end: end,
      );

      expect(intent.extraFilters, {
        'status_id': {InvoiceStatus.sent.wireId, InvoiceStatus.partial.wireId},
      });
      expect(intent.extraFilters.containsKey('date_range'), isFalse);
    });
  });
}
