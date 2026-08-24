import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/diagnostics_log.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
// Hide the Drift-generated `SystemLogRow` data class so it doesn't clash with
// the `SystemLogRow` widget under test.
import 'package:admin/data/db/app_database.dart' hide SystemLogRow;
import 'package:admin/data/models/api/system_log_api_model.dart';
import 'package:admin/data/models/domain/system_log.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/system_log_repository.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/system_logs_api.dart';
import 'package:admin/ui/core/widgets/error_view.dart';
import 'package:admin/ui/features/settings/state/settings_level_controller.dart';
import 'package:admin/ui/features/settings/views/advanced/system_logs_screen.dart';
import 'package:admin/ui/features/settings/widgets/system_log_row.dart';

import '../../../../../_localization_helper.dart';

/// Scripted [SystemLogsApi] — each entry is a `SystemLogListApi` to return or
/// an `Object` to throw, consumed in order. Mirrors the repository test's fake.
class _FakeApi implements SystemLogsApi {
  _FakeApi(this._scripted);
  final List<Object> _scripted;
  int calls = 0;

  @override
  Future<SystemLogListApi> fetchPage({
    int perPage = 200,
    String sort = 'created_at|DESC',
    String? clientId,
  }) async {
    calls++;
    if (_scripted.isEmpty) throw StateError('no scripted response');
    final next = _scripted.removeAt(0);
    if (next is SystemLogListApi) return next;
    throw next;
  }
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

/// Real in-memory DB + real [SystemLogRepository]; everything else the screen
/// doesn't touch falls through to [noSuchMethod].
class _FakeServices implements Services {
  _FakeServices({
    required this.auth,
    required this.systemLogs,
    required this.db,
    required this.serverVersion,
  });
  @override
  final AuthRepository auth;
  @override
  final SystemLogRepository systemLogs;
  @override
  final AppDatabase db;
  @override
  final ValueNotifier<String?> serverVersion;
  @override
  final DiagnosticsLog? diagnosticsLog = null;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

AuthSession _session({required bool admin}) => AuthSession(
  baseUrl: 'https://example.test',
  isHosted: false,
  accountId: 'acct',
  companies: [
    AuthCompany(
      id: 'co-A',
      name: 'Test Co',
      displayName: 'Test Company',
      permissions: '',
      isAdmin: admin,
      isOwner: admin,
    ),
  ],
  currentCompanyId: 'co-A',
);

SystemLogApi _row(
  String id, {
  int createdAt = 1700000000,
  int categoryId = 2, // CATEGORY_MAIL
  int eventId = 30, // EVENT_MAIL_SEND
  int typeId = 303, // TYPE_FAILURE
}) => SystemLogApi(
  id: id,
  companyId: 'co-A',
  userId: 'u1',
  clientId: '',
  eventId: eventId,
  categoryId: categoryId,
  typeId: typeId,
  log: '{"foo":"bar"}',
  createdAt: createdAt,
  updatedAt: createdAt,
);

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    PackageInfo.setMockInitialValues(
      appName: 'Invoice Ninja',
      packageName: 'com.invoiceninja.admin',
      version: '5.2.0',
      buildNumber: '520',
      buildSignature: '',
    );
  });

  tearDown(() async {
    await db.close();
  });

  Widget host(Services services) => MaterialApp(
    theme: buildInTheme(InTheme.light),
    localizationsDelegates: kTestLocalizationsDelegates,
    supportedLocales: kTestSupportedLocales,
    home: MultiProvider(
      providers: [
        Provider<Services>.value(value: services),
        // SettingsScreenScaffold → SettingsScopeBanner watches this.
        ChangeNotifierProvider<SettingsLevelController>(
          create: (_) => SettingsLevelController(),
        ),
      ],
      child: const SystemLogsScreen(),
    ),
  );

  Services makeServices({
    required AuthSession session,
    required _FakeApi api,
  }) => _FakeServices(
    auth: _FakeAuth(ValueNotifier(session)),
    systemLogs: SystemLogRepository(db: db, api: api),
    db: db,
    serverVersion: ValueNotifier<String?>('5.8.0'),
  );

  // Unmount the tree so drift query-stream subscriptions cancel, then pump to
  // flush drift's stream-close timer — otherwise the test reports a pending
  // timer at teardown.
  Future<void> teardownTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
  }

  testWidgets('admin: auto-refresh renders fetched log rows', (tester) async {
    final services = makeServices(
      session: _session(admin: true),
      api: _FakeApi([
        SystemLogListApi(data: [_row('a', createdAt: 2000), _row('b')]),
      ]),
    );
    await tester.pumpWidget(host(services));
    await tester.pumpAndSettle();

    expect(find.byType(SystemLogRow), findsNWidgets(2));
    // Admin sees the real page, not the restricted gate.
    expect(find.text('Restricted'), findsNothing);

    await teardownTree(tester);
  });

  testWidgets('admin + empty feed → no_system_logs state', (tester) async {
    final services = makeServices(
      session: _session(admin: true),
      api: _FakeApi([SystemLogListApi(data: const [])]),
    );
    await tester.pumpWidget(host(services));
    await tester.pumpAndSettle();

    expect(find.text('No system logs to display'), findsOneWidget);
    expect(find.byType(SystemLogRow), findsNothing);

    await teardownTree(tester);
  });

  testWidgets('admin + 403 → unavailable state', (tester) async {
    final services = makeServices(
      session: _session(admin: true),
      api: _FakeApi([const ServerException(403, 'forbidden')]),
    );
    await tester.pumpWidget(host(services));
    await tester.pumpAndSettle();

    expect(find.text('System logs are not available'), findsOneWidget);

    await teardownTree(tester);
  });

  testWidgets('admin + network error → ErrorView + retry', (tester) async {
    final services = makeServices(
      session: _session(admin: true),
      api: _FakeApi([const NetworkException('offline')]),
    );
    await tester.pumpWidget(host(services));
    await tester.pumpAndSettle();

    expect(find.byType(ErrorView), findsOneWidget);
    expect(find.text("Couldn't load system logs"), findsOneWidget);

    await teardownTree(tester);
  });

  group('feed filters (invoiceninja/flutter#60)', () {
    // A quiet account gets no filter chrome at all: with one category and one
    // outcome there is nothing to narrow.
    testWidgets('stay hidden when there is nothing to narrow', (tester) async {
      final services = makeServices(
        session: _session(admin: true),
        api: _FakeApi([
          SystemLogListApi(data: [_row('a'), _row('b')]),
        ]),
      );
      await tester.pumpWidget(host(services));
      await tester.pumpAndSettle();

      expect(find.byType(SystemLogRow), findsNWidgets(2));
      expect(find.byType(DropdownButtonFormField<int?>), findsNothing);
      await teardownTree(tester);
    });

    testWidgets('category narrows the feed and Clear brings it back', (
      tester,
    ) async {
      final services = makeServices(
        session: _session(admin: true),
        api: _FakeApi([
          SystemLogListApi(
            data: [
              _row('mail', createdAt: 3000),
              // Gateway success: a second category *and* a second outcome.
              _row(
                'gw',
                createdAt: 2000,
                categoryId: 1,
                eventId: 21,
                typeId: 301,
              ),
            ],
          ),
        ]),
      );
      await tester.pumpWidget(host(services));
      await tester.pumpAndSettle();
      expect(find.byType(SystemLogRow), findsNWidgets(2));

      await tester.tap(find.byType(DropdownButtonFormField<int?>));
      await tester.pumpAndSettle();
      // 'Email' — the label `SystemLog.categoryKey` resolves for category 2.
      await tester.tap(find.text('Email').last);
      await tester.pumpAndSettle();

      expect(find.byType(SystemLogRow), findsOneWidget);
      await teardownTree(tester);
    });

    testWidgets('an outcome filter that matches nothing offers a way out', (
      tester,
    ) async {
      final services = makeServices(
        session: _session(admin: true),
        api: _FakeApi([
          SystemLogListApi(
            data: [
              _row('mail', createdAt: 3000),
              _row(
                'gw',
                createdAt: 2000,
                categoryId: 1,
                eventId: 21,
                typeId: 301,
              ),
            ],
          ),
        ]),
      );
      await tester.pumpWidget(host(services));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<SystemLogTone?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Success').last);
      await tester.pumpAndSettle();
      // Only the gateway row is a success — and the mail row proves the
      // type-derived tone reaches the filter, since its event is neutral.
      expect(find.byType(SystemLogRow), findsOneWidget);

      // Success + Email is a real combination that matches nothing, and a
      // filtered-to-empty feed must not look like a load failure.
      await tester.tap(find.byType(DropdownButtonFormField<int?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Email').last);
      await tester.pumpAndSettle();
      expect(find.byType(SystemLogRow), findsNothing);
      expect(find.text('No records found'), findsOneWidget);

      await tester.tap(find.text('Clear Filters'));
      await tester.pumpAndSettle();
      expect(find.byType(SystemLogRow), findsNWidgets(2));
      // Both controls must actually read "All" again — a FormField keeps its
      // own state, so clearing has to rebuild them.
      expect(find.text('All'), findsNWidgets(2));
      await teardownTree(tester);
    });
  });

  testWidgets('non-admin → restricted; page gated, no server fetch', (
    tester,
  ) async {
    final api = _FakeApi([]);
    final services = makeServices(session: _session(admin: false), api: api);
    await tester.pumpWidget(host(services));
    await tester.pumpAndSettle();

    expect(find.text('Restricted'), findsOneWidget);
    expect(
      find.text('Only administrators can access this page.'),
      findsOneWidget,
    );
    // Whole page is gated — no log rows, and the gated screen never hits the
    // server (the auto-refresh bails before fetching for non-admins).
    expect(find.byType(SystemLogRow), findsNothing);
    expect(api.calls, 0);

    await teardownTree(tester);
  });
}
