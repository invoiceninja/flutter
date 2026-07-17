import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/company_settings.dart';
import 'package:admin/data/models/domain/enabled_modules.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/client_repository.dart';
import 'package:admin/data/repositories/company_repository.dart';
import 'package:admin/data/services/clients_api.dart';
import 'package:admin/data/services/companies_api.dart';
import 'package:admin/utils/formatting.dart';
import 'package:admin/ui/core/unsaved_changes/unsaved_changes_guard.dart';
import 'package:admin/ui/features/settings/state/settings_level_controller.dart';
import 'package:admin/ui/features/settings/view_models/generated_numbers_view_model.dart';
import 'package:admin/ui/features/settings/views/advanced/e_invoice/e_invoice_constants.dart';
import 'package:admin/ui/features/settings/views/advanced/generated_numbers/generated_numbers_shell.dart';

import '../../../../../../_localization_helper.dart';

/// Stand-in [CompanyRepository] that emits a single [Company] on
/// `watchCompany`, mirroring the helper from `custom_fields_shell_test.dart`.
class _StubCompanyRepo extends CompanyRepository {
  _StubCompanyRepo({
    required super.db,
    required super.api,
    required this.company,
  });

  final Company company;
  final _controllers = <String, StreamController<Company?>>{};

  /// Set when `updateCompany` is invoked — lets a test assert that an aborted
  /// save (e.g. blocked by `preSaveError`) never reached the write path.
  bool updateCompanyCalled = false;

  @override
  Stream<Company?> watchCompany(String companyId) {
    final c = _controllers.putIfAbsent(
      companyId,
      StreamController<Company?>.broadcast,
    );
    Future.microtask(() {
      if (!c.isClosed) c.add(company);
    });
    return c.stream;
  }

  @override
  Future<void> refresh(String companyId) async {}

  @override
  Future<void> updateCompany({
    required Company draft,
    Map<String, dynamic>? extraOutboxPayload,
  }) async {
    updateCompanyCalled = true;
  }
}

class _FakeCompaniesApi implements CompaniesApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeClientsApi implements ClientsApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeAuth implements AuthRepository {
  _FakeAuth(this._session);
  final ValueNotifier<AuthSession?> _session;
  @override
  ValueListenable<AuthSession?> get session => _session;
  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _FakeServices implements Services {
  _FakeServices({
    required this.auth,
    required this.company,
    required this.clients,
    required this.db,
    required this.settingsLevel,
    required this.unsavedChangesGuard,
  });
  @override
  final AuthRepository auth;
  @override
  final CompanyRepository company;
  @override
  final ClientRepository clients;
  @override
  final AppDatabase db;
  @override
  final SettingsLevelController settingsLevel;
  @override
  final UnsavedChangesGuard unsavedChangesGuard;

  // The Settings tab body calls `services.formatterFor` in initState (with an
  // `onError` handler) so the `Next Reset` date field can render in the
  // user's date format. Returning a failed future here exercises the
  // production failure path — the date field stays hidden, the rest of the
  // form continues to work.
  @override
  Future<Formatter> formatterFor(String companyId) =>
      Future.error(StateError('statics not stubbed in this test'));

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

AuthSession _session() => const AuthSession(
  baseUrl: 'https://example.test',
  isHosted: false,
  accountId: 'acct',
  companies: [],
  currentCompanyId: 'co-A',
  plan: 'pro',
);

int _allEntityModules() =>
    EnabledModule.invoices.bitmask |
    EnabledModule.recurringInvoices.bitmask |
    EnabledModule.quotes.bitmask |
    EnabledModule.credits.bitmask |
    EnabledModule.projects.bitmask |
    EnabledModule.tasks.bitmask |
    EnabledModule.vendors.bitmask |
    EnabledModule.purchaseOrders.bitmask |
    EnabledModule.expenses.bitmask |
    EnabledModule.recurringExpenses.bitmask;

/// Mount the shell behind a minimal GoRouter so `context.go` calls work.
/// Default location is the bare URL — that matches the controller's
/// initial index 0, so the shell's post-frame `animateTo` is a no-op
/// (otherwise the TabBar's scroll viewport, which hasn't been laid out
/// in the first frame, blows up with a null `viewportDimension`).
/// The Settings body's `formatterFor` call surfaces as an async error
/// against the unstubbed `services.statics`; the body swallows it and
/// the date field stays hidden — exactly the production failure mode.
Widget _host({
  required Services services,
  String initialLocation = '/settings/generated_numbers',
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/settings/generated_numbers',
        builder: (_, _) => const GeneratedNumbersShell(),
        routes: [
          GoRoute(
            path: ':tab',
            builder: (_, state) =>
                GeneratedNumbersShell(initialTab: state.pathParameters['tab']),
          ),
        ],
      ),
    ],
  );
  return MaterialApp.router(
    theme: buildInTheme(InTheme.light),
    localizationsDelegates: kTestLocalizationsDelegates,
    supportedLocales: kTestSupportedLocales,
    routerConfig: router,
    builder: (_, child) => MultiProvider(
      providers: [
        Provider<Services>.value(value: services),
        ChangeNotifierProvider<SettingsLevelController>.value(
          value: services.settingsLevel,
        ),
      ],
      child: child ?? const SizedBox.shrink(),
    ),
  );
}

void main() {
  late AppDatabase db;
  late _FakeCompaniesApi companiesApi;
  late _FakeClientsApi clientsApi;
  late ClientRepository clientRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    companiesApi = _FakeCompaniesApi();
    clientsApi = _FakeClientsApi();
    clientRepo = ClientRepository(db: db, api: clientsApi);
  });

  tearDown(() async {
    await db.close();
  });

  Services makeServices({required Company company}) {
    final repo = _StubCompanyRepo(db: db, api: companiesApi, company: company);
    return _FakeServices(
      auth: _FakeAuth(ValueNotifier(_session())),
      company: repo,
      clients: clientRepo,
      db: db,
      settingsLevel: SettingsLevelController(),
      unsavedChangesGuard: UnsavedChangesGuard(),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();
  }

  // Open a chip-bearing entity tab by tapping it. Loads the bare URL first
  // (Settings tab, index 0 — matches the controller's initial index, so the
  // shell's post-frame `animateTo` is a no-op), then taps the target tab once
  // the scrollable TabBar is laid out, avoiding the un-laid-out-viewport crash
  // that a non-zero deep link triggers (see the `_host` doc). Callers keep the
  // tab list short so the target stays on-screen.
  Future<void> pumpOnTab(
    WidgetTester tester, {
    required Company company,
    required String tabLabel,
  }) async {
    await tester.pumpWidget(_host(services: makeServices(company: company)));
    await settle(tester);
    await tester.tap(find.widgetWithText(Tab, tabLabel));
    await tester.pumpAndSettle();
  }

  testWidgets('all entity modules enabled → 13 tabs visible', (tester) async {
    final services = makeServices(
      company: Company(id: 'co-A', enabledModules: _allEntityModules()),
    );
    await tester.pumpWidget(_host(services: services));
    await settle(tester);

    // 13 tabs in display order. Text is the localized label.
    for (final label in const [
      'Settings',
      'Clients',
      'Invoices',
      'Recurring Invoices',
      'Payments',
      'Quotes',
      'Credits',
      'Projects',
      'Tasks',
      'Vendors',
      'Purchase Orders',
      'Expenses',
      'Recurring Expenses',
    ]) {
      expect(
        find.descendant(of: find.byType(Tab), matching: find.text(label)),
        findsOneWidget,
        reason: 'expected tab "$label" to be visible',
      );
    }

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('enabledModules = 0 → only Settings + Clients tabs render', (
    tester,
  ) async {
    final services = makeServices(
      company: const Company(id: 'co-A', enabledModules: 0),
    );
    await tester.pumpWidget(_host(services: services));
    await settle(tester);

    // Always-visible tabs.
    for (final label in const ['Settings', 'Clients']) {
      expect(
        find.descendant(of: find.byType(Tab), matching: find.text(label)),
        findsOneWidget,
      );
    }
    // Module-gated tabs should be absent.
    for (final label in const [
      'Invoices',
      'Recurring Invoices',
      'Payments',
      'Quotes',
      'Credits',
      'Projects',
      'Tasks',
      'Vendors',
      'Purchase Orders',
      'Expenses',
      'Recurring Expenses',
    ]) {
      expect(
        find.descendant(of: find.byType(Tab), matching: find.text(label)),
        findsNothing,
        reason: 'tab "$label" should be hidden when its module is disabled',
      );
    }

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'invoices module on without quotes/credits → no Payments tab gating bug',
    (tester) async {
      // Payments tab is gated on EnabledModule.invoices (mirroring React's
      // "payment numbers depend on invoices being on"). This regression-test
      // pins that behavior so a future drive-by edit doesn't silently lose
      // the Payments tab when only the Invoices module is on.
      final services = makeServices(
        company: Company(
          id: 'co-A',
          enabledModules: EnabledModule.invoices.bitmask,
        ),
      );
      await tester.pumpWidget(_host(services: services));
      await settle(tester);

      for (final label in const [
        'Settings',
        'Clients',
        'Invoices',
        'Payments',
      ]) {
        expect(
          find.descendant(of: find.byType(Tab), matching: find.text(label)),
          findsOneWidget,
        );
      }
      expect(
        find.descendant(of: find.byType(Tab), matching: find.text('Quotes')),
        findsNothing,
      );

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('deep link to a hidden tab falls back to a visible tab', (
    tester,
  ) async {
    // Tasks module disabled but URL targets `/tasks`.
    final services = makeServices(
      company: const Company(id: 'co-A', enabledModules: 0),
    );
    await tester.pumpWidget(
      _host(
        services: services,
        initialLocation: '/settings/generated_numbers/tasks',
      ),
    );
    await settle(tester);

    expect(
      find.descendant(of: find.byType(Tab), matching: find.text('Tasks')),
      findsNothing,
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  // The Clients tab (modules off → only Settings + Clients tabs, and Settings
  // has no chips) isolates the Clients body's chips, so a token assertion can't
  // collide with another entity tab.
  testWidgets(
    'variable chips use {\$token} format and tapping one inserts it',
    (tester) async {
      await pumpOnTab(
        tester,
        company: const Company(id: 'co-A', enabledModules: 0),
        tabLabel: 'Clients',
      );

      // Brace-dollar (matches the legacy apps + the inserted token), not the
      // old dollar-brace label.
      expect(find.widgetWithText(ActionChip, '{\$counter}'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, '\${counter}'), findsNothing);

      // Tapping splices the token into the pattern field. Read the controller
      // directly: after insertion the label `{$counter}` also appears in the
      // field, so a bare find.text would match both the chip and the field.
      await tester.tap(find.widgetWithText(ActionChip, '{\$counter}'));
      await tester.pumpAndSettle();

      final patternField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Number Pattern'),
      );
      expect(patternField.controller!.text, contains('{\$counter}'));

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('tapping multiple chips appends rather than replacing', (
    tester,
  ) async {
    // Guards the splice/append logic (each chip inserts at the caret left by
    // the previous one). The macOS IME select-all echo that this protects
    // against in production isn't emitted by the headless test env, so the
    // echo fix itself is verified manually — but this still catches a
    // regression to "replace" semantics.
    await pumpOnTab(
      tester,
      company: const Company(id: 'co-A', enabledModules: 0),
      tabLabel: 'Clients',
    );

    await tester.tap(find.widgetWithText(ActionChip, '{\$counter}'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ActionChip, '{\$year}'));
    await tester.pumpAndSettle();

    final patternField = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Number Pattern'),
    );
    expect(patternField.controller!.text, '{\$counter}{\$year}');

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('shows a live number preview that reacts to chip taps', (
    tester,
  ) async {
    await pumpOnTab(
      tester,
      company: const Company(id: 'co-A', enabledModules: 0),
      tabLabel: 'Clients',
    );

    SelectableText previewBox() =>
        tester.widget<SelectableText>(find.byType(SelectableText));

    // Caption + initial value: empty pattern, counter null→1, padding null→4.
    expect(find.text('Preview'), findsOneWidget);
    expect(previewBox().data, '0001');

    // Tapping a chip flows through the host and recomputes the preview.
    // The `{$year}` pattern has no counter token, so the backend (and now the
    // preview — confirmed on the demo server) appends the padded counter.
    await tester.tap(find.widgetWithText(ActionChip, '{\$year}'));
    await tester.pumpAndSettle();
    expect(previewBox().data, '${DateTime.now().year}0001');

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('user custom-field chip shows only when the field is active', (
    tester,
  ) async {
    // Inactive: no `user1` label configured → chip hidden.
    await pumpOnTab(
      tester,
      company: const Company(id: 'co-A', enabledModules: 0),
      tabLabel: 'Clients',
    );
    expect(find.widgetWithText(ActionChip, '{\$user_custom1}'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());

    // Active: `user1` has a label → chip shown, with the label as its tooltip.
    await pumpOnTab(
      tester,
      company: const Company(
        id: 'co-A',
        enabledModules: 0,
        customFields: {'user1': 'Badge'},
      ),
      tabLabel: 'Clients',
    );
    final chip = find.widgetWithText(ActionChip, '{\$user_custom1}');
    expect(chip, findsOneWidget);
    expect(tester.widget<ActionChip>(chip).tooltip, 'Badge');

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('client custom-field chip shows only when the field is active', (
    tester,
  ) async {
    // Quotes tab carries client tokens; it's the last tab and its only
    // neighbor (Clients) has no client_custom chip, so no token collision.
    await pumpOnTab(
      tester,
      company: Company(
        id: 'co-A',
        enabledModules: EnabledModule.quotes.bitmask,
      ),
      tabLabel: 'Quotes',
    );
    expect(find.widgetWithText(ActionChip, '{\$client_custom1}'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());

    await pumpOnTab(
      tester,
      company: Company(
        id: 'co-A',
        enabledModules: EnabledModule.quotes.bitmask,
        customFields: const {'client1': 'Region'},
      ),
      tabLabel: 'Quotes',
    );
    expect(
      find.widgetWithText(ActionChip, '{\$client_custom1}'),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  // The full vendor token set ({$vendor_number} + {$vendor_custom*}) is
  // backend-substituted only for Expense entities (GeneratesCounter
  // .applyNumberPattern gates on `instanceof Expense`); {$vendor_id_number}
  // also applies to a Vendor entity (covered by the Vendors-tab test below).
  // Purchase orders and recurring expenses must NOT offer these chips, or
  // users would build patterns whose {$vendor_*} tokens render literally.
  testWidgets(
    'vendor token chips show on Expenses only, not PO / Recurring Expenses',
    (tester) async {
      final vendorChip = find.widgetWithText(ActionChip, '{\$vendor_number}');

      // Expenses → chip present (the one entity the backend substitutes).
      await pumpOnTab(
        tester,
        company: Company(
          id: 'co-A',
          enabledModules: EnabledModule.expenses.bitmask,
        ),
        tabLabel: 'Expenses',
      );
      expect(vendorChip, findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());

      // Purchase Orders → chip absent.
      await pumpOnTab(
        tester,
        company: Company(
          id: 'co-A',
          enabledModules: EnabledModule.purchaseOrders.bitmask,
        ),
        tabLabel: 'Purchase Orders',
      );
      expect(vendorChip, findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());

      // Recurring Expenses → chip absent.
      await pumpOnTab(
        tester,
        company: Company(
          id: 'co-A',
          enabledModules: EnabledModule.recurringExpenses.bitmask,
        ),
        tabLabel: 'Recurring Expenses',
      );
      expect(vendorChip, findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  // VeriFactu (Spain's tax-authority e-invoicing) locks `counter_number_applied`
  // server-side. The Settings tab mirrors React (`Settings.tsx:109`,
  // `|| verifactuEnabled`) by greying the Generate Number dropdown — a null
  // `onChanged` on its DropdownButtonFormField. The Settings tab is index 0, so
  // it renders without tapping any tab.
  DropdownButtonFormField<String> generateNumberField(WidgetTester tester) =>
      tester.widget<DropdownButtonFormField<String>>(
        find.widgetWithText(DropdownButtonFormField<String>, 'Generate Number'),
      );

  testWidgets('VeriFactu disables the Generate Number dropdown', (
    tester,
  ) async {
    final services = makeServices(
      company: const Company(
        id: 'co-A',
        enabledModules: 0,
        settings: CompanySettings(eInvoiceType: kEInvoiceTypeVERIFACTU),
      ),
    );
    await tester.pumpWidget(_host(services: services));
    await settle(tester);

    expect(generateNumberField(tester).onChanged, isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('non-VeriFactu leaves the Generate Number dropdown editable', (
    tester,
  ) async {
    final services = makeServices(
      company: const Company(id: 'co-A', enabledModules: 0),
    );
    await tester.pumpWidget(_host(services: services));
    await settle(tester);

    expect(generateNumberField(tester).onChanged, isNotNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  // Fix A — the legacy `{$client_counter}` guard restored as an inline error:
  // a pattern using the per-client counter without a distinguishing token would
  // mint duplicate numbers across clients, and the server doesn't reject it.
  testWidgets(
    '{\$client_counter} without a distinguisher shows an inline error',
    (tester) async {
      await pumpOnTab(
        tester,
        company: const Company(id: 'co-A', enabledModules: 0),
        tabLabel: 'Clients',
      );
      final fieldFinder = find.widgetWithText(TextField, 'Number Pattern');
      TextField field() => tester.widget<TextField>(fieldFinder);

      await tester.enterText(fieldFinder, r'{$client_counter}');
      await tester.pumpAndSettle();
      // `:`→`$` render → message mentions "$client_counter". Read the field's
      // errorText directly so the typed text isn't mistaken for the error.
      expect(field().decoration!.errorText, contains(r'$client_counter'));

      // Adding {$counter} resolves the collision → error clears.
      await tester.enterText(fieldFinder, r'{$client_counter}{$counter}');
      await tester.pumpAndSettle();
      expect(field().decoration!.errorText, isNull);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  // Fix A — the same guard hard-blocks the save via `preSaveError` (company
  // scope), so an invalid pattern never reaches the network.
  test('preSaveError blocks a {\$client_counter}-only pattern', () {
    final repo = _StubCompanyRepo(
      db: db,
      api: companiesApi,
      company: const Company(),
    );
    final vm = GeneratedNumbersViewModel(
      repo: repo,
      companyId: 'co-A',
      patternError: 'ERR',
    );
    addTearDown(vm.dispose);

    expect(
      vm.preSaveError(
        const Company(
          settings: CompanySettings(invoiceNumberPattern: r'{$client_counter}'),
        ),
      ),
      'ERR',
    );
    expect(
      vm.preSaveError(
        const Company(
          settings: CompanySettings(
            invoiceNumberPattern: r'{$client_counter}{$counter}',
          ),
        ),
      ),
      isNull,
    );
    expect(vm.preSaveError(const Company()), isNull);
  });

  // Fix A — verify the block is actually wired into the save path (not just the
  // preSaveError predicate): a violating draft must abort before the write, and
  // a valid one must still save through.
  test('save() aborts the write when a pattern is invalid', () async {
    final badRepo = _StubCompanyRepo(
      db: db,
      api: companiesApi,
      company: const Company(
        id: 'co-A',
        settings: CompanySettings(invoiceNumberPattern: r'{$client_counter}'),
      ),
    );
    final badVm = GeneratedNumbersViewModel(
      repo: badRepo,
      companyId: 'co-A',
      patternError: 'ERR',
    );
    addTearDown(badVm.dispose);
    await badVm.load();
    await pumpEventQueue(); // drain the watchCompany microtask → _draft set

    expect(await badVm.save(), isNull);
    expect(badRepo.updateCompanyCalled, isFalse);
    expect(badVm.submitError, 'ERR');

    // Control: a valid pattern saves through, proving the block is specific.
    final okRepo = _StubCompanyRepo(
      db: db,
      api: companiesApi,
      company: const Company(
        id: 'co-A',
        settings: CompanySettings(invoiceNumberPattern: r'{$counter}'),
      ),
    );
    final okVm = GeneratedNumbersViewModel(
      repo: okRepo,
      companyId: 'co-A',
      patternError: 'ERR',
    );
    addTearDown(okVm.dispose);
    await okVm.load();
    await pumpEventQueue();

    expect(await okVm.save(), isNotNull);
    expect(okRepo.updateCompanyCalled, isTrue);
  });

  // Fix B — Settings dropdowns fall back to the server defaults (4 / when_saved
  // / 0) when the value is unset, instead of rendering blank (matches React).
  testWidgets('Settings dropdowns show server defaults when unset', (
    tester,
  ) async {
    final services = makeServices(
      company: const Company(id: 'co-A', enabledModules: 0),
    );
    await tester.pumpWidget(_host(services: services));
    await settle(tester);

    DropdownButtonFormField<String> dd(String label) =>
        tester.widget<DropdownButtonFormField<String>>(
          find.widgetWithText(DropdownButtonFormField<String>, label),
        );
    expect(dd('Number Padding').initialValue, '4');
    expect(dd('Generate Number').initialValue, 'when_saved');
    expect(dd('Reset Counter').initialValue, '0');

    await tester.pumpWidget(const SizedBox.shrink());
  });

  // Fix C — the Vendors tab offers only {$vendor_id_number} (the backend
  // substitutes it for a Vendor entity); the Expense-only vendor tokens stay off.
  testWidgets('Vendors tab offers {\$vendor_id_number} only', (tester) async {
    await pumpOnTab(
      tester,
      company: Company(
        id: 'co-A',
        enabledModules: EnabledModule.vendors.bitmask,
      ),
      tabLabel: 'Vendors',
    );
    expect(
      find.widgetWithText(ActionChip, '{\$vendor_id_number}'),
      findsOneWidget,
    );
    expect(find.widgetWithText(ActionChip, '{\$vendor_number}'), findsNothing);

    // Tapping inserts it and the preview renders the sample id.
    await tester.tap(find.widgetWithText(ActionChip, '{\$vendor_id_number}'));
    await tester.pumpAndSettle();
    final patternField = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Number Pattern'),
    );
    expect(patternField.controller!.text, contains('{\$vendor_id_number}'));
    expect(
      tester.widget<SelectableText>(find.byType(SelectableText)).data,
      contains('ID-0001'),
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
