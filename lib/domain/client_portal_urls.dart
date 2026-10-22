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
/// (subdomain or custom domain) and never needs it.
///
/// Self-hosted always carries the key. Without it the server picks a company
/// of its own — `ContactRegister` the *first account's* default company,
/// `ContactLoginController::resolveCompany` `Company::first()` — and nothing
/// the app can see proves that is this one: the session lists the signed-in
/// user's companies, not the server's, and a self-hosted server can hold a
/// second account (an OAuth sign-in with no matching user creates one). A
/// key-less URL shown to the wrong company registers its clients into
/// another company, or shows them another company's login page. So with no
/// key yet, there is no URL. → docs/client-portal-urls.md
String clientPortalUrl({
  required ClientPortalPage page,
  required bool isHosted,
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
    if (domain.isEmpty || companyKey.isEmpty) return '';
    return '$domain$path/$companyKey';
  }
  if (portalMode == kClientPortalModeDomain) {
    return domain.isEmpty ? '' : '$domain$path';
  }
  return subdomain.isEmpty ? '' : 'https://$subdomain.invoicing.co$path';
}
