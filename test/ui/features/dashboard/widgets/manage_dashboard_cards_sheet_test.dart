import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/statics_repository.dart';
import 'package:admin/data/services/statics_service.dart';
import 'package:admin/ui/features/dashboard/view_models/dashboard_view_model.dart';
import 'package:admin/ui/features/dashboard/widgets/manage_dashboard_cards_sheet.dart';

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

/// Only `auth.session` is reachable from the panels pane (it flags
/// module-disabled rows); everything else falls through to [noSuchMethod].
class _FakeServices implements Services {
  _FakeServices(this.auth);
  @override
  final AuthRepository auth;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

AuthSession _session() => AuthSession(
  baseUrl: 'https://example.test',
  isHosted: false,
  accountId: 'acct',
  companies: [
    const AuthCompany(
      id: 'co',
      name: 'Acme Corporation',
      displayName: 'Acme Corporation',
      permissions: '',
      isAdmin: true,
      isOwner: true,
    ),
  ],
  currentCompanyId: 'co',
);

void main() {
  late AppDatabase db;
  late DashboardViewModel vm;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    vm = DashboardViewModel(
      repo: FakeDashboardRepo(db),
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
  Future<void> openPanels(
    WidgetTester tester, {
    required bool mobileLayout,
  }) async {
    await tester.binding.setSurfaceSize(const Size(890, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      Provider<Services>.value(
        value: _FakeServices(_FakeAuth(ValueNotifier(_session()))),
        child: MaterialApp(
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          theme: buildInTheme(InTheme.light),
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

  testWidgets('mobile body: past-due is pinned, the other five reorder', (
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
    expect(find.byIcon(Icons.drag_indicator), findsNWidgets(5));
  });

  testWidgets('wide body: all six panels reorder', (tester) async {
    await openPanels(tester, mobileLayout: false);

    expect(find.byIcon(Icons.push_pin_outlined), findsNothing);
    expect(find.byIcon(Icons.drag_indicator), findsNWidgets(6));
  });
}
