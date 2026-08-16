import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/repositories/user_settings_repository.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/core/list/search/date_column_filter_key.dart';
import 'package:admin/ui/core/list/search/filter_key.dart';
import 'package:admin/ui/features/payments/widgets/payment_filter_keys.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins `PaymentStatusFilterKey` (`client_status`) and the generic
/// `DateColumnFilterKey(id: 'date')` `between` comparator that replaced the
/// old `PaymentDateRangeFilterKey` — it owns the canonical 3-part
/// `date,<start>,<end>` `date_range` wire the "Paid" KPI deep-link injects
/// (legacy 2-part still parses).

class _FakeVm extends GenericListViewModel<dynamic> {
  _FakeVm({
    required super.companyId,
    required super.navStateDao,
    required super.userSettings,
    super.searchDebounce,
    super.persistDebounce,
  });

  @override
  EntityType get entityType => EntityType.payment;

  @override
  List<ColumnDefinition<dynamic>> get allColumns => const [];

  @override
  List<String> get defaultColumnIds => const [];

  @override
  String get defaultSortField => 'date';

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

  group('PaymentStatusFilterKey', () {
    test('writes to extraFilters[client_status]', () async {
      final vm = await makeVm();
      const key = PaymentStatusFilterKey();

      expect(key.isAtDefault(vm), isTrue);
      await key.addValue(vm, 'completed');
      expect(vm.extraFilters['client_status'], {'completed'});

      await key.addValue(vm, 'refunded');
      expect(vm.extraFilters['client_status'], {'completed', 'refunded'});
      expect(key.isAtDefault(vm), isFalse);

      vm.dispose();
    });
  });

  // The payments list now uses the generic `DateColumnFilterKey(id: 'date')`
  // for date filtering — its `between` comparator owns the `date_range`
  // window slot the "Paid" KPI deep-link injects, replacing the old bespoke
  // `PaymentDateRangeFilterKey`.
  group('DateColumnFilterKey (date) — between window', () {
    const key = DateColumnFilterKey(
      id: 'date',
      serverKey: 'date',
      labelKey: 'date',
    );

    test('exposes between alongside the single-date comparators', () {
      expect(key.supportedOps, contains(FilterOp.between));
      expect(key.rangeServerKey, 'date_range');
    });

    test('isValidValue accepts canonical 3-part / legacy 2-part windows; '
        'rejects empty bounds', () {
      expect(key.isValidValue('date,2026-05-01,2026-05-31'), isTrue);
      expect(key.isValidValue('2026-05-01,2026-05-31'), isTrue);
      expect(key.isValidValue('between:2026-05-01,2026-05-31'), isTrue);
      expect(key.isValidValue('custom,,'), isFalse);
      // A single-date comparable value stays valid (comparable slot).
      expect(key.isValidValue('gte:2026-05-01'), isTrue);
    });

    test(
      'addValue routes a window to extraFilters[date_range] as the '
      'canonical date,<start>,<end> wire and clears the comparable slot',
      () async {
        final vm = await makeVm();

        // Seed a single-date comparable filter first.
        await key.addValue(vm, 'gte:2026-01-01');
        expect(vm.extraFilters['date'], {'gte:2026-01-01'});

        // Legacy 2-part window normalizes to canonical 3-part in the
        // date_range slot, and the comparable slot is cleared (mutually
        // exclusive within the key).
        await key.addValue(vm, '2026-05-01,2026-05-31');
        expect(vm.extraFilters['date_range'], {'date,2026-05-01,2026-05-31'});
        expect(vm.extraFilters['date'] ?? const <String>{}, isEmpty);

        // The between: prefix and a non-date column prefix both normalize.
        await key.addValue(vm, 'between:2026-06-01,2026-06-30');
        expect(vm.extraFilters['date_range'], {'date,2026-06-01,2026-06-30'});

        await key.removeValue(vm, 'date,2026-06-01,2026-06-30');
        expect(vm.extraFilters['date_range'] ?? const <String>{}, isEmpty);
        expect(key.isAtDefault(vm), isTrue);

        vm.dispose();
      },
    );

    test('switching back to a single-date op seeds from the window start '
        'and clears the range slot', () async {
      final vm = await makeVm();

      await key.addValue(vm, 'date,2026-05-01,2026-05-31');
      await key.changeOp(vm, 'date,2026-05-01,2026-05-31', FilterOp.gte);
      expect(vm.extraFilters['date_range'] ?? const <String>{}, isEmpty);
      expect(vm.extraFilters['date'], {'gte:2026-05-01'});

      vm.dispose();
    });

    testWidgets('the window renders as one chip; clear drops both slots', (
      tester,
    ) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.runAsync(() async {
        final vm = await makeVm();

        await key.addValue(vm, 'this_month,2026-05-01,2026-05-31');
        final tokens = key.tokensFrom(vm, ctx).toList();
        expect(tokens, hasLength(1));
        expect(tokens.single.displayValue, '2026-05-01 – 2026-05-31');
        expect(tokens.single.rawValue, 'date,2026-05-01,2026-05-31');

        await key.clear(vm, ctx);
        expect(vm.extraFilters['date_range'] ?? const <String>{}, isEmpty);
        expect(vm.extraFilters['date'] ?? const <String>{}, isEmpty);

        vm.dispose();
      });
    });

    // Regression for FU-1: the suggestion-menu between row commits via the
    // exclusive (replace-not-toggle) path, so re-picking the *identical*
    // window must keep it applied — not clear it. `selectExclusive` is the
    // dispatch that path lands on.
    testWidgets('re-applying the identical window via selectExclusive '
        'keeps it (no toggle-off)', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.runAsync(() async {
        final vm = await makeVm();

        await key.selectExclusive(vm, ctx, 'date,2026-05-01,2026-05-31');
        expect(vm.extraFilters['date_range'], {'date,2026-05-01,2026-05-31'});

        // Same window again — stays applied (would clear under the
        // applied-match toggle that onSelectValue uses).
        await key.selectExclusive(vm, ctx, 'date,2026-05-01,2026-05-31');
        expect(vm.extraFilters['date_range'], {'date,2026-05-01,2026-05-31'});

        vm.dispose();
      });
    });
  });
}
