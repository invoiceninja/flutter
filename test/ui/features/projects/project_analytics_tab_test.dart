import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/services/api_client.dart';
import 'package:admin/data/services/api_credentials.dart';
import 'package:admin/data/services/password_cache.dart';
import 'package:admin/data/services/project_charts_api.dart';
import 'package:admin/ui/features/projects/widgets/detail/analytics/project_analytics_tab.dart';

import '../../../_localization_helper.dart';

final ApiClient _dummyClient = ApiClient(
  credentials: ValueNotifier<ApiCredentials?>(
    const ApiCredentials(baseUrl: 'https://test', token: 't'),
  ),
  passwordCache: PasswordCache(),
  onUnauthorized: () async {},
);

class _FakeProjectChartsApi extends ProjectChartsApi {
  _FakeProjectChartsApi(this.analytics) : super(_dummyClient);

  final Object? analytics;

  @override
  Future<Object?> fetchAnalytics({
    required String projectId,
    required Date startDate,
    required Date endDate,
    bool includeDrafts = false,
  }) async => analytics;

  @override
  Future<Object?> fetchBurnup({
    required String projectId,
    required Date startDate,
    required Date endDate,
    BurnupBucket bucket = BurnupBucket.weekly,
    bool includeDrafts = false,
  }) async => null;
}

class _FakeServices implements Services {
  _FakeServices(this.projectCharts);
  @override
  final ProjectChartsApi projectCharts;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  // The server sends two different ratios: `utilization` is logged ÷ budgeted
  // HOURS, `budget_utilization` is actual ÷ budgeted MONEY. The KPI labelled
  // "Utilization" sits in an hours-led row, and rendering the money ratio there
  // read 0% for any project without a money budget or task rate — the common
  // non-billable case — while the hours ratio was decoded and never shown.
  testWidgets('the Utilization KPI shows the hours ratio', (tester) async {
    final api = _FakeProjectChartsApi({
      'budget_summary': [
        {
          'budgeted_hours': 100.0,
          'current_hours': 50.0,
          'utilization': 0.5, // hours: 50 / 100
          'budgeted_amount': 0.0,
          'remaining_budget': 0.0,
          'budget_utilization': 0.0, // money: no budget → 0
        },
      ],
    });

    await tester.pumpWidget(
      Provider<Services>.value(
        value: _FakeServices(api),
        child: MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: ProjectAnalyticsTab(projectId: 'p1'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('50%'), findsOneWidget);
    expect(
      find.text('0%'),
      findsNothing,
      reason: 'the money ratio must not be shown under an hours label',
    );
    // A project with no money budget shows a dash, not a misleading $0.00.
    expect(find.text('—'), findsWidgets);
  });
}
