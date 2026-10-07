// The company-gateway record screen, assembled — the record layout end to end
// against a real `Services` graph and a real local database, with the network
// played by a `MockClient`. The harness is
// `test/_support/record_screen_harness.dart`.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/api/company_gateway_api_model.dart';
import 'package:admin/domain/gateway_constants.dart';
import 'package:admin/ui/core/detail/entity_quick_actions.dart';
import 'package:admin/ui/core/detail/standing_card.dart';
import 'package:admin/ui/features/gateways/views/company_gateway_detail_screen.dart';
import 'package:admin/ui/features/gateways/widgets/company_gateway_actions.dart';
import 'package:admin/ui/features/gateways/widgets/detail/company_gateway_detail_header.dart';
import 'package:admin/ui/features/gateways/widgets/detail/company_gateway_detail_profile.dart';
import 'package:admin/ui/features/settings/widgets/settings_form_shell.dart';

import '../../../_support/record_screen_harness.dart';
import '../shell/_shell_test_helpers.dart';

const _other = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

CompanyGatewayApi _gateway({
  String id = 'g1',
  String key = kGatewayStripe,
  String label = 'Stripe (cards)',
  bool testMode = true,
  bool requireCvv = true,
  bool withMethods = true,
  bool isDeleted = false,
  int archivedAt = 0,
}) => CompanyGatewayApi.fromJson({
  'id': id,
  'gateway_key': key,
  'label': label,
  'test_mode': testMode,
  'token_billing': 'always',
  'require_cvv': requireCvv,
  // On by default in the model, so "requires nothing" has to say so.
  'require_contact_email': requireCvv,
  'require_postal_code': requireCvv,
  'fees_and_limits': withMethods
      ? {
          '1': {'is_enabled': true},
        }
      : <String, dynamic>{},
  'is_deleted': isDeleted,
  'archived_at': archivedAt,
  'updated_at': 1710000000,
  'created_at': 1700000000,
});

const _gateways = '/api/v1/company_gateways';

/// Records every request, and answers the gateway list with nothing new.
class _Server {
  final List<Uri> requests = [];

  Iterable<Uri> get listAsks => requests.where((u) => u.path == _gateways);

  http.Client get client => MockClient((request) async {
    requests.add(request.url);
    if (request.method == 'GET' && request.url.path == _gateways) {
      return jsonOk({'data': <Object>[]});
    }
    throw http.ClientException('offline (test fixture)');
  });
}

Future<void> _seed(Services services, CompanyGatewayApi gateway) async {
  // The provider names come from the statics catalog.
  await services.statics.applyStatic(<String, dynamic>{
    'currencies': [
      {
        'id': '1',
        'name': 'US Dollar',
        'code': 'USD',
        'symbol': r'$',
        'precision': 2,
        'thousand_separator': ',',
        'decimal_separator': '.',
        'swap_currency_symbol': false,
        'exchange_rate': 1,
      },
    ],
    'gateways': [
      {'key': kGatewayStripe, 'name': 'Stripe', 'visible': true},
      {'key': _other, 'name': 'Authorize.Net', 'visible': true},
    ],
  });
  services.invalidateFormatter('co1');
  await services.companyGateways.applyUpdateResponse(
    companyId: 'co1',
    serverResponse: gateway,
  );
}

/// The gateway screen over a gateway seeded into the local database.
void _screenTest(
  String description,
  CompanyGatewayApi gateway,
  Future<void> Function(WidgetTester tester, RecordScreen screen) body, {
  _Server? server,
  FakeCompany company = const FakeCompany(id: 'co1', name: 'Co'),
}) => recordScreenTest(
  description,
  seed: (services) => _seed(services, gateway),
  screen: () => CompanyGatewayDetailScreen(id: gateway.id),
  ready: () => find.byType(CompanyGatewayDetailProfile),
  body: body,
  httpClient: server?.client,
  company: company,
);

Finder _tiles() => find.byType(EntityQuickActions<CompanyGatewayAction>);

/// A quick-action tile, by its short label.
Finder _tile(String label) =>
    find.descendant(of: _tiles(), matching: find.text(label));

Finder _header(String text) => find.descendant(
  of: find.byType(CompanyGatewayDetailHeader),
  matching: find.text(text),
);

void main() {
  _screenTest(
    'a Stripe gateway: identity, its two actions, and the profile',
    _gateway(),
    (tester, screen) async {
      expect(_header('Stripe (cards)'), findsOneWidget);
      // The provider under the label — two gateways can share a processor.
      expect(_header('Stripe'), findsOneWidget);
      expect(_header('Test'), findsOneWidget);

      expect(_tile('Import'), findsOneWidget);
      expect(_tile('Verify'), findsOneWidget);

      // The profile is simply there.
      expect(find.text('Provider'), findsOneWidget);
      expect(find.text('Payment Methods'), findsOneWidget);
      expect(find.text('Required Fields'), findsOneWidget);
      expect(find.text('CVV'), findsOneWidget);
      // The header's Test pill says it; a "Test Mode" row would say it twice.
      expect(find.text('Test Mode'), findsNothing);

      // No figure the server keeps for a gateway.
      expect(find.byType(StandingCard), findsNothing);
      // A settings page like any other: centred and capped.
      expect(find.byType(SettingsFormShell), findsOneWidget);
    },
  );

  _screenTest(
    'the first gateway in the company\'s list is the Default one',
    _gateway(),
    (tester, screen) async {
      await screen.untilFound(_header('Default'), 'the pill');
    },
    company: const FakeCompany(
      id: 'co1',
      name: 'Co',
      settings: {'company_gateway_ids': 'g1,g2'},
    ),
  );

  _screenTest(
    'any other provider has no tiles, and a card with nothing in it is not '
    'drawn',
    _gateway(
      key: _other,
      label: '',
      testMode: false,
      requireCvv: false,
      withMethods: false,
    ),
    (tester, screen) async {
      // No label of its own, so the provider is the name — and is not then
      // repeated under it.
      expect(_header('Authorize.Net'), findsOneWidget);
      expect(_tile('Import'), findsNothing);
      expect(_tile('Verify'), findsNothing);
      expect(find.text('Required Fields'), findsNothing);
      // A gateway with no method enabled is never offered to a payer, so
      // that card says so instead of disappearing.
      expect(find.text('Payment Methods'), findsOneWidget);
    },
  );

  _screenTest(
    'a deleted gateway is read-only, and says so once',
    _gateway(isDeleted: true),
    (tester, screen) async {
      expect(
        find.text('This record is deleted. Restore it to make changes.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextButton, 'Restore'), findsOneWidget);
      // The banner says it; the header pill would be the same word again.
      expect(find.text('Deleted'), findsNothing);
      expect(_tile('Import'), findsNothing);
    },
  );

  _screenTest(
    'an archived gateway says so and keeps its actions',
    _gateway(archivedAt: 1710000000),
    (tester, screen) async {
      expect(find.textContaining('Archived'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Restore'), findsOneWidget);
      // Archived is not read-only.
      expect(_tile('Import'), findsOneWidget);
    },
  );

  _screenTest(
    'only an admin may write to a gateway: anyone else gets the banner '
    'without Restore, and no Verify',
    _gateway(archivedAt: 1710000000),
    (tester, screen) async {
      expect(find.textContaining('Archived'), findsOneWidget);
      expect(find.text('Restore'), findsNothing);
      expect(_tile('Verify'), findsNothing);
      // Import is the same server rule (`TestCompanyGatewayRequest`), and had
      // no gate of its own.
      expect(_tile('Import'), findsNothing);
    },
    company: const FakeCompany(
      id: 'co1',
      name: 'Co',
      isAdmin: false,
      isOwner: false,
      // Every edit right there is — and still not an admin.
      permissions: 'edit_all,view_all',
    ),
  );

  _screenTest(
    'an unsynced gateway gets the sync banner and no tiles',
    _gateway(id: 'tmp_1'),
    (tester, screen) async {
      expect(find.textContaining("hasn't synced"), findsOneWidget);
      expect(_tile('Import'), findsNothing);
    },
  );

  final server = _Server();
  _screenTest(
    'opening asks for no gateway; R refreshes the gateways, with nothing '
    'clicked first',
    _gateway(),
    (tester, screen) async {
      // Past the quiet re-check: gateways are bundled reference data, and
      // there is no by-id fetch for it to make.
      await screen.quiet();
      expect(server.listAsks, isEmpty);

      expect(await tester.sendKeyEvent(LogicalKeyboardKey.keyR), isTrue);
      await screen.until(() => server.listAsks.isNotEmpty, 'the refresh');
    },
    server: server,
  );
}
