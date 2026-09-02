// Responsive regression net. Sweeps representative layout-bearing widgets
// across narrow / medium / wide surfaces and fails on any RenderFlex
// overflow or unbounded-constraint violation. The point is a cheap guard so
// a stray full-width `Expanded` / unconstrained `Row` doesn't silently break
// the mobile (or wide) layout — exactly the gap the foundation audit flagged.
//
// Scope: Services-free widgets only, with one exception — ClientDetailCardsGrid
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
import 'package:admin/data/models/domain/project/project_burnup.dart';
import 'package:admin/data/models/domain/system_log.dart';
import 'package:admin/data/models/value/dashboard_filter.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/features/clients/widgets/detail/client_detail_cards_grid.dart';
import 'package:admin/ui/features/dashboard/widgets/filters/date_range_picker_button.dart';
import 'package:admin/ui/features/projects/widgets/detail/analytics/project_burnup_chart.dart';
import 'package:admin/ui/features/settings/widgets/system_log_row.dart';

import '../_responsive_helper.dart';

void main() {
  group('no overflow across breakpoints', () {
    for (final width in kResponsiveWidths) {
      testWidgets('ClientDetailCardsGrid @ ${width.toInt()}px', (tester) async {
        final client = Client.fromApi(
          ClientApi(
            id: 'c1',
            name: 'Acme Corporation',
            phone: '555-0100',
            // Long values + a contact so the grid renders its 3-column wide
            // layout (Details · Address · Contacts) — exercises overflow at
            // the ~321 px/card width the 1000 px breakpoint introduces.
            website:
                'https://www.acme-corporation-international-holdings.example.com/portal',
            contacts: const [
              ContactApi(
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
          ClientDetailCardsGrid(client: client, formatter: null),
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

      testWidgets('ProjectBurnupChart @ ${width.toInt()}px', (tester) async {
        // The Analytics tab's chart: fl_chart plot + a Wrap legend + a
        // width-derived clamped height. The endpoints still 404 on the demo
        // host, so this sweep is the only pre-deploy check that the card
        // lays out at every breakpoint.
        await pumpAt(
          tester,
          width,
          ProjectBurnupChart(
            burnup: ProjectBurnup.fromJson(const {
              'bucket_type': 'monthly',
              'project': {'budgeted_amount': 4000.0, 'currency_id': '1'},
              'markers': {'budgeted_hours': 40.0, 'budgeted_amount': 4000.0},
              'series': [
                {
                  'period_end': '2026-01-31',
                  'cumulative_logged_hours': 5.0,
                  'cumulative_billable_hours': 4.0,
                  'cumulative_invoiced_amount': 300.0,
                  'cumulative_paid_to_date': 100.0,
                  'ideal_hours': 13.3,
                  'ideal_amount': 1330.0,
                },
                {
                  'period_end': '2026-02-28',
                  'cumulative_logged_hours': 12.5,
                  'cumulative_billable_hours': 11.0,
                  'cumulative_invoiced_amount': 600.0,
                  'cumulative_paid_to_date': 400.0,
                  'ideal_hours': 26.6,
                  'ideal_amount': 2660.0,
                },
              ],
            }),
            formatter: null,
          ),
        );
        expectNoOverflow(tester);
      });

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

  // The date-range popover is shared by the dashboard, client statements,
  // reports and every list's filter / segment menus, and it gets squeezed
  // hardest — a 320 px device leaves it 288 px to fit a preset rail, a
  // calendar and two date fields (invoiceninja/flutter#38).
  //
  // A local width list rather than `kResponsiveWidths`: the phone widths below
  // matter for this widget specifically, and adding them to the shared list
  // would drag ClientDetailCardsGrid / SystemLogRow / ProjectBurnupChart /
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
