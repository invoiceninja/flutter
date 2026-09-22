import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/repositories/user_settings_repository.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/features/quotes/widgets/quote_filter_keys.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins `QuoteClientStatusFilterKey`: writes the computed-status wire values
/// to `vm.extraFilters['client_status']` (the server-backed
/// `QuoteFilters::client_status` param the dashboard Expired/Upcoming quote
/// panels use).

class _FakeVm extends GenericListViewModel<dynamic> {
  _FakeVm({
    required super.companyId,
    required super.navStateDao,
    required super.userSettings,
    super.searchDebounce,
    super.persistDebounce,
  });

  @override
  EntityType get entityType => EntityType.quote;

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

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() async {
    await db.close();
  });

  Future<_FakeVm> makeVm() async {
    final vm = _FakeVm(
      companyId: 'co',
      navStateDao: db.navStateDao,
      userSettings: UserSettingsRepository(db: db),
      searchDebounce: const Duration(milliseconds: 1),
      persistDebounce: const Duration(milliseconds: 1),
    );
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    return vm;
  }

  test('id is "status" and multi-valued', () {
    const key = QuoteClientStatusFilterKey();
    expect(key.id, 'status');
    expect(key.singleValue, isFalse);
    expect(key.checkboxMultiSelect, isTrue);
  });

  testWidgets(
    'status options are exactly the seven server client_status values — '
    '"cancelled" yes (the server branch shipped 2026-09-22), "rejected" no '
    '(QuoteFilters still has no rejected branch)',
    (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        Builder(
          builder: (c) {
            ctx = c;
            return const SizedBox();
          },
        ),
      );
      await tester.runAsync(() async {
        final vm = await makeVm();
        const key = QuoteClientStatusFilterKey();
        final suggestions = await key.watchValueSuggestions(vm, ctx, '').first;
        final rawValues = suggestions.map((s) => s.rawValue).toList();
        expect(rawValues, [
          'draft',
          'sent',
          'approved',
          'expired',
          'upcoming',
          'converted',
          'cancelled',
        ]);
        expect(rawValues, isNot(contains('rejected')));
        vm.dispose();
      });
    },
  );

  test('addValue unions into extraFilters[client_status]', () async {
    final vm = await makeVm();
    const key = QuoteClientStatusFilterKey();

    expect(key.isAtDefault(vm), isTrue);
    await key.addValue(vm, 'expired');
    expect(vm.extraFilters['client_status'], {'expired'});

    await key.addValue(vm, 'upcoming');
    expect(vm.extraFilters['client_status'], {'expired', 'upcoming'});

    await key.removeValue(vm, 'expired');
    expect(vm.extraFilters['client_status'], {'upcoming'});
    expect(key.isAtDefault(vm), isFalse);

    vm.dispose();
  });

  testWidgets('selectExclusive replaces the set in one write', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      Builder(
        builder: (c) {
          ctx = c;
          return const SizedBox();
        },
      ),
    );
    await tester.runAsync(() async {
      final vm = await makeVm();
      const key = QuoteClientStatusFilterKey();

      await key.addValue(vm, 'expired');
      await key.addValue(vm, 'sent');
      expect(vm.extraFilters['client_status'], {'expired', 'sent'});

      await key.selectExclusive(vm, ctx, 'upcoming');
      expect(vm.extraFilters['client_status'], {'upcoming'});

      await key.clear(vm, ctx);
      expect(vm.extraFilters['client_status'] ?? const <String>{}, isEmpty);

      vm.dispose();
    });
  });
}
