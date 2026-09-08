import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/repositories/user_settings_repository.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/core/list/search/date_column_filter_key.dart';
import 'package:admin/ui/core/list/search/filter_key.dart';
import 'package:admin/ui/core/list/search/filter_suggestion_menu.dart';
import 'package:admin/ui/core/list/search/token_search_controller.dart';
import 'package:admin/ui/features/products/stock_filter_key.dart';
import 'package:admin/ui/features/clients/client_filter_keys.dart';
import 'package:admin/ui/features/invoices/widgets/invoice_filter_keys.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../_localization_helper.dart';

/// Pins the checkbox / split-action contract for the state (`is`) filter:
/// it opts in to the checkbox picker and `selectExclusive` collapses the
/// applied set to a single state in one `setStates` write.
///
/// Also pins invoiceninja/flutter#126: the lifecycle dimension is never empty
/// (clearing lands on `{active}`, so deleted rows are opt-in only), and a key
/// sitting at its default renders no chip — while still reporting itself as
/// applied to the value picker, which is the half no other test would catch.

class _FakeVm extends GenericListViewModel<dynamic> {
  _FakeVm({
    required super.companyId,
    required super.navStateDao,
    required super.userSettings,
    super.searchDebounce,
    super.persistDebounce,
  });

  @override
  EntityType get entityType => EntityType.client;

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

  test('IsFilterKey opts in to the checkbox multi-select picker', () {
    expect(const IsFilterKey().checkboxMultiSelect, isTrue);
  });

  test('a non-opt-in key keeps the default toggle-and-close picker', () {
    expect(const NameFilterKey().checkboxMultiSelect, isFalse);
  });

  testWidgets(
    'selectExclusive collapses {active, archived} to {deleted} in one write',
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

      // Run the VM work in the real async zone: `makeVm`'s delayed loop and
      // the VM's debounced persist timer don't advance under the widget
      // binding's fake clock. `selectExclusive`'s override ignores [ctx].
      await tester.runAsync(() async {
        final vm = await makeVm();
        const key = IsFilterKey();

        await key.addValue(vm, EntityState.archived.serverName);
        expect(
          vm.states,
          containsAll(<EntityState>[EntityState.active, EntityState.archived]),
        );

        await key.selectExclusive(vm, ctx, EntityState.deleted.serverName);
        expect(vm.states, {EntityState.deleted});

        vm.dispose();
      });
    },
  );

  testWidgets('clear returns the dimension to {active}, never empty', (
    tester,
  ) async {
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
      const key = IsFilterKey();

      await key.addValue(vm, EntityState.archived.serverName);
      expect(
        vm.states,
        containsAll(<EntityState>[EntityState.active, EntityState.archived]),
      );

      await key.clear(vm, ctx);
      expect(
        vm.states,
        {EntityState.active},
        reason:
            'an empty set meant "show everything, deleted included" while '
            'rendering no chip and hiding the clear-filters button (#126)',
      );

      // Same for the last individual value, whichever it is.
      await key.selectExclusive(vm, ctx, EntityState.deleted.serverName);
      expect(vm.states, {EntityState.deleted});
      await key.removeValue(vm, EntityState.deleted.serverName);
      expect(vm.states, {EntityState.active});

      vm.dispose();
    });
  });

  testWidgets('activeChips collapses multi-value checkbox keys into one chip', (
    tester,
  ) async {
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
      final controller = TokenSearchController(
        vm: vm,
        filterKeys: const [IsFilterKey()],
        initialText: '',
      );
      addTearDown(controller.dispose);

      // Fresh VM: states == {active} is the DEFAULT, so no chip renders —
      // its `×` could only reset the dimension to the value it already holds
      // (#126). The picker still sees it as applied; asserted below.
      expect(controller.activeChips(ctx), isEmpty);
      expect(
        const IsFilterKey().tokensFrom(vm, ctx),
        hasLength(1),
        reason: 'the value picker resolves its ticked rows from tokensFrom',
      );

      // A non-default single state does render one non-aggregate chip.
      await vm.setStates({EntityState.archived});
      var chips = controller.activeChips(ctx);
      expect(chips, hasLength(1));
      expect(chips.single.aggregate, isFalse);

      // Three states → one aggregate chip listing all three, sorted.
      await vm.setStates({
        EntityState.active,
        EntityState.archived,
        EntityState.deleted,
      });
      chips = controller.activeChips(ctx);
      expect(chips, hasLength(1));
      final chip = chips.single;
      expect(chip.aggregate, isTrue);
      expect(chip.rawValues, hasLength(3));
      expect(chip.token.displayValue.split(', '), hasLength(3));
      final parts = chip.token.displayValue.split(', ');
      final sorted = [...parts]..sort();
      expect(parts, sorted, reason: 'chip values must be deterministic');

      // Removing the aggregate chip returns to the default — and the chip
      // goes with it, so the `×` is never a dead affordance.
      await controller.removeChip(chip, ctx);
      expect(vm.states, {EntityState.active});
      expect(controller.activeChips(ctx), isEmpty);

      vm.dispose();
    });
  });

  testWidgets(
    'a key at its default emits no token — IsFilterKey is the sole exception',
    (tester) async {
      // The invariant `TokenSearchController._hidesChips` rests on: skipping a
      // key that reports `isAtDefault` can only ever drop a chip that would
      // have been empty anyway. One key per shape class, including the one
      // whose `isAtDefault` is NOT "the values set is empty"
      // (`InvoiceOverdueFilterKey`, which early-returns inside its own
      // `tokensFrom` instead). Break that alignment in a new key and it would
      // silently stop rendering a chip the user applied.
      const keys = <FilterKey>[
        NameFilterKey(),
        BalanceFilterKey(),
        InvoiceStatusFilterKey(),
        InvoiceOverdueFilterKey(),
        StockFilterKey(),
        DateColumnFilterKey(id: 'date', serverKey: 'date', labelKey: 'date'),
        CustomFieldFilterKey(columnIndex: 1, configuredLabel: 'Region'),
      ];

      late BuildContext ctx;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          home: Builder(
            builder: (c) {
              ctx = c;
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        final vm = await makeVm();

        for (final k in keys) {
          expect(k.isAtDefault(vm), isTrue, reason: '${k.id} on a fresh VM');
          expect(
            k.tokensFrom(vm, ctx),
            isEmpty,
            reason: '${k.id} is at its default but still emitted a token',
          );
        }

        // The exception, stated explicitly so it can't be "tidied" away: the
        // lifecycle key reports applied-at-default on purpose, because the
        // value picker reads its ticked rows from `tokensFrom`.
        const isKey = IsFilterKey();
        expect(isKey.isAtDefault(vm), isTrue);
        expect(isKey.tokensFrom(vm, ctx), hasLength(1));

        vm.dispose();
      });
    },
  );

  testWidgets('a key that is NOT at its default still renders its chip', (
    tester,
  ) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Builder(
          builder: (c) {
            ctx = c;
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      final vm = await makeVm();
      final controller = TokenSearchController(
        vm: vm,
        filterKeys: const [IsFilterKey(), InvoiceOverdueFilterKey()],
        initialText: '',
      );
      addTearDown(controller.dispose);

      // The boolean-shaped key: `isAtDefault` is "the set doesn't contain
      // `true`", not "the set is empty", so it is the one the guard could
      // plausibly get wrong.
      expect(controller.activeChips(ctx), isEmpty);
      await const InvoiceOverdueFilterKey().addValue(vm, 'true');
      final chips = controller.activeChips(ctx);
      expect(chips, hasLength(1));
      expect(chips.single.key, isA<InvoiceOverdueFilterKey>());
      expect(controller.activeTokens(ctx), hasLength(1));

      vm.dispose();
    });
  });

  test('aliased `state`, not `status` (no clash with entity Status key)', () {
    const key = IsFilterKey();
    expect(key.id, 'is');
    expect(key.aliases, const ['state']);
    expect(key.aliases, isNot(contains('status')));
  });

  test('typed `status:` resolves to the entity Status key, not the '
      'lifecycle key', () {
    const keys = <FilterKey>[IsFilterKey(), InvoiceStatusFilterKey()];

    // `status:` must hit the per-entity Status key (registered second) —
    // before the alias fix `IsFilterKey` shadowed it.
    expect(
      FilterInputParse.of('status:paid', keys).matchedKey,
      isA<InvoiceStatusFilterKey>(),
    );
    // The lifecycle key is still reachable via `state:` and `is:`.
    expect(
      FilterInputParse.of('state:archived', keys).matchedKey,
      isA<IsFilterKey>(),
    );
    expect(
      FilterInputParse.of('is:archived', keys).matchedKey,
      isA<IsFilterKey>(),
    );
  });

  testWidgets('displayLabel resolves to "State"', (tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Builder(
          builder: (context) {
            ctx = context;
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(const IsFilterKey().displayLabel(ctx), 'State');
  });

  testWidgets(
    'pinnedValueKey owns the menu; bare text is the key value, dropped only by ":" or clear',
    (tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        final vm = await makeVm();
        final controller = TokenSearchController(
          vm: vm,
          filterKeys: const [IsFilterKey()],
          initialText: '',
        );
        addTearDown(controller.dispose);

        // No pin, empty text → key mode.
        expect(controller.parseInput().matchedKey, isNull);

        // Pin → value mode for that key, query empty, NO text written.
        // pinRevision must bump so the host rebuilds the menu.
        final rev0 = controller.pinRevision.value;
        controller.pinValueKey(const IsFilterKey());
        expect(controller.pinRevision.value, greaterThan(rev0));
        expect(controller.text.text, isEmpty);
        var parse = controller.parseInput();
        expect(parse.matchedKey, isA<IsFilterKey>());
        expect(parse.query, isEmpty);

        // A pinned key OWNS the menu: bare text (no `:`) is that key's
        // VALUE query, not a new key/free-text parse. The pin is dropped
        // only by an explicit `:` (handled in the field's _onTextChange,
        // not the controller) or clearPinnedValueKey() — never by plain
        // typing.
        controller.text.text = 'acme';
        parse = controller.parseInput();
        expect(parse.matchedKey, isA<IsFilterKey>());
        expect(parse.query, 'acme');

        // Clearing the text keeps the pin in effect; query back to empty.
        controller.text.clear();
        parse = controller.parseInput();
        expect(parse.matchedKey, isA<IsFilterKey>());
        expect(parse.query, isEmpty);

        final rev1 = controller.pinRevision.value;
        controller.clearPinnedValueKey();
        expect(controller.parseInput().matchedKey, isNull);
        expect(controller.pinRevision.value, greaterThan(rev1));

        vm.dispose();
      });
    },
  );

  testWidgets('Backspace on a pinned empty input clears the pin, not a chip', (
    tester,
  ) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Builder(
          builder: (c) {
            ctx = c;
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      final vm = await makeVm();
      final controller = TokenSearchController(
        vm: vm,
        filterKeys: const [IsFilterKey()],
        initialText: '',
      );
      addTearDown(controller.dispose);

      final backspace = KeyDownEvent(
        physicalKey: PhysicalKeyboardKey.backspace,
        logicalKey: LogicalKeyboardKey.backspace,
        timeStamp: Duration.zero,
      );

      // Pinned + empty input → Backspace returns to the key list
      // (clears the pin) and leaves the applied state set untouched.
      controller.pinValueKey(const IsFilterKey());
      final statesBefore = {...vm.states};
      final handled = controller.handleArrowEnterBackspace(
        backspace,
        suggestionsActive: false,
        context: ctx,
      );
      expect(handled, KeyEventResult.handled);
      expect(controller.pinnedValueKey, isNull);
      expect(vm.states, statesBefore, reason: 'no chip removed');

      // No pin + empty input + a chip present → Backspace removes the
      // last chip (unchanged behavior). Seed a NON-default state: at the
      // default there is no chip to remove.
      await vm.setStates({EntityState.archived});
      expect(controller.activeChips(ctx), hasLength(1));
      expect(
        controller.handleArrowEnterBackspace(
          backspace,
          suggestionsActive: false,
          context: ctx,
        ),
        KeyEventResult.handled,
      );
      await Future<void>.delayed(Duration.zero);
      expect(vm.states, {EntityState.active});

      // Back at the default there is nothing left to remove: Backspace must
      // fall through rather than "removing" an invisible chip — which would
      // also announce a phantom removal to screen readers.
      expect(
        controller.handleArrowEnterBackspace(
          backspace,
          suggestionsActive: false,
          context: ctx,
        ),
        KeyEventResult.ignored,
      );
      expect(vm.states, {EntityState.active});

      vm.dispose();
    });
  });
}
