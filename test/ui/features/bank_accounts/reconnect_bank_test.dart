import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:admin/data/models/api/bank_account_api_model.dart';
import 'package:admin/data/models/domain/bank_account.dart';
import 'package:admin/data/services/api_client.dart';
import 'package:admin/data/services/api_credentials.dart';
import 'package:admin/data/services/bank_accounts_api.dart';
import 'package:admin/data/services/password_cache.dart';
import 'package:admin/ui/features/bank_accounts/views/bank_account_list_screen.dart'
    show connectBankUrl;
import 'package:admin/ui/features/bank_accounts/widgets/reconnect_banner.dart'
    show bankReconnectArgs;

BankAccount _acct({required String integrationType, String inst = ''}) =>
    BankAccount.fromApi(
      BankAccountApi(
        integrationType: integrationType,
        nordigenInstitutionId: inst,
      ),
    );

ValueListenable<ApiCredentials?> _creds() => ValueNotifier<ApiCredentials?>(
  const ApiCredentials(baseUrl: 'https://co.example.com/', token: 't'),
);

({ApiClient client, List<Map<String, dynamic>> bodies}) _capture() {
  final bodies = <Map<String, dynamic>>[];
  final client = ApiClient(
    credentials: _creds(),
    passwordCache: PasswordCache(),
    onUnauthorized: () async {},
    httpClient: MockClient((req) async {
      bodies.add(jsonDecode(req.body) as Map<String, dynamic>);
      return http.Response(
        jsonEncode({
          'data': {'hash': 'H'},
        }),
        200,
        headers: const {'content-type': 'application/json'},
      );
    }),
  );
  return (client: client, bodies: bodies);
}

void main() {
  group('bankReconnectArgs (provider → connect-flow args)', () {
    test('YODLEE → yodlee context, no institution id', () {
      final a = _acct(integrationType: kBankIntegrationYodlee, inst: 'X');
      expect(bankReconnectArgs(a), (ctx: 'yodlee', institutionId: null));
    });

    test('NORDIGEN → nordigen context + its institution id', () {
      final a = _acct(
        integrationType: kBankIntegrationNordigen,
        inst: 'INST_42',
      );
      expect(bankReconnectArgs(a), (ctx: 'nordigen', institutionId: 'INST_42'));
    });

    test('unknown / empty integration type throws (no silent Nordigen)', () {
      expect(
        () => bankReconnectArgs(_acct(integrationType: '')),
        throwsArgumentError,
      );
      expect(
        () => bankReconnectArgs(_acct(integrationType: 'GOCARDLESS')),
        throwsArgumentError,
      );
    });
  });

  group('Reconnect — oneTimeToken with institution_id (Nordigen)', () {
    test('nordigen reconnect sends institution_id', () async {
      final c = _capture();
      final hash = await BankAccountsApi(
        c.client,
      ).oneTimeToken(context: 'nordigen', institutionId: 'INST_42');
      expect(hash, 'H');
      expect(c.bodies.single['context'], 'nordigen');
      expect(c.bodies.single.containsKey('platform'), isFalse);
      expect(c.bodies.single['institution_id'], 'INST_42');
    });

    test('empty / null institutionId omits the key entirely', () async {
      final c = _capture();
      await BankAccountsApi(
        c.client,
      ).oneTimeToken(context: 'nordigen', institutionId: '');
      await BankAccountsApi(c.client).oneTimeToken(context: 'yodlee');
      expect(c.bodies[0].containsKey('institution_id'), isFalse);
      expect(c.bodies[1].containsKey('institution_id'), isFalse);
    });

    test(
      'the existing connect call is unchanged (no institution_id)',
      () async {
        // Regression guard: the connect flow still sends exactly {context} —
        // adding the optional param must not alter it, and `platform` must
        // stay gone (invoiceninja/flutter#69).
        final c = _capture();
        await BankAccountsApi(c.client).oneTimeToken(context: 'yodlee');
        expect(c.bodies.single.keys.toSet(), {'context'});
      },
    );

    test('reconnect reuses the same hosted-URL builder as connect', () {
      // Reconnect is "re-trigger connect" — same URL contract per provider.
      expect(
        connectBankUrl('nordigen', 'H', 'https://co.example.com'),
        'https://co.example.com/nordigen/connect/H',
      );
      expect(
        connectBankUrl('yodlee', 'H', 'https://co.example.com'),
        'https://co.example.com/yodlee/onboard/H',
      );
    });
  });
}
