// The document Taxes card on the billing edit screens. Its tier count used to
// be latched on the FIRST build — which on a new document ran before the
// company row arrived — so a company with document taxes enabled got zero
// tiers and, with no surcharges, no card at all: and with it no inclusive-tax
// switch, which lives nowhere else.

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/ui/core/edit/entity_edit_field.dart';
import 'package:admin/ui/features/billing_shared/edit/billing_tax_surcharge_section.dart';

import '../../shell/_shell_test_helpers.dart';
import '_billing_edit_harness.dart';

void main() {
  Future<ShellFixture> fixtureWith(
    WidgetTester tester, {
    int enabledTaxRates = 0,
    int enabledItemTaxRates = 0,
  }) async {
    setWindow(tester, 1200);
    final fixture = await buildFixture(
      closeStreamsSynchronously: true,
      companies: const [FakeCompany(id: kHarnessCompanyId, name: 'Co')],
    );
    addTearDown(fixture.dispose);
    await setRates(
      fixture,
      enabledTaxRates: enabledTaxRates,
      enabledItemTaxRates: enabledItemTaxRates,
    );
    return fixture;
  }

  Widget section({bool inclusive = false}) => BillingTaxSurchargeSection(
    companyId: kHarnessCompanyId,
    taxRows: [
      for (var i = 0; i < 3; i++)
        (name: '', rate: Decimal.zero, onName: (_) {}, onRate: (_) {}),
    ],
    usesInclusiveTaxes: inclusive,
    onInclusiveChanged: (_) {},
    surcharges: [
      for (var i = 0; i < 4; i++) (amount: Decimal.zero, onAmount: (_) {}),
    ],
  );

  /// Two fields (name + rate) per tier; nothing else in the card is one.
  int tiers(WidgetTester tester) =>
      tester.widgetList(find.byType(EntityEditField)).length ~/ 2;

  Finder inclusiveSwitch() =>
      find.widgetWithText(SwitchListTile, 'Inclusive Taxes');

  testWidgets('shows the company\'s enabled tiers', (tester) async {
    final fixture = await fixtureWith(tester, enabledTaxRates: 2);
    await tester.pumpWidget(wrapWithShell(fixture.services, section()));
    await settle(tester);
    expect(tiers(tester), 2);
    expect(inclusiveSwitch(), findsOneWidget);
    await unmount(tester, fixture);
  });

  testWidgets('grows when the company answers after the first frame, and '
      'never shrinks', (tester) async {
    final fixture = await fixtureWith(tester, enabledItemTaxRates: 1);
    await tester.pumpWidget(wrapWithShell(fixture.services, section()));
    await settle(tester);
    expect(tiers(tester), 0);

    await setRates(fixture, enabledTaxRates: 2, enabledItemTaxRates: 1);
    await settle(tester);
    expect(tiers(tester), 2);

    await setRates(fixture, enabledTaxRates: 1, enabledItemTaxRates: 1);
    await settle(tester);
    expect(tiers(tester), 2, reason: 'the card has no way to remove a tier');
    await unmount(tester, fixture);
  });

  testWidgets('keeps the inclusive switch while it means something', (
    tester,
  ) async {
    final fixture = await fixtureWith(tester, enabledItemTaxRates: 1);
    await tester.pumpWidget(wrapWithShell(fixture.services, section()));
    await settle(tester);
    expect(inclusiveSwitch(), findsOneWidget, reason: 'the lines are taxed');
    await unmount(tester, fixture);
  });

  testWidgets('keeps the inclusive switch on an inclusive document', (
    tester,
  ) async {
    final fixture = await fixtureWith(tester);
    await tester.pumpWidget(
      wrapWithShell(fixture.services, section(inclusive: true)),
    );
    await settle(tester);
    expect(inclusiveSwitch(), findsOneWidget);
    await unmount(tester, fixture);
  });

  testWidgets('collapses when nothing in it applies', (tester) async {
    final fixture = await fixtureWith(tester);
    await tester.pumpWidget(wrapWithShell(fixture.services, section()));
    await settle(tester);
    expect(inclusiveSwitch(), findsNothing);
    expect(find.text('Taxes'), findsNothing);
    await unmount(tester, fixture);
  });
}

Future<void> setRates(
  ShellFixture fixture, {
  required int enabledTaxRates,
  required int enabledItemTaxRates,
}) async {
  final db = fixture.db;
  await (db.update(
    db.companies,
  )..where((c) => c.id.equals(kHarnessCompanyId))).write(
    CompaniesCompanion(
      enabledTaxRates: Value(enabledTaxRates),
      enabledItemTaxRates: Value(enabledItemTaxRates),
    ),
  );
}
