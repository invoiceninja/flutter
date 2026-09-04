import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/confirm_actions_controller.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/repositories/sync_repository.dart';
import 'package:admin/ui/core/list/entity_actions_popup_button.dart';
import 'package:admin/ui/core/widgets/toast_controller.dart';
import 'package:admin/ui/features/billing_shared/activity/comment_row_menu.dart';
import 'package:admin/ui/features/billing_shared/activity/pending_comment_row.dart';

import '../shell/_shell_test_helpers.dart';

/// The one surface in the app that can really delete a comment
/// (invoiceninja/flutter#123).
///
/// The API has no update or delete route for an activity note and the
/// `activities` table has no soft-delete column, so a note that has reached the
/// server is permanent. Until it drains it is just an outbox row — and dropping
/// that row means the note is never sent at all.
///
/// Driven against a real in-memory `AppDatabase` + `Services`: the verdict this
/// widget reports comes from the database rather than from the call, so a fake
/// `SyncRepository` would assert the wrong thing.
/// Deletes the row and *then* throws, which is `SyncRepository`'s own order:
/// `discardOutboxRow` drops the outbox row first and only afterwards reconciles
/// the parent's `is_dirty` flag, and that cascade can fail. The note is already
/// unsendable at that point, so the user must not be told it survived.
class _ThrowAfterDeleteSync implements SyncRepository {
  _ThrowAfterDeleteSync(this.db);

  @override
  final AppDatabase db;

  @override
  Future<bool> discardOutboxRow(int id) async {
    await db.outboxDao.deleteRow(id);
    throw StateError('reconcile blew up after the row was already gone');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// The fixture's real `Services` with only `sync` swapped.
class _SwappedSync implements Services {
  _SwappedSync(this._inner, this.sync);

  final Services _inner;

  @override
  final SyncRepository sync;

  @override
  AppDatabase get db => _inner.db;

  @override
  ConfirmActionsController get confirmActions => _inner.confirmActions;

  @override
  ToastController get toasts => _inner.toasts;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  Future<ShellFixture> fixture(WidgetTester tester) async {
    final f = await buildFixture(
      companies: [FakeCompany(id: 'co1', name: 'Co', isOwner: true)],
    );
    addTearDown(f.dispose);
    return f;
  }

  Future<OutboxRow> queueComment(
    ShellFixture f, {
    String notes = 'Chasing this up',
    String state = 'pending',
  }) async {
    final id = await f.db.outboxDao.enqueue(
      OutboxCompanion.insert(
        companyId: 'co1',
        entityType: 'client',
        entityId: 'c1',
        mutationKind: 'add_comment',
        payload: '{"entity_id":"c1","notes":"$notes"}',
        idempotencyKey: 'k1',
        nextAttemptAt: 0,
        createdAt: 0,
        state: Value(state),
      ),
    );
    return (await f.db.outboxDao.byId(id))!;
  }

  /// The row spins a `CircularProgressIndicator`, so `pumpAndSettle` would
  /// never return — every pump here is explicit.
  Future<void> pump(ShellFixture f, WidgetTester tester, OutboxRow row) async {
    await tester.pumpWidget(
      wrapWithShell(f.services, PendingCommentRow(row: row)),
    );
    await tester.pump();
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Actions'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('a queued comment offers Copy and Delete', (tester) async {
    final f = await fixture(tester);
    await pump(f, tester, await queueComment(f));
    expect(find.byType(EntityActionsPopupButton<CommentRowAction>), findsOne);
    await openMenu(tester);
    expect(find.widgetWithText(MenuItemButton, 'Copy'), findsOne);
    expect(find.widgetWithText(MenuItemButton, 'Delete'), findsOne);
  });

  testWidgets('Delete drops the row so the note is never sent', (tester) async {
    final f = await fixture(tester);
    f.services.confirmActions.value = false;
    final row = await queueComment(f);
    await pump(f, tester, row);
    await openMenu(tester);
    await tester.tap(find.widgetWithText(MenuItemButton, 'Delete'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(await f.db.outboxDao.byId(row.id), isNull);
  });

  testWidgets('Delete takes the Confirm actions gate', (tester) async {
    // It destroys what the user typed and fires with no further UI step, so it
    // is tagged `confirm` — and `guardedOnTap` reads the preference at tap
    // time, not at build time.
    final f = await fixture(tester);
    f.services.confirmActions.value = true;
    final row = await queueComment(f);
    await pump(f, tester, row);
    await openMenu(tester);
    await tester.tap(find.widgetWithText(MenuItemButton, 'Delete'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Prompted, and it names the note — a card shows two rows and the tab
    // shows every one, so the dialog has to say which.
    expect(find.text('Chasing this up'), findsWidgets);
    expect(await f.db.outboxDao.byId(row.id), isNotNull);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(await f.db.outboxDao.byId(row.id), isNull);
  });

  testWidgets('an in-flight comment offers Copy but not Delete', (
    tester,
  ) async {
    // `discardOutboxRow` only drops the outbox entry for an in-flight row —
    // its request may be landing concurrently. Offering Delete there would
    // remove the comment from the UI while the server keeps it, which is the
    // one thing this surface must never do.
    final f = await fixture(tester);
    await pump(f, tester, await queueComment(f, state: 'in_flight'));
    await openMenu(tester);
    expect(find.widgetWithText(MenuItemButton, 'Copy'), findsOne);
    expect(find.widgetWithText(MenuItemButton, 'Delete'), findsNothing);
  });

  testWidgets('a row claimed by the drain mid-confirm is not discarded', (
    tester,
  ) async {
    // `row` is a build-time snapshot and `guardedOnTap` holds the closure
    // across the Confirm-actions dialog — long enough for a drain to claim it.
    // An open *menu* is safe (the rebuild drops the item), but the dialog is a
    // separate route, and `SyncRepository.discardOutboxRow` re-reads the row
    // and deletes an `in_flight` one **anyway**. Without a re-read here the
    // comment would vanish from the UI while its request lands.
    final f = await fixture(tester);
    f.services.confirmActions.value = true;
    final row = await queueComment(f);
    await pump(f, tester, row);
    await openMenu(tester);
    await tester.tap(find.widgetWithText(MenuItemButton, 'Delete'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // The drain claims it while the prompt is up.
    await f.db.outboxDao.markInFlight(row.id);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final still = await f.db.outboxDao.byId(row.id);
    expect(still, isNotNull, reason: 'an in-flight note must not be dropped');
    expect(still!.state, 'in_flight');
  });

  testWidgets('a cascade that throws after the row is gone reports no error', (
    tester,
  ) async {
    // The verdict comes from the database, never from the call: by the time
    // `discardOutboxRow`'s reconcile can throw, the row is deleted and the note
    // will never be sent. Saying "An error occurred" there tells the user their
    // comment survived when it did not.
    final f = await fixture(tester);
    f.services.confirmActions.value = false;
    final row = await queueComment(f);
    final services = _SwappedSync(f.services, _ThrowAfterDeleteSync(f.db));
    await tester.pumpWidget(
      wrapWithShell(services, PendingCommentRow(row: row)),
    );
    await tester.pump();
    await openMenu(tester);
    await tester.tap(find.widgetWithText(MenuItemButton, 'Delete'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(await f.db.outboxDao.byId(row.id), isNull);
    expect(find.text('An error occurred'), findsNothing);
  });
}
