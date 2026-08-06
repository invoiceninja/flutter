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

    test('unknown routes fall back to the docs base', () {
      expect(userGuideUrl('/login'), base);
      expect(userGuideUrl('/'), base);
      expect(userGuideUrl(''), base);
    });
  });
}
