import 'package:admin/ui/features/shell/widgets/sidebar_footer_actions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('userGuideUrl', () {
    const base = 'https://invoiceninja.github.io/en';

    test('clients list and detail map to /clients', () {
      expect(userGuideUrl('/clients'), '$base/clients');
      expect(userGuideUrl('/clients/abc123'), '$base/clients');
      expect(userGuideUrl('/clients/abc123/edit'), '$base/clients');
    });

    test('dashboard maps to /user-guide', () {
      expect(userGuideUrl('/dashboard'), '$base/user-guide');
    });

    test('settings/company_details takes precedence over generic settings', () {
      expect(userGuideUrl('/settings/company_details'), '$base/basic-settings');
      expect(
        userGuideUrl('/settings/company_details/logo'),
        '$base/basic-settings',
      );
    });

    test('other settings subroutes map to /advanced-settings', () {
      expect(userGuideUrl('/settings'), '$base/advanced-settings');
      expect(userGuideUrl('/settings/account'), '$base/advanced-settings');
      expect(
        userGuideUrl('/settings/account_management/integrations'),
        '$base/advanced-settings',
      );
    });

    // The bare `$base` 404s on the docs site, and this branch catches most of
    // the app — Invoices, Products, Tasks, Quotes, Payments, Reports, Outbox.
    // Verified against the live site while fixing issue #12.
    test('unmapped routes fall back to the user guide, not the bare base', () {
      const routes = ['/invoices', '/products', '/reports', '/login', '/', ''];
      for (final route in routes) {
        expect(userGuideUrl(route), '$base/user-guide', reason: route);
      }
    });

    test('no route ever returns the bare docs base — it 404s', () {
      const routes = [
        '/clients',
        '/dashboard',
        '/settings',
        '/settings/company_details',
        '/invoices',
        '/login',
        '/',
        '',
      ];
      for (final route in routes) {
        expect(userGuideUrl(route), isNot(base), reason: route);
      }
    });
  });
}
