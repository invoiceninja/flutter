import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/utils/formatting.dart';
import 'package:admin/ui/features/dashboard/helpers/range_dates.dart';
import 'package:admin/ui/features/dashboard/view_models/dashboard_view_model.dart';
import 'package:admin/ui/features/dashboard/widgets/dashboard_refresh_button.dart';
import 'package:admin/ui/features/dashboard/widgets/filters/date_range_picker_button.dart';
import 'package:admin/ui/features/dashboard/widgets/filters/settings_popover.dart';
import 'package:admin/ui/features/dashboard/widgets/freshness.dart';
import 'package:admin/ui/features/dashboard/widgets/manage_dashboard_cards_sheet.dart';

/// Wide-layout TopBar shown above the dashboard scroll. Matches
/// `screens.jsx:196-201`: title = company name, subtitle = "{active date
/// range} · Updated N ago", actions = refresh + combined date-range/filter
/// popover + settings + "New invoice". Currency and include-drafts are folded
/// into the date-range popover.
///
/// The freshness stamp is metadata, so it rides the subtitle rather than the
/// action cluster: it re-measures itself every 30 s, and a self-changing width
/// inside the (bounded) actions `Wrap` could flip a run and shift the whole
/// page while the user is reading it. Pull-to-refresh still works.
///
/// Mobile uses a standard `AppBar` instead — see `DashboardScreen` for the
/// narrow path, which since flutter#51 is "narrow pane **or** phone": a handset
/// in landscape leaves a ~660 px pane, wide enough by width alone but nowhere
/// near enough for this bar's title column plus five full-label buttons.
class DashboardTopBar extends StatelessWidget {
  const DashboardTopBar({
    super.key,
    required this.vm,
    required this.companyName,
    required this.onRefresh,
    this.onNewInvoice,
    this.formatter,
  });

  final DashboardViewModel vm;
  final String companyName;

  /// Re-pull every dashboard section. Routed through `DashboardScreen` rather
  /// than straight to `vm.refresh` so a failed pass can surface a toast.
  final VoidCallback onRefresh;

  /// Null when the invoices module is disabled — the primary "New invoice"
  /// button is then omitted entirely.
  final VoidCallback? onNewInvoice;

  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    // The active window, stated in full. This used to read
    // "Dashboard · <end month> <year>", which named only the *last* month of a
    // multi-month range — "Last quarter" showed as "June 2026" (flutter#37).
    // The word "Dashboard" went with it: the subtitle is capped at 280 px with
    // a single ellipsised line, and keeping it pushed the freshness stamp off
    // the end. The sidebar already says which page this is.
    final subtitle = dashboardRangeDates(
      context,
      vm.filter,
      formatter: formatter,
    );
    final newInvoiceLabel = context.tr('new_invoice');

    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      padding: EdgeInsets.fromLTRB(
        InSpacing.xl,
        InSpacing.md(context),
        InSpacing.xl,
        InSpacing.md(context),
      ),
      child: Row(
        children: [
          // Title is NON-flex (capped + ellipsised) so the actions `Expanded`
          // is the only flex child and the Wrap gets every remaining pixel —
          // mirrors `entity_edit_scaffold`'s wide header. A flex *ratio* here
          // would cap the actions at a fixed fraction and wrap them even when
          // the title left room; leaving the Wrap non-flex (as before) gives
          // it unbounded width, so it takes its full natural size and crushes
          // the title instead.
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  companyName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: tokens.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                // Subtitle carries the freshness stamp. One string, one
                // ellipsis — no nested Row, so nothing to baseline-align and
                // no width change that can reach the action cluster.
                FreshnessTicker(
                  builder: (context) => Text(
                    '$subtitle · '
                    '${freshnessText(context, lastRefreshed: vm.lastRefreshed, isRefreshing: vm.isAnyRefreshing)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: tokens.ink3),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: InSpacing.md(context)),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              // Fill horizontally (that's what keeps the cluster flush right
              // and bounds the Wrap), but shrink-wrap vertically: an Align
              // with a null factor expands to any *bounded* incoming extent,
              // so without this the bar stretches to fill a height-constrained
              // slot. The screen's Column happens to pass unbounded height
              // today; don't leave that load-bearing.
              heightFactor: 1,
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: InSpacing.sm,
                // Needed now that the Wrap is bounded and can actually break:
                // without it two runs of 44 px buttons would touch.
                runSpacing: InSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Refresh stays first: a second run is end-aligned, so the
                  // lowest-priority control should lead (and "New invoice",
                  // the primary CTA, is last to drop).
                  DashboardRefreshButton(
                    isRefreshing: vm.isAnyRefreshing,
                    onRefresh: onRefresh,
                  ),
                  DateRangePickerButton(
                    current: vm.filter.range,
                    onChange: vm.setDateRange,
                    formatter: formatter,
                  ),
                  DashboardSettingsButton(vm: vm),
                  DashboardCardsButton(vm: vm, mobileLayout: false),
                  if (onNewInvoice != null)
                    FilledButton.icon(
                      onPressed: onNewInvoice,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(64, 44),
                      ),
                      icon: const Icon(Icons.add, size: 14),
                      label: Text(newInvoiceLabel),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
