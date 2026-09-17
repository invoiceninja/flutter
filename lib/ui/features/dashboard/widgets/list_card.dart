import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/core/widgets/error_view.dart';
import 'package:admin/ui/features/dashboard/view_models/async_section.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/ui/features/dashboard/widgets/list_card_skeleton.dart';

/// Generic dashboard list card. Pass the title, the per-row models, the body
/// builder, and the empty-state copy. Handles loading/empty/error states and
/// the 5-row preview + "All X" footer link.
///
/// The body slot is **edge-flush** — the shell adds no padding around the
/// `bodyBuilder` result. This lets a `DashboardEntityTable` header strip
/// stretch the full width of the card. Skeleton / empty / error states inside
/// this widget add their own padding so they don't visually touch the border.
class DashboardListCard<T> extends StatelessWidget {
  const DashboardListCard({
    super.key,
    required this.title,
    required this.section,
    required this.bodyBuilder,
    required this.footerLabel,
    required this.emptyTitle,
    this.emptyIcon = Icons.inbox_outlined,
    this.emptySubtitle,
    this.emptyAction,
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

  final String footerLabel;
  final String emptyTitle;
  final IconData emptyIcon;
  final String? emptySubtitle;
  final Widget? emptyAction;
  final VoidCallback? onViewAll;
  final VoidCallback? onRetry;
  final int preview;

  // `_statePadding` was a `static const EdgeInsets` before the spacing
  // tokens went responsive. Compute it per-build now so the inset
  // tracks the viewport.
  EdgeInsets _statePadding(BuildContext context) => EdgeInsets.symmetric(
    horizontal: InSpacing.lg(context),
    vertical: InSpacing.md(context),
  );

  @override
  Widget build(BuildContext context) {
    return DashboardCardShell(
      title: title,
      trailing: section.listState == ListSectionState.rows
          ? DashboardCardFooterLink(label: footerLabel, onTap: onViewAll)
          : null,
      padding: EdgeInsets.zero,
      child: _body(context),
    );
  }

  // The state order is `ListSectionState`'s, shared with the mobile cards and
  // with the view model that hides a panel exactly when this would render its
  // empty state (invoiceninja/flutter#161).
  Widget _body(BuildContext context) {
    switch (section.listState) {
      case ListSectionState.failed:
        return Padding(
          padding: _statePadding(context),
          child: SizedBox(
            height: 200,
            child: ErrorView(
              message: context.tr('couldnt_load_tap_to_retry', {
                'section': title.toLowerCase(),
              }),
              onRetry: onRetry,
            ),
          ),
        );
      case ListSectionState.loading:
        return Padding(
          padding: _statePadding(context),
          child: const ListCardSkeleton(),
        );
      case ListSectionState.empty:
        return Padding(
          padding: _statePadding(context),
          child: SizedBox(
            height: 200,
            child: EmptyState(
              icon: emptyIcon,
              title: emptyTitle,
              subtitle: emptySubtitle,
              action: emptyAction,
            ),
          ),
        );
      case ListSectionState.rows:
        return bodyBuilder(context, section.data!.take(preview).toList());
    }
  }
}
