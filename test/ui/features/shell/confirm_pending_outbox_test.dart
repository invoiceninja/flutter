// A full logout wipes `dead` outbox rows too — the changes the server
// rejected, waiting (with their dirty local rows) for a fix-and-retry. The
// pending prompt deliberately ignores them ("Sync first" can't help a row the
// server refused), so they used to be destroyed with no warning at all.

import 'package:admin/data/db/app_database.dart';
import 'package:admin/ui/features/shell/widgets/confirm_pending_outbox.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '_shell_test_helpers.dart';

void main() {
  Future<({ShellFixture fixture, List<OutboxConfirmResult> results})> setUp(
    WidgetTester tester, {
    required bool checkAllCompanies,
  }) async {
    final fixture = await buildFixture(
      companies: const [FakeCompany(id: 'c1', name: 'Acme Co', token: 't1')],
      currentCompanyId: 'c1',
    );
    addTearDown(fixture.dispose);
    await fixture.db.outboxDao.enqueue(
      OutboxCompanion.insert(
        companyId: 'c1',
        entityType: 'client',
        entityId: 'x',
        mutationKind: 'update',
        payload: '{}',
        idempotencyKey: 'k',
        createdAt: 0,
        nextAttemptAt: 0,
        state: const Value('dead'),
      ),
    );
    final results = <OutboxConfirmResult>[];
    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => results.add(
              await confirmPendingOutboxIfAny(
                context,
                companyId: 'c1',
                checkAllCompanies: checkAllCompanies,
              ),
            ),
            child: const Text('trigger'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();
    return (fixture: fixture, results: results);
  }

  Future<void> tearDownTree(WidgetTester tester, ShellFixture fixture) async {
    fixture.services.recentlyViewed.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  final failedBody = find.textContaining("couldn't be saved to the server");

  testWidgets('a full logout asks about failed changes; Cancel keeps them', (
    tester,
  ) async {
    final (:fixture, :results) = await setUp(tester, checkAllCompanies: true);

    expect(failedBody, findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(results, [OutboxConfirmResult.cancelled]);
    expect(await fixture.db.outboxDao.deadCountAll(), 1);
    await tearDownTree(tester, fixture);
  });

  testWidgets('Discard lets the logout proceed', (tester) async {
    final (:fixture, :results) = await setUp(tester, checkAllCompanies: true);

    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    expect(results, [OutboxConfirmResult.proceed]);
    await tearDownTree(tester, fixture);
  });

  testWidgets('a company switch keeps the database, so it never asks', (
    tester,
  ) async {
    final (:fixture, :results) = await setUp(tester, checkAllCompanies: false);

    expect(failedBody, findsNothing);
    expect(results, [OutboxConfirmResult.proceed]);
    await tearDownTree(tester, fixture);
  });
}
