import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/domain/list_status_tabs.dart';
import 'package:admin/domain/sidebar_badge_modes.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/shell/widgets/sidebar_badge.dart';

/// What the list scaffold should do with the status strip this frame.
enum StatusStripAction {
  /// Render nothing.
  hide,

  /// Render the strip at [StatusStripDecision.selectedIndex].
  show,

  /// Render nothing **and** clear the active tab: its bucket exists but this
  /// company can't use it (Products filtered to Low stock, then inventory
  /// tracking switched off). Leaving it would show a list filtered to nothing
  /// with no visible control to undo it.
  healThenHide,
}

@immutable
class StatusStripDecision {
  const StatusStripDecision(this.action, {this.selectedIndex = -1});

  final StatusStripAction action;

  /// Index into the resolved tabs, `0` for `All`, or **-1** when the active
  /// filters match no tab — a status the user hand-picked in the search field,
  /// say. Deliberately not falling back to `All`: "All" means *no* status
  /// filter, and underlining it while one is applied would be a lie.
  final int selectedIndex;
}

/// Every condition that can suppress the status strip, in one pure function.
///
/// Extracted from the scaffold because it is unreachable from a test there —
/// pumping `EntityListScreenScaffold` needs the whole `Services` graph — and
/// the conditions interact in ways that are easy to get wrong. They have been:
/// gating the heal on "no tabs available" alone silently cleared a restored
/// filter on Products, because [availabilityKnown] is false on the first frame
/// (the company row is a Drift read and cannot arrive synchronously) and
/// "not known yet" is not "switched off".
///
/// [tabs] must already be inventory-filtered (`listStatusTabsFor`).
StatusStripDecision decideStatusStrip({
  required bool embedded,
  required bool settingEnabled,
  required String? activeModeId,
  required List<ResolvedStatusTab> tabs,
  required bool availabilityKnown,
}) {
  // An embedded list is scoped to a parent record while the counts are
  // company-wide, so "Draft 47" on one client's Invoices tab would be a lie.
  if (embedded) return const StatusStripDecision(StatusStripAction.hide);

  // An active tab always shows its strip, even with the setting off: a
  // `badge_mode` restored from nav_state or applied by a saved view is a live
  // filter, and hiding its only control would strand the user.
  if (!settingEnabled && activeModeId == null) {
    return const StatusStripDecision(StatusStripAction.hide);
  }

  if (tabs.isEmpty) {
    // Only heal once we actually KNOW the bucket is unavailable. While the
    // answer is still pending, an empty tab list means "ask again next frame",
    // not "this company can't use it".
    return (activeModeId != null && availabilityKnown)
        ? const StatusStripDecision(StatusStripAction.healThenHide)
        : const StatusStripDecision(StatusStripAction.hide);
  }

  return StatusStripDecision(
    StatusStripAction.show,
    selectedIndex: activeModeId == null
        ? 0
        : tabs.indexWhere((t) => t.listModeId == activeModeId),
  );
}

/// The one-tap status strip above an entity list (invoiceninja/flutter#98).
///
/// Each tab is one of the entity's sidebar-counter buckets, so the number here
/// and the number on the rail are the same query — and, because the list is
/// narrowed by the same `badgeModePredicate`, so are the rows underneath.
///
/// Purely presentational: selection comes in as an index derived from the
/// ViewModel's `activeBadgeModeId`, and taps go straight back out. It holds no
/// filter state of its own, so the strip and the search field's chips cannot
/// drift apart.
class EntityListStatusTabs extends StatefulWidget {
  const EntityListStatusTabs({
    required this.tabs,
    required this.selectedIndex,
    required this.showCounts,
    required this.streamKey,
    required this.countStream,
    required this.onTap,
    this.contentPadding = EdgeInsetsDirectional.zero,
    this.enabled = true,
    super.key,
  });

  /// `All` first, then the entity's buckets in lifecycle order — build it with
  /// `listStatusTabsFor`.
  final List<ResolvedStatusTab> tabs;

  /// Index into [tabs], or **-1** when the active filters match no tab (the
  /// user hand-picked a status in the search field, say). Deliberately not
  /// falling back to `All`: "All" means *no* status filter, and the user has
  /// one — underlining it would be a lie.
  final int selectedIndex;

  /// Whether to render the count badges. False while the list is showing
  /// archived / deleted rows, where the active-only counts would simply be
  /// wrong. Changes tab *width*, not strip *height*, so nothing jumps.
  final bool showCounts;

  /// Identity of the data the counts are drawn from (entity + company).
  /// A change here rebuilds the stream cache; [countStream] itself is expected
  /// to be a fresh closure on every build and is never compared.
  final String streamKey;

  /// Live count for one badge-mode id. Injected rather than reached for through
  /// `Services` so this widget is pumpable without the DI graph.
  final Stream<int> Function(String modeId) countStream;

  final void Function(ResolvedStatusTab tab) onTap;

  /// Inset for the tabs themselves. Applied inside the scroller so the strip's
  /// bottom rule stays full-bleed — insetting the whole widget would leave a
  /// divider that starts 24 px in and runs to the screen edge.
  final EdgeInsetsDirectional contentPadding;

  /// False while the list is in multi-select. The strip stays laid out (so the
  /// body doesn't jump on every enter/exit) but stops accepting taps — a tap
  /// would reload the list and silently clear the user's selection.
  final bool enabled;

  @override
  State<EntityListStatusTabs> createState() => _EntityListStatusTabsState();
}

class _EntityListStatusTabsState extends State<EntityListStatusTabs> {
  final _scroll = ScrollController();

  /// One stream per tab, built once per [EntityListStatusTabs.streamKey].
  ///
  /// Load-bearing: `watchEntityCount` returns a **fresh** stream per call, and
  /// this strip rebuilds with the list's ViewModel — i.e. on every Drift
  /// emission and every page load. Feeding a `StreamBuilder` inline would tear
  /// down and re-subscribe every count query on every notify. Same cache the
  /// Sidebar counters settings preview uses, for the same reason.
  final _streams = <String, Stream<int>>{};
  String? _cachedFor;

  /// One stable key per tab **position**, so the selected tab can be scrolled
  /// into view. A restored "Overdue" is the fourth tab and off-screen on a
  /// phone, so without the scroll the strip opens looking like nothing is
  /// selected.
  ///
  /// Keyed by index rather than by "the selected one": a single key that moved
  /// with the selection would re-parent that tab's subtree on every switch,
  /// tearing down and re-subscribing its count stream for nothing.
  final _tabKeys = <GlobalKey>[];
  bool _didRevealSelection = false;
  bool _didScheduleFirstFrame = false;

  @override
  void initState() {
    super.initState();
    _ensureKeys();
    _ensureStreams();
    _scheduleFirstFrame();
  }

  @override
  void didUpdateWidget(EntityListStatusTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ensureKeys();
    _ensureStreams();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _ensureKeys() {
    while (_tabKeys.length < widget.tabs.length) {
      _tabKeys.add(GlobalKey());
    }
  }

  void _ensureStreams() {
    if (_cachedFor == widget.streamKey) return;
    _cachedFor = widget.streamKey;
    _streams
      ..clear()
      ..addEntries(
        widget.tabs.map(
          (t) => MapEntry(t.countModeId, widget.countStream(t.countModeId)),
        ),
      );
  }

  /// Reveal the restored tab, then rebuild once so the edge fades can read a
  /// scroll position that only exists after the first layout.
  ///
  /// `attach` adds the controller's listener but does not itself notify, so
  /// without the rebuild a strip nobody scrolls never paints its trailing fade.
  /// The reveal keeps its own latch — it must fire once, for a restored
  /// selection — while the rebuild is unconditional (a strip whose selection is
  /// tab 0 still overflows and still needs the hint).
  void _scheduleFirstFrame() {
    if (_didScheduleFirstFrame) return;
    _didScheduleFirstFrame = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _revealSelection();
      setState(() {});
    });
  }

  void _revealSelection() {
    if (_didRevealSelection || widget.selectedIndex <= 0) return;
    _didRevealSelection = true;
    final index = widget.selectedIndex;
    if (index >= _tabKeys.length) return;
    final ctx = _tabKeys[index].currentContext;
    if (ctx == null) return;
    // `Scrollable.ensureVisible` walks every enclosing scrollable, which is
    // safe here only because `_bodyWithBanner` mounts this strip as a plain
    // `Column` sibling of the list — the walk finds nothing but our own
    // horizontal scroller. Don't move the strip inside a scroll view without
    // switching to `_scroll.position.ensureVisible`.
    Scrollable.ensureVisible(ctx, alignment: 0.5, duration: Duration.zero);
  }

  @override
  Widget build(BuildContext context) {
    _scheduleFirstFrame();
    final tokens = context.inTheme;
    // The strip can be hosted without a Scaffold (embedded / test pumps), so it
    // supplies the Material its InkWells need. Transparent = no visual change.
    return Material(
      type: MaterialType.transparency,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // A width change that leaves `pixels` alone — a rotation, a window
          // resize, the pane widening until the strip fits — reaches no
          // `ScrollController` listener: `applyContentDimensions` only schedules
          // a `ScrollMetricsNotification`. Without this the strip keeps whichever
          // fades the previous width called for.
          NotificationListener<ScrollMetricsNotification>(
            onNotification: (_) {
              if (mounted) setState(() {});
              return false;
            },
            child: Stack(
              children: [
                SingleChildScrollView(
                  controller: _scroll,
                  scrollDirection: Axis.horizontal,
                  padding: widget.contentPadding,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < widget.tabs.length; i++)
                        _StatusTabButton(
                          key: _tabKeys[i],
                          tab: widget.tabs[i],
                          active: i == widget.selectedIndex,
                          tokens: tokens,
                          countStream: widget.showCounts
                              ? _streams[widget.tabs[i].countModeId]
                              : null,
                          onTap: widget.enabled
                              ? () => widget.onTap(widget.tabs[i])
                              : null,
                        ),
                    ],
                  ),
                ),
                // Fades hinting that more tabs scroll off-screen, GATED on the
                // scroll position — the same shape `EntityDetailTabs` uses.
                // Unconditional, the trailing one veils the last tab's own count
                // badge as soon as the strip reaches its end: the scroller has no
                // trailing `contentPadding`, and the badge is the tab's last child
                // behind only `InSpacing.md` (8 px on a phone), so it sits inside
                // the 24 px gradient. Reachable by flicking the strip, and by a
                // `badge_mode` restored from `nav_state` naming the last tab —
                // `_revealSelection` clamps to `maxScrollExtent` and parks it
                // flush against that edge. The leading fade was missing outright,
                // so a scrolled strip gave no hint that "All" was off-screen.
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _scroll,
                      builder: (context, _) {
                        // `hasContentDimensions`, not just `hasClients`: the
                        // position attaches on the first build but its extents
                        // only exist after layout, and reading one early throws a
                        // null check straight out of
                        // `ScrollPosition.minScrollExtent`.
                        final p =
                            _scroll.hasClients &&
                                _scroll.position.hasContentDimensions
                            ? _scroll.position
                            : null;
                        final atStart =
                            p == null || p.pixels <= p.minScrollExtent;
                        final atEnd =
                            p == null || p.pixels >= p.maxScrollExtent;
                        return Stack(
                          children: [
                            if (!atStart) _edgeFade(tokens, leading: true),
                            if (!atEnd) _edgeFade(tokens, leading: false),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: tokens.border),
        ],
      ),
    );
  }

  /// A gradient hinting that more tabs lie beyond one edge.
  ///
  /// `PositionedDirectional` + `AlignmentDirectional` so it lands on the right
  /// physical edge in Arabic / Hebrew too — the reason this isn't shared with
  /// `EntityDetailTabs._edgeFade`, which is `Positioned` + `Alignment`.
  Widget _edgeFade(InTheme tokens, {required bool leading}) =>
      PositionedDirectional(
        top: 0,
        bottom: 0,
        start: leading ? 0 : null,
        end: leading ? null : 0,
        child: Container(
          width: 24,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: leading
                  ? AlignmentDirectional.centerEnd
                  : AlignmentDirectional.centerStart,
              end: leading
                  ? AlignmentDirectional.centerStart
                  : AlignmentDirectional.centerEnd,
              colors: [tokens.bg.withValues(alpha: 0), tokens.bg],
            ),
          ),
        ),
      );
}

class _StatusTabButton extends StatelessWidget {
  const _StatusTabButton({
    required this.tab,
    required this.active,
    required this.tokens,
    required this.countStream,
    required this.onTap,
    super.key,
  });

  final ResolvedStatusTab tab;
  final bool active;
  final InTheme tokens;

  /// Null hides the badge entirely (archived / deleted view).
  final Stream<int>? countStream;

  /// Null while the list is in multi-select — renders, doesn't respond.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Inactive uses `ink2`, matching the entity-detail tab strip: muted but
    // clearly readable against the active state.
    final color = active ? tokens.ink : tokens.ink2;
    final stream = countStream;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        // A floor, never a fixed height: clamping the line box slices Inter
        // Tight's descenders once the UI text scale passes ~1.14.
        constraints: BoxConstraints(
          minHeight: Env.isTouchPrimary ? InSizes.touchTarget : 0,
        ),
        child: Container(
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(
            horizontal: InSpacing.md(context),
            vertical: InSpacing.md(context),
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active ? tokens.accent : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.tr(tab.labelKey),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: color,
                ),
              ),
              if (stream != null) ...[
                const SizedBox(width: InSpacing.sm),
                StreamBuilder<int>(
                  stream: stream,
                  builder: (context, snap) {
                    final count = snap.data;
                    // Nothing until the first emission — a flash of "0" that
                    // then jumps reads as a bug, and the strip is meant to be
                    // glanced at.
                    if (count == null) return const SizedBox.shrink();
                    return SidebarBadge(
                      count: count,
                      active: active,
                      // Zero wears the neutral palette whatever the bucket's
                      // tone: a red "0" would claim urgency about the one
                      // outcome that means there's nothing to do. Unlike the
                      // rail, the badge still renders at zero — "Draft 0" is
                      // the answer to the question the tab asks.
                      tone: count == 0 ? SidebarBadgeTone.neutral : tab.tone,
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
