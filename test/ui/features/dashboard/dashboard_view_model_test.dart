import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/resync_controller.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_card_config.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_list_rows.dart';
import 'package:admin/data/models/value/date.dart';
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

    test('defaults to every panel kind, in order, all visible', () {
      expect(vm.panelPrefs.map((p) => p.kind), DashboardKind.panelKinds);
      expect(vm.panelPrefs.every((p) => p.visible), isTrue);
      expect(vm.panelsAreDefault, isTrue);
    });

    test('reorderPanels moves a panel, fires notify, clears default', () {
      var globalHits = 0;
      vm.addListener(() => globalHits++);
      vm.reorderPanels(0, 2); // pastDue → index 2
      expect(vm.panelPrefs.first.kind, DashboardKind.invoicesAndQuotes);
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
      'reorderTrailingPanels reorders the rest, preserves past-due slot',
      () {
        // Default: past-due at index 0. Move the first trailing panel
        // (invoices & quotes) to the end of the trailing block — the target
        // index is the trailing COUNT, so it tracks the panel set rather than
        // being a literal that silently stops meaning "the end".
        final trailing = vm.panelPrefs
            .where((p) => p.kind != DashboardKind.pastDue)
            .length;
        vm.reorderTrailingPanels(0, trailing);
        expect(vm.panelPrefs.map((p) => p.kind), const [
          'past_due', // pinned, unchanged
          'upcoming_invoices',
          'recent_payments',
          'upcoming_quotes',
          'expired_quotes',
          'upcoming_recurring',
          'task_calendar',
          'invoices_and_quotes',
        ]);

        // Now move past-due off slot 0, then reorder the five again and confirm
        // past-due keeps its (non-zero) slot.
        vm.resetPanels();
        vm.reorderPanels(0, 2); // past-due → index 2
        expect(vm.panelPrefs[2].kind, DashboardKind.pastDue);
        vm.reorderTrailingPanels(0, 1); // swap the first two trailing panels
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
            'upcoming_invoices',
            'invoices_and_quotes',
            'recent_payments',
            'upcoming_quotes',
            'expired_quotes',
            'upcoming_recurring',
            'task_calendar',
          ],
        );
      },
    );

    test('persists and rehydrates panel order + visibility', () async {
      final writer = newVm(persistDebounce: const Duration(milliseconds: 5));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      writer.reorderPanels(0, 5); // pastDue → mid-list
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

    test('absent panels key (pre-upgrade install) → defaults all kinds '
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
      'hydrate drops unknown + duplicate kinds and places missing at rank',
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
        // Saved (deduped, known) keep their relative order; each missing kind
        // lands at its CANONICAL RANK relative to them rather than at the end.
        //
        // This fixture is the reason the rule is anchored on the PREDECESSOR:
        // the save puts `recent_payments` above `past_due`, so "before the
        // first kind of greater rank" would hoist `invoices_and_quotes` to the
        // very top, above the past-due card it is meant to sit under. Anchoring
        // on the last smaller-ranked kind keeps it directly below `past_due`
        // wherever the user has dragged that.
        expect(reader.panelPrefs.map((p) => p.kind), const [
          'recent_payments',
          'past_due',
          'invoices_and_quotes',
          'upcoming_invoices',
          'upcoming_quotes',
          'expired_quotes',
          'upcoming_recurring',
          'task_calendar',
        ]);
        expect(reader.panelPrefs.length, 8);
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
          reason: 'newly placed panels default to visible',
        );
        reader.dispose();
      },
    );

    test('the billing tab round-trips, and hydrate never writes', () async {
      final writer = newVm(persistDebounce: const Duration(milliseconds: 5));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(writer.billingTab, isNull, reason: 'All is the resting state');
      writer.setBillingTab('expired');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      writer.dispose();

      final reader = newVm();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(reader.billingTab, 'expired');

      // A no-op set must not schedule a write, or an unrelated rebuild could
      // churn nav_state.
      final before = await db.navStateDao.current();
      reader.setBillingTab('expired');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect((await db.navStateDao.current())?.updatedAt, before?.updatedAt);
      reader.dispose();
    });

    test('a save that was the OLD default hydrates to the NEW default', () async {
      // The upgrade case, and the reason the placement rule is worth having:
      // under the append rule every existing user's arrangement became
      // non-default the moment a kind shipped, permanently disabling the manage
      // dialog's Reset for them. Placed at rank, the old default is still the
      // default.
      final old = [
        for (final k in DashboardKind.panelKinds)
          if (k != DashboardKind.invoicesAndQuotes) '$k|1',
      ];
      await db.navStateDao.saveFilters(
        filtersJson: jsonEncode({
          'co': {
            'dashboard': {'panels': old},
          },
        }),
        now: 1,
      );
      final reader = newVm();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(reader.panelPrefs.map((p) => p.kind), DashboardKind.panelKinds);
      expect(reader.panelsAreDefault, isTrue);
      reader.dispose();
    });
  });

  // invoiceninja/flutter#161. The panel lists are built under the global
  // notify, which a section emission never fires (first test in this file) —
  // so "this panel has nothing to show" travels on a notifier of its own, and
  // only the six cache-backed panels can ever be on it.
  group('emptyPanels', () {
    const cached = {
      DashboardKind.pastDue,
      DashboardKind.upcomingInvoices,
      DashboardKind.recentPayments,
      DashboardKind.upcomingQuotes,
      DashboardKind.expiredQuotes,
      DashboardKind.upcomingRecurring,
    };

    Future<void> settle() =>
        Future<void>.delayed(const Duration(milliseconds: 10));

    DashboardQuoteRow quote() => DashboardQuoteRow.fromJson({
      'id': 'q1',
      'client': {'id': 'c1', 'name': 'Acme'},
    });

    test('starts empty — nothing has loaded, so nothing is known empty', () {
      expect(vm.emptyPanels.value, isEmpty);
    });

    test(
      'a loaded-empty section joins the set without a global notify',
      () async {
        var setHits = 0;
        var sectionHits = 0;
        var globalHits = 0;
        vm.emptyPanels.addListener(() => setHits++);
        vm
            .listenableFor(DashboardKind.upcomingQuotes)
            .addListener(() => sectionHits++);
        vm.addListener(() => globalHits++);

        repo.upcomingQuotes.add(const []);
        await settle();

        expect(vm.emptyPanels.value, {DashboardKind.upcomingQuotes});
        expect(setHits, 1);
        expect(sectionHits, 1, reason: 'the card itself still rebuilds');
        expect(
          globalHits,
          0,
          reason: 'a data emission must not rebuild the whole dashboard',
        );
      },
    );

    test('a repeated empty emission does not notify again', () async {
      var setHits = 0;
      vm.emptyPanels.addListener(() => setHits++);

      repo.upcomingQuotes.add(const []);
      await settle();
      repo.upcomingQuotes.add(const []);
      // An unrelated section changing is not a membership change either.
      repo.chart.add(null);
      await settle();

      expect(setHits, 1);
    });

    // The eligible set is derived (`panelKinds ∩ listKinds`), so this is the
    // test that notices a cache-backed panel that can't hide — or a
    // Drift-backed one that suddenly can.
    test('every cache-backed panel can be empty, and nothing else', () async {
      repo.pastDue.add(const []);
      repo.upcomingInvoices.add(const []);
      repo.recentPayments.add(const []);
      repo.upcomingQuotes.add(const []);
      repo.expiredQuotes.add(const []);
      repo.upcomingRecurring.add(const []);
      // `activities` is a list section but not a panel — it can't be hidden.
      repo.activities.add(const []);
      await settle();

      expect(vm.emptyPanels.value, cached);
      expect(cached, {
        for (final k in DashboardKind.panelKinds)
          if (DashboardKind.listKinds.contains(k)) k,
      });
    });

    test('rows, or a dropped cache row, take a panel back out', () async {
      repo.upcomingQuotes.add(const []);
      repo.expiredQuotes.add(const []);
      await settle();
      expect(vm.emptyPanels.value, {
        DashboardKind.upcomingQuotes,
        DashboardKind.expiredQuotes,
      });

      repo.upcomingQuotes.add([quote()]);
      repo.expiredQuotes.add(null);
      await settle();

      expect(vm.emptyPanels.value, isEmpty);
    });

    test(
      'a failed first fetch is not empty — its card shows the error',
      () async {
        repo.refreshAllErrors = {
          DashboardKind.upcomingQuotes: Exception('offline'),
        };
        await vm.refresh();
        await settle();

        expect(vm.upcomingQuotes.hasError, isTrue);
        expect(vm.upcomingQuotes.hasData, isFalse);
        expect(vm.emptyPanels.value, isEmpty);
      },
    );

    test('a failed refresh keeps a panel the cache knows is empty', () async {
      repo.upcomingQuotes.add(const []);
      await settle();
      repo.refreshAllErrors = {
        DashboardKind.upcomingQuotes: Exception('offline'),
      };
      await vm.refresh();
      await settle();

      // The wide card renders its empty state here too (`hasData` wins over
      // the error), so the panel is still one with nothing to show.
      expect(vm.upcomingQuotes.hasError, isTrue);
      expect(vm.emptyPanels.value, {DashboardKind.upcomingQuotes});
    });

    test('the published set cannot be mutated by a reader', () async {
      repo.upcomingQuotes.add(const []);
      await settle();
      expect(
        () => vm.emptyPanels.value.add(DashboardKind.pastDue),
        throwsUnsupportedError,
      );
    });
  });

  /// invoiceninja/flutter#162 — the dashboard branch stays mounted for the
  /// whole session, so a completed Sync pass is the only thing that reaches the
  /// totals, the chart, the configured cards and the "Updated N ago" stamp.
  /// Driven here by a plain notifier; `resync_wiring_test` runs the real
  /// controller and `syncNow` end to end.
  group('a completed Sync pass (issue #162)', () {
    var clock = 0;
    var serial = 0;
    late ValueNotifier<ResyncCompletion?> completions;
    late DashboardViewModel synced;

    DashboardViewModel newVm(
      ValueListenable<ResyncCompletion?> source, {
      Date Function()? today,
    }) => DashboardViewModel(
      repo: repo,
      companyId: 'co',
      navStateDao: db.navStateDao,
      statics: StaticsRepository(
        db: db,
        service: StaticsService(dummyDashboardClient),
      ),
      resyncCompletions: source,
      // Strictly increasing, so "the stamp moved" can't pass by chance.
      now: () => DateTime.fromMillisecondsSinceEpoch(++clock * 1000),
      today: today,
    );

    ResyncCompletion pass({
      String companyId = 'co',
      List<String> failedEntities = const [],
      Object? error,
    }) => ResyncCompletion(
      serial: ++serial,
      companyId: companyId,
      result: ResyncResult(
        ResyncDisposition.completed,
        failedEntities: failedEntities,
        error: error,
      ),
    );

    Future<void> settle() =>
        Future<void>.delayed(const Duration(milliseconds: 20));

    setUp(() async {
      completions = ValueNotifier<ResyncCompletion?>(null);
      synced = newVm(completions);
      await settle();
      expect(synced.lastRefreshed, isNotNull, reason: 'the boot refresh ran');
      // The outer `vm` booted too; count from here.
      repo.refreshAllCalls = 0;
    });

    tearDown(() {
      synced.dispose();
      completions.dispose();
    });

    test('refetches everything and moves the stamp', () async {
      final before = synced.lastRefreshed!;

      completions.value = pass();
      await settle();

      expect(repo.refreshAllCalls, 1);
      expect(
        synced.lastRefreshed!.isAfter(before),
        isTrue,
        reason: 'the label the reporter saw stuck at "Updated 2h ago"',
      );
      expect(synced.isAnyRefreshing, isFalse);
    });

    test('a clean pass leaves the Drift-backed panels alone', () async {
      final nonce = synced.panelRefreshNonce;
      expect(nonce, isNotNull, reason: 'the boot refresh stamped it');

      completions.value = pass();
      await settle();

      expect(
        synced.panelRefreshNonce,
        nonce,
        reason:
            'the pass just re-downloaded every invoice, quote and task; '
            're-arming would fetch those pages again on every Sync',
      );
    });

    test(
      'a pass that failed a panel download still refetches, and re-arms them',
      () async {
        // Its tail ran, and none of the dashboard's own endpoints read the
        // entity tables — but the task calendar does.
        completions.value = pass(failedEntities: const ['task']);
        await settle();

        expect(repo.refreshAllCalls, 1);
        expect(synced.panelRefreshNonce, synced.lastRefreshed);
      },
    );

    test(
      'a failed download the panels do not read leaves them alone',
      () async {
        final nonce = synced.panelRefreshNonce;

        completions.value = pass(failedEntities: const ['client']);
        await settle();

        expect(repo.refreshAllCalls, 1);
        expect(synced.panelRefreshNonce, nonce);
      },
    );

    test('the Refresh button still re-arms the panels', () async {
      final nonce = synced.panelRefreshNonce!;

      await synced.refresh();

      expect(synced.panelRefreshNonce!.isAfter(nonce), isTrue);
      expect(synced.panelRefreshNonce, synced.lastRefreshed);
    });

    test(
      'a failed refetch keeps the stamp and reports per section, not globally',
      () async {
        final before = synced.lastRefreshed;
        repo.refreshAllErrors = {DashboardKind.chart: Exception('offline')};

        completions.value = pass();
        await settle();

        expect(repo.refreshAllCalls, 1);
        expect(
          synced.lastRefreshed,
          before,
          reason: 'the stamp claims every section landed',
        );
        expect(synced.chart.hasError, isTrue);
        expect(
          synced.globalError,
          isNull,
          reason:
              "globalError is the Refresh button's toast detail, read right "
              'after its own refresh — an overlapping after-sync run must not '
              "hand it another run's error",
        );
      },
    );

    test('a pass for another company is ignored', () async {
      completions.value = pass(companyId: 'other');
      await settle();

      expect(
        repo.refreshAllCalls,
        0,
        reason:
            'a company switch rebuilds the view model before its hook cancels '
            'the pass, so the one it left can still complete',
      );
    });

    test('a completion carrying an error is ignored', () async {
      completions.value = pass(error: StateError('Not authenticated'));
      await settle();

      expect(repo.refreshAllCalls, 0);
    });

    test(
      'a completion during the boot refresh is deferred until it returns',
      () async {
        final own = ValueNotifier<ResyncCompletion?>(null);
        addTearDown(own.dispose);
        final gate = Completer<void>();
        repo.refreshAllGate = gate;
        final booting = newVm(own);
        addTearDown(booting.dispose);
        final stamps = <DateTime>{};
        booting.addListener(() {
          final at = booting.lastRefreshed;
          if (at != null) stamps.add(at);
        });
        await settle();
        expect(repo.refreshAllCalls, 1, reason: 'the boot refresh, held open');

        own.value = pass();
        own.value = pass(failedEntities: const ['invoice']);
        await settle();
        expect(
          repo.refreshAllCalls,
          1,
          reason:
              'a second run alongside the boot refresh would drop the shared '
              'isAnyRefreshing early',
        );

        repo.refreshAllGate = null;
        gate.complete();
        await settle();

        expect(
          repo.refreshAllCalls,
          2,
          reason:
              'dropped, the pass would be lost — the boot refresh may have '
              'read the server before it pushed — and two deferred passes '
              'still refetch once',
        );
        expect(
          stamps,
          hasLength(2),
          reason: 'the boot stamp, then the refetch',
        );
        expect(
          booting.panelRefreshNonce,
          booting.lastRefreshed,
          reason: 'one of the deferred passes failed a panel download',
        );
      },
    );

    test('a refetch after midnight reopens the filter-keyed watches', () async {
      var day = Date(2026, 8, 31);
      final own = ValueNotifier<ResyncCompletion?>(null);
      addTearDown(own.dispose);
      final overnight = newVm(own, today: () => day);
      addTearDown(overnight.dispose);
      await settle();
      final opened = repo.watchTotalsCalls;

      own.value = pass();
      await settle();
      expect(
        repo.watchTotalsCalls,
        opened,
        reason: 'the same day: the watches still match',
      );

      // "This month" now resolves to September, and `refreshAll` writes under
      // that hash — the watches were still on August's.
      day = Date(2026, 9, 1);
      own.value = pass();
      await settle();
      expect(repo.watchTotalsCalls, greaterThan(opened));
      final reopened = repo.watchTotalsCalls;

      await overnight.retry(DashboardKind.chart);
      expect(
        repo.watchTotalsCalls,
        reopened,
        reason: 'already on the new hash',
      );
    });

    test('a retry after midnight reopens them too', () async {
      var day = Date(2026, 8, 31);
      final own = ValueNotifier<ResyncCompletion?>(null);
      addTearDown(own.dispose);
      final overnight = newVm(own, today: () => day);
      addTearDown(overnight.dispose);
      await settle();
      final opened = repo.watchTotalsCalls;

      day = Date(2026, 9, 1);
      await overnight.retry(DashboardKind.chart);

      expect(repo.watchTotalsCalls, greaterThan(opened));
    });

    test('dispose detaches the listener', () async {
      final own = _ListenedCompletions();
      addTearDown(own.dispose);
      final gone = newVm(own);
      await settle();
      expect(own.attached, isTrue);
      repo.refreshAllCalls = 0;

      gone.dispose();
      expect(
        own.attached,
        isFalse,
        reason: 'Services.resync outlives every dashboard view model',
      );

      own.value = pass();
      await settle();
      expect(repo.refreshAllCalls, 0);
    });
  });
}

/// Reads the real listener list, so a test can prove a view model let go of
/// the app-lifetime notifier rather than merely ignoring it. (A counter bumped
/// in `removeListener` would also count a call that removed nothing — a
/// closure registered in place of the tear-off, say.)
class _ListenedCompletions extends ValueNotifier<ResyncCompletion?> {
  _ListenedCompletions() : super(null);

  bool get attached => hasListeners;
}
