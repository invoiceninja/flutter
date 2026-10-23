import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_card_config.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_panel_pref.dart';
import 'package:admin/data/repositories/dashboard_repository.dart';
import 'package:admin/data/repositories/statics_repository.dart';
import 'package:admin/data/repositories/user_settings_repository.dart';
import 'package:admin/data/services/statics_service.dart';
import 'package:admin/ui/features/dashboard/view_models/dashboard_view_model.dart';

import '_fake_dashboard_repo.dart';

/// The dashboard's cross-device sync through `company_user.react_settings`:
/// the cards in React's own `dashboard_fields`, the grouping in React's
/// `dashboard_charts.default_view`, the legend and panels under
/// `flutter_dashboard`. `docs/dashboard-panels.md`.
void main() {
  late AppDatabase db;
  late FakeDashboardRepo repo;
  late UserSettingsRepository settings;
  final vms = <DashboardViewModel>[];

  const activeInvoices = DashboardCardConfig(
    field: 'active_invoices',
    period: CardPeriod.current,
    calculate: CardCalc.sum,
    format: CardFormat.money,
  );
  const overdueTasks = DashboardCardConfig(
    field: 'overdue_tasks',
    period: CardPeriod.total,
    calculate: CardCalc.count,
    format: CardFormat.none,
  );

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = FakeDashboardRepo(db);
    settings = UserSettingsRepository(db: db);
  });

  tearDown(() async {
    for (final vm in vms) {
      vm.dispose();
    }
    vms.clear();
    await db.close();
  });

  Future<void> seedReactSettings(Map<String, Object?>? blob) =>
      db.userSettingsDao.upsert(
        UserSettingsCompanion(
          companyId: const Value('co'),
          userId: const Value('u1'),
          updatedAt: const Value(0),
          reactSettingsJson: Value(blob == null ? null : jsonEncode(blob)),
        ),
      );

  Future<void> seedNavState(Map<String, Object?> dashboard) =>
      db.navStateDao.saveFilters(
        filtersJson: jsonEncode({
          'co': {'dashboard': dashboard},
        }),
        now: 1,
      );

  Future<DashboardViewModel> newVm() async {
    final vm = DashboardViewModel(
      repo: repo,
      companyId: 'co',
      navStateDao: db.navStateDao,
      statics: StaticsRepository(
        db: db,
        service: StaticsService(dummyDashboardClient),
      ),
      userSettings: settings,
      persistDebounce: const Duration(milliseconds: 5),
    );
    vms.add(vm);
    await settle();
    return vm;
  }

  Future<List<OutboxRow>> outbox() => db.select(db.outbox).get();

  test('the synced blob wins over this device\'s nav_state, and React\'s '
      'card keys (index suffix, empty count format) are read', () async {
    // Past-due leads every saved arrangement; the rest reversed.
    final reversed = [
      DashboardKind.pastDue,
      ...DashboardKind.panelKinds.reversed.where(
        (k) => k != DashboardKind.pastDue,
      ),
    ];
    await seedNavState({
      'dashboardCards': [activeInvoices.key],
    });
    await seedReactSettings({
      'dashboard_fields': ['overdue_tasks|total|count||0'],
      'preferences': {
        'dashboard_charts': {'default_view': 'week'},
      },
      'flutter_dashboard': {
        'panels': [for (final k in reversed) '$k|0'],
        'chart_series': ['expenses'],
      },
    });
    final vm = await newVm();
    expect(vm.dashboardCards, [overdueTasks]);
    expect(vm.chartGrouping, ChartGrouping.week);
    expect(vm.visibleChartSeries, {ChartSeriesId.expenses});
    expect(vm.panelPrefs.map((p) => p.kind), reversed);
    expect(vm.panelPrefs.every((p) => !p.visible), isTrue);
    // Adopting another device's choice writes nothing back.
    expect(await outbox(), isEmpty);
  });

  test('a change is written to react_settings in React\'s format', () async {
    await seedReactSettings({'show_pdf_preview': true});
    final vm = await newVm();
    vm.addCard(overdueTasks);
    vm.setChartGrouping(ChartGrouping.day);
    await settle();
    final blob = await settings.getReactSettings('co');
    expect(blob!['show_pdf_preview'], isTrue);
    expect(blob['dashboard_fields'], ['overdue_tasks|total|count||0']);
    expect((blob['preferences'] as Map)['dashboard_charts'], {
      'default_view': 'day',
    });
    expect(
      blob.containsKey('flutter_dashboard'),
      isFalse,
      reason: 'only what changed is written',
    );
    expect(await outbox(), hasLength(1));
  });

  test('a change sends only its own path — never this device\'s copy of the '
      'rest, which may be older than React\'s', () async {
    await seedReactSettings({
      'dashboard_fields': [activeInvoices.toReactKey()],
    });
    final vm = await newVm();
    vm.toggleChartSeries(ChartSeriesId.expenses);
    await settle();
    final queued = await outbox();
    expect(reactSettingsPatchOf(queued.single.payload).keys, {
      'flutter_dashboard.chart_series',
    });
  });

  test('a card React has but this build cannot read survives a card change '
      'here', () async {
    const future = 'some_future_field|current|sum|money|0';
    await seedReactSettings({
      'dashboard_fields': [activeInvoices.toReactKey(), future],
    });
    final vm = await newVm();
    expect(vm.dashboardCards, [activeInvoices]);
    vm.addCard(overdueTasks);
    await settle();
    final blob = await settings.getReactSettings('co');
    expect(blob!['dashboard_fields'], [
      activeInvoices.toReactKey(),
      overdueTasks.toReactKey(),
      future,
    ]);
  });

  test(
    'the first device to sync seeds the rest with its own choices',
    () async {
      await seedNavState({
        'dashboardCards': [activeInvoices.key],
      });
      await seedReactSettings({});
      final vm = await newVm();
      expect(vm.dashboardCards, [activeInvoices]);
      final blob = await settings.getReactSettings('co');
      expect(blob!['dashboard_fields'], [
        'active_invoices|current|sum|money|0',
      ]);
    },
  );

  test('a device with nothing customised writes nothing', () async {
    await seedReactSettings({});
    await newVm();
    expect(await outbox(), isEmpty);
    expect(await settings.getReactSettings('co'), isEmpty);
  });

  test(
    'before the blob is captured the dashboard stays device-local',
    () async {
      await seedReactSettings(null);
      final vm = await newVm();
      vm.addCard(activeInvoices);
      await settle();
      expect(vm.dashboardCards, [activeInvoices]);
      expect(await outbox(), isEmpty);
      expect(await settings.getReactSettings('co'), isNull);
    },
  );

  test('a change from another device arriving by /refresh replaces the cards '
      'live: the new one is fetched, the dropped one purged', () async {
    await seedReactSettings({
      'dashboard_fields': [activeInvoices.toReactKey()],
    });
    final vm = await newVm();
    expect(vm.dashboardCards, [activeInvoices]);
    var notified = 0;
    vm.addListener(() => notified++);

    await applyServerReactSettings(
      db,
      companyId: 'co',
      server: {
        'dashboard_fields': [overdueTasks.toReactKey()],
      },
      nowMs: 2,
    );
    await settle();
    expect(vm.dashboardCards, [overdueTasks]);
    expect(notified, greaterThan(0));
    expect(repo.refreshedCardKeys, contains(overdueTasks.key));
    expect(repo.droppedCardKeys, contains(activeInvoices.key));
  });

  test('a capture landing before a local change is written does not revert '
      'it', () async {
    await seedReactSettings({});
    final vm = await newVm();
    vm.addCard(activeInvoices);
    // The /refresh still holds the server's pre-change blob.
    await applyServerReactSettings(
      db,
      companyId: 'co',
      server: {'dark_mode': true},
      nowMs: 2,
    );
    await settle();
    expect(vm.dashboardCards, [activeInvoices]);
    final blob = await settings.getReactSettings('co');
    expect(blob!['dark_mode'], isTrue);
    expect(blob['dashboard_fields'], [activeInvoices.toReactKey()]);
  });

  test('card keys round-trip through React\'s format', () {
    for (final c in [activeInvoices, overdueTasks]) {
      expect(DashboardCardConfig.fromReactKey(c.toReactKey()), c);
    }
    expect(
      DashboardCardConfig.fromReactKey('nope|current|sum|money|0'),
      isNull,
    );
    expect(
      DashboardCardConfig.fromReactKey('logged_tasks|current|sum|time|3'),
      const DashboardCardConfig(
        field: 'logged_tasks',
        period: CardPeriod.current,
        calculate: CardCalc.sum,
        format: CardFormat.time,
      ),
    );
    expect(
      DashboardPanelPref.tryParse('${DashboardKind.pastDue}|1'),
      const DashboardPanelPref(kind: DashboardKind.pastDue, visible: true),
    );
  });
}

/// Lets `_init`, the Drift watch and the 5 ms persist debounce run.
Future<void> settle() async {
  for (var i = 0; i < 4; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}
