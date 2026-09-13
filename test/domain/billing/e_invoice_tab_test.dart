import 'package:flutter_test/flutter_test.dart';

import 'package:admin/domain/billing/e_invoice_tab.dart';

void main() {
  group('eInvoiceTabVisible', () {
    test('a company that has not enabled e-invoicing does not get the tab', () {
      expect(eInvoiceTabVisible(const {}), isFalse);
      expect(eInvoiceTabVisible(const {'enable_e_invoice': false}), isFalse);
    });

    test('the switch shows it', () {
      expect(eInvoiceTabVisible(const {'enable_e_invoice': true}), isTrue);
    });

    test('PEPPOL shows it even with the switch untouched', () {
      // `enable_e_invoice` defaults false and `e_invoice_type` defaults to
      // EN16931, so the type is NOT covered by the switch — React's own gate
      // ORs the two for exactly this reason.
      expect(eInvoiceTabVisible(const {'e_invoice_type': 'PEPPOL'}), isTrue);
      expect(
        eInvoiceTabVisible(const {
          'enable_e_invoice': false,
          'e_invoice_type': 'PEPPOL',
        }),
        isTrue,
      );
    });

    test('a non-PEPPOL type on its own does not', () {
      expect(eInvoiceTabVisible(const {'e_invoice_type': 'EN16931'}), isFalse);
      expect(
        eInvoiceTabVisible(const {'e_invoice_type': 'VERIFACTU'}),
        isFalse,
      );
    });

    test('an unreadable company row resolves to hidden, not shown', () {
      // `SettingsRepository.resolved` returns `{}` for a company row it can't
      // read, and that is the right answer: a company nothing is known about
      // is not filing e-invoices. The "before it resolves" state is the
      // layout's own `false`, not a value this function can express — see
      // `eInvoiceTabVisible`'s doc for why the tab arrives rather than
      // vanishes.
      expect(eInvoiceTabVisible(const <String, dynamic>{}), isFalse);
    });

    test('the server sends a real bool, and the check is strict', () {
      // `CompanySettings.php` casts `enable_e_invoice` to `bool`, so a
      // truthy string or 1 is not a shape this can receive; matching React's
      // `=== true` keeps the two clients answering identically.
      expect(eInvoiceTabVisible(const {'enable_e_invoice': 'true'}), isFalse);
      expect(eInvoiceTabVisible(const {'enable_e_invoice': 1}), isFalse);
    });
  });
}
