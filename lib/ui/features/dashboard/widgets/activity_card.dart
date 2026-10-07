import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_activity.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/activity/activity_deep_link.dart';
import 'package:admin/ui/features/activity/widgets/activity_feed_row.dart';
import 'package:admin/ui/features/dashboard/helpers/activity_formatter.dart';
import 'package:admin/ui/features/dashboard/view_models/async_section.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/ui/features/dashboard/widgets/dashboard_panel_grid.dart';
import 'package:admin/ui/features/dashboard/widgets/list_card.dart';

/// "Activity" feed — 5 most recent rows, tone-tinted circle + templated text +
/// meta line. Matches `screens.jsx:268–295`.
class ActivityCard extends StatelessWidget {
  const ActivityCard({
    super.key,
    required this.section,
    required this.onViewAll,
    required this.onRetry,
    required this.onActivityTap,
  });

  final AsyncSection<List<DashboardActivity>> section;

  /// "View all" footer link tap — the `/activity` screen. **Null hides the
  /// link entirely**, so a host with no destination shows no dead affordance
  /// rather than a "coming soon" snackbar.
  final VoidCallback? onViewAll;
  final VoidCallback onRetry;

  /// Fired when an activity row is tapped. The dashboard resolves the most
  /// specific entity referenced (invoice > quote > payment > recurring >
  /// expense > client) and navigates there. Rows that reference no entity
  /// never fire it — they render inert (no ripple, no chevron) rather than as
  /// a dead tap.
  final void Function(DashboardActivity) onActivityTap;

  @override
  Widget build(BuildContext context) {
    final state = section.listState;
    final short =
        state == ListSectionState.empty || state == ListSectionState.failed;
    // Beside the chart this card is stretched to the row's height — see
    // `DashboardPanelCell`.
    final centred = short && DashboardPanelCell.stretchedOf(context);
    return DashboardCardShell(
      title: context.tr('activity'),
      trailing: onViewAll == null
          ? null
          : DashboardCardFooterLink(
              label: context.tr('view_all'),
              onTap: onViewAll,
            ),
      // The one-line states bring the panels' own padding; the feed rows and
      // their skeleton use the shell's.
      padding: short ? EdgeInsets.zero : null,
      bodyFills: centred,
      child: centred ? Center(child: _body(context)) : _body(context),
    );
  }

  Widget _body(BuildContext context) {
    switch (section.listState) {
      // The same one-line states as every list panel — this card sits beside
      // the chart, which fills whatever height is left over.
      case ListSectionState.failed:
        return DashboardPanelError(onRetry: onRetry);
      case ListSectionState.loading:
        return const ActivityFeedSkeleton();
      case ListSectionState.empty:
        return DashboardPanelMessage(title: context.tr('no_activity_yet'));
      case ListSectionState.rows:
        break;
    }
    final formatter = ActivityFormatter(context);
    final tokens = context.inTheme;
    final visible = section.data!.take(5).toList();
    return Column(
      children: [
        for (var i = 0; i < visible.length; i++) ...[
          _row(formatter, visible[i]),
          if (i != visible.length - 1)
            Divider(height: 1, thickness: 1, color: tokens.border),
        ],
      ],
    );
  }

  /// A row is only a navigation target when the activity references an entity;
  /// [ActivityFeedRow] renders the rest inert rather than as a dead tap.
  Widget _row(ActivityFormatter formatter, DashboardActivity a) {
    final render = formatter.format(a);
    return ActivityFeedRow(
      render: render,
      meta: render.meta,
      density: ActivityRowDensity.card,
      onTap: activityDeepLinkTarget(a) == null ? null : () => onActivityTap(a),
    );
  }
}
