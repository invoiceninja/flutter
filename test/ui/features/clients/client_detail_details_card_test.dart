// The Details card with a formatter — the state it is actually in once a
// record has loaded. (`client_detail_profile_test.dart` covers the card's
// gating with no formatter, where the money and date rows are not built.)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/api/client_api_model.dart';
import 'package:admin/data/models/api/group_setting_api_model.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/ui/features/clients/widgets/detail/client_detail_details_card.dart';
import 'package:admin/utils/formatting.dart';

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
  testWidgets('a group-inheriting client\'s task rate is in the group\'s '
      'currency, and the record\'s dates are at the foot', (tester) async {
    // The client has no currency of its own; its group bills in euros; the
    // company's is the dollar. Formatted with the client's own currency id
    // alone this read "$85.00" under a standing card in euros.
    const api = ClientApi(
      id: 'c1',
      name: 'Acme',
      groupSettingsId: 'g1',
      settings: {'default_task_rate': 85},
      createdAt: 1700000000,
      updatedAt: 1710000000,
    );
    late ShellFixture fixture;
    late Services services;
    late Formatter formatter;
    await tester.runAsync(() async {
      fixture = await buildFixture(
        companies: [
          const FakeCompany(
            id: 'co1',
            name: 'Co',
            settings: {'currency_id': '1'},
          ),
        ],
        closeStreamsSynchronously: true,
      );
      services = fixture.services;
      await _seedCurrencies(services);
      await services.groupSettings.applyUpdateResponse(
        companyId: 'co1',
        serverResponse: const GroupSettingApi(
          id: 'g1',
          name: 'Europe',
          settings: {'currency_id': '3'},
          updatedAt: 1700000000,
        ),
      );
      await services.clients.applyUpdateResponse(
        companyId: 'co1',
        serverResponse: api,
      );
      services.invalidateFormatter('co1');
      formatter = await services.formatterFor('co1');
    });

    await tester.pumpWidget(
      Provider<Services>.value(
        value: services,
        child: MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ClientDetailDetailsCard(
                client: Client.fromApi(api),
                company: null,
                formatter: formatter,
              ),
            ),
          ),
        ),
      ),
    );
    try {
      Finder rate() => find.text('€85.00');
      for (var i = 0; i < 60 && rate().evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 15)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(rate(), findsOneWidget);
      expect(find.textContaining(r'$'), findsNothing);

      // With a formatter the card always has these two, which is why Details
      // is never an empty section for a record that has loaded.
      expect(find.text('Date Created'), findsOneWidget);
      expect(find.text('Updated'), findsOneWidget);
      expect(find.text('Europe'), findsOneWidget, reason: 'the group, by name');
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(fixture.dispose);
    }
  });
}
