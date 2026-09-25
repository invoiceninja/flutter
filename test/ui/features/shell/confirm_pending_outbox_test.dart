// A full logout wipes `dead` outbox rows too — the changes the server
// rejected, waiting (with their dirty local rows) for a fix-and-retry. The
// pending prompt deliberately ignores them ("Sync first" can't help a row the
// server refused), so they used to be destroyed with no warning at all.

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/repositories/sync_repository.dart';
import 'package:admin/ui/features/shell/widgets/confirm_pending_outbox.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../_localization_helper.dart';
import '_shell_test_helpers.dart';

void main() {
  OutboxCompanion row(
    String entityId, {
    String state = 'pending',
    String key = 'k',
    int nextAttemptAt = 0,
    String? lastError,
  }) => OutboxCompanion.insert(
    companyId: 'c1',
    entityType: 'client',
    entityId: entityId,
    mutationKind: 'update',
    payload: '{}',
    idempotencyKey: key,
    createdAt: 0,
    nextAttemptAt: nextAttemptAt,
    state: Value(state),
    lastError: Value(lastError),
  );

  /// Seed [rows] for company c1, then run the prompt.
  Future<({ShellFixture fixture, List<OutboxConfirmResult> results})> setUpRows(
    WidgetTester tester, {
    required bool checkAllCompanies,
    required List<OutboxCompanion> rows,
  }) async {
    final fixture = await buildFixture(
      companies: const [FakeCompany(id: 'c1', name: 'Acme Co', token: 't1')],
      currentCompanyId: 'c1',
    );
    addTearDown(fixture.dispose);
    for (final r in rows) {
      await fixture.db.outboxDao.enqueue(r);
    }
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

  Future<({ShellFixture fixture, List<OutboxConfirmResult> results})> setUp(
    WidgetTester tester, {
    required bool checkAllCompanies,
    String state = 'dead',
  }) => setUpRows(
    tester,
    checkAllCompanies: checkAllCompanies,
    rows: [row('x', state: state)],
  );

  Future<void> tearDownTree(WidgetTester tester, ShellFixture fixture) async {
    fixture.services.recentlyViewed.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  final failedBody = find.textContaining('is waiting in the Outbox for you');

  testWidgets('a full logout asks about failed changes; Cancel keeps them', (
    tester,
  ) async {
    final (:fixture, :results) = await setUp(tester, checkAllCompanies: true);

    expect(failedBody, findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(results, [OutboxConfirmResult.cancelled]);
    expect(await fixture.db.outboxDao.attentionCountAll(), 1);
    await tearDownTree(tester, fixture);
  });

  testWidgets('a change that may already have gone through is asked about '
      'too, and offers the Outbox', (tester) async {
    final (:fixture, :results) = await setUp(
      tester,
      checkAllCompanies: true,
      state: 'unconfirmed',
    );

    expect(failedBody, findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'View'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(results, [OutboxConfirmResult.cancelled]);
    expect(await fixture.db.outboxDao.attentionCountAll(), 1);
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

  group('Discard in the pending prompt', () {
    testWidgets('deletes nothing until the sign-out review is passed too — '
        'Cancel there keeps it', (tester) async {
      // The pending prompt's Discard ran at once, so a Cancel in the review
      // that follows cancelled the sign-out with the changes already gone.
      final (:fixture, :results) = await setUpRows(
        tester,
        checkAllCompanies: true,
        rows: [
          row('x', key: 'k1'),
          row('y', state: 'dead', key: 'k2'),
        ],
      );

      await tester.tap(find.widgetWithText(TextButton, 'Discard'));
      await tester.pumpAndSettle();
      expect(failedBody, findsOneWidget);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(results, [OutboxConfirmResult.cancelled]);
      expect(await fixture.db.outboxDao.pendingCountForCompany('c1'), 1);
      await tearDownTree(tester, fixture);
    });

    testWidgets('nothing drains while the review is open — a reconnect\'s '
        'drain sent what the user had just chosen to discard', (tester) async {
      final (:fixture, :results) = await setUpRows(
        tester,
        checkAllCompanies: true,
        rows: [
          row('x', key: 'k1'),
          row('y', state: 'dead', key: 'k2'),
        ],
      );
      Future<OutboxRow> chosen() async =>
          (await fixture.db.select(fixture.db.outbox).get()).firstWhere(
            (r) => r.entityId == 'x',
          );

      await tester.tap(find.widgetWithText(TextButton, 'Discard'));
      await tester.pumpAndSettle();
      expect(failedBody, findsOneWidget);
      // Due again while the review is up — its backoff ran out, say — when a
      // reconnect kicks a drain.
      final due = await chosen();
      await fixture.db.outboxDao.scheduleRetry(
        id: due.id,
        attempts: due.attempts,
        nextAttemptAt: 0,
        error: 'before the review',
      );
      await tester.runAsync(
        () => fixture.services.sync.drainOnce(companyId: 'c1'),
      );

      final kept = await chosen();
      expect(kept.state, 'pending');
      expect(kept.lastError, 'before the review', reason: 'never attempted');
      expect(kept.nextAttemptAt, 0);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(results, [OutboxConfirmResult.cancelled]);

      // Kept, and sending again: the drains the review held are back.
      await tester.runAsync(
        () => fixture.services.sync.drainOnce(companyId: 'c1'),
      );
      expect((await chosen()).lastError, isNot('before the review'));
      await tearDownTree(tester, fixture);
    });

    testWidgets('discards once the review is passed as well', (tester) async {
      final (:fixture, :results) = await setUpRows(
        tester,
        checkAllCompanies: true,
        rows: [
          row('x', key: 'k1'),
          row('y', state: 'dead', key: 'k2'),
        ],
      );

      await tester.tap(find.widgetWithText(TextButton, 'Discard'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      expect(results, [OutboxConfirmResult.proceed]);
      expect(await fixture.db.outboxDao.pendingCountForCompany('c1'), 0);
      await tearDownTree(tester, fixture);
    });

    testWidgets('discards straight away on a company switch', (tester) async {
      final (:fixture, :results) = await setUpRows(
        tester,
        checkAllCompanies: false,
        rows: [row('x')],
      );

      await tester.tap(find.widgetWithText(TextButton, 'Discard'));
      await tester.pumpAndSettle();

      expect(results, [OutboxConfirmResult.proceed]);
      expect(await fixture.db.outboxDao.pendingCountForCompany('c1'), 0);
      await tearDownTree(tester, fixture);
    });
  });

  group('the review\'s View', () {
    Future<ShellFixture> fixtureWithDeadRowIn(List<String> companies) async {
      final fixture = await buildFixture(
        companies: const [FakeCompany(id: 'c1', name: 'Acme Co', token: 't1')],
        currentCompanyId: 'c1',
      );
      addTearDown(fixture.dispose);
      for (final (i, companyId) in companies.indexed) {
        await fixture.db.outboxDao.enqueue(
          OutboxCompanion.insert(
            companyId: companyId,
            entityType: 'client',
            entityId: 'x',
            mutationKind: 'update',
            payload: '{}',
            idempotencyKey: 'k$i',
            createdAt: 0,
            nextAttemptAt: 0,
            state: const Value('dead'),
          ),
        );
      }
      return fixture;
    }

    testWidgets('opens the Outbox of the company whose change failed', (
      tester,
    ) async {
      // The review counts every company, and the Outbox shows only the
      // active one: View opened an Outbox with nothing to see.
      final fixture = await fixtureWithDeadRowIn(['c2']);
      expect(
        await outboxLocationNeedingAttention(
          fixture.services.sync,
          activeCompanyId: 'c1',
        ),
        '/sync/outbox?company=c2',
      );
      fixture.services.recentlyViewed.dispose();
    });

    testWidgets('its button goes there', (tester) async {
      final fixture = await fixtureWithDeadRowIn(['c2']);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () => confirmPendingOutboxIfAny(
                  context,
                  companyId: 'c1',
                  checkAllCompanies: true,
                ),
                child: const Text('trigger'),
              ),
            ),
          ),
          GoRoute(
            path: '/sync/outbox',
            builder: (_, state) => Text(
              'outbox of ${state.uri.queryParameters['company'] ?? 'c1'}',
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        Provider<Services>.value(
          value: fixture.services,
          child: MaterialApp.router(
            theme: buildInTheme(InTheme.light),
            localizationsDelegates: kTestLocalizationsDelegates,
            supportedLocales: kTestSupportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('trigger'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'View'));
      await tester.pumpAndSettle();

      expect(find.text('outbox of c2'), findsOneWidget);
      fixture.services.recentlyViewed.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });

    testWidgets('stays on the active company when it has one too', (
      tester,
    ) async {
      final fixture = await fixtureWithDeadRowIn(['c2', 'c1']);
      expect(
        await outboxLocationNeedingAttention(
          fixture.services.sync,
          activeCompanyId: 'c1',
        ),
        '/sync/outbox',
      );
      fixture.services.recentlyViewed.dispose();
    });
  });

  testWidgets('Sync first says when what is left waits on another change', (
    tester,
  ) async {
    // A save held behind a change that may already have gone through can't be
    // sent until the user deals with that change: a bare "Sync failed", every
    // time, gave no way forward.
    final (:fixture, :results) = await setUpRows(
      tester,
      checkAllCompanies: false,
      rows: [
        row('x', state: 'unconfirmed', key: 'k1'),
        row(
          'x',
          key: 'k2',
          nextAttemptAt: 1 << 50,
          lastError: kHeldBehindUnconfirmedError,
        ),
      ],
    );

    await tester.tap(find.text('Sync first'));
    await tester.pumpAndSettle();

    expect(results, [OutboxConfirmResult.cancelled]);
    expect(
      find.text(
        'Some changes are waiting on an earlier one — check it in '
        'the Outbox',
      ),
      findsOneWidget,
    );
    expect(find.text('Sync failed'), findsNothing);
    fixture.services.toasts.clearAll();
    await tearDownTree(tester, fixture);
  });
}
