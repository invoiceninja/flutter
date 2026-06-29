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

  /// The six bottom-grid list panels a user can reorder / show / hide, in the
  /// default render order (mirrors `_bottomGrid` in `dashboard_screen.dart` —
  /// note `upcomingQuotes` precedes `expiredQuotes`). Excludes `activities`
  /// (it rides the chart row, not the orderable grid).
  static const List<String> panelKinds = [
    pastDue,
    upcomingInvoices,
    recentPayments,
    upcomingQuotes,
    expiredQuotes,
    upcomingRecurring,
  ];

  /// Per-configured-card cache/section kind. The card's stable
  /// `field|period|calc|format` key is collision-safe here: no static kind
  /// contains `|` or the `calc:` prefix.
  static String calc(String cardKey) => 'calc:$cardKey';
}

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
  }) async {
    final errors = <String, Object>{};
    final semaphore = _Semaphore(_maxConcurrent);
    final jobs = <Future<void>>[
      _runUnder(
        semaphore,
        () => refreshTotals(companyId, filter),
        onError: (e) => errors[DashboardKind.totalsCurrent] = e,
      ),
      _runUnder(
        semaphore,
        () => refreshChart(companyId, filter),
        onError: (e) => errors[DashboardKind.chart] = e,
      ),
      for (final kind in DashboardKind.listKinds)
        _runUnder(
          semaphore,
          () => _refreshByKind(companyId, kind),
          onError: (e) => errors[kind] = e,
        ),
      for (final card in cards)
        _runUnder(
          semaphore,
          () => refreshCalculatedField(companyId, filter, card),
          onError: (e) => errors[DashboardKind.calc(card.key)] = e,
        ),
    ];
    await Future.wait(jobs);
    return errors;
  }

  /// Filter-keyed-only refresh used when the filter changes (or a single
  /// card is added) — totals + chart + every configured card, capped by the
  /// same semaphore. List cards aren't filter-keyed so they're skipped here.
  Future<Map<String, Object>> refreshFilterKeyed(
    String companyId,
    DashboardFilter filter, {
    List<DashboardCardConfig> cards = const [],
  }) async {
    final errors = <String, Object>{};
    final semaphore = _Semaphore(_maxConcurrent);
    await Future.wait([
      _runUnder(
        semaphore,
        () => refreshTotals(companyId, filter),
        onError: (e) => errors[DashboardKind.totalsCurrent] = e,
      ),
      _runUnder(
        semaphore,
        () => refreshChart(companyId, filter),
        onError: (e) => errors[DashboardKind.chart] = e,
      ),
      for (final card in cards)
        _runUnder(
          semaphore,
          () => refreshCalculatedField(companyId, filter, card),
          onError: (e) => errors[DashboardKind.calc(card.key)] = e,
        ),
    ]);
    return errors;
  }

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
    final raw = await fetch();
    if (raw == null) return;
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
    } catch (e, st) {
      _log.warning('Dashboard refresh task failed', e, st);
      onError(e);
    } finally {
      sem.release();
    }
  }

  /// Watch a single map-shaped payload (`totals`, `chart`).
  Stream<T?> _watchDecoded<T>({
    required String companyId,
    required String kind,
    required String filterHash,
    required T Function(Map<String, dynamic>) decode,
  }) {
    return _dao
        .watch(companyId: companyId, kind: kind, filterHash: filterHash)
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
  /// `List<T>`. Uses [kDashboardListFilterHash] for the filter slot.
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
