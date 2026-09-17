import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/quick_create.dart';
import 'package:admin/l10n/localization.dart';

/// One entry in the dashboard's create sheet: an entity the user may start,
/// and the icon its sidebar row wears. `DashboardScreen` resolves these
/// against the registry, so nothing in this file needs `Services`.
@immutable
class QuickCreateOption {
  const QuickCreateOption({required this.type, required this.icon});

  final EntityType type;
  final IconData icon;
}

/// How much of the body's bottom edge [DashboardCreateFab] covers: a 56 px
/// button plus Material's 16 px margin. The Scaffold measures both from the
/// bottom safe inset, which the dashboard body's `SafeArea` has already
/// removed. So a list padded by this much more can scroll its last card clear
/// of the button.
const double kDashboardFabClearance = 56 + kFloatingActionButtonMargin;

/// The narrow dashboard's `+` (invoiceninja/flutter#164). It is the same
/// bottom-right button every list screen carries, but it opens
/// [showQuickCreateSheet], a choice of what to create, instead of a single
/// create screen.
///
/// It replaces two things. One is the New Invoice icon in the app bar, which a
/// phone user had to reach across the screen for and which could only start an
/// invoice. The other is the body's New Client / Enter Expense tiles, which
/// scrolled away with the page. Each of those is an entry in the sheet now.
///
/// The screen leaves the button off when [options] would be empty, so a user
/// who may create nothing never opens an empty sheet.
class DashboardCreateFab extends StatelessWidget {
  const DashboardCreateFab({
    super.key,
    required this.options,
    required this.onCreate,
  });

  final List<QuickCreateOption> options;

  /// Called with the picked entity after the sheet has closed, never while it
  /// is still on screen, so the navigation it starts has no modal route in its
  /// way.
  final ValueChanged<EntityType> onCreate;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      // No `Hero` at all. This button never flies into another route's FAB,
      // and Flutter's default `heroTag` is one shared constant: the shell
      // keeps every branch mounted, so the default would put this tag and a
      // list screen's identical one in the same route's subtree, which is the
      // duplicate `Hero` tags assert waiting to happen.
      heroTag: null,
      tooltip: context.tr('create_new'),
      onPressed: () async {
        final picked = await showQuickCreateSheet(context, options: options);
        if (picked == null || !context.mounted) return;
        onCreate(picked);
      },
      child: const Icon(Icons.add),
    );
  }
}

/// Shows the create sheet. Resolves to the picked entity, or null if the sheet
/// was dismissed.
///
/// A bottom sheet rather than a menu anchored to the button:
///
/// * The app's touch choosers are already sheets (`showPhoneCandidatePicker`,
///   and the narrow theme and company pickers).
/// * A sheet keeps every entry within reach of the thumb. A fourteen-entry
///   `MenuAnchor` rising from the corner would put its first entries at the top
///   of the screen.
/// * That menu would also line up with the screen edge, not the button: a root
///   menu that overflows to the right is pinned to the safe area, not to its
///   anchor.
///
/// It opens on the ROOT navigator because the shell paints the running-timer
/// pill above the branch navigator. A sheet mounted there would have the pill
/// floating over its bottom rows.
Future<EntityType?> showQuickCreateSheet(
  BuildContext context, {
  required List<QuickCreateOption> options,
}) {
  return showModalBottomSheet<EntityType>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => QuickCreateSheet(
      options: options,
      onSelected: (type) => Navigator.of(sheetContext).pop(type),
    ),
  );
}

/// The sheet's body: a "Create New" heading over a grid of tiles, one per
/// option, in the order given.
///
/// Public so a widget test can pump it without driving the modal route.
class QuickCreateSheet extends StatelessWidget {
  const QuickCreateSheet({
    super.key,
    required this.options,
    required this.onSelected,
  });

  final List<QuickCreateOption> options;
  final ValueChanged<EntityType> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final gutter = InSpacing.lg(context);
    return SafeArea(
      top: false,
      child: Padding(
        // No top padding: the drag handle above already spaces the heading.
        padding: EdgeInsets.fromLTRB(gutter, 0, gutter, gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                context.tr('create_new'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: tokens.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(height: InSpacing.md(context)),
            // Flexible + scroll: a landscape phone, or a large text size, can
            // make the grid taller than the sheet is allowed to be.
            Flexible(
              child: SingleChildScrollView(
                child: QuickCreateGrid(
                  tiles: [
                    for (final option in options)
                      _QuickCreateTile(
                        icon: option.icon,
                        label: context.tr(quickCreateLabelKey(option.type)),
                        onTap: () => onSelected(option.type),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Gap between grid cells, on both axes.
const double kQuickCreateTileGap = InSpacing.sm;

/// The narrowest a tile may be at text scale 1.0. This value sets the column
/// count at every width the sheet actually has, per [quickCreateColumns]:
///
/// | sheet content                 | 1.0    | 1.3    | 2.0    |
/// |-------------------------------|--------|--------|--------|
/// | 320 phone, 296                | 2 cols | 2 cols | 2 cols |
/// | 360 phone, 336                | 3 cols | 2 cols | 2 cols |
/// | 412 phone, 388                | 3 cols | 2 cols | 2 cols |
/// | landscape, 608 (sheet capped) | 5 cols | 4 cols | 3 cols |
///
/// Three columns on an ordinary phone is the point. At 107 px a tile holds
/// "New Recurring" on one line, so the longest English labels wrap once
/// instead of ellipsizing. Four columns would leave 78 px, where they cannot
/// wrap cleanly. `dashboard_create_fab_test.dart` pins the table.
const double kQuickCreateMinTileWidth = 96;

/// How many columns [QuickCreateGrid] lays out in [width] logical pixels.
///
/// [textScale] is the user's text-size multiplier. Clamped to 2..6: one column
/// would just be a list with borders, and past six the sheet (which Material
/// caps at 640 wide) has no width left to spread.
int quickCreateColumns({required double width, required double textScale}) {
  final minTile = kQuickCreateMinTileWidth * textScale;
  if (minTile <= 0 || width <= 0) return 2;
  final fits = (width + kQuickCreateTileGap) ~/ (minTile + kQuickCreateTileGap);
  return fits.clamp(2, 6);
}

/// [tiles] laid out in equal-width columns, with every tile in a run as tall
/// as the tallest one.
///
/// This is the layout `SidebarNavGrid` uses, with a column count tuned for a
/// sheet instead of a sidebar. It is deliberately not a `Wrap` or a fixed-
/// extent `GridView`. `Wrap` leaves a ragged bottom edge when a one-line label
/// sits beside a two-line one. A fixed extent clips a label once the user
/// raises the text size.
class QuickCreateGrid extends StatelessWidget {
  const QuickCreateGrid({super.key, required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) return const SizedBox.shrink();
    final scaler = MediaQuery.textScalerOf(context);
    final textScale =
        scaler.scale(kQuickCreateMinTileWidth) / kQuickCreateMinTileWidth;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = quickCreateColumns(
          width: constraints.maxWidth,
          textScale: textScale,
        );
        final runs = <Widget>[];
        for (var start = 0; start < tiles.length; start += columns) {
          final end = math.min(start + columns, tiles.length);
          final cells = <Widget>[
            for (var i = start; i < end; i++) ...[
              if (i > start) const SizedBox(width: kQuickCreateTileGap),
              Expanded(child: tiles[i]),
            ],
            // Pad a short final run with empty columns, so its tiles keep the
            // width of the run above instead of stretching.
            for (var i = end - start; i < columns; i++) ...[
              const SizedBox(width: kQuickCreateTileGap),
              const Expanded(child: SizedBox.shrink()),
            ],
          ];
          if (runs.isNotEmpty) {
            runs.add(const SizedBox(height: kQuickCreateTileGap));
          }
          runs.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: cells,
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: runs,
        );
      },
    );
  }
}

/// An icon above a label, in the tile style the sidebar's grid layout uses.
/// It is larger here because this is a touch surface with a single job.
class _QuickCreateTile extends StatelessWidget {
  const _QuickCreateTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final radius = BorderRadius.circular(InRadii.r2);
    // The fill is on the Material and the border is on a transparent
    // Container inside the InkWell, so the ripple paints over the fill and
    // stays visible. This is the idiom `no_ink_widget_test.dart` enforces.
    return Material(
      color: tokens.surface,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          // A floor, not a fixed height: the label must be able to grow with
          // the text scale.
          constraints: const BoxConstraints(minHeight: InSizes.touchTarget),
          decoration: BoxDecoration(
            border: Border.all(color: tokens.border),
            borderRadius: radius,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: InSpacing.xs,
            vertical: InSpacing.md(context),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: tokens.ink2),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                  color: tokens.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
