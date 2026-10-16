import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/api/project_api_model.dart';
import 'package:admin/data/models/domain/project.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/services/api_client.dart';
import 'package:admin/data/services/api_credentials.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/password_cache.dart';
import 'package:admin/data/services/project_charts_api.dart';
import 'package:admin/ui/features/projects/view_models/project_analytics_view_model.dart';
import 'package:admin/ui/features/projects/widgets/detail/analytics/project_analytics_tab.dart';

import '../../../_localization_helper.dart';

/// What the Analytics tab says, from what the server sent.
///
/// The server answers every block for every project, whatever its numbers
/// mean — so most of these are about a figure it sends that must NOT be
/// shown as it is.

final ApiClient _dummyClient = ApiClient(
  credentials: ValueNotifier<ApiCredentials?>(
    const ApiCredentials(baseUrl: 'https://test', token: 't'),
  ),
  passwordCache: PasswordCache(),
  onUnauthorized: () async {},
);

class _FakeProjectChartsApi extends ProjectChartsApi {
  _FakeProjectChartsApi({this.analytics, this.error}) : super(_dummyClient);

  final Object? analytics;
  final Object? error;

  @override
  Future<Object?> fetchAnalytics({
    required String projectId,
    bool includeDrafts = false,
  }) async {
    if (error != null) throw error!;
    return analytics;
  }

  @override
  Future<Object?> fetchBurnup({
    required String projectId,
    Date? startDate,
    Date? endDate,
    BurnupBucket bucket = BurnupBucket.daily,
    bool includeDrafts = false,
  }) async {
    if (error != null) throw error!;
    return null;
  }
}

const _today = Date(2026, 7, 24);

Project _project({double budgeted = 100, double logged = 50}) =>
    Project.fromApi(
      ProjectApi(
        id: 'p1',
        name: 'Rebuild',
        budgetedHours: budgeted,
        currentHours: logged,
        dueDate: '2026-09-30',
        createdAt: DateTime.utc(2026, 6, 1, 12).millisecondsSinceEpoch ~/ 1000,
        updatedAt: 1,
      ),
    );

Future<void> _pump(
  WidgetTester tester,
  _FakeProjectChartsApi api, {
  Project? project,
}) async {
  tester.view.physicalSize = const Size(1000, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final p = project ?? _project();
  final vm = ProjectAnalyticsViewModel(
    api: api,
    projectId: p.id,
    companyId: 'co',
    projectStart: const Date(2026, 6, 1),
    projectDue: p.dueDate,
    today: _today,
  );
  addTearDown(vm.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildInTheme(InTheme.light),
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: kTestSupportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: ProjectAnalyticsTab(project: p, viewModel: vm),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Map<String, dynamic> _row(Map<String, dynamic> fields) => {
  'project_id': 'p1',
  ...fields,
};

void main() {
  group('Forecast', () {
    testWidgets('the server\'s pace, when it means something', (tester) async {
      await _pump(
        tester,
        _FakeProjectChartsApi(
          analytics: {
            'estimated_vs_logged_hours': [
              _row({'estimated_hours': 100.0, 'logged_hours': 50.0}),
            ],
            'forecast_completion': [
              _row({
                'average_daily_velocity': 5.0,
                'remaining_hours': 50.0,
                'forecast_finish_date': '2026-08-03',
                'due_date': '2026-09-30',
                'schedule_variance_days': 58,
              }),
            ],
          },
        ),
      );
      expect(find.text('FORECAST FINISH'), findsOneWidget);
      expect(find.text('DAYS AHEAD'), findsOneWidget);
      expect(find.text('58'), findsOneWidget);
    });

    testWidgets('no hours budget: no forecast — the server says "today"', (
      tester,
    ) async {
      await _pump(
        tester,
        _FakeProjectChartsApi(
          analytics: {
            'estimated_vs_logged_hours': [
              _row({'estimated_hours': 0.0, 'logged_hours': 12.0}),
            ],
            'forecast_completion': [
              _row({
                'average_daily_velocity': 3.0,
                'remaining_hours': 0.0,
                'forecast_finish_date': '2026-07-24',
                'schedule_variance_days': 68,
              }),
            ],
          },
        ),
        project: _project(budgeted: 0, logged: 12),
      );
      expect(find.textContaining('budgeted hours'), findsOneWidget);
      expect(find.text('FORECAST FINISH'), findsNothing);
      expect(find.text('DAYS AHEAD'), findsNothing);
    });

    testWidgets('over budget says so, not "finishes today, days ahead"', (
      tester,
    ) async {
      await _pump(
        tester,
        _FakeProjectChartsApi(
          analytics: {
            'estimated_vs_logged_hours': [
              _row({'estimated_hours': 100.0, 'logged_hours': 150.0}),
            ],
            'forecast_completion': [
              _row({
                'average_daily_velocity': 5.0,
                'remaining_hours': 0.0,
                'forecast_finish_date': '2026-07-24',
                'schedule_variance_days': 68,
              }),
            ],
          },
        ),
        project: _project(budgeted: 100, logged: 150),
      );
      expect(find.text('OVER BUDGET'), findsOneWidget);
      expect(find.text('+50 h'), findsOneWidget);
      expect(find.text('DAYS AHEAD'), findsNothing);
    });

    testWidgets('a user who may not see the money: their own time, no slip', (
      tester,
    ) async {
      await _pump(
        tester,
        _FakeProjectChartsApi(
          analytics: {
            'budget_summary': <Object>[],
            'forecast_completion': [
              _row({
                'average_daily_velocity': 1.0,
                'remaining_hours': 50.0,
                'forecast_finish_date': '2026-09-12',
                'due_date': '2026-09-30',
                'schedule_variance_days': 18,
              }),
            ],
            'project_health': <Object>[],
            'metadata': {'can_view_financials': false},
          },
        ),
      );
      expect(find.textContaining('time you logged'), findsOneWidget);
      expect(find.text('FORECAST FINISH'), findsOneWidget);
      expect(
        find.text('DAYS AHEAD'),
        findsNothing,
        reason: 'one person\'s pace against the whole project\'s budget',
      );
      expect(find.text('Money'), findsNothing);
      expect(find.text('Include Drafts'), findsNothing);
      expect(
        find.textContaining('No analytics data'),
        findsNothing,
        reason: 'every block it reads is one the server sends them empty',
      );
    });
  });

  testWidgets('a new project is "no data", not a page of zeros and a '
      'green 100', (tester) async {
    await _pump(
      tester,
      _FakeProjectChartsApi(
        analytics: {
          'budget_summary': [
            _row({'budgeted_hours': 100.0}),
          ],
          'project_health': [
            _row({'health_score': 100.0, 'health_status': 'green'}),
          ],
          'metadata': {'can_view_financials': true},
        },
      ),
      project: _project(logged: 0),
    );
    expect(find.text('Good'), findsNothing);
    expect(find.text('100 / 100'), findsNothing);
    expect(find.textContaining('No analytics data'), findsOneWidget);
  });

  testWidgets('health in its own words, with a dash for a ratio over nothing', (
    tester,
  ) async {
    await _pump(
      tester,
      _FakeProjectChartsApi(
        analytics: {
          'estimated_vs_logged_hours': [
            _row({'estimated_hours': 100.0, 'logged_hours': 50.0}),
          ],
          'project_health': [
            _row({
              'health_score': 62.5,
              'health_status': 'amber',
              'indicators': {
                'budget_utilization': 0.0,
                'schedule_variance_days': -3,
                'margin_ratio': 0.0,
                'unbilled_ratio': 0.5,
                'outstanding_ratio': 0.0,
              },
            }),
          ],
          'invoice_progress': [
            _row({'work_value': 1000.0}),
          ],
          'metadata': {'can_view_financials': true},
        },
      ),
    );
    expect(find.text('Fair'), findsOneWidget);
    expect(find.text('63 / 100'), findsOneWidget);
    expect(find.text('On track'), findsNothing);
    // Nothing invoiced and no money budget: those shares are unknown.
    expect(find.text('—'), findsWidgets);
    expect(find.text('50%'), findsOneWidget, reason: 'unbilled share');
  });

  testWidgets('offline with nothing to show says so, with Retry', (
    tester,
  ) async {
    await _pump(
      tester,
      _FakeProjectChartsApi(error: const NetworkException('offline')),
    );
    expect(find.textContaining('need a connection'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.textContaining("aren't available"), findsNothing);
  });
}
