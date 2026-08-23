import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_card_config.dart';
import 'package:admin/data/models/value/company_format_settings.dart';
import 'package:admin/data/models/value/dashboard_filter.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/models/value/datetime_format.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/statics_repository.dart';
import 'package:admin/data/services/statics_service.dart';
import 'package:admin/ui/features/dashboard/view_models/dashboard_view_model.dart';
import 'package:admin/ui/features/dashboard/widgets/configured_cards_grid.dart';
import 'package:admin/ui/features/dashboard/widgets/freshness.dart';
import 'package:admin/ui/features/dashboard/widgets/mobile_dashboard_body.dart';
import 'package:admin/utils/formatting.dart';

import '../../../../_localization_helper.dart';
import '../../../../_responsive_helper.dart';
import '../_fake_dashboard_repo.dart';

/// flutter#37 was filed against the Android beta, and mobile was the worse
/// half of it: the AppBar carries a bare filter *icon*, so the selected window
/// appeared nowhere on the page. Every figure below was scoped to a range the
/// user could not see — "even more confusing when you start using filters like
/// `Last Year` or `Last Quarter` and that's what the app opens on".
///
/// The eyebrow now leads with the window. It displaces the company name and
/// the word "Dashboard", because one ellipsised 11 px line has no room for all
/// three. (It used to be justified by the AppBar title carrying the company;
/// flutter#50 retitled that bar to the page name, so the company now lives
/// only in the drawer's switcher. The assertion below is unchanged — the
/// eyebrow should not carry it either way.)
class _FakeAuth implements AuthRepository {
  _FakeAuth(this._session);
  final ValueNotifier<AuthSession?> _session;
  @override
  ValueListenable<AuthSession?> get session => _session;
  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// Only `auth.session` is reachable from `MobileDashboardBody` (it gates the
/// trailing list cards on the company's enabled modules); everything else
/// falls through to [noSuchMethod].
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
  late FakeDashboardRepo repo;
  late DashboardViewModel vm;

  final formatter = Formatter(
    settings: CompanyFormatSettings.fallback,
    currencies: const {},
    countries: const {},
    dateFormats: const {'5': DatetimeFormat(id: '5', format: 'MMM d, yyyy')},
  );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = FakeDashboardRepo(db);
    vm = DashboardViewModel(
      repo: repo,
      companyId: 'co',
      navStateDao: db.navStateDao,
      statics: StaticsRepository(
        db: db,
        service: StaticsService(dummyDashboardClient),
      ),
      // A range change schedules a debounced nav_state write; the default
      // 500 ms outlives the pump and trips "a Timer is still pending".
      persistDebounce: const Duration(milliseconds: 1),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
  });

  tearDown(() async {
    vm.dispose();
    await db.close();
  });

  /// [width] is the body's own extent and defaults to an iPhone-class portrait
  /// width. [surface] is the *window* behind it — they differ once the shell's
  /// rail takes its share, which is exactly the landscape-phone case flutter#51
  /// routes here. Setting it also moves `InSpacing.lg`, which reads the window
  /// rather than the box.
  Future<void> pumpBody(
    WidgetTester tester, {
    DashboardDateRange? range,
    double width = 390,
    Size? surface,
  }) async {
    if (range != null) await vm.setDateRange(range);
    if (surface != null) {
      await tester.binding.setSurfaceSize(surface);
      addTearDown(() => tester.binding.setSurfaceSize(null));
    }
    await tester.pumpWidget(
      Provider<Services>.value(
        value: _FakeServices(_FakeAuth(ValueNotifier(_session()))),
        child: MaterialApp(
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          theme: buildInTheme(InTheme.light),
          home: Scaffold(
            body: SizedBox(
              width: width,
              child: MobileDashboardBody(
                vm: vm,
                formatter: formatter,
                onOpenCard: (_) {},
                onPastDueInvoiceTap: (_) {},
                onAllInvoices: () {},
                onAllUpcomingInvoices: () {},
                onNewInvoice: () {},
                onAddClient: () {},
                onLogExpense: () {},
                onReports: () {},
                onOutstandingTap: () {},
                onPaidTap: () {},
                onActivityTap: (_) {},
                onUpcomingInvoiceTap: (_) {},
                onPaymentTap: (_) {},
                onAllPayments: () {},
                onQuoteTap: (_) {},
                onAllQuotes: () {},
                onRecurringTap: (_) {},
                onAllRecurring: () {},
              ),
            ),
          ),
        ),
      ),
    );
    // Explicit durations, never pumpAndSettle — FreshnessTicker owns a 30 s
    // Timer.periodic and the VM holds a live watch subscription per section.
    await tester.pump(const Duration(milliseconds: 10));
  }

  String eyebrowText(WidgetTester tester) => tester
      .widget<Text>(
        find
            .descendant(
              of: find.byType(FreshnessTicker),
              matching: find.byType(Text),
            )
            .first,
      )
      .data!;

  testWidgets('the eyebrow states the active window', (tester) async {
    await pumpBody(
      tester,
      range: const DashboardCustomRange(
        start: Date(2026, 4, 1),
        end: Date(2026, 6, 30),
      ),
    );

    expect(
      eyebrowText(tester),
      startsWith('APR 1, 2026 — JUN 30, 2026 · UPDATED'),
    );
  });

  testWidgets('the window survives a range change', (tester) async {
    await pumpBody(
      tester,
      range: const DashboardPresetRange(DashboardDatePreset.thisMonth),
    );
    final monthly = eyebrowText(tester);

    await pumpBody(
      tester,
      range: const DashboardPresetRange(DashboardDatePreset.lastQuarter),
    );

    expect(
      eyebrowText(tester),
      isNot(monthly),
      reason: 'the eyebrow is the only place a phone shows the window',
    );
  });

  testWidgets('the eyebrow does not carry the company name', (tester) async {
    await pumpBody(tester);

    expect(eyebrowText(tester), isNot(contains('ACME CORPORATION')));
  });

  testWidgets('the hero sub-KPI reads "Paid", not "Paid this month"', (
    tester,
  ) async {
    await pumpBody(
      tester,
      range: const DashboardPresetRange(DashboardDatePreset.lastYear),
    );

    expect(find.text('PAID'), findsOneWidget);
    expect(find.textContaining('THIS MONTH'), findsNothing);
  });

  // flutter#51 routes a phone here in landscape too, so this body is laid out
  // past 600 px for the first time. The risk runs the opposite way to the rest
  // of the file, which guards against a layout that is too *narrow*. Both pane
  // widths a rotated handset produces: 890 − 232 with the rail expanded,
  // 890 − 64 collapsed.
  //
  // The cards are seeded deliberately. `ConfiguredCardsGrid` is the one thing
  // here that changes shape at this width — it tiers to two columns at 600
  // (`configured_cards_grid.dart`) — and the body mounts it only when
  // `vm.dashboardCards` is non-empty, so without a seed the sweep would render
  // a `SizedBox.shrink()` where the new layout is and quietly prove nothing.
  //
  // What it does not cover: the section streams stay empty, so the list cards
  // are skeletons rather than populated tables; and an ellipsised or clipped
  // `Text` throws nothing, so this catches overflow only.
  testWidgets('lays out on a landscape phone without overflowing', (
    tester,
  ) async {
    const a = DashboardCardConfig(
      field: 'invoices',
      period: CardPeriod.current,
      calculate: CardCalc.sum,
      format: CardFormat.money,
    );
    const b = DashboardCardConfig(
      field: 'logged_tasks',
      period: CardPeriod.total,
      calculate: CardCalc.count,
      format: CardFormat.money,
    );
    vm.addCard(a);
    vm.addCard(b);

    for (final width in const <double>[658, 826]) {
      await pumpBody(tester, width: width, surface: const Size(890, 412));

      expectNoOverflow(tester);
      expect(
        find.byType(ConfiguredCardsGrid),
        findsOneWidget,
        reason:
            'the seed must survive — an empty card list silently drops the '
            'only widget that reflows at this width',
      );
    }
  });
}
