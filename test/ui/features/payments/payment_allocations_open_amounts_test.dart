import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/api/invoice_api_model.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/data/models/domain/payment.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/invoice_repository.dart';
import 'package:admin/ui/features/payments/widgets/edit/payment_allocations_section.dart';

import '../../../_localization_helper.dart';

class _FakeAuth implements AuthRepository {
  @override
  String? get currentCompanyId => 'co';
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeInvoices implements InvoiceRepository {
  @override
  Stream<List<Invoice>> watchForClient({
    required String companyId,
    required String clientId,
  }) => Stream.value([
    Invoice.fromApi(
      const InvoiceApi(
        id: 'i1',
        number: '0001',
        clientId: 'c1',
        statusId: '2',
        amount: 1250,
        balance: 1250,
      ),
    ),
  ]);
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

void main() {
  // The edit view model lets an invoice allocation follow a re-typed payment
  // amount only up to the invoice's open amount — which only this section
  // knows, so it reports it on load and alongside every change.
  testWidgets(
    'loading and every change report the open amounts of its invoices',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final reported = <Map<String, Decimal>>[];
      List<Paymentable>? changed;
      await tester.pumpWidget(
        Provider<Services>.value(
          value: _FakeServices(),
          child: MaterialApp(
            theme: buildInTheme(InTheme.light),
            localizationsDelegates: kTestLocalizationsDelegates,
            supportedLocales: kTestSupportedLocales,
            home: Scaffold(
              body: PaymentAllocationsSection(
                kind: AllocationKind.invoice,
                paymentables: [
                  Paymentable(
                    invoiceId: 'i1',
                    amount: Decimal.parse('1250'),
                    refunded: Decimal.zero,
                  ),
                ],
                clientId: 'c1',
                paymentAmount: Decimal.zero,
                onChanged: (next) => changed = next,
                onOpenAmounts: reported.add,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Before any change: the invoice the form opened with (an invoice's
      // Enter Payment) is reported too, or a typed partial amount can't follow
      // it.
      expect(reported, isNotEmpty);
      expect(reported.first, {'i1': Decimal.parse('1250')});

      final amountField = find.widgetWithText(TextFormField, '1250');
      expect(amountField, findsOneWidget);
      await tester.enterText(amountField, '600');
      await tester.pump();

      expect(changed!.single.amount, Decimal.parse('600'));
      expect(reported.last, {'i1': Decimal.parse('1250')});
    },
  );
}
