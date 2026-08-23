import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/schedule_api_model.dart';
import 'package:admin/data/models/domain/schedule.dart';
import 'package:admin/data/models/domain/schedule_constants.dart';
import 'package:admin/data/models/value/company_format_settings.dart';
import 'package:admin/data/models/value/datetime_format.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/schedule_repository.dart';
import 'package:admin/data/services/schedules_api.dart';
import 'package:admin/ui/core/widgets/unsynced_pill.dart';
import 'package:admin/ui/features/settings/state/settings_level_controller.dart';
import 'package:admin/ui/features/settings/views/advanced/schedules_screen.dart';
import 'package:admin/utils/formatting.dart';

import '../../../../../_localization_helper.dart';

/// A schedule the server rejected still lands in Drift as an optimistic local
/// row, so before this pill the list rendered it identically to a saved one —
/// which is what invoiceninja/flutter#43 reported ("oddly, the added schedule
/// appears in Schedules despite that").
///
/// The 360 dp case is the one that earns its keep: `ListTile` splits its width
/// between title and trailing via `BoxConstraints.tighten`, which **clamps a
/// negative title width to zero rather than throwing**. A third trailing widget
/// would erase the schedule's summary sentence with no overflow error and no
/// failing test — so assert the title is actually laid out, not just present.
class _FakeSchedulesApi implements SchedulesApi {
  @override
  Future<({ScheduleListApi data, int? cursorUpdatedAt, String? cursorId})>
  list({
    required int page,
    int perPage = 50,
    String? search,
    int? sinceUpdatedAt,
    String? sinceId,
    Map<String, String> filters = const {},
  }) async => (
    data: const ScheduleListApi(data: []),
    cursorUpdatedAt: null,
    cursorId: null,
  );

  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
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
    required this.schedules,
    required this.db,
  });
  @override
  final AuthRepository auth;
  @override
  final ScheduleRepository schedules;
  @override
  final AppDatabase db;

  @override
  Future<Formatter> formatterFor(String companyId) async => _formatter;

  @override
  Formatter? formatterIfReady(String companyId) => _formatter;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

final _formatter = Formatter(
  settings: const CompanyFormatSettings(
    currencyId: '1',
    countryId: '840',
    dateFormatId: 'X',
    useCommaAsDecimalPlace: false,
    showCurrencyCode: false,
    enableMilitaryTime: false,
    locale: '',
  ),
  currencies: const {},
  countries: const {},
  dateFormats: const {'X': DatetimeFormat(id: 'X', format: 'd/MMM/yyyy')},
);

// isHosted:false => isSelfHosted => isProPlan => hasProAccess, so the screen's
// `canCreate` gate is open and the plan banner stays quiet.
final _session = AuthSession(
  baseUrl: 'https://example.test',
  isHosted: false,
  accountId: 'acct',
  companies: [
    AuthCompany(
      id: 'co-A',
      name: 'Test Co',
      displayName: 'Test Company',
      permissions: '',
      isAdmin: true,
      isOwner: true,
    ),
  ],
  currentCompanyId: 'co-A',
);

void main() {
  late AppDatabase db;
  late ScheduleRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ScheduleRepository(db: db, api: _FakeSchedulesApi());
  });

  tearDown(() async => db.close());

  Widget host() => MaterialApp(
    theme: buildInTheme(InTheme.light),
    localizationsDelegates: kTestLocalizationsDelegates,
    supportedLocales: kTestSupportedLocales,
    home: MultiProvider(
      providers: [
        Provider<Services>.value(
          value: _FakeServices(
            auth: _FakeAuth(ValueNotifier(_session)),
            schedules: repo,
            db: db,
          ),
        ),
        ChangeNotifierProvider<SettingsLevelController>(
          create: (_) => SettingsLevelController(),
        ),
      ],
      child: const SchedulesScreen(),
    ),
  );

  /// Server-accepted row: lands via the bundle path, so `is_dirty` is false.
  Future<void> seedSynced({bool paused = false}) => repo.applyBundle(
    companyId: 'co-A',
    bundle: [
      ScheduleApi(
        id: 'sched-1',
        name: 'Synced',
        template: kScheduleTemplateEmailStatement,
        frequencyId: '5',
        nextRun: '2099-01-01',
        isPaused: paused,
        remainingCycles: -1,
        parameters: const {'clients': <String>[]},
        updatedAt: 1700000000,
        createdAt: 1700000000,
      ),
    ],
    fullSync: true,
  );

  /// Exactly what a create does: optimistic `tmp_` row with `is_dirty = true`,
  /// which is the state a server rejection leaves behind.
  Future<void> seedUnsynced({bool paused = false}) => repo.create(
    companyId: 'co-A',
    draft: Schedule.empty()
        .withTemplate(kScheduleTemplateEmailStatement)
        .copyWith(name: 'Pending', isPaused: paused),
  );

  Future<void> teardownTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  }

  testWidgets('a rejected/never-synced row is marked Unsynced', (tester) async {
    await seedUnsynced();
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.byType(UnsyncedPill), findsOneWidget);
    await teardownTree(tester);
  });

  testWidgets('a synced row carries no pill', (tester) async {
    await seedSynced();
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.byType(UnsyncedPill), findsNothing);
    await teardownTree(tester);
  });

  testWidgets('Unsynced outranks Paused — one state cue, never both', (
    tester,
  ) async {
    await seedUnsynced(paused: true);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.byType(UnsyncedPill), findsOneWidget);
    expect(find.text('Paused'), findsNothing);
    await teardownTree(tester);
  });

  testWidgets('at 360 dp the summary sentence keeps a real width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await seedUnsynced(paused: true);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.byType(UnsyncedPill), findsOneWidget);
    // `_summaryFor` for email_statement with no client filter.
    final title = find.text('Email Statement: All Clients');
    expect(title, findsOneWidget);
    // The silent-clamp guard: > 0 is the whole point, an overflow assertion
    // alone would pass on a title crushed to nothing.
    expect(tester.getSize(title).width, greaterThan(0));
    expect(tester.takeException(), isNull);

    await teardownTree(tester);
  });
}
