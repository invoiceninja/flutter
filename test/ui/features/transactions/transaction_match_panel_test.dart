import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/bank_transaction_api_model.dart';
import 'package:admin/data/models/domain/bank_transaction.dart';
import 'package:admin/ui/features/transactions/widgets/transaction_match_panel.dart';

import '../shell/_shell_test_helpers.dart';

/// A conversion only changes the transaction locally once the server
/// answers, so while it is queued the panel must not offer to convert it
/// again (invoiceninja/ui#3396 — the sequential workflow made the double
/// convert one tap away).
void main() {
  final tx = BankTransaction.fromApi(
    const BankTransactionApi(
      id: 'tx_1',
      description: 'Coffee',
      baseType: kTransactionTypeDebit,
      statusId: kTransactionStatusUnmatched,
      updatedAt: 1700000000,
    ),
  );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('a queued conversion replaces the tabs with a pending note', (
    tester,
  ) async {
    final fixture = await buildFixture(
      companies: [const FakeCompany(id: 'co1', name: 'Co')],
    );
    addTearDown(fixture.dispose);
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        Scaffold(
          body: SingleChildScrollView(
            child: TransactionMatchPanel(transaction: tx),
          ),
        ),
      ),
    );
    await settle(tester);
    expect(
      find.byKey(const Key('transaction_conversion_pending')),
      findsNothing,
    );

    await tester.runAsync(
      () => fixture.services.bankTransactions.matchToExpense(
        companyId: 'co1',
        transactionId: 'tx_1',
        vendorId: 'v1',
        categoryId: '',
      ),
    );
    await settle(tester);

    expect(
      find.byKey(const Key('transaction_conversion_pending')),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
