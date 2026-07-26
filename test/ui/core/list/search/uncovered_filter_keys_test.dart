import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/company_api_model.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/repositories/client_repository.dart';
import 'package:admin/data/repositories/expense_category_repository.dart';
import 'package:admin/data/repositories/project_repository.dart';
import 'package:admin/data/repositories/statics_repository.dart';
import 'package:admin/data/repositories/tag_repository.dart';
import 'package:admin/data/repositories/user_settings_repository.dart';
import 'package:admin/data/repositories/vendor_repository.dart';
import 'package:admin/data/services/clients_api.dart';
import 'package:admin/data/services/expense_categories_api.dart';
import 'package:admin/data/services/projects_api.dart';
import 'package:admin/data/services/statics_service.dart';
import 'package:admin/data/services/tags_api.dart';
import 'package:admin/data/services/vendors_api.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/core/list/search/filter_key.dart';
import 'package:admin/ui/core/list/search/tag_filter_key.dart';
import 'package:admin/ui/features/expense_categories/widgets/expense_category_filter_keys.dart';
import 'package:admin/ui/features/expenses/widgets/expense_filter_keys.dart';
import 'package:admin/ui/features/gateways/gateway_filter_keys.dart';
import 'package:admin/ui/features/payment_links/widgets/payment_link_filter_keys.dart';
import 'package:admin/ui/features/projects/project_filter_keys.dart';
import 'package:admin/ui/features/recurring_expenses/widgets/recurring_expense_filter_keys.dart';
import 'package:admin/ui/features/recurring_invoices/widgets/recurring_invoice_filter_keys.dart';
import 'package:admin/ui/features/transactions/widgets/transaction_filter_keys.dart';
import 'package:admin/ui/features/vendors/widgets/vendor_filter_keys.dart';

/// Covers the nine `*_filter_keys.dart` modules that had no test — expense,
/// expense_category, gateway, payment_link, project, recurring_expense,
/// recurring_invoice, transaction and vendor. Client / invoice / quote /
/// credit / payment / task already had one each.
///
/// Two things are checked, both aimed at the same failure mode — **a filter
/// chip that silently does nothing**:
///   1. *Composition* — each builder actually returns the keys its screen
///      registers, every key id is unique (a duplicate makes one unreachable),
///      and every `TagFilterKey` carries the right `entityType` (the wrong one
///      queries another entity's tags and always comes back empty).
///   2. *Round-trip* — for the four entity-specific key classes among them, an
///      `addValue` / `removeValue` cycle lands on the documented server param.
///
/// Grouped in one file rather than nine because the `GenericListViewModel`
/// harness is the bulk of the code and is identical for all of them.
class _FakeVm extends GenericListViewModel<dynamic> {
  _FakeVm({
    required super.companyId,
    required super.navStateDao,
    required super.userSettings,
    super.searchDebounce,
    super.persistDebounce,
  });

  @override
  EntityType get entityType => EntityType.expense;

  @override
  List<ColumnDefinition<dynamic>> get allColumns => const [];

  @override
  List<String> get defaultColumnIds => const [];

  @override
  String get defaultSortField => 'number';

  @override
  bool isValidColumnId(String field) => true;

  @override
  String idOf(dynamic item) => '';

  @override
  bool isArchived(dynamic item) => false;

  @override
  bool isDeleted(dynamic item) => false;

  @override
  Stream<List<dynamic>> watchPage() => const Stream.empty();

  @override
  Future<bool> fetchPage({
    required int page,
    required String? search,
    required Set<EntityState> states,
    required Map<String, Set<String>> extraFilters,
    required bool ignoreCursor,
  }) async => false;

  @override
  Future<void> refreshAll() async {}

  @override
  Iterable<BulkAction<dynamic>> get bulkActions => const [];
}

class _FakeClientsApi implements ClientsApi {
  @override
  Object? noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _FakeTagsApi implements TagsApi {
  @override
  Object? noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _FakeProjectsApi implements ProjectsApi {
  @override
  Object? noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _FakeVendorsApi implements VendorsApi {
  @override
  Object? noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _FakeExpenseCategoriesApi implements ExpenseCategoriesApi {
  @override
  Object? noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _FakeStaticsService implements StaticsService {
  @override
  Object? noSuchMethod(Invocation i) => throw UnimplementedError();
}

void main() {
  late AppDatabase db;
  late ClientRepository clients;
  late TagRepository tags;
  late ProjectRepository projects;
  late VendorRepository vendors;
  late ExpenseCategoryRepository categories;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    clients = ClientRepository(db: db, api: _FakeClientsApi());
    tags = TagRepository(db: db, api: _FakeTagsApi());
    projects = ProjectRepository(db: db, api: _FakeProjectsApi());
    vendors = VendorRepository(db: db, api: _FakeVendorsApi());
    categories = ExpenseCategoryRepository(
      db: db,
      api: _FakeExpenseCategoriesApi(),
    );
  });
  tearDown(() async => db.close());

  Future<_FakeVm> makeVm() async {
    final vm = _FakeVm(
      companyId: 'co',
      navStateDao: db.navStateDao,
      userSettings: UserSettingsRepository(db: db),
      searchDebounce: const Duration(milliseconds: 1),
      persistDebounce: const Duration(milliseconds: 1),
    );
    // Disposed via tearDown rather than at the end of each test body: a failing
    // `expect` would otherwise skip the dispose, leaving the VM's nav-state and
    // column Drift subscriptions live against a DB that tearDown then closes —
    // surfacing as an unhandled async error inside some *other* test.
    addTearDown(vm.dispose);
    // Let the VM's async `_init()` settle. `_hydrate()` early-returns on a
    // fresh DB (no persisted nav state), so nothing can write back over the
    // filters these tests set afterwards.
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    return vm;
  }

  Company companyWithLabels() =>
      Company.fromApi(const CompanyApi(id: 'co', name: 'Acme'));

  /// Every builder, keyed by the name a failure should name.
  Map<String, List<FilterKey>> allBuilders() => {
    'expense': buildExpenseFilterKeys(
      clients: clients,
      categories: categories,
      projects: projects,
      vendors: vendors,
      tags: tags,
      companyId: 'co',
    ),
    'expense_category': buildExpenseCategoryFilterKeys(),
    'gateway': buildCompanyGatewayFilterKeys(),
    'payment_link': buildPaymentLinkFilterKeys(),
    'project': buildProjectFilterKeys(
      clients: clients,
      tags: tags,
      companyId: 'co',
      company: companyWithLabels(),
    ),
    'recurring_expense': buildRecurringExpenseFilterKeys(
      tags: tags,
      companyId: 'co',
      company: companyWithLabels(),
    ),
    'recurring_invoice': buildRecurringInvoiceFilterKeys(
      clients: clients,
      tags: tags,
      companyId: 'co',
      company: companyWithLabels(),
    ),
    'transaction': buildTransactionFilterKeys(tags: tags, companyId: 'co'),
    'vendor': buildVendorFilterKeys(
      company: companyWithLabels(),
      // Only feeds suggestion lists for membership keys, none of which the
      // vendor builder wires yet — so it is never read here.
      statics: StaticsRepository(db: db, service: _FakeStaticsService()),
      tags: tags,
      companyId: 'co',
    ),
  };

  group('composition', () {
    test('every builder returns at least the universal is: key', () {
      allBuilders().forEach((name, keys) {
        expect(
          keys.map((k) => k.id),
          contains('is'),
          reason: '$name dropped IsFilterKey — the archived/deleted chip dies',
        );
      });
    });

    test('no builder emits a duplicate key id', () {
      allBuilders().forEach((name, keys) {
        final ids = keys.map((k) => k.id).toList();
        expect(
          ids.length,
          ids.toSet().length,
          reason: '$name has a duplicate id — one of the chips is unreachable',
        );
      });
    });

    test('tag keys carry their own entity type', () {
      const expected = {
        'expense': 'expense',
        'project': 'project',
        'recurring_expense': 'recurring_expense',
        'recurring_invoice': 'recurring_invoice',
        // The bank_transaction wire name, not "transaction".
        'transaction': 'bank_transaction',
        'vendor': 'vendor',
      };

      allBuilders().forEach((name, keys) {
        final tagKeys = keys.whereType<TagFilterKey>();
        if (!expected.containsKey(name)) {
          expect(tagKeys, isEmpty, reason: '$name gained an untracked tag key');
          return;
        }
        expect(tagKeys, hasLength(1), reason: '$name should register one');
        expect(
          tagKeys.single.entityType,
          expected[name],
          reason:
              'a mismatched entityType queries another entity\'s tags, so the '
              '$name tag chip always comes back empty',
        );
      });
    });

    test('the settings-style lists stay minimal (is: only)', () {
      for (final keys in [
        buildExpenseCategoryFilterKeys(),
        buildCompanyGatewayFilterKeys(),
        buildPaymentLinkFilterKeys(),
      ]) {
        expect(keys.map((k) => k.id), ['is']);
      }
    });

    test('expense registers its four entity-specific keys', () {
      final keys = allBuilders()['expense']!;

      expect(
        keys.map((k) => k.id).toSet(),
        containsAll(<String>['is', 'tag', 'client']),
      );
      expect(keys.whereType<ExpenseStatusFilterKey>(), hasLength(1));
      expect(keys.whereType<ExpenseCategoryFilterKey>(), hasLength(1));
      expect(keys.whereType<ExpenseProjectFilterKey>(), hasLength(1));
      expect(keys.whereType<ExpenseVendorFilterKey>(), hasLength(1));
    });

    test('transaction registers both status and type', () {
      final keys = allBuilders()['transaction']!;

      expect(keys.whereType<TransactionStatusFilterKey>(), hasLength(1));
      expect(keys.whereType<TransactionTypeFilterKey>(), hasLength(1));
    });

    test('recurring_invoice registers its status key', () {
      expect(
        allBuilders()['recurring_invoice']!
            .whereType<RecurringInvoiceStatusFilterKey>(),
        hasLength(1),
      );
    });
  });

  group('TransactionStatusFilterKey — multi-select onto status_id', () {
    test('shape', () {
      const key = TransactionStatusFilterKey();

      expect(key.id, 'status');
      expect(key.singleValue, isFalse);
      expect(key.checkboxMultiSelect, isTrue);
    });

    test('add / remove round-trips through extraFilters[status_id]', () async {
      final vm = await makeVm();
      const key = TransactionStatusFilterKey();

      expect(key.isAtDefault(vm), isTrue);

      await key.addValue(vm, '1');
      expect(vm.extraFilters['status_id'], {'1'});
      expect(key.isAtDefault(vm), isFalse);

      await key.addValue(vm, '2');
      expect(vm.extraFilters['status_id'], {'1', '2'});

      await key.removeValue(vm, '1');
      expect(vm.extraFilters['status_id'], {'2'});

      await key.removeValue(vm, '2');
      expect(key.isAtDefault(vm), isTrue);
    });
  });

  group('TransactionTypeFilterKey — single-select onto base_type', () {
    test('shape', () {
      const key = TransactionTypeFilterKey();

      expect(key.id, 'type');
      expect(
        key.singleValue,
        isTrue,
        reason: 'a transaction is either a deposit or a withdrawal',
      );
    });

    test('writes to base_type, not status_id', () async {
      final vm = await makeVm();
      const key = TransactionTypeFilterKey();

      await key.addValue(vm, 'CREDIT');

      expect(vm.extraFilters['base_type'], {'CREDIT'});
      expect(vm.extraFilters['status_id'], anyOf(isNull, isEmpty));
    });
  });

  group('RecurringInvoiceStatusFilterKey — multi-select onto status_id', () {
    test('shape', () {
      const key = RecurringInvoiceStatusFilterKey();

      expect(key.id, 'status');
      expect(key.singleValue, isFalse);
      expect(key.checkboxMultiSelect, isTrue);
    });

    test('add / remove round-trips', () async {
      final vm = await makeVm();
      const key = RecurringInvoiceStatusFilterKey();

      await key.addValue(vm, '2');
      await key.addValue(vm, '3');
      expect(vm.extraFilters['status_id'], {'2', '3'});

      await key.removeValue(vm, '2');
      expect(vm.extraFilters['status_id'], {'3'});
    });
  });

  group('ExpenseStatusFilterKey', () {
    test('is multi-select', () {
      const key = ExpenseStatusFilterKey();

      expect(key.singleValue, isFalse);
    });

    test('writes to client_status, NOT status_id', () async {
      final vm = await makeVm();
      const key = ExpenseStatusFilterKey();

      await key.addValue(vm, 'paid');

      expect(
        vm.extraFilters['client_status'],
        {'paid'},
        reason:
            'expenses filter on client_status while transactions and '
            'recurring invoices use status_id — pinning the exact param is '
            'the whole point of this test, since a wrong key silently '
            'produces a chip that filters nothing',
      );
      expect(vm.extraFilters['status_id'], anyOf(isNull, isEmpty));
    });

    test('add / remove round-trips', () async {
      final vm = await makeVm();
      const key = ExpenseStatusFilterKey();

      expect(key.isAtDefault(vm), isTrue);

      await key.addValue(vm, 'paid');
      await key.addValue(vm, 'pending');
      expect(vm.extraFilters['client_status'], {'paid', 'pending'});
      expect(key.isAtDefault(vm), isFalse);

      await key.removeValue(vm, 'paid');
      expect(vm.extraFilters['client_status'], {'pending'});

      await key.removeValue(vm, 'pending');
      expect(key.isAtDefault(vm), isTrue);
    });
  });
}
