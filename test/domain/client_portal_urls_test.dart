import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/portal_constants.dart';
import 'package:admin/domain/client_portal_urls.dart';

void main() {
  String url({
    ClientPortalPage page = ClientPortalPage.login,
    bool isHosted = false,
    String portalMode = kClientPortalModeDomain,
    String subdomain = '',
    String portalDomain = 'https://billing.example.com',
    String companyKey = 'KEY123',
  }) => clientPortalUrl(
    page: page,
    isHosted: isHosted,
    portalMode: portalMode,
    subdomain: subdomain,
    portalDomain: portalDomain,
    companyKey: companyKey,
  );

  group('self-hosted', () {
    // Without the key the server picks a company itself (the first
    // account's default company to register, `Company::first()` to log in),
    // and the app cannot prove that is this one — so the key is always there.
    test('the key pins this company on every page', () {
      for (final page in ClientPortalPage.values) {
        expect(
          url(page: page),
          'https://billing.example.com/client/${page.path}/KEY123',
        );
      }
    });

    test('no key yet: no URL, never the short address', () {
      for (final page in ClientPortalPage.values) {
        expect(url(page: page, companyKey: ''), isEmpty);
      }
    });

    test('ignores the portal mode and subdomain', () {
      expect(
        url(portalMode: kClientPortalModeSubdomain, subdomain: 'acme'),
        'https://billing.example.com/client/login/KEY123',
      );
    });

    test('trims a trailing slash from the domain', () {
      expect(
        url(portalDomain: 'https://billing.example.com/'),
        'https://billing.example.com/client/login/KEY123',
      );
    });

    test('shows nothing without a domain', () {
      expect(url(portalDomain: ''), isEmpty);
    });
  });

  group('hosted', () {
    test('custom domain resolves by host, so never a key', () {
      for (final page in ClientPortalPage.values) {
        expect(
          url(page: page, isHosted: true),
          'https://billing.example.com/client/${page.path}',
        );
      }
    });

    test('subdomain mode uses invoicing.co, even with a domain set', () {
      expect(
        url(
          page: ClientPortalPage.register,
          isHosted: true,
          portalMode: kClientPortalModeSubdomain,
          subdomain: 'acme',
        ),
        'https://acme.invoicing.co/client/register',
      );
    });

    test('shows nothing without the field the mode needs', () {
      expect(url(isHosted: true, portalDomain: ''), isEmpty);
      expect(
        url(isHosted: true, portalMode: kClientPortalModeSubdomain),
        isEmpty,
      );
    });
  });
}
