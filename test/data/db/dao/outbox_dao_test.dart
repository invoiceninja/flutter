import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';

/// Targeted tests for the three Outbox screen / 422-surface entry points
/// added on top of the existing dao. The broader state-machine coverage
/// (markDead, scheduleRetry, rewriteTempIdInPayloads, …) lives in
/// `sync_repository_test.dart`.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() async {
    await db.close();
  });

  Future<int> enqueue({
    String companyId = 'co',
    String entityType = 'client',
    String entityId = 'c1',
    String kind = 'update',
    String idempotencyKey = 'k',
    int createdAt = 0,
    String state = 'pending',
  }) async {
    final id = await db.outboxDao.enqueue(
      OutboxCompanion.insert(
        companyId: companyId,
        entityType: entityType,
        entityId: entityId,
        mutationKind: kind,
        payload: jsonEncode({'id': entityId}),
        idempotencyKey: idempotencyKey,
        nextAttemptAt: 0,
        createdAt: createdAt,
        state: Value(state),
      ),
    );
    return id;
  }

  group('watchAll', () {
    test(
      'emits every row for the company regardless of state, newest first',
      () async {
        final older = await enqueue(entityId: 'a', createdAt: 1, state: 'dead');
        final newer = await enqueue(entityId: 'b', createdAt: 2);
        final inFlight = await enqueue(
          entityId: 'c',
          createdAt: 3,
          state: 'in_flight',
        );
        // A row from a different company must not leak into this stream.
        await enqueue(companyId: 'other', entityId: 'd', createdAt: 4);

        final rows = await db.outboxDao.watchAll('co').first;
        expect(rows.map((r) => r.id), [inFlight, newer, older]);
      },
    );
  });

  group('companiesWithAttentionRows', () {
    test('companies with a dead or unconfirmed row, in order', () async {
      // The sign-out review counts these everywhere; its View opens the
      // Outbox of a company that has one.
      await enqueue(companyId: 'co_b', state: 'dead', idempotencyKey: 'k1');
      await enqueue(
        companyId: 'co_a',
        state: 'unconfirmed',
        idempotencyKey: 'k2',
      );
      await enqueue(companyId: 'co_pending', idempotencyKey: 'k3');

      expect(await db.outboxDao.companiesWithAttentionRows(), ['co_a', 'co_b']);
    });
  });

  group('countPendingParkedWith', () {
    test(
      'counts pending rows parked with one of the errors, in the company',
      () async {
        Future<void> parked(int id, String error) => db.outboxDao.scheduleRetry(
          id: id,
          attempts: 0,
          nextAttemptAt: 60000,
          error: error,
        );
        await parked(await enqueue(idempotencyKey: 'k1'), 'held');
        await parked(await enqueue(idempotencyKey: 'k2'), 'waiting');
        await parked(await enqueue(idempotencyKey: 'k3'), 'Down');
        await parked(
          await enqueue(companyId: 'other', idempotencyKey: 'k4'),
          'held',
        );
        final dead = await enqueue(idempotencyKey: 'k5');
        await db.outboxDao.markDead(id: dead, error: 'held', statusCode: 422);

        expect(
          await db.outboxDao.countPendingParkedWith(
            companyId: 'co',
            errors: const ['held', 'waiting'],
          ),
          2,
        );
      },
    );
  });

  group('liveCreateRowFor', () {
    test('a create on the wire wins over a newer one still queued — the '
        'record lands with it', () async {
      // Asked for the newest, it read the queued one: behind a change that
      // waits on the user, a save that will land was reported as rejected.
      final onTheWire = await enqueue(
        entityId: 'tmp_1',
        kind: 'create',
        idempotencyKey: 'k1',
      );
      await db.outboxDao.markInFlight(onTheWire);
      await enqueue(entityId: 'tmp_1', kind: 'create', idempotencyKey: 'k2');

      final row = await db.outboxDao.liveCreateRowFor(
        companyId: 'co',
        entityId: 'tmp_1',
      );
      expect(row?.id, onTheWire);
    });

    test('otherwise the newest queued create, and never a dead one', () async {
      final dead = await enqueue(
        entityId: 'tmp_1',
        kind: 'create',
        idempotencyKey: 'k1',
      );
      await db.outboxDao.markDead(id: dead, error: 'bad', statusCode: 422);
      expect(
        await db.outboxDao.liveCreateRowFor(companyId: 'co', entityId: 'tmp_1'),
        isNull,
      );
      final queued = await enqueue(
        entityId: 'tmp_1',
        kind: 'create',
        idempotencyKey: 'k2',
      );
      expect(
        (await db.outboxDao.liveCreateRowFor(
          companyId: 'co',
          entityId: 'tmp_1',
        ))?.id,
        queued,
      );
    });
  });

  group('companiesWithActiveRows', () {
    test(
      'distinct companies with pending or in_flight rows; dead-only '
      'companies excluded (the full-logout guard reads this — the outbox '
      'is ground truth even when a company vanished from the session)',
      () async {
        await enqueue(companyId: 'co_pending', idempotencyKey: 'k1');
        await enqueue(
          companyId: 'co_pending',
          entityId: 'c2',
          idempotencyKey: 'k2',
        );
        await enqueue(
          companyId: 'co_inflight',
          state: 'in_flight',
          idempotencyKey: 'k3',
        );
        await enqueue(
          companyId: 'co_dead',
          state: 'dead',
          idempotencyKey: 'k4',
        );

        final companies = await db.outboxDao.companiesWithActiveRows();
        expect(
          companies,
          unorderedEquals(['co_pending', 'co_inflight']),
          reason: 'distinct, non-dead only',
        );
      },
    );

    test('empty when the outbox holds nothing actionable', () async {
      await enqueue(state: 'dead');
      expect(await db.outboxDao.companiesWithActiveRows(), isEmpty);
    });
  });

  group('unsynced-work probes (what a destructive logout must consult)', () {
    test('companiesWithUnsyncedRows counts dead rows — a rejected edit is '
        'still the user\'s unsynced work', () async {
      await enqueue(companyId: 'co_pending', idempotencyKey: 'k1');
      await enqueue(companyId: 'co_dead', state: 'dead', idempotencyKey: 'k2');
      expect(
        await db.outboxDao.companiesWithUnsyncedRows(),
        unorderedEquals(['co_pending', 'co_dead']),
      );
      // The prompt's "can Sync first help" query stays dead-free.
      expect(await db.outboxDao.companiesWithActiveRows(), ['co_pending']);
    });

    test('attentionCountAll counts failed and unconfirmed rows across every '
        'company', () async {
      await enqueue(companyId: 'a', state: 'dead', idempotencyKey: 'k1');
      await enqueue(companyId: 'b', state: 'dead', idempotencyKey: 'k2');
      await enqueue(companyId: 'b', state: 'unconfirmed', idempotencyKey: 'k4');
      await enqueue(companyId: 'b', idempotencyKey: 'k3');
      expect(await db.outboxDao.attentionCountAll(), 3);
    });

    test('hasAnyRows sees any state and nothing else', () async {
      expect(await db.outboxDao.hasAnyRows(), isFalse);
      await enqueue(state: 'dead');
      expect(await db.outboxDao.hasAnyRows(), isTrue);
    });
  });

  group('findDeadSaveForEntity', () {
    test('returns the newest dead row for the (type, id) tuple', () async {
      await enqueue(entityId: 'c1', state: 'dead', idempotencyKey: 'k1');
      final newerDead = await enqueue(
        entityId: 'c1',
        state: 'dead',
        idempotencyKey: 'k2',
      );
      // Pending rows for the same entity are excluded.
      await enqueue(entityId: 'c1', idempotencyKey: 'k3');
      // Dead rows for a different entity are excluded.
      await enqueue(entityId: 'c2', state: 'dead', idempotencyKey: 'k4');

      final row = await db.outboxDao.findDeadSaveForEntity(
        companyId: 'co',
        entityType: 'client',
        entityId: 'c1',
      );
      expect(row?.id, newerDead);
    });

    test('finds the record\'s failed SAVE, never another failed change to '
        'it', () async {
      // A rejected email on the same record used to match: the form opened
      // on its error, and the next good save deleted it.
      final save = await enqueue(
        entityId: 'c1',
        state: 'dead',
        idempotencyKey: 'k1',
      );
      await enqueue(
        entityId: 'c1',
        kind: 'email_entity',
        state: 'dead',
        idempotencyKey: 'k2',
      );
      final row = await db.outboxDao.findDeadSaveForEntity(
        companyId: 'co',
        entityType: 'client',
        entityId: 'c1',
      );
      expect(row?.id, save);
    });

    test('returns null when no dead row exists', () async {
      await enqueue(entityId: 'c1'); // pending
      final row = await db.outboxDao.findDeadSaveForEntity(
        companyId: 'co',
        entityType: 'client',
        entityId: 'c1',
      );
      expect(row, isNull);
    });
  });

  group('deleteOlderDeadSaves', () {
    test('drops the record\'s failed saves older than the given row, and '
        'nothing else', () async {
      final olderUpdate = await enqueue(state: 'dead', idempotencyKey: 'k1');
      final olderCreate = await enqueue(
        kind: 'create',
        state: 'dead',
        idempotencyKey: 'k2',
      );
      final email = await enqueue(
        kind: 'email_entity',
        state: 'dead',
        idempotencyKey: 'k3',
      );
      final pending = await enqueue(idempotencyKey: 'k4');
      final otherRecord = await enqueue(
        entityId: 'c2',
        state: 'dead',
        idempotencyKey: 'k5',
      );
      final discarded = await enqueue(idempotencyKey: 'k6');
      final newer = await enqueue(state: 'dead', idempotencyKey: 'k7');

      final deleted = await db.outboxDao.deleteOlderDeadSaves(
        companyId: 'co',
        entityType: 'client',
        entityId: 'c1',
        beforeId: discarded,
        includeCreates: true,
      );

      expect(deleted, 2);
      expect(await db.outboxDao.byId(olderUpdate), isNull);
      expect(await db.outboxDao.byId(olderCreate), isNull);
      for (final kept in [email, pending, otherRecord, discarded, newer]) {
        expect(await db.outboxDao.byId(kept), isNotNull, reason: 'row $kept');
      }
    });

    test('spares a failed create unless told to take it', () async {
      final create = await enqueue(
        kind: 'create',
        state: 'dead',
        idempotencyKey: 'k1',
      );
      final later = await enqueue(idempotencyKey: 'k2');

      await db.outboxDao.deleteOlderDeadSaves(
        companyId: 'co',
        entityType: 'client',
        entityId: 'c1',
        beforeId: later,
        includeCreates: false,
      );

      expect(await db.outboxDao.byId(create), isNotNull);
    });
  });

  group('findDiscardableForEntity', () {
    // Backs "Discard failed save" on BOTH edit scaffolds. `findDeadSaveForEntity`
    // was the wrong query there: only a 422 kills a row, so a 5xx or a lost
    // connection leaves the banner up over a `pending` row the dead-only
    // lookup cannot see — the tap cleared the banner and left the queued write
    // to apply anyway.
    test(
      'finds a still-pending row, which findDeadSaveForEntity cannot',
      () async {
        final pending = await enqueue(entityId: 'c1', idempotencyKey: 'k1');

        expect(
          await db.outboxDao.findDeadSaveForEntity(
            companyId: 'co',
            entityType: 'client',
            entityId: 'c1',
          ),
          isNull,
          reason: 'precondition: the row is retrying, not dead',
        );
        final row = await db.outboxDao.findDiscardableForEntity(
          companyId: 'co',
          entityType: 'client',
          entityId: 'c1',
        );
        expect(row?.id, pending);
      },
    );

    test('prefers the newest row, dead or pending', () async {
      await enqueue(entityId: 'c1', state: 'dead', idempotencyKey: 'k1');
      final newest = await enqueue(entityId: 'c1', idempotencyKey: 'k2');

      final row = await db.outboxDao.findDiscardableForEntity(
        companyId: 'co',
        entityType: 'client',
        entityId: 'c1',
      );
      expect(row?.id, newest);
    });

    test('never returns an in-flight row', () async {
      // `discardOutboxRow` deletes an in-flight row while its request stays on
      // the wire — right for the Outbox screen's explicit Discard, and exactly
      // the lie the banner exists to avoid.
      await enqueue(entityId: 'c1', state: 'in_flight', idempotencyKey: 'k1');

      expect(
        await db.outboxDao.findDiscardableForEntity(
          companyId: 'co',
          entityType: 'client',
          entityId: 'c1',
        ),
        isNull,
      );
    });

    test('never returns a non-save mutation on the same record', () async {
      // A discard abandons the ROW, not the ENTITY: an `add_comment` is
      // enqueued under the PARENT's type + id, and is unrelated user work.
      await enqueue(entityId: 'c1', kind: 'add_comment', idempotencyKey: 'k1');
      await enqueue(entityId: 'c1', kind: 'archive', idempotencyKey: 'k2');

      expect(
        await db.outboxDao.findDiscardableForEntity(
          companyId: 'co',
          entityType: 'client',
          entityId: 'c1',
        ),
        isNull,
      );

      final save = await enqueue(entityId: 'c1', idempotencyKey: 'k3');
      final row = await db.outboxDao.findDiscardableForEntity(
        companyId: 'co',
        entityType: 'client',
        entityId: 'c1',
      );
      expect(
        row?.id,
        save,
        reason: 'the newer comment/archive rows must not shadow the save',
      );
    });

    test('is scoped to the company and the record', () async {
      await enqueue(companyId: 'other', entityId: 'c1', idempotencyKey: 'k1');
      await enqueue(entityId: 'c2', idempotencyKey: 'k2');
      await enqueue(
        entityType: 'invoice',
        entityId: 'c1',
        idempotencyKey: 'k3',
      );

      expect(
        await db.outboxDao.findDiscardableForEntity(
          companyId: 'co',
          entityType: 'client',
          entityId: 'c1',
        ),
        isNull,
      );
    });
  });

  group('markDead', () {
    test(
      'persists fieldErrorsJson alongside the message + status code',
      () async {
        final id = await enqueue();
        await db.outboxDao.markDead(
          id: id,
          error: 'Validation failed',
          statusCode: 422,
          fieldErrorsJson: '{"name":["is required"]}',
        );
        final row = (await (db.select(
          db.outbox,
        )..where((o) => o.id.equals(id))).get()).single;
        expect(row.state, 'dead');
        expect(row.lastError, 'Validation failed');
        expect(row.lastStatusCode, 422);
        expect(row.fieldErrorsJson, '{"name":["is required"]}');
      },
    );
  });

  group('staleRowsForCompany', () {
    test(
      'returns dead + in_flight + far-future-pending rows, scoped to company',
      () async {
        final now = 1000000;
        final dayMs = const Duration(days: 1).inMilliseconds;

        Future<int> add({
          String companyId = 'co',
          String entityId = 'e',
          String state = 'pending',
          int nextAttemptAt = 0,
        }) async {
          return db.outboxDao.enqueue(
            OutboxCompanion.insert(
              companyId: companyId,
              entityType: 'client',
              entityId: entityId,
              mutationKind: 'update',
              payload: '{}',
              idempotencyKey: 'k$entityId$state',
              nextAttemptAt: nextAttemptAt,
              createdAt: now,
              state: Value(state),
            ),
          );
        }

        final dead = await add(entityId: 'dead', state: 'dead');
        final inFlight = await add(entityId: 'flight', state: 'in_flight');
        // Pending parked > 24 h out — stale.
        final parked = await add(
          entityId: 'parked',
          nextAttemptAt: now + 365 * dayMs,
        );
        // Fresh pending — NOT stale.
        await add(entityId: 'fresh', nextAttemptAt: now + 1000);
        // Pending parked just at threshold — NOT stale (strictly greater).
        await add(entityId: 'edge', nextAttemptAt: now + dayMs);
        // Different company — must not leak.
        await add(companyId: 'other', entityId: 'other-dead', state: 'dead');

        final rows = await db.outboxDao.staleRowsForCompany(
          companyId: 'co',
          now: now,
        );
        expect(rows.map((r) => r.id), [dead, inFlight, parked]);
      },
    );
  });

  group('resetInFlightForCompany', () {
    test('re-arms orphaned in_flight rows to pending, scoped to the company, '
        'leaving pending and dead rows untouched', () async {
      final orphanA = await enqueue(
        entityId: 'a',
        state: 'in_flight',
        idempotencyKey: 'k1',
      );
      final orphanB = await enqueue(
        entityId: 'b',
        state: 'in_flight',
        idempotencyKey: 'k2',
      );
      final stillPending = await enqueue(entityId: 'c', idempotencyKey: 'k3');
      final dead = await enqueue(
        entityId: 'd',
        state: 'dead',
        idempotencyKey: 'k4',
      );
      // A different company's in_flight row must not be touched.
      final otherCo = await enqueue(
        companyId: 'other',
        entityId: 'e',
        state: 'in_flight',
        idempotencyKey: 'k5',
      );

      final recovered = await db.outboxDao.resetInFlightForCompany('co');

      Future<String> stateOf(int id) async => (await (db.select(
        db.outbox,
      )..where((o) => o.id.equals(id))).getSingle()).state;

      expect(recovered, 2, reason: 'two orphaned rows recovered');
      expect(await stateOf(orphanA), 'pending');
      expect(await stateOf(orphanB), 'pending');
      expect(await stateOf(stillPending), 'pending');
      expect(await stateOf(dead), 'dead', reason: 'dead rows stay dead');
      expect(
        await stateOf(otherCo),
        'in_flight',
        reason: 'other companies are not touched',
      );
    });
  });

  group('retryDead', () {
    test(
      're-arms a dead row to pending with attempts reset and nextAttemptAt '
      'set, preserving payload / idempotency_key / field_errors_json',
      () async {
        final id = await enqueue(idempotencyKey: 'stable-key');
        await db.outboxDao.markDead(
          id: id,
          error: 'boom',
          statusCode: 422,
          fieldErrorsJson: '{"name":["bad"]}',
        );
        // Bump attempts so we can see them reset.
        await (db.update(db.outbox)..where((o) => o.id.equals(id))).write(
          const OutboxCompanion(attempts: Value(4)),
        );
        await db.outboxDao.retryDead(id: id, now: 12345);
        final row = (await (db.select(
          db.outbox,
        )..where((o) => o.id.equals(id))).get()).single;
        expect(row.state, 'pending');
        expect(row.attempts, 0);
        expect(row.nextAttemptAt, 12345);
        expect(row.idempotencyKey, 'stable-key');
        expect(row.payload, contains('c1'));
        // The prior errors stick around so the form can keep showing them
        // until the retry resolves them or the user discards explicitly.
        expect(row.fieldErrorsJson, '{"name":["bad"]}');
      },
    );

    test('touches only a failed or waiting row — never one that turned '
        'unconfirmed or went in flight while its menu was open', () async {
      // Re-arming an unconfirmed row here skipped the Resend confirmation for
      // a change that may already have gone through.
      final unconfirmed = await enqueue(idempotencyKey: 'u');
      await db.outboxDao.markUnconfirmed(id: unconfirmed, error: 'reset');
      final inFlight = await enqueue(entityId: 'c2', idempotencyKey: 'f');
      await db.outboxDao.markInFlight(inFlight);
      final dead = await enqueue(entityId: 'c3', idempotencyKey: 'd');
      await db.outboxDao.markDead(id: dead, error: 'boom', statusCode: 500);

      expect(await db.outboxDao.retryDead(id: unconfirmed, now: 1), isFalse);
      expect(await db.outboxDao.retryDead(id: inFlight, now: 1), isFalse);
      expect(await db.outboxDao.retryDead(id: dead, now: 1), isTrue);
      expect((await db.outboxDao.byId(unconfirmed))!.state, 'unconfirmed');
      expect((await db.outboxDao.byId(inFlight))!.state, 'in_flight');
    });
  });

  group('unconfirmed rows (may have reached the server)', () {
    // A non-idempotent change whose attempt may have landed: the drain never
    // re-sends it, so every query has to say which side of the line it is on
    // — "Sync first" can't send it, the user's review has to count it, and
    // later edits of the same record must wait behind it.
    Future<int> unconfirmed({
      String entityId = 'c1',
      String kind = 'email_entity',
      String key = 'ku',
    }) => enqueue(
      entityId: entityId,
      kind: kind,
      state: 'unconfirmed',
      idempotencyKey: key,
    );

    test(
      'is never sent by a drain, and "Sync first" does not wait on it',
      () async {
        await unconfirmed();
        expect(await db.outboxDao.nextReady(companyId: 'co', now: 1), isEmpty);
        expect(await db.outboxDao.pendingCountForCompany('co'), 0);
        expect(await db.outboxDao.companiesWithActiveRows(), isEmpty);
        expect(await db.outboxDao.companiesWithUnsyncedRows(), ['co']);
        expect(await db.outboxDao.attentionCountAll(), 1);
        expect(
          await db.outboxDao.watchAttentionCount(companyId: 'co').first,
          1,
        );
      },
    );

    test('holds back later changes to the same record, however long it '
        'waits, and only those', () async {
      final ahead = await unconfirmed();
      final behind = await enqueue(idempotencyKey: 'k2');
      final other = await enqueue(entityId: 'c2', idempotencyKey: 'k3');
      Future<bool> blocked(int id, String entityId) =>
          db.outboxDao.hasEarlierActiveRowForEntity(
            companyId: 'co',
            entityType: 'client',
            entityId: entityId,
            beforeId: id,
            // Far past any parked horizon: an unconfirmed row has none.
            now: 1 << 40,
          );
      expect(await blocked(behind, 'c1'), isTrue);
      expect(await blocked(other, 'c2'), isFalse);
      expect(
        (await db.outboxDao.unconfirmedRowAhead(
          companyId: 'co',
          entityType: 'client',
          entityId: 'c1',
          beforeId: behind,
        ))?.id,
        ahead,
      );
      expect(
        await db.outboxDao.unconfirmedRowAhead(
          companyId: 'co',
          entityType: 'client',
          entityId: 'c1',
          beforeId: ahead,
        ),
        isNull,
      );
    });

    test(
      'a document upload holds nothing back, and no refresh waits on it',
      () async {
        // Uploads are the likeliest rows to time out once the body is out, and
        // an unconfirmed one held back every later save of its record until
        // the user dealt with it — for the company, every settings screen,
        // silently — while `/refresh` withheld the company's columns. An upload
        // writes no field of the record, so it can cause none of the lost
        // updates the hold exists to prevent.
        final upload = await unconfirmed(kind: 'document_upload');
        final save = await enqueue(idempotencyKey: 'k-save');
        expect(
          await db.outboxDao.hasEarlierActiveRowForEntity(
            companyId: 'co',
            entityType: 'client',
            entityId: 'c1',
            beforeId: save,
            now: 1 << 40,
          ),
          isFalse,
        );
        expect(
          await db.outboxDao.unconfirmedRowAhead(
            companyId: 'co',
            entityType: 'client',
            entityId: 'c1',
            beforeId: save,
          ),
          isNull,
        );
        expect(
          await db.outboxDao.findUnconfirmedForEntity(
            companyId: 'co',
            entityType: 'client',
            entityId: 'c1',
          ),
          isNull,
          reason: 'the edit form has nothing to wait on',
        );
        expect((await db.outboxDao.byId(upload))!.state, 'unconfirmed');

        // The company's upload is an `update` carrying the action.
        final companyUpload = await db.outboxDao.enqueue(
          OutboxCompanion.insert(
            companyId: 'co',
            entityType: 'company',
            entityId: 'co',
            mutationKind: 'update',
            payload: jsonEncode({
              '_action': 'upload_document',
              'file_name': 'contract.pdf',
            }),
            idempotencyKey: 'k-company-upload',
            nextAttemptAt: 0,
            createdAt: 0,
            state: const Value('unconfirmed'),
          ),
        );
        final settingsSave = await enqueue(
          entityType: 'company',
          entityId: 'co',
          idempotencyKey: 'k-settings',
        );
        expect(
          await db.outboxDao.hasEarlierActiveRowForEntity(
            companyId: 'co',
            entityType: 'company',
            entityId: 'co',
            beforeId: settingsSave,
            now: 1 << 40,
          ),
          isFalse,
        );
        await db.outboxDao.deleteRow(settingsSave);
        expect(
          await db.outboxDao.hasActiveRowsFor(
            companyId: 'co',
            entityType: 'company',
          ),
          isFalse,
          reason: 'no company column is waiting to be sent',
        );
        expect((await db.outboxDao.byId(companyUpload))!.state, 'unconfirmed');
      },
    );

    test('a document upload is no edit of its record', () async {
      // An upload writes no field of its record and sets no dirty flag, so it
      // is neither a newer edit a server copy must yield to nor a reason to
      // keep a discarded edit's flag. Counting the company's own upload kept
      // Check's refresh of the company from ever landing: the Documents tab
      // stayed stale, and the user was steered into uploading it again.
      await db.outboxDao.enqueue(
        OutboxCompanion.insert(
          companyId: 'co',
          entityType: 'company',
          entityId: 'co',
          mutationKind: 'update',
          payload: jsonEncode({
            '_action': 'upload_document',
            'file_name': 'contract.pdf',
          }),
          idempotencyKey: 'k-company-upload',
          nextAttemptAt: 0,
          createdAt: 0,
          state: const Value('unconfirmed'),
        ),
      );
      await unconfirmed(kind: 'document_upload', key: 'k-client-upload');

      expect(
        await db.outboxDao.hasEditRowForEntity(
          companyId: 'co',
          entityType: 'company',
          entityId: 'co',
        ),
        isFalse,
      );
      expect(
        await db.outboxDao.hasActiveRowsForEntity(
          companyId: 'co',
          entityType: 'client',
          entityId: 'c1',
        ),
        isFalse,
      );

      // A real edit of either still counts.
      await enqueue(
        entityType: 'company',
        entityId: 'co',
        idempotencyKey: 'k-settings',
      );
      await enqueue(idempotencyKey: 'k-client-edit');
      expect(
        await db.outboxDao.hasEditRowForEntity(
          companyId: 'co',
          entityType: 'company',
          entityId: 'co',
        ),
        isTrue,
      );
      expect(
        await db.outboxDao.hasActiveRowsForEntity(
          companyId: 'co',
          entityType: 'client',
          entityId: 'c1',
        ),
        isTrue,
      );
    });

    test('markUnconfirmed parks a row; resendUnconfirmed puts only an '
        'unconfirmed one back in line, same key, fresh budget', () async {
      final id = await enqueue(idempotencyKey: 'same-key');
      await db.outboxDao.scheduleRetry(
        id: id,
        attempts: 3,
        nextAttemptAt: 99,
        error: 'x',
      );
      await db.outboxDao.markUnconfirmed(
        id: id,
        error: 'Connection closed',
        statusCode: 502,
      );
      var row = (await db.outboxDao.byId(id))!;
      expect(row.state, 'unconfirmed');
      expect(row.lastStatusCode, 502);

      expect(await db.outboxDao.resendUnconfirmed(id: id, now: 500), isTrue);
      row = (await db.outboxDao.byId(id))!;
      expect(row.state, 'pending');
      expect(row.attempts, 0);
      expect(row.nextAttemptAt, 500);
      expect(row.idempotencyKey, 'same-key');

      expect(
        await db.outboxDao.resendUnconfirmed(id: id, now: 600),
        isFalse,
        reason: 'a pending row is not moved again',
      );
    });

    test('the edit form finds it, and its Discard may abandon it', () async {
      final id = await unconfirmed(kind: 'update');
      expect(
        (await db.outboxDao.findUnconfirmedForEntity(
          companyId: 'co',
          entityType: 'client',
          entityId: 'c1',
        ))?.id,
        id,
      );
      expect(
        (await db.outboxDao.findDiscardableForEntity(
          companyId: 'co',
          entityType: 'client',
          entityId: 'c1',
        ))?.id,
        id,
      );
    });

    test('counts as a local edit still in charge of the record', () async {
      await unconfirmed(kind: 'update');
      expect(
        await db.outboxDao.hasActiveRowsForEntity(
          companyId: 'co',
          entityType: 'client',
          entityId: 'c1',
        ),
        isTrue,
      );
      expect(
        await db.outboxDao.hasActiveRowsFor(
          companyId: 'co',
          entityType: 'client',
        ),
        isTrue,
      );
    });

    test('a landed create heals its temp id without re-arming it', () async {
      final id = await unconfirmed(entityId: 'tmp_x', kind: 'update');
      await db.outboxDao.rewriteTempIdInPayloads(
        companyId: 'co',
        entityType: 'client',
        tempId: 'tmp_x',
        realId: 'real_x',
      );
      final row = (await db.outboxDao.byId(id))!;
      expect(row.entityId, 'real_x');
      expect(row.payload, contains('real_x'));
      expect(row.state, 'unconfirmed', reason: 'it still waits for the user');
    });

    test('shows up in the stale-row snapshot', () async {
      await unconfirmed();
      expect(
        await db.outboxDao.staleRowsForCompany(companyId: 'co', now: 0),
        hasLength(1),
      );
    });
  });
}
