import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/features/dashboard/view_models/dashboard_view_model.dart';
import 'package:admin/ui/features/dashboard/widgets/dashboard_create_fab.dart';
import 'package:admin/ui/features/dashboard/widgets/dashboard_create_strip.dart';
import 'package:admin/ui/features/dashboard/widgets/dashboard_refresh_button.dart';
import 'package:admin/ui/features/dashboard/widgets/freshness.dart';
import 'package:admin/ui/features/dashboard/widgets/manage_dashboard_cards_sheet.dart';

/// Wide-layout top bar, fixed above the dashboard scroll: the company and how
/// fresh the data is, the create buttons, then Refresh and Customize.
///
/// **The create buttons live here, not in the page**, so they are on screen
/// however far the dashboard is scrolled — see [DashboardCreateStrip]. They
/// take the room the date range, currency and include-drafts controls used to
/// hold; those now sit in the page, above the figures they govern
/// (`DashboardPeriodBar`), because up here they read as filters on the whole
/// dashboard and most of it ignores them.
///
/// The freshness stamp rides the subtitle rather than the action cluster: it
/// re-measures itself every 30 s, and a self-changing width among the actions
/// could shift them while the user is reaching for one.
///
/// Mobile uses a standard `AppBar` instead — see `DashboardScreen` for the
/// narrow path, which since flutter#51 is "narrow pane **or** phone".
class DashboardTopBar extends StatelessWidget {
  const DashboardTopBar({
    super.key,
    required this.vm,
    required this.companyName,
    required this.onRefresh,
    this.createOptions = const [],
    this.onCreate,
  });

  final DashboardViewModel vm;
  final String companyName;

  /// Re-pull every dashboard section. Routed through `DashboardScreen` rather
  /// than straight to `vm.refresh` so a failed pass can surface a toast.
  final VoidCallback onRefresh;

  /// What the user may create, already gated and ordered by
  /// `quickCreateEntities` — the same list the narrow layout's `+` sheet
  /// offers. Empty draws no create buttons at all.
  final List<QuickCreateOption> createOptions;
  final ValueChanged<EntityType>? onCreate;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    final onCreate = this.onCreate;

    return Container(
      // Floored to the shared header height (the constraint covers padding and
      // the bottom rule) so this lines up with the sidebar's company row across
      // the seam. A floor, not a fixed height — a long title or a large text
      // scale must still be able to grow it.
      constraints: const BoxConstraints(minHeight: InSizes.headerBand),
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
      // Three things want this row, and when it is tight they are served in
      // this order: Refresh and Customize (fixed — never pushed off), then the
      // company's name (up to [_kTitleMaxWidth]), then the create buttons,
      // which take what is left and fold what does not fit into their own More
      // menu. A plain flex row cannot say that — it would share the squeeze
      // between the name and the buttons in proportion — so the pair is laid
      // out first and the other two split the remainder by measurement.
      child: Row(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final gap = InSpacing.lg(context);
                final hasCreates = createOptions.isNotEmpty && onCreate != null;
                // The name gives up just enough for one `+` button: the wide
                // layout has no create FAB, so creating must survive any
                // squeeze.
                final reserved = hasCreates
                    ? gap + dashboardCreateMenuButtonExtent()
                    : 0.0;
                final room = constraints.maxWidth - reserved;
                return Row(
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: room.clamp(0.0, _kTitleMaxWidth),
                      ),
                      child: _title(context, tokens, theme),
                    ),
                    Expanded(
                      child: !hasCreates
                          ? const SizedBox.shrink()
                          : _CreateSlot(
                              gap: gap,
                              options: createOptions,
                              onCreate: onCreate,
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
          SizedBox(width: InSpacing.lg(context)),
          DashboardRefreshButton(
            isRefreshing: vm.isAnyRefreshing,
            onRefresh: onRefresh,
          ),
          const SizedBox(width: InSpacing.sm),
          DashboardCardsButton(vm: vm),
        ],
      ),
    );
  }

  Widget _title(BuildContext context, InTheme tokens, ThemeData theme) {
    return Column(
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
        FreshnessTicker(
          builder: (context) => Text(
            freshnessText(
              context,
              lastRefreshed: vm.lastRefreshed,
              isRefreshing: vm.isAnyRefreshing,
              cachedAt: vm.figuresFetchedAt,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: tokens.ink2),
          ),
        ),
      ],
    );
  }
}

/// The widest the company name and freshness stamp may grow.
const double _kTitleMaxWidth = 240;

/// Below this the create buttons' slot cannot be relied on to hold a labelled
/// button beside its More, and collapses to one `+` that opens them all.
const double _kCreateSlotMinWidth = 200;

/// The create buttons, right-aligned in whatever the title left.
class _CreateSlot extends StatelessWidget {
  const _CreateSlot({
    required this.gap,
    required this.options,
    required this.onCreate,
  });

  final double gap;
  final List<QuickCreateOption> options;
  final ValueChanged<EntityType> onCreate;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < _kCreateSlotMinWidth) {
          return Align(
            alignment: AlignmentDirectional.centerEnd,
            heightFactor: 1,
            child: DashboardCreateMenuButton(
              options: options,
              onCreate: onCreate,
            ),
          );
        }
        return Padding(
          padding: EdgeInsetsDirectional.only(start: gap),
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            // Fill the width (that is what right-aligns the strip), but
            // shrink-wrap the height: an `Align` with no factor expands to any
            // bounded extent it is handed.
            heightFactor: 1,
            child: DashboardCreateStrip(options: options, onCreate: onCreate),
          ),
        );
      },
    );
  }
}
