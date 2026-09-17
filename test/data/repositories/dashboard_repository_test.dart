import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/dashboard_cache_dao.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_card_config.dart';
import 'package:admin/data/models/value/dashboard_filter.dart';
import 'package:admin/data/repositories/base_entity_repository.dart'
    show CompanySwitchedException;
import 'package:admin/data/repositories/dashboard_repository.dart';
import 'package:admin/data/services/api_client.dart';
import 'package:admin/data/services/api_credentials.dart';
import 'package:admin/data/services/dashboard_api.dart';
import 'package:admin/data/services/password_cache.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// These tests target DashboardRepository's behavioral contracts:
///   * refresh fans out, writes cache rows, and watch streams emit decoded
///     domain models from those rows
///   * per-kind errors don't kill peer refreshes
///   * `null` is emitted before the first cache row exists
///   * `clearForCompany` wipes the company's cache
///
/// They do NOT exercise the http layer — a fake DashboardApi feeds canned
/// responses.

/// Minimal ApiClient stand-in so we can satisfy [DashboardApi]'s `final
/// ApiClient client` field. The fake never calls it — it's just there because
/// the type requires it.
final ApiClient _dummyClient = ApiClient(
  credentials: ValueNotifier<ApiCredentials?>(
    const ApiCredentials(baseUrl: 'https://test', token: 't'),
  ),
  passwordCache: PasswordCache(),
  onUnauthorized: () async {},
);

class _FakeDashboardApi extends DashboardApi {
  _FakeDashboardApi() : super(_dummyClient);

  final Map<String, Object?> _totalsCurrent = {};
  final Map<String, Object?> _totalsPrevious = {};
  Object? chartSummary;
  Object? activities;
  Object? pastDue;
  Object? upcomingInvoices;
  Object? recentPayments;
  Object? expiredQuotes;
  Object? upcomingQuotes;
  Object? upcomingRecurring;

  /// Per-method failure injection. Throws when set.
  Map<String, Object> failures = {};

  /// Canned calculated-field payload, and the `failures` key it answers to.
  Object? calculatedField;
  static const String calcKey = 'calculated_field';

  /// Live and high-water counts of *overlapping* fetches, so a test can assert
  /// the repo's concurrency cap. See `a refresh pass never exceeds
  /// maxConcurrent`.
  int inFlight = 0;
  int peakInFlight = 0;

  /// Runs as a fetch goes out — lets a test move the session on while the
  /// request is on the wire.
  void Function()? onFetch;

  Future<Object?> _maybe(String key, Object? value) async {
    onFetch?.call();
    inFlight++;
    if (inFlight > peakInFlight) peakInFlight = inFlight;
    // Yield so peers can enter before this one leaves. Without it every fetch
    // would finish in the microtask it started in, the peak would read 1
    // whatever the cap is, and the concurrency test would be vacuously green.
    await Future<void>.delayed(Duration.zero);
    inFlight--;
    final fail = failures[key];
    if (fail != null) throw fail;
    return value;
  }

  @override
  Future<Object?> fetchCalculatedField(
    DashboardFilter filter,
    DashboardCardConfig config,
  ) => _maybe(calcKey, calculatedField);

  @override
  Future<Object?> fetchTotals(
    DashboardFilter filter, {
    bool previousPeriod = false,
  }) {
    final key = previousPeriod ? 'totals_previous' : 'totals_current';
    final value = previousPeriod
        ? _totalsPrevious[filter.filterHash()]
        : _totalsCurrent[filter.filterHash()];
    return _maybe(key, value);
  }

  @override
  Future<Object?> fetchChartSummary(DashboardFilter filter) =>
      _maybe('chart', chartSummary);

  @override
  Future<Object?> fetchActivities() => _maybe('activities', activities);

  @override
  Future<Object?> fetchPastDueInvoices() => _maybe('past_due', pastDue);

  @override
  Future<Object?> fetchUpcomingInvoices() =>
      _maybe('upcoming_invoices', upcomingInvoices);

  @override
  Future<Object?> fetchRecentPayments() =>
      _maybe('recent_payments', recentPayments);

  @override
  Future<Object?> fetchExpiredQuotes() =>
      _maybe('expired_quotes', expiredQuotes);

  @override
  Future<Object?> fetchUpcomingQuotes() =>
      _maybe('upcoming_quotes', upcomingQuotes);

  @override
  Future<Object?> fetchUpcomingRecurringInvoices() =>
      _maybe('upcoming_recurring', upcomingRecurring);
}

void main() {
  late AppDatabase db;
  late _FakeDashboardApi api;
  late DashboardRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    api = _FakeDashboardApi();
    repo = DashboardRepository(db: db, api: api, now: () => 1000);
  });

  tearDown(() async {
    await db.close();
  });

  group('refresh + watch round-trip', () {
    test('watchTotals emits null until refresh writes a cache row', () async {
      final filter = DashboardFilter.defaults();
      // Seed the response: a single-currency totals map.
      api._totalsCurrent[filter.filterHash()] = {
        'currencies': {'1': 'USD'},
        '1': {
          'revenue': {'paid_to_date': '100.50', 'code': 'USD'},
          'expenses': {'amount': '0', 'code': 'USD'},
          'invoices': {'invoiced_amount': '0', 'code': 'USD'},
          'outstanding': {
            'outstanding_count': 3,
            'amount': '250.00',
            'code': 'USD',
          },
        },
      };
      api._totalsPrevious[filter.filterHash()] =
          api._totalsCurrent[filter.filterHash()];

      final stream = repo.watchTotals('co_a', filter);
      final values = <dynamic>[];
      final sub = stream.listen(values.add);

      // Settle the initial subscription.
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(values.last, isNull);

      await repo.refreshTotals('co_a', filter);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(values.last, isNotNull);
      expect(values.last!.byCurrency.length, 1);
      expect(values.last!.byCurrency['1']!.outstandingCount, 3);

      await sub.cancel();
    });

    test('refreshAll fans out and records per-kind failures', () async {
      final filter = DashboardFilter.defaults();
      api._totalsCurrent[filter.filterHash()] = {
        'currencies': <String, dynamic>{},
      };
      api._totalsPrevious[filter.filterHash()] = {
        'currencies': <String, dynamic>{},
      };
      api.chartSummary = {'start_date': '2026-05-01', 'end_date': '2026-05-31'};
      api.activities = <dynamic>[];
      api.pastDue = <dynamic>[];
      api.upcomingInvoices = <dynamic>[];
      api.recentPayments = <dynamic>[];
      api.expiredQuotes = <dynamic>[];
      api.upcomingQuotes = <dynamic>[];
      api.upcomingRecurring = <dynamic>[];

      // Inject a failure on one kind.
      api.failures['chart'] = StateError('boom');

      final errors = await repo.refreshAll('co_a', filter);
      expect(errors.containsKey(DashboardKind.chart), isTrue);
      // Other kinds still completed successfully — verified by reading the DAO.
      final pastDueRow = await db.dashboardCacheDao.read(
        companyId: 'co_a',
        kind: DashboardKind.pastDue,
        filterHash: kDashboardListFilterHash,
      );
      expect(pastDueRow, isNotNull);
    });

    test('clearForCompany wipes only that company\'s cache', () async {
      final filter = DashboardFilter.defaults();
      api.pastDue = <dynamic>[];
      api._totalsCurrent[filter.filterHash()] = {
        'currencies': <String, dynamic>{},
      };
      api._totalsPrevious[filter.filterHash()] = {
        'currencies': <String, dynamic>{},
      };

      await repo.refreshPastDue('co_a');
      await repo.refreshPastDue('co_b');

      await repo.clearForCompany('co_a');

      final a = await db.dashboardCacheDao.read(
        companyId: 'co_a',
        kind: DashboardKind.pastDue,
        filterHash: kDashboardListFilterHash,
      );
      final b = await db.dashboardCacheDao.read(
        companyId: 'co_b',
        kind: DashboardKind.pastDue,
        filterHash: kDashboardListFilterHash,
      );
      expect(a, isNull);
      expect(b, isNotNull);
    });

    test('AppDatabase.wipe() clears dashboard_cache', () async {
      api.pastDue = <dynamic>[];
      await repo.refreshPastDue('co_a');
      expect(
        await db.dashboardCacheDao.read(
          companyId: 'co_a',
          kind: DashboardKind.pastDue,
          filterHash: kDashboardListFilterHash,
        ),
        isNotNull,
      );
      await db.wipe();
      expect(
        await db.dashboardCacheDao.read(
          companyId: 'co_a',
          kind: DashboardKind.pastDue,
          filterHash: kDashboardListFilterHash,
        ),
        isNull,
      );
    });
  });

  /// A dashboard fetch writes under the company it was called with, and nothing
  /// cancels one — so the refetch a completed Sync starts (#162) could land
  /// after a sign-out wiped the database, or file one company's figures under
  /// another after a switch.
  group('the live-company guard (issue #162)', () {
    Future<dynamic> readActivities() => db.dashboardCacheDao.read(
      companyId: 'co_a',
      kind: DashboardKind.activities,
      filterHash: kDashboardListFilterHash,
    );

    setUp(() => api.activities = <dynamic>[]);

    test('an unbound hook checks nothing', () async {
      await repo.refreshActivities('co_a');
      expect(await readActivities(), isNotNull);
    });

    test('the live company writes', () async {
      repo.activeCompanyId = () => 'co_a';
      await repo.refreshActivities('co_a');
      expect(await readActivities(), isNotNull);
    });

    test('another company throws and writes nothing', () async {
      repo.activeCompanyId = () => 'co_b';
      await expectLater(
        repo.refreshActivities('co_a'),
        throwsA(isA<CompanySwitchedException>()),
      );
      expect(await readActivities(), isNull);
    });

    test('signed out — a bound hook answering null — writes nothing', () async {
      // Stricter than the entity repos, where null means "not yet": nothing on
      // the dashboard fetches before a session exists.
      repo.activeCompanyId = () => null;
      await expectLater(
        repo.refreshActivities('co_a'),
        throwsA(isA<CompanySwitchedException>()),
      );
      expect(await readActivities(), isNull);
    });

    test(
      'a sign-out landing while the request is out writes nothing',
      () async {
        String? live = 'co_a';
        repo.activeCompanyId = () => live;
        api.onFetch = () => live = null;

        await expectLater(
          repo.refreshActivities('co_a'),
          throwsA(isA<CompanySwitchedException>()),
        );
        expect(await readActivities(), isNull);
      },
    );

    test('totals check before each write', () async {
      final filter = DashboardFilter.defaults();
      api._totalsCurrent[filter.filterHash()] = {
        'currencies': <String, dynamic>{},
      };
      api._totalsPrevious[filter.filterHash()] = {
        'currencies': <String, dynamic>{},
      };
      String? live = 'co_a';
      repo.activeCompanyId = () => live;
      api.onFetch = () => live = 'co_b';

      await expectLater(
        repo.refreshTotals('co_a', filter),
        throwsA(isA<CompanySwitchedException>()),
      );
      for (final kind in [
        DashboardKind.totalsCurrent,
        DashboardKind.totalsPrevious,
      ]) {
        expect(
          await db.dashboardCacheDao.read(
            companyId: 'co_a',
            kind: kind,
            filterHash: filter.filterHash(),
          ),
          isNull,
          reason: kind,
        );
      }
    });

    test('a batch reports the drop per kind rather than throwing', () async {
      repo.activeCompanyId = () => null;
      api.pastDue = <dynamic>[];

      final errors = await repo.refreshListCards('co_a');

      expect(errors, isNotEmpty);
      expect(errors.values, everyElement(isA<CompanySwitchedException>()));
    });
  });

  /// Drift re-runs every watch on any `dashboard_cache` write; the decoded
  /// streams must not re-emit a row that didn't change (#162 doubled the writes
  /// per Sync).
  group('decoded watches skip unchanged rows (issue #162)', () {
    test('a write to another kind does not re-emit; a rewrite does', () async {
      var clock = 1000;
      final ticking = DashboardRepository(db: db, api: api, now: () => clock);
      api.activities = <dynamic>[];
      api.pastDue = <dynamic>[];
      Future<void> settle() =>
          Future<void>.delayed(const Duration(milliseconds: 20));

      var emissions = 0;
      final sub = ticking.watchActivities('co_a').listen((_) => emissions++);
      addTearDown(sub.cancel);
      await settle();
      await ticking.refreshActivities('co_a');
      await settle();
      final afterWrite = emissions;

      await ticking.refreshPastDue('co_a');
      await settle();
      expect(emissions, afterWrite, reason: 'an unrelated row was written');

      clock = 2000;
      await ticking.refreshActivities('co_a');
      await settle();
      expect(
        emissions,
        afterWrite + 1,
        reason: 'a new fetched_at is a real rewrite, payload or not',
      );
    });
  });

  /// The `/activity` screen's "Updated N ago" follows this, so every writer of
  /// the row moves it (invoiceninja/flutter#162).
  group('watchActivitiesFetchedAt (issue #162)', () {
    test('emits null, then each write time of the activities row — and nothing '
        'for a write to another kind', () async {
      var clock = 1000;
      final ticking = DashboardRepository(db: db, api: api, now: () => clock);
      api.activities = <dynamic>[];
      api.pastDue = <dynamic>[];
      Future<void> settle() =>
          Future<void>.delayed(const Duration(milliseconds: 20));

      final seen = <DateTime?>[];
      final sub = ticking.watchActivitiesFetchedAt('co_a').listen(seen.add);
      addTearDown(sub.cancel);
      await settle();
      expect(seen, [null], reason: 'no row yet');

      await ticking.refreshActivities('co_a');
      await settle();
      expect(seen, [null, DateTime.fromMillisecondsSinceEpoch(1000)]);

      // Drift re-runs the query on any `dashboard_cache` write — a totals or
      // list-card refresh must not repaint the label.
      clock = 2000;
      await ticking.refreshPastDue('co_a');
      await settle();
      expect(seen, hasLength(2));

      // A second writer of the same row: the Sync tail, the dashboard.
      await ticking.refreshActivities('co_a');
      await settle();
      expect(seen.last, DateTime.fromMillisecondsSinceEpoch(2000));
      expect(seen, hasLength(3));
    });

    test('is scoped to its company', () async {
      api.activities = <dynamic>[];
      final seen = <DateTime?>[];
      final sub = repo.watchActivitiesFetchedAt('co_b').listen(seen.add);
      addTearDown(sub.cancel);

      await repo.refreshActivities('co_a');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(seen, [null]);
    });
  });

  /// The Sync pass calls [DashboardRepository.refreshListCards] so the
  /// `/activity` screen and the dashboard's list cards stop showing pre-sync
  /// rows (invoiceninja/flutter#160).
  group('refreshListCards (issue #160)', () {
    /// Seed every list-card endpoint. Totals and chart are deliberately left
    /// unseeded — half of what these tests pin is what `refreshListCards`
    /// does NOT touch.
    void seedListCards() {
      api.activities = <dynamic>[];
      api.pastDue = <dynamic>[];
      api.upcomingInvoices = <dynamic>[];
      api.recentPayments = <dynamic>[];
      api.expiredQuotes = <dynamic>[];
      api.upcomingQuotes = <dynamic>[];
      api.upcomingRecurring = <dynamic>[];
    }

    Future<dynamic> readList(String kind) => db.dashboardCacheDao.read(
      companyId: 'co_a',
      kind: kind,
      filterHash: kDashboardListFilterHash,
    );

    test('writes every list-card row and nothing filter-keyed', () async {
      seedListCards();

      final errors = await repo.refreshListCards('co_a');

      expect(
        errors,
        isEmpty,
        reason:
            'an empty error map also pins that every DashboardKind.listKinds '
            'entry is routable through _refreshByKind — a kind added there '
            'with no case falls through to a StateError that a Sync pass would '
            'swallow and log on every pass, forever',
      );
      for (final kind in DashboardKind.listKinds) {
        expect(await readList(kind), isNotNull, reason: 'no row for $kind');
      }
      // The filter-keyed half stays the dashboard's own business: it is keyed
      // by a DashboardFilter this caller has no business inventing.
      expect(
        await db.dashboardCacheDao.read(
          companyId: 'co_a',
          kind: DashboardKind.totalsCurrent,
          filterHash: DashboardFilter.defaults().filterHash(),
        ),
        isNull,
      );
    });

    test('records a per-kind failure without aborting its siblings', () async {
      seedListCards();
      api.failures[DashboardKind.activities] = StateError('boom');

      final errors = await repo.refreshListCards('co_a');

      expect(errors.keys, {DashboardKind.activities});
      for (final kind in DashboardKind.listKinds) {
        if (kind == DashboardKind.activities) continue;
        expect(await readList(kind), isNotNull, reason: 'no row for $kind');
      }
    });

    test(
      'a refresh pass never exceeds maxConcurrent, however its job lists are '
      'composed',
      () async {
        // The regression this exists for: `refreshAll` and `refreshFilterKeyed`
        // each used to build their own `_Semaphore`, so composing them — the
        // obvious way to write `refreshAll` as "filter-keyed, then list cards"
        // — would silently run the dashboard at a multiple of the cap. Only one
        // private driver may construct a semaphore.
        final filter = DashboardFilter.defaults();
        final capped = DashboardRepository(
          db: db,
          api: api,
          now: () => 1000,
          maxConcurrent: 2,
        );
        seedListCards();
        api.chartSummary = {
          'start_date': '2026-05-01',
          'end_date': '2026-05-31',
        };
        api._totalsCurrent[filter.filterHash()] = {
          'currencies': <String, dynamic>{},
        };
        api._totalsPrevious[filter.filterHash()] = {
          'currencies': <String, dynamic>{},
        };
        api.calculatedField = <String, dynamic>{};
        const cards = [
          DashboardCardConfig(
            field: 'active_invoices',
            period: CardPeriod.current,
            calculate: CardCalc.sum,
            format: CardFormat.money,
          ),
        ];

        // The cap is on *jobs*, and every list card is exactly one fetch, so
        // here the two units coincide and the assertion can be exact.
        api.peakInFlight = 0;
        await capped.refreshListCards('co_a');
        expect(api.peakInFlight, lessThanOrEqualTo(2));
        expect(
          api.peakInFlight,
          greaterThan(1),
          reason:
              'if nothing ever overlapped, the cap assertions here would pass '
              'no matter how many semaphores were in play',
        );

        // The composed call: all three job builders at once. One job —
        // `refreshTotals` — deliberately fires its current and previous
        // periods in parallel *inside* its single slot, so the fetch-level
        // peak sits exactly one above the job-level cap. A regression giving
        // each builder its own semaphore would put it at 7, not 3.
        api.peakInFlight = 0;
        await capped.refreshAll('co_a', filter, cards: cards);
        expect(api.peakInFlight, lessThanOrEqualTo(3));
        expect(api.peakInFlight, greaterThan(1));
      },
    );
  });
}
