import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import 'package:admin/data/db/dao/nav_state_dao.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_activity.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_calculated_field.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_card_config.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_chart_series.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_list_rows.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_panel_pref.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_totals.dart';
import 'package:admin/data/models/value/dashboard_filter.dart';
import 'package:admin/data/repositories/dashboard_repository.dart';
import 'package:admin/data/repositories/statics_repository.dart';
import 'package:admin/ui/features/dashboard/view_models/async_section.dart';

final _log = Logger('DashboardViewModel');

/// Drives the Dashboard screen. Owns:
///   * The current [DashboardFilter] (range, currency, drafts, chart window).
///   * A per-section [AsyncSection] for totals (current + previous), chart,
///     activities, and each list card.
///   * Subscriptions to Drift watch streams; resubscribes filter-keyed ones
///     (totals + chart) when the filter changes.
///   * Refresh kickoff on construction / explicit `refresh()`.
///   * Persistence of filter + legend toggles into `nav_state` using the
///     project's `{companyId: {<feature>: {...}}}` envelope.
class DashboardViewModel extends ChangeNotifier {
  DashboardViewModel({
    required this.repo,
    required this.companyId,
    required this.navStateDao,
    required this.statics,
    int firstMonthOfYear = 1,
    Duration persistDebounce = const Duration(milliseconds: 500),
    DateTime Function()? now,
  }) : _fiscalYearStart = firstMonthOfYear,
       _persistDebounce = persistDebounce,
       _now = now ?? DateTime.now {
    _filter = _filter.copyWith(firstMonthOfYear: _fiscalYearStart);
    unawaited(_init());
  }

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

  /// User ordering + visibility for the six fixed list panels. Defaults to the
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
  /// renders in the mobile hero zone) and the remaining five reorder beneath it.
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
  Future<bool> refresh() async {
    isAnyRefreshing = true;
    globalError = null;
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
        globalError = errors.values.first;
      } else {
        lastRefreshed = _now();
        clean = true;
      }
    } catch (e, st) {
      _log.warning('Dashboard refresh failed', e, st);
      globalError = e;
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

  void _resubscribeFilterKeyed() {
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
        // Append any panel missing from the saved list (e.g. a panel added in a
        // later release) visible-by-default, so the set is always complete and
        // in a stable order.
        for (final k in DashboardKind.panelKinds) {
          if (seen.add(k)) {
            loaded.add(DashboardPanelPref(kind: k, visible: true));
          }
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
    _disposed = true;
    _persistTimer?.cancel();
    for (final sub in _subs.values) {
      sub.cancel();
    }
    for (final n in _sectionNotifiers.values) {
      n.dispose();
    }
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
