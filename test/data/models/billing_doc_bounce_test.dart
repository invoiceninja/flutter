import 'package:admin/data/models/api/invoice_api_model.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards `hasBouncedInvitation` — the getter that drives the red bounce
/// badge on billing-doc list/detail status pills. Defined identically on
/// invoice/quote/credit/PO/recurring; Invoice is the representative case.
Invoice _invoiceWith(List<Map<String, dynamic>> invitations) => Invoice.fromApi(
  InvoiceApi.fromJson({
    'id': 'inv1',
    'status_id': '2',
    'invitations': invitations,
  }),
);

void main() {
  group('Invoice.hasBouncedInvitation', () {
    test('false when there are no invitations', () {
      expect(_invoiceWith(const []).hasBouncedInvitation, isFalse);
    });

    test('false for a clean delivered invitation', () {
      final inv = _invoiceWith([
        {'id': 'i1', 'email_status': 'delivered', 'sent_date': '2026-05-01'},
      ]);
      expect(inv.hasBouncedInvitation, isFalse);
    });

    test('false for a delivered invitation whose email_error holds the '
        'MTA success line', () {
      // Every webhook ESP stores the delivery `Details` in email_error, so
      // reading a non-empty email_error as a bounce badged every delivered
      // document (beta report: "all emails indicate they have bounced").
      final inv = _invoiceWith([
        {
          'id': 'i1',
          'email_status': 'delivered',
          'email_error': 'smtp;250 2.0.0 OK 1615496594 z6si',
          'sent_date': '2026-05-01',
        },
      ]);
      expect(inv.hasBouncedInvitation, isFalse);
    });

    test('true when an invitation drew a spam complaint', () {
      final inv = _invoiceWith([
        {'id': 'i1', 'email_status': 'spam'},
      ]);
      expect(inv.hasBouncedInvitation, isTrue);
    });

    test('true when an invitation status is bounced', () {
      final inv = _invoiceWith([
        {'id': 'i1', 'email_status': 'delivered'},
        {'id': 'i2', 'email_status': 'bounced'},
      ]);
      expect(inv.hasBouncedInvitation, isTrue);
    });

    test('true when an invitation carries a delivery error', () {
      final inv = _invoiceWith([
        {'id': 'i1', 'email_error': 'mailbox full'},
      ]);
      expect(inv.hasBouncedInvitation, isTrue);
    });

    test('true when status is error even without an error string', () {
      final inv = _invoiceWith([
        {'id': 'i1', 'email_status': 'error'},
      ]);
      expect(inv.hasBouncedInvitation, isTrue);
    });
  });
}
