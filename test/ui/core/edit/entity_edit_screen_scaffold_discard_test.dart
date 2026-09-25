import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/confirm_actions_controller.dart';
import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/prefs/device_pref_keys.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/sync_repository.dart';
import 'package:admin/data/repositories/unconfirmed_prior_mutation_exception.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/domain/entity_registry.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/sync/mutation.dart';
import 'package:admin/domain/sync/sync_dispatcher.dart';
import 'package:admin/ui/core/edit/entity_edit_screen_scaffold.dart';
import 'package:admin/ui/core/edit/generic_edit_view_model.dart';
import 'package:admin/ui/core/list/master_detail_layout.dart';
import 'package:admin/ui/core/unsaved_changes/unsaved_changes_guard.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';

import '../../../_localization_helper.dart';
import '../../../_support/device_prefs_test_support.dart';

/// A new record's draft has no id — its temp id lives on the view model
/// (`recoveryTempId`) — and every lookup of its failed outbox row was keyed on
/// the draft's id or on `existingId`, both empty. So after a server error
/// "Discard failed save" dropped nothing and the create still went out, and
/// a rejection's dead row was never linked.
///
/// Mounted in the production route shape: `/clients/new` is a SIBLING of the
/// list inside the entity shell, so there is nothing to pop, and the editors
/// carry the router's `onExit` unsaved-changes guard.
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
  _FakeSync({this.removesRecord = false});

  /// What a discard reports: true when the ghost path took the local record
  /// with a never-synced create.
  final bool removesRecord;
  final List<int> discarded = [];
  final List<int> superseded = [];

  @override
  Future<bool> discardFailedSave(int id) async {
    discarded.add(id);
    return removesRecord;
  }

  @override
  Future<bool> discardDeletesUnsyncedRecord(OutboxRow row) async =>
      removesRecord && row.state != 'unconfirmed';

  @override
  Future<bool> supersedeDeadSave(int id) async {
    superseded.add(id);
    return true;
  }

  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _NoopDispatcher implements SyncDispatcher {
  final List<String> clearedDirty = [];

  @override
  Future<void> dispatch({
    required OutboxRow row,
    required MutationKind kind,
  }) async {}

  @override
  Future<void> deleteLocalRecord({
    required String companyId,
    required String id,
  }) async {}

  @override
  Future<void> clearLocalDirty({
    required String companyId,
    required String id,
  }) async => clearedDirty.add(id);
}

EntityRegistry _registry(SyncDispatcher dispatcher) => EntityRegistry({
  EntityType.client: EntityHandlers(
    type: EntityType.client,
    wireName: 'client',
    apiPath: '/api/v1/clients',
    routePath: '/clients',
    icon: Icons.people,
    dispatcher: dispatcher,
  ),
});

class _FakeServices implements Services {
  _FakeServices({
    required this.db,
    required this.sync,
    SyncDispatcher? disp,
    bool confirm = false,
  }) : entityRegistry = _registry(disp ?? _NoopDispatcher()),
       confirmActions = ConfirmActionsController(
         prefs: prefsWith({DevicePrefKeys.confirmActions: confirm}),
       );

  @override
  final ConfirmActionsController confirmActions;

  @override
  final AppDatabase db;
  @override
  final SyncRepository sync;
  @override
  final AuthRepository auth = _FakeAuth();
  @override
  final UnsavedChangesGuard unsavedChangesGuard = UnsavedChangesGuard();
  @override
  final EntityRegistry entityRegistry;

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

/// An existing record: its save queues an update, as the repositories do —
/// then fails with [failure] when there is one.
class _EditVm extends GenericEditViewModel<String> {
  _EditVm({required this.db, required this.entityId, this.failure})
    : super(initialDraft: 'x', original: 'x');

  final AppDatabase db;
  final String entityId;
  final Object? failure;
  int? rowId;

  /// As the view models do: a record whose create failed is saved as a
  /// create again ([GenericEditViewModel.savesAsCreate]).
  @override
  Future<SaveResult<String>> performSave() async {
    rowId = await _enqueue(
      db,
      kind: savesAsCreate ? 'create' : 'update',
      state: 'pending',
      key: savesAsCreate ? 'idem-recreate' : 'idem-update',
      entityId: entityId,
    );
    final fail = failure;
    if (fail != null) throw fail;
    return SaveResult(entity: draft, outboxRowId: rowId!);
  }
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  /// Mount the scaffold at `/clients/new` ([existingId] null) or
  /// `/clients/<existingId>/edit`, in the production route shape.
  Future<GoRouter> pump(
    WidgetTester tester,
    GenericEditViewModel<String> vm, {
    required SyncRepository sync,
    SyncDispatcher? disp,
    String? existingId,
    bool confirm = false,
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
    Future<bool> confirmExit(BuildContext context, GoRouterState _) =>
        context.read<Services>().unsavedChangesGuard.confirmIfDirty(context);
    final router = GoRouter(
      initialLocation: existingId == null
          ? '/clients/new'
          : '/clients/$existingId/edit',
      routes: [
        ShellRoute(
          pageBuilder: (context, state, child) => NoTransitionPage<void>(
            key: const ValueKey('master_detail:/clients'),
            child: MasterDetailLayout(
              basePath: '/clients',
              list: const Scaffold(body: Center(child: Text('clients list'))),
              rightPane: child,
              hasPane: state.matchedLocation != '/clients',
              viewMode: state.uri.queryParameters['view'],
            ),
          ),
          routes: [
            GoRoute(
              path: '/clients',
              builder: (_, _) => const SizedBox.shrink(),
            ),
            GoRoute(
              path: '/clients/new',
              builder: (_, _) => scaffold(null),
              onExit: confirmExit,
            ),
            GoRoute(
              path: '/clients/:id',
              builder: (_, _) => const Text('client detail'),
              routes: [
                GoRoute(
                  path: 'edit',
                  builder: (_, state) => scaffold(state.pathParameters['id']),
                  onExit: confirmExit,
                ),
              ],
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      Provider<Services>.value(
        value: _FakeServices(db: db, sync: sync, disp: disp, confirm: confirm),
        child: MaterialApp.router(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  String uriOf(GoRouter router) =>
      router.routerDelegate.currentConfiguration.uri.toString();

  Future<void> tap(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  group('a create form', () {
    testWidgets('Discard after a server error drops the queued create — it '
        'would otherwise still go out — and keeps the draft', (tester) async {
      final sync = _FakeSync(removesRecord: true);
      final vm = _CreateVm(
        db: db,
        rowState: 'pending',
        failure: (_) => const ServerException(503, 'Down'),
      );
      final router = await pump(tester, vm, sync: sync);
      await tap(tester, 'Save');
      await tap(tester, 'Discard failed save');

      expect(sync.discarded, [vm.rowId]);
      expect(
        uriOf(router),
        '/clients/new',
        reason: 'it points at no record to lose',
      );
    });

    testWidgets('a rejection links its dead row, so Discard drops it', (
      tester,
    ) async {
      final sync = _FakeSync(removesRecord: true);
      final vm = _CreateVm(
        db: db,
        rowState: 'dead',
        failure: (_) =>
            const ValidationException('The given data was invalid.', {
              'name': ['The name field is required.'],
            }),
      );
      final router = await pump(tester, vm, sync: sync);
      await tap(tester, 'Save');
      expect(vm.deadOutboxRowId, vm.rowId);

      await tap(tester, 'Discard failed save');
      expect(sync.discarded, [vm.rowId]);
      expect(uriOf(router), '/clients/new');
    });

    testWidgets('discarding a create that may already have gone through '
        'leaves the form for the list', (tester) async {
      // Its draft, saved again, could make the record twice. The pop that
      // was meant to leave never ran here: `/clients/new` is a sibling route.
      final sync = _FakeSync(removesRecord: true);
      final vm = _CreateVm(
        db: db,
        rowState: 'unconfirmed',
        failure: UnconfirmedPriorMutationException.new,
      );
      final router = await pump(tester, vm, sync: sync);
      await tap(tester, 'Save');
      await tap(tester, 'Discard');

      expect(sync.discarded, [vm.rowId]);
      expect(uriOf(router), '/clients');
      expect(find.text('Discard changes?'), findsNothing);
    });

    testWidgets('a create that went unconfirmed behind the form is shown, not '
        'dropped unseen', (tester) async {
      final sync = _FakeSync(removesRecord: true);
      final vm = _CreateVm(
        db: db,
        rowState: 'pending',
        failure: (_) => const ServerException(503, 'Down'),
      );
      await pump(tester, vm, sync: sync);
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

  testWidgets('discarding the failed create of a record the server has never '
      'seen leaves its edit form for the list, without asking to discard '
      'changes', (tester) async {
    // The pop landed on the deleted record's detail, behind a "Discard
    // changes?" prompt for a draft of a record that no longer exists.
    final sync = _FakeSync(removesRecord: true);
    final deadCreate = await _enqueue(db, kind: 'create', state: 'dead');
    final vm = _EditVm(db: db, entityId: _tmpId);
    final router = await pump(tester, vm, sync: sync, existingId: _tmpId);
    vm.updateDraftForTest('edited');
    await tester.pumpAndSettle();

    await tap(tester, 'Discard failed save');

    expect(sync.discarded, [deadCreate]);
    expect(find.text('Discard changes?'), findsNothing);
    expect(uriOf(router), '/clients');
  });

  testWidgets('with Confirm actions on, it asks first — the discard takes the '
      'record, and whatever was queued that needs it', (tester) async {
    // It used to go on one tap. The Outbox's Discard of the same row asks.
    final sync = _FakeSync(removesRecord: true);
    final deadCreate = await _enqueue(db, kind: 'create', state: 'dead');
    final vm = _EditVm(db: db, entityId: _tmpId);
    final router = await pump(
      tester,
      vm,
      sync: sync,
      existingId: _tmpId,
      confirm: true,
    );

    await tap(tester, 'Discard failed save');
    expect(find.textContaining('never saved to the server'), findsOneWidget);
    await tap(tester, 'Cancel');
    expect(sync.discarded, isEmpty);
    expect(uriOf(router), '/clients/$_tmpId/edit');

    await tap(tester, 'Discard failed save');
    await tester.tap(
      find.descendant(
        of: find.byType(PrimaryDialogAction),
        matching: find.text('Discard'),
      ),
    );
    await tester.pumpAndSettle();
    expect(sync.discarded, [deadCreate]);
    expect(uriOf(router), '/clients');
  });

  testWidgets('…but not on a form discarding an edit — that drops only the '
      'edit', (tester) async {
    final sync = _FakeSync();
    final deadEdit = await _enqueue(
      db,
      kind: 'update',
      state: 'dead',
      entityId: 'c1',
      key: 'idem-dead',
    );
    final vm = _EditVm(db: db, entityId: 'c1');
    await pump(tester, vm, sync: sync, existingId: 'c1', confirm: true);

    await tap(tester, 'Discard failed save');

    expect(find.byType(AlertDialog), findsNothing);
    expect(sync.discarded, [deadEdit]);
  });

  testWidgets('Discard after a failed re-save releases the record — the failed '
      'save the form opened on goes too', (tester) async {
    // The form opened on dead D; the re-save queued P, which hit a 5xx.
    // Discarding P alone left D holding the record's dirty flag.
    final disp = _NoopDispatcher();
    final sync = SyncRepository(
      db: db,
      registry: _registry(disp),
      now: () => DateTime.fromMillisecondsSinceEpoch(1000),
    );
    final dead = await _enqueue(
      db,
      kind: 'update',
      state: 'dead',
      entityId: 'c1',
      key: 'idem-dead',
    );
    final vm = _EditVm(
      db: db,
      entityId: 'c1',
      failure: const ServerException(503, 'Down'),
    );
    await pump(tester, vm, sync: sync, disp: disp, existingId: 'c1');
    expect(vm.deadOutboxRowId, dead, reason: 'linked on open');

    await tap(tester, 'Save');
    await tap(tester, 'Discard failed save');

    expect(await db.outboxDao.byId(dead), isNull);
    expect(await db.outboxDao.byId(vm.rowId!), isNull);
    expect(disp.clearedDirty, ['c1']);
  });

  testWidgets('saving an edit of a record whose create was rejected sends the '
      'create again, and only then drops the rejected one', (tester) async {
    // Saved as an update, the edit waited behind the rejected create for
    // ever. The repository keeps a rejected temp-id create until a newer
    // create of the record exists — deleting it earlier stranded the record.
    final sync = SyncRepository(
      db: db,
      registry: _registry(_NoopDispatcher()),
      now: () => DateTime.fromMillisecondsSinceEpoch(1000),
    );
    final deadCreate = await _enqueue(db, kind: 'create', state: 'dead');
    final vm = _EditVm(db: db, entityId: _tmpId);
    await pump(tester, vm, sync: sync, existingId: _tmpId);
    expect(vm.deadOutboxRowId, deadCreate, reason: 'linked on open');
    expect(vm.savesAsCreate, isTrue);

    await tap(tester, 'Save');

    expect(await db.outboxDao.byId(deadCreate), isNull);
    final resent = (await db.outboxDao.byId(vm.rowId!))!;
    expect(resent.mutationKind, 'create');
    expect(resent.state, 'pending');
  });

  testWidgets('a create that fails after the form opened turns the next save '
      'into a re-send of it — each Retry queued an edit that could never go', (
    tester,
  ) async {
    final sync = _FakeSync();
    final create = await _enqueue(db, kind: 'create', state: 'pending');
    final vm = _EditVm(
      db: db,
      entityId: _tmpId,
      failure: const ServerException(
        0,
        'References a record that could not be saved',
      ),
    );
    await pump(tester, vm, sync: sync, existingId: _tmpId);
    expect(vm.savesAsCreate, isFalse, reason: 'its create was still queued');
    await db.outboxDao.markDead(
      id: create,
      error: 'The name field is required.',
      statusCode: 422,
      fieldErrorsJson: '{"name":["The name field is required."]}',
    );

    await tap(tester, 'Save');

    expect(vm.savesAsCreate, isTrue);
    expect(vm.deadOutboxRowId, create);
  });

  testWidgets('saving an edit still supersedes a dead create under the real '
      'id — the record exists, so that row is stale', (tester) async {
    // Left behind by a newer attempt re-keyed when an older one landed; a
    // Retry of it would create the record a second time.
    final sync = _FakeSync();
    final deadCreate = await _enqueue(
      db,
      kind: 'create',
      state: 'dead',
      entityId: 'c_real',
    );
    final vm = _EditVm(db: db, entityId: 'c_real');
    await pump(tester, vm, sync: sync, existingId: 'c_real');
    expect(vm.deadOutboxRowId, deadCreate, reason: 'linked on open');

    await tap(tester, 'Save');

    expect(sync.superseded, [deadCreate]);
  });
}

extension on GenericEditViewModel<String> {
  /// Make the draft dirty, as a user's edit would.
  // ignore: invalid_use_of_protected_member
  void updateDraftForTest(String value) => updateDraft(value);
}
