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
import 'package:admin/data/models/domain/user.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/dashboard_repository.dart';
import 'package:admin/data/repositories/user_repository.dart';
import 'package:admin/data/services/dashboard_api.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/core/widgets/error_view.dart';
import 'package:admin/ui/core/widgets/filter_icon_button.dart';
import 'package:admin/ui/features/activity/views/activity_screen.dart';
import 'package:admin/ui/features/activity/widgets/activity_feed_row.dart';
import 'package:admin/ui/features/activity/widgets/activity_filter_sheet.dart';
import 'package:admin/ui/features/activity/widgets/activity_timeline_chart.dart';
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

/// The wide pane's filter rail lists the roster.
class _FakeUserRepo implements UserRepository {
  @override
  Stream<List<User>> watchAllForPicker({required String companyId}) =>
      Stream<List<User>>.value(const <User>[]);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
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
  late final UserRepository user = _FakeUserRepo();

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
  String? userId,
  int? createdAt,
}) => DashboardActivity.fromJson(<String, dynamic>{
  'id': id,
  'activity_type_id': type,
  'created_at': createdAt ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
  'notes': '',
  'ip': '10.0.0.1',
  if (userLabel != null)
    'user': {'label': userLabel, 'hashed_id': userId ?? 'u_$id'},
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

  Future<void> pumpScreen(
    WidgetTester tester, {
    Size size = const Size(500, 900),
  }) async {
    await tester.binding.setSurfaceSize(size);
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

  group('load more', () {
    Finder feed() => find.descendant(
      of: find.byType(ListView),
      matching: find.byType(Scrollable),
    );

    List<DashboardActivity> window(int n) => [
      for (var i = 0; i < n; i++) _activity(id: '$i', invoiceId: 'inv$i'),
    ];

    testWidgets('a full window offers it under the feed', (tester) async {
      await pumpScreen(tester);
      await emit(tester, window(kActivityFeedRows));
      final button = find.widgetWithText(OutlinedButton, 'Load more');
      await tester.scrollUntilVisible(button, 2000, scrollable: feed());
      // `scrollUntilVisible` stops once any of it is on screen; the tap needs
      // its centre.
      await tester.ensureVisible(button);
      await tester.pump();
      await tester.tap(button);
      await tester.pump();
      expect(repo.loadOlderActivitiesCalls, 1);
    });

    testWidgets('and above it, where the timeline ends', (tester) async {
      await pumpScreen(tester);
      await emit(tester, window(kActivityFeedRows));
      await tester.tap(find.widgetWithText(TextButton, 'Load more'));
      await tester.pump();
      expect(repo.loadOlderActivitiesCalls, 1);
    });

    testWidgets('a short window offers neither', (tester) async {
      await pumpScreen(tester);
      await emit(tester, window(3));
      expect(find.text('Load more'), findsNothing);
    });

    testWidgets('at the max, the footer points to the Activity report', (
      tester,
    ) async {
      await pumpScreen(tester);
      // A server without the feed cursor: the window stops at the lower cap.
      repo.cursorSupported = false;
      await emit(tester, window(kActivityWindowMax));
      expect(find.text('Load more'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Open the Activity report'),
        5000,
        scrollable: feed(),
      );
      expect(find.text('Open the Activity report'), findsOneWidget);
    });
  });

  testWidgets('groups rows under a day header', (tester) async {
    await pumpScreen(tester);
    await emit(tester, [_activity(id: '1', invoiceId: 'inv1')]);
    // The header is a node on the timeline spine, and says how many events
    // the day holds.
    expect(find.text('Today · 1 event'), findsOneWidget);
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

  group('layout', () {
    testWidgets('a wide pane shows the filters as a rail, with no button', (
      tester,
    ) async {
      await pumpScreen(tester, size: const Size(1200, 900));
      await emit(tester, [_activity(id: '1', invoiceId: 'inv1')]);
      expect(find.byType(ActivityFilterPanel), findsOneWidget);
      // Two controls for one state is the thing the rail replaces.
      expect(find.byType(FilterIconButton), findsNothing);
      final chart = tester.widget<ActivityTimelineChart>(
        find.byType(ActivityTimelineChart),
      );
      expect(chart.compact, isFalse);
    });

    testWidgets('a narrow pane keeps the button and a compact timeline', (
      tester,
    ) async {
      await pumpScreen(tester);
      await emit(tester, [_activity(id: '1', invoiceId: 'inv1')]);
      expect(find.byType(ActivityFilterPanel), findsNothing);
      expect(find.byType(FilterIconButton), findsOneWidget);
      final chart = tester.widget<ActivityTimelineChart>(
        find.byType(ActivityTimelineChart),
      );
      expect(chart.compact, isTrue);
    });

    testWidgets('a short pane drops the timeline, not the feed', (
      tester,
    ) async {
      await pumpScreen(tester, size: const Size(800, 420));
      await emit(tester, [_activity(id: '1', invoiceId: 'inv1')]);
      expect(find.byType(ActivityTimelineChart), findsNothing);
      expect(find.byType(ActivityFeedRow), findsOneWidget);
    });
  });

  group('timeline', () {
    testWidgets('tapping a bar keeps that period, and tapping it again '
        'lets go', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpScreen(tester);
      final now = DateTime.now();
      final old = DateTime(now.year, now.month, now.day - 3, 12);
      await emit(tester, [
        _activity(id: '1', invoiceId: 'inv1'),
        _activity(
          id: '2',
          invoiceId: 'inv2',
          createdAt: old.millisecondsSinceEpoch ~/ 1000,
        ),
      ]);
      expect(find.byType(ActivityFeedRow), findsNWidgets(2));

      // No company `Formatter` here, so a day reads as ISO.
      final iso = Date(old.year, old.month, old.day).toIso();
      final bar = find.bySemanticsLabel(RegExp('^${RegExp.escape(iso)}: '));
      await tester.tap(bar);
      await tester.pump();
      expect(find.byType(ActivityFeedRow), findsOneWidget);
      expect(find.widgetWithText(InputChip, iso), findsOneWidget);

      await tester.tap(bar);
      await tester.pump();
      expect(find.byType(ActivityFeedRow), findsNWidgets(2));
      expect(find.byType(InputChip), findsNothing);
      semantics.dispose();
    });
  });

  group('runs', () {
    testWidgets('a burst on one record folds behind "+N more"', (tester) async {
      await pumpScreen(tester);
      final now = DateTime.now();
      int at(int minute) =>
          DateTime(
            now.year,
            now.month,
            now.day,
            12,
            minute,
          ).millisecondsSinceEpoch ~/
          1000;
      await emit(tester, [
        for (final m in [3, 2, 1])
          _activity(
            id: 'r$m',
            invoiceId: 'inv1',
            userId: 'alice',
            createdAt: at(m),
          ),
      ]);
      expect(find.byType(ActivityFeedRow), findsOneWidget);

      await tester.tap(find.text('+2 more'));
      await tester.pump();
      expect(find.byType(ActivityFeedRow), findsNWidgets(3));

      await tester.tap(find.text('Collapse'));
      await tester.pump();
      expect(find.byType(ActivityFeedRow), findsOneWidget);
    });
  });
}
