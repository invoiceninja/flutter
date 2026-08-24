import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_activity.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/core/widgets/error_view.dart';
import 'package:admin/ui/features/activity/activity_deep_link.dart';
import 'package:admin/ui/features/activity/widgets/activity_feed_row.dart';
import 'package:admin/ui/features/dashboard/helpers/activity_formatter.dart';
import 'package:admin/ui/features/dashboard/view_models/async_section.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';

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
    return DashboardCardShell(
      title: context.tr('activity'),
      trailing: onViewAll == null
          ? null
          : DashboardCardFooterLink(
              label: context.tr('view_all'),
              onTap: onViewAll,
            ),
      child: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    if (section.hasError && !section.hasData) {
      return _Constrained(
        child: ErrorView(
          message: context.tr('couldnt_load_tap_to_retry', {
            'section': context.tr('activity').toLowerCase(),
          }),
          onRetry: onRetry,
        ),
      );
    }
    final items = section.data;
    if (items == null) {
      return const ActivityFeedSkeleton();
    }
    if (items.isEmpty) {
      return _Constrained(
        child: EmptyState(
          icon: Icons.notifications_none_outlined,
          title: context.tr('no_activity_yet'),
        ),
      );
    }
    final formatter = ActivityFormatter(context);
    final tokens = context.inTheme;
    final visible = items.take(5).toList();
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

class _Constrained extends StatelessWidget {
  const _Constrained({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => SizedBox(height: 160, child: child);
}
