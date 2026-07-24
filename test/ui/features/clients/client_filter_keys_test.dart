import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/value/country.dart';
import 'package:admin/data/models/value/currency.dart';
import 'package:admin/data/models/value/industry.dart';
import 'package:admin/data/models/value/language.dart';
import 'package:admin/data/models/value/size.dart';
import 'package:decimal/decimal.dart';
import 'package:admin/data/repositories/group_setting_repository.dart';
import 'package:admin/data/repositories/tag_repository.dart';
import 'package:admin/data/services/tags_api.dart';
import 'package:admin/data/repositories/user_repository.dart';
import 'package:admin/data/repositories/user_settings_repository.dart';
import 'package:admin/data/services/group_settings_api.dart';
import 'package:admin/data/services/statics_service.dart';
import 'package:admin/data/services/users_api.dart';
import 'package:admin/data/repositories/statics_repository.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/core/list/search/date_column_filter_key.dart';
import 'package:admin/ui/core/list/search/filter_key.dart';
import 'package:admin/ui/core/list/search/filter_token.dart';
import 'package:admin/ui/core/list/search/token_search_controller.dart';
import 'package:admin/ui/features/clients/client_filter_keys.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../_localization_helper.dart';

// The clients list registers its `created` / `updated` date filters as the
// shared `DateColumnFilterKey` (the operator menu includes `between`, which
// writes a window to `created_at_range` / `updated_at_range`).
const _createdKey = DateColumnFilterKey(
  id: 'created',
  serverKey: 'created_at',
  labelKey: 'created',
);
const _updatedKey = DateColumnFilterKey(
  id: 'updated',
  serverKey: 'updated_at',
  labelKey: 'updated',
);

/// Verifies the four built-in client filter keys round-trip values through
/// the VM and produce the right chip/suggestion data. We bring up a real
/// `GenericListViewModel` against an in-memory Drift database; mocking the
/// VM would just re-create its base, which is where the writes land.

/// Bare-minimum VM stand-in so we don't need to spin up the full Clients
/// stack just to exercise filter-key state.
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
  String get defaultSortField => 'name';

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
  Stream<List<String>> watchDistinctCustomValues(int columnIndex) =>
      Stream.value(const ['North', 'South', 'East']);

  /// Synchronous override so widget tests can exercise
  /// `CustomFieldFilterKey.quickValueSuggestions` without waiting for the
  /// base VM's stream-subscription cache to populate (the subscription
  /// uses `Stream.value`, which fires asynchronously on the microtask
  /// queue — `testWidgets`'s fake clock doesn't drain that reliably).
  @override
  List<String> distinctCustomValues(int columnIndex) => const [
    'North',
    'South',
    'East',
  ];

  @override
  Iterable<BulkAction<dynamic>> get bulkActions => const [];
}

class _FakeStaticsRepository extends StaticsRepository {
  _FakeStaticsRepository({
    required super.db,
    required super.service,
    Map<String, Country>? countries,
    Map<String, Industry>? industries,
    Map<String, Size>? sizes,
    Map<String, Currency>? currencies,
    Map<String, Language>? languages,
  }) : _countries = countries ?? const {},
       _industries = industries ?? const {},
       _sizes = sizes ?? const {},
       _currencies = currencies ?? const {},
       _languages = languages ?? const {};

  final Map<String, Country> _countries;
  final Map<String, Industry> _industries;
  final Map<String, Size> _sizes;
  final Map<String, Currency> _currencies;
  final Map<String, Language> _languages;

  @override
  Future<void> ensureLoaded({bool force = false}) async {}

  @override
  Map<String, Country> get countries => _countries;

  @override
  Country? country(String id) => _countries[id];

  @override
  Map<String, Industry> get industries => _industries;

  @override
  Industry? industry(String id) => _industries[id];

  @override
  Map<String, Size> get sizes => _sizes;

  @override
  Size? size(String id) => _sizes[id];

  @override
  Map<String, Currency> get currencies => _currencies;

  @override
  Currency? currency(String id) => _currencies[id];

  @override
  Map<String, Language> get languages => _languages;

  @override
  Language? language(String id) => _languages[id];
}

const _kUsa = Country(
  id: '840',
  name: 'United States',
  iso2: 'US',
  iso3: 'USA',
  swapCurrencySymbol: false,
  thousandSeparator: ',',
  decimalSeparator: '.',
  swapPostalCode: false,
);

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
    // Wait for the hydrate cycle so writes don't race against init.
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    return vm;
  }

  Widget wrap(Widget child) => MaterialApp(
    localizationsDelegates: kTestLocalizationsDelegates,
    supportedLocales: kTestSupportedLocales,
    home: Material(child: child),
  );

  group('IsFilterKey', () {
    test('is at default when states == {active}', () async {
      final vm = await makeVm();
      const key = IsFilterKey();
      expect(key.isAtDefault(vm), isTrue);
      await vm.setStates({EntityState.archived});
      expect(key.isAtDefault(vm), isFalse);
      vm.dispose();
    });

    test('addValue always unions (Sentry-style accumulate)', () async {
      final vm = await makeVm();
      const key = IsFilterKey();
      // From default `{active}`, picking Archived unions — both chips
      // remain visible. The user can `×` the active one if they want.
      await key.addValue(vm, 'archived');
      expect(vm.states, {EntityState.active, EntityState.archived});
      await key.addValue(vm, 'deleted');
      expect(vm.states, {
        EntityState.active,
        EntityState.archived,
        EntityState.deleted,
      });
      vm.dispose();
    });

    test('removeValue keeps the rest when one of many drops', () async {
      final vm = await makeVm();
      const key = IsFilterKey();
      await vm.setStates({EntityState.archived, EntityState.deleted});
      await key.removeValue(vm, 'archived');
      expect(vm.states, {EntityState.deleted});
      vm.dispose();
    });

    test('removeValue allows an empty state set — chip disappears', () async {
      final vm = await makeVm();
      const key = IsFilterKey();
      // Default `{active}`. Removing the only chip clears entirely.
      await key.removeValue(vm, 'active');
      expect(
        vm.states,
        isEmpty,
        reason: 'empty set means "no status restriction"; user sees all rows',
      );
      vm.dispose();
    });

    test('cycleValue returns null — chip tap opens the value picker', () async {
      final vm = await makeVm();
      const key = IsFilterKey();
      // Falling back to the base class default means `_onChipTap` routes
      // to the "open value picker" branch instead of cycling silently.
      expect(key.cycleValue(vm), isNull);
      vm.dispose();
    });
  });

  group('CustomFieldFilterKey', () {
    test('available iff a label is configured — server supports '
        'custom_value1..4 as of the v5 filter PR', () async {
      final vm = await makeVm();
      const empty = CustomFieldFilterKey(columnIndex: 1, configuredLabel: '');
      const configured = CustomFieldFilterKey(
        columnIndex: 1,
        configuredLabel: 'Region',
      );
      expect(empty.isAvailable(vm), isFalse, reason: 'no label → self-hide');
      expect(configured.isAvailable(vm), isTrue);
      vm.dispose();
    });

    test('addValue accumulates, removeValue drops', () async {
      final vm = await makeVm();
      const key = CustomFieldFilterKey(
        columnIndex: 1,
        configuredLabel: 'Region',
      );
      await key.addValue(vm, 'North');
      await key.addValue(vm, 'South');
      expect(vm.customFilters[1], {'North', 'South'});
      await key.removeValue(vm, 'North');
      expect(vm.customFilters[1], {'South'});
      vm.dispose();
    });

    testWidgets(
      'dropdown-click path: TokenSearchController.selectValue commits the '
      'value and tokensFrom emits the chip',
      (tester) async {
        // Reproduces the user-visible flow: user picks `custom1:` from the
        // Add Filter menu, the value dropdown streams cached values, the
        // user clicks one. The menu wiring funnels every value tap through
        // `TokenSearchController.selectValue` — exercising it here pins
        // any regression in the dropdown-click pipeline (closure capture,
        // setSearch race, applied-state check) to a unit test.
        final vm = _FakeVm(
          companyId: 'co',
          navStateDao: db.navStateDao,
          userSettings: UserSettingsRepository(db: db),
          searchDebounce: const Duration(milliseconds: 1),
          persistDebounce: const Duration(milliseconds: 1),
        );
        addTearDown(vm.dispose);
        const key = CustomFieldFilterKey(
          columnIndex: 1,
          configuredLabel: 'Region',
        );
        final controller = TokenSearchController(
          vm: vm,
          filterKeys: const [key],
          initialText: '',
        );
        addTearDown(controller.dispose);

        late BuildContext capturedContext;
        await tester.pumpWidget(
          wrap(
            Builder(
              builder: (context) {
                capturedContext = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        await controller.selectValue(
          key,
          const FilterValueSuggestion(rawValue: 'North', displayLabel: 'North'),
          capturedContext,
        );

        expect(vm.customFilters[1], {'North'});
        final chips = key.tokensFrom(vm, capturedContext).toList();
        expect(chips, hasLength(1));
        expect(chips.single.rawValue, 'North');
        expect(chips.single.displayKey, 'Region');
        // Let the persist + search debounce timers fire so the test
        // framework's pending-timer guard is satisfied.
        await tester.pump(const Duration(milliseconds: 10));
      },
    );

    testWidgets(
      'TokenSearchController.filterKeys can be swapped: an empty-label key '
      'emits no chip, but reassigning a configured-label key surfaces one — '
      'guards the stale-keys race in `TokenSearchField.didUpdateWidget`',
      (tester) async {
        // Reproduces the user-visible bug: when the StreamBuilder<Company?>
        // wrapping the search field first builds with `company == null`,
        // `buildClientFilterKeys` produces `CustomFieldFilterKey`s with
        // empty `configuredLabel`s. The Company stream then emits and the
        // host hands the field a fresh keys list with labels populated. If
        // the controller doesn't sync, chip rendering keeps consulting the
        // stale empty-label key and `tokensFrom` short-circuits, so the
        // filter applies but the pill never paints.
        final vm = _FakeVm(
          companyId: 'co',
          navStateDao: db.navStateDao,
          userSettings: UserSettingsRepository(db: db),
          searchDebounce: const Duration(milliseconds: 1),
          persistDebounce: const Duration(milliseconds: 1),
        );
        addTearDown(vm.dispose);
        // Stage 1: configure the filter via the FRESH key (mirrors the
        // picker's path — it reads `widget.filterKeys`, not the
        // controller's). The value lands in `vm.customFilters[1]`.
        await const CustomFieldFilterKey(
          columnIndex: 1,
          configuredLabel: 'Region',
        ).addValue(vm, 'North');
        expect(vm.customFilters[1], {'North'});

        // Stage 2: controller initialised with the STALE keys (empty
        // label) — the chip query should return nothing because
        // `tokensFrom` short-circuits.
        final controller = TokenSearchController(
          vm: vm,
          filterKeys: const [
            CustomFieldFilterKey(columnIndex: 1, configuredLabel: ''),
          ],
          initialText: '',
        );
        addTearDown(controller.dispose);

        late int staleCount;
        late int freshCount;
        late FilterToken freshChip;
        await tester.pumpWidget(
          wrap(
            Builder(
              builder: (context) {
                staleCount = controller.activeTokens(context).length;
                // Stage 3: the host's didUpdateWidget would now sync the
                // controller with the fresh keys. Same call here.
                controller.filterKeys = const [
                  CustomFieldFilterKey(
                    columnIndex: 1,
                    configuredLabel: 'Region',
                  ),
                ];
                final tokens = controller.activeTokens(context);
                freshCount = tokens.length;
                if (tokens.isNotEmpty) freshChip = tokens.first;
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        expect(staleCount, 0); // bug reproduces with stale keys
        expect(freshCount, 1); // fix surfaces the chip after the swap
        expect(freshChip.rawValue, 'North');
        expect(freshChip.displayKey, 'Region');
        // Also let the pending VM timer (scheduled by setCustomFilter →
        // _resetAndReload → _schedulePersist) settle so the test
        // framework's pending-timer guard doesn't fire.
        await tester.pump(const Duration(milliseconds: 10));
      },
    );

    testWidgets('tokensFrom returns empty when the label is un-configured — '
        'guards against orphan chips painting after a label is removed', (
      tester,
    ) async {
      // The empty-label gate in `tokensFrom` short-circuits before the
      // vm is read, so any vm satisfies the call signature. We construct
      // `_FakeVm` directly (skipping `makeVm`'s hydrate-await loop,
      // which doesn't settle inside `testWidgets`'s fake-time clock).
      final vm = _FakeVm(
        companyId: 'co',
        navStateDao: db.navStateDao,
        userSettings: UserSettingsRepository(db: db),
        searchDebounce: const Duration(milliseconds: 1),
        persistDebounce: const Duration(milliseconds: 1),
      );
      addTearDown(vm.dispose);
      late int unconfiguredCount;
      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) {
              unconfiguredCount = const CustomFieldFilterKey(
                columnIndex: 1,
                configuredLabel: '',
              ).tokensFrom(vm, context).length;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(unconfiguredCount, 0);
    });
  });

  group('CountryFilterKey', () {
    test('reads from extraFilters under country_id', () async {
      final vm = await makeVm();
      final key = CountryFilterKey(
        statics: _FakeStaticsRepository(
          db: db,
          service: _FakeStaticsService(),
          countries: const {'840': _kUsa},
        ),
      );
      await key.addValue(vm, '840');
      expect(vm.extraFilters['country_id'], {'840'});
      await key.removeValue(vm, '840');
      expect(vm.extraFilters.containsKey('country_id'), isFalse);
      vm.dispose();
    });

    test(
      'addValue accepts ISO code aliases and resolves to numeric id',
      () async {
        final vm = await makeVm();
        final key = CountryFilterKey(
          statics: _FakeStaticsRepository(
            db: db,
            service: _FakeStaticsService(),
            countries: const {'840': _kUsa},
          ),
        );
        await key.addValue(vm, 'US');
        expect(
          vm.extraFilters['country_id'],
          {'840'},
          reason: 'paste compat: `country:US` resolves through ISO2',
        );
        vm.dispose();
      },
    );

    test(
      'isAvailable — server supports country_id as of the v5 filter PR',
      () async {
        final vm = await makeVm();
        final key = CountryFilterKey(
          statics: _FakeStaticsRepository(
            db: db,
            service: _FakeStaticsService(),
          ),
        );
        expect(key.isAvailable(vm), isTrue);
        vm.dispose();
      },
    );
  });

  group('IndustryFilterKey', () {
    test('reads from extraFilters under industry_id', () async {
      final vm = await makeVm();
      final key = IndustryFilterKey(
        statics: _FakeStaticsRepository(
          db: db,
          service: _FakeStaticsService(),
          industries: const {'5': Industry(id: '5', name: 'Software')},
        ),
      );
      await key.addValue(vm, '5');
      expect(vm.extraFilters['industry_id'], {'5'});
      await key.removeValue(vm, '5');
      expect(vm.extraFilters.containsKey('industry_id'), isFalse);
      vm.dispose();
    });

    test(
      'isAvailable — server supports industry_id as of the v5 filter PR',
      () async {
        final vm = await makeVm();
        final key = IndustryFilterKey(
          statics: _FakeStaticsRepository(
            db: db,
            service: _FakeStaticsService(),
          ),
        );
        expect(key.isAvailable(vm), isTrue);
        vm.dispose();
      },
    );
  });

  group('SizeFilterKey', () {
    test('reads from extraFilters under size_id', () async {
      final vm = await makeVm();
      final key = SizeFilterKey(
        statics: _FakeStaticsRepository(
          db: db,
          service: _FakeStaticsService(),
          sizes: const {'2': Size(id: '2', name: '4 - 10')},
        ),
      );
      await key.addValue(vm, '2');
      expect(vm.extraFilters['size_id'], {'2'});
      await key.removeValue(vm, '2');
      expect(vm.extraFilters.containsKey('size_id'), isFalse);
      vm.dispose();
    });
  });

  group('AssignedFilterKey', () {
    test('available + plural serverKey (assigned_user_ids)', () async {
      final vm = await makeVm();
      final key = AssignedFilterKey(
        users: UserRepository(db: db, api: _FakeUsersApi()),
        companyId: 'co',
      );
      expect(key.isAvailable(vm), isTrue);
      // Must match the backend's column-guarded CSV base method + the
      // ClientRepository parser key.
      expect(key.serverKey, 'assigned_user_ids');
      vm.dispose();
    });

    test('chip resolves the name SYNCHRONOUSLY via the injected resolver '
        '(no per-instance stream cache → no id-then-name flicker)', () {
      final key = AssignedFilterKey(
        users: UserRepository(db: db, api: _FakeUsersApi()),
        companyId: 'co',
        nameForAssignedId: (id) => id == 'u1' ? 'Jane Doe' : null,
      );
      // First render of a freshly-built instance — must be the name.
      expect(key.displayValueFor('u1'), 'Jane Doe');
      // Unknown / unresolved id falls back to the raw id.
      expect(key.displayValueFor('u9'), 'u9');
    });
  });

  group('GroupFilterKey', () {
    test('available + serverKey group_settings_id', () async {
      final vm = await makeVm();
      final key = GroupFilterKey(
        groups: GroupSettingRepository(db: db, api: _FakeGroupSettingsApi()),
        companyId: 'co',
      );
      expect(key.isAvailable(vm), isTrue);
      expect(key.serverKey, 'group_settings_id');
      vm.dispose();
    });

    test('chip resolves the name SYNCHRONOUSLY via the injected resolver', () {
      final key = GroupFilterKey(
        groups: GroupSettingRepository(db: db, api: _FakeGroupSettingsApi()),
        companyId: 'co',
        nameForGroupId: (id) => id == 'g1' ? 'VIP' : null,
      );
      expect(key.displayValueFor('g1'), 'VIP');
      expect(key.displayValueFor('g9'), 'g9');
    });
  });

  group('NameFilterKey', () {
    test(
      'addValue stores the raw value (no wildcard) — server does LIKE',
      () async {
        final vm = await makeVm();
        const key = NameFilterKey();
        await key.addValue(vm, 'tes');
        expect(
          vm.extraFilters['name'],
          {'tes'},
          reason:
              'Server matches via SQL LIKE %value%; a literal `*` would '
              'make the filter return 0 rows.',
        );
        // singleValue: re-adding replaces, not unions.
        await key.addValue(vm, 'bob');
        expect(vm.extraFilters['name'], {'bob'});
        await key.removeValue(vm, 'bob');
        expect(vm.extraFilters.containsKey('name'), isFalse);
        vm.dispose();
      },
    );

    test('addValue trims whitespace and rejects empty input', () async {
      final vm = await makeVm();
      const key = NameFilterKey();
      await key.addValue(vm, '  spaced  ');
      expect(vm.extraFilters['name'], {'spaced'});
      await key.addValue(vm, '   ');
      // Empty-after-trim should not overwrite the existing value.
      expect(vm.extraFilters['name'], {'spaced'});
      vm.dispose();
    });

    testWidgets('hintForValueMode returns a non-null localized hint', (
      tester,
    ) async {
      String? hint;
      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) {
              hint = const NameFilterKey().hintForValueMode(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(hint, isNotNull);
      expect(hint, isNot(''));
    });
  });

  group('EmailFilterKey', () {
    test('addValue stores the value under server param `email` and '
        'singleValue replaces on subsequent adds', () async {
      final vm = await makeVm();
      const key = EmailFilterKey();
      await key.addValue(vm, '@gmail.com');
      expect(vm.extraFilters['email'], {'@gmail.com'});
      await key.addValue(vm, 'foo@bar.io');
      expect(vm.extraFilters['email'], {'foo@bar.io'});
      await key.removeValue(vm, 'foo@bar.io');
      expect(vm.extraFilters.containsKey('email'), isFalse);
      vm.dispose();
    });
  });

  group('NumberFilterKey', () {
    test('addValue stores the value under server param `number` and '
        'singleValue replaces on subsequent adds', () async {
      final vm = await makeVm();
      const key = NumberFilterKey();
      await key.addValue(vm, '1234');
      expect(vm.extraFilters['number'], {'1234'});
      await key.addValue(vm, '9999');
      expect(vm.extraFilters['number'], {'9999'});
      await key.removeValue(vm, '9999');
      expect(vm.extraFilters.containsKey('number'), isFalse);
      vm.dispose();
    });

    testWidgets('chip renders as `= "value"` — exact-match shape', (
      tester,
    ) async {
      // Construct `_FakeVm` directly — `makeVm()`'s hydrate-await loop
      // uses `Future.delayed(Duration.zero)`, which never settles inside
      // `testWidgets`'s fake-time clock.
      final vm = _FakeVm(
        companyId: 'co',
        navStateDao: db.navStateDao,
        userSettings: UserSettingsRepository(db: db),
        searchDebounce: const Duration(milliseconds: 1),
        persistDebounce: const Duration(milliseconds: 1),
      );
      addTearDown(vm.dispose);
      const key = NumberFilterKey();
      await key.addValue(vm, '1234');
      late List<FilterToken> tokens;
      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) {
              tokens = key.tokensFrom(vm, context).toList();
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(tokens, hasLength(1));
      expect(tokens.single.displayValue, '= "1234"');
      // Let the persist + search debounce timers fire so the test
      // framework's pending-timer guard is satisfied.
      await tester.pump(const Duration(milliseconds: 10));
    });
  });

  group('menu availability after the v5 filter PR', () {
    // The v5 filter PR added server support for country/industry/size/
    // classification/vat/number/custom_value, so those keys are now
    // available. `email` (still exact `whereHas`), `currency_id` /
    // `language_id` (settings-JSON, §A2 — not columns) stay gated.
    test('flipped keys are available; out-of-scope keys stay gated', () async {
      final vm = await makeVm();
      final fakeStatics = _FakeStaticsRepository(
        db: db,
        service: _FakeStaticsService(),
      );
      final available = <(String, bool)>[
        ('number', const NumberFilterKey().isAvailable(vm)),
        ('country', CountryFilterKey(statics: fakeStatics).isAvailable(vm)),
        ('industry', IndustryFilterKey(statics: fakeStatics).isAvailable(vm)),
        ('size', SizeFilterKey(statics: fakeStatics).isAvailable(vm)),
        ('vat', const VatFilterKey().isAvailable(vm)),
        ('classification', const ClassificationFilterKey().isAvailable(vm)),
        (
          'custom1 with label',
          const CustomFieldFilterKey(
            columnIndex: 1,
            configuredLabel: 'Region',
          ).isAvailable(vm),
        ),
      ];
      for (final (name, ok) in available) {
        expect(ok, isTrue, reason: '$name should now be available');
      }
      final gated = <(String, bool)>[
        ('email', const EmailFilterKey().isAvailable(vm)),
        ('currency', CurrencyFilterKey(statics: fakeStatics).isAvailable(vm)),
        ('language', LanguageFilterKey(statics: fakeStatics).isAvailable(vm)),
      ];
      for (final (name, ok) in gated) {
        expect(ok, isFalse, reason: '$name stays gated (out of PR scope)');
      }
      vm.dispose();
    });
  });

  group('BalanceFilterKey', () {
    test(
      'addValue writes canonical PREFIX wire `op:value` — the server '
      '`split()` parses prefix; suffix `value:op` was a zero-row no-op',
      () async {
        final vm = await makeVm();
        const key = BalanceFilterKey();
        await key.addValue(vm, '1000');
        expect(vm.extraFilters['balance'], {'gt:1000'});
        vm.dispose();
      },
    );

    test('addValue decodes the legacy SUFFIX wire and self-heals to '
        'canonical prefix', () async {
      final vm = await makeVm();
      const key = BalanceFilterKey();
      await key.addValue(vm, '1000:lt');
      expect(vm.extraFilters['balance'], {'lt:1000'});
      // singleValue: a new operator replaces the previous one.
      await key.addValue(vm, '500:gt');
      expect(vm.extraFilters['balance'], {'gt:500'});
      // Already-canonical input round-trips unchanged.
      await key.addValue(vm, 'gte:250');
      expect(vm.extraFilters['balance'], {'gte:250'});
      vm.dispose();
    });

    test('addValue trims whitespace and rejects empty', () async {
      final vm = await makeVm();
      const key = BalanceFilterKey();
      await key.addValue(vm, '   ');
      expect(vm.extraFilters.containsKey('balance'), isFalse);
      await key.addValue(vm, '  100  ');
      expect(vm.extraFilters['balance'], {'gt:100'});
      vm.dispose();
    });

    test('supportedOps exposes the full gt/gte/lt/lte/eq set', () async {
      const key = BalanceFilterKey();
      expect(key.supportedOps, [
        FilterOp.gt,
        FilterOp.gte,
        FilterOp.lt,
        FilterOp.lte,
        FilterOp.eq,
      ]);
    });

    test('addValue accepts the symbol-prefix forms produced by the '
        'pick-op-first flow and normalises to canonical prefix', () async {
      final vm = await makeVm();
      const key = BalanceFilterKey();
      await key.addValue(vm, '>1000');
      expect(vm.extraFilters['balance'], {'gt:1000'});
      await key.addValue(vm, '<500');
      expect(vm.extraFilters['balance'], {'lt:500'});
      await key.addValue(vm, '≥250');
      expect(vm.extraFilters['balance'], {'gte:250'});
      await key.addValue(vm, '<=99');
      expect(vm.extraFilters['balance'], {'lte:99'});
      // Embedded whitespace around the value is tolerated.
      await key.addValue(vm, '> 250');
      expect(vm.extraFilters['balance'], {'gt:250'});
      vm.dispose();
    });

    test('changeOp swaps just the operator, keeping the value', () async {
      final vm = await makeVm();
      const key = BalanceFilterKey();
      await key.addValue(vm, '1000');
      expect(vm.extraFilters['balance'], {'gt:1000'});
      await key.changeOp(vm, 'gt:1000', FilterOp.lte);
      expect(vm.extraFilters['balance'], {'lte:1000'});
      vm.dispose();
    });

    test(
      'isValidValue rejects bare operator symbols with no numeric value '
      '(so Enter on `balance:>` is a no-op instead of silently dropping)',
      () {
        const key = BalanceFilterKey();
        // No value: invalid.
        expect(key.isValidValue('>'), isFalse);
        expect(key.isValidValue('<'), isFalse);
        expect(key.isValidValue('gt:'), isFalse);
        expect(key.isValidValue('lt:'), isFalse);
        expect(key.isValidValue(''), isFalse);
        // With a value (any of the accepted forms): valid.
        expect(key.isValidValue('1000'), isTrue);
        expect(key.isValidValue('>1000'), isTrue);
        expect(key.isValidValue('gt:1000'), isTrue);
        expect(key.isValidValue('1000:lt'), isTrue); // legacy suffix decode
        expect(key.isValidValue('< 500'), isTrue);
      },
    );
  });

  group('created date key (DateColumnFilterKey)', () {
    test('addValue writes canonical `gte:<date>` for a bare date (default '
        'op preserves the historical server >=)', () async {
      final vm = await makeVm();
      const key = _createdKey;
      await key.addValue(vm, '2026-01-01');
      expect(vm.extraFilters['created_at'], {'gte:2026-01-01'});
      // Explicit prefix is honored.
      await key.addValue(vm, 'lt:2026-03-01');
      expect(vm.extraFilters['created_at'], {'lt:2026-03-01'});
      // Legacy suffix self-heals.
      await key.addValue(vm, '2026-02-01:gt');
      expect(vm.extraFilters['created_at'], {'gt:2026-02-01'});
      vm.dispose();
    });
  });

  // The token field's FilterInputParse splits on the FIRST colon, so a
  // typed `created:gte:2026-01-01` reaches addValue as the query
  // `gte:2026-01-01`. Verify the whole typed-entry vector resolves to
  // canonical wire (the path the segmented-chip plan calls out).
  group('typed-entry vectors (post-FilterInputParse query)', () {
    test('created date key: `gte:2026-01-01` → canonical', () async {
      final vm = await makeVm();
      const key = _createdKey;
      await key.addValue(vm, 'gte:2026-01-01');
      expect(vm.extraFilters['created_at'], {'gte:2026-01-01'});
      vm.dispose();
    });

    test('BalanceFilterKey: `>1000` → `gt:1000`', () async {
      final vm = await makeVm();
      const key = BalanceFilterKey();
      await key.addValue(vm, '>1000');
      expect(vm.extraFilters['balance'], {'gt:1000'});
      vm.dispose();
    });

    test(
      'BalanceFilterKey: `gt:5000` → `gt:5000` (already canonical)',
      () async {
        final vm = await makeVm();
        const key = BalanceFilterKey();
        await key.addValue(vm, 'gt:5000');
        expect(vm.extraFilters['balance'], {'gt:5000'});
        vm.dispose();
      },
    );
  });

  group('updated date key (DateColumnFilterKey)', () {
    test('addValue writes canonical `gte:<date>` for a bare date', () async {
      final vm = await makeVm();
      const key = _updatedKey;
      await key.addValue(vm, '2026-05-01');
      expect(vm.extraFilters['updated_at'], {'gte:2026-05-01'});
      vm.dispose();
    });
  });

  group('VatFilterKey / IdNumberFilterKey / ClassificationFilterKey', () {
    test('vat accumulates multiple values', () async {
      final vm = await makeVm();
      const key = VatFilterKey();
      await key.addValue(vm, 'DE123');
      await key.addValue(vm, 'FR456');
      expect(vm.extraFilters['vat_number'], {'DE123', 'FR456'});
      await key.removeValue(vm, 'DE123');
      expect(vm.extraFilters['vat_number'], {'FR456'});
      vm.dispose();
    });

    test('classification stores the typed enum-ish value', () async {
      final vm = await makeVm();
      const key = ClassificationFilterKey();
      await key.addValue(vm, 'company');
      expect(vm.extraFilters['classification'], {'company'});
      vm.dispose();
    });
  });

  group('CurrencyFilterKey', () {
    test('reads from extraFilters under currency_id', () async {
      final vm = await makeVm();
      final key = CurrencyFilterKey(
        statics: _FakeStaticsRepository(
          db: db,
          service: _FakeStaticsService(),
          currencies: {
            '1': Currency(
              id: '1',
              name: 'US Dollar',
              code: 'USD',
              symbol: r'$',
              precision: 2,
              thousandSeparator: ',',
              decimalSeparator: '.',
              swapCurrencySymbol: false,
              exchangeRate: Decimal.one,
            ),
          },
        ),
      );
      await key.addValue(vm, '1');
      expect(vm.extraFilters['currency_id'], {'1'});
      vm.dispose();
    });
  });

  group('LanguageFilterKey', () {
    test('reads from extraFilters under language_id', () async {
      final vm = await makeVm();
      final key = LanguageFilterKey(
        statics: _FakeStaticsRepository(
          db: db,
          service: _FakeStaticsService(),
          languages: const {
            '1': Language(id: '1', name: 'English', locale: 'en'),
          },
        ),
      );
      await key.addValue(vm, '1');
      expect(vm.extraFilters['language_id'], {'1'});
      vm.dispose();
    });
  });

  group(
    'quickValueSuggestions (cross-key value matches in free-text picker)',
    () {
      // The key-mode picker calls `quickValueSuggestions` on every key
      // synchronously and surfaces matches as a `Filter values` block.
      // These tests verify the per-key contribution: each contributing
      // key returns the expected matches, and non-contributing keys
      // (typed-input + flat-membership) return empty so they don't
      // pollute the picker.

      testWidgets('IsFilterKey: `act` → [Active] (startsWith on label)', (
        tester,
      ) async {
        // Construct `_FakeVm` directly — `makeVm()`'s hydrate-await loop
        // uses `Future.delayed(Duration.zero)`, which never settles
        // inside `testWidgets`'s fake-time clock. `quickValueSuggestions`
        // doesn't read VM state on contributing keys (statics-backed
        // keys hit `statics.*`; `IsFilterKey` enumerates EntityState
        // values), so a freshly-constructed VM is enough.
        final vm = _FakeVm(
          companyId: 'co',
          navStateDao: db.navStateDao,
          userSettings: UserSettingsRepository(db: db),
          searchDebounce: const Duration(milliseconds: 1),
          persistDebounce: const Duration(milliseconds: 1),
        );
        addTearDown(vm.dispose);
        late List<FilterValueSuggestion> matches;
        await tester.pumpWidget(
          wrap(
            Builder(
              builder: (context) {
                matches = const IsFilterKey().quickValueSuggestions(
                  vm,
                  context,
                  'act',
                );
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        expect(matches.map((s) => s.rawValue), ['active']);
        expect(matches.first.displayLabel, 'Active');
      });

      testWidgets('IsFilterKey: empty query → []', (tester) async {
        // Construct `_FakeVm` directly — `makeVm()`'s hydrate-await loop
        // uses `Future.delayed(Duration.zero)`, which never settles
        // inside `testWidgets`'s fake-time clock. `quickValueSuggestions`
        // doesn't read VM state on contributing keys (statics-backed
        // keys hit `statics.*`; `IsFilterKey` enumerates EntityState
        // values), so a freshly-constructed VM is enough.
        final vm = _FakeVm(
          companyId: 'co',
          navStateDao: db.navStateDao,
          userSettings: UserSettingsRepository(db: db),
          searchDebounce: const Duration(milliseconds: 1),
          persistDebounce: const Duration(milliseconds: 1),
        );
        addTearDown(vm.dispose);
        late List<FilterValueSuggestion> matches;
        await tester.pumpWidget(
          wrap(
            Builder(
              builder: (context) {
                matches = const IsFilterKey().quickValueSuggestions(
                  vm,
                  context,
                  '',
                );
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        expect(matches, isEmpty);
      });

      testWidgets('IsFilterKey: no match → []', (tester) async {
        // Construct `_FakeVm` directly — `makeVm()`'s hydrate-await loop
        // uses `Future.delayed(Duration.zero)`, which never settles
        // inside `testWidgets`'s fake-time clock. `quickValueSuggestions`
        // doesn't read VM state on contributing keys (statics-backed
        // keys hit `statics.*`; `IsFilterKey` enumerates EntityState
        // values), so a freshly-constructed VM is enough.
        final vm = _FakeVm(
          companyId: 'co',
          navStateDao: db.navStateDao,
          userSettings: UserSettingsRepository(db: db),
          searchDebounce: const Duration(milliseconds: 1),
          persistDebounce: const Duration(milliseconds: 1),
        );
        addTearDown(vm.dispose);
        late List<FilterValueSuggestion> matches;
        await tester.pumpWidget(
          wrap(
            Builder(
              builder: (context) {
                matches = const IsFilterKey().quickValueSuggestions(
                  vm,
                  context,
                  'xyz',
                );
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        expect(matches, isEmpty);
      });

      testWidgets('CountryFilterKey: `ger` → [Germany] (startsWith on name)', (
        tester,
      ) async {
        // Construct `_FakeVm` directly — `makeVm()`'s hydrate-await loop
        // uses `Future.delayed(Duration.zero)`, which never settles
        // inside `testWidgets`'s fake-time clock. `quickValueSuggestions`
        // doesn't read VM state on contributing keys (statics-backed
        // keys hit `statics.*`; `IsFilterKey` enumerates EntityState
        // values), so a freshly-constructed VM is enough.
        final vm = _FakeVm(
          companyId: 'co',
          navStateDao: db.navStateDao,
          userSettings: UserSettingsRepository(db: db),
          searchDebounce: const Duration(milliseconds: 1),
          persistDebounce: const Duration(milliseconds: 1),
        );
        addTearDown(vm.dispose);
        final key = CountryFilterKey(
          statics: _FakeStaticsRepository(
            db: db,
            service: _FakeStaticsService(),
            countries: const {
              '276': Country(
                id: '276',
                name: 'Germany',
                iso2: 'DE',
                iso3: 'DEU',
                swapCurrencySymbol: false,
                thousandSeparator: '.',
                decimalSeparator: ',',
                swapPostalCode: false,
              ),
              '840': _kUsa,
            },
          ),
        );
        late List<FilterValueSuggestion> matches;
        await tester.pumpWidget(
          wrap(
            Builder(
              builder: (context) {
                matches = key.quickValueSuggestions(vm, context, 'ger');
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        expect(matches.map((s) => s.displayLabel), ['Germany']);
        expect(matches.first.rawValue, '276');
      });

      testWidgets('CountryFilterKey: `us` → [United States] via ISO2', (
        tester,
      ) async {
        // Construct `_FakeVm` directly — `makeVm()`'s hydrate-await loop
        // uses `Future.delayed(Duration.zero)`, which never settles
        // inside `testWidgets`'s fake-time clock. `quickValueSuggestions`
        // doesn't read VM state on contributing keys (statics-backed
        // keys hit `statics.*`; `IsFilterKey` enumerates EntityState
        // values), so a freshly-constructed VM is enough.
        final vm = _FakeVm(
          companyId: 'co',
          navStateDao: db.navStateDao,
          userSettings: UserSettingsRepository(db: db),
          searchDebounce: const Duration(milliseconds: 1),
          persistDebounce: const Duration(milliseconds: 1),
        );
        addTearDown(vm.dispose);
        final key = CountryFilterKey(
          statics: _FakeStaticsRepository(
            db: db,
            service: _FakeStaticsService(),
            countries: const {'840': _kUsa},
          ),
        );
        late List<FilterValueSuggestion> matches;
        await tester.pumpWidget(
          wrap(
            Builder(
              builder: (context) {
                matches = key.quickValueSuggestions(vm, context, 'us');
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        // ISO2 exact-match is the second branch — the name "United
        // States" doesn't startsWith "us", but the iso2 code does.
        expect(matches.map((s) => s.displayLabel), ['United States']);
        expect(matches.first.secondaryLabel, 'US');
      });

      testWidgets('CountryFilterKey: caps at 3 per key when many match', (
        tester,
      ) async {
        // Construct `_FakeVm` directly — `makeVm()`'s hydrate-await loop
        // uses `Future.delayed(Duration.zero)`, which never settles
        // inside `testWidgets`'s fake-time clock. `quickValueSuggestions`
        // doesn't read VM state on contributing keys (statics-backed
        // keys hit `statics.*`; `IsFilterKey` enumerates EntityState
        // values), so a freshly-constructed VM is enough.
        final vm = _FakeVm(
          companyId: 'co',
          navStateDao: db.navStateDao,
          userSettings: UserSettingsRepository(db: db),
          searchDebounce: const Duration(milliseconds: 1),
          persistDebounce: const Duration(milliseconds: 1),
        );
        addTearDown(vm.dispose);
        // Five made-up countries all starting with "un" so the cap is
        // the only thing constraining the output.
        Country mk(String id, String name, String iso2, String iso3) => Country(
          id: id,
          name: name,
          iso2: iso2,
          iso3: iso3,
          swapCurrencySymbol: false,
          thousandSeparator: ',',
          decimalSeparator: '.',
          swapPostalCode: false,
        );
        final key = CountryFilterKey(
          statics: _FakeStaticsRepository(
            db: db,
            service: _FakeStaticsService(),
            countries: {
              '1': mk('1', 'Unallocated', 'UA', 'UAA'),
              '2': mk('2', 'Unbridged', 'UB', 'UBB'),
              '3': mk('3', 'Uncharted', 'UC', 'UCC'),
              '4': mk('4', 'Undecided', 'UD', 'UDD'),
              '5': mk('5', 'United Land', 'UL', 'ULL'),
            },
          ),
        );
        late List<FilterValueSuggestion> matches;
        await tester.pumpWidget(
          wrap(
            Builder(
              builder: (context) {
                matches = key.quickValueSuggestions(vm, context, 'un');
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        // Alphabetically: Unallocated, Unbridged, Uncharted, …
        expect(matches.length, 3);
        expect(matches.map((s) => s.displayLabel), [
          'Unallocated',
          'Unbridged',
          'Uncharted',
        ]);
      });

      testWidgets('CurrencyFilterKey: `eur` → [EUR] (startsWith on code)', (
        tester,
      ) async {
        // Construct `_FakeVm` directly — `makeVm()`'s hydrate-await loop
        // uses `Future.delayed(Duration.zero)`, which never settles
        // inside `testWidgets`'s fake-time clock. `quickValueSuggestions`
        // doesn't read VM state on contributing keys (statics-backed
        // keys hit `statics.*`; `IsFilterKey` enumerates EntityState
        // values), so a freshly-constructed VM is enough.
        final vm = _FakeVm(
          companyId: 'co',
          navStateDao: db.navStateDao,
          userSettings: UserSettingsRepository(db: db),
          searchDebounce: const Duration(milliseconds: 1),
          persistDebounce: const Duration(milliseconds: 1),
        );
        addTearDown(vm.dispose);
        final key = CurrencyFilterKey(
          statics: _FakeStaticsRepository(
            db: db,
            service: _FakeStaticsService(),
            currencies: {
              '3': Currency(
                id: '3',
                name: 'Euro',
                code: 'EUR',
                symbol: '€',
                precision: 2,
                thousandSeparator: '.',
                decimalSeparator: ',',
                swapCurrencySymbol: false,
                exchangeRate: Decimal.one,
              ),
              '1': Currency(
                id: '1',
                name: 'US Dollar',
                code: 'USD',
                symbol: r'$',
                precision: 2,
                thousandSeparator: ',',
                decimalSeparator: '.',
                swapCurrencySymbol: false,
                exchangeRate: Decimal.one,
              ),
            },
          ),
        );
        late List<FilterValueSuggestion> matches;
        await tester.pumpWidget(
          wrap(
            Builder(
              builder: (context) {
                matches = key.quickValueSuggestions(vm, context, 'eur');
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        expect(matches.map((s) => s.displayLabel), ['EUR']);
        expect(matches.first.rawValue, '3');
        expect(matches.first.secondaryLabel, 'Euro');
      });

      testWidgets('IndustryFilterKey: `soft` → [Software]', (tester) async {
        // Construct `_FakeVm` directly — `makeVm()`'s hydrate-await loop
        // uses `Future.delayed(Duration.zero)`, which never settles
        // inside `testWidgets`'s fake-time clock. `quickValueSuggestions`
        // doesn't read VM state on contributing keys (statics-backed
        // keys hit `statics.*`; `IsFilterKey` enumerates EntityState
        // values), so a freshly-constructed VM is enough.
        final vm = _FakeVm(
          companyId: 'co',
          navStateDao: db.navStateDao,
          userSettings: UserSettingsRepository(db: db),
          searchDebounce: const Duration(milliseconds: 1),
          persistDebounce: const Duration(milliseconds: 1),
        );
        addTearDown(vm.dispose);
        final key = IndustryFilterKey(
          statics: _FakeStaticsRepository(
            db: db,
            service: _FakeStaticsService(),
            industries: const {
              '5': Industry(id: '5', name: 'Software'),
              '9': Industry(id: '9', name: 'Manufacturing'),
            },
          ),
        );
        late List<FilterValueSuggestion> matches;
        await tester.pumpWidget(
          wrap(
            Builder(
              builder: (context) {
                matches = key.quickValueSuggestions(vm, context, 'soft');
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        expect(matches.map((s) => s.displayLabel), ['Software']);
      });

      testWidgets('LanguageFilterKey: `eng` → [English]', (tester) async {
        // Construct `_FakeVm` directly — `makeVm()`'s hydrate-await loop
        // uses `Future.delayed(Duration.zero)`, which never settles
        // inside `testWidgets`'s fake-time clock. `quickValueSuggestions`
        // doesn't read VM state on contributing keys (statics-backed
        // keys hit `statics.*`; `IsFilterKey` enumerates EntityState
        // values), so a freshly-constructed VM is enough.
        final vm = _FakeVm(
          companyId: 'co',
          navStateDao: db.navStateDao,
          userSettings: UserSettingsRepository(db: db),
          searchDebounce: const Duration(milliseconds: 1),
          persistDebounce: const Duration(milliseconds: 1),
        );
        addTearDown(vm.dispose);
        final key = LanguageFilterKey(
          statics: _FakeStaticsRepository(
            db: db,
            service: _FakeStaticsService(),
            languages: const {
              '1': Language(id: '1', name: 'English', locale: 'en'),
            },
          ),
        );
        late List<FilterValueSuggestion> matches;
        await tester.pumpWidget(
          wrap(
            Builder(
              builder: (context) {
                matches = key.quickValueSuggestions(vm, context, 'eng');
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        expect(matches.map((s) => s.displayLabel), ['English']);
      });

      testWidgets(
        'CustomFieldFilterKey: `nor` → [North] (startsWith on cached value)',
        (tester) async {
          // Regression coverage for the cross-key custom-value lookup. The
          // sister keys (Country, Currency, Industry, Language, Status) all
          // got `quickValueSuggestions` overrides; CustomFieldFilterKey was
          // missed in that pass, so typing free text didn't surface
          // `Region: North`. Reads from the synchronous cache populated by
          // `GenericListViewModel._subscribeCustomValues`.
          final vm = _FakeVm(
            companyId: 'co',
            navStateDao: db.navStateDao,
            userSettings: UserSettingsRepository(db: db),
            searchDebounce: const Duration(milliseconds: 1),
            persistDebounce: const Duration(milliseconds: 1),
          );
          addTearDown(vm.dispose);
          late List<FilterValueSuggestion> matches;
          await tester.pumpWidget(
            wrap(
              Builder(
                builder: (context) {
                  matches = const CustomFieldFilterKey(
                    columnIndex: 1,
                    configuredLabel: 'Region',
                  ).quickValueSuggestions(vm, context, 'nor');
                  return const SizedBox.shrink();
                },
              ),
            ),
          );
          expect(matches.map((s) => s.displayLabel), ['North']);
          expect(matches.first.rawValue, 'North');
        },
      );

      testWidgets(
        'CustomFieldFilterKey: empty configuredLabel returns [] (key is hidden)',
        (tester) async {
          // Symmetric with `isAvailable: false` — when the workspace
          // hasn't configured a label for this custom column, the key
          // doesn't show up in the menu, so its cross-key contributions
          // shouldn't either.
          final vm = _FakeVm(
            companyId: 'co',
            navStateDao: db.navStateDao,
            userSettings: UserSettingsRepository(db: db),
            searchDebounce: const Duration(milliseconds: 1),
            persistDebounce: const Duration(milliseconds: 1),
          );
          addTearDown(vm.dispose);
          late List<FilterValueSuggestion> matches;
          await tester.pumpWidget(
            wrap(
              Builder(
                builder: (context) {
                  matches = const CustomFieldFilterKey(
                    columnIndex: 1,
                    configuredLabel: '',
                  ).quickValueSuggestions(vm, context, 'nor');
                  return const SizedBox.shrink();
                },
              ),
            ),
          );
          expect(matches, isEmpty);
        },
      );

      testWidgets(
        'non-contributing keys return empty by default (Name, Balance, Vat)',
        (tester) async {
          // Construct `_FakeVm` directly — see the earlier comment.
          final vm = _FakeVm(
            companyId: 'co',
            navStateDao: db.navStateDao,
            userSettings: UserSettingsRepository(db: db),
            searchDebounce: const Duration(milliseconds: 1),
            persistDebounce: const Duration(milliseconds: 1),
          );
          addTearDown(vm.dispose);
          // These keys don't have an enumerable value set, so they
          // should NOT show up in the cross-key value-match block —
          // typing free text shouldn't surface a `Name: foo` row.
          late List<List<FilterValueSuggestion>> results;
          await tester.pumpWidget(
            wrap(
              Builder(
                builder: (context) {
                  results = [
                    const NameFilterKey().quickValueSuggestions(
                      vm,
                      context,
                      'foo',
                    ),
                    const BalanceFilterKey().quickValueSuggestions(
                      vm,
                      context,
                      '100',
                    ),
                    const VatFilterKey().quickValueSuggestions(
                      vm,
                      context,
                      'DE',
                    ),
                    const IdNumberFilterKey().quickValueSuggestions(
                      vm,
                      context,
                      '123',
                    ),
                    const ClassificationFilterKey().quickValueSuggestions(
                      vm,
                      context,
                      'com',
                    ),
                  ];
                  return const SizedBox.shrink();
                },
              ),
            ),
          );
          for (final r in results) {
            expect(r, isEmpty);
          }
        },
      );
    },
  );

  group('editableValueText — chip-tap-to-edit pre-fill', () {
    // Click-to-edit on a chip pushes `key:editableValueText(rawValue)` into
    // the input so the user lands in their existing value. Tests below
    // assert (a) the editable form matches what the user originally
    // typed, and (b) `addValue(editable)` round-trips back to the same
    // wire format — so submitting an unchanged edit produces no diff.

    test('EmailFilterKey: passes the address through unchanged', () {
      const key = EmailFilterKey();
      expect(key.editableValueText('foo@bar.com'), 'foo@bar.com');
    });

    test('NumberFilterKey: passes the number through unchanged', () {
      const key = NumberFilterKey();
      expect(key.editableValueText('1234'), '1234');
    });

    test('NameFilterKey: strips a trailing legacy `*` wildcard', () {
      const key = NameFilterKey();
      expect(key.editableValueText('tes'), 'tes');
      // Persisted state from an older app version may carry a `*` —
      // strip it so the chip's "contains tes" matches the editable form.
      expect(key.editableValueText('tes*'), 'tes');
    });

    test('BalanceFilterKey: any wire → `symbol+value` (round-trip)', () async {
      final vm = await makeVm();
      const key = BalanceFilterKey();
      // Canonical prefix, legacy suffix, and pretty unicode all decode.
      expect(key.editableValueText('gt:1000'), '>1000');
      expect(key.editableValueText('1000:lt'), '<1000');
      expect(key.editableValueText('gte:250'), '≥250');
      expect(key.editableValueText('lte:99'), '≤99');
      // Re-submitting an unchanged edit round-trips to canonical wire.
      await key.addValue(vm, '>1000');
      expect(vm.extraFilters['balance'], {'gt:1000'});
      vm.dispose();
    });

    test('BalanceFilterKey: legacy suffix `value:op` → `symbol+value`', () {
      const key = BalanceFilterKey();
      expect(key.editableValueText('1000:gt'), '>1000');
      expect(key.editableValueText('250:lt'), '<250');
    });

    test('created / updated date keys: strip the operator', () {
      expect(_createdKey.editableValueText('2026-01-01:gt'), '2026-01-01');
      expect(_updatedKey.editableValueText('2026-05-01:gt'), '2026-05-01');
    });

    test(
      'membership / enum keys do NOT override — value belongs in the picker',
      () async {
        final vm = await makeVm();
        final statics = _FakeStaticsRepository(
          db: db,
          service: _FakeStaticsService(),
        );
        // null defaults preserve the "remove chip + open menu" path.
        expect(const IsFilterKey().editableValueText('active'), isNull);
        expect(
          CountryFilterKey(statics: statics).editableValueText('840'),
          isNull,
        );
        expect(
          CurrencyFilterKey(statics: statics).editableValueText('1'),
          isNull,
        );
        expect(const VatFilterKey().editableValueText('DE123'), isNull);
        expect(
          const CustomFieldFilterKey(
            columnIndex: 1,
            configuredLabel: 'Region',
          ).editableValueText('North'),
          isNull,
        );
        vm.dispose();
      },
    );
  });

  group('buildClientFilterKeys', () {
    testWidgets('resolves company custom-field labels', (tester) async {
      late List<String> displayLabels;
      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) {
              final keys = buildClientFilterKeys(
                company: const Company(
                  id: 'co',
                  name: 'Acme',
                  customFields: {
                    'client1': 'Region|North,South',
                    'client3': 'Project',
                  },
                ),
                statics: _FakeStaticsRepository(
                  db: db,
                  service: _FakeStaticsService(),
                ),
                groups: GroupSettingRepository(
                  db: db,
                  api: _FakeGroupSettingsApi(),
                ),
                users: UserRepository(db: db, api: _FakeUsersApi()),
                tags: TagRepository(db: db, api: _StubTagsApi()),
                companyId: 'co',
              );
              displayLabels = [for (final k in keys) k.displayLabel(context)];
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      // is, name, email, number, balance, custom1..4 (4), country,
      // industry, size, currency, language, classification, vat,
      // id_number, created, updated, group, assigned
      // → 21 keys + the appended tag filter = 22. (The standalone "updated
      // between" entry was folded into the `updated` DateColumnFilterKey's
      // `between` operator; FilterFilterKey was removed earlier — it
      // duplicated the plain-text search path.)
      // custom1 gets "Region", custom3 gets "Project"; others fall through to
      // the generic label.
      expect(displayLabels.length, 22);
      expect(displayLabels.last, 'Tags', reason: 'tag filter appended last');
      // Order: is(0), name(1), email(2), number(3), balance(4),
      // custom1(5)…custom4(8), …
      expect(
        displayLabels[5],
        'Region',
        reason: 'custom1 with configured label',
      );
      expect(
        displayLabels[7],
        'Project',
        reason: 'custom3 with configured label',
      );
    });
  });

  group('created / updated date keys (DateColumnFilterKey)', () {
    test('are available', () async {
      final vm = await makeVm();
      expect(_createdKey.isAvailable(vm), isTrue);
      expect(_updatedKey.isAvailable(vm), isTrue);
      vm.dispose();
    });

    test('removeValue clears the date filter', () async {
      final vm = await makeVm();
      const key = _createdKey;

      await key.addValue(vm, '2026-01-01');
      expect(vm.extraFilters['created_at'], {'gte:2026-01-01'});

      await key.removeValue(vm, 'gte:2026-01-01');
      expect(vm.extraFilters['created_at'] ?? const <String>{}, isEmpty);

      vm.dispose();
    });

    testWidgets('chip splits value and comparator', (tester) async {
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
        const key = _createdKey;
        await key.addValue(vm, '2026-01-01');
        final tokens = key.tokensFrom(vm, ctx).toList();
        expect(tokens.single.rawValue, 'gte:2026-01-01');
        expect(tokens.single.displayValue, '2026-01-01');
        // Default op for dates is gte → "is on or after" (raw l10n key
        // in this Localization-less test context).
        expect(tokens.single.displayComparator, 'is_on_or_after');
        vm.dispose();
      });
    });
  });

  // The standalone "Updated between" dropdown entry was replaced by the
  // `between` operator on the `created` / `updated` DateColumnFilterKeys. Its
  // window lives in `created_at_range` / `updated_at_range` (canonical 3-part
  // `<col>,<start>,<end>` wire) — the slots `ClientRepository.watchPage`
  // mirrors locally. Mirrors the payments `DateColumnFilterKey` between group.
  group('created / updated between windows (DateColumnFilterKey)', () {
    for (final (label, key, rangeSlot, compSlot)
        in <(String, DateColumnFilterKey, String, String)>[
          ('created', _createdKey, 'created_at_range', 'created_at'),
          ('updated', _updatedKey, 'updated_at_range', 'updated_at'),
        ]) {
      test('$label: exposes between alongside the single-date comparators', () {
        expect(key.supportedOps, contains(FilterOp.between));
        expect(key.rangeServerKey, rangeSlot);
      });

      test(
        '$label: addValue routes a window to the range slot as the canonical '
        '<col>,<start>,<end> wire and clears the comparable slot',
        () async {
          final vm = await makeVm();
          // Seed a single-date comparable filter first.
          await key.addValue(vm, 'gte:2026-01-01');
          expect(vm.extraFilters[compSlot], {'gte:2026-01-01'});
          // A legacy 2-part window normalizes to canonical 3-part in the
          // range slot, and the comparable slot is cleared (mutually
          // exclusive within the key).
          await key.addValue(vm, '2026-05-01,2026-05-31');
          expect(vm.extraFilters[rangeSlot], {
            '$compSlot,2026-05-01,2026-05-31',
          });
          expect(vm.extraFilters[compSlot] ?? const <String>{}, isEmpty);
          vm.dispose();
        },
      );

      test('$label: switching back to a single-date op seeds from the window '
          'start and clears the range slot', () async {
        final vm = await makeVm();
        await key.addValue(vm, '$compSlot,2026-05-01,2026-05-31');
        await key.changeOp(vm, '$compSlot,2026-05-01,2026-05-31', FilterOp.gte);
        expect(vm.extraFilters[rangeSlot] ?? const <String>{}, isEmpty);
        expect(vm.extraFilters[compSlot], {'gte:2026-05-01'});
        vm.dispose();
      });

      testWidgets(
        '$label: the window renders as one chip; clear drops both slots',
        (tester) async {
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
            // A non-column prefix still normalizes to the canonical wire.
            await key.addValue(vm, 'preset,2026-05-01,2026-05-31');
            final tokens = key.tokensFrom(vm, ctx).toList();
            expect(tokens, hasLength(1));
            expect(tokens.single.displayValue, '2026-05-01 – 2026-05-31');
            expect(tokens.single.rawValue, '$compSlot,2026-05-01,2026-05-31');

            await key.clear(vm, ctx);
            expect(vm.extraFilters[rangeSlot] ?? const <String>{}, isEmpty);
            expect(vm.extraFilters[compSlot] ?? const <String>{}, isEmpty);
            vm.dispose();
          });
        },
      );
    }
  });
}

class _FakeStaticsService implements StaticsService {
  @override
  Future<Map<String, dynamic>> fetch() async => const {};
}

// Group/Assigned filter keys only touch the local DAO via `watchAll` /
// `watchAllForPicker` — the api is never called, so a throwing fake is fine
// (same pattern as group_setting_repository_test / user_repository_test).
class _FakeGroupSettingsApi implements GroupSettingsApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeUsersApi implements UsersApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _StubTagsApi implements TagsApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
