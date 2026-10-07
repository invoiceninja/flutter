import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_list_rows.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/dashboard/view_models/async_section.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/ui/features/dashboard/widgets/dashboard_panel_grid.dart';
import 'package:admin/ui/features/dashboard/widgets/list_card_skeleton.dart';

/// "View All (12)" — with the count only when the server has said how many
/// there are (`DashboardRows.total`).
///
/// A panel shows five rows of the fifty it fetched, and its link used to read
/// "All invoices" whether five more were waiting or five hundred. The total is
/// the paginator's, so it is exact; without one the link says nothing about
/// quantity rather than guess from the page in hand.
String viewAllLabel(BuildContext context, List<Object?> rows) {
  final label = context.tr('view_all');
  final total = rows.serverTotal;
  return total == null ? label : '$label ($total)';
}

/// Generic dashboard list card. Pass the title, the per-row models and the
/// body builder; it handles the loading, empty and failed states and the
/// header link.
///
/// The body slot is **edge-flush** — the shell adds no padding around the
/// `bodyBuilder` result. This lets a `DashboardEntityTable` header strip
/// stretch the full width of the card. The other states add their own padding.
///
/// **Empty and failed are one line each.** They used to be an `EmptyState`
/// with a 64 px icon and an `ErrorView` in a fixed 200 px box — a box the
/// error view did not even fit (it needs about 224 px, so it scrolled inside
/// its own card), and a quiet account paid 200 px a panel to be told "no
/// upcoming quotes". The phone's cards made the same change first, for the
/// same reason.
class DashboardListCard<T> extends StatelessWidget {
  const DashboardListCard({
    super.key,
    required this.title,
    required this.section,
    required this.bodyBuilder,
    required this.emptyTitle,
    this.emptySubtitle,
    this.onViewAll,
    this.onRetry,
    this.preview = 5,
  });

  final String title;
  final AsyncSection<List<T>> section;

  /// Builds the data body once the section is ready and non-empty. Receives
  /// the already-sliced preview list (length ≤ [preview]). Each card supplies
  /// a `DashboardEntityTable` for its row layout.
  final Widget Function(BuildContext, List<T>) bodyBuilder;

  final String emptyTitle;
  final String? emptySubtitle;
  final VoidCallback? onViewAll;
  final VoidCallback? onRetry;
  final int preview;

  @override
  Widget build(BuildContext context) {
    final state = section.listState;
    final hasRows = state == ListSectionState.rows;
    // Beside a taller neighbour this card is stretched to its height, and a
    // one-line state would sit at the top of a hollow box: centre it. Rows and
    // the skeleton stay where they are — a list starts at the top.
    final centred =
        DashboardPanelCell.stretchedOf(context) &&
        (state == ListSectionState.empty || state == ListSectionState.failed);
    return DashboardCardShell(
      title: title,
      trailing: hasRows && onViewAll != null
          ? DashboardCardFooterLink(
              label: viewAllLabel(context, section.data!),
              onTap: onViewAll,
            )
          : null,
      padding: EdgeInsets.zero,
      bodyFills: centred,
      child: centred ? Center(child: _body(context)) : _body(context),
    );
  }

  // The state order is `ListSectionState`'s, shared with the mobile cards and
  // with the view model that hides a panel exactly when this would render its
  // empty state (invoiceninja/flutter#161).
  Widget _body(BuildContext context) {
    switch (section.listState) {
      case ListSectionState.failed:
        return DashboardPanelError(onRetry: onRetry);
      case ListSectionState.loading:
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: InSpacing.lg(context),
            vertical: InSpacing.sm,
          ),
          child: const ListCardSkeleton(rowCount: 3),
        );
      case ListSectionState.empty:
        return DashboardPanelMessage(
          title: emptyTitle,
          subtitle: emptySubtitle,
        );
      case ListSectionState.rows:
        return bodyBuilder(context, section.data!.take(preview).toList());
    }
  }
}

/// A panel with nothing to show: one muted line (and an optional second), not
/// an icon and a paragraph in a 200 px box. An empty panel is the ordinary
/// state of a healthy account; it should cost a line.
class DashboardPanelMessage extends StatelessWidget {
  const DashboardPanelMessage({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.all(InSpacing.lg(context)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(color: tokens.ink2),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(color: tokens.ink2),
            ),
        ],
      ),
    );
  }
}

/// A panel whose fetch failed with nothing cached: says so on one line, with
/// the retry beside it. It used to be a full error view that scrolled inside
/// its own card.
class DashboardPanelError extends StatelessWidget {
  const DashboardPanelError({super.key, required this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: InSpacing.lg(context),
        end: InSpacing.sm,
        top: InSpacing.sm,
        bottom: InSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: tokens.overdue),
          const SizedBox(width: InSpacing.sm),
          Expanded(
            child: Text(
              context.tr('could_not_load_label'),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: tokens.ink2),
            ),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: Text(context.tr('retry'))),
        ],
      ),
    );
  }
}
