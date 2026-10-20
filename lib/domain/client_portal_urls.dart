import 'package:admin/app/portal_constants.dart';

/// The public client-portal pages whose address the Client Portal settings
/// surface. The value is the path segment after `/client/`.
enum ClientPortalPage {
  login('login'),
  register('register');

  const ClientPortalPage(this.path);

  final String path;
}

/// The address(es) a company's clients reach a portal page at.
///
/// [primary] is the address to hand out. [withCompanyKey] is the same page
/// pinned to this company, offered only on a self-hosted server; it is `''`
/// everywhere else.
class ClientPortalUrls {
  const ClientPortalUrls({required this.primary, this.withCompanyKey = ''});

  static const empty = ClientPortalUrls(primary: '');

  final String primary;
  final String withCompanyKey;
}

/// Builds the address of [page] the way the server resolves it.
///
/// The server's `client/login/{company_key?}` and `client/register/{company_key?}`
/// routes take the key as optional. Hosted resolves the company from the host
/// (subdomain or custom domain) and never needs it. Self-hosted falls back to
/// a company of its own choosing when the key is missing (`ContactRegister`:
/// the account's default company; `ContactLoginController::resolveCompany`:
/// `Company::first()`), so the short address is the one to print on a
/// business card for a single-company server, and the keyed one only matters
/// when the server holds several companies. Showing only the keyed form made
/// a self-hosted user think the portal address had changed.
ClientPortalUrls clientPortalUrls({
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
    if (domain.isEmpty) return ClientPortalUrls.empty;
    return ClientPortalUrls(
      primary: '$domain$path',
      withCompanyKey: companyKey.isEmpty ? '' : '$domain$path/$companyKey',
    );
  }
  if (portalMode == kClientPortalModeDomain) {
    if (domain.isEmpty) return ClientPortalUrls.empty;
    return ClientPortalUrls(primary: '$domain$path');
  }
  if (subdomain.isEmpty) return ClientPortalUrls.empty;
  return ClientPortalUrls(primary: 'https://$subdomain.invoicing.co$path');
}
