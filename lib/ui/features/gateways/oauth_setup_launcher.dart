import 'package:admin/domain/gateway_constants.dart';
import 'package:admin/ui/core/utils/external_url.dart';

/// Build the per-provider external OAuth setup URL. The server mints a
/// short-lived hash via `POST /one_time_token`; the user then visits one
/// of these URLs to complete the OAuth dance on the web. Once they're
/// done, the gateway row updates and shows up in the list (the next
/// background sync picks up the change — no in-app callback needed).
///
/// Mirrors `admin-portal/lib/ui/company_gateway/edit/company_gateway_edit_vm.dart`
/// lines 133-170. Returns null for gateway types that don't use an OAuth
/// signup flow — the caller falls back to the regular Credentials form.
Uri? buildOAuthSetupUrl({
  required String gatewayKey,
  required String baseUrl,
  required String hash,
}) {
  final cleanUrl = _stripApiSegment(baseUrl);
  switch (gatewayKey) {
    case kGatewayStripeConnect:
      return Uri.parse('$cleanUrl/stripe/signup/$hash');
    case kGatewayWePay:
      return Uri.parse('$cleanUrl/wepay/signup/$hash');
    case kGatewayPayPalPlatform:
      // PayPal PPCP shares this gateway key — covered by the same branch.
      return Uri.parse('$cleanUrl/paypal?hash=$hash');
    case kGatewayGoCardlessOAuth:
      return Uri.parse('$cleanUrl/gocardless/oauth/connect/$hash');
    default:
      return null;
  }
}

/// Open [url] in the system browser. Matches the legacy
/// `launchUrl(Uri.parse(...))` call site — the user completes setup outside
/// the app and the result lands on the next gateway-list refresh.
Future<bool> openExternal(Uri url) => launchExternalUri(url);

/// The legacy admin-portal strips a trailing `/api/v1` segment when
/// composing the setup URL so the redirect lands on the bare host (the
/// signup endpoints sit at `/stripe/signup/{hash}`, not under `/api/v1`).
/// Replicated here so callers don't need to know the trick.
String _stripApiSegment(String baseUrl) {
  var url = baseUrl;
  if (url.endsWith('/')) url = url.substring(0, url.length - 1);
  if (url.endsWith('/api/v1')) {
    url = url.substring(0, url.length - '/api/v1'.length);
  }
  return url;
}
