import 'dart:async';
import 'dart:convert';

import 'package:logging/logging.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/dashboard_cache_dao.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_activity.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_calculated_field.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_card_config.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_chart_series.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_list_rows.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_totals.dart';
import 'package:admin/data/models/value/dashboard_filter.dart';
import 'package:admin/data/repositories/base_entity_repository.dart'
    show CompanySwitchedException;
import 'package:admin/data/services/dashboard_api.dart';

final _log = Logger('DashboardRepository');

/// Cache kinds — `kind` column values in the `dashboard_cache` table.
class DashboardKind {
  DashboardKind._();

  static const String totalsCurrent = 'totals_current';
  static const String totalsPrevious = 'totals_previous';
  static const String chart = 'chart';
  static const String activities = 'activities';
  static const String pastDue = 'past_due';
  static const String upcomingInvoices = 'upcoming_invoices';
  static const String recentPayments = 'recent_payments';
  static const String expiredQuotes = 'expired_quotes';
  static const String upcomingQuotes = 'upcoming_quotes';
  static const String upcomingRecurring = 'upcoming_recurring';

  /// The task-availability month grid. Unlike every *server-fed* kind above it,
  /// this panel is **Drift-backed** — it watches the local tasks table rather than a
  /// `dashboard_cache` row — so it deliberately appears in [panelKinds] only,
  /// never in [listKinds] (which [DashboardRepository.refreshAll] iterates and
  /// which would fire a `/dashboard` fetch for an endpoint that has no such
  /// kind) nor in [allKinds] (which seeds a per-section notifier for a section
  /// that has no stream).
  static const String taskCalendar = 'task_calendar';

  /// The consolidated Invoices & Quotes strip (invoiceninja/flutter#155). Like
  /// [taskCalendar] it is **Drift-backed** — it watches the local invoices and
  /// quotes tables — so it belongs in [panelKinds] only, never in [listKinds]
  /// (which `refreshAll` iterates, firing a `/dashboard` fetch for an endpoint
  /// that has no such kind) nor in [allKinds] (which seeds a per-section
  /// notifier for a section that has no stream).
  static const String invoicesAndQuotes = 'invoices_and_quotes';

  /// Every list-card kind. These aren't filter-keyed.
  static const List<String> listKinds = [
    activities,
    pastDue,
    upcomingInvoices,
    recentPayments,
    expiredQuotes,
    upcomingQuotes,
    upcomingRecurring,
  ];

  /// Every section kind (filter-keyed totals/chart + the list cards).
  /// Used to pre-create the per-section listenables on the dashboard VM.
  static const List<String> allKinds = [
    totalsCurrent,
    totalsPrevious,
    chart,
    ...listKinds,
  ];

  /// The bottom-grid panels a user can reorder / show / hide, in the default
  /// render order (mirrors `_bottomGrid` in `dashboard_screen.dart` — note
  /// `upcomingQuotes` precedes `expiredQuotes`). Excludes `activities` (it
  /// rides the chart row, not the orderable grid).
  ///
  /// Not all of these are list cards, and not all are cache-backed:
  /// [taskCalendar] renders a month grid straight off the local tasks table,
  /// and [invoicesAndQuotes] a status strip off the local invoices and quotes
  /// tables.
  /// A new kind goes at the slot it should occupy: `DashboardViewModel._hydrate`
  /// places anything missing from a saved arrangement **at its canonical rank**
  /// here, relative to the kinds that arrangement already holds. (It appended,
  /// once, which made a declared slot unreachable for anyone who had ever
  /// changed the date range — the panel then landed last on every existing
  /// install and first on a fresh one.)
  ///
  /// Only the kinds also in [listKinds] can be left off the dashboard for
  /// having nothing to show ("Hide empty panels", invoiceninja/flutter#161);
  /// `DashboardViewModel` derives that set from these two lists.
  static const List<String> panelKinds = [
    pastDue,
    // Second, immediately below "Needs your attention": it is a superset of
    // three of the panels beneath it, so leading with it is the honest order —
    // and a strip of counts is the one panel meant to be glanced at rather
    // than read, which is worth little at the bottom of a phone page.
    invoicesAndQuotes,
    upcomingInvoices,
    recentPayments,
    upcomingQuotes,
    expiredQuotes,
    upcomingRecurring,
    taskCalendar,
  ];

  /// Per-configured-card cache/section kind. The card's stable
  /// `field|period|calc|format` key is collision-safe here: no static kind
  /// contains `|` or the `calc:` prefix.
  static String calc(String cardKey) => 'calc:$cardKey';
}

/// One unit of refresh work: the cache `kind` a failure is filed under, paired
/// with the call that does it.
///
/// A list of pairs rather than two parallel lists — same shape as
/// `Services._resyncSteps` — so a job can never be reported under a peer's
/// kind.
typedef _RefreshJob = (String, Future<void> Function());

/// Source of truth for dashboard data. The UI watches per-kind streams; the
/// network only writes. There is no outbox path — the dashboard is read-only.
///
/// On a successful fetch the repo upserts the raw API JSON into
/// `dashboard_cache`. The watch streams decode the cached JSON into the
/// domain model lazily, emitting `null` whenever no cache row exists for
/// `(company, kind, filterHash)` yet (UI shows a skeleton).
class DashboardRepository {
  DashboardRepository({
    required this.db,
    required this.api,
    int Function()? now,
    int maxConcurrent = 4,
  }) : _now = now ?? (() => DateTime.now().millisecondsSinceEpoch),
       _maxConcurrent = maxConcurrent;

  final AppDatabase db;
  final DashboardApi api;
  final int Function() _now;
  final int _maxConcurrent;

  /// The company whose token requests are going out under —
  /// `auth.credentials.value?.companyId`, bound by `Services.build` exactly as
  /// every entity repo's is. Tests leave it null, which disables the check.
  String? Function()? activeCompanyId;

  /// Throws unless a fetch for [companyId] may still go out, or its response
  /// still be written.
  ///
  /// Every refresh here writes under the `companyId` it was *called* with,
  /// while `ApiClient` sends whatever token is live — and nothing cancels a
  /// dashboard fetch: the refetch a completed Sync starts
  /// (invoiceninja/flutter#162) is outside the pass `resync.cancel()` stops.
  /// So a company switch filed B's figures under A, and a sign-out let a late
  /// response land after `logout()` had wiped the database and forgotten the
  /// identity, where the next sign-in's identity check can no longer see it.
  ///
  /// Stricter than `BaseEntityRepository.companyStillActive` in one respect: a
  /// bound hook answering null means signed out, and blocks as well. Nothing
  /// on the dashboard fetches before a session exists, so null never means
  /// "not yet".
  void _ensureStillActive(String companyId, String kind) {
    final live = activeCompanyId;
    if (live == null) return;
    final active = live();
    if (active == companyId) return;
    throw CompanySwitchedException(
      expected: companyId,
      active: active,
      entityType: 'dashboard $kind',
    );
  }

  DashboardCacheDao get _dao => db.dashboardCacheDao;

  // ─── Watches ─────────────────────────────────────────────────────────

  Stream<DashboardTotals?> watchTotals(
    String companyId,
    DashboardFilter filter, {
    bool previousPeriod = false,
  }) => _watchDecoded<DashboardTotals>(
    companyId: companyId,
    kind: previousPeriod
        ? DashboardKind.totalsPrevious
        : DashboardKind.totalsCurrent,
    filterHash: filter.filterHash(),
    decode: (m) => DashboardTotals.fromJson(m),
  );

  Stream<DashboardChartSeries?> watchChart(
    String companyId,
    DashboardFilter filter,
  ) => _watchDecoded<DashboardChartSeries>(
    companyId: companyId,
    kind: DashboardKind.chart,
    filterHash: filter.filterHash(),
    decode: (m) => DashboardChartSeries.fromJson(m),
  );

  Stream<List<DashboardActivity>?> watchActivities(String companyId) =>
      _watchList<DashboardActivity>(
        companyId: companyId,
        kind: DashboardKind.activities,
        decode: DashboardActivity.listFromJson,
      );

  /// When the [watchActivities] row was last written — by *any* writer — or
  /// null while there is none.
  ///
  /// The `/activity` screen's "Updated N ago" reads this rather than a stamp of
  /// its own. That row is written by the screen's own refresh, by the Sync
  /// pass's tail, and by every dashboard load of the feed — its boot and
  /// company-switch load, its Refresh button, a card retry, and its refetch
  /// when a pass completes. A stamp only the screen set stayed on "Updated 2h
  /// ago" over rows a Sync had just replaced (invoiceninja/flutter#162).
  ///
  /// `distinct` because Drift re-runs this query on every `dashboard_cache`
  /// write, and a totals or chart refresh must not repaint the label.
  Stream<DateTime?> watchActivitiesFetchedAt(String companyId) => _dao
      .watch(
        companyId: companyId,
        kind: DashboardKind.activities,
        filterHash: kDashboardListFilterHash,
      )
      .map(
        (row) => row == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(row.fetchedAt),
      )
      .distinct();

  Stream<List<DashboardInvoiceRow>?> watchPastDue(String companyId) =>
      _watchList<DashboardInvoiceRow>(
        companyId: companyId,
        kind: DashboardKind.pastDue,
        decode: DashboardInvoiceRow.listFromJson,
      );

  Stream<List<DashboardInvoiceRow>?> watchUpcomingInvoices(String companyId) =>
      _watchList<DashboardInvoiceRow>(
        companyId: companyId,
        kind: DashboardKind.upcomingInvoices,
        decode: DashboardInvoiceRow.listFromJson,
      );

  Stream<List<DashboardPaymentRow>?> watchRecentPayments(String companyId) =>
      _watchList<DashboardPaymentRow>(
        companyId: companyId,
        kind: DashboardKind.recentPayments,
        decode: DashboardPaymentRow.listFromJson,
      );

  Stream<List<DashboardQuoteRow>?> watchExpiredQuotes(String companyId) =>
      _watchList<DashboardQuoteRow>(
        companyId: companyId,
        kind: DashboardKind.expiredQuotes,
        decode: DashboardQuoteRow.listFromJson,
      );

  Stream<List<DashboardQuoteRow>?> watchUpcomingQuotes(String companyId) =>
      _watchList<DashboardQuoteRow>(
        companyId: companyId,
        kind: DashboardKind.upcomingQuotes,
        decode: DashboardQuoteRow.listFromJson,
      );

  Stream<List<DashboardRecurringInvoiceRow>?> watchUpcomingRecurring(
    String companyId,
  ) => _watchList<DashboardRecurringInvoiceRow>(
    companyId: companyId,
    kind: DashboardKind.upcomingRecurring,
    decode: DashboardRecurringInvoiceRow.listFromJson,
  );

  /// Watch one configured card's cached scalar. Filter-keyed (date range /
  /// currency / drafts feed `filterHash`); period/calc/format live in the
  /// card key embedded in the `kind`.
  Stream<DashboardCalculatedField?> watchCalculatedField(
    String companyId,
    DashboardFilter filter,
    DashboardCardConfig config,
  ) {
    return _dao
        .watch(
          companyId: companyId,
          kind: DashboardKind.calc(config.key),
          filterHash: filter.filterHash(),
        )
        // See [_watchDecoded].
        .distinct()
        .map((row) {
          if (row == null) return null;
          try {
            return DashboardCalculatedField.fromServer(jsonDecode(row.payload));
          } catch (e, st) {
            _log.warning(
              'Failed to decode calculated_fields cache [${config.key}]',
              e,
              st,
            );
          }
          return null;
        });
  }

  Future<void> refreshCalculatedField(
    String companyId,
    DashboardFilter filter,
    DashboardCardConfig config,
  ) => _refresh(
    companyId: companyId,
    kind: DashboardKind.calc(config.key),
    filterHash: filter.filterHash(),
    fetch: () => api.fetchCalculatedField(filter, config),
  );

  /// Drop every cached row for a removed/reconfigured card so the cache
  /// doesn't grow across every filter-hash the user ever viewed.
  Future<void> dropCalculatedField(String companyId, DashboardCardConfig c) =>
      _dao.deleteKind(companyId: companyId, kind: DashboardKind.calc(c.key));

  // ─── Refreshes ───────────────────────────────────────────────────────

  /// Refresh totals (both current period and the equivalent previous-period
  /// shift). Two API calls in parallel; both must complete before the future
  /// resolves — a partial failure surfaces as a single rethrown exception.
  Future<void> refreshTotals(String companyId, DashboardFilter filter) async {
    _ensureStillActive(companyId, DashboardKind.totalsCurrent);
    final hash = filter.filterHash();
    final fetchedAt = _now();
    final results = await Future.wait([
      api
          .fetchTotals(filter)
          .then((raw) => MapEntry(DashboardKind.totalsCurrent, raw)),
      api
          .fetchTotals(filter, previousPeriod: true)
          .then((raw) => MapEntry(DashboardKind.totalsPrevious, raw)),
    ]);
    for (final entry in results) {
      if (entry.value == null) continue;
      // Per write: the session can move on between the two.
      _ensureStillActive(companyId, entry.key);
      await _dao.upsert(
        companyId: companyId,
        kind: entry.key,
        filterHash: hash,
        payload: jsonEncode(entry.value),
        fetchedAt: fetchedAt,
      );
    }
  }

  Future<void> refreshChart(String companyId, DashboardFilter filter) =>
      _refresh(
        companyId: companyId,
        kind: DashboardKind.chart,
        filterHash: filter.filterHash(),
        fetch: () => api.fetchChartSummary(filter),
      );

  Future<void> refreshActivities(String companyId) => _refresh(
    companyId: companyId,
    kind: DashboardKind.activities,
    filterHash: kDashboardListFilterHash,
    fetch: api.fetchActivities,
  );

  Future<void> refreshPastDue(String companyId) => _refresh(
    companyId: companyId,
    kind: DashboardKind.pastDue,
    filterHash: kDashboardListFilterHash,
    fetch: api.fetchPastDueInvoices,
  );

  Future<void> refreshUpcomingInvoices(String companyId) => _refresh(
    companyId: companyId,
    kind: DashboardKind.upcomingInvoices,
    filterHash: kDashboardListFilterHash,
    fetch: api.fetchUpcomingInvoices,
  );

  Future<void> refreshRecentPayments(String companyId) => _refresh(
    companyId: companyId,
    kind: DashboardKind.recentPayments,
    filterHash: kDashboardListFilterHash,
    fetch: api.fetchRecentPayments,
  );

  Future<void> refreshExpiredQuotes(String companyId) => _refresh(
    companyId: companyId,
    kind: DashboardKind.expiredQuotes,
    filterHash: kDashboardListFilterHash,
    fetch: api.fetchExpiredQuotes,
  );

  Future<void> refreshUpcomingQuotes(String companyId) => _refresh(
    companyId: companyId,
    kind: DashboardKind.upcomingQuotes,
    filterHash: kDashboardListFilterHash,
    fetch: api.fetchUpcomingQuotes,
  );

  Future<void> refreshUpcomingRecurring(String companyId) => _refresh(
    companyId: companyId,
    kind: DashboardKind.upcomingRecurring,
    filterHash: kDashboardListFilterHash,
    fetch: api.fetchUpcomingRecurringInvoices,
  );

  /// Refresh every kind in parallel under a concurrency cap. Each kind
  /// captures its own error so a partial failure doesn't abort siblings —
  /// the caller (ViewModel) folds per-kind exceptions into its own
  /// per-section error state.
  ///
  /// Returns a map of kind → exception for the kinds that failed.
  Future<Map<String, Object>> refreshAll(
    String companyId,
    DashboardFilter filter, {
    List<DashboardCardConfig> cards = const [],
  }) => _runJobs([
    ..._totalsAndChartJobs(companyId, filter),
    ..._listCardJobs(companyId),
    ..._calculatedFieldJobs(companyId, filter, cards),
  ]);

  /// Filter-keyed-only refresh used when the filter changes (or a single
  /// card is added) — totals + chart + every configured card, capped by the
  /// same semaphore. List cards aren't filter-keyed so they're skipped here.
  Future<Map<String, Object>> refreshFilterKeyed(
    String companyId,
    DashboardFilter filter, {
    List<DashboardCardConfig> cards = const [],
  }) => _runJobs([
    ..._totalsAndChartJobs(companyId, filter),
    ..._calculatedFieldJobs(companyId, filter, cards),
  ]);

  /// The complement of [refreshFilterKeyed]: every list card, and nothing
  /// that depends on a [DashboardFilter].
  ///
  /// List cards aren't filter-keyed — they all live at
  /// [kDashboardListFilterHash] — which is exactly what lets a caller with no
  /// dashboard mounted run them, and that caller is the **Sync pass**
  /// (`Services.syncNow`). That pass re-downloads the fourteen browsable
  /// entity tables and never touched `dashboard_cache`, so the `/activity`
  /// screen and the dashboard's Activity card — both watching the one
  /// `(company, activities, '_')` row — kept painting pre-sync rows until the
  /// user pressed a refresh button. Neither screen re-runs its constructor:
  /// the shell is a `StatefulShellRoute.indexedStack`, so both stay mounted
  /// for the whole session (invoiceninja/flutter#160). See `docs/sync.md`
  /// § A Sync pass re-downloads the entity tables and nothing else.
  ///
  /// Deliberately NOT totals / chart / configured cards: those are keyed by a
  /// [DashboardFilter] that is UI state owned by `DashboardViewModel` (range,
  /// currency, include-drafts). A caller with no dashboard mounted would have
  /// to invent one, and would write a cache row under a hash nothing watches.
  ///
  /// Returns kind → exception for the kinds that failed; never throws.
  /// Iterates [DashboardKind.listKinds], so a kind added there without a
  /// matching [_refreshByKind] case now fails on **every sync** rather than
  /// only on a mounted dashboard — swallowed and logged, so invisible outside
  /// the diagnostics log. `dashboard_repository_test` pins the set.
  Future<Map<String, Object>> refreshListCards(String companyId) =>
      _runJobs(_listCardJobs(companyId));

  /// Run [jobs] in parallel under ONE [_Semaphore], folding each failure into
  /// the returned map under its own kind. Never throws.
  ///
  /// The semaphore is built here and nowhere else, and that is the point:
  /// [_maxConcurrent] caps a refresh *pass*, so two job lists composed into
  /// one call must share one cap. Giving each half its own — the obvious way
  /// to write [refreshAll] as "filter-keyed, then list cards" — silently runs
  /// the dashboard at 2x the cap, which is invisible in review and shows up
  /// only as a burst of parallel requests on a slow connection.
  Future<Map<String, Object>> _runJobs(List<_RefreshJob> jobs) async {
    final errors = <String, Object>{};
    final semaphore = _Semaphore(_maxConcurrent);
    await Future.wait([
      for (final (kind, task) in jobs)
        _runUnder(semaphore, task, onError: (e) => errors[kind] = e),
    ]);
    return errors;
  }

  /// Totals + chart: the two sections keyed by the [filter] itself.
  List<_RefreshJob> _totalsAndChartJobs(
    String companyId,
    DashboardFilter filter,
  ) => [
    (DashboardKind.totalsCurrent, () => refreshTotals(companyId, filter)),
    (DashboardKind.chart, () => refreshChart(companyId, filter)),
  ];

  /// Every list card. Not filter-keyed — see [refreshListCards].
  List<_RefreshJob> _listCardJobs(String companyId) => [
    for (final kind in DashboardKind.listKinds)
      (kind, () => _refreshByKind(companyId, kind)),
  ];

  /// The user's configured calculated-field cards. Filter-keyed too — the
  /// date range / currency / drafts flag live in the hash, `period` / `calc`
  /// / `format` in the card key.
  List<_RefreshJob> _calculatedFieldJobs(
    String companyId,
    DashboardFilter filter,
    List<DashboardCardConfig> cards,
  ) => [
    for (final card in cards)
      (
        DashboardKind.calc(card.key),
        () => refreshCalculatedField(companyId, filter, card),
      ),
  ];

  Future<void> _refreshByKind(String companyId, String kind) {
    switch (kind) {
      case DashboardKind.activities:
        return refreshActivities(companyId);
      case DashboardKind.pastDue:
        return refreshPastDue(companyId);
      case DashboardKind.upcomingInvoices:
        return refreshUpcomingInvoices(companyId);
      case DashboardKind.recentPayments:
        return refreshRecentPayments(companyId);
      case DashboardKind.expiredQuotes:
        return refreshExpiredQuotes(companyId);
      case DashboardKind.upcomingQuotes:
        return refreshUpcomingQuotes(companyId);
      case DashboardKind.upcomingRecurring:
        return refreshUpcomingRecurring(companyId);
    }
    return Future.error(StateError('Unknown dashboard kind: $kind'));
  }

  Future<void> _refresh({
    required String companyId,
    required String kind,
    required String filterHash,
    required Future<Object?> Function() fetch,
  }) async {
    // Before the request too: a job still queued behind the concurrency cap
    // would otherwise go out under the next session's token.
    _ensureStillActive(companyId, kind);
    final raw = await fetch();
    if (raw == null) return;
    _ensureStillActive(companyId, kind);
    await _dao.upsert(
      companyId: companyId,
      kind: kind,
      filterHash: filterHash,
      payload: jsonEncode(raw),
      fetchedAt: _now(),
    );
  }

  Future<void> _runUnder(
    _Semaphore sem,
    Future<void> Function() task, {
    required void Function(Object) onError,
  }) async {
    await sem.acquire();
    try {
      await task();
    } on CompanySwitchedException catch (e) {
      // Benign — the session moved on under the fetch; see
      // [_ensureStillActive]. Still reported, so no caller stamps a refresh
      // whose rows were never written.
      _log.fine('Dashboard refresh task dropped: $e');
      onError(e);
    } catch (e, st) {
      _log.warning('Dashboard refresh task failed', e, st);
      onError(e);
    } finally {
      sem.release();
    }
  }

  /// Watch a single map-shaped payload (`totals`, `chart`).
  ///
  /// `distinct` on the *row*, before decoding: Drift re-runs every watch on
  /// any `dashboard_cache` write, so each refresh job re-decoded — and
  /// re-emitted — every section, including the 250-row activity feed in both
  /// of its view models, and a Sync now issues two rounds of those writes
  /// (invoiceninja/flutter#162). The generated row `==` compares the payload
  /// *and* `fetched_at`, so a real rewrite still comes through. It also stops
  /// an unrelated write from quietly clearing a section's error state, since a
  /// data emission is what resets it.
  Stream<T?> _watchDecoded<T>({
    required String companyId,
    required String kind,
    required String filterHash,
    required T Function(Map<String, dynamic>) decode,
  }) {
    return _dao
        .watch(companyId: companyId, kind: kind, filterHash: filterHash)
        .distinct()
        .map((row) {
          if (row == null) return null;
          try {
            final decoded = jsonDecode(row.payload);
            if (decoded is Map<String, dynamic>) return decode(decoded);
            if (decoded is Map) {
              return decode(decoded.map((k, v) => MapEntry(k.toString(), v)));
            }
          } catch (e, st) {
            _log.warning('Failed to decode dashboard cache [$kind]', e, st);
          }
          return null;
        });
  }

  /// Watch a list-shaped payload (`activities`, list cards). Decodes to
  /// `List<T>`. Uses [kDashboardListFilterHash] for the filter slot. Row-level
  /// `distinct` for the reason on [_watchDecoded].
  Stream<List<T>?> _watchList<T>({
    required String companyId,
    required String kind,
    required List<T> Function(Object?) decode,
  }) {
    return _dao
        .watch(
          companyId: companyId,
          kind: kind,
          filterHash: kDashboardListFilterHash,
        )
        .distinct()
        .map((row) {
          if (row == null) return null;
          try {
            return decode(jsonDecode(row.payload));
          } catch (e, st) {
            _log.warning(
              'Failed to decode dashboard cache list [$kind]',
              e,
              st,
            );
          }
          return null;
        });
  }

  /// Reset (delete) every cached row for `companyId`. Called on company
  /// switch / logout — also covered by `AppDatabase.wipe()`.
  Future<void> clearForCompany(String companyId) =>
      _dao.deleteForCompany(companyId);
}

/// Counting semaphore used to cap concurrent HTTP calls during `refreshAll`.
class _Semaphore {
  _Semaphore(this._maxConcurrent);
  final int _maxConcurrent;
  int _inFlight = 0;
  final _waiters = <Completer<void>>[];

  Future<void> acquire() {
    if (_inFlight < _maxConcurrent) {
      _inFlight++;
      return Future.value();
    }
    final c = Completer<void>();
    _waiters.add(c);
    return c.future;
  }

  void release() {
    if (_waiters.isNotEmpty) {
      _waiters.removeAt(0).complete();
      return;
    }
    if (_inFlight > 0) _inFlight--;
  }
}
