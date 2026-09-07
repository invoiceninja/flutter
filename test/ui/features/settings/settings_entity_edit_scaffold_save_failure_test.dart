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

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/sync_repository.dart';
import 'package:admin/ui/core/edit/generic_edit_view_model.dart';
import 'package:admin/ui/features/settings/state/settings_level_controller.dart';
import 'package:admin/ui/features/settings/widgets/settings_entity_edit_scaffold.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../_localization_helper.dart';

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

  @override
  Future<bool> discardOutboxRow(int id) async {
    discarded.add(id);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// `Notify.*` falls back to `Services.toasts`, which `noSuchMethod` throws for
/// (caught → silent no-op, no ToastHost needed).
class _FakeServices implements Services {
  _FakeServices({required this.db, required this.auth, required this.sync});
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
}
