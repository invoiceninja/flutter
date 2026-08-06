import 'package:admin/ui/features/settings/views/basic/account_management/account_management_shell.dart';
import 'package:flutter_test/flutter_test.dart';

/// `AccountManagementShell` derives its active tab from the location, not from
/// the `:tab` path parameter. go_router hands every page in the stack the whole
/// match list's `pathParameters`, so once a `tabSubRoutes` child (Analytics,
/// API Tokens, …) is the terminal match `:tab` is null — a shell that trusted
/// it would snap back to the Plan tab and navigate the child away (issue #8).
void main() {
  group('accountManagementTabSlug', () {
    test('bare base path is the default (Plan) tab', () {
      expect(accountManagementTabSlug('/settings/account_management'), '');
      expect(accountManagementTabSlug('/settings/account_management/'), '');
    });

    test('a tab URL resolves to its slug', () {
      for (final slug in [
        'overview',
        'enabled_modules',
        'integrations',
        'security_settings',
        'referral_program',
        'danger_zone',
      ]) {
        expect(
          accountManagementTabSlug('/settings/account_management/$slug'),
          slug,
        );
      }
    });

    test('a sub-route still resolves to its owning tab', () {
      for (final child in [
        'analytics',
        'api_tokens',
        'api_webhooks',
        'quickbooks',
      ]) {
        expect(
          accountManagementTabSlug(
            '/settings/account_management/integrations/$child',
          ),
          'integrations',
        );
      }
      expect(
        accountManagementTabSlug(
          '/settings/account_management/integrations/api_tokens/tok1',
        ),
        'integrations',
      );
    });

    test('returns null outside the shell so the tab is left alone', () {
      expect(accountManagementTabSlug('/settings/company_details'), isNull);
      expect(accountManagementTabSlug('/settings'), isNull);
      expect(accountManagementTabSlug('/clients'), isNull);
    });

    test('does not match a path that merely shares the prefix', () {
      expect(accountManagementTabSlug('/settings/account_managementx'), isNull);
    });
  });
}
