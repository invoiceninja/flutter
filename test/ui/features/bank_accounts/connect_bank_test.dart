import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:admin/data/services/api_client.dart';
import 'package:admin/data/services/api_credentials.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/bank_accounts_api.dart';
import 'package:admin/data/services/password_cache.dart';
import 'package:admin/ui/features/bank_accounts/views/bank_account_list_screen.dart';
import 'package:admin/ui/features/bank_accounts/widgets/bank_connect.dart';

ValueListenable<ApiCredentials?> _creds() => ValueNotifier<ApiCredentials?>(
  const ApiCredentials(baseUrl: 'https://co.example.com/', token: 't'),
);

void main() {
  _bankConnectErrorMessageTests();

  group('connectBankUrl (admin-portal parity)', () {
    test('yodlee → server-relative base (NOT a hardcoded domain)', () {
      expect(
        connectBankUrl('yodlee', 'abc', 'https://co.example.com'),
        'https://co.example.com/yodlee/onboard/abc',
      );
    });

    test('both providers strip /api/v1 + trailing slash from the base', () {
      expect(
        connectBankUrl('nordigen', 'xyz', 'https://co.example.com/'),
        'https://co.example.com/nordigen/connect/xyz',
      );
      expect(
        connectBankUrl('nordigen', 'xyz', 'https://co.example.com'),
        'https://co.example.com/nordigen/connect/xyz',
      );
      expect(
        connectBankUrl('yodlee', 'H', 'https://co.example.com/api/v1'),
        'https://co.example.com/yodlee/onboard/H',
      );
      expect(
        connectBankUrl('nordigen', 'H', 'https://co.example.com/api/v1/'),
        'https://co.example.com/nordigen/connect/H',
      );
    });

    test('hosted production base is unchanged (still invoicing.co)', () {
      expect(
        connectBankUrl('yodlee', 'H', 'https://invoicing.co/api/v1'),
        'https://invoicing.co/yodlee/onboard/H',
      );
    });
  });

  group('BankAccountsApi.oneTimeToken', () {
    test(
      'POSTs {context} — and never a platform — returning the hash',
      () async {
        Uri? captured;
        Map<String, dynamic>? body;
        final fake = MockClient((req) async {
          captured = req.url;
          body = jsonDecode(req.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'data': {'hash': 'H123'},
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        });
        final client = ApiClient(
          credentials: _creds(),
          passwordCache: PasswordCache(),
          onUnauthorized: () async {},
          httpClient: fake,
        );

        final hash = await BankAccountsApi(
          client,
        ).oneTimeToken(context: 'yodlee');

        expect(captured!.path, '/api/v1/one_time_token');
        expect(body!['context'], 'yodlee');
        // `OneTimeTokenRequest` allows only `flutter_native` / `react`, so the
        // `'flutter'` this used to send 422'd every connect attempt
        // (invoiceninja/flutter#69). Nothing on the bank-connect route reads
        // the key, so the fix is to omit it.
        expect(body!.containsKey('platform'), isFalse);
        expect(hash, 'H123');
      },
    );

    test('tolerates a flat {hash} body; throws when absent', () async {
      ApiClient mk(Object responseBody) => ApiClient(
        credentials: _creds(),
        passwordCache: PasswordCache(),
        onUnauthorized: () async {},
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode(responseBody),
            200,
            headers: const {'content-type': 'application/json'},
          ),
        ),
      );

      expect(
        await BankAccountsApi(
          mk({'hash': 'flat'}),
        ).oneTimeToken(context: 'nordigen'),
        'flat',
      );
      expect(
        () => BankAccountsApi(
          mk({'nope': true}),
        ).oneTimeToken(context: 'nordigen'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

/// "An error occurred: The given data was invalid." named nothing the user
/// could act on (invoiceninja/flutter#69); the useful text was in the 422's
/// per-field messages.
void _bankConnectErrorMessageTests() {
  const fallback = 'An error occurred';

  group('bankConnectErrorMessage', () {
    test('flattens a 422 into its per-field messages', () {
      expect(
        bankConnectErrorMessage(
          const ValidationException('The given data was invalid.', {
            'platform': ['The selected platform is invalid.'],
            'context': ['The context field is required.'],
          }),
          fallback,
        ),
        'The selected platform is invalid. · The context field is required.',
      );
    });

    test('falls back when a 422 carries no field messages', () {
      expect(
        bankConnectErrorMessage(
          const ValidationException('The given data was invalid.', {
            'platform': ['   '],
          }),
          fallback,
        ),
        'The given data was invalid.',
      );
    });

    test('never surfaces a 5xx body — it can be raw HTML', () {
      expect(
        bankConnectErrorMessage(
          const ServerException(500, '<!DOCTYPE html><html><head><title>50'),
          fallback,
        ),
        'An error occurred',
      );
    });

    test('uses a non-5xx ApiException message verbatim', () {
      expect(
        bankConnectErrorMessage(
          const NetworkException('No internet connection'),
          fallback,
        ),
        'No internet connection',
      );
    });

    test('a non-API error gets the generic message', () {
      expect(
        bankConnectErrorMessage(StateError('boom'), fallback),
        'An error occurred',
      );
    });
  });
}
