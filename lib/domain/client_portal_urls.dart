import 'package:admin/app/portal_constants.dart';

/// The public client-portal pages whose address the Client Portal settings
/// surface. The value is the path segment after `/client/`.
enum ClientPortalPage {
  login('login'),
  register('register');

  const ClientPortalPage(this.path);

  final String path;
}

/// Builds the address of [page] the way the server resolves it, or `''` when
/// the field it needs is blank.
///
/// The server's `client/login/{company_key?}` and `client/register/{company_key?}`
/// routes take the key as optional. Hosted resolves the company from the host
/// (subdomain or custom domain) and never needs it. Self-hosted falls back to
/// a company of its own choosing when the key is missing (`ContactRegister`:
/// the account's default company; `ContactLoginController::resolveCompany`:
/// `Company::first()`), so the key is added only when
/// [hasMultipleCompanies] — the signed-in user's companies, which is as much
/// of the server as the app can see. Always adding it made a single-company
/// user think the portal address had changed.
String clientPortalUrl({
  required ClientPortalPage page,
  required bool isHosted,
  required bool hasMultipleCompanies,
  required String portalMode,
  required String subdomain,
  required String portalDomain,
  required String companyKey,
}) {
  final domain = portalDomain.endsWith('/')
      ? portalDomain.substring(0, portalDomain.length - 1)
      : portalDomain;
  final path = '/client/${page.path}';
  if (!isHosted) {
    if (domain.isEmpty) return '';
    if (hasMultipleCompanies && companyKey.isNotEmpty) {
      return '$domain$path/$companyKey';
    }
    return '$domain$path';
  }
  if (portalMode == kClientPortalModeDomain) {
    return domain.isEmpty ? '' : '$domain$path';
  }
  return subdomain.isEmpty ? '' : 'https://$subdomain.invoicing.co$path';
}
