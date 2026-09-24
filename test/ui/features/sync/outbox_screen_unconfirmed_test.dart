import 'dart:convert';

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
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/sync_repository.dart';
import 'package:admin/domain/entity_registry.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/sync/mutation.dart';
import 'package:admin/domain/sync/sync_dispatcher.dart';
import 'package:admin/ui/core/widgets/toast_controller.dart';
import 'package:admin/ui/features/sync/views/outbox_screen.dart';

import '../../../_localization_helper.dart';

/// An `unconfirmed` row is a change that may already have reached the server.
/// Retry — a silent re-send — is exactly what could do it twice, so the
/// Outbox offers Check and a Resend that asks first instead.
class _FakeAuth implements AuthRepository {
  _FakeAuth(this._session);
  final ValueListenable<AuthSession?> _session;
  @override
  ValueListenable<AuthSession?> get session => _session;
  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _FakeSync implements SyncRepository {
  _FakeSync(this.db);

  @override
  final AppDatabase db;
  final List<int> rechecked = [];
  final List<int> resent = [];

  @override
  Future<void> recheck(OutboxRow row) async => rechecked.add(row.id);

  @override
  Future<bool> resendUnconfirmed(int id) async {
    resent.add(id);
    return db.outboxDao.resendUnconfirmed(id: id, now: 0);
  }

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
  _FakeServices({required this.auth, required this.db, required this.sync})
    : confirmActions = ConfirmActionsController(db: db, initial: false);

  @override
  final AuthRepository auth;
  @override
  final AppDatabase db;
  @override
  final SyncRepository sync;
  @override
  final ConfirmActionsController confirmActions;

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

void main() {
  late AppDatabase db;
  late ToastController toasts;
  late ValueNotifier<AuthSession?> session;
  late _FakeSync sync;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    toasts = ToastController();
    session = ValueNotifier<AuthSession?>(
      const AuthSession(
        baseUrl: 'https://example.test',
        isHosted: false,
        accountId: 'acct',
        companies: [
          AuthCompany(
            id: 'co',
            name: 'Test',
            displayName: 'Test',
            permissions: '',
            isAdmin: true,
            isOwner: true,
          ),
        ],
        currentCompanyId: 'co',
      ),
    );
    sync = _FakeSync(db);
  });

  tearDown(() async {
    session.dispose();
    toasts.dispose();
    await db.close();
  });

  Future<int> seed({required String kind, required String entityId}) =>
      db.outboxDao.enqueue(
        OutboxCompanion.insert(
          companyId: 'co',
          entityType: 'client',
          entityId: entityId,
          mutationKind: kind,
          payload: jsonEncode({'id': entityId}),
          idempotencyKey: 'k-$kind',
          nextAttemptAt: 0,
          createdAt: 0,
          state: const Value('unconfirmed'),
          lastError: const Value('Connection reset by peer'),
        ),
      );

  Widget host() => MultiProvider(
    providers: [
      Provider<Services>.value(
        value: _FakeServices(auth: _FakeAuth(session), db: db, sync: sync),
      ),
      ChangeNotifierProvider<ToastController>.value(value: toasts),
    ],
    child: MaterialApp.router(
      theme: buildInTheme(InTheme.light),
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: kTestSupportedLocales,
      routerConfig: GoRouter(
        initialLocation: '/sync/outbox',
        routes: [
          GoRoute(
            path: '/sync/outbox',
            builder: (_, _) => const OutboxScreen(),
          ),
          GoRoute(
            path: '/clients',
            builder: (_, _) => const Text('clients list'),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) =>
                    Text('client ${state.pathParameters['id']}'),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  /// Explicit pumps rather than `pumpAndSettle` — see the discard test.
  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byType(PopupMenuButton<String>).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> pick(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
  }

  Future<void> teardownTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  }

  testWidgets('says what it is and what to do, and offers Check and Resend — '
      'never Retry', (tester) async {
    await seed(kind: 'email_entity', entityId: 'c1');
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('May have been sent'), findsOneWidget);
    expect(find.textContaining("won't be sent again on its own"), findsOne);
    expect(find.text('Connection reset by peer'), findsOneWidget);

    await openMenu(tester);
    expect(find.text('Check'), findsOneWidget);
    expect(find.text('Resend'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
    await teardownTree(tester);
  });

  testWidgets('Resend asks first; Cancel leaves the row waiting', (
    tester,
  ) async {
    final id = await seed(kind: 'email_entity', entityId: 'c1');
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await openMenu(tester);
    await pick(tester, 'Resend');
    await tester.pumpAndSettle();
    expect(find.textContaining('do it a second time'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(sync.resent, isEmpty);
    expect((await db.outboxDao.byId(id))?.state, 'unconfirmed');
    await teardownTree(tester);
  });

  testWidgets('confirming Resend puts the row back in line', (tester) async {
    final id = await seed(kind: 'email_entity', entityId: 'c1');
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await openMenu(tester);
    await pick(tester, 'Resend');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Resend'));
    await tester.pumpAndSettle();

    expect(sync.resent, [id]);
    expect((await db.outboxDao.byId(id))?.state, 'pending');
    expect(toasts.toasts.single.message, 'Sync has started');

    // The toast owns an auto-dismiss Timer; the binding fails the test if one
    // is still pending when the tree goes away.
    toasts.clearAll();
    await teardownTree(tester);
  });

  testWidgets('Check re-fetches, then opens the record the change was to', (
    tester,
  ) async {
    final id = await seed(kind: 'email_entity', entityId: 'c1');
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await openMenu(tester);
    await pick(tester, 'Check');
    await tester.pumpAndSettle();

    expect(sync.rechecked, [id]);
    expect(find.text('client c1'), findsOneWidget);
    await teardownTree(tester);
  });

  testWidgets('Check on a create opens its list, where a record the server '
      'made would lead', (tester) async {
    await seed(kind: 'create', entityId: 'tmp_c1');
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    await openMenu(tester);
    await pick(tester, 'Check');
    await tester.pumpAndSettle();

    expect(find.text('clients list'), findsOneWidget);
    await teardownTree(tester);
  });
}
