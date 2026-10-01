import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/ui/features/settings/settings_search_catalog.dart';
import 'package:admin/ui/features/settings/state/settings_level_controller.dart';
import 'package:admin/ui/features/settings/widgets/settings_screen_scaffold.dart';
import 'package:admin/ui/features/settings/widgets/settings_two_pane_scope.dart';

import '../../../_localization_helper.dart';

/// The settings "Learn more" links (invoiceninja/ui#3391). The paths were
/// checked against the live docs site when they were written; this pins their
/// shape so a typo can't ship as a link to the docs 404 page.
void main() {
  test('every docs path is a user-guide / advanced-topics page', () {
    final shape = RegExp(r'^(user-guide|advanced-topics)/[a-z-]+(#[a-z_-]+)?$');
    final withDocs = kSettingsSections.where((s) => s.docsPath != null);
    expect(withDocs.length, greaterThanOrEqualTo(20));
    for (final s in withDocs) {
      expect(s.docsPath, matches(shape), reason: s.slug);
      expect(s.docsUrl, startsWith('https://invoiceninja.github.io/docs/'));
    }
  });

  test('resolved by the section title the page hands its scaffold', () {
    expect(
      settingsDocsUrlForTitle('company_details'),
      'https://invoiceninja.github.io/docs/user-guide/basic-settings'
      '#company_details',
    );
    expect(
      settingsDocsUrlForTitle('user_management'),
      endsWith('#user_management'),
    );
    // Online Payments' page title is its slug, not its sidebar label.
    expect(settingsDocsUrlForTitle('online_payments'), endsWith('/gateways'));
    expect(settingsDocsUrlForTitle('edit_user'), isNull);
  });

  Future<void> pump(WidgetTester tester, String titleKey) async {
    final level = SettingsLevelController();
    addTearDown(level.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsLevelController>.value(
        value: level,
        child: MaterialApp(
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          home: SettingsTwoPaneScope(
            isTwoPane: true,
            child: SettingsScreenScaffold(
              titleKey: titleKey,
              actions: [
                TextButton(onPressed: () {}, child: const Text('Save')),
              ],
              body: const SizedBox(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('a section page shows Learn more, before its own actions', (
    tester,
  ) async {
    await pump(tester, 'company_details');
    final help = find.byKey(const ValueKey('settings_learn_more'));
    expect(help, findsOneWidget);
    expect(
      tester.getTopLeft(help).dx,
      lessThan(tester.getTopLeft(find.text('Save')).dx),
    );
  });

  testWidgets('a page with no docs shows none', (tester) async {
    await pump(tester, 'system_logs');
    expect(find.byKey(const ValueKey('settings_learn_more')), findsNothing);
  });
}
