import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/sync_repository.dart';
import 'package:admin/data/repositories/unconfirmed_prior_mutation_exception.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/ui/core/edit/entity_edit_screen_scaffold.dart';
import 'package:admin/ui/core/edit/generic_edit_view_model.dart';
import 'package:admin/ui/core/unsaved_changes/unsaved_changes_guard.dart';

import '../../../_localization_helper.dart';

/// A new record's draft has no id — its temp id lives on the view model
/// (`recoveryTempId`) — and every lookup of its failed outbox row was keyed on
/// the draft's id or on `existingId`, both empty. So after a server error
/// "Discard failed save" dropped nothing and the create still went out, and
/// a rejection's dead row was never linked.
class _FakeAuth implements AuthRepository {
  @override
  final ValueListenable<AuthSession?> session = ValueNotifier<AuthSession?>(
    const AuthSession(
      baseUrl: 'https://example.test',
      isHosted: false,
      accountId: 'acct',
      companies: [],
      currentCompanyId: 'co',
    ),
  );

  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _FakeSync implements SyncRepository {
  final List<int> discarded = [];
  final List<int> superseded = [];

  /// A create never synced, so discarding it removes the local record too.
  @override
  Future<bool> discardOutboxRow(int id) async {
    discarded.add(id);
    return true;
  }

  @override
  Future<bool> supersedeDeadSave(int id) async {
    superseded.add(id);
    return true;
  }

  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _FakeServices implements Services {
  _FakeServices({required this.db, required this.sync});

  @override
  final AppDatabase db;
  @override
  final SyncRepository sync;
  @override
  final AuthRepository auth = _FakeAuth();
  @override
  final UnsavedChangesGuard unsavedChangesGuard = UnsavedChangesGuard();

  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

const _tmpId = 'tmp_00000000-0000-4000-8000-0000000000bb';

/// Queue a row for the record under test, as the repositories do.
Future<int> _enqueue(
  AppDatabase db, {
  required String kind,
  required String state,
  String key = 'idem-create',
  String entityId = _tmpId,
}) => db.outboxDao.enqueue(
  OutboxCompanion.insert(
    companyId: 'co',
    entityType: 'client',
    entityId: entityId,
    mutationKind: kind,
    payload: '{}',
    idempotencyKey: key,
    createdAt: 0,
    nextAttemptAt: 0,
    state: Value(state),
    lastError: Value(state == 'dead' ? 'The name field is required.' : 'Down'),
    lastStatusCode: Value(state == 'dead' ? 422 : 503),
    fieldErrorsJson: Value(
      state == 'dead' ? '{"name":["The name field is required."]}' : null,
    ),
  ),
);

/// A new record: queues its create in [rowState], remembers the temp id, then
/// fails with [failure].
class _CreateVm extends GenericEditViewModel<String> {
  _CreateVm({required this.db, required this.rowState, required this.failure})
    : super(initialDraft: '');

  final AppDatabase db;
  final String rowState;
  final Object Function(int rowId) failure;
  int? rowId;

  @override
  Future<SaveResult<String>> performSave() async {
    rowId = await _enqueue(db, kind: 'create', state: rowState);
    rememberCreateTempId(_tmpId);
    throw failure(rowId!);
  }
}

/// An existing record: its save queues an update, as the repositories do.
class _EditVm extends GenericEditViewModel<String> {
  _EditVm({required this.db, required this.entityId})
    : super(initialDraft: 'x', original: 'x');

  final AppDatabase db;
  final String entityId;

  @override
  Future<SaveResult<String>> performSave() async {
    final rowId = await _enqueue(
      db,
      kind: 'update',
      state: 'pending',
      key: 'idem-update',
      entityId: entityId,
    );
    return SaveResult(entity: draft, outboxRowId: rowId);
  }
}

void main() {
  late AppDatabase db;
  late _FakeSync sync;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    sync = _FakeSync();
  });
  tearDown(() async => db.close());

  /// Mount the scaffold at `/clients/new` ([existingId] null) or
  /// `/clients/<existingId>/edit`, over a list route it can pop back to.
  Future<void> pump(
    WidgetTester tester,
    GenericEditViewModel<String> vm, {
    String? existingId,
  }) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    Widget scaffold(String? id) =>
        EntityEditScreenScaffold<String, GenericEditViewModel<String>>(
          existingId: id,
          entityTypeName: 'client',
          fetchExisting: (_, _, _, _) async => 'x',
          buildVm: (_, _, _, _) => vm,
          titleBuilder: (_, _) => 'Client',
          titleWhileLoading: (_) => 'Client',
          bodyBuilder: (_, _) => const SizedBox.shrink(),
          resetToEmpty: (_) {},
          onSaved: (_, _, _) {},
          entityIdOf: (draft) => '',
        );
    await tester.pumpWidget(
      Provider<Services>.value(
        value: _FakeServices(db: db, sync: sync),
        child: MaterialApp.router(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          routerConfig: GoRouter(
            initialLocation: existingId == null
                ? '/clients/new'
                : '/clients/$existingId/edit',
            routes: [
              GoRoute(
                path: '/clients',
                builder: (_, _) => const Text('clients list'),
                routes: [
                  GoRoute(path: 'new', builder: (_, _) => scaffold(null)),
                  GoRoute(
                    path: ':id/edit',
                    builder: (_, state) => scaffold(state.pathParameters['id']),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  group('a create form', () {
    testWidgets('Discard after a server error drops the queued create — it '
        'would otherwise still go out', (tester) async {
      final vm = _CreateVm(
        db: db,
        rowState: 'pending',
        failure: (_) => const ServerException(503, 'Down'),
      );
      await pump(tester, vm);
      await tap(tester, 'Save');
      await tap(tester, 'Discard failed save');

      expect(sync.discarded, [vm.rowId]);
      expect(
        find.text('clients list'),
        findsNothing,
        reason: 'the form keeps the draft — it points at no record to lose',
      );
    });

    testWidgets('a rejection links its dead row, so Discard drops it', (
      tester,
    ) async {
      final vm = _CreateVm(
        db: db,
        rowState: 'dead',
        failure: (_) =>
            const ValidationException('The given data was invalid.', {
              'name': ['The name field is required.'],
            }),
      );
      await pump(tester, vm);
      await tap(tester, 'Save');
      expect(vm.deadOutboxRowId, vm.rowId);

      await tap(tester, 'Discard failed save');
      expect(sync.discarded, [vm.rowId]);
      expect(find.text('clients list'), findsNothing);
    });

    testWidgets('discarding a create that may already have gone through '
        'leaves the form, as before', (tester) async {
      // Its draft, saved again, could make the record twice.
      final vm = _CreateVm(
        db: db,
        rowState: 'unconfirmed',
        failure: UnconfirmedPriorMutationException.new,
      );
      await pump(tester, vm);
      await tap(tester, 'Save');
      await tap(tester, 'Discard');

      expect(sync.discarded, [vm.rowId]);
      expect(find.text('clients list'), findsOneWidget);
    });

    testWidgets('a create that went unconfirmed behind the form is shown, not '
        'dropped unseen', (tester) async {
      final vm = _CreateVm(
        db: db,
        rowState: 'pending',
        failure: (_) => const ServerException(503, 'Down'),
      );
      await pump(tester, vm);
      await tap(tester, 'Save');
      // A background retry's outcome is unknown.
      await db.outboxDao.markUnconfirmed(id: vm.rowId!, error: 'Reset');
      await tap(tester, 'Discard failed save');

      expect(sync.discarded, isEmpty);
      expect(vm.unconfirmedRowId, vm.rowId);
      expect(vm.recoveryTempId, _tmpId, reason: 'so a Save is refused');
      expect(find.text('A change may already have gone through'), findsOne);
    });
  });

  testWidgets('saving an edit of a record whose create was rejected keeps that '
      'create — the edit waits behind it', (tester) async {
    // Deleting it as "superseded" stranded the record: the update then died
    // as referencing a discarded record.
    final deadCreate = await _enqueue(db, kind: 'create', state: 'dead');
    final vm = _EditVm(db: db, entityId: _tmpId);
    await pump(tester, vm, existingId: _tmpId);
    expect(vm.deadOutboxRowId, deadCreate, reason: 'linked on open');

    await tap(tester, 'Save');

    expect(sync.superseded, isEmpty);
  });

  testWidgets('saving an edit still supersedes a dead create under the real '
      'id — the record exists, so that row is stale', (tester) async {
    // Left behind by a newer attempt re-keyed when an older one landed; a
    // Retry of it would create the record a second time.
    final deadCreate = await _enqueue(
      db,
      kind: 'create',
      state: 'dead',
      entityId: 'c_real',
    );
    final vm = _EditVm(db: db, entityId: 'c_real');
    await pump(tester, vm, existingId: 'c_real');
    expect(vm.deadOutboxRowId, deadCreate, reason: 'linked on open');

    await tap(tester, 'Save');

    expect(sync.superseded, [deadCreate]);
  });
}
