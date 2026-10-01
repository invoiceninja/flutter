import 'package:admin/data/models/api/company_gateway_api_model.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/base_entity_api.dart';

/// Concrete API for `/api/v1/company_gateways`. The base class handles list/
/// get/create/update/delete/action; this subclass only supplies the path and
/// the parsers.
///
/// Named `CompanyGatewaysApi` (plural) to avoid collision with `CompanyGatewayApi`
/// (the single-resource model class in
/// `data/models/api/company_gateway_api_model.dart`).
class CompanyGatewaysApi
    extends BaseEntityApi<CompanyGatewayListApi, CompanyGatewayItemApi> {
  CompanyGatewaysApi(super.client);

  @override
  String get basePath => '/api/v1/company_gateways';

  @override
  CompanyGatewayListApi parseList(Object json) =>
      CompanyGatewayListApi.fromJson(json as Map<String, dynamic>);

  @override
  CompanyGatewayItemApi parseItem(Object json) =>
      CompanyGatewayItemApi.fromJson(json as Map<String, dynamic>);

  /// `POST /api/v1/company_gateways/{id}/test` — pings the gateway's
  /// credentials. Server returns `{message: 'true'}` on success or
  /// `{message: '<error>'}` on failure; we surface that as a bool to the
  /// caller, which renders a "valid credentials" / "invalid credentials"
  /// snackbar accordingly.
  Future<({bool valid, String? message})> testCredentials(String id) async {
    final raw = await client.postJson('$basePath/$id/test', body: const {});
    if (raw is Map<String, dynamic>) {
      final message = raw['message']?.toString();
      return (valid: message == 'true', message: message);
    }
    return (valid: false, message: null);
  }

  /// `POST /api/v1/one_time_token` — used by the OAuth setup flow to mint a
  /// short-lived hash the user redeems on the web. Returns the hash so the
  /// caller can construct the per-gateway redirect URL.
  Future<String> requestOneTimeToken() async {
    final raw = await client.postJson(
      '/api/v1/one_time_token',
      body: const {
        'context': {'return_url': ''},
      },
    );
    if (raw is Map<String, dynamic>) {
      final hash = raw['hash']?.toString();
      if (hash != null && hash.isNotEmpty) return hash;
    }
    throw const ServerException(0, 'one_time_token response missing hash');
  }

  /// `POST /api/v1/stripe/disconnect/{id}` — the route sits inside the
  /// server's `api/v1` group (`routes/api.php`); only the OAuth *signup*
  /// pages (`/stripe/signup/{hash}`) live at the web root. Admin-only and
  /// password-gated; the API client adds the header when
  /// `requiresPassword: true` is set and the user has authed recently.
  ///
  /// A direct call, not an outbox mutation: it deauthorizes the Stripe
  /// account synchronously and the UI needs the outcome before it can show
  /// the gateway as disconnected — there is nothing to queue offline.
  Future<void> disconnectStripe({required String id}) async {
    await client.postJson(
      '/api/v1/stripe/disconnect/$id',
      body: const {},
      requiresPassword: true,
    );
  }

  /// `POST /api/v1/company_gateways/{id}/import_customers` — pulls Stripe's
  /// customer list into Invoice Ninja as Clients. No interesting return data
  /// beyond a success flag; the caller surfaces a `imported_customers`
  /// snackbar.
  Future<void> importStripeCustomers({required String id}) async {
    await client.postJson('$basePath/$id/import_customers', body: const {});
  }

  /// `POST /api/v1/stripe/verify` — used by the "Verify customers"
  /// affordance to reconcile Stripe's customer count against Invoice
  /// Ninja's. Admin-only on the server. Returns
  /// `{stripe_customer_count: int, stripe_customers: [...]}` so the dialog
  /// can show the two counts side-by-side.
  Future<({int stripeCount, int localCount})> verifyStripeCustomers() async {
    final raw = await client.postJson(
      '/api/v1/stripe/verify',
      body: const {},
      requiresPassword: true,
    );
    if (raw is Map<String, dynamic>) {
      final stripeCount = (raw['stripe_customer_count'] as num?)?.toInt() ?? 0;
      final localList = raw['stripe_customers'];
      final localCount = localList is List ? localList.length : 0;
      return (stripeCount: stripeCount, localCount: localCount);
    }
    return (stripeCount: 0, localCount: 0);
  }
}
