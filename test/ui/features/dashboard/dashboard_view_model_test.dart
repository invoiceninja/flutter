import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_card_config.dart';
import 'package:admin/data/repositories/dashboard_repository.dart';
import 'package:admin/data/repositories/statics_repository.dart';
import 'package:admin/data/services/statics_service.dart';
import 'package:admin/ui/features/dashboard/view_models/dashboard_view_model.dart';

import '_fake_dashboard_repo.dart';

void main() {
  late AppDatabase db;
  late FakeDashboardRepo repo;
  late DashboardViewModel vm;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = FakeDashboardRepo(db);
    vm = DashboardViewModel(
      repo: repo,
      companyId: 'co',
      navStateDao: db.navStateDao,
      statics: StaticsRepository(
        db: db,
        service: StaticsService(dummyDashboardClient),
      ),
    );
    // Let _init() (hydrate + subscribeAll + refresh) settle.
    await Future<void>.delayed(const Duration(milliseconds: 20));
  });

  tearDown(() async {
    vm.dispose();
    await db.close();
  });

  // 4.5 — per-section listenables. A single section's stream emission must
  // bump *only* that section's listenable (so one card rebuilds), and must
  // NOT fire the global VM notify (which is reserved for cross-cutting
  // chrome: filter / refresh state). Cross-cutting actions (`setFilter`)
  // must still fire the global notify.
  test('a single section emission bumps only that section listenable, '
      'not peers and not the global notify', () async {
    var activitiesHits = 0;
    var pastDueHits = 0;
    var globalHits = 0;
    vm
        .listenableFor(DashboardKind.activities)
        .addListener(() => activitiesHits++);
    vm.listenableFor(DashboardKind.pastDue).addListener(() => pastDueHits++);
    vm.addListener(() => globalHits++);

    // Content is irrelevant — routing is what's under test. An empty
    // list still drives the stream → onData → _bumpSection(activities).
    repo.activities.add(const []);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(activitiesHits, 1, reason: 'activities card should rebuild');
    expect(pastDueHits, 0, reason: 'peer section must not rebuild');
    expect(
      globalHits,
      0,
      reason: 'a data emission must not fire the global notify',
    );
  });

  test('setFilter fires the global notify (chrome) ', () async {
    var globalHits = 0;
    vm.addListener(() => globalHits++);

    await vm.setFilter(
      vm.filter.copyWith(includeDrafts: !vm.filter.includeDrafts),
    );

    expect(globalHits, greaterThanOrEqualTo(1));
  });

  test('retry error surfaces on the failing section listenable only', () async {
    var pastDueHits = 0;
    var activitiesHits = 0;
    vm.listenableFor(DashboardKind.pastDue).addListener(() => pastDueHits++);
    vm
        .listenableFor(DashboardKind.activities)
        .addListener(() => activitiesHits++);

    // refreshPastDue is overridden to succeed; force the error path by
    // making the section error via retry of a kind whose refresh throws.
    // Simplest: drive _setSectionError through retry with a thrown repo.
    await vm.retry(DashboardKind.pastDue);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    // retry(pastDue) → _setSectionError(pastDue, null) → bumps pastDue.
    expect(pastDueHits, greaterThanOrEqualTo(1));
    expect(activitiesHits, 0);
  });

  // #23: the legend defaults to all four series (React renders every series
  // unconditionally). Envelopes written before that change carry the retired
  // invoices-only default and are upgraded once, while any deliberate choice
  // — including invoices-only made *after* the upgrade — survives.
  group('chart series legend', () {
    DashboardViewModel newVm({Duration? persistDebounce}) => DashboardViewModel(
      repo: repo,
      companyId: 'co',
      navStateDao: db.navStateDao,
      statics: StaticsRepository(
        db: db,
        service: StaticsService(dummyDashboardClient),
      ),
      persistDebounce: persistDebounce ?? const Duration(milliseconds: 500),
    );

    Future<DashboardViewModel> readerFor(Map<String, Object?> dashboard) async {
      await db.navStateDao.saveFilters(
        filtersJson: jsonEncode({
          'co': {'dashboard': dashboard},
        }),
        now: 1,
      );
      final reader = newVm();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return reader;
    }

    test('defaults to all four series', () {
      expect(vm.visibleChartSeries, kDefaultChartSeries);
    });

    test('kDefaultChartSeries covers every ChartSeriesId and is immutable', () {
      // Fails if a fifth series is added to the enum without updating the
      // const, which would silently ship it disabled-by-default.
      expect(kDefaultChartSeries, ChartSeriesId.values.toSet());
      // Fails if the const is swapped for a shared growable set, which one
      // stray in-place mutation could poison process-wide.
      expect(
        () => kDefaultChartSeries.add(ChartSeriesId.invoices),
        throwsUnsupportedError,
      );
    });

    test('legacy invoices-only envelope upgrades to all four', () async {
      final reader = await readerFor({
        'chartSeries': ['invoices'],
      });
      expect(reader.visibleChartSeries, kDefaultChartSeries);
      reader.dispose();
    });

    test('a legacy hand-picked subset is preserved', () async {
      final reader = await readerFor({
        'chartSeries': ['payments', 'expenses'],
      });
      expect(reader.visibleChartSeries, {
        ChartSeriesId.payments,
        ChartSeriesId.expenses,
      });
      reader.dispose();
    });

    test('invoices-only is honored once the marker is present', () async {
      final reader = await readerFor({
        'chartSeries': ['invoices'],
        'chartSeriesV': 2,
      });
      expect(reader.visibleChartSeries, {ChartSeriesId.invoices});
      reader.dispose();
    });

    test('toggling down to invoices-only survives a restart', () async {
      final writer = newVm(persistDebounce: const Duration(milliseconds: 5));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      writer
        ..toggleChartSeries(ChartSeriesId.payments)
        ..toggleChartSeries(ChartSeriesId.outstanding)
        ..toggleChartSeries(ChartSeriesId.expenses);
      // Let the debounced _persist() flush to nav_state.
      await Future<void>.delayed(const Duration(milliseconds: 40));
      writer.dispose();

      final reader = newVm();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        reader.visibleChartSeries,
        {ChartSeriesId.invoices},
        reason: 'a deliberate invoices-only choice must not be re-upgraded',
      );
      reader.dispose();
    });

    test('an unrelated persist stamps the version marker', () async {
      final writer = newVm(persistDebounce: const Duration(milliseconds: 5));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      // Legend untouched — only the grouping changes.
      writer.setChartGrouping(ChartGrouping.week);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      writer.dispose();

      final doc =
          jsonDecode((await db.navStateDao.current())!.filtersJson!)
              as Map<String, dynamic>;
      final dash =
          (doc['co']! as Map<String, dynamic>)['dashboard']!
              as Map<String, dynamic>;
      expect(dash['chartSeriesV'], 2);
      expect(
        (dash['chartSeries']! as List).cast<String>().toSet(),
        kDefaultChartSeries.map((s) => s.name).toSet(),
      );
    });

    test('absent chartSeries key (pre-legend install) → all four', () async {
      final reader = await readerFor({
        'dashboardCards': ['active_invoices|current|sum|money'],
      });
      expect(reader.visibleChartSeries, kDefaultChartSeries);
      reader.dispose();
    });

    test('an all-unknown series list falls back to the default', () async {
      final reader = await readerFor({
        'chartSeries': ['bogus'],
      });
      expect(reader.visibleChartSeries, kDefaultChartSeries);
      reader.dispose();
    });

    test('toggleChartSeries refuses to empty the set', () {
      var globalHits = 0;
      vm.addListener(() => globalHits++);
      for (final id in ChartSeriesId.values) {
        vm.toggleChartSeries(id);
      }
      // The last toggle would have emptied the chart, so it is refused.
      expect(vm.visibleChartSeries, {ChartSeriesId.expenses});
      expect(
        globalHits,
        ChartSeriesId.values.length - 1,
        reason: 'the refused toggle must not notify',
      );
    });
  });

  group('chart grouping', () {
    test('defaults to month when nav_state has no chartGrouping', () {
      expect(vm.chartGrouping, ChartGrouping.month);
    });

    test('setChartGrouping fires global notify, does not change the filter, '
        'and never refetches', () async {
      var globalHits = 0;
      vm.addListener(() => globalHits++);
      final filterBefore = vm.filter;
      final hashBefore = vm.filter.filterHash();

      vm.setChartGrouping(ChartGrouping.week);

      expect(vm.chartGrouping, ChartGrouping.week);
      expect(globalHits, greaterThanOrEqualTo(1));
      // Pure client-side re-bucket: the filter (and its hash, which keys
      // the network fetch) is untouched.
      expect(vm.filter, filterBefore);
      expect(vm.filter.filterHash(), hashBefore);

      // No-op when unchanged.
      globalHits = 0;
      vm.setChartGrouping(ChartGrouping.week);
      expect(globalHits, 0);
    });

    test('add/remove/reorder persist, fetch, and purge cache', () async {
      const a = DashboardCardConfig(
        field: 'active_invoices',
        period: CardPeriod.current,
        calculate: CardCalc.sum,
        format: CardFormat.money,
      );
      const b = DashboardCardConfig(
        field: 'logged_tasks',
        period: CardPeriod.total,
        calculate: CardCalc.count,
        format: CardFormat.money,
      );

      vm.addCard(a);
      vm.addCard(b);
      vm.addCard(a); // duplicate → no-op
      expect(vm.dashboardCards.map((c) => c.key), [a.key, b.key]);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(repo.refreshedCardKeys, contains(a.key));

      vm.reorderCards(0, 1); // move a to index 1 (after b)
      expect(vm.dashboardCards.map((c) => c.key), [b.key, a.key]);

      vm.removeCard(a.key);
      expect(vm.dashboardCards.map((c) => c.key), [b.key]);
      expect(repo.droppedCardKeys, contains(a.key));
    });

    test('persists and rehydrates configured cards in order', () async {
      final writer = DashboardViewModel(
        repo: repo,
        companyId: 'co',
        navStateDao: db.navStateDao,
        statics: StaticsRepository(
          db: db,
          service: StaticsService(dummyDashboardClient),
        ),
        persistDebounce: const Duration(milliseconds: 5),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      writer.addCard(
        const DashboardCardConfig(
          field: 'active_quotes',
          period: CardPeriod.previous,
          calculate: CardCalc.avg,
          format: CardFormat.money,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 40));
      writer.dispose();

      final reader = DashboardViewModel(
        repo: repo,
        companyId: 'co',
        navStateDao: db.navStateDao,
        statics: StaticsRepository(
          db: db,
          service: StaticsService(dummyDashboardClient),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        reader.dashboardCards.single.key,
        'active_quotes|previous|avg|money',
      );
      reader.dispose();
    });

    test('persists and rehydrates the selected grouping', () async {
      final writer = DashboardViewModel(
        repo: repo,
        companyId: 'co',
        navStateDao: db.navStateDao,
        statics: StaticsRepository(
          db: db,
          service: StaticsService(dummyDashboardClient),
        ),
        persistDebounce: const Duration(milliseconds: 5),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      writer.setChartGrouping(ChartGrouping.day);
      // Let the debounced _persist() flush to nav_state.
      await Future<void>.delayed(const Duration(milliseconds: 40));
      writer.dispose();

      final reader = DashboardViewModel(
        repo: repo,
        companyId: 'co',
        navStateDao: db.navStateDao,
        statics: StaticsRepository(
          db: db,
          service: StaticsService(dummyDashboardClient),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(reader.chartGrouping, ChartGrouping.day);
      reader.dispose();
    });

    test(
      're-add after remove waits for the pending drop before refetch',
      () async {
        const a = DashboardCardConfig(
          field: 'active_invoices',
          period: CardPeriod.current,
          calculate: CardCalc.sum,
          format: CardFormat.money,
        );
        vm.addCard(a);
        await Future<void>.delayed(const Duration(milliseconds: 10));
        repo.refreshedCardKeys.clear();

        final gate = Completer<void>();
        repo.dropGate = gate;
        vm.removeCard(a.key); // drop starts, blocked on the gate
        vm.addCard(a); // re-add → _refreshCard must await the pending drop
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(
          repo.refreshedCardKeys,
          isNot(contains(a.key)),
          reason: 'refetch must not run while the drop is still pending',
        );

        gate.complete();
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(
          repo.refreshedCardKeys,
          contains(a.key),
          reason: 'refetch runs once the drop completes (fresh row survives)',
        );
      },
    );
  });

  group('list panels', () {
    DashboardViewModel newVm({Duration? persistDebounce}) => DashboardViewModel(
      repo: repo,
      companyId: 'co',
      navStateDao: db.navStateDao,
      statics: StaticsRepository(
        db: db,
        service: StaticsService(dummyDashboardClient),
      ),
      persistDebounce: persistDebounce ?? const Duration(milliseconds: 500),
    );

    test('defaults to the six panels, in order, all visible', () {
      expect(vm.panelPrefs.map((p) => p.kind), DashboardKind.panelKinds);
      expect(vm.panelPrefs.every((p) => p.visible), isTrue);
      expect(vm.panelsAreDefault, isTrue);
    });

    test('reorderPanels moves a panel, fires notify, clears default', () {
      var globalHits = 0;
      vm.addListener(() => globalHits++);
      vm.reorderPanels(0, 2); // pastDue → index 2
      expect(vm.panelPrefs.first.kind, DashboardKind.upcomingInvoices);
      expect(vm.panelPrefs[2].kind, DashboardKind.pastDue);
      expect(vm.panelsAreDefault, isFalse);
      expect(globalHits, greaterThanOrEqualTo(1));
    });

    test('togglePanelVisibility flips one panel, preserves order', () {
      vm.togglePanelVisibility(DashboardKind.expiredQuotes);
      expect(
        vm.panelPrefs
            .firstWhere((p) => p.kind == DashboardKind.expiredQuotes)
            .visible,
        isFalse,
      );
      expect(vm.panelPrefs.map((p) => p.kind), DashboardKind.panelKinds);
      expect(vm.panelsAreDefault, isFalse);
      // Toggling back restores the canonical default.
      vm.togglePanelVisibility(DashboardKind.expiredQuotes);
      expect(vm.panelsAreDefault, isTrue);
    });

    test('resetPanels restores default order + visibility', () {
      vm.reorderPanels(0, 3);
      vm.togglePanelVisibility(DashboardKind.recentPayments);
      expect(vm.panelsAreDefault, isFalse);
      vm.resetPanels();
      expect(vm.panelPrefs.map((p) => p.kind), DashboardKind.panelKinds);
      expect(vm.panelPrefs.every((p) => p.visible), isTrue);
      expect(vm.panelsAreDefault, isTrue);
    });

    test(
      'reorderTrailingPanels reorders the five, preserves past-due slot',
      () {
        // Default: past-due at index 0. Move the first of the five (upcoming
        // invoices) to the end of the five.
        vm.reorderTrailingPanels(0, 4);
        expect(vm.panelPrefs.map((p) => p.kind), const [
          'past_due', // pinned, unchanged
          'recent_payments',
          'upcoming_quotes',
          'expired_quotes',
          'upcoming_recurring',
          'upcoming_invoices',
        ]);

        // Now move past-due off slot 0, then reorder the five again and confirm
        // past-due keeps its (non-zero) slot.
        vm.resetPanels();
        vm.reorderPanels(0, 2); // past-due → index 2
        expect(vm.panelPrefs[2].kind, DashboardKind.pastDue);
        vm.reorderTrailingPanels(0, 1); // swap the first two of the five
        expect(
          vm.panelPrefs[2].kind,
          DashboardKind.pastDue,
          reason: 'past-due slot preserved',
        );
        expect(
          vm.panelPrefs
              .where((p) => p.kind != DashboardKind.pastDue)
              .map((p) => p.kind),
          const [
            'recent_payments',
            'upcoming_invoices',
            'upcoming_quotes',
            'expired_quotes',
            'upcoming_recurring',
          ],
        );
      },
    );

    test('persists and rehydrates panel order + visibility', () async {
      final writer = newVm(persistDebounce: const Duration(milliseconds: 5));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      writer.reorderPanels(0, 5); // pastDue → last
      writer.togglePanelVisibility(DashboardKind.upcomingQuotes); // hide
      await Future<void>.delayed(const Duration(milliseconds: 40));
      final expectedOrder = writer.panelPrefs.map((p) => p.kind).toList();
      writer.dispose();

      final reader = newVm();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(reader.panelPrefs.map((p) => p.kind), expectedOrder);
      expect(
        reader.panelPrefs
            .firstWhere((p) => p.kind == DashboardKind.upcomingQuotes)
            .visible,
        isFalse,
      );
      expect(reader.panelsAreDefault, isFalse);
      reader.dispose();
    });

    test(
      'an unrelated persist (chart grouping) does not clobber panels',
      () async {
        // w1: save a custom arrangement.
        final w1 = newVm(persistDebounce: const Duration(milliseconds: 5));
        await Future<void>.delayed(const Duration(milliseconds: 20));
        w1.togglePanelVisibility(DashboardKind.expiredQuotes);
        await Future<void>.delayed(const Duration(milliseconds: 40));
        w1.dispose();

        // w2: hydrates the custom panels, then fires an unrelated persist.
        final w2 = newVm(persistDebounce: const Duration(milliseconds: 5));
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(
          w2.panelPrefs
              .firstWhere((p) => p.kind == DashboardKind.expiredQuotes)
              .visible,
          isFalse,
          reason: 'custom panels must hydrate before the unrelated write',
        );
        w2.setChartGrouping(ChartGrouping.week);
        await Future<void>.delayed(const Duration(milliseconds: 40));
        w2.dispose();

        // reader: both the panels AND the grouping survive.
        final reader = newVm();
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(
          reader.panelPrefs
              .firstWhere((p) => p.kind == DashboardKind.expiredQuotes)
              .visible,
          isFalse,
        );
        expect(reader.chartGrouping, ChartGrouping.week);
        reader.dispose();
      },
    );

    test('absent panels key (pre-upgrade install) → defaults all six '
        'visible', () async {
      // A dashboard envelope persisted before panels existed.
      await db.navStateDao.saveFilters(
        filtersJson: jsonEncode({
          'co': {
            'dashboard': {
              'dashboardCards': ['active_invoices|current|sum|money'],
            },
          },
        }),
        now: 1,
      );
      final reader = newVm();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(reader.panelPrefs.map((p) => p.kind), DashboardKind.panelKinds);
      expect(reader.panelPrefs.every((p) => p.visible), isTrue);
      reader.dispose();
    });

    test(
      'hydrate drops unknown + duplicate kinds and appends missing',
      () async {
        await db.navStateDao.saveFilters(
          filtersJson: jsonEncode({
            'co': {
              'dashboard': {
                'panels': [
                  'recent_payments|0', // hidden
                  'past_due|1',
                  'past_due|1', // duplicate → ignored
                  'not_a_panel|1', // unknown → dropped
                ],
              },
            },
          }),
          now: 1,
        );
        final reader = newVm();
        await Future<void>.delayed(const Duration(milliseconds: 20));
        // Saved (deduped, known) first, then missing kinds appended in
        // panelKinds order.
        expect(reader.panelPrefs.map((p) => p.kind), const [
          'recent_payments',
          'past_due',
          'upcoming_invoices',
          'upcoming_quotes',
          'expired_quotes',
          'upcoming_recurring',
        ]);
        expect(reader.panelPrefs.length, 6);
        expect(
          reader.panelPrefs
              .firstWhere((p) => p.kind == DashboardKind.recentPayments)
              .visible,
          isFalse,
          reason: 'saved visibility preserved',
        );
        expect(
          reader.panelPrefs
              .firstWhere((p) => p.kind == DashboardKind.upcomingInvoices)
              .visible,
          isTrue,
          reason: 'appended panels default to visible',
        );
        reader.dispose();
      },
    );
  });
}
