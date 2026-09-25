import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/client_api_model.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/client_repository.dart';
import 'package:admin/data/repositories/sync_repository.dart';
import 'package:admin/data/services/clients_api.dart';
import 'package:admin/domain/entity_registry.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/sync/mutation.dart';
import 'package:admin/domain/sync/sync_dispatcher.dart';
import 'package:admin/ui/core/edit/entity_edit_screen_scaffold.dart';
import 'package:admin/ui/core/unsaved_changes/unsaved_changes_guard.dart';
import 'package:admin/ui/features/clients/view_models/client_edit_view_model.dart';

import '../../../_localization_helper.dart';

/// An edit of a record whose offline create failed — opened from the Outbox,
/// say — saved an update, which waited forever behind the failed create: the
/// user's fix could never be sent from the form. It now re-sends the create
/// (`GenericEditViewModel.savesAsCreate`).
class _UnusedClientsApi implements ClientsApi {
  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

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

final _registry = EntityRegistry({
  EntityType.client: EntityHandlers(
    type: EntityType.client,
    wireName: 'client',
    apiPath: '/api/v1/clients',
    routePath: '/clients',
    icon: Icons.people,
    dispatcher: _NoopDispatcher(),
  ),
});

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
  final EntityRegistry entityRegistry = _registry;

  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  late AppDatabase db;
  late ClientRepository repo;
  late SyncRepository sync;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ClientRepository(
      db: db,
      api: _UnusedClientsApi(),
      uuid: const Uuid(),
      now: () => DateTime.utc(2026, 5, 11, 12),
    );
    sync = SyncRepository(
      db: db,
      registry: _registry,
      now: () => DateTime.fromMillisecondsSinceEpoch(1000),
    );
  });
  tearDown(() async => db.close());

  /// A client created offline whose create the server rejected.
  Future<({String tmpId, int createRow})> failedCreate() async {
    final created = await repo.create(
      companyId: 'co',
      draft: Client.fromApi(const ClientApi(id: '', name: 'Acme')),
    );
    await db.outboxDao.markDead(
      id: created.outboxRowId,
      error: 'The given data was invalid.',
      statusCode: 422,
      fieldErrorsJson: '{"name":["The name has already been taken."]}',
    );
    return (tmpId: created.entity.id, createRow: created.outboxRowId);
  }

  Future<ClientEditViewModel> pumpEdit(WidgetTester tester, String id) async {
    // Read outside the widget tree: `pumpAndSettle` never settles over a live
    // Drift watch stream.
    final existing = (await tester.runAsync(
      () => repo.watch(companyId: 'co', id: id).first,
    ))!;
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    late ClientEditViewModel vm;
    final router = GoRouter(
      initialLocation: '/clients/$id/edit',
      routes: [
        GoRoute(
          path: '/clients/:id/edit',
          builder: (_, state) =>
              EntityEditScreenScaffold<Client, ClientEditViewModel>(
                existingId: state.pathParameters['id'],
                entityTypeName: 'client',
                fetchExisting: (_, _, _, _) async => existing,
                buildVm: (_, _, companyId, existing) =>
                    vm = ClientEditViewModel(
                      repo: repo,
                      companyId: companyId,
                      existing: existing,
                    ),
                titleBuilder: (_, _) => 'Client',
                titleWhileLoading: (_) => 'Client',
                bodyBuilder: (_, _) => const SizedBox.shrink(),
                resetToEmpty: (_) {},
                onSaved: (_, _, _) {},
                entityIdOf: (client) => client.id,
              ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      Provider<Services>.value(
        value: _FakeServices(db: db, sync: sync),
        child: MaterialApp.router(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return vm;
  }

  testWidgets('an edit of a client whose create failed opens on the create\'s '
      'own rejection, not the edit that died of it', (tester) async {
    final (:tmpId, :createRow) = await failedCreate();
    final edit = await repo.save(
      companyId: 'co',
      client: Client.fromApi(ClientApi(id: tmpId, name: 'Acme Ltd')),
    );
    await db.outboxDao.markDead(
      id: edit.outboxRowId,
      error: 'References a record that could not be saved',
    );

    final vm = await pumpEdit(tester, tmpId);

    expect(vm.deadOutboxRowId, createRow);
    expect(vm.savesAsCreate, isTrue);
    expect(vm.isCreate, isFalse);
    expect(find.text('The name has already been taken.'), findsOneWidget);
  });

  testWidgets('saves as a create under its temp id, and the failed create is '
      'superseded', (tester) async {
    final (:tmpId, :createRow) = await failedCreate();
    await pumpEdit(tester, tmpId);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final rows = await db.select(db.outbox).get();
    expect(await db.outboxDao.byId(createRow), isNull);
    expect(rows, hasLength(1));
    expect(rows.single.mutationKind, MutationKind.create.wireName);
    expect(rows.single.entityId, tmpId);
    expect(rows.single.state, 'pending');
  });

  testWidgets('an edit whose create is still queued saves as an update behind '
      'it', (tester) async {
    final created = await repo.create(
      companyId: 'co',
      draft: Client.fromApi(const ClientApi(id: '', name: 'Acme')),
    );
    final vm = await pumpEdit(tester, created.entity.id);
    expect(vm.savesAsCreate, isFalse);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final kinds = [
      for (final r in await db.select(db.outbox).get()) r.mutationKind,
    ];
    expect(kinds, [MutationKind.create.wireName, MutationKind.update.wireName]);
  });
}
