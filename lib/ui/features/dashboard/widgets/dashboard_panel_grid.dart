import 'package:flutter/material.dart';

import 'package:admin/data/models/domain/dashboard/dashboard_panel_pref.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/link_text.dart';

/// The wide dashboard's bottom grid: the orderable panels, in the user's
/// saved order, laid out one or two to a row.
///
/// Extracted from `DashboardScreen._bottomGrid` for two reasons, both about
/// what happens when the set of rendered panels changes — which, since
/// invoiceninja/flutter#161, it does whenever a panel empties out, not just
/// when the user hides or reorders one:
///
/// * **Every panel is keyed with a `GlobalKey` owned by this `State`.** The
///   grid is rows of `IntrinsicHeight(Row([Expanded, …]))` with no keys of
///   their own, and a key only takes part in matching among siblings — so the
///   `ValueKey` this used to carry, sitting under `Expanded`, never matched
///   anything. Any panel that changed row or column was torn down and
///   rebuilt, which for the two Drift-backed panels means their view model is
///   disposed, their fetch reruns and the task calendar forgets its month. A
///   `GlobalKey` follows the card into its new row: the framework retakes the
///   element within the same frame (every row rebuilds together), and
///   `AutomaticKeepAlive` explicitly handles a client that moved under it. The
///   keys are per-`State`, never static, so a second dashboard can't collide.
/// * **It can be tested.** The screen's body never builds in a widget test
///   (its `formatterFor` never completes), so this is where the key rule gets
///   pinned.
///
/// The `builders` map stays with the screen — `dashboard_panel_wiring_test`
/// looks for each `DashboardKind.<kind>:` entry there.
class DashboardPanelGrid extends StatefulWidget {
  const DashboardPanelGrid({
    super.key,
    required this.panelPrefs,
    required this.builders,
    required this.hidden,
    required this.columns,
    required this.gap,
    required this.onShowPanels,
  });

  /// The user's saved order and visibility.
  final List<DashboardPanelPref> panelPrefs;

  /// One builder per panel this company can render — a kind with no entry is
  /// module- or permission-gated off (`enabledPanelKinds`).
  final Map<String, Widget Function()> builders;

  /// Panels left out because they have nothing to show — see
  /// `HiddenEmptyPanelsBuilder`.
  final Set<String> hidden;

  final int columns;
  final double gap;

  /// Opens the Customize sheet on its Panels tab.
  final VoidCallback onShowPanels;

  @override
  State<DashboardPanelGrid> createState() => _DashboardPanelGridState();
}

class _DashboardPanelGridState extends State<DashboardPanelGrid> {
  final Map<String, GlobalKey> _keys = {};

  @override
  Widget build(BuildContext context) {
    final builders = widget.builders;
    bool renderable(DashboardPanelPref p) => builders.containsKey(p.kind);
    final cards = <Widget>[
      for (final p in widget.panelPrefs)
        if (p.visible && renderable(p) && !widget.hidden.contains(p.kind))
          KeyedSubtree(
            key: _keys.putIfAbsent(
              p.kind,
              () => GlobalKey(debugLabel: 'dashboard panel ${p.kind}'),
            ),
            child: builders[p.kind]!(),
          ),
    ];

    if (cards.isEmpty) {
      // Offer a way back only to panels the *user* switched off that would
      // show something once switched on. Nothing enabled → nothing to surface;
      // everything merely empty right now → "Show panels" would be a lie, since
      // they are shown — and a switched-off panel that is empty too would stay
      // invisible after the user followed the link. Either way collapse
      // silently — the chart / activity / KPI rows above still anchor the
      // screen.
      final userHidden = widget.panelPrefs.any(
        (p) => !p.visible && renderable(p) && !widget.hidden.contains(p.kind),
      );
      if (!userHidden) return const SizedBox.shrink();
      return Align(
        alignment: Alignment.centerLeft,
        child: LinkText(
          label: context.tr('show_panels'),
          onTap: widget.onShowPanels,
          style: const TextStyle(fontSize: 12.5),
        ),
      );
    }

    return _MultiColumnGrid(
      columns: widget.columns,
      gap: widget.gap,
      children: cards,
    );
  }
}

/// Simple column-balanced grid that places `children` left-to-right, top-to-
/// bottom into [columns] columns with `gap` between cells and rows. We use
/// this instead of `GridView` so each row can size itself to its tallest
/// card (cards have variable internal height).
class _MultiColumnGrid extends StatelessWidget {
  const _MultiColumnGrid({
    required this.columns,
    required this.gap,
    required this.children,
  });

  final int columns;
  final double gap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += columns) {
      final rowChildren = <Widget>[];
      for (var j = 0; j < columns; j++) {
        final idx = i + j;
        if (j > 0) rowChildren.add(SizedBox(width: gap));
        rowChildren.add(
          Expanded(
            child: idx < children.length
                ? children[idx]
                : const SizedBox.shrink(),
          ),
        );
      }
      if (rows.isNotEmpty) rows.add(SizedBox(height: gap));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: rowChildren,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}
