// Pins the Account Management tab set per session type. Referral Program is
// hosted-only: a self-hosted account can't earn referrals, so the tab is hidden
// outright rather than rendered as an explanatory dead end (issue #27).
//
// This asserts on the pure slug list rather than pumping the shell — the shell
// needs a GoRouter plus a full Services graph, and the ordering invariant is
// what actually matters (the TabBar labels and the TabBarView children are
// built from the same list, so a reorder would silently desync them).

import 'package:flutter_test/flutter_test.dart';

import 'package:admin/ui/features/settings/views/basic/account_management/account_management_shell.dart';

void main() {
  group('visibleAccountManagementTabSlugs', () {
    test('hosted shows all seven tabs in display order', () {
      expect(visibleAccountManagementTabSlugs(isHosted: true), [
        '', // Plan
        'overview',
        'enabled_modules',
        'integrations',
        'security_settings',
        'referral_program',
        'danger_zone',
      ]);
    });

    test('self-hosted drops Referral Program and keeps the rest in order', () {
      expect(visibleAccountManagementTabSlugs(isHosted: false), [
        '',
        'overview',
        'enabled_modules',
        'integrations',
        'security_settings',
        'danger_zone',
      ]);
    });

    test('self-hosted differs from hosted by exactly the referral tab', () {
      final hosted = visibleAccountManagementTabSlugs(isHosted: true);
      final selfHosted = visibleAccountManagementTabSlugs(isHosted: false);
      expect(
        hosted.where((s) => s != 'referral_program').toList(),
        selfHosted,
        reason:
            'Only referral_program is hosted-only. If another tab becomes '
            'hosted-only, extend this test rather than loosening it.',
      );
    });

    test('every visible slug round-trips through accountManagementTabSlug', () {
      // The shell resolves the active tab from the location, so a slug that
      // the parser can't recover would strand the URL on the Plan tab.
      for (final slug in visibleAccountManagementTabSlugs(isHosted: true)) {
        final path = slug.isEmpty
            ? '/settings/account_management'
            : '/settings/account_management/$slug';
        expect(accountManagementTabSlug(path), slug);
      }
    });
  });
}
