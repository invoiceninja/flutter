import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_activity.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/dashboard_repository.dart';
import 'package:admin/data/services/dashboard_api.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/core/widgets/error_view.dart';
import 'package:admin/ui/features/activity/views/activity_screen.dart';
import 'package:admin/ui/features/activity/widgets/activity_feed_row.dart';
import 'package:admin/utils/formatting.dart';

import '../../../_localization_helper.dart';
import '../dashboard/_fake_dashboard_repo.dart';

/// Covers the `/activity` screen's own behaviour (invoiceninja/flutter#53):
/// the four async states, the recoverable filtered-empty state, the window
/// footer, day headers, and — the reason the shared row widget exists — that a
/// row referencing no entity renders inert instead of as a dead tap.
///
/// `formatterFor` never completes here, exactly as `dashboard_screen_test` does
/// it: rows still render (the audit meta falls back to relative time), so the
/// screen is pumpable without a real company `Formatter`.
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
    required this.dashboard,
    required this.db,
  });

  @override
  final AuthRepository auth;
  @override
  final DashboardRepository dashboard;
  @override
  final AppDatabase db;

  @override
  Future<Formatter> formatterFor(String companyId) =>
      Completer<Formatter>().future;

  @override
  Formatter? formatterIfReady(String companyId) => null;

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

DashboardActivity _activity({
  required String id,
  int type = 4,
  String? invoiceId,
  String? userLabel = 'Alice',
  int? createdAt,
}) => DashboardActivity.fromJson(<String, dynamic>{
  'id': id,
  'activity_type_id': type,
  'created_at': createdAt ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
  'notes': '',
  'ip': '10.0.0.1',
  if (userLabel != null) 'user': {'label': userLabel, 'hashed_id': 'u_$id'},
  if (invoiceId != null) 'invoice': {'label': '0042', 'hashed_id': invoiceId},
});

void main() {
  late AppDatabase db;
  late FakeDashboardRepo repo;
  late _FakeServices services;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = FakeDashboardRepo(db);
    services = _FakeServices(
      auth: _FakeAuth(ValueNotifier<AuthSession?>(_session())),
      dashboard: repo,
      db: db,
    );
  });

  tearDown(() async => db.close());

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      Provider<Services>.value(
        value: services,
        child: MaterialApp(
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          theme: buildInTheme(InTheme.light),
          home: const ActivityScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  /// Feeds the VM's watch stream and lets the listener land.
  Future<void> emit(WidgetTester tester, List<DashboardActivity> rows) async {
    repo.activities.add(rows);
    await tester.pump();
    await tester.pump();
  }

  testWidgets('cold open shows the skeleton, not an empty state', (
    tester,
  ) async {
    await pumpScreen(tester);
    expect(find.byType(ActivityFeedSkeleton), findsOneWidget);
    expect(find.byType(EmptyState), findsNothing);
  });

  testWidgets('an empty window gets the plain empty state', (tester) async {
    await pumpScreen(tester);
    await emit(tester, const []);
    expect(find.byType(ActivityFeedSkeleton), findsNothing);
    expect(find.text('No activity yet'), findsOneWidget);
  });

  testWidgets('renders every row in the window, not just five', (tester) async {
    await pumpScreen(tester);
    await emit(tester, [
      for (var i = 0; i < 8; i++) _activity(id: '$i', invoiceId: 'inv$i'),
    ]);
    expect(find.byType(ActivityFeedRow), findsNWidgets(8));
  });

  group('window footer', () {
    testWidgets('stays silent when the server did not cap us', (tester) async {
      await pumpScreen(tester);
      await emit(tester, [_activity(id: '1', invoiceId: 'inv1')]);
      // Below the cap nothing is hidden; claiming a ceiling here would assert a
      // truncation that isn't happening.
      expect(find.textContaining('most recent activities'), findsNothing);
    });

    testWidgets('explains the ceiling once the window is saturated', (
      tester,
    ) async {
      await pumpScreen(tester);
      await emit(tester, [
        for (var i = 0; i < kActivityFeedRows; i++)
          _activity(id: '$i', invoiceId: 'inv$i'),
      ]);
      // Explicit scrollable: the search field carries one of its own, so a
      // bare finder is ambiguous. Large delta — this list is 250 rows deep.
      await tester.scrollUntilVisible(
        find.textContaining('most recent activities'),
        2000,
        scrollable: find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.textContaining('most recent activities'), findsOneWidget);
    });
  });

  testWidgets('groups rows under a day header', (tester) async {
    await pumpScreen(tester);
    await emit(tester, [_activity(id: '1', invoiceId: 'inv1')]);
    expect(find.text('Today'), findsOneWidget);
  });

  testWidgets('a row with no entity reference renders inert', (tester) async {
    await pumpScreen(tester);
    // No invoice / client / anything: `activityDeepLinkTarget` returns null.
    await emit(tester, [_activity(id: 'system')]);

    expect(find.byType(ActivityFeedRow), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ActivityFeedRow),
        matching: find.byIcon(Icons.chevron_right),
      ),
      findsNothing,
      reason: 'a chevron on an untappable row is a dead-tap affordance',
    );
    expect(
      find.descendant(
        of: find.byType(ActivityFeedRow),
        matching: find.byType(InkWell),
      ),
      findsNothing,
    );
  });

  testWidgets('a row that references an entity is a real target', (
    tester,
  ) async {
    await pumpScreen(tester);
    await emit(tester, [_activity(id: '1', invoiceId: 'inv1')]);
    expect(
      find.descendant(
        of: find.byType(ActivityFeedRow),
        matching: find.byIcon(Icons.chevron_right),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(ActivityFeedRow),
        matching: find.byType(InkWell),
      ),
      findsOneWidget,
    );
  });

  testWidgets('an error with no cached rows offers a retry', (tester) async {
    repo.refreshActivitiesError = StateError('boom');
    await pumpScreen(tester);
    await tester.pump();
    expect(find.byType(ErrorView), findsOneWidget);

    repo.refreshActivitiesError = null;
    final before = repo.refreshActivitiesCalls;
    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    await tester.pump();
    expect(repo.refreshActivitiesCalls, greaterThan(before));
  });

  group('search', () {
    testWidgets('narrows the list and shows a removable chip', (tester) async {
      await pumpScreen(tester);
      await emit(tester, [
        _activity(id: '1', invoiceId: 'inv1', userLabel: 'Alice'),
        _activity(id: '2', invoiceId: 'inv2', userLabel: 'Bob'),
      ]);
      expect(find.byType(ActivityFeedRow), findsNWidgets(2));

      await tester.enterText(find.byType(TextField), 'Bob');
      await tester.pump();
      expect(find.byType(ActivityFeedRow), findsOneWidget);
      expect(find.widgetWithText(InputChip, 'Bob'), findsOneWidget);
    });

    testWidgets('over-filtering offers a way back out', (tester) async {
      await pumpScreen(tester);
      await emit(tester, [_activity(id: '1', invoiceId: 'inv1')]);

      await tester.enterText(find.byType(TextField), 'nothing matches this');
      await tester.pump();
      expect(find.byType(ActivityFeedRow), findsNothing);
      // A dead end on a *bounded* window is the failure mode this guards.
      final clear = find.widgetWithText(TextButton, 'Clear Filters');
      expect(clear, findsOneWidget);

      await tester.tap(clear);
      await tester.pump();
      expect(find.byType(ActivityFeedRow), findsOneWidget);
      expect(find.byType(InputChip), findsNothing);
      // The field follows the ViewModel. Without that binding the box would
      // still read 'nothing matches this' over an unfiltered list — and the
      // same binding is what shows a *restored* filter after a restart.
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        isEmpty,
      );
    });
  });
}
