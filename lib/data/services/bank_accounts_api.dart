import 'package:admin/data/models/api/bank_account_api_model.dart';
import 'package:admin/data/services/base_entity_api.dart';

/// Concrete API for `/api/v1/bank_integrations` (wire entity:
/// `bank_integration`; UI label "bank account"). The base class handles
/// list / get / create / update / delete / action; this subclass supplies
/// the path, the parsers, and the non-standard `refresh_accounts`
/// endpoint.
///
/// Named `BankAccountsApi` (plural) to avoid collision with `BankAccountApi`
/// (the single-resource model class in `data/models/api/...`).
class BankAccountsApi
    extends BaseEntityApi<BankAccountListApi, BankAccountItemApi> {
  BankAccountsApi(super.client);

  @override
  String get basePath => '/api/v1/bank_integrations';

  @override
  BankAccountListApi parseList(Object json) =>
      BankAccountListApi.fromJson(json as Map<String, dynamic>);

  @override
  BankAccountItemApi parseItem(Object json) =>
      BankAccountItemApi.fromJson(json as Map<String, dynamic>);

  /// `POST /api/v1/one_time_token` — mints a short-lived hash the client
  /// hands to the aggregator's hosted connect page (Yodlee / Nordigen).
  /// `context` is `'yodlee'` or `'nordigen'` (React parity). Online-only
  /// interactive flow (not an outbox mutation — you can't link a bank
  /// offline); demo-mode is correctly blocked by `postJson`.
  ///
  /// [institutionId] is sent only for Nordigen **reconnect** (mirrors
  /// React `handleConnectNordigen`): a stale link already knows its
  /// institution, so we target it directly instead of re-prompting the
  /// picker. Omitted (key absent) for the normal connect flow.
  Future<String> oneTimeToken({
    required String context,
    String? institutionId,
  }) async {
    final raw = await client.postJson(
      '/api/v1/one_time_token',
      body: {
        'context': context,
        // No `platform` key. `OneTimeTokenRequest` validates it
        // `sometimes|nullable|string|in:flutter_native,react`, so the
        // `'flutter'` this used to send failed *every* Connect Accounts
        // attempt with a bare 422 "The given data was invalid."
        // (invoiceninja/flutter#69, reproduced against the live demo server).
        // Omitting it is right rather than merely safe: only the calendar
        // OAuth callback reads `platform`, and the bank-connect route never
        // looks at the value — while an older self-hosted server whose `in:`
        // list predates `flutter_native` would 422 all over again.
        if (institutionId != null && institutionId.isNotEmpty)
          'institution_id': institutionId,
      },
    );
    if (raw is Map) {
      final data = raw['data'];
      if (data is Map && data['hash'] is String) {
        return data['hash'] as String;
      }
      if (raw['hash'] is String) return raw['hash'] as String;
    }
    throw const FormatException('one_time_token: no hash in response');
  }

  /// `POST /api/v1/bank_integrations/refresh_accounts` — pings the upstream
  /// providers (Yodlee/Nordigen) for the account list and pulls down any
  /// fresh balances. Returns the refreshed list envelope.
  Future<BankAccountListApi> refreshAccounts({
    required String idempotencyKey,
  }) async {
    final raw = await client.mutate(
      method: 'POST',
      path: '$basePath/refresh_accounts',
      idempotencyKey: idempotencyKey,
      body: const <String, dynamic>{},
    );
    return parseList(raw as Object);
  }
}
