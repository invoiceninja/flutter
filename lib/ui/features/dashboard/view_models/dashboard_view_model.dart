import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import 'package:admin/app/resync_controller.dart';
import 'package:admin/data/db/dao/nav_state_dao.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_activity.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_calculated_field.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_card_config.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_chart_series.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_list_rows.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_panel_pref.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_totals.dart';
import 'package:admin/data/models/value/dashboard_filter.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/repositories/dashboard_repository.dart';
import 'package:admin/data/repositories/statics_repository.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/features/dashboard/view_models/async_section.dart';

final _log = Logger('DashboardViewModel');

/// Drives the Dashboard screen. Owns:
///   * The current [DashboardFilter] (range, currency, drafts, chart window).
///   * A per-section [AsyncSection] for totals (current + previous), chart,
///     activities, and each list card.
///   * Subscriptions to Drift watch streams; resubscribes filter-keyed ones
///     (totals + chart) when the filter changes.
///   * Refresh kickoff on construction / explicit `refresh()` / a completed
///     Sync pass for this company.
///   * Persistence of filter + legend toggles into `nav_state` using the
///     project's `{companyId: {<feature>: {...}}}` envelope.
class DashboardViewModel extends ChangeNotifier {
  DashboardViewModel({
    required this.repo,
    required this.companyId,
    required this.navStateDao,
    required this.statics,
    ValueListenable<ResyncCompletion?>? resyncCompletions,
    int firstMonthOfYear = 1,
    Duration persistDebounce = const Duration(milliseconds: 500),
    DateTime Function()? now,
    Date Function()? today,
  }) : _resyncCompletions = resyncCompletions,
       _fiscalYearStart = firstMonthOfYear,
       _persistDebounce = persistDebounce,
       _now = now ?? DateTime.now,
       _today = today ?? Date.today {
    _filter = _filter.copyWith(firstMonthOfYear: _fiscalYearStart);
    resyncCompletions?.addListener(_onResyncCompleted);
    unawaited(_init());
  }

  /// `Services.resync.lastCompletion` — see [_onResyncCompleted]. Optional so a
  /// test that isn't about Sync can leave it out.
  final ValueListenable<ResyncCompletion?>? _resyncCompletions;

  /// Company `first_month_of_year`, stamped onto every [DashboardFilter] so the
  /// `thisYear` / `lastYear` presets resolve onto the fiscal year. Not known
  /// synchronously at construction (it rides the async `Formatter`); the screen
  /// pushes it in via [setFiscalYearStart] once the formatter resolves.
  int _fiscalYearStart;

  final DashboardRepository repo;
  final String companyId;
  final NavStateDao navStateDao;
  final StaticsRepository statics;
  final Duration _persistDebounce;
  final DateTime Function() _now;

  /// The calendar day [filter]'s presets resolve against — see
  /// [_resubscribeIfRolledOver]. Injected so a test can cross midnight.
  final Date Function() _today;

  DashboardFilter _filter = DashboardFilter.defaults();
  DashboardFilter get filter => _filter;

  AsyncSection<DashboardTotals> totals = const AsyncSection.idle();
  AsyncSection<DashboardTotals> totalsPrevious = const AsyncSection.idle();
  AsyncSection<DashboardChartSeries> chart = const AsyncSection.idle();
  AsyncSection<List<DashboardActivity>> activities = const AsyncSection.idle();
  AsyncSection<List<DashboardInvoiceRow>> pastDue = const AsyncSection.idle();
  AsyncSection<List<DashboardInvoiceRow>> upcomingInvoices =
      const AsyncSection.idle();
  AsyncSection<List<DashboardPaymentRow>> recentPayments =
      const AsyncSection.idle();
  AsyncSection<List<DashboardQuoteRow>> expiredQuotes =
      const AsyncSection.idle();
  AsyncSection<List<DashboardQuoteRow>> upcomingQuotes =
      const AsyncSection.idle();
  AsyncSection<List<DashboardRecurringInvoiceRow>> upcomingRecurring =
      const AsyncSection.idle();

  /// Which chart series the legend has enabled. Default = all four, matching
  /// the React web client. Reassigned (never mutated in place) by
  /// [toggleChartSeries] and `_hydrate` — see [kDefaultChartSeries].
  Set<ChartSeriesId> visibleChartSeries = kDefaultChartSeries;

  /// Chart x-axis bucketing. Default = month, matching React's
  /// `dashboard_charts.default_view`. Persisted alongside [visibleChartSeries];
  /// changing it never refetches (the server response is grouping-agnostic).
  ChartGrouping chartGrouping = ChartGrouping.month;

  /// User-configured metric cards (React's `dashboard_fields`). Filter-keyed,
  /// persisted locally in the `dashboard` nav_state envelope. Order is the
  /// render order.
  List<DashboardCardConfig> dashboardCards = [];

  /// User ordering + visibility for the fixed dashboard panels. Defaults to the
  /// canonical order, all visible; `_hydrate` overlays the saved arrangement.
  /// Persisted in the same `dashboard` nav_state envelope as [dashboardCards].
  List<DashboardPanelPref> panelPrefs = _defaultPanelPrefs();

  static List<DashboardPanelPref> _defaultPanelPrefs() => [
    for (final k in DashboardKind.panelKinds)
      DashboardPanelPref(kind: k, visible: true),
  ];

  /// Per-card async state keyed by [DashboardCardConfig.key]. Each card
  /// listens to `listenableFor(DashboardKind.calc(key))`.
  final Map<String, AsyncSection<DashboardCalculatedField>> _cardSections = {};

  /// In-flight `dropCalculatedField` per card key. A re-add of the same card
  /// must wait for any pending drop to finish before it refetches, otherwise
  /// the (unawaited) drop's `deleteKind` can wipe the freshly fetched row.
  final Map<String, Future<void>> _pendingCardDrops = {};

  AsyncSection<DashboardCalculatedField> cardSection(String key) =>
      _cardSections[key] ?? const AsyncSection.idle();

  /// Wall-clock of the most recent successful refresh — drives the
  /// "Updated N ago" freshness label.
  DateTime? lastRefreshed;

  /// The `refreshNonce` of the two Drift-backed panels (the task calendar and
  /// Invoices & Quotes): a change from one non-null value to another makes
  /// them refetch their own server window. A first stamp is their initial
  /// load, never a re-arm.
  ///
  /// It moves with [lastRefreshed] on the boot refresh and on a refresh the
  /// user asked for. After a Sync pass it moves only when the pass failed to
  /// download what those panels read — otherwise the pass has just
  /// re-downloaded all of it, and re-arming would fetch those pages again, and
  /// blink the calendar's "nothing booked" caption, on every Sync.
  DateTime? panelRefreshNonce;
  bool isAnyRefreshing = false;
  Object? globalError;

  final _subs = <String, StreamSubscription<dynamic>>{};
  Timer? _persistTimer;
  bool _hydrated = false;

  /// One [Listenable] per [DashboardKind]. A section's stream emission (or
  /// an error/loading mutation) bumps *only* its own notifier, so a
  /// payments re-emission rebuilds only the payments card — not the whole
  /// dashboard. Cross-cutting chrome (filter, refresh state) still rides
  /// the global [notifyListeners]. Eagerly created so `listenableFor` is
  /// cheap and `Listenable.merge` targets are stable.
  final Map<String, _SectionNotifier> _sectionNotifiers = {
    for (final k in DashboardKind.allKinds) k: _SectionNotifier(),
  };

  /// Per-section listenable for the card/chart/KPI bound to [kind].
  Listenable listenableFor(String kind) =>
      _sectionNotifiers[kind] ?? (_sectionNotifiers[kind] = _SectionNotifier());

  /// The KPI row reads both totals sections, so it listens to both.
  late final Listenable kpiListenable = Listenable.merge([
    listenableFor(DashboardKind.totalsCurrent),
    listenableFor(DashboardKind.totalsPrevious),
  ]);

  /// The chart card's hero now reads the paid-revenue totals (current +
  /// previous) alongside the chart series, so it must rebuild on any of the
  /// three — not just the chart section.
  late final Listenable chartCardListenable = Listenable.merge([
    listenableFor(DashboardKind.chart),
    listenableFor(DashboardKind.totalsCurrent),
    listenableFor(DashboardKind.totalsPrevious),
  ]);

  void _bumpSection(String kind) {
    if (_disposed) return;
    _sectionNotifiers[kind]?.bump();
  }

  /// The panel kinds whose section has **loaded and holds no rows** — exactly
  /// the panels whose card would render its "No …" state
  /// (`ListSectionState.empty`, invoiceninja/flutter#161). Both dashboard
  /// bodies and the Customize sheet read it through `HiddenEmptyPanelsBuilder`
  /// to leave those panels out when the device hides empty panels.
  ///
  /// A separate notifier, not the global [notifyListeners]: a section emission
  /// deliberately bumps only its own card (see [listenableFor]), so the panel
  /// *lists* — built under the global notify — would never learn that a panel
  /// emptied. It publishes only when membership changes.
  ///
  /// Never contains a panel whose section is still `null` (loading, or a
  /// failed first fetch — the card shows a skeleton or an error, which is not
  /// "nothing to show"), nor a Drift-backed panel: only [_emptiableKinds]
  /// qualify.
  ValueListenable<Set<String>> get emptyPanels => _emptyPanels;
  final ValueNotifier<Set<String>> _emptyPanels = ValueNotifier(
    const <String>{},
  );

  /// The panels backed by a `dashboard_cache` section — derived from the
  /// registry, so a cache-backed panel added later qualifies without a second
  /// list to keep in step. The two Drift-backed panels (the task calendar and
  /// Invoices & Quotes) are never in [DashboardKind.listKinds]: they own their
  /// state and the fetch that fills it, and hiding one while the local cache
  /// reads empty would stop the only request that could prove otherwise.
  static final Set<String> _emptiableKinds = {
    for (final kind in DashboardKind.panelKinds)
      if (DashboardKind.listKinds.contains(kind)) kind,
  };

  /// Called with each emission of a section stream. Emptiness changes only
  /// here: `_setSectionError` keeps the section's data, so a failed refresh
  /// can neither hide a panel nor reveal one.
  void _syncPanelEmpty(String kind, Object? data) {
    if (_disposed || !_emptiableKinds.contains(kind)) return;
    final empty = data is List<Object?> && isLoadedEmpty(data);
    final current = _emptyPanels.value;
    if (current.contains(kind) == empty) return;
    _emptyPanels.value = Set.unmodifiable(
      empty ? {...current, kind} : ({...current}..remove(kind)),
    );
  }

  /// Currencies offered by the dropdown. Reads from `totals.byCurrency` when
  /// available; falls back to the full statics list during cold-start so the
  /// dropdown is never empty.
  Map<String, String> get availableCurrencies {
    final fromTotals = totals.data?.currencies;
    if (fromTotals != null && fromTotals.isNotEmpty) return fromTotals;
    return {
      for (final entry in statics.currencies.entries)
        entry.key: entry.value.name,
    };
  }

  // ─── Public actions ──────────────────────────────────────────────────

  /// Selected tab of the Invoices & Quotes panel, null for `All`.
  ///
  /// Per company, because which tabs exist depends on the company's modules and
  /// the user's permissions there. The panel heals a value it can no longer
  /// offer back to `All` rather than rendering nothing selected.
  String? get billingTab => _billingTab;
  String? _billingTab;

  /// Called on a user tap only — never on hydrate, or every cold start would
  /// rewrite `nav_state`.
  void setBillingTab(String? id) {
    if (_billingTab == id) return;
    _billingTab = id;
    _schedulePersist();
  }

  Future<void> setFilter(DashboardFilter next) async {
    if (next == _filter) return;
    final wasFilterKeyedChange =
        next.filterHash() != _filter.filterHash() ||
        next.includeDrafts != _filter.includeDrafts;
    _filter = next;
    notifyListeners();
    _schedulePersist();
    _resubscribeFilterKeyed();
    if (wasFilterKeyedChange) {
      await _refreshFilterKeyed();
    }
  }

  Future<void> setCurrency(int currencyId) =>
      setFilter(_filter.copyWith(currencyId: currencyId));

  Future<void> setIncludeDrafts(bool value) =>
      setFilter(_filter.copyWith(includeDrafts: value));

  Future<void> setDateRange(DashboardDateRange range) =>
      setFilter(_filter.copyWith(range: range));

  /// Push the company's `first_month_of_year` in once the async `Formatter`
  /// resolves (it isn't known at construction). Re-stamps the filter and, only
  /// when that actually changes the resolved range (i.e. the active preset is
  /// `thisYear` / `lastYear`), refetches the filter-keyed sections.
  Future<void> setFiscalYearStart(int firstMonthOfYear) async {
    if (firstMonthOfYear == _fiscalYearStart) return;
    _fiscalYearStart = firstMonthOfYear;
    final next = _filter.copyWith(firstMonthOfYear: firstMonthOfYear);
    final reranged = next.filterHash() != _filter.filterHash();
    _filter = next;
    notifyListeners();
    if (reranged) {
      _resubscribeFilterKeyed();
      await _refreshFilterKeyed();
    }
  }

  void toggleChartSeries(ChartSeriesId id) {
    final next = Set<ChartSeriesId>.from(visibleChartSeries);
    if (!next.remove(id)) next.add(id);
    if (next.isEmpty) return; // never leave the chart empty
    visibleChartSeries = next;
    notifyListeners();
    _schedulePersist();
  }

  void setChartGrouping(ChartGrouping next) {
    if (next == chartGrouping) return;
    chartGrouping = next;
    notifyListeners();
    _schedulePersist();
  }

  /// Add a configured card (no-op if an identical config already exists).
  /// Persists, subscribes, and live-fetches it immediately (instant-apply).
  void addCard(DashboardCardConfig config) {
    if (dashboardCards.any((c) => c.key == config.key)) return;
    dashboardCards = [...dashboardCards, config];
    _cardSections[config.key] = const AsyncSection.loading();
    notifyListeners();
    _schedulePersist();
    _subscribeCard(config);
    unawaited(_refreshCard(config));
  }

  void removeCard(String key) {
    final idx = dashboardCards.indexWhere((c) => c.key == key);
    if (idx < 0) return;
    final removed = dashboardCards[idx];
    dashboardCards = [...dashboardCards]..removeAt(idx);
    _subs[DashboardKind.calc(key)]?.cancel();
    _subs.remove(DashboardKind.calc(key));
    _sectionNotifiers.remove(DashboardKind.calc(key))?.dispose();
    _cardSections.remove(key);
    final drop = repo.dropCalculatedField(companyId, removed);
    _pendingCardDrops[key] = drop;
    unawaited(
      drop.whenComplete(() {
        if (identical(_pendingCardDrops[key], drop)) {
          _pendingCardDrops.remove(key);
        }
      }),
    );
    notifyListeners();
    _schedulePersist();
  }

  void reorderCards(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= dashboardCards.length) return;
    final next = [...dashboardCards];
    final moved = next.removeAt(oldIndex);
    next.insert(newIndex.clamp(0, next.length), moved);
    dashboardCards = next;
    notifyListeners();
    _schedulePersist();
  }

  // ─── List-panel ordering / visibility ─────────────────────────────────
  // Pure layout state (no streams). The dashboard body rebuilds on the global
  // notify; the manage dialog reorders/toggles via these.

  void reorderPanels(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= panelPrefs.length) return;
    final next = [...panelPrefs];
    final moved = next.removeAt(oldIndex);
    next.insert(newIndex.clamp(0, next.length), moved);
    panelPrefs = next;
    notifyListeners();
    _schedulePersist();
  }

  /// Reorder only the non-past-due panels, preserving past-due's slot. Used by
  /// the narrow manage layout, where past-due is pinned to the top (it always
  /// renders in the mobile hero zone) and the rest reorder beneath it.
  /// [oldIndex]/[newIndex] index the past-due-excluded subsequence.
  void reorderTrailingPanels(int oldIndex, int newIndex) {
    final rest = panelPrefs
        .where((p) => p.kind != DashboardKind.pastDue)
        .toList();
    if (oldIndex < 0 || oldIndex >= rest.length) return;
    final moved = rest.removeAt(oldIndex);
    rest.insert(newIndex.clamp(0, rest.length), moved);
    var ri = 0;
    panelPrefs = [
      for (final p in panelPrefs)
        p.kind == DashboardKind.pastDue ? p : rest[ri++],
    ];
    notifyListeners();
    _schedulePersist();
  }

  void togglePanelVisibility(String kind) {
    final idx = panelPrefs.indexWhere((p) => p.kind == kind);
    if (idx < 0) return;
    final next = [...panelPrefs];
    next[idx] = next[idx].copyWith(visible: !next[idx].visible);
    panelPrefs = next;
    notifyListeners();
    _schedulePersist();
  }

  void resetPanels() {
    if (panelsAreDefault) return;
    panelPrefs = _defaultPanelPrefs();
    notifyListeners();
    _schedulePersist();
  }

  /// True when [panelPrefs] equals the canonical default — order-sensitive
  /// (relies on `DashboardPanelPref ==`). Gates the manage dialog's reset.
  bool get panelsAreDefault => listEquals(panelPrefs, _defaultPanelPrefs());

  /// Per-card retry (compact in-card error affordance).
  Future<void> retryCard(String key) async {
    final idx = dashboardCards.indexWhere((c) => c.key == key);
    if (idx < 0) return;
    _resubscribeIfRolledOver();
    await _refreshCard(dashboardCards[idx]);
  }

  Future<void> _refreshCard(DashboardCardConfig config) async {
    try {
      // Serialize against a pending remove's cache purge so the drop can't
      // delete this fetch's freshly written row (P0 race).
      final pendingDrop = _pendingCardDrops[config.key];
      if (pendingDrop != null) await pendingDrop;
      await repo.refreshCalculatedField(companyId, _filter, config);
      _setCardError(config.key, null);
    } catch (e) {
      _setCardError(config.key, e);
    }
  }

  void _subscribeCard(DashboardCardConfig config) {
    // Ensure the section notifier exists before the first stream bump.
    listenableFor(DashboardKind.calc(config.key));
    _subscribe(
      DashboardKind.calc(config.key),
      repo.watchCalculatedField(companyId, _filter, config),
      (d) {
        final prev = _cardSections[config.key] ?? const AsyncSection.idle();
        _cardSections[config.key] = prev.withData(d);
      },
    );
  }

  void _setCardError(String key, Object? err) {
    final prev = _cardSections[key] ?? const AsyncSection.idle();
    _cardSections[key] = err == null
        ? prev.withData(prev.data)
        : AsyncSection.error(err, data: prev.data);
    _bumpSection(DashboardKind.calc(key));
  }

  /// Full refetch: every kind, parallel under the repo's concurrency cap.
  ///
  /// Returns true only when every section landed cleanly. `refreshAll` folds
  /// each job's exception into a map and never throws, so a partial failure is
  /// otherwise indistinguishable from success except that [lastRefreshed] goes
  /// unstamped — which reads as "the Refresh button did nothing". Callers that
  /// represent a *user-initiated* refresh use the result to surface a toast.
  Future<bool> refresh() =>
      _runRefresh(reportGlobalError: true, rearmPanels: true);

  /// A Sync pass for this company ran to its end: refetch everything, exactly
  /// as the Refresh button does (invoiceninja/flutter#162).
  ///
  /// The pass re-downloads the entity tables and — through its #160 tail — the
  /// list cards, but the totals, chart and configured cards are keyed by
  /// [filter], which only this view model knows. And the dashboard branch stays
  /// mounted for the whole session, so neither those sections nor the
  /// "Updated N ago" stamp moved: the reporter synced and was still told the
  /// data was two hours old. See `docs/sync.md` § A screen that refetches after
  /// a Sync pass listens to `lastCompletion`.
  ///
  /// A *full* refetch, list cards included, although the tail fetched those a
  /// moment ago — about seven repeat requests per Sync. What that buys is one
  /// code path, the Refresh button's, and a [lastRefreshed] whose "every
  /// section landed" promise holds without carrying the tail's per-card
  /// failures across the pass boundary.
  void _onResyncCompleted() {
    final done = _resyncCompletions?.value;
    if (_disposed || done == null) return;
    // A company switch rebuilds this view model before its hook cancels the
    // pass, so a pass for the company just left can still complete — and the
    // id check, not the cancellation, is what keeps it out.
    if (done.companyId != companyId) return;
    // Never true today (the controller withholds a failed prologue), but it
    // is the check that keeps a request off a logout if that rule loosens.
    if (done.result.error != null) return;
    final rearmPanels = done.result.failedEntities.any(_panelEntities.contains);
    if (!_bootRefreshDone) {
      // Deferred, not dropped — the notifier never replays it. The boot
      // refresh can have read the server before the pass pushed its edits (one
      // slow request holds it open for up to a minute), and running a second
      // refresh alongside it would drop the shared `isAnyRefreshing` early and
      // flash "Not yet loaded", which `_init` goes out of its way to avoid.
      _refetchAfterBoot = true;
      _refetchAfterBootRearms |= rearmPanels;
      return;
    }
    unawaited(_runRefresh(reportGlobalError: false, rearmPanels: rearmPanels));
  }

  /// The downloads the two Drift-backed panels read. A pass that failed one of
  /// them re-arms the panels — see [panelRefreshNonce].
  static final Set<String> _panelEntities = {
    EntityType.invoice.name,
    EntityType.quote.name,
    EntityType.task.name,
  };

  /// Set once the boot refresh in [_init] has returned — see
  /// [_onResyncCompleted].
  bool _bootRefreshDone = false;

  /// A completion arrived before [_bootRefreshDone]: [_init] refetches once
  /// more when the boot refresh returns, re-arming the panels if any of the
  /// deferred passes asked to.
  bool _refetchAfterBoot = false;
  bool _refetchAfterBootRearms = false;

  /// The body of every full refetch.
  ///
  /// [reportGlobalError] is false for the Sync-triggered one: [globalError]
  /// exists for `_refreshWithFeedback`'s toast, which reads it straight after
  /// its own [refresh] — an overlapping run that cleared or overwrote it would
  /// hand that toast another run's error. The after-sync run shows no toast;
  /// its failure shows as [lastRefreshed] staying put, plus the error state of
  /// the sections that render one (configured cards, and list cards with
  /// nothing cached — the KPI row and the chart render none).
  ///
  /// [rearmPanels] decides whether a clean run also moves
  /// [panelRefreshNonce].
  Future<bool> _runRefresh({
    required bool reportGlobalError,
    required bool rearmPanels,
  }) async {
    _resubscribeIfRolledOver();
    isAnyRefreshing = true;
    if (reportGlobalError) globalError = null;
    notifyListeners();
    var clean = false;
    try {
      final errors = await repo.refreshAll(
        companyId,
        _filter,
        cards: dashboardCards,
      );
      if (errors.isNotEmpty) {
        // Streams will emit the latest cached value (possibly null/stale);
        // mark the failing sections as error so the per-card retry surfaces.
        _foldPerSectionErrors(errors);
        // This — not the catch below — is the path a failed pass actually
        // takes. Leaving globalError null here made it look like a safety net
        // while being permanently unset.
        if (reportGlobalError) globalError = errors.values.first;
      } else {
        lastRefreshed = _now();
        if (rearmPanels) panelRefreshNonce = lastRefreshed;
        clean = true;
      }
    } catch (e, st) {
      _log.warning('Dashboard refresh failed', e, st);
      if (reportGlobalError) globalError = e;
    } finally {
      isAnyRefreshing = false;
      notifyListeners();
    }
    return clean;
  }

  /// Per-section retry (used by ErrorView's retry button).
  Future<void> retry(String kind) async {
    if (kind.startsWith('calc:')) {
      await retryCard(kind.substring(5));
      return;
    }
    // Not every panel kind is cache-backed — `DashboardKind.taskCalendar`
    // watches Drift and has no endpoint here. Falling through the switch would
    // clear that section's error and report success without fetching anything,
    // so refuse rather than lie.
    if (!DashboardKind.listKinds.contains(kind) &&
        kind != DashboardKind.totalsCurrent &&
        kind != DashboardKind.totalsPrevious &&
        kind != DashboardKind.chart) {
      return;
    }
    _resubscribeIfRolledOver();
    isAnyRefreshing = true;
    notifyListeners();
    try {
      switch (kind) {
        case DashboardKind.totalsCurrent:
        case DashboardKind.totalsPrevious:
          await repo.refreshTotals(companyId, _filter);
        case DashboardKind.chart:
          await repo.refreshChart(companyId, _filter);
        case DashboardKind.activities:
          await repo.refreshActivities(companyId);
        case DashboardKind.pastDue:
          await repo.refreshPastDue(companyId);
        case DashboardKind.upcomingInvoices:
          await repo.refreshUpcomingInvoices(companyId);
        case DashboardKind.recentPayments:
          await repo.refreshRecentPayments(companyId);
        case DashboardKind.expiredQuotes:
          await repo.refreshExpiredQuotes(companyId);
        case DashboardKind.upcomingQuotes:
          await repo.refreshUpcomingQuotes(companyId);
        case DashboardKind.upcomingRecurring:
          await repo.refreshUpcomingRecurring(companyId);
      }
      _setSectionError(kind, null);
    } catch (e) {
      _setSectionError(kind, e);
    } finally {
      isAnyRefreshing = false;
      notifyListeners();
    }
  }

  // ─── Init / streams ───────────────────────────────────────────────────

  Future<void> _init() async {
    // Raised before the Drift read, not inside refresh(): otherwise the frames
    // spent hydrating are `lastRefreshed == null && !isAnyRefreshing`, which
    // the freshness stamp renders as "Not yet loaded". Harmless at the bottom
    // of a scroll; a visible flash beside the company name in the top bar, at
    // boot and on every company switch (which builds a fresh VM).
    isAnyRefreshing = true;
    await _hydrate();
    _subscribeAll();
    await refresh();
    _bootRefreshDone = true;
    if (_refetchAfterBoot && !_disposed) {
      final rearmPanels = _refetchAfterBootRearms;
      _refetchAfterBoot = false;
      _refetchAfterBootRearms = false;
      await _runRefresh(reportGlobalError: false, rearmPanels: rearmPanels);
    }
  }

  void _subscribeAll() {
    _resubscribeFilterKeyed();
    _subscribe(
      DashboardKind.activities,
      repo.watchActivities(companyId),
      (d) => activities = activities.withData(d),
    );
    _subscribe(
      DashboardKind.pastDue,
      repo.watchPastDue(companyId),
      (d) => pastDue = pastDue.withData(d),
    );
    _subscribe(
      DashboardKind.upcomingInvoices,
      repo.watchUpcomingInvoices(companyId),
      (d) => upcomingInvoices = upcomingInvoices.withData(d),
    );
    _subscribe(
      DashboardKind.recentPayments,
      repo.watchRecentPayments(companyId),
      (d) => recentPayments = recentPayments.withData(d),
    );
    _subscribe(
      DashboardKind.expiredQuotes,
      repo.watchExpiredQuotes(companyId),
      (d) => expiredQuotes = expiredQuotes.withData(d),
    );
    _subscribe(
      DashboardKind.upcomingQuotes,
      repo.watchUpcomingQuotes(companyId),
      (d) => upcomingQuotes = upcomingQuotes.withData(d),
    );
    _subscribe(
      DashboardKind.upcomingRecurring,
      repo.watchUpcomingRecurring(companyId),
      (d) => upcomingRecurring = upcomingRecurring.withData(d),
    );
  }

  /// The [filter] hash the filter-keyed watches were opened with — see
  /// [_resubscribeIfRolledOver].
  String? _watchedFilterHash;

  /// Reopen the filter-keyed watches if [filter] no longer hashes the way it
  /// did when they were opened.
  ///
  /// A preset (this month, last 30 days, …) resolves against today, so its
  /// hash moves at midnight — and again at a month or year boundary — while
  /// nothing else re-subscribes. A dashboard left open overnight, which is the
  /// one a Sync has to refresh, wrote every refetch under the new hash and went
  /// on showing the old rows beneath a fresh "Updated just now".
  void _resubscribeIfRolledOver() {
    // Not yet subscribed: `_init` opens the watches after hydrating.
    if (_disposed || _watchedFilterHash == null) return;
    if (_filter.filterHash(today: _today()) == _watchedFilterHash) return;
    _resubscribeFilterKeyed();
  }

  void _resubscribeFilterKeyed() {
    _watchedFilterHash = _filter.filterHash(today: _today());
    _subscribe(
      DashboardKind.totalsCurrent,
      repo.watchTotals(companyId, _filter),
      (d) {
        totals = totals.withData(d);
      },
    );
    _subscribe(
      DashboardKind.totalsPrevious,
      repo.watchTotals(companyId, _filter, previousPeriod: true),
      (d) {
        totalsPrevious = totalsPrevious.withData(d);
      },
    );
    _subscribe(DashboardKind.chart, repo.watchChart(companyId, _filter), (d) {
      chart = chart.withData(d);
    });
    for (final card in dashboardCards) {
      _subscribeCard(card);
    }
  }

  void _subscribe<T>(String key, Stream<T> stream, void Function(T) onData) {
    _subs[key]?.cancel();
    _subs[key] = stream.listen(
      (value) {
        onData(value);
        _syncPanelEmpty(key, value);
        // Route to the section's listenable only — a data emission must
        // not rebuild the whole dashboard. `key` is the DashboardKind.
        _bumpSection(key);
      },
      onError: (Object e, StackTrace st) {
        _log.warning('Dashboard stream error [$key]', e, st);
      },
    );
  }

  Future<void> _refreshFilterKeyed() async {
    isAnyRefreshing = true;
    notifyListeners();
    try {
      final errors = await repo.refreshFilterKeyed(
        companyId,
        _filter,
        cards: dashboardCards,
      );
      if (errors.isNotEmpty) _foldPerSectionErrors(errors);
    } finally {
      isAnyRefreshing = false;
      notifyListeners();
    }
  }

  void _foldPerSectionErrors(Map<String, Object> errors) {
    errors.forEach(_setSectionError);
  }

  void _setSectionError(String kind, Object? err) {
    if (kind.startsWith('calc:')) {
      _setCardError(kind.substring(5), err);
      return;
    }
    switch (kind) {
      case DashboardKind.totalsCurrent:
        totals = err == null
            ? totals.withData(totals.data)
            : AsyncSection.error(err, data: totals.data);
      case DashboardKind.totalsPrevious:
        totalsPrevious = err == null
            ? totalsPrevious.withData(totalsPrevious.data)
            : AsyncSection.error(err, data: totalsPrevious.data);
      case DashboardKind.chart:
        chart = err == null
            ? chart.withData(chart.data)
            : AsyncSection.error(err, data: chart.data);
      case DashboardKind.activities:
        activities = err == null
            ? activities.withData(activities.data)
            : AsyncSection.error(err, data: activities.data);
      case DashboardKind.pastDue:
        pastDue = err == null
            ? pastDue.withData(pastDue.data)
            : AsyncSection.error(err, data: pastDue.data);
      case DashboardKind.upcomingInvoices:
        upcomingInvoices = err == null
            ? upcomingInvoices.withData(upcomingInvoices.data)
            : AsyncSection.error(err, data: upcomingInvoices.data);
      case DashboardKind.recentPayments:
        recentPayments = err == null
            ? recentPayments.withData(recentPayments.data)
            : AsyncSection.error(err, data: recentPayments.data);
      case DashboardKind.expiredQuotes:
        expiredQuotes = err == null
            ? expiredQuotes.withData(expiredQuotes.data)
            : AsyncSection.error(err, data: expiredQuotes.data);
      case DashboardKind.upcomingQuotes:
        upcomingQuotes = err == null
            ? upcomingQuotes.withData(upcomingQuotes.data)
            : AsyncSection.error(err, data: upcomingQuotes.data);
      case DashboardKind.upcomingRecurring:
        upcomingRecurring = err == null
            ? upcomingRecurring.withData(upcomingRecurring.data)
            : AsyncSection.error(err, data: upcomingRecurring.data);
    }
    // Surface the error/recovery on the affected card. Previously this
    // rode the enclosing refresh/retry global notify; now sections are
    // independently listenable so route it explicitly.
    _bumpSection(kind);
  }

  // ─── nav_state persistence ────────────────────────────────────────────

  Future<void> _hydrate() async {
    try {
      final row = await navStateDao.current();
      final raw = row?.filtersJson;
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final company = decoded[companyId];
      if (company is! Map) return;
      final dash = company['dashboard'];
      if (dash is! Map) return;

      final loadedFilter = DashboardFilter.tryFromJson(dash['filter']);
      // Re-stamp the fiscal year: it isn't persisted (it's a company setting),
      // so a restored filter must inherit the current value.
      if (loadedFilter != null) {
        _filter = loadedFilter.copyWith(firstMonthOfYear: _fiscalYearStart);
      }

      // `chartSeriesV` marks an envelope written by a build whose default is
      // all four series. Its absence means the blob predates that change, so a
      // stored set that is *exactly* the retired default ({invoices}) records
      // the old default, not a choice, and is upgraded. Any other stored set
      // could only have come from tapping the legend, so it is honored as-is.
      // Once the marker is present the stored set wins outright — including a
      // deliberate invoices-only, which must stay reachable. See #23.
      final seriesVersion = dash['chartSeriesV'];
      final seriesChosenPostUpgrade =
          seriesVersion is int && seriesVersion >= _kChartSeriesVersion;
      final series = dash['chartSeries'];
      if (series is List) {
        final next = <ChartSeriesId>{};
        for (final s in series) {
          for (final id in ChartSeriesId.values) {
            if (id.name == s) next.add(id);
          }
        }
        final isRetiredDefault =
            !seriesChosenPostUpgrade &&
            setEquals(next, _kRetiredDefaultChartSeries);
        if (next.isNotEmpty) {
          visibleChartSeries = isRetiredDefault ? kDefaultChartSeries : next;
        }
      }

      final grouping = dash['chartGrouping'];
      for (final g in ChartGrouping.values) {
        if (g.name == grouping) {
          chartGrouping = g;
          break;
        }
      }

      final cards = dash['dashboardCards'];
      if (cards is List) {
        final seen = <String>{};
        final loaded = <DashboardCardConfig>[];
        for (final c in cards) {
          final cfg = DashboardCardConfig.tryParse(c);
          if (cfg != null && seen.add(cfg.key)) loaded.add(cfg);
        }
        dashboardCards = loaded;
      }

      // The Invoices & Quotes panel's selected tab. Restored alongside the date
      // range, which is a far stronger filter living in this same blob — it
      // re-scopes the KPIs, the chart and every list card, where this narrows
      // one card whose own control sits 8 px above the rows it filters.
      final billingTab = dash['billingTab'];
      if (billingTab is String && billingTab.isNotEmpty) {
        _billingTab = billingTab;
      }

      // When `panels` is absent (every pre-upgrade install), panelPrefs keeps
      // its all-visible default — no else branch.
      final panels = dash['panels'];
      if (panels is List) {
        final seen = <String>{};
        final loaded = <DashboardPanelPref>[];
        for (final p in panels) {
          final pref = DashboardPanelPref.tryParse(p);
          // Keep only known panel kinds; dedupe by kind.
          if (pref != null &&
              DashboardKind.panelKinds.contains(pref.kind) &&
              seen.add(pref.kind)) {
            loaded.add(pref);
          }
        }
        // Place any panel missing from the saved list (e.g. one added in a
        // later release) visible-by-default, AT ITS CANONICAL RANK rather than
        // at the end.
        //
        // Appending was the old rule, and it made a new panel's declared slot
        // unreachable for anyone who had ever changed the date range — which
        // persists this blob — so it always landed last on every existing
        // install. The rule has to be stated precisely, because the obvious
        // version is wrong:
        //
        //  * walk `panelKinds` in ASCENDING canonical order, so several
        //    missing kinds keep their relative order rather than landing
        //    arbitrarily;
        //  * insert each immediately AFTER the last already-placed kind of
        //    smaller canonical index (position 0 if there is none). Anchoring
        //    on the predecessor is what keeps a new kind below `past_due` even
        //    in a save where the user dragged `past_due` down.
        //
        // Never `loaded.insert(canonicalIndex, …)`: on a reordered save that
        // shoves unrelated panels around, and it `RangeError`s whenever the
        // saved list is shorter than the index — which the `catch` below would
        // swallow, silently discarding the user's whole arrangement.
        final rank = {
          for (var i = 0; i < DashboardKind.panelKinds.length; i++)
            DashboardKind.panelKinds[i]: i,
        };
        for (final k in DashboardKind.panelKinds) {
          if (!seen.add(k)) continue;
          final mine = rank[k]!;
          var at = 0;
          for (var i = 0; i < loaded.length; i++) {
            final other = rank[loaded[i].kind];
            if (other != null && other < mine) at = i + 1;
          }
          loaded.insert(at, DashboardPanelPref(kind: k, visible: true));
        }
        panelPrefs = loaded;
      }
    } catch (e, st) {
      _log.warning('Failed to hydrate dashboard nav_state', e, st);
    } finally {
      _hydrated = true;
    }
  }

  void _schedulePersist() {
    if (!_hydrated) return;
    _persistTimer?.cancel();
    _persistTimer = Timer(_persistDebounce, _persist);
  }

  Future<void> _persist() async {
    try {
      final row = await navStateDao.current();
      final existing = row?.filtersJson;
      Map<String, dynamic> doc;
      if (existing == null || existing.isEmpty) {
        doc = <String, dynamic>{};
      } else {
        final decoded = jsonDecode(existing);
        doc = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
      }
      final companyDoc = doc[companyId];
      final companyMap = companyDoc is Map<String, dynamic>
          ? Map<String, dynamic>.from(companyDoc)
          : <String, dynamic>{};
      companyMap['dashboard'] = {
        'filter': _filter.toJson(),
        'chartSeries': visibleChartSeries.map((s) => s.name).toList(),
        // Seals the #23 migration for this company. Written on *every*
        // persist, not just from toggleChartSeries: `_schedulePersist` bails
        // while `!_hydrated`, so the stamped value is always post-migration,
        // and an unrelated write (date range, card add) finishes the upgrade
        // sooner.
        'chartSeriesV': _kChartSeriesVersion,
        'chartGrouping': chartGrouping.name,
        'dashboardCards': dashboardCards.map((c) => c.toJson()).toList(),
        'panels': panelPrefs.map((p) => p.toJson()).toList(),
        if (_billingTab != null) 'billingTab': _billingTab,
      };
      doc[companyId] = companyMap;
      await navStateDao.saveFilters(
        filtersJson: jsonEncode(doc),
        now: _now().millisecondsSinceEpoch,
      );
    } catch (e, st) {
      _log.warning('Failed to persist dashboard nav_state', e, st);
    }
  }

  /// Tracks `dispose()` so async refresh work that returns after the VM
  /// has been torn down skips its trailing `notifyListeners()` (which
  /// would throw `was used after being disposed` in debug). The dashboard
  /// fires several long-running fetches at construction time, so this
  /// race shows up routinely under tests.
  bool _disposed = false;

  bool get isDisposed => _disposed;

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    // First: `Services.resync` outlives every view model, and a company switch
    // disposes this one while the pass for its company may still be running.
    _resyncCompletions?.removeListener(_onResyncCompleted);
    _disposed = true;
    _persistTimer?.cancel();
    for (final sub in _subs.values) {
      sub.cancel();
    }
    for (final n in _sectionNotifiers.values) {
      n.dispose();
    }
    _emptyPanels.dispose();
    super.dispose();
  }
}

/// Public `ChangeNotifier` whose `bump()` exposes `notifyListeners` to the
/// VM. One per dashboard section so a single section's emission rebuilds
/// only the widget(s) bound to it.
class _SectionNotifier extends ChangeNotifier {
  void bump() => notifyListeners();
}

/// Series ids that the chart card can toggle via legend chips.
enum ChartSeriesId { invoices, payments, outstanding, expenses }

/// Legend default: all four series, matching the React web client, which
/// renders invoices/payments/outstanding/expenses unconditionally with no
/// toggle at all (`react/src/pages/dashboard/components/Chart.tsx`). See #23.
///
/// Kept a `const` literal rather than `ChartSeriesId.values.toSet()`: every VM
/// aliases this value until something reassigns, and a shared *growable* set
/// would let one stray in-place `add` / `remove` poison the default
/// process-wide. `const` turns that into an immediate `UnsupportedError`.
const Set<ChartSeriesId> kDefaultChartSeries = {
  ChartSeriesId.invoices,
  ChartSeriesId.payments,
  ChartSeriesId.outstanding,
  ChartSeriesId.expenses,
};

/// The retired default. A persisted envelope holding exactly this set *and* no
/// `chartSeriesV` marker was written by a build whose default was
/// invoices-only, so it records that default rather than a user's choice —
/// `_hydrate` upgrades it to [kDefaultChartSeries].
const Set<ChartSeriesId> _kRetiredDefaultChartSeries = {ChartSeriesId.invoices};

/// Version stamp written under `chartSeriesV`. Bump only when the *default*
/// set changes; its absence in a stored envelope means "written before the
/// all-four default shipped".
const int _kChartSeriesVersion = 2;

/// Chart x-axis bucketing granularity. Pure client-side re-bucketing of the
/// same `chart_summary_v2` response — never sent to the server. Mirrors
/// React's `preferences.dashboard_charts.default_view`.
enum ChartGrouping { day, week, month }
