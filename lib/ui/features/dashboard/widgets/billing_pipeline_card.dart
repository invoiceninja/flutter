import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/domain/dashboard/billing_status_tabs.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/list_status_tabs.dart';
import 'package:admin/domain/sidebar_badge_modes.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/deep_link_filter_intent.dart';
import 'package:admin/ui/core/list/entity_list_status_tabs.dart';
import 'package:admin/ui/features/dashboard/view_models/billing_pipeline_view_model.dart';
import 'package:admin/ui/features/dashboard/widgets/billing_pipeline_table.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/ui/features/dashboard/widgets/list_card_skeleton.dart';
import 'package:admin/ui/features/dashboard/widgets/mobile/dashboard_mobile_rows.dart';
import 'package:admin/utils/formatting.dart';

/// Rows shown per layout. Three on a phone matches `_needsAttentionCard`, the
/// other card on this screen that narrows on mobile: the panel already sits
/// ~1150 px down, so two fewer rows is ~125 px less scrolling per tab.
const int kBillingPipelineNarrowRows = 3;
const int kBillingPipelineWideRows = 5;

/// Dashboard panel consolidating invoices and quotes behind one status strip
/// with live counts (invoiceninja/flutter#155).
///
/// Drift-backed, so — like the task calendar — several things here are
/// load-bearing and invisible at the call site.
///
/// **It must keep itself alive.** Both dashboard bodies are lazily-collected
/// `ListView`s, so a plain `StatefulWidget` is garbage-collected past the cache
/// extent, taking its view model, its Drift subscriptions, the selected tab and
/// the fetch latches with it.
///
/// **Nothing under it may be a `LayoutBuilder`** — the wide grid wraps each row
/// in `IntrinsicHeight`, which throws on an intrinsic query against one in
/// debug and silently answers 0 in release. That is why [narrow] is a
/// parameter: each host already knows which it is. (The strip's `Wrap` is fine
/// — `RenderWrap` answers intrinsics via `getDryLayout`.)
///
/// **It is gated on `view_invoice` / `view_quote`**, unlike the six
/// server-backed panels: those render data the API has already
/// permission-scoped, so an empty card honestly means "nothing to show", while
/// this one reads the local tables — a user without the permission has no rows
/// in Drift, so an ungated strip would paint seven zeroes as a positive claim.
/// See `enabledPanelKinds`.
class DashboardBillingPipelineCard extends StatefulWidget {
  const DashboardBillingPipelineCard({
    super.key,
    required this.companyId,
    required this.formatter,
    required this.refreshNonce,
    required this.narrow,
    required this.includeInvoices,
    required this.includeQuotes,
    required this.initialTabId,
    required this.onTabChanged,
  });

  final String companyId;
  final Formatter formatter;

  /// The dashboard's last completed refresh. `refreshAll` iterates the
  /// *cache-backed* kinds only, so without this the one gesture a user makes on
  /// a stale dashboard would refresh every panel except this one.
  final DateTime? refreshNonce;

  /// Stacked rows instead of the wide table. A parameter, never a
  /// `LayoutBuilder` — see the class doc.
  final bool narrow;

  /// Which halves participate. Passed down from the two hosts rather than
  /// re-derived here: `enabledPanelKinds` is the one place the module ×
  /// permission gate lives, and a fourth copy is exactly what it exists to
  /// prevent.
  final bool includeInvoices;
  final bool includeQuotes;

  /// The tab id restored from `nav_state`, or null for `All`. Persisted by the
  /// host (it owns the dashboard's per-company blob), healed here — a stored id
  /// this company can no longer use degrades to `All`.
  final String? initialTabId;

  /// Fired on a user tap only. Writing on hydrate would rewrite `nav_state` on
  /// every cold start.
  final ValueChanged<String?> onTabChanged;

  @override
  State<DashboardBillingPipelineCard> createState() =>
      _DashboardBillingPipelineCardState();
}

class _DashboardBillingPipelineCardState
    extends State<DashboardBillingPipelineCard>
    with AutomaticKeepAliveClientMixin {
  late Services _services;
  late BillingPipelineViewModel _vm;
  List<BillingStatusTab> _tabs = const [];

  /// True once the user has tapped a tab.
  ///
  /// Gates the late-restore below. [DashboardViewModel._hydrate] is an async
  /// Drift read that does not notify, so the restored tab usually arrives
  /// AFTER this card has mounted — and without the latch a slow `nav_state`
  /// read would yank the user off a tab they had already chosen.
  bool _userPicked = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _services = context.read<Services>();
    _vm = _buildVm();
  }

  int get _rowLimit =>
      widget.narrow ? kBillingPipelineNarrowRows : kBillingPipelineWideRows;

  BillingPipelineViewModel _buildVm() {
    final registry = _services.entityRegistry;
    _tabs = billingStatusTabsFor(
      invoiceModes:
          registry[EntityType.invoice]?.badgeModes ?? kDefaultBadgeModes,
      quoteModes: registry[EntityType.quote]?.badgeModes ?? kDefaultBadgeModes,
      includeInvoices: widget.includeInvoices,
      includeQuotes: widget.includeQuotes,
    );
    // A stored tab this company can no longer use — quotes module switched off,
    // `view_quote` revoked, a mode retired — degrades to `All`. Without the
    // heal the strip shows nothing selected and the view model subscribes to a
    // tab with no participating halves.
    final initial = billingStatusTabById(_tabs, widget.initialTabId);
    return BillingPipelineViewModel(
      invoices: _services.invoices,
      quotes: _services.quotes,
      companyId: widget.companyId,
      includeInvoices: widget.includeInvoices,
      includeQuotes: widget.includeQuotes,
      tabs: _tabs,
      rowLimit: _rowLimit,
      initialTab: initial,
    );
  }

  @override
  void didUpdateWidget(covariant DashboardBillingPipelineCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.companyId != widget.companyId ||
        oldWidget.formatter != widget.formatter ||
        oldWidget.includeInvoices != widget.includeInvoices ||
        oldWidget.includeQuotes != widget.includeQuotes ||
        oldWidget.narrow != widget.narrow) {
      // A company switch usually tears this subtree down, but not when the new
      // company's formatter is already cached — then only this runs.
      _vm.dispose();
      _vm = _buildVm();
    } else if (oldWidget.initialTabId == null &&
        widget.initialTabId != null &&
        !_userPicked) {
      // The restored tab arriving late, which is the ONLY ordering production
      // produces: the dashboard body mounts as soon as its formatter resolves
      // — a microtask on a warm navigation — while the `nav_state` read that
      // fills `billingTab` is still in flight and never notifies on its own.
      // Reading `initialTabId` in `initState` alone therefore drops it every
      // time, making the persisted tab write-only.
      final restored = billingStatusTabById(_tabs, widget.initialTabId);
      if (restored != null) _vm.selectTab(restored);
    } else if (oldWidget.refreshNonce != null &&
        oldWidget.refreshNonce != widget.refreshNonce) {
      // `null` → the first stamp is the dashboard's initial load completing,
      // not a refresh, and it carries no invoice/quote data. Re-arming on it
      // would make every cold start fetch twice.
      _vm.invalidateLoadedTabs();
      unawaited(_vm.ensureTabLoaded());
    }
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  // Both destinations are spelled once, here, rather than handed down from two
  // hosts as callbacks — the same choice `DashboardTaskCalendarCard` makes.
  void _openRecord(BillingPipelineRow row) =>
      goEntityRecord(context, row.type, row.id);

  /// Open a list on the same bucket the panel is showing.
  ///
  /// `badge_mode` is the list's own local-first filter key, and
  /// `GenericListViewModel._applyIntentState` already sanitizes an unknown one
  /// — it was written anticipating this producer.
  void _openList(EntityType type, String? modeId) {
    final path = type == EntityType.invoice ? '/invoices' : '/quotes';
    final narrowed = modeId != null && modeId != kBadgeModeTotal;
    context.go(
      path,
      extra: narrowed
          ? ListFilterIntent(
              extraFilters: {
                kBadgeModeFilterKey: {modeId},
              },
            )
          : ListFilterIntent(),
    );
  }

  void _onTapTab(BillingStatusTab tab) {
    _userPicked = true;
    _vm.selectTab(tab);
    // Only a user gesture persists — see [onTabChanged].
    widget.onTabChanged(tab.isAll ? null : tab.id);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin
    if (_tabs.isEmpty) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => _card(context),
    );
  }

  Widget _card(BuildContext context) {
    final tab = _vm.tab;
    final links = _footerLinks(context, tab);
    return DashboardCardShell(
      title: context.tr('invoices_and_quotes'),
      // Wide puts the links in the header; narrow cannot — the title sits in an
      // `Expanded` with the trailing widget unbounded, so the title is what
      // gives way, and "Invoices & Quotes" plus two links already fills an
      // English phone card.
      trailing: widget.narrow ? null : links,
      // Edge-flush, like `DashboardListCard`: the strip's bottom rule has to
      // reach both borders, and the default `InSpacing.lg` inset would also
      // make the table's width budget ~32 px optimistic.
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _strip(context),
          _body(context, tab),
          if (widget.narrow)
            Padding(
              padding: EdgeInsets.fromLTRB(
                InSpacing.lg(context),
                0,
                InSpacing.lg(context),
                InSpacing.md(context),
              ),
              child: links,
            ),
        ],
      ),
    );
  }

  Widget _strip(BuildContext context) {
    final selected = _vm.tab;
    final index = selected == null
        ? 0
        : _tabs.indexWhere((t) => t.id == selected.id);
    // The strip speaks `ResolvedStatusTab`; the panel speaks
    // `BillingStatusTab`. The adapter is keyed on `countModeId` — NOT
    // `listModeId`, which is null for `All` — and resolving back through it is
    // what keeps a merged tab's per-entity ids explicit.
    final byCountMode = <String, BillingStatusTab>{
      for (final t in _tabs) t.mode?.id ?? kBadgeModeTotal: t,
    };
    final resolved = [
      for (final t in _tabs)
        ResolvedStatusTab(t.mode, const <String, Set<String>>{}),
    ];
    return EntityListStatusTabs(
      tabs: resolved,
      selectedIndex: index,
      // Badges wait for the first fetch: a Drift watch emits within a frame, so
      // without this the panel's opening frame is seven confident zeroes.
      showCounts: _vm.firstLoadResolved,
      // Encodes which halves participate — the strip caches one stream per tab
      // on this key alone, so a module change must not reuse stale counts.
      streamKey:
          'billing:${widget.companyId}:'
          '${widget.includeInvoices}${widget.includeQuotes}',
      countStream: (modeId) => _countStream(byCountMode[modeId]),
      onTap: (t) {
        final match = byCountMode[t.countModeId];
        if (match != null) _onTapTab(match);
      },
      wrap: true,
      contentPadding: EdgeInsetsDirectional.fromSTEB(
        InSpacing.lg(context),
        InSpacing.md(context),
        InSpacing.lg(context),
        InSpacing.md(context),
      ),
    );
  }

  /// One tab's count, summed across the halves that participate.
  ///
  /// **Never forwards the tab's own id to both entities.** `watchBadgeCount`
  /// does `if (extra != null) q.where(extra)`, so a mode a DAO does not
  /// recognise skips the WHERE and counts *every active row* — the quote-only
  /// `approved` would silently add every invoice in the company.
  Stream<int> _countStream(BillingStatusTab? tab) {
    if (tab == null) return Stream<int>.value(0);
    final invoiceId = widget.includeInvoices ? tab.invoiceModeId : null;
    final quoteId = widget.includeQuotes ? tab.quoteModeId : null;
    Stream<int> watch(EntityType type, String modeId) =>
        _services.watchEntityCount(type, widget.companyId, modeId: modeId);

    if (invoiceId != null && quoteId != null) {
      // Deliberately not `combineLatest2`: it returns a single-subscription
      // stream, and the strip caches these and re-listens whenever `showCounts`
      // flips (the first-load gate, a company rebind, a refresh re-arm), which
      // would throw "Stream has already been listened to".
      return _sum(
        watch(EntityType.invoice, invoiceId),
        watch(EntityType.quote, quoteId),
      );
    }
    if (invoiceId != null) return watch(EntityType.invoice, invoiceId);
    if (quoteId != null) return watch(EntityType.quote, quoteId);
    return Stream<int>.value(0);
  }

  /// Re-listenable combine: emits as soon as either side has a value, treating
  /// the other as 0 until it arrives, so a slow half never stalls the badge.
  static Stream<int> _sum(Stream<int> a, Stream<int> b) =>
      Stream<int>.multi((controller) {
        int? left;
        int? right;
        void emit() {
          if (left == null && right == null) return;
          controller.add((left ?? 0) + (right ?? 0));
        }

        final subA = a.listen((v) {
          left = v;
          emit();
        }, onError: controller.addError);
        final subB = b.listen((v) {
          right = v;
          emit();
        }, onError: controller.addError);
        controller.onCancel = () async {
          await subA.cancel();
          await subB.cancel();
        };
      });

  Widget _body(BuildContext context, BillingStatusTab? tab) {
    final rows = _vm.rows;
    final showType = tab?.isMixed ?? false;
    // A floor, never a fixed height: a fixed one clamps the line box and slices
    // Inter Tight's descenders past ~1.14x text scale, and would clip a cell
    // that wrapped. Sized for a FULL tab so the card is stable in both
    // directions — in the wide grid a growing body resizes the card beside it
    // (`_MultiColumnGrid` stretches each row to its tallest cell), and on
    // mobile everything below it slides.
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: _rowLimit * _rowHeight),
      child: _bodyContent(context, rows, showType),
    );
  }

  /// Measured height of one rendered row per layout — the narrow shell is
  /// number+pill over the client name (~63), the wide table a single line of
  /// cells at 10 px vertical padding (~44).
  double get _rowHeight => widget.narrow ? 63 : 44;

  Widget _bodyContent(
    BuildContext context,
    List<BillingPipelineRow> rows,
    bool showType,
  ) {
    if (!_vm.firstLoadResolved && rows.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(InSpacing.lg(context)),
        child: ListCardSkeleton(rowCount: _rowLimit),
      );
    }
    if (rows.isEmpty) return _empty(context);
    if (widget.narrow) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final row in rows)
            MobileBillingPipelineRow(
              row: row,
              formatter: widget.formatter,
              showType: showType,
              onTap: () => _openRecord(row),
            ),
        ],
      );
    }
    return BillingPipelineTable(
      rows: rows,
      formatter: widget.formatter,
      showType: showType,
      onOpen: _openRecord,
    );
  }

  Widget _empty(BuildContext context) {
    final tokens = context.inTheme;
    final tab = _vm.tab;
    // `Rejected` is local-only until the server grows a `client_status=rejected`
    // branch (BACKEND.md § F1), so its empty state must not claim absence — the
    // caveat and the sentence both render, because "Rejected 0 over nothing" is
    // exactly the state the caveat exists for.
    final isLocalOnly = tab?.isLocalOnly ?? false;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: InSpacing.lg(context),
        vertical: InSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        // `_body` reserves `rowLimit * rowHeight` so the card cannot resize on
        // a tab switch, and `RenderFlex` honours that `minHeight` whatever the
        // `mainAxisSize` — so without this the message sits at the top of a
        // ~190 px box with the rest of the reserved space empty beneath it.
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            context.tr(isLocalOnly ? 'none_synced_yet' : 'no_records_found'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: tokens.ink3),
          ),
          if (isLocalOnly) ...[
            const SizedBox(height: 4),
            Text(
              context.tr('counted_from_local_data'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: tokens.ink3),
            ),
          ],
        ],
      ),
    );
  }

  Widget _footerLinks(BuildContext context, BillingStatusTab? tab) {
    final invoiceId = widget.includeInvoices ? tab?.invoiceModeId : null;
    final quoteId = widget.includeQuotes ? tab?.quoteModeId : null;
    return Wrap(
      alignment: WrapAlignment.end,
      // Real separation: two 12 px labels 8 px apart is a mis-tap that silently
      // opens the wrong list, with no undo.
      spacing: InSpacing.lg(context),
      runSpacing: InSpacing.sm,
      children: [
        // `touchFloor` because this card cannot wire
        // `DashboardCardShell.onHeaderTap` — that contract requires a single
        // destination and a merged tab has two — so the links carry the target
        // themselves.
        if (invoiceId != null)
          DashboardCardFooterLink(
            label: context.tr('invoices'),
            onTap: () => _openList(EntityType.invoice, invoiceId),
            touchFloor: true,
          ),
        if (quoteId != null)
          DashboardCardFooterLink(
            label: context.tr('quotes'),
            onTap: () => _openList(EntityType.quote, quoteId),
            touchFloor: true,
          ),
      ],
    );
  }
}
