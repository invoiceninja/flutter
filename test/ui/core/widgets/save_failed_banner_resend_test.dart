import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/sync_repository.dart';
import 'package:admin/domain/entity_registry.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/sync/mutation.dart';
import 'package:admin/domain/sync/sync_dispatcher.dart';
import 'package:admin/ui/core/edit/generic_edit_view_model.dart';
import 'package:admin/ui/core/widgets/save_failed_banner.dart';
import 'package:admin/ui/core/widgets/toast_controller.dart';

import '../../../_localization_helper.dart';

/// Resend puts a save that may already have gone through back in line. On a
/// create form it used to leave the form open, Save and all — and saving
/// again queued a second create while the resent one was in flight, or after
/// it had landed under an id the form never learns: two records on the
/// server. It now leaves the form the way Check does.
class _FakeSync implements SyncRepository {
  _FakeSync(this.db);

  @override
  final AppDatabase db;

  @override
  Future<bool> resendUnconfirmed(int id) =>
      db.outboxDao.resendUnconfirmed(id: id, now: 0);

  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _NoopDispatcher implements SyncDispatcher {
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
  }) async {}
}

class _FakeServices implements Services {
  _FakeServices({required this.db, required this.sync});

  @override
  final AppDatabase db;
  @override
  final SyncRepository sync;

  @override
  final EntityRegistry entityRegistry = EntityRegistry({
    EntityType.client: EntityHandlers(
      type: EntityType.client,
      wireName: 'client',
      apiPath: '/api/v1/clients',
      routePath: '/clients',
      icon: Icons.people,
      dispatcher: _NoopDispatcher(),
    ),
  });

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _Vm extends GenericEditViewModel<String> {
  _Vm() : super(initialDraft: 'draft');

  @override
  Future<SaveResult<String>> performSave() async =>
      throw UnimplementedError('not exercised');
}

void main() {
  late AppDatabase db;
  late ToastController toasts;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    toasts = ToastController();
  });
  tearDown(() async {
    toasts.dispose();
    await db.close();
  });

  Future<int> seedUnconfirmed(MutationKind kind, String entityId) =>
      db.outboxDao.enqueue(
        OutboxCompanion.insert(
          companyId: 'co',
          entityType: 'client',
          entityId: entityId,
          mutationKind: kind.wireName,
          payload: jsonEncode({'id': entityId}),
          idempotencyKey: 'k-$entityId',
          nextAttemptAt: 0,
          createdAt: 0,
          state: const Value('unconfirmed'),
          lastError: const Value('Connection reset by peer'),
        ),
      );

  Future<_Vm> resendFrom(
    WidgetTester tester, {
    required String formPath,
    required int rowId,
  }) async {
    final vm = _Vm()..applyUnconfirmed(rowId: rowId, isSave: true);
    addTearDown(vm.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<Services>.value(
            value: _FakeServices(db: db, sync: _FakeSync(db)),
          ),
          ChangeNotifierProvider<ToastController>.value(value: toasts),
        ],
        child: MaterialApp.router(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          routerConfig: GoRouter(
            initialLocation: formPath,
            routes: [
              GoRoute(
                path: '/clients',
                builder: (_, _) => const Text('clients list'),
                routes: [
                  GoRoute(
                    path: ':id/edit',
                    builder: (_, _) => Scaffold(
                      body: SaveFailedBanner(vm: vm, onDiscard: () async {}),
                    ),
                  ),
                  GoRoute(
                    path: 'new',
                    builder: (_, _) => Scaffold(
                      body: SaveFailedBanner(vm: vm, onDiscard: () async {}),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Resend'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Resend'));
    await tester.pumpAndSettle();
    return vm;
  }

  testWidgets('a resent create leaves its form for the list', (tester) async {
    final id = await seedUnconfirmed(MutationKind.create, 'tmp_c1');

    final vm = await resendFrom(tester, formPath: '/clients/new', rowId: id);

    expect((await db.outboxDao.byId(id))?.state, 'pending');
    expect(find.text('clients list'), findsOneWidget);
    expect(find.byType(SaveFailedBanner), findsNothing);
    expect(
      vm.isDirty,
      isFalse,
      reason: 'the route\'s exit guard would ask to discard what was sent',
    );
    toasts.clearAll();
  });

  testWidgets('a resent update keeps its form open', (tester) async {
    final id = await seedUnconfirmed(MutationKind.update, 'c1');

    await resendFrom(tester, formPath: '/clients/c1/edit', rowId: id);

    expect((await db.outboxDao.byId(id))?.state, 'pending');
    expect(find.text('clients list'), findsNothing);
    expect(find.byType(SaveFailedBanner), findsOneWidget);
    toasts.clearAll();
  });

  group('Discard on a change resent elsewhere', () {
    /// Seed an unconfirmed update the banner shows, resend it as the Outbox
    /// would, let [then] move it on, and tap the banner's Discard. Returns how
    /// many times the screen's discard ran.
    Future<(int, _Vm)> discardAfterResend(
      WidgetTester tester, {
      Future<void> Function(int id)? then,
    }) async {
      final id = await seedUnconfirmed(MutationKind.update, 'c1');
      final vm = _Vm()..applyUnconfirmed(rowId: id, isSave: true);
      addTearDown(vm.dispose);
      await db.outboxDao.resendUnconfirmed(id: id, now: 0);
      await then?.call(id);
      var discards = 0;
      await tester.pumpWidget(
        Provider<Services>.value(
          value: _FakeServices(db: db, sync: _FakeSync(db)),
          child: MaterialApp(
            theme: buildInTheme(InTheme.light),
            localizationsDelegates: kTestLocalizationsDelegates,
            supportedLocales: kTestSupportedLocales,
            home: Scaffold(
              body: SaveFailedBanner(vm: vm, onDiscard: () async => discards++),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Discard'));
      await tester.pumpAndSettle();
      return (discards, vm);
    }

    testWidgets('still drops it while it is only queued', (tester) async {
      final (discards, _) = await discardAfterResend(tester);
      expect(discards, 1, reason: 'the user asked to drop it');
    });

    testWidgets('just drops the banner once it is on its way', (tester) async {
      // Check and Resend re-read the row first; Discard went straight to the
      // screen's handler, which discards the row by id whatever its state —
      // an `in_flight` one included, whose request is already on the wire.
      final (discards, vm) = await discardAfterResend(
        tester,
        then: db.outboxDao.markInFlight,
      );

      expect(discards, 0);
      expect(vm.unconfirmedRowId, isNull);
      expect(find.text('A change may already have gone through'), findsNothing);
    });
  });
}
