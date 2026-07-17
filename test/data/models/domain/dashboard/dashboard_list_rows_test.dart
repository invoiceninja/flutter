import 'package:admin/data/models/domain/dashboard/dashboard_list_rows.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('dashboard row client currency (#23)', () {
    test('invoice/quote/recurring read currency_id from client.settings, not '
        'a (never-sent) top-level currency_id', () {
      final client = {
        'id': 'c1',
        'name': 'Acme',
        'settings': {'currency_id': '3'}, // EUR override
      };
      expect(
        DashboardInvoiceRow.fromJson({'id': 'i1', 'client': client}).currencyId,
        '3',
      );
      expect(
        DashboardQuoteRow.fromJson({'id': 'q1', 'client': client}).currencyId,
        '3',
      );
      expect(
        DashboardRecurringInvoiceRow.fromJson({
          'id': 'r1',
          'client': client,
        }).currencyId,
        '3',
      );
    });

    test(
      'a client with no currency override yields empty (→ company currency)',
      () {
        final row = DashboardInvoiceRow.fromJson({
          'id': 'i1',
          'client': {
            'id': 'c1',
            'settings': {'other': 'x'},
          },
        });
        expect(row.currencyId, '');
      },
    );
  });
}
