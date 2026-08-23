import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/sync_repository.dart';
import 'package:admin/domain/entity_registry.dart';
import 'package:admin/ui/core/widgets/toast_controller.dart';
import 'package:admin/ui/features/sync/views/outbox_screen.dart';

import '../../../_localization_helper.dart';

/// invoiceninja/flutter#44: "Discard doesn't immediately remove the item from
/// view; requires re-entering Outbox."
///
/// The pin is the *first* test: with the discard held open, the tile must
/// already be gone while the row is still in Drift. That fails on a screen
/// that can only react to a watch emission, whatever the reason the emission
/// didn't arrive.
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
  _FakeSync(this.db, {this.gate, this.fail = false});

  @override
  final AppDatabase db;

  /// Holds the discard open so the test can inspect the frame between the tap
  /// and the DB write.
  final Completer<void>? gate;
  final bool fail;

  @override
  Future<bool> discardOutboxRow(int id) async {
    final held = gate;
    if (held != null) await held.future;
    if (fail) throw StateError('boom');
    await db.outboxDao.deleteRow(id);
    return true;
  }

  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _FakeServices implements Services {
  _FakeServices({required this.auth, required this.db, required this.sync});

  @override
  final AuthRepository auth;
  @override
  final AppDatabase db;
  @override
  final SyncRepository sync;

  // No handlers: `byWireName` returns null, so the tile falls back to the
  // generic icon and the menu simply omits "Open".
  @override
  final EntityRegistry entityRegistry = EntityRegistry(const {});

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

AuthSession _sessionFor(String companyId) => AuthSession(
  baseUrl: 'https://example.test',
  isHosted: false,
  accountId: 'acct',
  companies: [
    for (final id in const ['co', 'co2'])
      AuthCompany(
        id: id,
        name: 'Test $id',
        displayName: 'Test $id',
        permissions: '',
        isAdmin: true,
        isOwner: true,
      ),
  ],
  currentCompanyId: companyId,
);

void main() {
  late AppDatabase db;
  late ToastController toasts;
  late ValueNotifier<AuthSession?> session;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    toasts = ToastController();
    session = ValueNotifier<AuthSession?>(_sessionFor('co'));
  });

  tearDown(() async {
    session.dispose();
    toasts.dispose();
    await db.close();
  });

  Future<int> seed({
    required String entityId,
    required String idempotencyKey,
    int createdAt = 0,
    String companyId = 'co',
  }) => db.outboxDao.enqueue(
    OutboxCompanion.insert(
      companyId: companyId,
      entityType: 'schedule',
      entityId: entityId,
      mutationKind: 'create',
      payload: jsonEncode({'id': entityId}),
      idempotencyKey: idempotencyKey,
      nextAttemptAt: 0,
      createdAt: createdAt,
      state: const Value('dead'),
    ),
  );

  Widget host(SyncRepository sync) => MaterialApp(
    theme: buildInTheme(InTheme.light),
    localizationsDelegates: kTestLocalizationsDelegates,
    supportedLocales: kTestSupportedLocales,
    home: MultiProvider(
      providers: [
        Provider<Services>.value(
          value: _FakeServices(auth: _FakeAuth(session), db: db, sync: sync),
        ),
        ChangeNotifierProvider<ToastController>.value(value: toasts),
      ],
      child: const OutboxScreen(),
    ),
  );

  /// Opens a row's menu and picks [label]. Deliberately explicit pumps rather
  /// than `pumpAndSettle`: `PopupMenuButton` only fires `onSelected` once the
  /// menu route has finished popping.
  ///
  /// Takes a plain finder (rows are newest-first, so `.at(0)` is the newest)
  /// so the behavioural pin below doesn't lean on the row keys this same
  /// change introduces — it has to fail on the old screen for the right
  /// reason.
  Future<void> pickFromMenu(
    WidgetTester tester,
    Finder menu,
    String label,
  ) async {
    await tester.tap(menu);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text(label));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
  }

  // The default 800x600 test viewport is at/above `Breakpoints.wide` (600),
  // so the screen renders its global-nav branch: no drawer, no hamburger, and
  // therefore no `StatefulNavigationShell` needed in the tree. Shrinking the
  // view below 600 in a new test would change that.
  Future<void> teardownTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  }

  testWidgets('Discard removes the tile in the frame the delete is still '
      'pending', (tester) async {
    final gate = Completer<void>();
    final kept = await seed(entityId: 'tmp_a', idempotencyKey: 'k1');
    final target = await seed(
      entityId: 'tmp_b',
      idempotencyKey: 'k2',
      createdAt: 1,
    );
    await tester.pumpWidget(host(_FakeSync(db, gate: gate)));
    await tester.pumpAndSettle();
    expect(find.text('tmp_b'), findsOneWidget);

    // Newest first, so row 0 is `tmp_b`.
    await pickFromMenu(
      tester,
      find.byType(PopupMenuButton<String>).at(0),
      'Discard',
    );

    expect(
      await db.outboxDao.byId(target),
      isNotNull,
      reason: 'the delete is still gated — this is the optimistic hide',
    );
    expect(find.text('tmp_b'), findsNothing);
    expect(find.text('tmp_a'), findsOneWidget, reason: 'only that one goes');
    expect(find.byKey(ValueKey(kept)), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('tmp_b'), findsNothing, reason: 'stays gone');
    expect(await db.outboxDao.byId(target), isNull);
    await teardownTree(tester);
  });

  testWidgets('a discard that fails puts the tile back and says so', (
    tester,
  ) async {
    final id = await seed(entityId: 'tmp_a', idempotencyKey: 'k1');
    await tester.pumpWidget(host(_FakeSync(db, fail: true)));
    await tester.pumpAndSettle();

    await pickFromMenu(
      tester,
      find.byType(PopupMenuButton<String>).first,
      'Discard',
    );
    await tester.pumpAndSettle();

    expect(find.text('tmp_a'), findsOneWidget, reason: 'still queued');
    expect(find.byKey(ValueKey(id)), findsOneWidget);
    expect(toasts.toasts.single.variant, NotifyVariant.error);
    expect(toasts.toasts.single.message, 'An error occurred');

    // The toast owns an auto-dismiss Timer; the binding fails the test if one
    // is still pending when the tree goes away.
    toasts.clearAll();
    await teardownTree(tester);
  });

  testWidgets('a company switch rebinds the queue to the new tenant', (
    tester,
  ) async {
    await seed(entityId: 'tmp_a', idempotencyKey: 'k1');
    await seed(entityId: 'tmp_z', idempotencyKey: 'k2', companyId: 'co2');
    await tester.pumpWidget(host(_FakeSync(db)));
    await tester.pumpAndSettle();
    expect(find.text('tmp_a'), findsOneWidget);
    expect(find.text('tmp_z'), findsNothing);

    session.value = _sessionFor('co2');
    await tester.pumpAndSettle();

    expect(find.text('tmp_z'), findsOneWidget, reason: "co2's queue");
    expect(find.text('tmp_a'), findsNothing, reason: 'never the old tenant');
    await teardownTree(tester);
  });

  testWidgets('rows are keyed by row id, not list position', (tester) async {
    final first = await seed(entityId: 'tmp_a', idempotencyKey: 'k1');
    final second = await seed(
      entityId: 'tmp_b',
      idempotencyKey: 'k2',
      createdAt: 1,
    );
    await tester.pumpWidget(host(_FakeSync(db)));
    await tester.pumpAndSettle();

    expect(find.byKey(ValueKey(first)), findsOneWidget);
    expect(find.byKey(ValueKey(second)), findsOneWidget);
    await teardownTree(tester);
  });
}
