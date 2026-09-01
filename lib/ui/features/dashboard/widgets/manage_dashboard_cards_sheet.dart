import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_card_config.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_panel_pref.dart';
import 'package:admin/data/repositories/dashboard_repository.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';
import 'package:admin/ui/features/dashboard/view_models/dashboard_view_model.dart';
import 'package:admin/ui/features/dashboard/widgets/delta_chip.dart';
import 'package:admin/ui/features/dashboard/widgets/kpi_card.dart';

/// Which tab the manage-dashboard surface opens on.
enum ManagePane { cards, panels }

/// Top-bar / app-bar entry point that opens the manage-dashboard surface
/// (metric cards + list panels). Styled identically to `DashboardSettingsButton`
/// so the dashboard chrome reads as one family.
class DashboardCardsButton extends StatelessWidget {
  const DashboardCardsButton({
    super.key,
    required this.vm,
    required this.mobileLayout,
  });

  final DashboardViewModel vm;

  /// See [openManageDashboardCards]. Required rather than defaulted: this
  /// button is a wide-bar control today, but a default is exactly how the
  /// Panels tab came to disagree with the dashboard behind it.
  final bool mobileLayout;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return TextButton.icon(
      style: TextButton.styleFrom(
        foregroundColor: tokens.ink2,
        backgroundColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(InRadii.r2),
          side: BorderSide(color: tokens.border),
        ),
      ),
      icon: const Icon(Icons.dashboard_customize_outlined, size: 14),
      label: Text(
        context.tr('customize'),
        style: const TextStyle(fontSize: 13),
      ),
      onPressed: () =>
          openManageDashboardCards(context, vm: vm, mobileLayout: mobileLayout),
    );
  }
}

/// Wide (≥600) → centered dialog (~720, the settings max-width convention),
/// two columns (compose | current). Narrow → full-height scroll-controlled
/// bottom sheet, single column. Both host the same live editor; mutations
/// apply instantly (no Save gate).
///
/// [mobileLayout] says which dashboard body this surface is editing, and is
/// **not** the same question as the presentation above. The presentation
/// follows the *window*, which is the right input for "dialog or sheet"; the
/// Panels tab needs the *pane* (plus the phone test), because that is what
/// decides whether past-due is a reorderable panel or pinned to the mobile
/// hero zone. The two disagree for a 600–832 px desktop window (the rail
/// leaves the pane under 600) and, since flutter#51, for every phone in
/// landscape. Only the caller knows the answer, so it is passed rather than
/// re-derived here — and it is required, because the default it used to have
/// silently made past-due draggable in a layout that ignores the order.
Future<void> openManageDashboardCards(
  BuildContext context, {
  required DashboardViewModel vm,
  required bool mobileLayout,
  ManagePane initialTab = ManagePane.cards,
}) {
  final wide = MediaQuery.sizeOf(context).width >= 600;
  if (wide) {
    return showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 640),
          child: _ManageBody(
            vm: vm,
            twoColumn: true,
            initialTab: initialTab,
            mobileLayout: mobileLayout,
          ),
        ),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    // The field pickers are real text fields, and `showModalBottomSheet` lifts
    // nothing by itself. Padding first also makes the 0.92 fraction measure
    // against the keyboard-reduced box rather than the whole screen — otherwise
    // the sheet keeps its full height and simply hides behind the keyboard.
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: FractionallySizedBox(
        heightFactor: 0.92,
        child: _ManageBody(
          vm: vm,
          twoColumn: false,
          initialTab: initialTab,
          mobileLayout: mobileLayout,
        ),
      ),
    ),
  );
}

class _ManageBody extends StatefulWidget {
  const _ManageBody({
    required this.vm,
    required this.twoColumn,
    required this.initialTab,
    required this.mobileLayout,
  });
  final DashboardViewModel vm;

  /// Presentation only (dialog vs sheet) — see [mobileLayout] for why these
  /// are two separate flags.
  final bool twoColumn;
  final ManagePane initialTab;

  /// True when the dashboard behind this surface is `MobileDashboardBody`.
  final bool mobileLayout;

  @override
  State<_ManageBody> createState() => _ManageBodyState();
}

class _FieldOpt {
  const _FieldOpt(this.id, this.label);
  final String id;
  final String label;
}

class _ManageBodyState extends State<_ManageBody> {
  late ManagePane _pane = widget.initialTab;
  String? _field;
  CardPeriod _period = CardPeriod.current;
  CardCalc _calc = CardCalc.sum;
  CardFormat _format = CardFormat.money;

  /// Key of the just-added card — drives the scroll-to + brief highlight.
  String? _recentlyAddedKey;
  Timer? _flashTimer;
  final GlobalKey _newRowKey = GlobalKey();
  final ScrollController _listScroll = ScrollController();

  DashboardViewModel get vm => widget.vm;

  @override
  void dispose() {
    _flashTimer?.cancel();
    _listScroll.dispose();
    super.dispose();
  }

  DashboardCardConfig? get _prospective {
    final f = _field;
    if (f == null) return null;
    final fmt = isTaskField(f) ? _format : CardFormat.money;
    return DashboardCardConfig(
      field: f,
      period: _period,
      calculate: _calc,
      format: fmt,
    );
  }

  bool get _isDuplicate {
    final p = _prospective;
    return p != null && vm.dashboardCards.any((c) => c.key == p.key);
  }

  String _periodLabel(CardPeriod p) => switch (p) {
    CardPeriod.current => 'current',
    CardPeriod.previous => 'previous',
    CardPeriod.total => 'total',
  };

  String _calcLabel(CardCalc c) => switch (c) {
    CardCalc.sum => 'sum',
    CardCalc.avg => 'average',
    CardCalc.count => 'count',
  };

  void _onAdd() {
    final p = _prospective;
    if (p == null) return;
    vm.addCard(p);
    _recentlyAddedKey = p.key;
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() => _recentlyAddedKey = null);
    });
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _newRowKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 250),
          alignment: 0.5,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.all(InSpacing.lg(context)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(context),
            SizedBox(height: InSpacing.md(context)),
            if (_pane == ManagePane.cards)
              ..._cardsBody(context)
            else
              ..._panelsBody(context),
          ],
        ),
      ),
    );
  }

  // ── Cards tab (compose | current) ─────────────────────────────────────
  List<Widget> _cardsBody(BuildContext context) {
    final fieldOpts = [
      for (final f in kDashboardCardFields)
        _FieldOpt(f, context.tr(fieldLabelKey(f))),
    ]..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));

    if (widget.twoColumn) {
      return [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: _composePane(context, fieldOpts),
                ),
              ),
              SizedBox(width: InSpacing.lg(context)),
              Expanded(child: _currentPane(context)),
            ],
          ),
        ),
      ];
    }
    return [
      Flexible(
        child: SingleChildScrollView(child: _composePane(context, fieldOpts)),
      ),
      SizedBox(height: InSpacing.lg(context)),
      Flexible(child: _currentPane(context)),
    ];
  }

  // ── Panels tab (reorder + show/hide the six fixed list panels) ────────
  // One bounded-height pane (Expanded works under the bounded Dialog/sheet in
  // both layouts) + a reset-to-defaults footer.
  List<Widget> _panelsBody(BuildContext context) => [
    Expanded(
      child: _PanelsPane(vm: vm, mobileLayout: widget.mobileLayout),
    ),
    SizedBox(height: InSpacing.sm),
    ListenableBuilder(
      listenable: vm,
      builder: (context, _) => Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: vm.panelsAreDefault ? null : vm.resetPanels,
          icon: const Icon(Icons.restart_alt, size: 16),
          label: Text(context.tr('reset_to_defaults')),
        ),
      ),
    ),
  ];

  Widget _header(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: SegmentedButton<ManagePane>(
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              segments: [
                ButtonSegment(
                  value: ManagePane.cards,
                  label: Text(context.tr('cards')),
                ),
                ButtonSegment(
                  value: ManagePane.panels,
                  label: Text(context.tr('panels')),
                ),
              ],
              selected: {_pane},
              onSelectionChanged: (s) => setState(() => _pane = s.first),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close),
          iconSize: 20,
          tooltip: context.tr('close'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  // ── Compose pane ──────────────────────────────────────────────────────

  Widget _composePane(BuildContext context, List<_FieldOpt> fieldOpts) {
    final isTask = _field != null && isTaskField(_field!);
    _FieldOpt? selected;
    for (final o in fieldOpts) {
      if (o.id == _field) {
        selected = o;
        break;
      }
    }
    return _PaneCard(
      title: context.tr('add'),
      child: Padding(
        padding: EdgeInsets.all(InSpacing.lg(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            SearchableDropdownField<_FieldOpt>(
              label: context.tr('field'),
              items: fieldOpts,
              initialValue: selected,
              displayString: (o) => o.label,
              idOf: (o) => o.id,
              emptyHintKey: 'no_records_found',
              onChanged: (o) => setState(() {
                _field = o?.id;
                if (_field == null || !isTaskField(_field!)) {
                  _format = CardFormat.money;
                }
              }),
            ),
            SizedBox(height: InSpacing.md(context)),
            _LabeledControl(
              label: context.tr('period'),
              child: _seg<CardPeriod>(
                CardPeriod.values,
                _period,
                (v) => setState(() => _period = v),
                (v) => context.tr(_periodLabel(v)),
              ),
            ),
            SizedBox(height: InSpacing.md(context)),
            _LabeledControl(
              label: context.tr('calculate'),
              child: _seg<CardCalc>(
                CardCalc.values,
                _calc,
                (v) => setState(() => _calc = v),
                (v) => context.tr(_calcLabel(v)),
              ),
            ),
            if (isTask) ...[
              SizedBox(height: InSpacing.md(context)),
              _LabeledControl(
                label: context.tr('format'),
                child: _seg<CardFormat>(
                  CardFormat.values,
                  _format,
                  (v) => setState(() => _format = v),
                  (v) => context.tr(v.name),
                ),
              ),
            ],
            SizedBox(height: InSpacing.lg(context)),
            _LabeledControl(
              label: context.tr('preview'),
              child: SizedBox(height: 140, child: _preview(context)),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 150),
              alignment: Alignment.topCenter,
              child: _isDuplicate
                  ? Padding(
                      padding: EdgeInsets.only(top: InSpacing.md(context)),
                      child: _duplicateWarning(context),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            SizedBox(height: InSpacing.lg(context)),
            PrimaryDialogAction(
              label: context.tr('add'),
              enabled: _field != null && !_isDuplicate,
              onPressed: _onAdd,
              // Disabled until a card is chosen (autofocus can't land) — no hint.
              autofocus: false,
              showEnterHint: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _preview(BuildContext context) {
    if (_field == null) {
      final tokens = context.inTheme;
      return DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.surfaceAlt,
          borderRadius: BorderRadius.circular(InRadii.r3),
          border: Border.all(color: tokens.border),
        ),
        child: Center(
          child: Text(
            context.tr('field'),
            style: TextStyle(color: tokens.ink3, fontSize: 12),
          ),
        ),
      );
    }
    return KpiCard(
      label: context.tr(fieldLabelKey(_field!)),
      value: '—',
      deltaPercent: null,
      goodDirection: GoodDirection.up,
      showDelta: false,
      subcaption:
          '${context.tr(_periodLabel(_period))} · '
          '${context.tr(_calcLabel(_calc))}',
    );
  }

  Widget _duplicateWarning(BuildContext context) {
    final tokens = context.inTheme;
    return Row(
      children: [
        Icon(Icons.warning_amber_rounded, size: 16, color: tokens.overdue),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            context.tr('card_already_exists'),
            style: TextStyle(fontSize: 12, color: tokens.ink3),
          ),
        ),
      ],
    );
  }

  // ── Current pane ──────────────────────────────────────────────────────

  Widget _currentPane(BuildContext context) {
    final tokens = context.inTheme;
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        final cards = vm.dashboardCards;
        return _PaneCard(
          title: context.tr('cards'),
          fill: true,
          trailing: cards.isEmpty
              ? null
              : Text(
                  '${cards.length}',
                  style: TextStyle(fontSize: 12, color: tokens.ink3),
                ),
          child: cards.isEmpty
              ? EmptyState(
                  icon: Icons.dashboard_customize_outlined,
                  title: context.tr('no_records_found'),
                  subtitle: context.tr('add_dashboard_cards'),
                )
              : ReorderableListView.builder(
                  scrollController: _listScroll,
                  padding: EdgeInsets.symmetric(
                    horizontal: InSpacing.lg(context),
                    vertical: InSpacing.md(context),
                  ),
                  buildDefaultDragHandles: false,
                  itemCount: cards.length,
                  onReorderItem: vm.reorderCards,
                  itemBuilder: (context, i) {
                    final c = cards[i];
                    final highlighted = c.key == _recentlyAddedKey;
                    return _CardRow(
                      key: ValueKey(c.key),
                      rowKey: highlighted ? _newRowKey : null,
                      highlighted: highlighted,
                      index: i,
                      title: context.tr(fieldLabelKey(c.field)),
                      subtitle:
                          '${context.tr(_periodLabel(c.period))} · '
                          '${context.tr(_calcLabel(c.calculate))}',
                      onRemove: () => vm.removeCard(c.key),
                    );
                  },
                ),
        );
      },
    );
  }

  // ── Shared bits ───────────────────────────────────────────────────────

  Widget _seg<T>(
    List<T> values,
    T selected,
    ValueChanged<T> onChange,
    String Function(T) labelOf,
  ) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SegmentedButton<T>(
        showSelectedIcon: false,
        style: SegmentedButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
        segments: [
          for (final v in values)
            ButtonSegment<T>(
              value: v,
              label: Text(labelOf(v), style: const TextStyle(fontSize: 12)),
            ),
        ],
        selected: {selected},
        onSelectionChanged: (s) => onChange(s.first),
      ),
    );
  }
}

/// FormSection-style chrome (surface + 1px border + r3, header + divider)
/// whose body fills the remaining height — lets the current-cards list get
/// a bounded height for its own scroll/reorder.
class _PaneCard extends StatelessWidget {
  const _PaneCard({
    required this.title,
    required this.child,
    this.trailing,
    this.fill = false,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  /// When true the body fills remaining height (`Flexible`) so an inner
  /// scrollable/list gets bounded constraints — used by the current-cards
  /// pane. The compose pane sizes to content and is scrolled by an outer
  /// `SingleChildScrollView`, so it must stay `fill: false`.
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.inTheme;
    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(InRadii.r3),
        border: Border.all(color: tokens.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: InSpacing.lg(context),
              vertical: InSpacing.md(context),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: tokens.ink,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          Divider(height: 1, color: tokens.border),
          if (fill) Flexible(child: child) else child,
        ],
      ),
    );
  }
}

class _LabeledControl extends StatelessWidget {
  const _LabeledControl({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: tokens.ink3)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _CardRow extends StatelessWidget {
  const _CardRow({
    super.key,
    required this.index,
    required this.title,
    required this.subtitle,
    required this.onRemove,
    this.rowKey,
    this.highlighted = false,
  });

  final int index;
  final String title;
  final String subtitle;
  final VoidCallback onRemove;
  final Key? rowKey;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return AnimatedContainer(
      key: rowKey,
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: highlighted ? tokens.accentSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(InRadii.r1),
      ),
      padding: EdgeInsets.symmetric(
        vertical: InSpacing.xs,
        horizontal: InSpacing.xs,
      ),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Icon(Icons.drag_indicator, color: tokens.ink3, size: 20),
          ),
          SizedBox(width: InSpacing.md(context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodyMedium),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: tokens.ink3),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            iconSize: 18,
            tooltip: context.tr('remove'),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

/// Panels-tab body: a single reorderable list of the six fixed dashboard list
/// panels with a per-row show/hide [Switch]. Mirrors `_currentPane` (a
/// `_PaneCard(fill: true)` wrapping a `ReorderableListView`) so both tabs read
/// as one family. All six are shown so the reorder index stays 1:1 with
/// `vm.panelPrefs`; module-disabled panels are kept (their saved state survives)
/// but flagged so toggling them isn't a silent dead control.
class _PanelsPane extends StatefulWidget {
  const _PanelsPane({required this.vm, required this.mobileLayout});
  final DashboardViewModel vm;

  /// True when the dashboard behind this pane is `MobileDashboardBody`, which
  /// pins past-due to its hero zone and drops it from the ordered trailing
  /// panels — so the row is presented as pinned, and the remaining five
  /// reorder through `reorderTrailingPanels`.
  final bool mobileLayout;

  @override
  State<_PanelsPane> createState() => _PanelsPaneState();
}

class _PanelsPaneState extends State<_PanelsPane> {
  // Its own controller — never share the cards pane's `_listScroll`.
  final ScrollController _scroll = ScrollController();

  DashboardViewModel get vm => widget.vm;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Services lives above MaterialApp (main.dart) so a root-navigator dialog
    // can read it; only the dashboard's own VM provider sits below the
    // navigator, which is why `vm` is passed in explicitly.
    final company = context.read<Services>().auth.session.value?.currentCompany;
    bool moduleOn(EntityType t) => company?.moduleEnabled(t) ?? false;
    final enabledKinds = <String>{
      if (moduleOn(EntityType.invoice)) DashboardKind.pastDue,
      if (moduleOn(EntityType.invoice)) DashboardKind.upcomingInvoices,
      if (moduleOn(EntityType.payment)) DashboardKind.recentPayments,
      if (moduleOn(EntityType.quote)) DashboardKind.upcomingQuotes,
      if (moduleOn(EntityType.quote)) DashboardKind.expiredQuotes,
      if (moduleOn(EntityType.recurringInvoice))
        DashboardKind.upcomingRecurring,
    };
    return _PaneCard(
      title: context.tr('panels'),
      fill: true,
      child: ListenableBuilder(
        listenable: vm,
        builder: (context, _) {
          final prefs = vm.panelPrefs;

          _PanelRow rowFor(
            DashboardPanelPref p,
            int index, {
            required bool pinned,
          }) => _PanelRow(
            key: ValueKey(p.kind),
            index: index,
            title: context.tr(panelTitleKey(p.kind)),
            visible: p.visible,
            moduleEnabled: enabledKinds.contains(p.kind),
            pinned: pinned,
            onToggle: () => vm.togglePanelVisibility(p.kind),
          );

          final listPadding = EdgeInsets.symmetric(
            horizontal: InSpacing.lg(context),
            vertical: InSpacing.md(context),
          );

          // Wide: a single list, 1:1 with panelPrefs.
          //
          // Which arm this takes is passed in, never measured here. The mobile
          // body pins past-due to the hero zone and ignores its order slot, and
          // this surface floats on the root navigator where the only thing it
          // can measure is the *window* — which reads "wide" both for a
          // 600–832 px desktop window and for every phone in landscape, in each
          // of which the dashboard is rendering the mobile body. Measuring it
          // here made the past-due drag handle a dead control there.
          if (!widget.mobileLayout) {
            return ReorderableListView.builder(
              scrollController: _scroll,
              padding: listPadding,
              buildDefaultDragHandles: false,
              itemCount: prefs.length,
              onReorderItem: vm.reorderPanels,
              itemBuilder: (context, i) => rowFor(prefs[i], i, pinned: false),
            );
          }

          // Narrow: past-due is pinned at the top (it always renders in the
          // mobile hero zone; its order slot is ignored), and the remaining
          // five reorder beneath it — mirroring the mobile dashboard exactly.
          final pastDue = prefs.firstWhere(
            (p) => p.kind == DashboardKind.pastDue,
          );
          final rest = prefs
              .where((p) => p.kind != DashboardKind.pastDue)
              .toList();
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.only(
                  left: InSpacing.lg(context),
                  right: InSpacing.lg(context),
                  top: InSpacing.md(context),
                ),
                child: rowFor(pastDue, 0, pinned: true),
              ),
              Expanded(
                child: ReorderableListView.builder(
                  scrollController: _scroll,
                  padding: listPadding,
                  buildDefaultDragHandles: false,
                  itemCount: rest.length,
                  onReorderItem: vm.reorderTrailingPanels,
                  itemBuilder: (context, i) =>
                      rowFor(rest[i], i, pinned: false),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PanelRow extends StatelessWidget {
  const _PanelRow({
    super.key,
    required this.index,
    required this.title,
    required this.visible,
    required this.moduleEnabled,
    required this.pinned,
    required this.onToggle,
  });

  final int index;
  final String title;
  final bool visible;
  final bool moduleEnabled;
  final bool pinned;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    // Two distinct muted states (never conflated):
    //  • module-disabled → inert (ink3) + a "module disabled" reason hint.
    //  • user-hidden      → the off Switch carries it; only a light title
    //                       de-emphasis (ink2) so it never reads as disabled.
    final Color titleColor = !moduleEnabled
        ? tokens.ink3
        : (visible ? tokens.ink : tokens.ink2);

    final Widget handle = pinned
        ? Tooltip(
            message: context.tr('shown_first'),
            child: Icon(Icons.push_pin_outlined, color: tokens.ink3, size: 18),
          )
        : ReorderableDragStartListener(
            index: index,
            child: Tooltip(
              message: context.tr('drag_to_reorder'),
              child: Icon(Icons.drag_indicator, color: tokens.ink3, size: 20),
            ),
          );

    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: InSpacing.xs,
        horizontal: InSpacing.xs,
      ),
      child: Row(
        children: [
          handle,
          SizedBox(width: InSpacing.md(context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: titleColor),
                ),
                if (!moduleEnabled)
                  Text(
                    context.tr('module_disabled'),
                    style: TextStyle(fontSize: 11, color: tokens.ink3),
                  ),
              ],
            ),
          ),
          Tooltip(
            message: context.tr(visible ? 'hide' : 'show'),
            // Inert when the backing module is off — the panel can't render
            // regardless, so Material greys the switch to match the dimmed row.
            // The saved `visible` flag is untouched and returns when re-enabled.
            child: Switch.adaptive(
              value: visible,
              onChanged: moduleEnabled ? (_) => onToggle() : null,
            ),
          ),
        ],
      ),
    );
  }
}
