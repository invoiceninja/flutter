// Responsive regression net. Sweeps representative layout-bearing widgets
// across narrow / medium / wide surfaces and fails on any RenderFlex
// overflow or unbounded-constraint violation. The point is a cheap guard so
// a stray full-width `Expanded` / unconstrained `Row` doesn't silently break
// the mobile (or wide) layout — exactly the gap the foundation audit flagged.
//
// Scope: Services-free widgets only, with one exception — ClientDetailProfile
// renders phone numbers, and tap-to-call's `PhoneActionsScope` reads
// `Provider<Services>`, so it opts into `pumpAt(phoneActions: true)`'s minimal
// harness. Full feature screens (list / edit / settings) need the real
// `Provider<Services>` harness; pulling each through here is the documented
// follow-up (see the plan's C3 reasoning — the VM-level pattern is the cheaper
// canonical edit/list assertion). New responsive bugs in pure layout widgets
// belong here; add the widget + a width sweep.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/client_api_model.dart';
import 'package:admin/data/models/api/contact_api_model.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/project/project_analytics.dart';
import 'package:admin/data/models/domain/project/project_burnup.dart';
import 'package:admin/data/models/domain/system_log.dart';
import 'package:admin/data/models/value/dashboard_filter.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/features/clients/widgets/detail/client_detail_profile.dart';
import 'package:admin/ui/features/dashboard/widgets/filters/date_range_picker_button.dart';
import 'package:admin/data/services/api_client.dart';
import 'package:admin/data/services/api_credentials.dart';
import 'package:admin/data/services/password_cache.dart';
import 'package:admin/data/services/project_charts_api.dart';
import 'package:admin/ui/features/projects/view_models/project_analytics_view_model.dart';
import 'package:admin/ui/features/projects/widgets/detail/analytics/expenses_section.dart';
import 'package:admin/ui/features/projects/widgets/detail/analytics/forecast_section.dart';
import 'package:admin/ui/features/projects/widgets/detail/analytics/money_section.dart';
import 'package:admin/ui/features/projects/widgets/detail/analytics/project_burnup_chart.dart';
import 'package:admin/ui/features/projects/widgets/detail/analytics/time_section.dart';
import 'package:admin/ui/features/settings/widgets/system_log_row.dart';

import '../_responsive_helper.dart';

void main() {
  group('no overflow across breakpoints', () {
    for (final width in kResponsiveWidths) {
      testWidgets('ClientDetailProfile @ ${width.toInt()}px', (tester) async {
        final client = Client.fromApi(
          ClientApi(
            id: 'c1',
            name: 'Acme Corporation',
            phone: '555-0100',
            // Long values, an address and a contact so the profile renders
            // its 3-column wide row (Contacts · Details · Address) — exercises
            // overflow at the ~321 px/card width the 1000 px breakpoint
            // introduces. Two contacts: the summary card above the profile
            // takes the first, and the profile lists the rest.
            website:
                'https://www.acme-corporation-international-holdings.example.com/portal',
            address1:
                '1 Extraordinarily Long Street Name Boulevard, Suite 4000',
            contacts: const [
              ContactApi(id: 'lead', firstName: 'Lee', isPrimary: true),
              ContactApi(
                id: 'second',
                firstName: 'Alexandra',
                lastName: 'Montgomery-Worthington',
                email:
                    'alexandra.montgomery.worthington@a-very-long-enterprise-domain.example.com',
                phone: '555-0100',
              ),
            ],
            updatedAt: 1,
          ),
        );
        await pumpAt(
          tester,
          width,
          ClientDetailProfile(client: client, company: null),
          // The one widget here that isn't Services-free: its phone rows go
          // through `PhoneActionsScope`. The minimal harness also hands it a
          // foreign timezone, so the local-time suffix and the contact row's
          // Call / Message buttons are part of what this sweep measures.
          phoneActions: true,
        );
        expectNoOverflow(tester);
      });

      testWidgets('SystemLogRow @ ${width.toInt()}px', (tester) async {
        // Shared by Settings → System Logs, the gateway-detail card, and the
        // client-detail tab. Collapsed JSON preview + responsive left-column /
        // stacked layout must not overflow at any width.
        await pumpAt(
          tester,
          width,
          SystemLogRow(
            log: SystemLog(
              id: 's1',
              companyId: 'c1',
              userId: 'u1',
              clientId: 'cli_1',
              eventId: 32,
              categoryId: 2,
              typeId: 301,
              log: '{"error":"missing from header","code":422}',
              createdAt: DateTime.utc(2026, 5, 1),
              updatedAt: DateTime.utc(2026, 5, 1),
            ),
            isWide: width >= 600,
          ),
        );
        expectNoOverflow(tester);
      });

      for (final scale in const [1.0, 1.4]) {
        testWidgets(
          'Project analytics sections @ ${width.toInt()}px x$scale',
          (tester) => _pumpAnalytics(tester, width, scale),
        );
      }

      testWidgets('EmptyState with action @ ${width.toInt()}px', (
        tester,
      ) async {
        await pumpAt(
          tester,
          width,
          EmptyState(
            icon: Icons.inbox_outlined,
            title: 'Nothing here yet',
            subtitle: 'Create your first record to get started.',
            action: FilledButton(
              onPressed: () {},
              child: const Text('New record'),
            ),
          ),
          scroll: false,
        );
        expectNoOverflow(tester);
      });
    }
  });

  group('project analytics at phone widths', () {
    for (final width in const [320.0, 360.0]) {
      for (final scale in const [1.0, 1.4]) {
        testWidgets(
          '@ ${width.toInt()}px x$scale',
          (tester) => _pumpAnalytics(tester, width, scale),
        );
      }
    }
  });

  // The date-range popover is shared by the dashboard, client statements,
  // reports and every list's filter / segment menus, and it gets squeezed
  // hardest — a 320 px device leaves it 288 px to fit a preset rail, a
  // calendar and two date fields (invoiceninja/flutter#38).
  //
  // A local width list rather than `kResponsiveWidths`: the phone widths below
  // matter for this widget specifically, and adding them to the shared list
  // would drag ClientDetailProfile / SystemLogRow / the project analytics sections /
  // EmptyState into widths they were never designed against.
  //
  // Note what this can and can't catch: soft-wrapped text and clipped content
  // throw nothing, so `expectNoOverflow` stays green through the original bug.
  // It guards the parts that *do* throw — chiefly the Cancel/Apply row, which
  // needs ~148 px and overflows a `Row` in the narrowest compact column.
  group('DashboardDateRangePopover across breakpoints', () {
    for (final width in const <double>[288, 328, 360, ...kResponsiveWidths]) {
      testWidgets('@ ${width.toInt()}px', (tester) async {
        await pumpAt(
          tester,
          width,
          DashboardDateRangePopover(
            current: DashboardCustomRange(
              start: const Date(2026, 3, 1),
              end: const Date(2026, 4, 20),
            ),
          ),
        );
        expectNoOverflow(tester);
      });
    }
  });
}

/// The Analytics tab's five sections — the burn-up's controls and legend,
/// the figure rows, the bar lists with their clamped labels, the category
/// ring, the velocity and spend plots — with every block filled and one long
/// task name.
Future<void> _pumpAnalytics(
  WidgetTester tester,
  double width,
  double scale,
) async {
  // the category ring, the velocity and spend plots — with every
  final vm = ProjectAnalyticsViewModel(
    api: ProjectChartsApi(_dummyClient),
    projectId: 'p1',
    companyId: 'co',
    projectStart: const Date(2026, 6, 1),
    today: const Date(2026, 7, 24),
  );
  addTearDown(vm.dispose);
  final analytics = ProjectAnalytics.fromJson(_analyticsFixture);
  await pumpAt(
    tester,
    width,
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ForecastSection(
          analytics: analytics,
          projectBudgetedHours: 40,
          projectLoggedHours: 12.5,
          projectDueDate: const Date(2026, 9, 30),
          formatter: null,
        ),
        ProjectBurnupSection(
          vm: vm,
          burnup: ProjectBurnup.fromJson(_burnupFixture),
        ),
        MoneySection(analytics: analytics, formatter: null),
        TimeSection(
          analytics: analytics,
          formatter: null,
          today: const Date(2026, 7, 24),
        ),
        ExpensesSection(
          analytics: analytics,
          formatter: null,
          today: const Date(2026, 7, 24),
        ),
      ],
    ),
    height: 4200,
    textScale: scale,
  );
  expectNoOverflow(tester);
}

/// Never called: the sections are pumped with their data, not fetched.
final ApiClient _dummyClient = ApiClient(
  credentials: ValueNotifier<ApiCredentials?>(
    const ApiCredentials(baseUrl: 'https://test', token: 't'),
  ),
  passwordCache: PasswordCache(),
  onUnauthorized: () async {},
);

Map<String, dynamic> _block(String key, List<Map<String, dynamic>> rows) => {
  key: [
    {'project_id': 'p1', key: rows},
  ],
};

final Map<String, dynamic> _analyticsFixture = {
  'budget_summary': [
    {
      'budgeted_hours': 40.0,
      'current_hours': 12.5,
      'task_rate': 100.0,
      'total_tasks': 12,
      'budgeted_amount': 4000.0,
      'actual_amount': 1500.0,
      'currency_id': '1',
    },
  ],
  'budget_vs_actual': [
    {
      'budgeted_amount': 4000.0,
      'actual_amount': 1500.0,
      'labor_value': 1250.0,
      'expense_amount': 250.0,
    },
  ],
  'estimated_vs_logged_hours': [
    {
      'estimated_hours': 40.0,
      'logged_hours': 12.5,
      'billable_hours': 10.0,
      'remaining_hours': 27.5,
      'task_estimated_hours': 30.0,
      'remaining_estimated_hours': 20.0,
      'unestimated_active_task_count': 2,
      'active_tasks_over_estimate_count': 1,
    },
  ],
  'invoice_progress': [
    {
      'work_value': 1250.0,
      'invoiced_amount': 600.0,
      'paid_amount': 400.0,
      'outstanding_amount': 200.0,
      'unbilled_amount': 650.0,
    },
  ],
  'forecast_completion': [
    {
      'average_daily_velocity': 2.5,
      'remaining_hours': 27.5,
      'forecast_finish_date': '2026-08-04',
      'due_date': '2026-09-30',
      'schedule_variance_days': 57,
    },
  ],
  'timeline_variance': [
    {'completion_percentage': 31.25, 'ideal_progress_percentage': 44.4},
  ],
  'unbilled_hours': [
    {'unbilled_hours': 6.5, 'unbilled_amount': 650.0, 'uninvoiced_tasks': 5},
  ],
  'profitability': [
    {
      'invoiced_amount': 600.0,
      'expense_amount': 250.0,
      'net_margin': 350.0,
      'margin_ratio': 0.5833,
    },
  ],
  'project_health': [
    {
      'health_score': 81.5,
      'health_status': 'green',
      'indicators': {
        'budget_utilization': 0.375,
        'schedule_variance_days': 57,
        'margin_ratio': 0.5833,
        'unbilled_ratio': 0.52,
        'outstanding_ratio': 0.3333,
      },
    },
  ],
  ..._block('team_contribution', [
    for (var i = 0; i < 4; i++)
      {'user_id': 'u$i', 'user_name': 'Person $i', 'logged_hours': 3.0 + i},
  ]),
  ..._block('time_distribution', [
    {
      'task_id': 't0',
      'task_number': '0001',
      'description':
          'An extraordinarily long task description that has to be clamped '
          'to its label column rather than push the bar off the card',
      'logged_hours': 6.0,
    },
    for (var i = 1; i < 12; i++)
      {'task_id': 't$i', 'task_number': '000$i', 'logged_hours': 0.5 * i},
  ]),
  ..._block('velocity_trend', [
    {'period': '2026-06-02', 'hours': 3.0, 'billable_hours': 2.0},
    {'period': '2026-06-20', 'hours': 5.5, 'billable_hours': 5.0},
    {'period': '2026-07-21', 'hours': 4.0, 'billable_hours': 3.0},
  ]),
  ..._block('expense_breakdown', [
    {'category_id': 'e1', 'category_name': 'Travel', 'expense_amount': 150.0},
    {
      'category_id': null,
      'category_name': 'Uncategorized',
      'expense_amount': 100.0,
    },
  ]),
  ..._block('cumulative_spend', [
    {
      'period': '2026-06-02',
      'cumulative_labor_value': 300.0,
      'cumulative_expense_amount': 0.0,
      'cumulative_actual_amount': 300.0,
    },
    {
      'period': '2026-07-21',
      'cumulative_labor_value': 1250.0,
      'cumulative_expense_amount': 250.0,
      'cumulative_actual_amount': 1500.0,
    },
  ]),
  'metadata': {'can_view_financials': true, 'include_drafts': true},
};

const Map<String, dynamic> _burnupFixture = {
  'start_date': '2026-06-01',
  'end_date': '2026-09-30',
  'bucket_type': 'monthly',
  'project': {'budgeted_amount': 4000.0, 'currency_id': '1'},
  'markers': {
    'due_date': '2026-09-30',
    'budgeted_hours': 40.0,
    'budgeted_amount': 4000.0,
    'task_estimated_hours': 30.0,
  },
  'metadata': {'unestimated_task_count': 2},
  'series': [
    {
      'period_end': '2026-06-30',
      'cumulative_logged_hours': 5.0,
      'cumulative_billable_hours': 4.0,
      'cumulative_invoiced_amount': 300.0,
      'cumulative_paid_to_date': 100.0,
      'cumulative_net_invoiced_amount': 250.0,
      'ideal_hours': 13.3,
      'ideal_amount': 1330.0,
    },
    {
      'period_end': '2026-07-31',
      'cumulative_logged_hours': 12.5,
      'cumulative_billable_hours': 11.0,
      'cumulative_invoiced_amount': 600.0,
      'cumulative_paid_to_date': 400.0,
      'cumulative_net_invoiced_amount': 350.0,
      'ideal_hours': 26.6,
      'ideal_amount': 2660.0,
    },
  ],
};
