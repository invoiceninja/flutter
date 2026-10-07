import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/invoice_api_model.dart';
import 'package:admin/data/models/api/quote_api_model.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/data/models/domain/quote.dart';
import 'package:admin/ui/features/dashboard/helpers/attention_record_verdict.dart';

Invoice _invoice(
  String statusId, {
  double balance = 100,
  bool deleted = false,
}) => Invoice.fromApi(
  InvoiceApi(
    id: 'i1',
    statusId: statusId,
    balance: balance,
    amount: 100,
    isDeleted: deleted,
  ),
);

Quote _quote(String statusId, {bool deleted = false, String invoiceId = ''}) =>
    Quote.fromApi(
      QuoteApi(
        id: 'q1',
        statusId: statusId,
        isDeleted: deleted,
        invoiceId: invoiceId,
      ),
    );

/// A dashboard row is a cached copy of the server's list, so its action runs
/// on the record as it is *now*. These are the three answers that re-read can
/// give.
void main() {
  group('invoiceVerdict', () {
    test('an invoice still owed is acted on', () {
      expect(invoiceVerdict(_invoice('2')), AttentionVerdict.act);
      expect(invoiceVerdict(_invoice('3', balance: 40)), AttentionVerdict.act);
    });

    test('paid, cancelled, reversed or deleted is resolved', () {
      expect(
        invoiceVerdict(_invoice('4', balance: 0)),
        AttentionVerdict.resolved,
      );
      expect(invoiceVerdict(_invoice('5')), AttentionVerdict.resolved);
      expect(invoiceVerdict(_invoice('6')), AttentionVerdict.resolved);
      expect(
        invoiceVerdict(_invoice('2', deleted: true)),
        AttentionVerdict.resolved,
      );
    });

    // The status can lag the balance by a request: a payment that settled the
    // invoice in the portal a moment ago.
    test('a zero balance is resolved whatever the status says', () {
      expect(
        invoiceVerdict(_invoice('2', balance: 0)),
        AttentionVerdict.resolved,
      );
    });

    test('a record that is not on the device and could not be fetched is '
        'unavailable — never "resolved"', () {
      expect(invoiceVerdict(null), AttentionVerdict.unavailable);
    });
  });

  group('quoteVerdict', () {
    test('a sent quote is still worth a reminder', () {
      expect(quoteVerdict(_quote('2')), AttentionVerdict.act);
    });

    test('approved, converted, rejected, a draft or deleted is resolved', () {
      for (final status in ['1', '3', '4', '5']) {
        expect(
          quoteVerdict(_quote(status)),
          AttentionVerdict.resolved,
          reason: 'status $status',
        );
      }
      expect(
        quoteVerdict(_quote('2', deleted: true)),
        AttentionVerdict.resolved,
      );
    });

    // Converted is a status on some servers and only a linked invoice on
    // others; either way there is nothing left to remind about.
    test('a sent quote already turned into an invoice is resolved', () {
      expect(
        quoteVerdict(_quote('2', invoiceId: 'inv9')),
        AttentionVerdict.resolved,
      );
    });

    test('unfetchable is unavailable', () {
      expect(quoteVerdict(null), AttentionVerdict.unavailable);
    });
  });
}
