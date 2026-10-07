import 'package:flutter/material.dart';

import 'package:admin/data/models/domain/dashboard/dashboard_panel_pref.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/link_text.dart';
import 'package:admin/ui/features/dashboard/helpers/panel_rows.dart';

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
/// **Which panels share a row is `layoutPanelRows`' decision**, not "fill two
/// columns in order": Invoices & Quotes always takes a whole row, the rest
/// pair up, and an odd one out gives a table the row rather than leaving half
/// of it empty. The pure function is unit-tested on every subset; this widget
/// only draws its answer.
///
/// The `builders` map stays with the screen — `dashboard_panel_wiring_test`
/// looks for each `DashboardKind.<kind>:` entry there.
/// Says to the card beneath it that it sits in a cell a neighbour can stretch —
/// one half of a paired row, whose height is the taller of the two.
///
/// A card in such a cell can be much taller than its content, and a short
/// state ("No upcoming quotes") then sat at the top of a hollow box. Knowing
/// it is stretched, the card centres that state instead
/// (`DashboardCardShell.bodyFills`). Only the widget that builds the row can
/// know: the same card in a full-width row, or in the phone's list, has an
/// unbounded height, where filling it would throw.
class DashboardPanelCell extends InheritedWidget {
  const DashboardPanelCell({
    super.key,
    required this.stretched,
    required super.child,
  });

  final bool stretched;

  /// Whether the nearest cell is a stretched one. False with none above.
  static bool stretchedOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<DashboardPanelCell>()
          ?.stretched ??
      false;

  @override
  bool updateShouldNotify(DashboardPanelCell oldWidget) =>
      oldWidget.stretched != stretched;
}

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
    final shown = [
      for (final p in widget.panelPrefs)
        if (p.visible && renderable(p) && !widget.hidden.contains(p.kind))
          p.kind,
    ];
    // Keyed by kind and built once per frame, then placed by the row layout:
    // a panel that changes row or width keeps its element.
    final cards = <String, Widget>{
      for (final kind in shown)
        kind: KeyedSubtree(
          key: _keys.putIfAbsent(
            kind,
            () => GlobalKey(debugLabel: 'dashboard panel $kind'),
          ),
          child: builders[kind]!(),
        ),
    };

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

    final rows = layoutPanelRows(shown, columns: widget.columns);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) SizedBox(height: widget.gap),
          _row(rows[i], cards),
        ],
      ],
    );
  }

  Widget _row(PanelRow row, Map<String, Widget> cards) {
    final first = cards[row.first]!;
    if (row.spans) return first;
    final second = row.second == null ? null : cards[row.second];
    // `IntrinsicHeight` + stretch: the two cards of a row end on one line
    // whatever each holds. It is why nothing under a panel may be a
    // `LayoutBuilder` (`docs/dashboard-panels.md`).
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: DashboardPanelCell(stretched: true, child: first)),
          SizedBox(width: widget.gap),
          // A lone half-width panel keeps its half: only the task calendar on
          // its own ends up here, and stretched across the row its 440 px
          // month grid would be an island.
          Expanded(
            child: second == null
                ? const SizedBox.shrink()
                : DashboardPanelCell(stretched: true, child: second),
          ),
        ],
      ),
    );
  }
}
