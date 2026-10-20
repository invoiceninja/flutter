import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/portal_constants.dart';
import 'package:admin/domain/client_portal_urls.dart';

void main() {
  ClientPortalUrls urls({
    ClientPortalPage page = ClientPortalPage.login,
    bool isHosted = false,
    String portalMode = kClientPortalModeDomain,
    String subdomain = '',
    String portalDomain = 'https://billing.example.com',
    String companyKey = 'KEY123',
  }) => clientPortalUrls(
    page: page,
    isHosted: isHosted,
    portalMode: portalMode,
    subdomain: subdomain,
    portalDomain: portalDomain,
    companyKey: companyKey,
  );

  group('self-hosted', () {
    test('leads with the short address and offers the keyed one', () {
      for (final page in ClientPortalPage.values) {
        final u = urls(page: page);
        expect(u.primary, 'https://billing.example.com/client/${page.path}');
        expect(
          u.withCompanyKey,
          'https://billing.example.com/client/${page.path}/KEY123',
        );
      }
    });

    test('ignores the portal mode and subdomain', () {
      final u = urls(portalMode: kClientPortalModeSubdomain, subdomain: 'acme');
      expect(u.primary, 'https://billing.example.com/client/login');
    });

    test('trims a trailing slash from the domain', () {
      final u = urls(portalDomain: 'https://billing.example.com/');
      expect(u.primary, 'https://billing.example.com/client/login');
      expect(
        u.withCompanyKey,
        'https://billing.example.com/client/login/KEY123',
      );
    });

    test('drops the keyed address when there is no key', () {
      final u = urls(companyKey: '');
      expect(u.primary, 'https://billing.example.com/client/login');
      expect(u.withCompanyKey, isEmpty);
    });

    test('shows nothing without a domain', () {
      final u = urls(portalDomain: '');
      expect(u.primary, isEmpty);
      expect(u.withCompanyKey, isEmpty);
    });
  });

  group('hosted', () {
    test('custom domain resolves by host, so no keyed address', () {
      for (final page in ClientPortalPage.values) {
        final u = urls(page: page, isHosted: true);
        expect(u.primary, 'https://billing.example.com/client/${page.path}');
        expect(u.withCompanyKey, isEmpty);
      }
    });

    test('subdomain mode uses invoicing.co, even with a domain set', () {
      final u = urls(
        page: ClientPortalPage.register,
        isHosted: true,
        portalMode: kClientPortalModeSubdomain,
        subdomain: 'acme',
      );
      expect(u.primary, 'https://acme.invoicing.co/client/register');
      expect(u.withCompanyKey, isEmpty);
    });

    test('shows nothing without the field the mode needs', () {
      expect(urls(isHosted: true, portalDomain: '').primary, isEmpty);
      expect(
        urls(isHosted: true, portalMode: kClientPortalModeSubdomain).primary,
        isEmpty,
      );
    });
  });
}
