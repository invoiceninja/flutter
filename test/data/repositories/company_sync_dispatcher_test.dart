import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/company_api_model.dart';
import 'package:admin/data/repositories/company_repository.dart';
import 'package:admin/data/repositories/company_sync_dispatcher.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/companies_api.dart';
import 'package:admin/data/services/documents_api.dart';
import 'package:admin/domain/sync/mutation.dart';

/// First coverage for `CompanySyncDispatcher` — one of only three dispatchers
/// that bypass `BaseEntitySyncDispatcher`, and the one every settings-screen
/// write drains through. `UserSyncDispatcher` had a test; this did not.
///
/// The highest-risk behaviour here is the two **control keys** the edit screens
/// stash inside the payload — `_sync_send_time` (Email Settings) and
/// `_design_updates` (Invoice Design "update all records"). Both must be popped
/// off before the body is serialized: leaking either into `PUT /companies/{id}`
/// sends the server a field it doesn't know, and the failure mode is a silently
/// wrong settings save rather than an error.
class _RecordedUpdate {
  _RecordedUpdate(this.id, this.payload, this.idempotencyKey, this.query);
  final String id;
  final Map<String, dynamic> payload;
  final String idempotencyKey;
  final Map<String, String>? query;
}

class _RecordedSetDefault {
  _RecordedSetDefault(this.designId, this.entity, this.level, this.key);
  final String designId;
  final String entity;
  final String level;
  final String key;
}

class _RecordingCompaniesApi implements CompaniesApi {
  final List<_RecordedUpdate> updates = [];
  final List<Map<String, dynamic>> deleteBodies = [];
  final List<_RecordedSetDefault> setDefaults = [];
  int regenerateCalls = 0;

  /// When set, `setDefaultDesign` throws for this entity — exercises the
  /// best-effort swallow that must not fail the already-applied settings PUT.
  String? failSetDefaultForEntity;

  /// The canonical company the server echoes back. Deliberately carries a
  /// distinctive `settings` entry: `CompanyApi.settings` defaults to `{}` and
  /// the fixture seeds the row with `'{}'`, so a blank response would make
  /// `applyUpdateResponse` write a byte-identical value and any "did it
  /// apply?" assertion would be vacuous.
  static const canonical = CompanyItemApi(
    data: CompanyApi(id: 'co', settings: {'currency_id': '3'}),
  );

  @override
  Future<CompanyItemApi> update({
    required String id,
    required Map<String, dynamic> payload,
    required String idempotencyKey,
    bool requiresPassword = false,
    Map<String, String>? query,
  }) async {
    updates.add(_RecordedUpdate(id, payload, idempotencyKey, query));
    return canonical;
  }

  @override
  Future<void> deleteWithBody({
    required String id,
    required Map<String, dynamic> body,
    required String idempotencyKey,
  }) async {
    deleteBodies.add(body);
  }

  @override
  Future<void> setDefaultDesign({
    required String designId,
    required String entity,
    required String settingsLevel,
    required String idempotencyKey,
    String? clientId,
    String? groupSettingsId,
  }) async {
    setDefaults.add(
      _RecordedSetDefault(designId, entity, settingsLevel, idempotencyKey),
    );
    if (entity == failSetDefaultForEntity) {
      throw const ServerException(400, 'unknown design');
    }
  }

  @override
  Future<CompanyItemApi> regenerateEInvoiceToken({
    required String idempotencyKey,
  }) async {
    regenerateCalls++;
    return const CompanyItemApi(data: CompanyApi(id: 'co'));
  }

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _RecordingDocumentsApi implements DocumentsApi {
  final List<({String id, bool requiresPassword})> deletes = [];

  /// Runs *inside* `delete`, i.e. before the dispatcher's local prune. Lets a
  /// test observe the DB mid-flight and prove the prune happens only after the
  /// server confirms — an ordering that a final-state assertion can't see.
  Future<void> Function()? onDelete;

  @override
  Future<void> delete({
    required String id,
    required String idempotencyKey,
    required bool requiresPassword,
  }) async {
    deletes.add((id: id, requiresPassword: requiresPassword));
    await onDelete?.call();
  }

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late AppDatabase db;
  late _RecordingCompaniesApi api;
  late _RecordingDocumentsApi documentsApi;
  late CompanySyncDispatcher dispatcher;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    api = _RecordingCompaniesApi();
    documentsApi = _RecordingDocumentsApi();
    dispatcher = CompanySyncDispatcher(
      api: api,
      repo: CompanyRepository(db: db, api: api),
      documentsApi: documentsApi,
    );
    await db.companiesDao.upsertAll([
      CompaniesCompanion.insert(
        id: 'co',
        name: 'Acme',
        settings: '{}',
        permissions: '',
        accountId: 'acct',
        token: 'tok',
        updatedAt: 1700000000,
      ),
    ]);
  });
  tearDown(() async => db.close());

  OutboxRow rowFor(
    MutationKind kind, {
    Map<String, dynamic>? payload,
    String rawPayload = '',
  }) => OutboxRow(
    id: 1,
    companyId: 'co',
    entityType: 'company',
    entityId: 'co',
    mutationKind: kind.wireName,
    payload: payload != null ? jsonEncode(payload) : rawPayload,
    idempotencyKey: 'idk',
    state: 'pending',
    attempts: 0,
    nextAttemptAt: 0,
    createdAt: 0,
    requiresPassword: false,
  );

  Future<void> dispatch(MutationKind kind, {Map<String, dynamic>? payload}) =>
      dispatcher.dispatch(
        row: rowFor(kind, payload: payload),
        kind: kind,
      );

  group('settings update', () {
    test('PUTs the payload and applies the response', () async {
      await dispatch(MutationKind.update, payload: {'name': 'Renamed'});

      expect(api.updates, hasLength(1));
      expect(api.updates.single.id, 'co');
      expect(api.updates.single.payload, {'name': 'Renamed'});
      expect(api.updates.single.idempotencyKey, 'idk');
      expect(api.updates.single.query, isNull);

      final row = await db.companiesDao.byId('co');
      expect(
        jsonDecode(row!.settings),
        {'currency_id': '3'},
        reason:
            'the canonical server response must land in Drift — without the '
            'applyUpdateResponse tail the local row keeps the stale settings',
      );
    });
  });

  group('control keys are stripped from the PUT body', () {
    test('_sync_send_time becomes a query param, never a body field', () async {
      await dispatch(
        MutationKind.update,
        payload: {'name': 'Acme', '_sync_send_time': true},
      );

      expect(api.updates.single.payload, {'name': 'Acme'});
      expect(
        api.updates.single.payload.containsKey('_sync_send_time'),
        isFalse,
        reason: 'the control key must not reach the server',
      );
      expect(api.updates.single.query, {'sync_send_time': 'true'});
    });

    test(
      'a non-bool _sync_send_time is dropped without a query param',
      () async {
        await dispatch(
          MutationKind.update,
          payload: {'name': 'Acme', '_sync_send_time': 'yes'},
        );

        expect(api.updates.single.payload, {'name': 'Acme'});
        expect(api.updates.single.query, isNull);
      },
    );

    test(
      '_design_updates is stripped and fires one set/default per entry',
      () async {
        await dispatch(
          MutationKind.update,
          payload: {
            'name': 'Acme',
            '_design_updates': [
              {'design_id': 'd1', 'entity': 'invoice'},
              {'design_id': 'd2', 'entity': 'quote'},
            ],
          },
        );

        expect(api.updates.single.payload, {'name': 'Acme'});
        expect(api.setDefaults, hasLength(2));
        expect(api.setDefaults[0].designId, 'd1');
        expect(api.setDefaults[0].entity, 'invoice');
        expect(api.setDefaults[0].level, 'company');
        expect(
          api.setDefaults[0].key,
          'idk:set_default:invoice',
          reason:
              'per-entity keys derived from the row key keep a retry idempotent',
        );
        expect(api.setDefaults[1].entity, 'quote');
      },
    );

    test(
      'malformed _design_updates entries are skipped, not thrown on',
      () async {
        await dispatch(
          MutationKind.update,
          payload: {
            '_design_updates': [
              'not-a-map',
              {'design_id': 'd1'}, // missing entity
              {'entity': 'quote'}, // missing design_id
              {'design_id': 'd2', 'entity': 'credit'},
            ],
          },
        );

        expect(api.setDefaults, hasLength(1));
        expect(api.setDefaults.single.entity, 'credit');
      },
    );

    test('a failing set/default does not fail the row — the settings PUT '
        'already landed', () async {
      api.failSetDefaultForEntity = 'invoice';

      await dispatch(
        MutationKind.update,
        payload: {
          '_design_updates': [
            {'design_id': 'd1', 'entity': 'invoice'},
            {'design_id': 'd2', 'entity': 'quote'},
          ],
        },
      );

      expect(api.updates, hasLength(1));
      expect(
        api.setDefaults.map((s) => s.entity),
        ['invoice', 'quote'],
        reason: 'one entity failing must not abort the remaining entries',
      );
    });
  });

  group('_action branches', () {
    test(
      'remove_e_invoice_certificate PUTs only the explicit null key',
      () async {
        await dispatch(
          MutationKind.update,
          payload: {
            '_action': 'remove_e_invoice_certificate',
            'name': 'ignored',
          },
        );

        expect(
          api.updates.single.payload,
          {'e_invoice_certificate': null},
          reason:
              'the server only clears the cert when the key is present, and a '
              'full company body would clobber unrelated columns',
        );
      },
    );
  });

  group('delete + documents', () {
    test('delete routes to deleteWithBody', () async {
      await dispatch(MutationKind.delete, payload: {'password': 'p'});

      expect(api.deleteBodies, [
        {'password': 'p'},
      ]);
      expect(api.updates, isEmpty);
    });

    test('documentDelete hits the doc-scoped endpoint password-gated and '
        'prunes the local documents column only after it returns', () async {
      await (db.update(db.companies)..where((c) => c.id.equals('co'))).write(
        const CompaniesCompanion(documents: Value('[{"id":"d1"},{"id":"d2"}]')),
      );
      // Captured while the server call is still in flight.
      Object? documentsDuringCall;
      documentsApi.onDelete = () async {
        documentsDuringCall = jsonDecode(
          (await db.companiesDao.byId('co'))!.documents!,
        );
      };

      await dispatch(
        MutationKind.documentDelete,
        payload: {'document_id': 'd1'},
      );

      expect(
        documentsDuringCall,
        [
          {'id': 'd1'},
          {'id': 'd2'},
        ],
        reason:
            'pruning optimistically would let the page mount-refresh re-add a '
            'not-yet-drained delete — the column must stay intact until the '
            'server confirms',
      );

      expect(documentsApi.deletes, [(id: 'd1', requiresPassword: true)]);
      final row = await db.companiesDao.byId('co');
      expect(jsonDecode(row!.documents!), [
        {'id': 'd2'},
      ]);
    });
  });

  group('e-invoice branch table', () {
    test(
      'regenerateEInvoiceToken is handled and short-circuits update',
      () async {
        await dispatch(MutationKind.regenerateEInvoiceToken);

        expect(api.regenerateCalls, 1);
        expect(api.updates, isEmpty);
      },
    );
  });

  group('defensive paths', () {
    test('a corrupt payload raises ValidationException instead of burning '
        'five retries on a raw decode error', () async {
      await expectLater(
        dispatcher.dispatch(
          row: rowFor(MutationKind.update, rawPayload: 'not json'),
          kind: MutationKind.update,
        ),
        throwsA(isA<ValidationException>()),
      );
      expect(api.updates, isEmpty);
    });

    test('an unexpected mutation kind is skipped, not dispatched', () async {
      await dispatch(MutationKind.archive, payload: {'name': 'Acme'});

      expect(api.updates, isEmpty);
      expect(api.deleteBodies, isEmpty);
    });
  });

  group('discard hooks are inert (company has no offline create)', () {
    test('deleteLocalRecord and clearLocalDirty are no-ops', () async {
      await dispatcher.deleteLocalRecord(companyId: 'co', id: 'co');
      await dispatcher.clearLocalDirty(companyId: 'co', id: 'co');

      expect(await db.companiesDao.byId('co'), isNotNull);
    });
  });
}
