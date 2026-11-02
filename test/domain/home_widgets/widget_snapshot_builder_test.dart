@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:admin/data/models/domain/dashboard/dashboard_list_rows.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_totals.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/models/domain/time_entry.dart';
import 'package:admin/data/models/value/company_format_settings.dart';
import 'package:admin/data/models/value/currency.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/models/value/datetime_format.dart';
import 'package:admin/domain/home_widgets/widget_snapshot.dart';
import 'package:admin/domain/home_widgets/widget_snapshot_builder.dart';
import 'package:admin/utils/formatting.dart';

/// The widget snapshot builder: what the home-screen widgets will be told.
///
/// The last group also writes `test/fixtures/home_widgets/*.json`, the golden
/// files the Swift and Kotlin decoders are tested against — so a schema change
/// here shows up as a diff in those files and fails the native tests until
/// they are updated too. Regenerate with `UPDATE_WIDGET_FIXTURES=1`.

/// Mid-month and mid-day, far from any period or day edge (CLAUDE.md § Strict
/// rules — CI runs in UTC).
const _today = Date(2026, 10, 14);
final _fetched = DateTime.utc(2026, 10, 14, 11, 30);
final _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

Currency _usd() => Currency(
  id: '1',
  name: 'US Dollar',
  code: 'USD',
  symbol: r'$',
  precision: 2,
  thousandSeparator: ',',
  decimalSeparator: '.',
  swapCurrencySymbol: false,
  exchangeRate: Decimal.one,
);

Formatter _formatter() => Formatter(
  settings: CompanyFormatSettings.fallback.copyWith(currencyId: '1'),
  currencies: {'1': _usd()},
  countries: const {},
  dateFormats: const {'5': DatetimeFormat(id: '5', format: 'MMM d, yyyy')},
);

DashboardTotals _totals({
  String invoiced = '0',
  String paid = '0',
  String expenses = '0',
  String outstanding = '0',
  int outstandingCount = 0,
}) => DashboardTotals.fromJson({
  'currencies': {'1': 'USD'},
  '1': {
    'invoices': {'invoiced_amount': invoiced, 'code': 'USD'},
    'revenue': {'paid_to_date': paid, 'code': 'USD'},
    'outstanding': {
      'amount': outstanding,
      'outstanding_count': outstandingCount,
      'code': 'USD',
    },
    'expenses': {'amount': expenses, 'code': 'USD'},
  },
});

DashboardInvoiceRow _inv(
  String id, {
  Date? due,
  String balance = '100',
  String? partial,
  Date? partialDue,
}) => DashboardInvoiceRow(
  id: id,
  number: 'INV-$id',
  clientId: 'c1',
  clientName: 'Acme',
  dueDate: due,
  balance: Decimal.parse(balance),
  amount: Decimal.parse(balance),
  statusId: 2,
  currencyId: '',
  partial: partial == null ? null : Decimal.parse(partial),
  partialDueDate: partialDue,
);

Task _task(String id, List<TimeEntry> log, {String clientId = 'c1'}) => Task(
  id: id,
  number: id,
  description: 'Task $id',
  rate: Decimal.zero,
  invoiceId: '',
  clientId: clientId,
  projectId: '',
  statusId: 's1',
  statusOrder: 0,
  assignedUserId: '',
  timeLog: log,
  customValue1: '',
  customValue2: '',
  customValue3: '',
  customValue4: '',
  updatedAt: _epoch,
  createdAt: _epoch,
  archivedAt: null,
  isDeleted: false,
);

String _tr(String key, [Map<String, String>? params]) {
  var s = 'T:$key';
  params?.forEach((k, v) => s = '$s|$k=$v');
  return s;
}

WidgetCompanyInput _company({
  bool canViewDashboard = true,
  bool showExpenses = true,
  DashboardTotals? outstanding,
  Map<WidgetPeriod, WidgetPeriodInput> periods = const {},
  List<DashboardInvoiceRow>? pastDue,
  List<DashboardInvoiceRow>? upcoming,
  List<Task> running = const [],
  List<Task> recent = const [],
}) => WidgetCompanyInput(
  id: 'co1',
  name: 'Acme Studio',
  accent: '#2f6fed',
  canViewDashboard: canViewDashboard,
  showExpenses: showExpenses,
  formatter: _formatter(),
  baseCurrencyId: '1',
  outstanding: outstanding,
  outstandingFetchedAt: outstanding == null ? null : _fetched,
  periods: periods,
  pastDue: pastDue,
  upcoming: upcoming,
  listsFetchedAt: pastDue == null ? null : _fetched,
  runningTasks: running,
  recentTasks: recent,
  clientNames: const {'c1': 'Acme'},
  canEditTask: (t) => t.id != 'teammate',
);

WidgetSnapshot _build(List<WidgetCompanyInput> companies) =>
    buildWidgetSnapshot(
      userId: 'u1',
      activeCompanyId: 'co1',
      appLock: false,
      rtl: false,
      tr: _tr,
      companies: companies,
      today: _today,
      // Inside the 11:00–13:00 UTC band: the same local day from UTC−11 to
      // UTC+10, so the "Today" total is the same on any dev machine.
      now: DateTime.utc(2026, 10, 14, 12),
    );

Map<String, Object?> _json(WidgetSnapshot s) =>
    jsonDecode(jsonEncode(s.toJson(writtenAt: _fetched)))
        as Map<String, Object?>;

Map<String, Object?> _figures(WidgetSnapshot s) =>
    ((_json(s)['companies']! as List).single as Map)['figures']
        as Map<String, Object?>;

final _thisMonth = WidgetPeriodInput(
  start: const Date(2026, 10, 1),
  end: const Date(2026, 10, 31),
  current: _totals(invoiced: '12000', paid: '8000', expenses: '900'),
  previous: _totals(invoiced: '10000', paid: '10000', expenses: '1000'),
  fetchedAt: _fetched,
);

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  group('figures', () {
    test('an unknown figure is absent, never zero', () {
      final s = _build([_company()]);
      expect(
        (_json(s)['companies']! as List).single,
        isNot(contains('figures')),
      );
    });

    test('no dashboard permission writes no figures at all', () {
      final s = _build([
        _company(
          canViewDashboard: false,
          outstanding: _totals(outstanding: '5', outstandingCount: 1),
        ),
      ]);
      final company = (_json(s)['companies']! as List).single as Map;
      expect(company['canViewDashboard'], isFalse);
      expect(company, isNot(contains('figures')));
    });

    test('outstanding carries a full and a compact amount', () {
      final s = _build([
        _company(
          outstanding: _totals(outstanding: '12431.50', outstandingCount: 4),
        ),
      ]);
      final out = _figures(s)['outstanding']! as Map;
      expect((out['amount']! as Map)['text'], r'$12,431.50');
      expect((out['amount']! as Map)['compact'], isNot(r'$12,431.50'));
      expect(out['unpaidCount'], 4);
      expect(out, isNot(contains('pastDueCount')), reason: 'list not loaded');
    });

    test('the past-due amount is only written when proven', () {
      final whole = _build([
        _company(
          outstanding: _totals(outstanding: '300', outstandingCount: 3),
          pastDue: [
            _inv('1', due: const Date(2026, 10, 2)),
            _inv('2', due: const Date(2026, 10, 9), balance: '50'),
          ],
          upcoming: const [],
        ),
      ]);
      final out = _figures(whole)['outstanding']! as Map;
      expect(out['pastDueCount'], 2);
      expect(out['pastDueExact'], isTrue);
      expect((out['pastDueAmount']! as Map)['text'], r'$150.00');
      // $150 of $300: the past-due bar's half.
      expect(out['pastDueShare'], 0.5);

      // A full page with no paginator total may hold more than it shows.
      final page = [
        for (var i = 0; i < 50; i++) _inv('$i', due: const Date(2026, 10, 2)),
      ];
      final partial = _build([
        _company(
          outstanding: _totals(outstanding: '300', outstandingCount: 3),
          pastDue: page,
          upcoming: const [],
        ),
      ]);
      final out2 = _figures(partial)['outstanding']! as Map;
      expect(out2['pastDueExact'], isFalse);
      expect(out2, isNot(contains('pastDueAmount')));
      expect(out2, isNot(contains('pastDueShare')), reason: 'not proven');
    });

    test('a period names itself and trends against the previous one', () {
      final s = _build([
        _company(periods: {WidgetPeriod.thisMonth: _thisMonth}),
      ]);
      final p =
          (_figures(s)['periods']! as Map)['this_month']!
              as Map<String, Object?>;
      expect(p['label'], 'T:this_month');
      expect(p['name'], 'October');
      expect(p['endsOn'], '2026-10-31');
      expect((p['invoices']! as Map)['deltaPct'], 20);
      expect((p['invoices']! as Map)['good'], isTrue);
      expect((p['payments']! as Map)['deltaPct'], -20);
      expect((p['payments']! as Map)['good'], isFalse);
      // Spending less is the good direction.
      expect((p['expenses']! as Map)['deltaPct'], -10);
      expect((p['expenses']! as Map)['good'], isTrue);
    });

    test('expenses are left out where the app hides them', () {
      final s = _build([
        _company(
          showExpenses: false,
          periods: {WidgetPeriod.thisMonth: _thisMonth},
        ),
      ]);
      final p = (_figures(s)['periods']! as Map)['this_month']! as Map;
      expect(p, isNot(contains('expenses')));
    });
  });

  group('widgetTrend', () {
    test('is hidden in the first days of a period', () {
      expect(
        widgetTrend(
          Decimal.parse('200'),
          Decimal.parse('100'),
          elapsedDays: kWidgetTrendMinDays - 1,
          goodWhenUp: true,
        ),
        isNull,
      );
    });

    test('is hidden with nothing to compare against', () {
      expect(
        widgetTrend(
          Decimal.parse('200'),
          Decimal.zero,
          elapsedDays: 14,
          goodWhenUp: true,
        ),
        isNull,
      );
    });

    test('is capped', () {
      final t = widgetTrend(
        Decimal.parse('100000'),
        Decimal.one,
        elapsedDays: 14,
        goodWhenUp: true,
      );
      expect(t?.pct, kWidgetTrendMaxPct);
    });
  });

  group('widgetPeriodName', () {
    test('a fiscal year straddling two calendar years names both', () {
      expect(
        widgetPeriodName(
          WidgetPeriod.thisYear,
          start: const Date(2026, 4, 1),
          end: const Date(2027, 3, 31),
          localeTag: 'en',
          label: 'This Year',
        ),
        '2026–27',
      );
    });

    test('a rolling window has no name but its label', () {
      expect(
        widgetPeriodName(
          WidgetPeriod.last30Days,
          start: const Date(2026, 9, 15),
          end: _today,
          localeTag: 'en',
          label: 'Last 30 Days',
        ),
        'Last 30 Days',
      );
    });
  });

  group('needs attention', () {
    test('rows carry the date lateness counts from, deposit included', () {
      final s = _build([
        _company(
          pastDue: [
            _inv('1', due: const Date(2026, 10, 2)),
            // Only the deposit is late; the invoice itself is due next month.
            _inv(
              '2',
              due: const Date(2026, 11, 30),
              partial: '40',
              partialDue: const Date(2026, 10, 10),
            ),
          ],
          upcoming: [_inv('3', due: const Date(2026, 10, 17))],
        ),
      ]);
      final a = _figures(s)['attention']! as Map;
      final late = a['pastDue']! as List;
      expect((late[0] as Map)['lateSince'], '2026-10-02');
      expect((late[1] as Map)['lateSince'], '2026-10-10');
      expect(((late[1] as Map)['amount']! as Map)['text'], r'$40.00');
      final soon = a['dueSoon']! as List;
      expect((soon.single as Map)['dueOn'], '2026-10-17');
    });
  });

  group('timers', () {
    test('a running timer carries its start and the time before it', () {
      final s = _build([
        _company(
          running: [
            _task('t1', [
              TimeEntry(
                start: DateTime.utc(2026, 10, 14, 8),
                stop: DateTime.utc(2026, 10, 14, 9),
              ),
              TimeEntry(start: DateTime.utc(2026, 10, 14, 10), stop: null),
            ]),
          ],
        ),
      ]);
      final timer =
          ((_json(s)['companies']! as List).single as Map)['timers'] as List;
      final t = timer.single as Map;
      expect(t['taskId'], 't1');
      expect(t['client'], 'Acme');
      expect(
        t['runningSince'],
        DateTime.utc(2026, 10, 14, 10).millisecondsSinceEpoch,
      );
      expect(t['priorSeconds'], 3600);
      expect(t['canStop'], isTrue);
    });

    test("a teammate's timer is listed without a Stop", () {
      final s = _build([
        _company(
          running: [
            _task('teammate', [
              TimeEntry(start: DateTime.utc(2026, 10, 14, 10), stop: null),
            ]),
          ],
        ),
      ]);
      final timers =
          ((_json(s)['companies']! as List).single as Map)['timers'] as List;
      expect((timers.single as Map)['canStop'], isFalse);
    });

    test('at most three, and a stopped task is never one', () {
      final running = [
        for (var i = 0; i < 5; i++)
          _task('r$i', [
            TimeEntry(start: DateTime.utc(2026, 10, 14, 10), stop: null),
          ]),
      ];
      final stopped = _task('s', [
        TimeEntry(
          start: DateTime.utc(2026, 10, 14, 8),
          stop: DateTime.utc(2026, 10, 14, 9),
        ),
      ]);
      final s = _build([
        _company(running: [stopped, ...running]),
      ]);
      final timers =
          ((_json(s)['companies']! as List).single as Map)['timers'] as List;
      expect(timers, hasLength(kWidgetMaxTimers));
      expect(timers.map((t) => (t as Map)['taskId']), isNot(contains('s')));
      // The rest are counted, so the widget can say "+2 running".
      expect(
        ((_json(s)['companies']! as List).single as Map)['runningCount'],
        5,
      );
    });
  });

  group('today', () {
    test('counts finished work inside today, once per task — not a running '
        'entry (the widget ticks that), not yesterday, not a booking', () {
      final today = TimeEntry(
        start: DateTime.utc(2026, 10, 14, 11),
        stop: DateTime.utc(2026, 10, 14, 11, 30),
      );
      final running = _task('r', [
        today,
        TimeEntry(start: DateTime.utc(2026, 10, 14, 11, 40), stop: null),
      ]);
      final recent = _task('d', [
        TimeEntry(
          start: DateTime.utc(2026, 10, 12, 11),
          stop: DateTime.utc(2026, 10, 12, 12),
        ),
        // Booked for later today: not worked.
        TimeEntry(
          start: DateTime.utc(2026, 10, 14, 12, 30),
          stop: DateTime.utc(2026, 10, 14, 13),
        ),
      ]);
      final s = _build([
        _company(running: [running], recent: [running, recent]),
      ]);
      final company = (_json(s)['companies']! as List).single as Map;
      expect(company['today'], {'date': '2026-10-14', 'doneSeconds': 1800});
    });

    test('absent when no task rows were read', () {
      final company =
          (_json(_build([_company()]))['companies']! as List).single as Map;
      expect(company, isNot(contains('today')));
    });
  });

  group('payload', () {
    test('comparable() ignores the write time', () {
      final s = _build([_company()]);
      expect(
        jsonEncode(s.comparable()),
        jsonEncode(
          _build([
            _company(),
          ]).toJson(writtenAt: DateTime.fromMillisecondsSinceEpoch(0)),
        ),
      );
    });

    test('signed out keeps the strings and nothing else', () {
      final j = const WidgetSnapshot.signedOut(
        strings: {'widget_sign_in': 'Sign in'},
      ).toJson(writtenAt: _fetched);
      expect(j['signedIn'], isFalse);
      expect(j, isNot(contains('userId')));
      expect(j['companies'], isEmpty);
      expect(j['strings'], {'widget_sign_in': 'Sign in'});
    });
  });

  group('golden fixtures (decoded by the Swift and Kotlin tests)', () {
    WidgetSnapshot full() => _build([
      _company(
        outstanding: _totals(outstanding: '12431.50', outstandingCount: 4),
        periods: {WidgetPeriod.thisMonth: _thisMonth},
        pastDue: [_inv('1', due: const Date(2026, 10, 2))],
        upcoming: [_inv('3', due: const Date(2026, 10, 17))],
        running: [
          _task('t1', [
            TimeEntry(start: DateTime.utc(2026, 10, 14, 10), stop: null),
          ]),
        ],
        recent: [
          _task('t2', [
            TimeEntry(
              start: DateTime.utc(2026, 10, 13, 9),
              stop: DateTime.utc(2026, 10, 13, 11),
            ),
          ]),
        ],
      ),
    ]);
    Map<String, Map<String, Object?>> fixtures() => {
      'v1_full.json': full().toJson(writtenAt: _fetched),
      'v1_signed_out.json': WidgetSnapshot.signedOut(
        strings: widgetStrings(_tr),
      ).toJson(writtenAt: _fetched),
      // A newer schema than any shipped widget knows: it must say "Update",
      // not crash or guess.
      'v99_future.json': {
        ...full().toJson(writtenAt: _fetched),
        'v': 99,
        'somethingNew': {'a': 1},
      },
    };

    for (final name in const [
      'v1_full.json',
      'v1_signed_out.json',
      'v99_future.json',
    ]) {
      test(name, () {
        final json = fixtures()[name]!;
        final file = File('test/fixtures/home_widgets/$name');
        final text = '${const JsonEncoder.withIndent('  ').convert(json)}\n';
        if (Platform.environment['UPDATE_WIDGET_FIXTURES'] == '1' ||
            !file.existsSync()) {
          file
            ..createSync(recursive: true)
            ..writeAsStringSync(text);
        }
        expect(
          file.readAsStringSync(),
          text,
          reason:
              'The snapshot schema changed. Regenerate with '
              'UPDATE_WIDGET_FIXTURES=1, then update the Swift and Kotlin '
              'decoders and their tests.',
        );
      });
    }
  });
}
