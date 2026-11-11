import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/domain/payment.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/invoice_repository.dart';
import 'package:admin/domain/columns/payment_columns.dart';
import 'package:admin/domain/columns/payment_invoice_numbers_cell.dart';
import 'package:admin/ui/core/widgets/invoice_name_label.dart';
import 'package:admin/ui/features/payments/view_models/payment_edit_view_model.dart';

// No session, so the `InvoiceNameLabel` fallback renders the invoice id
// itself — enough to tell it from a number read off the payment. Every other
// `Services` member throws, so a cell that reached for the invoice repository
// (a request per row) fails the test.
class _FakeAuth implements AuthRepository {
  @override
  final ValueListenable<AuthSession?> session = ValueNotifier(null);
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeInvoices implements InvoiceRepository {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeServices implements Services {
  @override
  final AuthRepository auth = _FakeAuth();
  @override
  final InvoiceRepository invoices = _FakeInvoices();
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Paymentable _inv(String id) =>
    Paymentable(invoiceId: id, amount: Decimal.one, refunded: Decimal.zero);

Paymentable _credit(String id) =>
    Paymentable(creditId: id, amount: Decimal.one, refunded: Decimal.zero);

void main() {
  PaymentInvoiceRef ref(String id, String number) => PaymentInvoiceRef(
    id: id,
    number: number,
    amount: Decimal.one,
    balance: Decimal.zero,
    paidToDate: Decimal.one,
  );

  Future<void> pump(
    WidgetTester tester,
    List<Paymentable> paymentables, {
    List<PaymentInvoiceRef> invoices = const [],
  }) => tester.pumpWidget(
    Provider<Services>.value(
      value: _FakeServices(),
      child: MaterialApp(
        theme: buildInTheme(InTheme.light),
        home: Scaffold(
          body: SizedBox(
            width: 160,
            child: PaymentInvoiceNumbersCell(
              payment: emptyPayment().copyWith(
                paymentables: paymentables,
                invoices: invoices,
              ),
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('a payment applied to nothing shows the dash', (tester) async {
    await pump(tester, [_credit('c1')]);
    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('the number comes off the payment, with no lookup', (
    tester,
  ) async {
    await pump(
      tester,
      [_inv('i1'), _credit('c1')],
      invoices: [ref('i1', 'INV-0012')],
    );
    expect(find.text('INV-0012'), findsOneWidget);
    expect(find.byType(InvoiceNameLabel), findsNothing);
    expect(find.textContaining('+'), findsNothing);
  });

  testWidgets('several invoices name the first and count the rest', (
    tester,
  ) async {
    await pump(
      tester,
      [_inv('i1'), _inv('i2'), _inv('i1'), _inv('i3')],
      invoices: [ref('i2', 'INV-2'), ref('i1', 'INV-1'), ref('i3', 'INV-3')],
    );
    expect(find.text('INV-1'), findsOneWidget);
    expect(find.text('+2'), findsOneWidget);
    expect(find.byType(InvoiceNameLabel), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an invoice the payment has no reference for is looked up', (
    tester,
  ) async {
    await pump(tester, [_inv('i1')]);
    expect(find.byType(InvoiceNameLabel), findsOneWidget);
    expect(find.text('i1'), findsOneWidget);
  });

  test('the copyable value is the numbers the payment carries', () {
    final column = paymentColumnsById['invoice_number']!;
    final payment = emptyPayment().copyWith(
      paymentables: [_inv('i1'), _inv('i2'), _inv('i3')],
      invoices: [ref('i1', 'INV-1'), ref('i2', 'INV-2')],
    );
    expect(column.valueBuilder!(payment), 'INV-1, INV-2');
    expect(column.valueBuilder!(emptyPayment()), '');
  });

  test('the column keeps the old app\'s id and never sorts', () {
    final column = paymentColumnsById['invoice_number']!;
    expect(column.labelKey, 'invoice_number');
    expect(column.sortable, isFalse);
  });
}
