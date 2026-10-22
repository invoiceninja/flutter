import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/project_api_model.dart';
import 'package:admin/data/models/api/vendor_api_model.dart';
import 'package:admin/data/repositories/client_repository.dart';
import 'package:admin/data/repositories/ensure_loaded_outcome.dart';
import 'package:admin/data/repositories/expense_category_repository.dart';
import 'package:admin/data/repositories/project_repository.dart';
import 'package:admin/data/repositories/tag_repository.dart';
import 'package:admin/data/repositories/task_status_repository.dart';
import 'package:admin/data/repositories/vendor_repository.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/clients_api.dart';
import 'package:admin/data/services/expense_categories_api.dart';
import 'package:admin/data/services/projects_api.dart';
import 'package:admin/data/services/tags_api.dart';
import 'package:admin/data/services/task_statuses_api.dart';
import 'package:admin/data/services/vendors_api.dart';
import 'package:admin/ui/core/list/search/filter_key.dart';
import 'package:admin/ui/core/list/search/membership_filter_key.dart';
import 'package:admin/ui/core/list/search/record_chip_names.dart';
import 'package:admin/ui/features/expenses/widgets/expense_filter_keys.dart';
import 'package:admin/ui/features/purchase_orders/widgets/purchase_order_filter_keys.dart';
import 'package:admin/ui/features/tasks/task_filter_keys.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// `vendor:` and `project:` chips name their record the way a `client:` chip
/// does: through a live map of every cached record, archived and deleted
/// included, and — for a record the cache has never held — one fetch.

Future<void> _settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('RecordChipNameHydrator', () {
    late List<String> asked;
    late EnsureLoadedOutcome answer;
    late RecordChipNameHydrator names;

    setUp(() {
      asked = [];
      answer = EnsureLoadedOutcome.fetched;
      names = RecordChipNameHydrator((id) async {
        asked.add(id);
        return answer;
      });
    });

    test('a name the lookup has is shown, and nothing is fetched', () async {
      expect(names.resolve('v1', (_) => 'Acme'), 'Acme');
      await _settle();
      expect(asked, isEmpty);
    });

    test('with no lookup the id is shown, and nothing is fetched', () async {
      expect(names.resolve('v1', null), 'v1');
      await _settle();
      expect(asked, isEmpty);
    });

    test(
      'an unknown id is fetched once, however often the chip builds',
      () async {
        expect(names.resolve('v9', (_) => null), 'v9');
        expect(names.resolve('v9', (_) => ''), 'v9');
        await _settle();
        names.resolve('v9', (_) => null);
        await _settle();
        expect(asked, ['v9']);
      },
    );

    test('an unanswered fetch (offline) is not repeated at once', () async {
      answer = EnsureLoadedOutcome.unreachable;
      names.resolve('v9', (_) => null);
      await _settle();
      names.resolve('v9', (_) => null);
      await _settle();
      expect(asked, ['v9']);
    });

    test('a local tmp_ id is never fetched', () async {
      expect(names.resolve('tmp_abc', (_) => null), 'tmp_abc');
      await _settle();
      expect(asked, isEmpty);
    });
  });

  group('the keys', () {
    late AppDatabase db;
    late _VendorsApi vendorsApi;
    late _ProjectsApi projectsApi;
    late VendorRepository vendors;
    late ProjectRepository projects;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      vendorsApi = _VendorsApi();
      projectsApi = _ProjectsApi();
      vendors = VendorRepository(db: db, api: vendorsApi);
      projects = ProjectRepository(db: db, api: projectsApi);
    });
    tearDown(() => db.close());

    MembershipFilterKey keyOf(List<FilterKey> keys, String id) =>
        keys.firstWhere((k) => k.id == id) as MembershipFilterKey;

    test('vendor: on purchase orders fetches an uncached vendor', () async {
      var names = <String, String>{};
      final key = keyOf(
        buildPurchaseOrderFilterKeys(
          clients: ClientRepository(db: db, api: _NoClientsApi()),
          vendors: vendors,
          tags: TagRepository(db: db, api: _NoTagsApi()),
          companyId: 'co',
          nameForVendorId: (id) => names[id],
        ),
        'vendor',
      );
      expect(key.displayValueFor('v9'), 'v9');
      await _settle();
      expect(vendorsApi.gets, ['v9']);
      names = await vendorChipNamesOf(vendors);
      expect(key.displayValueFor('v9'), 'Zed Supplies');
      expect(vendorsApi.gets, ['v9'], reason: 'asked once');
    });

    test('vendor: and project: on expenses fetch uncached records', () async {
      var vendorNames = <String, String>{};
      var projectNames = <String, String>{};
      final keys = buildExpenseFilterKeys(
        clients: ClientRepository(db: db, api: _NoClientsApi()),
        categories: ExpenseCategoryRepository(db: db, api: _NoCategoriesApi()),
        projects: projects,
        vendors: vendors,
        tags: TagRepository(db: db, api: _NoTagsApi()),
        companyId: 'co',
        nameForVendorId: (id) => vendorNames[id],
        nameForProjectId: (id) => projectNames[id],
      );
      final vendor = keyOf(keys, 'vendor');
      final project = keyOf(keys, 'project');
      expect(vendor.displayValueFor('v9'), 'v9');
      expect(project.displayValueFor('p9'), 'p9');
      await _settle();
      expect(vendorsApi.gets, ['v9']);
      expect(projectsApi.gets, ['p9']);
      vendorNames = await vendorChipNamesOf(vendors);
      projectNames = await projectChipNamesOf(projects);
      expect(vendor.displayValueFor('v9'), 'Zed Supplies');
      expect(project.displayValueFor('p9'), 'Zed Rollout');
      for (final k in keys) {
        k.dispose();
      }
    });

    test('project: on tasks fetches an uncached project', () async {
      var names = <String, String>{};
      final keys = buildTaskFilterKeys(
        clients: ClientRepository(db: db, api: _NoClientsApi()),
        projects: projects,
        statuses: TaskStatusRepository(db: db, api: _NoStatusesApi()),
        tags: TagRepository(db: db, api: _NoTagsApi()),
        companyId: 'co',
        nameForProjectId: (id) => names[id],
      );
      final key = keyOf(keys, 'project');
      expect(key.displayValueFor('p9'), 'p9');
      await _settle();
      expect(projectsApi.gets, ['p9']);
      names = await projectChipNamesOf(projects);
      expect(key.displayValueFor('p9'), 'Zed Rollout');
      for (final k in keys) {
        k.dispose();
      }
    });

    test('an archived or deleted vendor / project still names its chip, '
        'while the suggestions stay active-only', () async {
      await vendors.applyUpdateResponse(
        companyId: 'co',
        serverResponse: VendorApi.fromJson({
          'id': 'v_arch',
          'name': 'Archived Supplies',
          'archived_at': 1700000000,
          'updated_at': 1700000000,
        }),
      );
      await projects.applyUpdateResponse(
        companyId: 'co',
        serverResponse: ProjectApi.fromJson({
          'id': 'p_del',
          'name': 'Deleted Rollout',
          'is_deleted': true,
          'archived_at': 1700000000,
          'updated_at': 1700000000,
        }),
      );
      expect(await vendors.watchActiveNames(companyId: 'co').first, isEmpty);
      expect(await projects.watchActiveNames(companyId: 'co').first, isEmpty);
      expect(await vendorChipNamesOf(vendors), {'v_arch': 'Archived Supplies'});
      expect(await projectChipNamesOf(projects), {'p_del': 'Deleted Rollout'});
    });
  });
}

/// The same map `vendorChipNames` / `projectChipNames` build, read once
/// (they take `Services`, which a data-level test does not build).
Future<Map<String, String>> vendorChipNamesOf(VendorRepository repo) async => {
  for (final r in await repo.watchAllNames(companyId: 'co').first) r.id: r.name,
};

Future<Map<String, String>> projectChipNamesOf(
  ProjectRepository repo,
) async => {
  for (final r in await repo.watchAllNames(companyId: 'co').first) r.id: r.name,
};

class _VendorsApi implements VendorsApi {
  final gets = <String>[];

  @override
  Future<VendorItemApi> get(String id) async {
    gets.add(id);
    return VendorItemApi(
      data: VendorApi(id: id, name: 'Zed Supplies'),
    );
  }

  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected API call: ${invocation.memberName}');
}

class _ProjectsApi implements ProjectsApi {
  final gets = <String>[];

  @override
  Future<ProjectItemApi> get(String id) async {
    gets.add(id);
    return ProjectItemApi(
      data: ProjectApi(id: id, name: 'Zed Rollout'),
    );
  }

  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected API call: ${invocation.memberName}');
}

class _NoClientsApi implements ClientsApi {
  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw const NetworkException('offline');
}

class _NoTagsApi implements TagsApi {
  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw const NetworkException('offline');
}

class _NoCategoriesApi implements ExpenseCategoriesApi {
  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw const NetworkException('offline');
}

class _NoStatusesApi implements TaskStatusesApi {
  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw const NetworkException('offline');
}
