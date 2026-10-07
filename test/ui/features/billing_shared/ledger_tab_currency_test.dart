// The ledger tab formats in the party's currency.
//
// It used to hand every amount to `Formatter.money` with no currency, which
// is the *company's*. A euro client's ledger read in dollars — one tab away
// from the same balance, in euros, on the record's standing card.

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/api/client_api_model.dart';
import 'package:admin/ui/features/billing_shared/ledger/ledger_tab.dart';

import '../../../_localization_helper.dart';
import '../shell/_shell_test_helpers.dart';

Future<void> _seedCurrencies(Services services) =>
    services.statics.applyStatic(<String, dynamic>{
      'currencies': [
        for (final c in const [
          ('1', 'US Dollar', 'USD', r'$'),
          ('3', 'Euro', 'EUR', '€'),
        ])
          {
            'id': c.$1,
            'name': c.$2,
            'code': c.$3,
            'symbol': c.$4,
            'precision': 2,
            'thousand_separator': ',',
            'decimal_separator': '.',
            'swap_currency_symbol': false,
            'exchange_rate': 1,
          },
      ],
    });

void main() {
  testWidgets('a euro client\'s ledger summary is in euros', (tester) async {
    late ShellFixture fixture;
    late Services services;
    await tester.runAsync(() async {
      fixture = await buildFixture(
        // The company's own currency is the dollar.
        companies: [
          FakeCompany(
            id: 'co1',
            name: 'Co',
            isAdmin: true,
            settings: const {'currency_id': '1'},
          ),
        ],
        closeStreamsSynchronously: true,
      );
      services = fixture.services;
      await _seedCurrencies(services);
      await services.clients.applyUpdateResponse(
        companyId: 'co1',
        serverResponse: const ClientApi(
          id: 'c1',
          name: 'Acme',
          currencyId: '3',
          updatedAt: 1,
        ),
      );
      services.invalidateFormatter('co1');
    });
    final formatter = await tester.runAsync(() => services.formatterFor('co1'));

    // Torn down whatever happens: a failed `expect` otherwise leaves the
    // fixture open and a second, misleading "Timer still pending" failure.
    try {
      await tester.pumpWidget(
        Provider<Services>.value(
          value: services,
          child: MaterialApp(
            theme: buildInTheme(InTheme.light),
            localizationsDelegates: kTestLocalizationsDelegates,
            supportedLocales: kTestSupportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: LedgerTab(
                  scope: LedgerScope.client,
                  companyId: 'co1',
                  entityId: 'c1',
                  formatter: formatter,
                  summaryBalance: Decimal.parse('4250'),
                  summaryPaidToDate: Decimal.parse('18900'),
                ),
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump(const Duration(milliseconds: 60));
      }

      expect(find.textContaining('€4,250.00'), findsOneWidget);
      expect(find.textContaining('€18,900.00'), findsOneWidget);
      expect(find.textContaining(r'$'), findsNothing);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(fixture.dispose);
    }
  });
}
