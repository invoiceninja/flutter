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
import 'package:admin/data/models/domain/enabled_modules.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/client_repository.dart';
import 'package:admin/data/repositories/company_repository.dart';
import 'package:admin/data/services/clients_api.dart';
import 'package:admin/data/services/companies_api.dart';
import 'package:admin/ui/core/unsaved_changes/unsaved_changes_guard.dart';
import 'package:admin/ui/features/settings/state/settings_level_controller.dart';
import 'package:admin/ui/features/settings/view_models/custom_fields_view_model.dart';
import 'package:admin/ui/features/settings/views/advanced/custom_fields/custom_fields_shell.dart';

import '../../../../../../_localization_helper.dart';

/// Stand-in [CompanyRepository]: emits a single [Company] on `watchCompany`
/// so the VM's `load()` flips `isLoaded` and the shell mounts its loaded
/// branch.
class _StubCompanyRepo extends CompanyRepository {
  _StubCompanyRepo({
    required super.db,
    required super.api,
    required this.company,
  });

  final Company company;
  final _controllers = <String, StreamController<Company?>>{};

  @override
  Stream<Company?> watchCompany(String companyId) {
    final c = _controllers.putIfAbsent(
      companyId,
      StreamController<Company?>.broadcast,
    );
    // Emit on the next microtask so the listener subscribed inside `load()`
    // sees the value.
    Future.microtask(() {
      if (!c.isClosed) c.add(company);
    });
    return c.stream;
  }

  @override
  Future<void> refresh(String companyId) async {}
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

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

AuthSession _session({
  String plan = 'pro',
  bool isHosted = false,
  bool isAdmin = true,
}) => AuthSession(
  baseUrl: 'https://example.test',
  isHosted: isHosted,
  accountId: 'acct',
  // A `co-A` company is required: editing is gated on the current company's
  // admin/owner role (mirrors React). Default admin so the persist tests can
  // type into enabled fields; the gating test flips `isAdmin: false`.
  companies: [
    AuthCompany(
      id: 'co-A',
      name: 'Co A',
      displayName: 'Co A',
      permissions: '',
      isAdmin: isAdmin,
      // Fixture: a privileged user is owner+admin (so the plan banner's
      // owner-gated "Manage Plan" CTA shows); a non-privileged user is neither.
      isOwner: isAdmin,
    ),
  ],
  currentCompanyId: 'co-A',
  plan: plan,
);

/// Bitmask combining the modules that map to a custom-fields tab —
/// Invoices/Payments (sharing the Invoices bit), Projects, Tasks, Vendors, and
/// Expenses. (Quotes/Credits have no tab — they reuse the Invoices fields.)
int _allModules() =>
    EnabledModule.invoices.bitmask |
    EnabledModule.projects.bitmask |
    EnabledModule.tasks.bitmask |
    EnabledModule.vendors.bitmask |
    EnabledModule.expenses.bitmask;

/// Mounts the shell inside a minimal `GoRouter` so the shell's
/// `GoRouterState.of(context)` reads + `context.go` writes don't blow up.
Widget _host({
  required Services services,
  String initialLocation = '/settings/custom_fields',
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/settings/custom_fields',
        builder: (_, _) => const CustomFieldsShell(),
        routes: [
          GoRoute(
            path: ':tab',
            builder: (_, state) =>
                CustomFieldsShell(initialTab: state.pathParameters['tab']),
          ),
        ],
      ),
      // Banner link target. Stubbed; the test just asserts the route exists.
      GoRoute(
        path: '/settings/account_management/plan',
        builder: (_, _) => const Text('PLAN_SCREEN'),
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

  Services makeServices({
    required Company company,
    String plan = 'pro',
    bool isHosted = false,
    bool isAdmin = true,
  }) {
    final repo = _StubCompanyRepo(db: db, api: companiesApi, company: company);
    return _FakeServices(
      auth: _FakeAuth(
        ValueNotifier(
          _session(plan: plan, isHosted: isHosted, isAdmin: isAdmin),
        ),
      ),
      company: repo,
      clients: clientRepo,
      db: db,
      settingsLevel: SettingsLevelController(),
      unsavedChangesGuard: UnsavedChangesGuard(),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    // Microtask emit → controller listener → notify → rebuild.
    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();
  }

  testWidgets('all modules enabled + paid plan → 10 tabs visible, no banner', (
    tester,
  ) async {
    final services = makeServices(
      company: Company(id: 'co-A', enabledModules: _allModules()),
    );
    await tester.pumpWidget(_host(services: services));
    await settle(tester);

    // 10 entity tabs in display order. Text is the localized label,
    // which capitalizes the slug (`company` → "Company", etc.). No Quotes /
    // Credits tabs — quotes & credits reuse the Invoices custom fields.
    for (final label in const [
      'Company',
      'Clients',
      'Products',
      'Invoices',
      'Payments',
      'Projects',
      'Tasks',
      'Vendors',
      'Expenses',
      'Users',
    ]) {
      expect(
        find.descendant(of: find.byType(Tab), matching: find.text(label)),
        findsOneWidget,
        reason: 'expected tab "$label" to be visible',
      );
    }
    // Pro plan → no upgrade banner.
    expect(find.text('Manage Plan'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'enabledModules = 0 → only 4 tabs (company / clients / products / users)',
    (tester) async {
      final services = makeServices(
        company: const Company(id: 'co-A', enabledModules: 0),
      );
      await tester.pumpWidget(_host(services: services));
      await settle(tester);

      // Always-visible tabs.
      for (final label in const ['Company', 'Clients', 'Products', 'Users']) {
        expect(
          find.descendant(of: find.byType(Tab), matching: find.text(label)),
          findsOneWidget,
        );
      }
      // Module-gated tabs should be absent.
      for (final label in const [
        'Invoices',
        'Payments',
        'Projects',
        'Tasks',
        'Vendors',
        'Expenses',
      ]) {
        expect(
          find.descendant(of: find.byType(Tab), matching: find.text(label)),
          findsNothing,
          reason: 'tab "$label" should be hidden when its module is disabled',
        );
      }

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'free plan → upgrade banner shows with a tappable "Manage Plan" link',
    (tester) async {
      final services = makeServices(
        company: Company(id: 'co-A', enabledModules: _allModules()),
        plan: '', // free account
        // Pro/Enterprise gating only applies on hosted accounts —
        // self-hosted users always have feature access via licensing.
        isHosted: true,
      );
      await tester.pumpWidget(_host(services: services));
      await settle(tester);

      // Banner: lock icon + the upgrade message + the link button.
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      // The English copy from `start_free_trial_message` localization.
      expect(
        find.textContaining('Start your FREE 14 day trial'),
        findsOneWidget,
      );
      // The link label routes to the Plan screen.
      expect(find.text('Manage Plan'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('deep link to a hidden tab falls back to the first visible tab', (
    tester,
  ) async {
    // Tasks module disabled, but URL targets `/settings/custom_fields/tasks`.
    final services = makeServices(
      company: const Company(id: 'co-A', enabledModules: 0),
    );
    await tester.pumpWidget(
      _host(
        services: services,
        initialLocation: '/settings/custom_fields/tasks',
      ),
    );
    await settle(tester);

    // The shell should resolve to the first visible tab (Company / empty
    // slug). The Tasks tab itself is gone from the TabBar.
    expect(
      find.descendant(of: find.byType(Tab), matching: find.text('Tasks')),
      findsNothing,
    );
    // The Company tab body's section card shows the localized
    // `company_field` title.
    expect(find.text('Company Field'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  // Regression test for Finding 1 — the type dropdown must follow the draft
  // when `vm.reset()` reverts a user edit. Without the ValueKey idiom in
  // `custom_field_row.dart`, `DropdownButtonFormField.initialValue` is
  // captured once on first mount and never re-read; Discard would silently
  // leave the dropdown showing the edited type while the underlying draft
  // had reverted.
  testWidgets(
    'F1 regression: dropdown remounts to the reset value after vm.reset()',
    (tester) async {
      final services = makeServices(
        // Baseline: company1 slot uses `Date` type. The reset should snap
        // back here after we simulate an edit to `Switch`.
        company: Company(
          id: 'co-A',
          enabledModules: 0,
          customFields: const {'company1': 'X|date'},
        ),
      );
      await tester.pumpWidget(_host(services: services));
      await settle(tester);

      // The dropdown's selected text matches the resolved type's label.
      // `field_type` localization keys map: 'date' → "Date".
      expect(find.text('Date'), findsOneWidget);

      // Edit the type to `switch`. Going through the VM exercises the same
      // `customFields` write path the user-driven `onChanged` does, without
      // needing to drive the dropdown UI in the widget tester.
      final bodyCtx = tester.element(find.text('Company Field'));
      final vm = Provider.of<CustomFieldsViewModel>(bodyCtx, listen: false);
      vm.updateCompany(
        (c) => c.copyWith(customFields: {'company1': 'X|switch'}),
      );
      await tester.pump();
      expect(find.text('Switch'), findsOneWidget);

      // Discard. Without the ValueKey fix the dropdown would stay on
      // "Switch" while the draft reverts to "Date".
      vm.reset();
      await tester.pump();
      expect(
        find.text('Date'),
        findsOneWidget,
        reason: 'dropdown should remount to baseline type after reset',
      );
      expect(find.text('Switch'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  // Regression test for Finding 2 — clearing a surcharge label must also
  // reset the paired `customSurchargeTaxes<n>` boolean. Without the
  // `_writeSurchargeTax(..., false)` call inside `_write`, the server would
  // receive a stale "charge taxes" flag for a now-deleted surcharge slot.
  testWidgets(
    'F2 regression: clearing a surcharge label resets the charge-taxes bool',
    (tester) async {
      // Widen the test surface so the scrollable TabBar's underlying
      // `Scrollable` has a viewport before any `animateTo` runs —
      // otherwise `_TabBarState._tabCenteredScrollOffset` reads
      // `viewportDimension` as null and crashes the post-frame callback.
      await tester.binding.setSurfaceSize(const Size(1600, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final services = makeServices(
        // Invoices module on (so the Surcharge section renders),
        // `enabledTaxRates != 0` (so the Charge Taxes Switch is visible),
        // and slot 1 has a label + the Switch flipped ON.
        company: Company(
          id: 'co-A',
          enabledModules: EnabledModule.invoices.bitmask,
          enabledTaxRates: 1,
          customFields: const {'surcharge1': 'Discount'},
          customSurchargeTaxes1: true,
        ),
      );
      // Start at the default (Company) tab so the TabBar's Scrollable has
      // time to lay out before we navigate. Going straight to
      // `/settings/custom_fields/invoices` would schedule an immediate
      // `animateTo` in the first build's post-frame callback, before the
      // Scrollable's viewport is attached — that's the null-viewportDimension
      // crash.
      await tester.pumpWidget(_host(services: services));
      await settle(tester);

      // Switch to the Invoices tab. By now the TabBar has laid out cleanly.
      await tester.tap(
        find.descendant(of: find.byType(Tab), matching: find.text('Invoices')),
      );
      await settle(tester);

      // The Invoices tab body shows both Invoice and Surcharge sections.
      expect(find.text('Surcharge Field'), findsOneWidget);

      // Grab the VM via the body subtree. Sanity-check the seeded state.
      final bodyCtx = tester.element(find.text('Surcharge Field'));
      final vm = Provider.of<CustomFieldsViewModel>(bodyCtx, listen: false);
      expect(vm.draft?.customSurchargeTaxes1, isTrue);
      expect(vm.draft?.customFields['surcharge1'], 'Discount');

      // Find the surcharge slot 1 row by its parent's ValueKey (set by
      // `invoices_screen.dart`), then drill into its label TextField.
      final row = find.byKey(const ValueKey('co-A:surcharge1'));
      expect(row, findsOneWidget);
      final labelField = find.descendant(
        of: row,
        matching: find.byType(TextField),
      );
      expect(labelField, findsOneWidget);

      // Simulate the user clearing the label. `enterText('')` fires the
      // TextField's `onChanged` with the empty string, which `_write` reads
      // as "retire this surcharge slot."
      await tester.enterText(labelField, '');
      await tester.pump();

      // Slot is gone from the map AND the paired bool is reset.
      expect(vm.draft?.customFields.containsKey('surcharge1'), isFalse);
      expect(vm.draft?.customSurchargeTaxes1, isFalse);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('an admin-portal surcharge label shows without its type suffix', (
    tester,
  ) async {
    // admin-portal saved `Label|single_line_text` for a surcharge, and the
    // label box showed the whole string. Same tab dance as above.
    await tester.binding.setSurfaceSize(const Size(1600, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final services = makeServices(
      company: Company(
        id: 'co-A',
        enabledModules: EnabledModule.invoices.bitmask,
        customFields: const {'surcharge1': 'Shipping|single_line_text'},
      ),
    );
    await tester.pumpWidget(_host(services: services));
    await settle(tester);
    await tester.tap(
      find.descendant(of: find.byType(Tab), matching: find.text('Invoices')),
    );
    await settle(tester);

    final labelField = find.descendant(
      of: find.byKey(const ValueKey('co-A:surcharge1')),
      matching: find.byType(TextField),
    );
    expect(tester.widget<TextField>(labelField).controller!.text, 'Shipping');

    await tester.pumpWidget(const SizedBox.shrink());
  });

  // A `<label>|single_line_text` slot (the encoding React + admin-portal
  // write for "Single-line text") must render AS single-line text — not as a
  // dropdown whose options are the literal string `single_line_text`. The
  // `single_line_text` keyword was missing from `_kReservedTypes`.
  testWidgets(
    'single_line_text slot renders as Single-line text, not Dropdown',
    (tester) async {
      final services = makeServices(
        company: const Company(
          id: 'co-A',
          enabledModules: 0,
          customFields: {'company1': 'Region|single_line_text'},
        ),
      );
      await tester.pumpWidget(_host(services: services));
      await settle(tester);

      final row = find.byKey(const ValueKey('co-A:company1'));
      expect(row, findsOneWidget);

      // The Field Type selector shows the selected value "Single-line text",
      // never "Dropdown".
      expect(
        find.descendant(of: row, matching: find.text('Single-line text')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.text('Dropdown')),
        findsNothing,
      );
      // Structural guard (independent of the dropdown's internals): a
      // single-line row has only the label TextField. The buggy dropdown
      // rendering adds a second (options) TextField seeded with the raw
      // `single_line_text` string. The Field Type selector is a
      // DropdownButtonFormField, not a TextField, so it isn't counted.
      expect(
        find.descendant(of: row, matching: find.byType(TextField)),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  // Round-trip: typing a label into an empty slot persists the canonical
  // `Label|single_line_text` encoding — NOT a bare `Label`, which would
  // re-parse as multi-line text on the next load.
  testWidgets('typing a label persists Label|single_line_text', (tester) async {
    final services = makeServices(
      company: const Company(id: 'co-A', enabledModules: 0),
    );
    await tester.pumpWidget(_host(services: services));
    await settle(tester);

    final row = find.byKey(const ValueKey('co-A:company1'));
    final labelField = find.descendant(
      of: row,
      matching: find.byType(TextField),
    );
    expect(labelField, findsOneWidget);

    await tester.enterText(labelField, 'Region');
    await tester.pump();

    final bodyCtx = tester.element(find.text('Company Field'));
    final vm = Provider.of<CustomFieldsViewModel>(bodyCtx, listen: false);
    expect(vm.draft?.customFields['company1'], 'Region|single_line_text');

    await tester.pumpWidget(const SizedBox.shrink());
  });

  // Clearing the label retires the slot entirely (matches React's
  // `useHandleCustomFieldChange`) — it must not leave a malformed
  // `|single_line_text` entry behind.
  testWidgets('clearing a single-line label removes the slot', (tester) async {
    final services = makeServices(
      company: const Company(
        id: 'co-A',
        enabledModules: 0,
        customFields: {'company1': 'Region|single_line_text'},
      ),
    );
    await tester.pumpWidget(_host(services: services));
    await settle(tester);

    final row = find.byKey(const ValueKey('co-A:company1'));
    final labelField = find.descendant(
      of: row,
      matching: find.byType(TextField),
    );
    expect(labelField, findsOneWidget);

    await tester.enterText(labelField, '');
    await tester.pump();

    final bodyCtx = tester.element(find.text('Company Field'));
    final vm = Provider.of<CustomFieldsViewModel>(bodyCtx, listen: false);
    expect(vm.draft?.customFields.containsKey('company1'), isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  // The reported follow-up: picking "Dropdown" must reveal the comma-separated
  // options field. It used to store a bare label (no pipe), which re-parsed as
  // multi-line — so the options field never appeared. An empty-options dropdown
  // now persists as `"Label|"` (the React / admin-portal encoding).
  testWidgets(
    'selecting Dropdown reveals the options field and keeps the pipe',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final services = makeServices(
        company: const Company(
          id: 'co-A',
          enabledModules: 0,
          customFields: {'company1': 'Status|single_line_text'},
        ),
      );
      await tester.pumpWidget(_host(services: services));
      await settle(tester);

      final row = find.byKey(const ValueKey('co-A:company1'));
      // Single-line to start: only the label field.
      expect(
        find.descendant(of: row, matching: find.byType(TextField)),
        findsOneWidget,
      );

      // Open this row's Field Type dropdown and pick "Dropdown".
      await tester.tap(
        find.descendant(
          of: row,
          matching: find.byType(DropdownButtonFormField<String>),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dropdown').last);
      await tester.pumpAndSettle();

      final bodyCtx = tester.element(find.text('Company Field'));
      final vm = Provider.of<CustomFieldsViewModel>(bodyCtx, listen: false);

      // Options field now present (label + options) and the slot kept its pipe
      // so it stays a dropdown on the next build.
      expect(
        find.descendant(of: row, matching: find.byType(TextField)),
        findsNWidgets(2),
      );
      expect(vm.draft?.customFields['company1'], 'Status|');

      // Typing options persists them.
      await tester.enterText(
        find.descendant(of: row, matching: find.byType(TextField)).last,
        'Open,Closed',
      );
      await tester.pump();
      expect(vm.draft?.customFields['company1'], 'Status|Open,Closed');

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  // A stored `"Label|"` (empty-options dropdown) must hydrate as a Dropdown,
  // not single-line text.
  testWidgets('a Label| slot hydrates as a Dropdown with an options field', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final services = makeServices(
      company: const Company(
        id: 'co-A',
        enabledModules: 0,
        customFields: {'company1': 'Status|'},
      ),
    );
    await tester.pumpWidget(_host(services: services));
    await settle(tester);

    final row = find.byKey(const ValueKey('co-A:company1'));
    // Field Type shows "Dropdown" and the (empty) options field is present.
    expect(
      find.descendant(of: row, matching: find.text('Dropdown')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row, matching: find.byType(TextField)),
      findsNWidgets(2),
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  // Editing is gated on admin/owner AND a paid plan (React parity). A
  // non-admin Pro user sees read-only fields — and no upgrade banner, because
  // they DO have the plan (the banner is plan-gated, not role-gated).
  testWidgets('non-admin Pro user → read-only fields, no upgrade banner', (
    tester,
  ) async {
    final services = makeServices(
      company: Company(id: 'co-A', enabledModules: _allModules()),
      isAdmin: false, // Pro plan, but not admin/owner.
    );
    await tester.pumpWidget(_host(services: services));
    await settle(tester);

    expect(find.text('Manage Plan'), findsNothing);
    final labelField = find.descendant(
      of: find.byKey(const ValueKey('co-A:company1')),
      matching: find.byType(TextField),
    );
    expect(labelField, findsOneWidget);
    expect(tester.widget<TextField>(labelField).enabled, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  // Reseed regression: the label + options text controllers must follow the
  // draft when `vm.reset()` reverts an in-place Discard (the type dropdown
  // already self-heals via its ValueKey; this covers the two text fields).
  testWidgets('reseed: Discard reverts the label + options text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final services = makeServices(
      company: const Company(
        id: 'co-A',
        enabledModules: 0,
        customFields: {'company1': 'Region|North,South'},
      ),
    );
    await tester.pumpWidget(_host(services: services));
    await settle(tester);

    final row = find.byKey(const ValueKey('co-A:company1'));
    final fields = find.descendant(of: row, matching: find.byType(TextField));
    expect(fields, findsNWidgets(2)); // label + dropdown options

    await tester.enterText(fields.at(0), 'Region X');
    await tester.enterText(fields.at(1), 'North,South,East');
    await tester.pump();
    expect(find.text('Region X'), findsOneWidget);
    expect(find.text('North,South,East'), findsOneWidget);

    final bodyCtx = tester.element(find.text('Company Field'));
    final vm = Provider.of<CustomFieldsViewModel>(bodyCtx, listen: false);
    vm.reset();
    await tester.pump();

    // Both controllers snapped back to the baseline.
    expect(find.text('Region X'), findsNothing);
    expect(find.text('North,South,East'), findsNothing);
    expect(find.text('Region'), findsOneWidget);
    expect(find.text('North,South'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
