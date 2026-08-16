import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/value/company_format_settings.dart';
import 'package:admin/data/models/value/dashboard_filter.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/models/value/datetime_format.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/statics_repository.dart';
import 'package:admin/data/services/statics_service.dart';
import 'package:admin/ui/features/dashboard/view_models/dashboard_view_model.dart';
import 'package:admin/ui/features/dashboard/widgets/freshness.dart';
import 'package:admin/ui/features/dashboard/widgets/mobile_dashboard_body.dart';
import 'package:admin/utils/formatting.dart';

import '../../../../_localization_helper.dart';
import '../_fake_dashboard_repo.dart';

/// flutter#37 was filed against the Android beta, and mobile was the worse
/// half of it: the AppBar carries a bare filter *icon*, so the selected window
/// appeared nowhere on the page. Every figure below was scoped to a range the
/// user could not see — "even more confusing when you start using filters like
/// `Last Year` or `Last Quarter` and that's what the app opens on".
///
/// The eyebrow now leads with the window. It displaces the company name (the
/// AppBar title directly above already carries it) and the word "Dashboard",
/// because one ellipsised 11 px line has no room for all three.
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

  Future<void> pumpBody(
    WidgetTester tester, {
    DashboardDateRange? range,
  }) async {
    if (range != null) await vm.setDateRange(range);
    await tester.pumpWidget(
      Provider<Services>.value(
        value: _FakeServices(_FakeAuth(ValueNotifier(_session()))),
        child: MaterialApp(
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          theme: buildInTheme(InTheme.light),
          home: Scaffold(
            body: SizedBox(
              width: 390, // iPhone-class logical width
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

  testWidgets('the eyebrow no longer duplicates the AppBar company name', (
    tester,
  ) async {
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
}
