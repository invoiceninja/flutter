// Verifies the SyncEventListener escalation added for unrecoverable outbox
// failures: when the user is online and no caller is surfacing the failure
// itself, a dead row pops a MODAL (so the user can't miss it); offline it
// stays a non-blocking toast. Uses the real `Services` from the shell test
// helpers so the actual `services.sync` event stream + `connectivity` drive
// the listener, not a stub.

import 'package:admin/data/db/app_database.dart';
import 'package:admin/ui/features/shell/widgets/sync_event_listener.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '_shell_test_helpers.dart';

void main() {
  // Enqueue a row whose mutation kind can't be parsed: the drain marks it dead
  // and emits a DeadEvent (handledByCaller=false, since no `awaitRow` caller) —
  // the same shape a 400 reactivate-email failure produces, without needing a
  // mock HTTP layer.
  Future<void> enqueueDeadlyRow(
    ShellFixture fixture,
  ) => fixture.services.db.outboxDao.enqueue(
    OutboxCompanion.insert(
      companyId: 'co',
      entityType:
          'client', // registered, so we hit "unknown kind" not "no dispatcher"
      entityId: 'c1',
      mutationKind: 'action:bogus',
      payload: '{}',
      idempotencyKey: 'k1',
      nextAttemptAt: 0,
      createdAt: 0,
    ),
  );

  testWidgets('online + caller-unhandled dead row → modal alert', (
    tester,
  ) async {
    final fixture = await buildFixture(
      companies: const [FakeCompany(id: 'co', name: 'Co')],
      currentCompanyId: 'co',
      online: true,
    );
    addTearDown(fixture.dispose);

    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        const SyncEventListener(child: SizedBox.shrink()),
      ),
    );
    // Let the listener subscribe (it does so in didChangeDependencies) BEFORE
    // the event is produced — the event stream is broadcast and doesn't buffer.
    await tester.pump();

    await enqueueDeadlyRow(fixture);
    await fixture.services.sync.drainOnce(companyId: 'co');
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Could not save'), findsOneWidget);
    expect(find.text('View'), findsOneWidget);
    expect(find.text('Dismiss'), findsOneWidget);

    // Dismiss closes the modal.
    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('offline → no modal (stays a toast, never blocks the user)', (
    tester,
  ) async {
    final fixture = await buildFixture(
      companies: const [FakeCompany(id: 'co', name: 'Co')],
      currentCompanyId: 'co',
      online: false,
    );
    addTearDown(fixture.dispose);

    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        const SyncEventListener(child: SizedBox.shrink()),
      ),
    );
    await tester.pump();

    await enqueueDeadlyRow(fixture);
    await fixture.services.sync.drainOnce(companyId: 'co');
    await tester.pumpAndSettle();

    expect(
      find.byType(AlertDialog),
      findsNothing,
      reason: 'offline failures must not pop a blocking modal',
    );
  });

  // Overlapping conflict/password events are DEFERRED and replayed when the
  // current modal closes (neither is re-emitted by the sync engine). For a
  // password event that replay is wrong: `retryPasswordRows` re-arms every
  // parked row in the company at once, so the deferred event is already
  // satisfied — replaying it reopened the sheet the instant the user dismissed
  // it, asking again for the password they had just typed.
  /// Two destructive mutations that both 412 on their first attempt — the
  /// ordinary shape of two offline deletes, and the case that produces a
  /// SECOND `PasswordRequiredEvent` while the first sheet is still open.
  Future<void> enqueueTwo412Rows(ShellFixture fixture) async {
    for (final id in ['c1', 'c2']) {
      await fixture.services.db.outboxDao.enqueue(
        OutboxCompanion.insert(
          companyId: 'co',
          entityType: 'client',
          entityId: id,
          mutationKind: 'delete',
          payload: '{}',
          idempotencyKey: 'k-$id',
          nextAttemptAt: 0,
          createdAt: 0,
        ),
      );
    }
    await fixture.services.sync.drainOnce(companyId: 'co');
  }

  testWidgets('a second 412 row does not re-open the password sheet', (
    tester,
  ) async {
    final fixture = await buildFixture(
      companies: const [FakeCompany(id: 'co', name: 'Co')],
      currentCompanyId: 'co',
      online: true,
      httpClient: MockClient(
        (_) async => http.Response('{"message":"Invalid Password"}', 412),
      ),
    );
    addTearDown(fixture.dispose);

    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        const SyncEventListener(child: SizedBox.shrink()),
      ),
    );
    await tester.pump();

    await enqueueTwo412Rows(fixture);
    await tester.pumpAndSettle();

    expect(
      find.byType(AlertDialog),
      findsOneWidget,
      reason: 'the first 412 must prompt',
    );

    await tester.enterText(find.byType(TextField).first, 'hunter2');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    expect(
      find.byType(AlertDialog),
      findsNothing,
      reason: 'the deferred second password event must not re-prompt',
    );
  });

  // The cancel twin of the above. Dropping the deferred event only on the
  // SUCCESS path left this worse than before the deferral existed: the user
  // declines and the sheet reopens instantly, rather than the row simply dying
  // into the Outbox.
  testWidgets('cancelling the password sheet does not re-prompt', (
    tester,
  ) async {
    final fixture = await buildFixture(
      companies: const [FakeCompany(id: 'co', name: 'Co')],
      currentCompanyId: 'co',
      online: true,
      httpClient: MockClient(
        (_) async => http.Response('{"message":"Invalid Password"}', 412),
      ),
    );
    addTearDown(fixture.dispose);

    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        const SyncEventListener(child: SizedBox.shrink()),
      ),
    );
    await tester.pump();

    await enqueueTwo412Rows(fixture);
    await tester.pumpAndSettle();

    expect(
      find.byType(AlertDialog),
      findsOneWidget,
      reason: 'the first 412 must prompt',
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(
      find.byType(AlertDialog),
      findsNothing,
      reason: 'a declined prompt must not immediately re-ask',
    );
  });
}
