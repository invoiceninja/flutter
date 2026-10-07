// Shared harness for pumping the REAL wide `TokenSearchField`.
//
// Until this existed nothing did: `token_search_field_test.dart` covers the
// parser and the chip, and its header says the field itself was deliberately
// left alone. So every bug in the field's own behaviour — where the popup
// lands, what Enter commits, what emptying the box does — shipped untested.
//
// Three things the harness gets right that a naive pump would not:
//
//  * **A second Overlay, offset from the window.** The real shell hosts a
//    list in a branch Navigator whose Overlay starts to the right of the
//    sidebar (x = 232 on a wide window). The popup is placed in that
//    Overlay's coordinates, so a test that hosts the field in the root
//    Overlay cannot see a lost origin. Assert on GLOBAL rects
//    (`tester.getRect`): a dropped conversion then shows up as +232.
//  * **A real view model.** The bugs are in how the field and the VM talk
//    (`setSearch`, its debounce, `setExtraFilter`), so a stub VM would pin the
//    test's own assumptions.
//  * **`pump()`, never `pumpAndSettle()`.** The open popup re-lays-out every
//    frame, and a filtered list shows a progress line.

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/search_focus_registry.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/repositories/user_settings_repository.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';
import 'package:admin/ui/core/list/search/filter_key.dart';
import 'package:admin/ui/core/list/search/filter_suggestion_menu.dart';
import 'package:admin/ui/core/list/search/filter_token.dart';
import 'package:admin/ui/core/list/search/membership_filter_key.dart';
import 'package:admin/ui/core/list/search/token_search_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../../_localization_helper.dart';

/// The sidebar's width on a wide window — where the branch Overlay starts.
const double kHarnessSidebar = 232;

/// `Services` for the field: it reads `searchFocus` in `initState` and, for
/// the hint cap, `keyboardShortcuts` (guarded — a throw there just hides the
/// hint). Anything else is a test bug and throws.
class FakeSearchServices implements Services {
  @override
  final SearchFocusRegistry searchFocus = SearchFocusRegistry();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// A real [GenericListViewModel] over an in-memory database whose fetches
/// return nothing.
class HarnessVm extends GenericListViewModel<dynamic> {
  HarnessVm({
    required super.companyId,
    required super.navStateDao,
    required super.userSettings,
    super.searchDebounce,
    super.persistDebounce,
    this.locked = const {},
  });

  /// Stands in for an embedded list, whose parent scope locks a key.
  final Set<String> locked;

  @override
  Set<String> get lockedFilterKeyIds => locked;

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

HarnessVm newHarnessVm(
  AppDatabase db, {
  Duration searchDebounce = Duration.zero,
  Set<String> locked = const {},
}) {
  final vm = HarnessVm(
    companyId: 'co',
    navStateDao: db.navStateDao,
    userSettings: UserSettingsRepository(db: db),
    searchDebounce: searchDebounce,
    persistDebounce: Duration.zero,
    locked: locked,
  );
  addTearDown(vm.dispose);
  return vm;
}

/// A pick-only, multi-valued key with three fixed values — the shape of
/// Client / Country / Tags without their repositories. [checkbox] makes it a
/// multi-select list (Status / Tags) rather than a single-pick one (Client).
class FruitKey extends MembershipFilterKey {
  FruitKey({this.checkbox = false, this.delay});

  final bool checkbox;

  /// When set, the value list arrives after this long — a Drift-backed list.
  final Duration? delay;

  static const Map<String, String> fruits = {
    'a': 'Apple',
    'b': 'Banana',
    'c': 'Cherry',
  };

  @override
  String get id => 'fruit';

  @override
  String get serverKey => 'fruit_id';

  @override
  String displayLabel(BuildContext context) => 'Fruit';

  @override
  bool get acceptsTypedValue => false;

  @override
  bool get checkboxMultiSelect => checkbox;

  @override
  String displayValueFor(String rawValue) => fruits[rawValue] ?? rawValue;

  @override
  Stream<List<FilterValueSuggestion>> watchValueSuggestions(
    GenericListViewModel<dynamic> vm,
    BuildContext context,
    String query,
  ) {
    final q = query.trim().toLowerCase();
    final rows = [
      for (final e in fruits.entries)
        if (q.isEmpty || e.value.toLowerCase().contains(q))
          FilterValueSuggestion(rawValue: e.key, displayLabel: e.value),
    ];
    final wait = delay;
    return wait == null
        ? Stream.value(rows)
        : Stream.fromFuture(Future.delayed(wait, () => rows));
  }
}

/// A key with exactly one value, applied the moment it is picked (Overdue).
class DirectKey extends FilterKey {
  DirectKey();

  String? added;

  @override
  String get id => 'overdue';

  @override
  String displayLabel(BuildContext context) => 'Overdue';

  @override
  FilterValueType get valueType => FilterValueType.enumeration;

  @override
  bool get singleValue => true;

  @override
  bool get acceptsTypedValue => false;

  @override
  String? get directApplyValue => 'true';

  @override
  bool isAtDefault(GenericListViewModel<dynamic> vm) => added == null;

  @override
  Iterable<FilterToken> tokensFrom(
    GenericListViewModel<dynamic> vm,
    BuildContext context,
  ) => const [];

  @override
  Stream<List<FilterValueSuggestion>> watchValueSuggestions(
    GenericListViewModel<dynamic> vm,
    BuildContext context,
    String query,
  ) => Stream.value(const []);

  @override
  Future<void> addValue(
    GenericListViewModel<dynamic> vm,
    String rawValue,
  ) async {
    added = rawValue;
  }

  @override
  Future<void> removeValue(
    GenericListViewModel<dynamic> vm,
    String rawValue,
  ) async {
    added = null;
  }
}

/// Pumps the wide field inside a nested Navigator that starts
/// [kHarnessSidebar] px in, in a box [fieldWidth] wide.
Future<void> pumpWideField(
  WidgetTester tester, {
  required GenericListViewModel<dynamic> vm,
  required List<FilterKey> keys,
  double fieldWidth = 700,
  Size surface = const Size(1280, 800),
  TextDirection textDirection = TextDirection.ltr,
  double top = 24,
}) async {
  tester.view.physicalSize = surface;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: buildInTheme(InTheme.light),
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: kTestSupportedLocales,
      home: Provider<Services>.value(
        value: FakeSearchServices(),
        child: Directionality(
          textDirection: textDirection,
          child: Row(
            // Physical order whatever the direction under test: the sidebar
            // is at the window's left in this harness either way.
            textDirection: TextDirection.ltr,
            children: [
              const SizedBox(width: kHarnessSidebar),
              Expanded(
                child: Navigator(
                  onGenerateRoute: (_) => MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      body: Align(
                        alignment: Alignment.topLeft,
                        child: Padding(
                          padding: EdgeInsets.only(left: 24, top: top),
                          child: SizedBox(
                            width: fieldWidth,
                            child: TokenSearchField(
                              vm: vm,
                              filterKeys: keys,
                              wide: true,
                              hintKey: 'search',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Finder get menuFinder => find.byType(FilterSuggestionMenu);
Finder get fieldFinder => find.byType(TokenSearchField);
Finder get inputFinder => find.byType(TextField);

/// Two pumps: the frame that builds and lays out the popup, and the one after
/// it, in which the rows it published are live for the keyboard.
Future<void> settleMenu(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

/// Lets a debounced search (and the reload it triggers) land.
Future<void> settleSearch(
  WidgetTester tester, [
  Duration debounce = Duration.zero,
]) async {
  await tester.pump(debounce + const Duration(milliseconds: 1));
  await tester.pump();
}
