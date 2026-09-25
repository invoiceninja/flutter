// Guards the destructive Account Management → Danger Zone flows: the owner-only
// gate, the confirm-word + password submit gate, and the 412 password-incorrect
// surfacing. These are the highest-risk paths in the area (irreversible company
// delete / purge), so the state machine that gates them is pinned here.
//
// Success paths (purge/delete → context.go redirect) are intentionally NOT
// covered: wrapWithShell uses a plain MaterialApp with no GoRouter, so they'd
// throw on navigation. They're verified manually per the review plan.

import 'dart:convert';

import 'package:admin/data/services/password_cache.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/features/settings/views/basic/account_management/danger_zone_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../../../shell/_shell_test_helpers.dart';

void main() {
  testWidgets(
    'non-owner sees the restricted empty state with no destructive actions',
    (tester) async {
      final fixture = await buildFixture(
        companies: const [
          FakeCompany(id: 'c1', name: 'Acme Co', isOwner: false),
        ],
        currentCompanyId: 'c1',
      );
      addTearDown(fixture.dispose);

      await tester.pumpWidget(
        wrapWithShell(
          fixture.services,
          const AccountManagementDangerZoneScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Purge Data'), findsNothing);
    },
  );

  testWidgets('purge submit is gated on the confirm word AND a password '
      '(confirm match is case-insensitive)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final fixture = await buildFixture(
      companies: const [FakeCompany(id: 'c1', name: 'Acme Co')],
      currentCompanyId: 'c1',
    );
    addTearDown(fixture.dispose);

    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        const AccountManagementDangerZoneScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Wide surface → the dialog renders as an AlertDialog.
    final purgeButton = find.widgetWithText(OutlinedButton, 'Purge Data');
    await tester.ensureVisible(purgeButton);
    await tester.pumpAndSettle();
    await tester.tap(purgeButton);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    bool submitEnabled() =>
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
            .onPressed !=
        null;

    // Dialog fields in tree order: [0] confirm, [1] cancellation message,
    // [2] password.
    final confirmField = find.byType(TextField).at(0);
    final passwordField = find.byType(TextField).at(2);

    // Nothing typed → disabled.
    expect(submitEnabled(), isFalse);

    // Wrong confirm word → still disabled.
    await tester.enterText(confirmField, 'nope');
    await tester.pump();
    expect(submitEnabled(), isFalse);

    // Right word but wrong case, and still no password → disabled.
    await tester.enterText(confirmField, 'PURGE');
    await tester.pump();
    expect(submitEnabled(), isFalse);

    // Both conditions met → enabled.
    await tester.enterText(passwordField, 'hunter2');
    await tester.pump();
    expect(submitEnabled(), isTrue);
  });

  testWidgets(
    'a 412 on purge surfaces the password error and keeps the dialog open',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final client = MockClient((req) async {
        if (req.method == 'POST' &&
            req.url.path.contains('/companies/purge_save_settings/')) {
          return http.Response(
            jsonEncode({'message': 'Invalid Password'}),
            412,
            headers: {'content-type': 'application/json'},
          );
        }
        // Mirror the fail-fast offline client for anything else (e.g. a
        // background refresh kicked off by restore()).
        throw http.ClientException('offline (test)');
      });

      final fixture = await buildFixture(
        companies: const [FakeCompany(id: 'c1', name: 'Acme Co')],
        currentCompanyId: 'c1',
        httpClient: client,
      );
      addTearDown(fixture.dispose);

      await tester.pumpWidget(
        wrapWithShell(
          fixture.services,
          const AccountManagementDangerZoneScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final purgeButton = find.widgetWithText(OutlinedButton, 'Purge Data');
      await tester.ensureVisible(purgeButton);
      await tester.pumpAndSettle();
      await tester.tap(purgeButton);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'purge');
      await tester.enterText(find.byType(TextField).at(2), 'hunter2');
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      // Drive the async submit by hand — do NOT pumpAndSettle while the busy
      // spinner animates (it would never settle).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('The current password is incorrect.'), findsOneWidget);
    },
  );

  group('a user with no password to type', () {
    Future<void> openPurge(WidgetTester tester, PasswordSubject subject) async {
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final fixture = await buildFixture(
        companies: const [FakeCompany(id: 'c1', name: 'Acme Co')],
        currentCompanyId: 'c1',
      );
      addTearDown(fixture.dispose);
      fixture.services.passwordCache.subject = () => subject;
      await tester.pumpWidget(
        wrapWithShell(
          fixture.services,
          const AccountManagementDangerZoneScreen(),
        ),
      );
      await tester.pumpAndSettle();
      final purgeButton = find.widgetWithText(OutlinedButton, 'Purge Data');
      await tester.ensureVisible(purgeButton);
      await tester.pumpAndSettle();
      await tester.tap(purgeButton);
      await tester.pumpAndSettle();
    }

    bool submitEnabled(WidgetTester tester) =>
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
            .onPressed !=
        null;

    testWidgets('an OAuth sign-up the server lets through types only the '
        'confirm word', (tester) async {
      await openPurge(
        tester,
        const PasswordSubject(
          oauthProvider: 'google',
          hasPassword: false,
          oauthPasswordRequired: false,
        ),
      );
      // confirm + cancellation message; no password field.
      expect(find.byType(TextField), findsNWidgets(2));
      await tester.enterText(find.byType(TextField).at(0), 'purge');
      await tester.pump();
      expect(submitEnabled(tester), isTrue);
    });

    testWidgets('with nothing the server accepts, it says to set a password '
        'and cannot submit', (tester) async {
      await openPurge(
        tester,
        const PasswordSubject(
          oauthProvider: 'google',
          hasPassword: false,
          oauthPasswordRequired: true,
        ),
      );
      expect(find.text('Please set an account password'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2));
      await tester.enterText(find.byType(TextField).at(0), 'purge');
      await tester.pump();
      expect(submitEnabled(tester), isFalse);
    });
  });
}
