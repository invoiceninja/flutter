import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/hide_empty_panels_controller.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/domain/enabled_modules.dart';
import 'package:admin/data/repositories/dashboard_repository.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/statics_repository.dart';
import 'package:admin/data/services/statics_service.dart';
import 'package:admin/ui/features/dashboard/view_models/dashboard_view_model.dart';
import 'package:admin/ui/features/dashboard/widgets/manage_dashboard_cards_sheet.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';

import '../../../../_localization_helper.dart';
import '../_fake_dashboard_repo.dart';

/// The Panels tab has to agree with the dashboard body behind it: the mobile
/// body pins past-due to its hero zone and drops it from the ordered trailing
/// panels (`mobile_dashboard_body.dart` `_trailingPanels`), so there the row
/// must render as pinned and the other five reorder through
/// `reorderTrailingPanels`.
///
/// It used to answer that by measuring `MediaQuery.sizeOf(context).width`, which
/// is the **window** — and this surface floats on the root navigator, so the
/// window is all it can see. Two configurations render the mobile body behind a
/// ≥600 px window: a desktop window of 600–832 px (the sidebar rail leaves the
/// pane under 600) and, since flutter#51, **any phone in landscape**. In both,
/// past-due came up with a live drag handle whose gesture the dashboard ignores
/// — and which wrote through `reorderPanels`, so the same drag saved a
/// different order than it does in portrait.
///
/// The flag is passed from the call site now. These tests hold the window wide
/// in *both* cases, so they fail if anyone re-derives it from `MediaQuery`.
class _FakeAuth implements AuthRepository {
  _FakeAuth(this._session);
  final ValueNotifier<AuthSession?> _session;
  @override
  ValueListenable<AuthSession?> get session => _session;
  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// Only `auth.session` (it flags module-disabled rows) and `hideEmptyPanels`
/// (the footer switch and the "Hidden while empty" caption) are reachable from
/// the Panels tab; everything else falls through to [noSuchMethod].
class _FakeServices implements Services {
  _FakeServices(this.auth, this.hideEmptyPanels);
  @override
  final AuthRepository auth;
  @override
  final HideEmptyPanelsController hideEmptyPanels;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// [enabledModules] defaults to 0, where every row is module-disabled — so a
/// test about an available row's caption must pass a real mask.
AuthSession _session({int enabledModules = 0}) => AuthSession(
  baseUrl: 'https://example.test',
  isHosted: false,
  accountId: 'acct',
  companies: [
    AuthCompany(
      id: 'co',
      name: 'Acme Corporation',
      displayName: 'Acme Corporation',
      permissions: '',
      isAdmin: true,
      isOwner: true,
      enabledModules: enabledModules,
    ),
  ],
  currentCompanyId: 'co',
);

void main() {
  late AppDatabase db;
  late FakeDashboardRepo repo;
  late DashboardViewModel vm;
  late HideEmptyPanelsController pref;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = FakeDashboardRepo(db);
    // Automatic. This harness's window is not a phone (see `openPanels`), so
    // automatic resolves to off here.
    pref = HideEmptyPanelsController(prefs: DevicePrefsStore(db));
    vm = DashboardViewModel(
      repo: repo,
      companyId: 'co',
      navStateDao: db.navStateDao,
      statics: StaticsRepository(
        db: db,
        service: StaticsService(dummyDashboardClient),
      ),
      // As elsewhere in this folder: the default 500 ms nav_state debounce
      // outlives the pump and trips the pending-Timer invariant.
      persistDebounce: const Duration(milliseconds: 1),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
  });

  tearDown(() async {
    vm.dispose();
    pref.dispose();
    await db.close();
  });

  /// Opens the Panels tab through the real entry point — the pane is private,
  /// and going through `openManageDashboardCards` is also what pins the
  /// call-site contract. `Provider` sits *above* `MaterialApp` because the
  /// dialog mounts on the root navigator and reads `Services` from there
  /// (main.dart has the same shape).
  ///
  /// The window is deliberately wide in every case: the claim under test is
  /// that [mobileLayout] decides, not the viewport.
  ///
  /// `setSurfaceSize` leaves `MediaQuery` at the test view's 800x600, so
  /// `Breakpoints.isPhone` is false and "Hide empty panels" starts off unless
  /// a test sets `pref.value` — or passes [phone], which sizes both the
  /// surface and `MediaQuery` to it (so the sheet opens as a bottom sheet) and
  /// applies [textScale].
  Future<void> openPanels(
    WidgetTester tester, {
    required bool mobileLayout,
    int enabledModules = 0,
    Size? phone,
    double textScale = 1.0,
  }) async {
    await tester.binding.setSurfaceSize(phone ?? const Size(890, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      Provider<Services>.value(
        value: _FakeServices(
          _FakeAuth(ValueNotifier(_session(enabledModules: enabledModules))),
          pref,
        ),
        child: MaterialApp(
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          theme: buildInTheme(InTheme.light),
          // Above the Navigator, so the sheet on the root navigator sees it.
          builder: phone == null
              ? null
              : (context, inner) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    size: phone,
                    textScaler: TextScaler.linear(textScale),
                  ),
                  child: inner!,
                ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => openManageDashboardCards(
                  context,
                  vm: vm,
                  mobileLayout: mobileLayout,
                  initialTab: ManagePane.panels,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    // Explicit durations, never pumpAndSettle — the VM holds live Drift watch
    // subscriptions. 400 ms clears the dialog route transition.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('mobile body: past-due is pinned, the rest reorder', (
    tester,
  ) async {
    await openPanels(tester, mobileLayout: true);

    expect(
      find.byIcon(Icons.push_pin_outlined),
      findsOneWidget,
      reason:
          'past-due renders in the mobile hero zone — its order is ignored, '
          'so a drag handle here is a dead control',
    );
    // Every kind but the pinned past-due one.
    expect(
      find.byIcon(Icons.drag_indicator),
      findsNWidgets(DashboardKind.panelKinds.length - 1),
    );
  });

  testWidgets('wide body: every panel reorders', (tester) async {
    await openPanels(tester, mobileLayout: false);

    expect(find.byIcon(Icons.push_pin_outlined), findsNothing);
    expect(
      find.byIcon(Icons.drag_indicator),
      findsNWidgets(DashboardKind.panelKinds.length),
    );
  });

  // invoiceninja/flutter#161. The switch shares the footer's single run with
  // Reset — a second row would push the last panel row off screen, which the
  // two handle counts above would catch.
  group('hide empty panels', () {
    // The nearest `Row` around the label is the switch's own — every panel
    // row carries a `Switch` too.
    Finder footerSwitch() => find.descendant(
      of: find
          .ancestor(
            of: find.text('Hide empty panels'),
            matching: find.byType(Row),
          )
          .first,
      matching: find.byType(Switch),
    );

    testWidgets('the footer switch shows and sets the device preference', (
      tester,
    ) async {
      await openPanels(tester, mobileLayout: false);

      expect(find.text('Hide empty panels'), findsOneWidget);
      expect(
        tester.widget<Switch>(footerSwitch()).value,
        isFalse,
        reason: 'automatic is off away from a phone',
      );

      await tester.tap(footerSwitch());
      await tester.pump();
      expect(pref.value, isTrue);
      expect(tester.widget<Switch>(footerSwitch()).value, isTrue);

      // The label is part of the control, not just a caption beside it —
      // and switching back to what this device would pick anyway (off, away
      // from a phone) returns to automatic rather than storing an override.
      await tester.tap(find.text('Hide empty panels'));
      await tester.pump();
      expect(pref.value, isNull);
      expect(tester.widget<Switch>(footerSwitch()).value, isFalse);
    });

    testWidgets('the footer wraps its label on a small phone at large text', (
      tester,
    ) async {
      // A plain `Text` in the switch's `Row` ignored the `Wrap`'s width bound
      // and overflowed, pushing the switch past the sheet's edge.
      await openPanels(
        tester,
        mobileLayout: true,
        phone: const Size(320, 640),
        textScale: 2.0,
      );

      expect(find.text('Hide empty panels'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final sheet = tester.getRect(find.byType(BottomSheet));
      final toggle = tester.getRect(footerSwitch());
      expect(toggle.right, lessThanOrEqualTo(sheet.right));
      expect(toggle.left, greaterThanOrEqualTo(sheet.left));
    });

    testWidgets('a screen reader hears the label on the switch itself', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await openPanels(tester, mobileLayout: false);

      expect(
        tester.getSemantics(find.text('Hide empty panels')),
        isSemantics(
          label: 'Hide empty panels',
          hasToggledState: true,
          isToggled: false,
          hasTapAction: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets('a switched-on panel that is empty says why it is missing', (
      tester,
    ) async {
      pref.value = true;
      await openPanels(
        tester,
        mobileLayout: false,
        enabledModules: EnabledModule.recurringInvoices.bitmask,
      );
      expect(find.text('Hidden while empty'), findsNothing);

      repo.upcomingRecurring.add(const []);
      await tester.pump(const Duration(milliseconds: 10));
      expect(find.text('Hidden while empty'), findsOneWidget);

      // Not while the device shows empty panels — then it isn't hidden.
      pref.value = false;
      await tester.pump();
      expect(find.text('Hidden while empty'), findsNothing);
    });

    testWidgets('a user-hidden empty panel keeps its own reason', (
      tester,
    ) async {
      pref.value = true;
      vm.togglePanelVisibility(DashboardKind.upcomingRecurring);
      await openPanels(
        tester,
        mobileLayout: true,
        enabledModules: EnabledModule.recurringInvoices.bitmask,
      );
      repo.upcomingRecurring.add(const []);
      await tester.pump(const Duration(milliseconds: 10));

      // Its switch already says "off"; "hidden while empty" would be a
      // second, wrong explanation.
      expect(find.text('Hidden while empty'), findsNothing);
    });
  });
}
