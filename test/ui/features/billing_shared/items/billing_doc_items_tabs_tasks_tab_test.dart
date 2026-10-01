import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/default_items_tab_controller.dart';
import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/data/models/domain/billing/line_item_type.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/company_settings.dart';
import 'package:admin/data/models/domain/product.dart';
import 'package:admin/data/models/domain/tax_rate.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/company_repository.dart';
import 'package:admin/data/repositories/invoice_repository.dart';
import 'package:admin/data/repositories/product_repository.dart';
import 'package:admin/data/repositories/settings_repository.dart';
import 'package:admin/data/repositories/tax_rate_repository.dart';
import 'package:admin/data/services/invoices_api.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/ui/features/billing_shared/items/billing_doc_items_tabs.dart';
import 'package:admin/ui/features/billing_shared/line_item_editor/line_item_editor.dart';
import 'package:admin/ui/features/invoices/view_models/invoice_edit_view_model.dart';
import 'package:admin/utils/formatting.dart';

import '../../../../_localization_helper.dart';

/// A beta user could not find the Products → Tasks switch on a new invoice,
/// and turning on Settings → Task Settings → "Show Tasks Table" changed
/// nothing: the tabs only ever appeared once a task had been PICKED, the
/// setting was stored and never read, and every row the editor created was a
/// `standard` (product) line — so an hourly line, the one the server prints in
/// the PDF's task table, could not be typed at all.
class _FakeInvoicesApi implements InvoicesApi {
  @override
  Object? noSuchMethod(Invocation i) => throw UnimplementedError();
}

/// Replays the current company to every new subscriber and pushes later
/// changes to all of them — the shape of a Drift watch. The tabs widget and
/// each per-tab editor subscribe at different times, so a plain broadcast
/// stream would leave a late editor with no company at all.
class _CompanyRepo implements CompanyRepository {
  _CompanyRepo(this.current);

  Company current;
  final _changes = StreamController<Company?>.broadcast();

  void emit(Company next) {
    current = next;
    _changes.add(next);
  }

  /// The repo's first-frame seed. Null models a cold cache, where the
  /// setting only arrives with the watch's first (async) event.
  bool seeded = false;

  @override
  Company? peek({required String companyId, required String id}) =>
      seeded ? current : null;

  @override
  Stream<Company?> watchCompany(String companyId) =>
      Stream<Company?>.multi((c) {
        c.add(current);
        final sub = _changes.stream.listen(c.add);
        c.onCancel = sub.cancel;
      });

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError(i.memberName.toString());
}

class _StubProductRepo implements ProductRepository {
  @override
  Stream<List<Product>> watchPage({
    required String companyId,
    int loadedPages = 1,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    String sortField = '',
    bool sortAscending = true,
    Map<int, Set<String>> customFilters = const {},
    String? groupField,
    String? badgeModeId,
  }) => const Stream<List<Product>>.empty();

  @override
  Future<bool> ensurePageLoaded({
    required String companyId,
    required int page,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    Map<String, Set<String>> extraFilters = const {},
    bool ignoreCursor = false,
  }) async => false;

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError(i.memberName.toString());
}

class _StubTaxRateRepo implements TaxRateRepository {
  @override
  Stream<List<TaxRate>> watchAll({required String companyId}) =>
      Stream<List<TaxRate>>.value(const <TaxRate>[]).asBroadcastStream();

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError(i.memberName.toString());
}

class _StubAuth implements AuthRepository {
  @override
  final ValueListenable<AuthSession?> session = ValueNotifier<AuthSession?>(
    null,
  );

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError(i.memberName.toString());
}

class _FakeServices implements Services {
  _FakeServices(this.company, {bool prefersTasks = false})
    : defaultItemsTab = _ProductsFirst(prefersTasks: prefersTasks);

  // The tab a document opens on when its lines don't decide (React #3355).
  @override
  final DefaultItemsTabController defaultItemsTab;
  @override
  final AuthRepository auth = _StubAuth();

  @override
  final CompanyRepository company;

  @override
  final ProductRepository products = _StubProductRepo();

  @override
  final TaxRateRepository taxRates = _StubTaxRateRepo();

  @override
  Formatter? formatterIfReady(String companyId) => null;

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError(i.memberName.toString());
}

Company _company({
  bool showTasksTable = true,
  Map<String, dynamic>? translations,
}) => Company(
  id: 'co',
  showTasksTable: showTasksTable,
  settings: CompanySettings(translations: translations),
);

LineItem _product() =>
    emptyLineItem().copyWith(productKey: 'WIDGET', notes: 'product note');

/// Free-form hourly: `type_id` 2 with no task behind it — what the Tasks tab
/// creates, and what React / admin-portal write.
LineItem _hourly() => emptyLineItem().copyWith(
  productKey: 'Consulting',
  notes: 'hourly note',
  cost: Decimal.fromInt(50),
  quantity: Decimal.fromInt(2),
  typeId: LineItemType.task,
);

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  InvoiceEditViewModel makeVm(List<LineItem> lines) => InvoiceEditViewModel(
    repo: InvoiceRepository(
      db: db,
      api: _FakeInvoicesApi(),
      settings: SettingsRepository(db: db),
    ),
    companyId: 'co',
    clientRequiredMessage: 'client required',
    crossClientLineItemsMessage: '',
    partialInvalidMessage: '',
    existing: emptyInvoice().copyWith(id: 'inv1', lineItems: lines),
  );

  /// [width] ≥ 700 renders the desktop table; below it, the phone cards.
  Future<InvoiceEditViewModel> pump(
    WidgetTester tester, {
    required _CompanyRepo repo,
    List<LineItem> lines = const [],
    bool offerTasksTab = true,
    double width = 1200,
    double minHeight = 0,
    InvoiceEditViewModel? reuse,
    bool settle = true,
    bool prefersTasks = false,
  }) async {
    tester.view.physicalSize = Size(width + 200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // [reuse] models the narrow layout's Items page being rebuilt around the
    // SAME document: its `TabBarView` disposes the page, the VM lives on.
    final vm = reuse ?? makeVm(lines);
    if (reuse == null) addTearDown(vm.dispose);

    await tester.pumpWidget(
      Provider<Services>.value(
        value: _FakeServices(repo, prefersTasks: prefersTasks),
        child: MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: width,
              child: SingleChildScrollView(
                // Stands in for `BillingDocEditItemsBody`, which sets the
                // viewport height on the narrow branch and 0 on the wide one.
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: minHeight),
                  child: AnimatedBuilder(
                    animation: vm,
                    builder: (context, _) => BillingDocItemsTabs(
                      vm: vm,
                      companyId: 'co',
                      lineItems: vm.draft.lineItems,
                      onChanged: vm.replaceLineItems,
                      newItemFactory: emptyLineItem,
                      rowErrors: null,
                      onPickItems: () {},
                      offerTasksTab: offerTasksTab,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // The company arrives a microtask after the first frame, as from Drift.
    if (settle) await tester.pump(const Duration(milliseconds: 50));
    return vm;
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  int activeTab(WidgetTester tester) =>
      tester.widget<TabBar>(find.byType(TabBar)).controller!.index;

  group('which documents get a Tasks tab', () {
    testWidgets('setting off, no hourly line → no tabs', (tester) async {
      await pump(
        tester,
        repo: _CompanyRepo(_company(showTasksTable: false)),
        lines: [_product()],
      );
      expect(find.byType(TabBar), findsNothing);
      await unmount(tester);
    });

    testWidgets('"Show Tasks Table" on → Products | Tasks on a new invoice', (
      tester,
    ) async {
      await pump(tester, repo: _CompanyRepo(_company()));
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.text('Products'), findsOneWidget);
      expect(find.text('Tasks'), findsOneWidget);
      expect(activeTab(tester), 0, reason: 'a new document opens on Products');
      await unmount(tester);
    });

    testWidgets('a document that does not offer it (credit) → no tabs', (
      tester,
    ) async {
      await pump(tester, repo: _CompanyRepo(_company()), offerTasksTab: false);
      expect(find.byType(TabBar), findsNothing);
      await unmount(tester);
    });

    testWidgets('a free-form hourly line (no task_id) is a Tasks line', (
      tester,
    ) async {
      // Keyed on the type, not only the task link: React and admin-portal
      // write type-2 lines with no task behind them, and they used to land
      // in Products here.
      await pump(
        tester,
        repo: _CompanyRepo(_company(showTasksTable: false)),
        lines: [_product(), _hourly()],
        offerTasksTab: false,
      );
      expect(find.text('Products (1)'), findsOneWidget);
      expect(find.text('Tasks (1)'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('which tab is showing', () {
    testWidgets('a document that bills only hours opens on Tasks', (
      tester,
    ) async {
      final vm = await pump(
        tester,
        repo: _CompanyRepo(_company(showTasksTable: false)),
        lines: [_hourly()],
      );
      expect(activeTab(tester), 1);

      // ...at mount only: adding and then removing a product line must not
      // move the user.
      await tester.tap(find.textContaining('Products'));
      await tester.pumpAndSettle();
      vm.replaceLineItems([...vm.draft.lineItems, _product()]);
      await tester.pump();
      vm.replaceLineItems([_hourly()]);
      await tester.pump();
      expect(activeTab(tester), 0);
      await unmount(tester);
    });

    // React #3355: the lines decide by majority — counted per visible tab
    // (this app, unlike React, has an Expenses tab); a tie or no lines falls
    // to Device Settings → Default tab.
    testWidgets('a document that mostly bills hours opens on Tasks', (
      tester,
    ) async {
      await pump(
        tester,
        repo: _CompanyRepo(_company()),
        lines: [_hourly(), _hourly(), _product()],
      );
      expect(activeTab(tester), 1);
      await unmount(tester);
    });

    testWidgets('task and expense lines never open an empty Products tab', (
      tester,
    ) async {
      LineItem expense(String id) => emptyLineItem().copyWith(
        productKey: 'Taxi',
        cost: Decimal.fromInt(30),
        expenseId: id,
      );
      await pump(
        tester,
        repo: _CompanyRepo(_company()),
        lines: [
          _hourly(),
          _hourly(),
          expense('e1'),
          expense('e2'),
          expense('e3'),
        ],
      );
      // Products / Tasks / Expenses — the expenses hold the most lines.
      expect(find.text('Expenses (3)'), findsOneWidget);
      expect(activeTab(tester), 2);
      await unmount(tester);
    });

    testWidgets('a new document opens on the default tab', (tester) async {
      await pump(tester, repo: _CompanyRepo(_company()), prefersTasks: true);
      expect(activeTab(tester), 1);
      await unmount(tester);
    });

    testWidgets('a tie falls through to the default tab', (tester) async {
      await pump(
        tester,
        repo: _CompanyRepo(_company()),
        lines: [_hourly(), _product()],
        prefersTasks: true,
      );
      expect(activeTab(tester), 1);
      await unmount(tester);
    });

    testWidgets('the default never opens a Tasks tab that is not shown', (
      tester,
    ) async {
      await pump(
        tester,
        repo: _CompanyRepo(_company(showTasksTable: false)),
        lines: [_product()],
        prefersTasks: true,
      );
      expect(find.byType(TabBar), findsNothing);
      await unmount(tester);
    });

    testWidgets('picked tasks bring the view with them', (tester) async {
      // The picker (FAB / ⌘N / Add Items) adds task lines from wherever the
      // user is; staying on Products hid the result of the pick.
      final vm = await pump(
        tester,
        repo: _CompanyRepo(_company()),
        lines: [_product()],
      );
      expect(activeTab(tester), 0);

      vm.replaceLineItems([
        ...vm.draft.lineItems,
        _hourly().copyWith(taskId: 'task-1'),
      ]);
      await tester.pumpAndSettle();
      expect(activeTab(tester), 1);
      await unmount(tester);
    });

    testWidgets('the tab survives the Items page being rebuilt', (
      tester,
    ) async {
      // The narrow layout's TabBarView disposes the Items page when the user
      // moves to Notes. The Tasks tab here has no line yet, so on a cold
      // cache (no `peek` seed) it only exists once the company's setting
      // lands — after the first frame — and the remembered tab has to wait.
      final repo = _CompanyRepo(_company());
      final vm = await pump(tester, repo: repo);
      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();
      await unmount(tester);

      await pump(tester, repo: repo, reuse: vm);
      expect(activeTab(tester), 1);
      await unmount(tester);

      // And with the seed, it's there on the very first frame.
      repo.seeded = true;
      await pump(tester, repo: repo, reuse: vm, settle: false);
      expect(activeTab(tester), 1);
      await unmount(tester);
    });

    testWidgets('an edit made in a tab never moves the view', (tester) async {
      // Only lines added from outside (the picker) are followed. A row typed
      // in Tasks commits on a 250 ms debounce; switching to Products inside
      // that window used to have the commit drag the user straight back.
      final vm = await pump(tester, repo: _CompanyRepo(_company()));
      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Description'),
        'Design review',
      );
      await tester.pump(Duration.zero);
      await tester.tap(find.text('Products'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(vm.draft.lineItems.single.typeId, LineItemType.task);
      expect(find.text('Tasks (1)'), findsOneWidget);
      expect(activeTab(tester), 0);
      await unmount(tester);
    });

    testWidgets('a cloned expense row stays in the Expenses tab', (
      tester,
    ) async {
      // This app's expense lines are `standard` + `expense_id`, so dropping
      // the link on a clone made the copy a product line: it vanished from
      // the tab it was cloned in.
      final vm = await pump(
        tester,
        repo: _CompanyRepo(_company(showTasksTable: false)),
        lines: [
          _product(),
          emptyLineItem().copyWith(
            productKey: 'Taxi',
            notes: 'expense note',
            cost: Decimal.fromInt(30),
            expenseId: 'exp-1',
          ),
        ],
      );
      await tester.tap(find.text('Expenses (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clone'));
      await tester.pumpAndSettle();

      expect(find.text('Expenses (2)'), findsOneWidget);
      expect(find.text('Products (1)'), findsOneWidget);
      expect(activeTab(tester), 1);
      final copy = vm.draft.lineItems.last;
      expect(copy.productKey, 'Taxi');
      expect(copy.expenseId, isNull, reason: 'a copy is not the expense');
      expect(copy.typeId, LineItemType.expense);
      await unmount(tester);
    });

    testWidgets('only the tabs that exist get an editor', (tester) async {
      // Each editor opens its own company / currency / product watches, so
      // an Expenses editor with no Expenses tab was pure cost.
      await pump(tester, repo: _CompanyRepo(_company()), lines: [_product()]);
      expect(find.byType(TabBar), findsOneWidget);
      expect(
        find.byType(LineItemEditor, skipOffstage: false),
        findsNWidgets(2),
      );
      await unmount(tester);
    });
  });

  group('the Tasks tab is hourly (desktop table)', () {
    testWidgets('a row typed there is type 2, and stays in the tab', (
      tester,
    ) async {
      final vm = await pump(tester, repo: _CompanyRepo(_company()));
      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();

      // Service / Rate / Hours — the columns of the PDF's task table.
      expect(find.text('SERVICE'), findsOneWidget);
      expect(find.text('RATE'), findsOneWidget);
      expect(find.text('HOURS'), findsOneWidget);
      expect(find.text('UNIT COST'), findsNothing);

      // Type into the always-present blank row, past the 250 ms debounce.
      await tester.enterText(
        find.widgetWithText(TextField, 'Description'),
        'Design review',
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(vm.draft.lineItems, hasLength(1));
      expect(vm.draft.lineItems.single.typeId, LineItemType.task);
      expect(find.text('Tasks (1)'), findsOneWidget);
      expect(activeTab(tester), 1);

      // Its Hours cell takes a duration: `1:30` is an hour and a half, not
      // the 130 hours `parseDecimal` made of it.
      final hours = find.byWidgetPredicate(
        (w) => w is TextField && w.controller?.text == '1',
      );
      await tester.enterText(hours.first, '1:30');
      await tester.pump(const Duration(milliseconds: 300));
      expect(vm.draft.lineItems.single.quantity, Decimal.parse('1.5'));
      await unmount(tester);
    });

    testWidgets("a company's Custom Label for hours wins", (tester) async {
      await pump(
        tester,
        repo: _CompanyRepo(_company(translations: const {'hours': 'Time'})),
      );
      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();
      expect(find.text('TIME'), findsOneWidget);
      expect(find.text('HOURS'), findsNothing);
      await unmount(tester);
    });

    testWidgets('the setting landing late keeps an in-flight product edit', (
      tester,
    ) async {
      // The tab bar arriving must insert ABOVE the products editor, not
      // remount it: a remount disposes the rows and drops a cell edit still
      // inside its 250 ms debounce.
      final repo = _CompanyRepo(_company(showTasksTable: false));
      final vm = await pump(tester, repo: repo, lines: [_product()]);
      expect(find.byType(TabBar), findsNothing);

      await tester.enterText(
        find.widgetWithText(TextField, 'product note'),
        'EDITED',
      );
      await tester.pump(Duration.zero);

      repo.emit(_company());
      await tester.pump(Duration.zero);
      expect(find.byType(TabBar), findsOneWidget);

      vm.flushPendingEdits();
      expect(vm.draft.lineItems.single.notes, 'EDITED');
      await unmount(tester);
    });
  });

  group('the Tasks tab is hourly (phone)', () {
    testWidgets('Add Line asks for Service / Rate / Hours', (tester) async {
      final vm = await pump(tester, repo: _CompanyRepo(_company()), width: 400);
      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Add Line'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Service'),
        'Consulting',
      );
      await tester.enterText(find.widgetWithText(TextField, 'Rate'), '80');
      await tester.enterText(find.widgetWithText(TextField, 'Hours'), '0:45');
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      final line = vm.draft.lineItems.single;
      expect(line.typeId, LineItemType.task);
      expect(line.productKey, 'Consulting');
      expect(line.cost, Decimal.fromInt(80));
      expect(line.quantity, Decimal.parse('0.75'));
      await unmount(tester);
    });
  });

  group('layout under the tabs', () {
    testWidgets('the phone empty state still centres in the viewport', (
      tester,
    ) async {
      // With the setting on, EVERY new invoice on a phone renders the tabbed
      // branch — and an `IndexedStack` loosened the minHeight the empty state
      // centres in (#141), parking it right under the tab bar.
      await pump(
        tester,
        repo: _CompanyRepo(_company()),
        width: 400,
        minHeight: 700,
      );
      final tabBarBottom = tester.getBottomLeft(find.byType(TabBar)).dy;
      final emptyY = tester.getCenter(find.text('No line items yet')).dy;
      expect(emptyY, greaterThan(tabBarBottom + 200));
      await unmount(tester);
    });

    testWidgets('a short tab is not as tall as the longest one', (
      tester,
    ) async {
      // An `IndexedStack` sizes to its TALLEST child, so one hourly line sat
      // in a box as tall as eight product rows.
      await pump(
        tester,
        repo: _CompanyRepo(_company()),
        lines: [for (var i = 0; i < 8; i++) _product(), _hourly()],
      );
      final onProducts = tester.getSize(find.byType(BillingDocItemsTabs));
      await tester.tap(find.textContaining('Tasks'));
      await tester.pumpAndSettle();
      final onTasks = tester.getSize(find.byType(BillingDocItemsTabs));
      expect(onTasks.height, lessThan(onProducts.height - 100));
      await unmount(tester);
    });
  });

  test('Save strips blank rows wherever they sit, not only at the end', () {
    // Each tab appends its new rows to the END of the full list, so a blank
    // row added in Tasks and a typed one in Products leave the blank one
    // mid-list — and it went to the server as an empty task-table line.
    final vm = makeVm([
      _product(),
      emptyLineItem().copyWith(typeId: LineItemType.task),
      _hourly(),
      emptyLineItem(),
    ]);
    addTearDown(vm.dispose);
    vm.stripEmptyLineItems();
    expect(vm.draft.lineItems.map((li) => li.notes), [
      'product note',
      'hourly note',
    ]);
  });
}

class _ProductsFirst implements DefaultItemsTabController {
  _ProductsFirst({this.prefersTasks = false});

  @override
  final bool prefersTasks;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}
