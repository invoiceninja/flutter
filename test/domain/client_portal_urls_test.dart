import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/portal_constants.dart';
import 'package:admin/domain/client_portal_urls.dart';

void main() {
  String url({
    ClientPortalPage page = ClientPortalPage.login,
    bool isHosted = false,
    bool hasMultipleCompanies = false,
    String portalMode = kClientPortalModeDomain,
    String subdomain = '',
    String portalDomain = 'https://billing.example.com',
    String companyKey = 'KEY123',
  }) => clientPortalUrl(
    page: page,
    isHosted: isHosted,
    hasMultipleCompanies: hasMultipleCompanies,
    portalMode: portalMode,
    subdomain: subdomain,
    portalDomain: portalDomain,
    companyKey: companyKey,
  );

  group('self-hosted', () {
    test('one company: the short address, no key', () {
      for (final page in ClientPortalPage.values) {
        expect(
          url(page: page),
          'https://billing.example.com/client/${page.path}',
        );
      }
    });

    test('several companies: the key pins this one', () {
      for (final page in ClientPortalPage.values) {
        expect(
          url(page: page, hasMultipleCompanies: true),
          'https://billing.example.com/client/${page.path}/KEY123',
        );
      }
    });

    test('several companies but no key yet: the short address', () {
      expect(
        url(hasMultipleCompanies: true, companyKey: ''),
        'https://billing.example.com/client/login',
      );
    });

    test('ignores the portal mode and subdomain', () {
      expect(
        url(portalMode: kClientPortalModeSubdomain, subdomain: 'acme'),
        'https://billing.example.com/client/login',
      );
    });

    test('trims a trailing slash from the domain', () {
      expect(
        url(portalDomain: 'https://billing.example.com/'),
        'https://billing.example.com/client/login',
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
          url(page: page, isHosted: true, hasMultipleCompanies: true),
          'https://billing.example.com/client/${page.path}',
        );
      }
    });

    test('subdomain mode uses invoicing.co, even with a domain set', () {
      expect(
        url(
          page: ClientPortalPage.register,
          isHosted: true,
          hasMultipleCompanies: true,
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
