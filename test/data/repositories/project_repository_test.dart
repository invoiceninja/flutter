import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/client_api_model.dart';
import 'package:admin/data/models/api/project_api_model.dart';
import 'package:admin/data/models/api/tag_api_model.dart';
import 'package:admin/data/models/domain/project.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/base_entity_repository.dart';
import 'package:admin/data/repositories/client_repository.dart';
import 'package:admin/data/repositories/project_repository.dart';
import 'package:admin/data/services/clients_api.dart';
import 'package:admin/data/services/projects_api.dart';
import 'package:admin/data/services/upload_source.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/sync/mutation.dart';

import '_base_entity_repository_contract.dart';

/// Covers the universal `BaseEntityRepository` contract via the shared
/// harness plus Project-specific assertions for `watchForClient`, the
/// dueDate Date round-trip, and the document mutation kinds.
class _ProjectFixture
    extends EntityRepositoryContractFixture<Project, ProjectApi> {
  @override
  String get entityType => 'project';

  @override
  ProjectRepository buildRepo(AppDatabase db) =>
      ProjectRepository(db: db, api: _FakeProjectsApi());

  @override
  ProjectApi buildApiModel({
    required String id,
    String? displayValue,
    int updatedAt = 1700000000,
  }) => ProjectApi(id: id, name: displayValue ?? id, updatedAt: updatedAt);

  @override
  Project fromApi(ProjectApi api) => Project.fromApi(api);

  @override
  Project editCopy(Project item, {required String displayValue}) =>
      item.copyWith(name: displayValue);

  @override
  String idOf(Project item) => item.id;

  @override
  bool isDirtyOf(Project item) => item.isDirty;

  @override
  DateTime Function(Project item)? get updatedAtOf =>
      (item) => item.updatedAt;

  @override
  Future<SaveResult<Project>> create(
    BaseEntityRepository<Project, ProjectApi> repo, {
    required String companyId,
    required Project draft,
  }) => (repo as ProjectRepository).create(companyId: companyId, draft: draft);

  @override
  Future<SaveResult<Project>> save(
    BaseEntityRepository<Project, ProjectApi> repo, {
    required String companyId,
    required Project entity,
  }) => (repo as ProjectRepository).save(companyId: companyId, project: entity);

  @override
  Future<void> delete(
    BaseEntityRepository<Project, ProjectApi> repo, {
    required String companyId,
    required String id,
  }) => (repo as ProjectRepository).delete(companyId: companyId, id: id);
}

void main() {
  runEntityRepositoryContract(_ProjectFixture());

  group('ProjectRepository — entity-specific', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });
    tearDown(() async {
      await db.close();
    });

    ProjectRepository makeRepo() =>
        ProjectRepository(db: db, api: _FakeProjectsApi());

    test('_fromRow overlays is_dirty so watchPage reflects the unsaved '
        'state after restart', () async {
      final repo = makeRepo();
      final draft = Project.fromApi(
        const ProjectApi(name: 'X', updatedAt: 1700000000),
      );
      await repo.create(companyId: 'co', draft: draft);
      final created = await repo
          .watchPage(companyId: 'co', loadedPages: 1)
          .first;
      expect(created, hasLength(1));
      expect(created.first.isDirty, isTrue);
    });

    test('runTemplate enqueues MutationKind.runTemplate with id + '
        'template_id', () async {
      final repo = makeRepo();
      await repo.runTemplate(
        companyId: 'co',
        id: 'proj_99',
        templateId: 'tmpl_3',
      );
      final rows = await db.outboxDao.nextReady(
        companyId: 'co',
        now: 9999999999999,
      );
      final row = rows.firstWhere(
        (r) => r.mutationKind == MutationKind.runTemplate.wireName,
      );
      expect(row.entityId, 'proj_99');
      expect(row.payload, contains('tmpl_3'));
    });

    test('dueDate Date round-trips through fromApi/toApiJson', () {
      final api = const ProjectApi(
        id: 'proj_1',
        name: 'Q1 work',
        dueDate: '2026-04-30',
        taskRate: '50',
        budgetedHours: 40,
        updatedAt: 1700000000,
      );
      final domain = Project.fromApi(api);
      expect(domain.dueDate, const Date(2026, 4, 30));
      expect(domain.taskRate, Decimal.parse('50'));
      expect(domain.budgetedHours, 40.0);

      final payload = domain.toApiJson();
      expect(payload['due_date'], '2026-04-30');
      expect(payload['task_rate'], '50');
      expect(payload['budgeted_hours'], 40.0);
    });

    test('budgetedAmount round-trips as Decimal from number or string', () {
      // The server transformer emits a float; older/raw payloads can carry a
      // string. Both must land on the same Decimal and serialize back as a
      // string so precision survives (see `task_rate`).
      for (final raw in <Object>[1250.5, '1250.50']) {
        final domain = Project.fromApi(
          ProjectApi(
            id: 'proj_1',
            name: 'Q1 work',
            budgetedAmount: raw,
            updatedAt: 1700000000,
          ),
        );
        expect(domain.budgetedAmount, Decimal.parse('1250.5'));
        expect(domain.toApiJson()['budgeted_amount'], '1250.5');
      }
    });

    test('absent budgetedAmount defaults to zero', () {
      final domain = Project.fromApi(
        const ProjectApi(id: 'proj_1', name: 'X', updatedAt: 1700000000),
      );
      expect(domain.budgetedAmount, Decimal.zero);
    });

    test('empty dueDate string parses to null, serializes back to empty', () {
      final domain = Project.fromApi(
        const ProjectApi(id: 'proj_1', name: 'X', updatedAt: 1700000000),
      );
      expect(domain.dueDate, isNull);
      expect(domain.toApiJson()['due_date'], '');
    });

    test(
      'watchForClient returns only projects with a matching clientId',
      () async {
        final repo = makeRepo();
        await repo.applyCreateResponse(
          companyId: 'co',
          tempId: 'p1',
          serverResponse: const ProjectApi(
            id: 'p1',
            name: 'P1',
            clientId: 'client_a',
            updatedAt: 1700000000,
          ),
        );
        await repo.applyCreateResponse(
          companyId: 'co',
          tempId: 'p2',
          serverResponse: const ProjectApi(
            id: 'p2',
            name: 'P2',
            clientId: 'client_b',
            updatedAt: 1700000001,
          ),
        );
        await repo.applyCreateResponse(
          companyId: 'co',
          tempId: 'p3',
          serverResponse: const ProjectApi(
            id: 'p3',
            name: 'P3',
            clientId: 'client_a',
            updatedAt: 1700000002,
          ),
        );
        final forA = await repo
            .watchForClient(companyId: 'co', clientId: 'client_a')
            .first;
        expect(forA.map((p) => p.id), unorderedEquals(['p1', 'p3']));
      },
    );

    test('watchForClient with empty clientId yields an empty list', () async {
      final repo = makeRepo();
      final result = await repo
          .watchForClient(companyId: 'co', clientId: '')
          .first;
      expect(result, isEmpty);
    });

    group('watchPage extraFilters mirrors (H1)', () {
      Future<void> seed(
        ProjectRepository repo,
        String id, {
        String clientId = '',
        List<TagRefApi> tags = const [],
      }) => repo.applyCreateResponse(
        companyId: 'co',
        tempId: id,
        serverResponse: ProjectApi(
          id: id,
          name: id,
          clientId: clientId,
          tags: tags,
          updatedAt: 1700000000,
        ),
      );

      test('client_id membership narrows locally', () async {
        final repo = makeRepo();
        await seed(repo, 'p1', clientId: 'client_a');
        await seed(repo, 'p2', clientId: 'client_b');
        await seed(repo, 'p3', clientId: 'client_c');

        final rows = await repo
            .watchPage(
              companyId: 'co',
              extraFilters: const {
                'client_id': {'client_a', 'client_c'},
              },
            )
            .first;
        expect(rows.map((p) => p.id), unorderedEquals(['p1', 'p3']));
      });

      test('tag_ids narrows post-decode with OR membership', () async {
        final repo = makeRepo();
        await seed(
          repo,
          'p1',
          tags: const [TagRefApi(id: 't1', name: 'Design')],
        );
        await seed(
          repo,
          'p2',
          tags: const [TagRefApi(id: 't2', name: 'Ops')],
        );
        await seed(repo, 'p3');

        final rows = await repo
            .watchPage(
              companyId: 'co',
              extraFilters: const {
                'tag_ids': {'t1'},
              },
            )
            .first;
        expect(rows.map((p) => p.id), ['p1']);
      });
    });

    test('uploadDocument enqueues MutationKind.documentUpload (NOT '
        'password-gated)', () async {
      final repo = makeRepo();
      await repo.uploadDocument(
        companyId: 'co',
        entityId: 'proj_1',
        source: fileUploadSource('/tmp/foo.pdf'),
      );
      final rows = await db.outboxDao.nextReady(
        companyId: 'co',
        now: 9999999999999,
      );
      final row = rows.firstWhere(
        (r) => r.mutationKind == MutationKind.documentUpload.wireName,
      );
      expect(row.entityId, 'proj_1');
      expect(row.payload, contains('/tmp/foo.pdf'));
      expect(row.requiresPassword, isFalse);
    });

    test('deleteDocument enqueues MutationKind.documentDelete with '
        'requiresPassword=true', () async {
      final repo = makeRepo();
      await repo.deleteDocument(
        companyId: 'co',
        entityId: 'proj_1',
        documentId: 'doc_42',
      );
      final rows = await db.outboxDao.nextReady(
        companyId: 'co',
        now: 9999999999999,
      );
      final row = rows.firstWhere(
        (r) => r.mutationKind == MutationKind.documentDelete.wireName,
      );
      expect(row.requiresPassword, isTrue);
      expect(row.payload, contains('doc_42'));
    });

    test('delete and purge are password-gated', () async {
      final repo = makeRepo();
      await repo.delete(companyId: 'co', id: 'proj_1');
      await repo.purge(companyId: 'co', id: 'proj_1');
      final rows = await db.outboxDao.nextReady(
        companyId: 'co',
        now: 9999999999999,
      );
      final delRow = rows.firstWhere(
        (r) => r.mutationKind == MutationKind.delete.wireName,
      );
      final purgeRow = rows.firstWhere(
        (r) => r.mutationKind == MutationKind.purge.wireName,
      );
      expect(delRow.requiresPassword, isTrue);
      expect(purgeRow.requiresPassword, isTrue);
    });

    test('restore clears archived_at so the row returns to the active list '
        'and leaves the archived set', () async {
      final repo = makeRepo();

      // Seed an archived project (server echo carries archived_at > 0).
      await repo.applyUpdateResponse(
        companyId: 'co',
        serverResponse: const ProjectApi(
          id: 'p1',
          name: 'P1',
          archivedAt: 1700000100,
          updatedAt: 1700000100,
        ),
      );
      Future<Set<String>> idsFor(EntityState state) async =>
          (await repo.watchPage(companyId: 'co', states: {state}).first)
              .map((p) => p.id)
              .toSet();
      expect(await idsFor(EntityState.archived), contains('p1'));
      expect(await idsFor(EntityState.active), isNot(contains('p1')));

      // Restore: the server echoes archived_at: 0.
      await repo.applyUpdateResponse(
        companyId: 'co',
        serverResponse: const ProjectApi(
          id: 'p1',
          name: 'P1',
          archivedAt: 0,
          updatedAt: 1700000200,
        ),
      );

      // The row must reappear in the active list (the bug: a stale
      // archived_at column kept the active filter excluding it) and leave
      // the archived set.
      expect(
        await idsFor(EntityState.active),
        contains('p1'),
        reason:
            'restore must clear archived_at so the active filter '
            '(archived_at IS NULL) includes the row',
      );
      expect(await idsFor(EntityState.archived), isNot(contains('p1')));
    });

    test('watchDistinctCustomValues returns sorted distinct non-empty values '
        'for the given column', () async {
      final repo = makeRepo();
      Future<void> seed(String id, String cv1) => repo.applyUpdateResponse(
        companyId: 'co',
        serverResponse: ProjectApi(
          id: id,
          name: id,
          customValue1: cv1,
          updatedAt: 1700000000,
        ),
      );
      await seed('p1', 'Beta');
      await seed('p2', 'Alpha');
      await seed('p3', 'Beta'); // duplicate — collapsed
      await seed('p4', ''); // empty — excluded
      final values = await repo
          .watchDistinctCustomValues(companyId: 'co', columnIndex: 1)
          .first;
      expect(values, ['Alpha', 'Beta']);
    });
  });

  group('ProjectRepository — deleted-client filter', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });
    tearDown(() async {
      await db.close();
    });

    Future<void> seedProject(String id, String clientId) =>
        ProjectRepository(db: db, api: _FakeProjectsApi()).applyUpdateResponse(
          companyId: 'co',
          serverResponse: ProjectApi(
            id: id,
            name: id,
            clientId: clientId,
            updatedAt: 1700000000,
          ),
        );

    Future<void> seedClient(String id, {required bool deleted}) =>
        ClientRepository(db: db, api: _FakeClientsApi()).applyUpdateResponse(
          companyId: 'co',
          serverResponse: ClientApi(
            id: id,
            name: id,
            isDeleted: deleted,
            updatedAt: 1700000000,
          ),
        );

    test('workspace list hides projects of soft-deleted clients but keeps '
        'active-client and client-less projects', () async {
      await seedProject('p_active', 'c_active');
      await seedProject('p_deleted', 'c_deleted');
      await seedProject('p_noclient', '');
      await seedClient('c_active', deleted: false);
      await seedClient('c_deleted', deleted: true);

      final rows = await ProjectRepository(
        db: db,
        api: _FakeProjectsApi(),
      ).watchPage(companyId: 'co').first;
      final ids = rows.map((p) => p.id).toSet();
      expect(ids, containsAll(<String>['p_active', 'p_noclient']));
      expect(ids, isNot(contains('p_deleted')));
    });

    test("client-scoped watch still shows a soft-deleted client's projects "
        '(detail tabs must not go blank)', () async {
      await seedProject('p1', 'c_deleted');
      await seedClient('c_deleted', deleted: true);

      final rows = await ProjectRepository(
        db: db,
        api: _FakeProjectsApi(),
      ).watchPage(companyId: 'co', clientId: 'c_deleted').first;
      expect(rows.map((p) => p.id), contains('p1'));
    });

    test('watch re-emits without the project when its client is soft-deleted '
        '(reactivity)', () async {
      final repo = ProjectRepository(db: db, api: _FakeProjectsApi());
      await seedProject('p1', 'c1');
      await seedClient('c1', deleted: false);

      final emissions = <Set<String>>[];
      final sub = repo
          .watchPage(companyId: 'co')
          .listen((rows) => emissions.add(rows.map((p) => p.id).toSet()));
      await pumpEventQueue();
      expect(emissions.last, contains('p1'));

      await seedClient('c1', deleted: true);
      await pumpEventQueue();
      expect(
        emissions.last,
        isNot(contains('p1')),
        reason: 'the projects watch must react to a client soft-delete',
      );

      await sub.cancel();
    });
  });
}

class _FakeProjectsApi implements ProjectsApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeClientsApi implements ClientsApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
