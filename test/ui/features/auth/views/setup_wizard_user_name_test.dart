import 'dart:convert';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/ui/features/auth/views/setup_wizard_screen.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../shell/_shell_test_helpers.dart';

/// The wizard asks for the user's own name only when the account has none —
/// an Apple sign-up whose user hid their name, or an email sign-up — as
/// admin-portal's wizard did.
void main() {
  Future<ShellFixture> fixtureWithUser({
    required String firstName,
    required String lastName,
  }) async {
    final fixture = await buildFixture(
      companies: const [FakeCompany(id: 'c1', name: 'Untitled Company')],
      currentCompanyId: 'c1',
    );
    final db = fixture.db;
    await db.userSettingsDao.upsert(
      UserSettingsCompanion.insert(companyId: 'c1', userId: 'u1', updatedAt: 0),
    );
    await db.userDao.upsert(
      UsersCompanion(
        id: const Value('u1'),
        companyId: const Value('c1'),
        firstName: Value(firstName),
        lastName: Value(lastName),
        email: const Value('ada@example.com'),
        phone: const Value(''),
        languageId: const Value(''),
        signature: const Value(''),
        payload: Value(jsonEncode({'id': 'u1', 'email': 'ada@example.com'})),
        createdAt: const Value(0),
        updatedAt: const Value(0),
      ),
    );
    // Re-read the session so it picks up the seeded user.
    await fixture.services.auth.restore();
    fixture.services.refreshScheduler.stop();
    return fixture;
  }

  testWidgets('a nameless user is asked for a first and last name', (
    tester,
  ) async {
    final fixture = await fixtureWithUser(firstName: '', lastName: '');
    addTearDown(fixture.dispose);
    await tester.pumpWidget(
      wrapWithShell(fixture.services, const SetupWizardScreen()),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('setup_first_name')), findsOneWidget);
    expect(find.byKey(const ValueKey('setup_last_name')), findsOneWidget);
  });

  testWidgets('a named user is not asked again', (tester) async {
    final fixture = await fixtureWithUser(firstName: 'Ada', lastName: '');
    addTearDown(fixture.dispose);
    await tester.pumpWidget(
      wrapWithShell(fixture.services, const SetupWizardScreen()),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('setup_first_name')), findsNothing);
  });
}
