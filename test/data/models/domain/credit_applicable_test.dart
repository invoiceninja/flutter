import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/credit_api_model.dart';
import 'package:admin/data/models/domain/credit.dart';

/// Guards [Credit.isApplicableForPayment] — the client-side mirror of the
/// backend `CreditFilters::applicable` gate (React sends `?applicable=true`)
/// used by the payment allocation credit picker. Only SENT/PARTIAL credits
/// with a positive balance and an unelapsed due date may be applied; drafts,
/// applied, zero-balance, archived/deleted, and past-due credits must not
/// appear as selectable targets (the server would apply nothing).
void main() {
  Credit credit({
    String statusId = '2', // sent
    String amount = '100',
    String balance = '100',
    String dueDate = '',
    bool isDeleted = false,
    int archivedAt = 0,
  }) => Credit.fromApi(
    CreditApi(
      id: 'c1',
      statusId: statusId,
      amount: amount,
      balance: balance,
      dueDate: dueDate,
      isDeleted: isDeleted,
      archivedAt: archivedAt,
    ),
  );

  test('SENT credit with positive balance is applicable', () {
    expect(
      credit(statusId: '2', balance: '100').isApplicableForPayment,
      isTrue,
    );
  });

  test('PARTIAL credit with positive balance is applicable', () {
    expect(credit(statusId: '3', balance: '40').isApplicableForPayment, isTrue);
  });

  test('DRAFT credit (amount > 0, balance 0) is NOT applicable — the bug', () {
    // `balanceOrAmount` reports the full amount for a draft, which is what let
    // drafts leak into the picker; the gate must still exclude them because the
    // server can apply nothing against a zero balance.
    final c = credit(statusId: '1', amount: '1000', balance: '0');
    expect(c.balanceOrAmount > Decimal.zero, isTrue); // reports amount...
    expect(c.isApplicableForPayment, isFalse); // ...but not applicable
  });

  test('APPLIED credit is NOT applicable', () {
    expect(
      credit(statusId: '4', balance: '100').isApplicableForPayment,
      isFalse,
    );
  });

  test('SENT credit with zero balance is NOT applicable', () {
    expect(credit(statusId: '2', balance: '0').isApplicableForPayment, isFalse);
  });

  test('archived credit is NOT applicable', () {
    expect(credit(archivedAt: 1700000000).isApplicableForPayment, isFalse);
  });

  test('deleted credit is NOT applicable', () {
    expect(credit(isDeleted: true).isApplicableForPayment, isFalse);
  });

  test('past-due credit is NOT applicable', () {
    expect(credit(dueDate: '2000-01-01').isApplicableForPayment, isFalse);
  });

  test('future or empty due date is applicable', () {
    expect(credit(dueDate: '2999-01-01').isApplicableForPayment, isTrue);
    expect(credit(dueDate: '').isApplicableForPayment, isTrue);
  });
}
