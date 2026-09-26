// The expense Amount card's tax tiers. Their count used to be latched on the
// FIRST build — which on a new expense ran before the company row arrived — so
// a company with expense taxes enabled kept the "tax rates are disabled" hint
// and no tax inputs at all.

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/ui/core/edit/entity_edit_field.dart';
import 'package:admin/ui/features/expenses/widgets/edit/expense_tax_section.dart';

import '../../billing_shared/edit/_billing_edit_harness.dart';
import '../../shell/_shell_test_helpers.dart';

void main() {
  Widget section() => ExpenseTaxSection(
    companyId: kHarnessCompanyId,
    amount: Decimal.zero,
    amountError: null,
    taxNames: const ['', '', ''],
    taxRates: [Decimal.zero, Decimal.zero, Decimal.zero],
    taxAmounts: [Decimal.zero, Decimal.zero, Decimal.zero],
    usesInclusiveTaxes: false,
    calculateTaxByAmount: false,
    onAmountChanged: (_) {},
    onTaxNameChanged: (_, _) {},
    onTaxRateChanged: (_, _) {},
    onTaxAmountChanged: (_, _) {},
    onUsesInclusiveTaxesChanged: (_) {},
    onCalculateByAmountChanged: (_) {},
  );

  Future<void> setRates(ShellFixture fixture, int enabled) async {
    final db = fixture.db;
    await (db.update(db.companies)
          ..where((c) => c.id.equals(kHarnessCompanyId)))
        .write(CompaniesCompanion(enabledExpenseTaxRates: Value(enabled)));
  }

  /// The amount field, plus a name + rate pair per tier (no bundled rates, so
  /// each tier is the freeform pair).
  int tiers(WidgetTester tester) =>
      (tester.widgetList(find.byType(EntityEditField)).length - 1) ~/ 2;

  testWidgets('grows when the company answers after the first frame, and '
      'never shrinks', (tester) async {
    setWindow(tester, 1200);
    final fixture = await buildFixture(
      closeStreamsSynchronously: true,
      companies: const [FakeCompany(id: kHarnessCompanyId, name: 'Co')],
    );
    addTearDown(fixture.dispose);

    await tester.pumpWidget(wrapWithShell(fixture.services, section()));
    await settle(tester);
    expect(tiers(tester), 0);
    expect(find.text('Item tax rates are disabled'), findsOneWidget);

    await setRates(fixture, 2);
    await settle(tester);
    expect(tiers(tester), 2);
    expect(find.text('Item tax rates are disabled'), findsNothing);

    await setRates(fixture, 1);
    await settle(tester);
    expect(tiers(tester), 2);
    await unmount(tester, fixture);
  });
}
