import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/product.dart';
import 'package:admin/data/models/domain/tax_rate.dart';
import 'package:admin/data/repositories/company_repository.dart';
import 'package:admin/data/repositories/invoice_repository.dart';
import 'package:admin/data/repositories/product_repository.dart';
import 'package:admin/data/repositories/tax_rate_repository.dart';
import 'package:admin/data/repositories/settings_repository.dart';
import 'package:admin/data/services/invoices_api.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/ui/features/billing_shared/items/billing_doc_items_tabs.dart';
import 'package:admin/ui/features/invoices/view_models/invoice_edit_view_model.dart';
import 'package:admin/utils/formatting.dart';

import '../../../../_localization_helper.dart';

/// Save flushes all three per-type editors through `addBeforeSaveHook`, and
/// `GenericEditViewModel.save()` runs those hooks in ONE synchronous loop.
/// `onChanged` writes through to `vm.draft` immediately, but the widget's
/// `lineItems` prop only catches up on the next frame — so merging each flushed
/// subset back into the PROPS made every hook start from the list as it was
/// before Save began, and the second flush silently discarded the first one's
/// edit. No error, no visual cue: the user's line-item change was simply gone.
class _FakeInvoicesApi implements InvoicesApi {
  @override
  Object? noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _StubCompanyRepo implements CompanyRepository {
  @override
  Stream<Company?> watchCompany(String companyId) =>
      Stream<Company?>.value(const Company(id: 'co')).asBroadcastStream();

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError(i.memberName.toString());
}

/// The desktop table's product typeahead and tax cell each open a repo watch.
/// Empty streams keep them inert without standing up the real graph.
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

class _FakeServices implements Services {
  @override
  final CompanyRepository company = _StubCompanyRepo();

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

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  // Distinct notes per row: all three editors are mounted at once inside the
  // IndexedStack, so a shared string would let a finder match the wrong cell.
  LineItem productRow() =>
      emptyLineItem().copyWith(productKey: 'WIDGET', notes: 'product note');
  LineItem taskRow() =>
      emptyLineItem().copyWith(taskId: 'task-1', notes: 'task note');

  testWidgets('a Save that flushes two tabs keeps both edits', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final vm = InvoiceEditViewModel(
      repo: InvoiceRepository(
        db: db,
        api: _FakeInvoicesApi(),
        settings: SettingsRepository(db: db),
      ),
      companyId: 'co',
      clientRequiredMessage: 'client required',
      crossClientLineItemsMessage: '',
      partialInvalidMessage: '',
      // No clientId: `save()` runs every before-save hook and then fails
      // `validate()` on `client_id`, returning before `performSave`. That
      // exercises exactly the hook loop with no repo call, no Drift write and
      // no fake-API throw to leave an unhandled async error behind.
      existing: emptyInvoice().copyWith(
        id: 'inv1',
        lineItems: [productRow(), taskRow()],
      ),
    );
    addTearDown(vm.dispose);

    await tester.pumpWidget(
      Provider<Services>.value(
        value: _FakeServices(),
        child: MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 1200, // ≥ 700 → the desktop table, which owns flushPending
              child: SingleChildScrollView(
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
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));

    // Products tab is active on mount. Type, then move to Tasks and type —
    // zero-duration pumps throughout so neither 250 ms cell debounce fires.
    await tester.enterText(
      find.widgetWithText(TextField, 'product note'),
      'PRODUCT EDIT',
    );
    await tester.pump(Duration.zero);

    await tester.tap(find.textContaining('Tasks'));
    await tester.pump(Duration.zero);

    await tester.enterText(
      find.widgetWithText(TextField, 'task note'),
      'TASK EDIT',
    );
    await tester.pump(Duration.zero);

    // Save: hook 1 flushes products, hook 2 flushes tasks.
    await vm.save();

    final notes = vm.draft.lineItems.map((li) => li.notes).toList();
    expect(
      notes,
      containsAll(<String>['PRODUCT EDIT', 'TASK EDIT']),
      reason: 'the tasks flush must not rebuild from a pre-Save list',
    );
    expect(vm.draft.lineItems, hasLength(2));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
