// Regression: the save-failure surfacing on `SettingsEntityEditScaffold` —
// the parallel edit chrome behind all 13 settings entities (tax rates, task
// statuses, tags, payment terms, group settings, schedules, designs, tokens,
// transaction rules, webhooks, bank accounts, …).
//
// The "a rejected save must never be a dead end" machinery (CLAUDE.md § Sync)
// was built into `EntityEditScaffold` only; this scaffold never got any of it,
// then got half of it. Two defects, one per test here:
//
//   1. `_relinkFailedSync` existed but was called ONLY from `_onSave`'s failure
//      branch — never from `_load`. So the same-session case was covered and
//      the REOPEN case was not: a tax rate whose save died in the outbox
//      reopened looking perfectly clean, no banner, no route to the dead row.
//      Its own doc already claimed it was there so "a reopened form states why
//      the last save failed", and its sibling
//      `EntityEditScreenScaffold._hydrateFailedSync` is called from the load
//      path — so the omission was invisible in review.
//
//   2. `_discardFailedSync` read only `vm.deadOutboxRowId` and dropped the DAO
//      fallback its sibling `_resolveDeadRowId` has (and that
//      `save_failed_banner.dart` documents: "the screen's discard handler does
//      the fallback dao lookup"). The banner renders off `submitError`, so a
//      row still `pending`/retrying after a network or 5xx failure has NO
//      dead-row id yet — the user tapped "Discard failed save", the banner
//      vanished, and the outbox row survived to apply the write they had just
//      discarded.

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
import 'package:admin/ui/core/edit/generic_edit_view_model.dart';
import 'package:admin/ui/features/settings/state/settings_level_controller.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/features/settings/widgets/settings_entity_edit_scaffold.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../_localization_helper.dart';
import '../../../_support/device_prefs_test_support.dart';

class _FakeAuth implements AuthRepository {
  _FakeAuth(String companyId)
    : _session = ValueNotifier<AuthSession?>(
        AuthSession(
          baseUrl: 'https://example.com',
          isHosted: true,
          accountId: 'acct',
          companies: const [],
          currentCompanyId: companyId,
        ),
      );
  final ValueNotifier<AuthSession?> _session;

  @override
  ValueListenable<AuthSession?> get session => _session;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _FakeSync implements SyncRepository {
  final List<int> discarded = [];
  final List<int> superseded = [];

  /// What a discard reports: true when the ghost path took the local record
  /// with a never-synced create. False by default — a discarded update never
  /// takes it — so the forms mounted without a router never navigate.
  bool removesRecord = false;

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
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// `Notify.*` falls back to `Services.toasts`, which `noSuchMethod` throws for
/// (caught → silent no-op, no ToastHost needed).
class _FakeServices implements Services {
  _FakeServices({
    required this.db,
    required this.auth,
    required this.sync,
    bool confirm = false,
  }) : confirmActions = ConfirmActionsController(
         prefs: prefsWith({DevicePrefKeys.confirmActions: confirm}),
       );
  @override
  final ConfirmActionsController confirmActions;
  @override
  final AppDatabase db;
  @override
  final AuthRepository auth;
  @override
  final SyncRepository sync;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// Draft is a plain String. `performSave` throws the way a network / 5xx
/// failure does, so `save()` returns null with `submitError` set and NO
/// dead-row id — the exact state the discard fallback exists for.
class _Vm extends GenericEditViewModel<String> {
  _Vm(String v) : super(initialDraft: v, original: v);

  @override
  Future<SaveResult<String>> performSave() async =>
      throw Exception('Connection failed');
}

/// An existing record whose save goes through: it queues its update the way
/// the repositories do.
class _SavingVm extends GenericEditViewModel<String> {
  _SavingVm({required this.db}) : super(initialDraft: 'seed', original: 'seed');

  final AppDatabase db;

  @override
  Future<SaveResult<String>> performSave() async {
    final rowId = await db.outboxDao.enqueue(
      OutboxCompanion.insert(
        companyId: 'co',
        entityType: 'tax_rates',
        entityId: 'tr1',
        mutationKind: 'update',
        payload: '{}',
        idempotencyKey: 'idem-save',
        createdAt: 0,
        nextAttemptAt: 0,
      ),
    );
    return SaveResult(entity: draft, outboxRowId: rowId);
  }
}

/// A new record. Its save queues the create row the way the repositories do —
/// under a `tmp_` id the view model remembers, while the draft carries no id
/// at all — and then fails with [failure].
class _CreateVm extends GenericEditViewModel<String> {
  _CreateVm({
    required this.db,
    required this.tmpId,
    required this.dead,
    this.failure,
    this.failureFor,
    this.rowState,
  }) : super(initialDraft: '');

  final AppDatabase db;
  final String tmpId;
  final bool dead;
  final Object? failure;
  final Object Function(int rowId)? failureFor;
  final String? rowState;
  int? rowId;

  @override
  Future<SaveResult<String>> performSave() async {
    rowId = await db.outboxDao.enqueue(
      OutboxCompanion.insert(
        companyId: 'co',
        entityType: 'tax_rates',
        entityId: tmpId,
        mutationKind: 'create',
        payload: '{}',
        idempotencyKey: 'idem-create',
        createdAt: 0,
        nextAttemptAt: 0,
        state: Value(rowState ?? (dead ? 'dead' : 'pending')),
        lastError: Value(dead ? 'The rate field must be a number.' : 'Down'),
        lastStatusCode: Value(dead ? 422 : 503),
        fieldErrorsJson: Value(
          dead ? '{"rate":["The rate field must be a number."]}' : null,
        ),
      ),
    );
    rememberCreateTempId(tmpId);
    throw failureFor?.call(rowId!) ?? failure!;
  }
}

void main() {
  const companyId = 'co';
  const wireName = 'tax_rates';
  const entityId = 'tr1';

  late AppDatabase db;
  late _FakeSync sync;
  late _FakeServices services;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    sync = _FakeSync();
    services = _FakeServices(db: db, auth: _FakeAuth(companyId), sync: sync);
  });
  tearDown(() async => db.close());

  /// Insert an outbox row for the entity under test. [dead] mirrors a row the
  /// drain gave up on (a 422); leaving it false mirrors one still retrying
  /// after a network / 5xx failure — the case with no dead-row id.
  Future<int> enqueueRow({
    required bool dead,
    String? error,
    String? fieldErrorsJson,
    int? statusCode,
    String state = '',
    String mutationKind = 'update',
    String idempotencyKey = '',
  }) => db.outboxDao.enqueue(
    OutboxCompanion.insert(
      companyId: companyId,
      entityType: wireName,
      entityId: entityId,
      mutationKind: mutationKind,
      payload: '{}',
      idempotencyKey: idempotencyKey.isEmpty
          ? 'idem-${dead ? 'dead' : 'live'}'
          : idempotencyKey,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      nextAttemptAt: DateTime.now().millisecondsSinceEpoch,
      state: Value(state.isEmpty ? (dead ? 'dead' : 'pending') : state),
      lastError: Value(error),
      lastStatusCode: Value(statusCode),
      fieldErrorsJson: Value(fieldErrorsJson),
    ),
  );

  late _Vm vm;
  final levelController = SettingsLevelController();

  Future<void> pumpScaffold(WidgetTester tester) async {
    vm = _Vm('seed');
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: MultiProvider(
          providers: [
            Provider<Services>.value(value: services),
            // `SettingsScreenScaffold` always mounts `SettingsScopeBanner`,
            // which reads this. It self-hides at company scope.
            ChangeNotifierProvider<SettingsLevelController>.value(
              value: levelController,
            ),
          ],
          child: SettingsEntityEditScaffold<String, _Vm>(
            existingId: entityId,
            backRoute: '/settings/tax_rates',
            createTitleKey: 'new_tax_rate',
            editTitleKey: 'edit_tax_rate',
            wireName: wireName,
            watchById: (_) => Stream<String?>.value('seed'),
            refreshAll: () async {},
            onArchive: (_) async {},
            onRestore: (_) async {},
            onDelete: (_) async {},
            vmFactory: ({String? existing}) => vm,
            canSave: (_) => true,
            isArchivedOf: (_) => false,
            isDeletedOf: (_) => false,
            bodyBuilder: (context, _) => const [SizedBox.shrink()],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('reopening a form whose save died in the outbox states why', (
    tester,
  ) async {
    await enqueueRow(
      dead: true,
      error: 'The rate field must be a number.',
      statusCode: 422,
      fieldErrorsJson: '{"rate":["The rate field must be a number."]}',
    );

    await pumpScaffold(tester);

    expect(
      find.text('The rate field must be a number.'),
      findsOneWidget,
      reason:
          'the load path must replay the dead row onto the fresh VM — '
          'otherwise a reopened form looks clean and the dead row is '
          'unreachable from the screen that created it',
    );
    expect(find.text('Discard failed save'), findsOneWidget);
    expect(
      vm.fieldErrorFor('rate'),
      'The rate field must be a number.',
      reason: 'the 422 field map must reach the form, not just the banner',
    );
  });

  testWidgets('a clean reopen renders no banner', (tester) async {
    await pumpScaffold(tester);

    expect(find.text('Discard failed save'), findsNothing);
    expect(vm.submitError, isNull);
  });

  testWidgets('closing the screen disposes its view model', (tester) async {
    // It never did, so every visit leaked the VM and any watch it holds —
    // the group-setting VM keeps a Drift stream open for its duplicate-name
    // check. `EntityEditScreenScaffold` always disposed its own.
    await pumpScaffold(tester);
    expect(vm.isDisposed, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(vm.isDisposed, isTrue);
  });

  testWidgets('Discard finds a still-retrying row the VM has no id for', (
    tester,
  ) async {
    // No dead row: the save failed on the network / a 5xx, so the row is
    // still `pending` and `applyFailedSync` was never given a row id.
    final rowId = await enqueueRow(dead: false);

    await pumpScaffold(tester);

    // Drive the real Save path: `performSave` throws, so `save()` returns
    // null with `submitError` set and no dead row to relink from.
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(vm.submitError, isNotNull, reason: 'precondition');
    expect(vm.deadOutboxRowId, isNull, reason: 'precondition');
    expect(find.text('Discard failed save'), findsOneWidget);

    await tester.tap(find.text('Discard failed save'));
    await tester.pumpAndSettle();

    expect(
      sync.discarded,
      [rowId],
      reason:
          'without the dao fallback the banner just vanishes and the row '
          'survives to apply the write the user discarded',
    );
  });

  testWidgets('Discard leaves an in-flight row alone', (tester) async {
    // `discardOutboxRow` deletes an in-flight row while its request stays on
    // the wire — right for the Outbox screen's explicit Discard, and exactly
    // the lie this surface exists to avoid. The row re-parks as `pending` on
    // failure, so the banner outlives the attempt either way.
    await enqueueRow(dead: false, state: 'in_flight');

    await pumpScaffold(tester);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard failed save'));
    await tester.pumpAndSettle();

    expect(sync.discarded, isEmpty);
  });

  testWidgets(
    'Discard abandons the save, not the record — a queued comment survives',
    (tester) async {
      // A discard abandons the ROW, not the ENTITY (CLAUDE.md § Sync). An
      // `add_comment` is enqueued under the parent's entity type + id, so a
      // kind-blind lookup would swallow unrelated user work.
      final commentRow = await enqueueRow(
        dead: false,
        mutationKind: 'add_comment',
        idempotencyKey: 'idem-comment',
      );
      final saveRow = await enqueueRow(dead: false);

      await pumpScaffold(tester);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard failed save'));
      await tester.pumpAndSettle();

      expect(sync.discarded, [saveRow]);
      expect(sync.discarded, isNot(contains(commentRow)));
    },
  );

  testWidgets('Discard on a save held as unconfirmed abandons that row, not '
      'a stale failure the form opened with', (tester) async {
    // The banner shows the unconfirmed save, and its Discard reached for the
    // dead row cached on open first — so the change that may already have
    // gone through survived the discard.
    final deadRow = await enqueueRow(
      dead: true,
      error: 'The rate field must be a number.',
      statusCode: 422,
    );
    final unconfirmedRow = await enqueueRow(
      dead: false,
      state: 'unconfirmed',
      idempotencyKey: 'idem-unconfirmed',
    );

    await pumpScaffold(tester);
    expect(vm.deadOutboxRowId, deadRow, reason: 'precondition');
    expect(vm.unconfirmedRowId, unconfirmedRow, reason: 'precondition');

    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    expect(sync.discarded, [unconfirmedRow]);
  });

  testWidgets('Discard after a failed re-save abandons the newer row, not the '
      'dead one the form opened with', (tester) async {
    // The form opened onto dead D, and the re-save's newer row is backing off
    // after a failure. The relink after every failed save re-cached D, so
    // Discard deleted D and the newer write — the one the user had just
    // discarded — went out anyway.
    await enqueueRow(
      dead: true,
      error: 'The rate field must be a number.',
      statusCode: 422,
    );
    final retrying = await enqueueRow(
      dead: false,
      idempotencyKey: 'idem-retrying',
    );

    await pumpScaffold(tester);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard failed save'));
    await tester.pumpAndSettle();

    expect(sync.discarded, [retrying]);
  });

  group('a create form', () {
    // A new record's draft has no id — its temp id lives on the view model —
    // so every lookup of its failed row was keyed on nothing.
    const tmpId = 'tmp_00000000-0000-4000-8000-0000000000aa';

    Future<_CreateVm> pumpCreate(
      WidgetTester tester, {
      required bool dead,
      required Object failure,
    }) async {
      final vm = _CreateVm(db: db, tmpId: tmpId, dead: dead, failure: failure);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          home: MultiProvider(
            providers: [
              Provider<Services>.value(value: services),
              ChangeNotifierProvider<SettingsLevelController>.value(
                value: levelController,
              ),
            ],
            child: SettingsEntityEditScaffold<String, _CreateVm>(
              existingId: null,
              backRoute: '/settings/tax_rates',
              createTitleKey: 'new_tax_rate',
              editTitleKey: 'edit_tax_rate',
              wireName: wireName,
              watchById: (_) => Stream<String?>.value(null),
              refreshAll: () async {},
              onArchive: (_) async {},
              onRestore: (_) async {},
              onDelete: (_) async {},
              vmFactory: ({String? existing}) => vm,
              canSave: (_) => true,
              isArchivedOf: (_) => false,
              isDeletedOf: (_) => false,
              bodyBuilder: (context, _) => const [SizedBox.shrink()],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return vm;
    }

    testWidgets('Discard after a server error drops the queued create — '
        'it would otherwise still go out', (tester) async {
      final vm = await pumpCreate(
        tester,
        dead: false,
        failure: const ServerException(503, 'Down'),
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard failed save'));
      await tester.pumpAndSettle();

      expect(sync.discarded, [vm.rowId]);
    });

    testWidgets('a create that went unconfirmed behind the form is shown, '
        'not dropped unseen', (tester) async {
      final vm = await pumpCreate(
        tester,
        dead: false,
        failure: const ServerException(503, 'Down'),
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      // A background retry's outcome is unknown.
      await db.outboxDao.markUnconfirmed(id: vm.rowId!, error: 'Reset');
      await tester.tap(find.text('Discard failed save'));
      await tester.pumpAndSettle();

      expect(sync.discarded, isEmpty);
      expect(vm.unconfirmedRowId, vm.rowId);
      expect(vm.recoveryTempId, tmpId, reason: 'so a Save is refused');
    });

    testWidgets('a rejection links its dead row, so Discard drops it', (
      tester,
    ) async {
      final vm = await pumpCreate(
        tester,
        dead: true,
        failure: const ValidationException('The given data was invalid.', {
          'rate': ['The rate field must be a number.'],
        }),
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(vm.deadOutboxRowId, vm.rowId);

      await tester.tap(find.text('Discard failed save'));
      await tester.pumpAndSettle();

      expect(sync.discarded, [vm.rowId]);
    });
  });

  group('leaving the form', () {
    // A discard that took a never-synced record with its create leaves the
    // form — a settings form stayed open on a record that no longer exists,
    // or on a create's draft that, saved again, could make it twice.
    const tmpId = 'tmp_00000000-0000-4000-8000-0000000000ab';

    Future<GoRouter> pumpRouted(
      WidgetTester tester,
      GenericEditViewModel<String> vm, {
      String? existingId,
    }) async {
      Widget scaffold(String? id) =>
          SettingsEntityEditScaffold<String, GenericEditViewModel<String>>(
            existingId: id,
            backRoute: '/settings/tax_rates',
            createTitleKey: 'new_tax_rate',
            editTitleKey: 'edit_tax_rate',
            wireName: wireName,
            watchById: (_) => Stream<String?>.value('seed'),
            refreshAll: () async {},
            onArchive: (_) async {},
            onRestore: (_) async {},
            onDelete: (_) async {},
            vmFactory: ({String? existing}) => vm,
            canSave: (_) => true,
            isArchivedOf: (_) => false,
            isDeletedOf: (_) => false,
            bodyBuilder: (context, _) => const [SizedBox.shrink()],
          );
      final router = GoRouter(
        initialLocation: existingId == null
            ? '/settings/tax_rates/new'
            : '/settings/tax_rates/$existingId',
        routes: [
          GoRoute(
            path: '/settings/tax_rates',
            builder: (_, _) => const Scaffold(body: Text('tax rates list')),
            routes: [
              GoRoute(path: 'new', builder: (_, _) => scaffold(null)),
              GoRoute(
                path: ':id',
                builder: (_, state) => scaffold(state.pathParameters['id']),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<Services>.value(value: services),
            ChangeNotifierProvider<SettingsLevelController>.value(
              value: levelController,
            ),
          ],
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

    testWidgets('discarding a create that may already have gone through leaves '
        'a settings create form for its list', (tester) async {
      sync.removesRecord = true;
      final vm = _CreateVm(
        db: db,
        tmpId: tmpId,
        dead: false,
        rowState: 'unconfirmed',
        failureFor: UnconfirmedPriorMutationException.new,
      );
      final router = await pumpRouted(tester, vm);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      expect(sync.discarded, [vm.rowId]);
      expect(uriOf(router), '/settings/tax_rates');
    });

    testWidgets('discarding the failed create of a record the server has never '
        'seen leaves its settings form', (tester) async {
      sync.removesRecord = true;
      final dead = await db.outboxDao.enqueue(
        OutboxCompanion.insert(
          companyId: companyId,
          entityType: wireName,
          entityId: tmpId,
          mutationKind: 'create',
          payload: '{}',
          idempotencyKey: 'idem-dead',
          createdAt: 0,
          nextAttemptAt: 0,
          state: const Value('dead'),
          lastError: const Value('The rate field must be a number.'),
          lastStatusCode: const Value(422),
        ),
      );
      final router = await pumpRouted(tester, _Vm('seed'), existingId: tmpId);
      await tester.tap(find.text('Discard failed save'));
      await tester.pumpAndSettle();

      expect(sync.discarded, [dead]);
      expect(uriOf(router), '/settings/tax_rates');
    });

    testWidgets('with Confirm actions on, discarding that create asks first — '
        'it takes the record, and whatever needs it', (tester) async {
      services = _FakeServices(
        db: db,
        auth: _FakeAuth(companyId),
        sync: sync,
        confirm: true,
      );
      sync.removesRecord = true;
      final dead = await db.outboxDao.enqueue(
        OutboxCompanion.insert(
          companyId: companyId,
          entityType: wireName,
          entityId: tmpId,
          mutationKind: 'create',
          payload: '{}',
          idempotencyKey: 'idem-dead',
          createdAt: 0,
          nextAttemptAt: 0,
          state: const Value('dead'),
          lastError: const Value('The rate field must be a number.'),
          lastStatusCode: const Value(422),
        ),
      );
      final router = await pumpRouted(tester, _Vm('seed'), existingId: tmpId);

      await tester.tap(find.text('Discard failed save'));
      await tester.pumpAndSettle();
      expect(find.textContaining('never saved to the server'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(sync.discarded, isEmpty);

      await tester.tap(find.text('Discard failed save'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(PrimaryDialogAction),
          matching: find.text('Discard'),
        ),
      );
      await tester.pumpAndSettle();
      expect(sync.discarded, [dead]);
      expect(uriOf(router), '/settings/tax_rates');
    });

    testWidgets('a create that fails after the form opened turns the next '
        'save into a re-send of it', (tester) async {
      final create = await db.outboxDao.enqueue(
        OutboxCompanion.insert(
          companyId: companyId,
          entityType: wireName,
          entityId: tmpId,
          mutationKind: 'create',
          payload: '{}',
          idempotencyKey: 'idem-create',
          createdAt: 0,
          nextAttemptAt: 0,
        ),
      );
      final vm = _Vm('seed');
      await pumpRouted(tester, vm, existingId: tmpId);
      expect(vm.savesAsCreate, isFalse, reason: 'its create was still queued');
      await db.outboxDao.markDead(
        id: create,
        error: 'The rate field must be a number.',
        statusCode: 422,
      );

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(vm.savesAsCreate, isTrue);
      expect(vm.deadOutboxRowId, create);
    });

    testWidgets('a create form that drops a create the server never saw keeps '
        'its draft', (tester) async {
      sync.removesRecord = true;
      final vm = _CreateVm(
        db: db,
        tmpId: tmpId,
        dead: false,
        failure: const ServerException(503, 'Down'),
      );
      final router = await pumpRouted(tester, vm);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard failed save'));
      await tester.pumpAndSettle();

      expect(sync.discarded, [vm.rowId]);
      expect(uriOf(router), '/settings/tax_rates/new');
    });

    testWidgets('an edit of a record whose create failed links that create '
        'and saves by re-sending it', (tester) async {
      // Its save queued an update that waited forever behind the failed
      // create; and the form opened on the cascade's error on the edit that
      // died with it, not on the create's own rejection.
      Future<int> dead(String kind, String key, String error) =>
          db.outboxDao.enqueue(
            OutboxCompanion.insert(
              companyId: companyId,
              entityType: wireName,
              entityId: tmpId,
              mutationKind: kind,
              payload: '{}',
              idempotencyKey: key,
              createdAt: 0,
              nextAttemptAt: 0,
              state: const Value('dead'),
              lastError: Value(error),
              lastStatusCode: const Value(422),
            ),
          );
      final create = await dead(
        'create',
        'idem-create',
        'The rate field must be a number.',
      );
      await dead(
        'update',
        'idem-update',
        'References a record that could not be saved',
      );
      final vm = _Vm('seed');

      await pumpRouted(tester, vm, existingId: tmpId);

      expect(vm.deadOutboxRowId, create);
      expect(vm.savesAsCreate, isTrue);
      expect(vm.isCreate, isFalse);
    });

    testWidgets('a successful re-save drops the failed save it replaced', (
      tester,
    ) async {
      // Settings forms never did: the failed save re-showed its stale error
      // on every open, and an Outbox Retry would PUT its old payload over the
      // newer one.
      final dead = await enqueueRow(
        dead: true,
        error: 'The rate field must be a number.',
        statusCode: 422,
        fieldErrorsJson: '{"rate":["The rate field must be a number."]}',
      );
      final router = await pumpRouted(
        tester,
        _SavingVm(db: db),
        existingId: entityId,
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(sync.superseded, [dead]);
      expect(uriOf(router), '/settings/tax_rates');
    });
  });
}
