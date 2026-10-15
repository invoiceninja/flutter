import 'package:flutter_test/flutter_test.dart';

import '../../tools/perf/perf_compare.dart';

/// The rules that decide whether the Performance workflow raises an
/// alert (docs/performance-tracking.md). A rule that is wrong here either
/// pages someone over runner noise — and the alerts stop being read — or
/// stays quiet over a real slowdown, which is the thing the suite exists for.
void main() {
  final now = DateTime.utc(2026, 10, 15, 4);

  PerfBudgets budgets(
    Map<String, Map<String, Object>> benchmarks, {
    double reference = 10,
  }) => PerfBudgets.fromJson({
    'reference': {'machine': 'ref', 'calibrationMs': reference},
    'defaults': {'regression': 0.25, 'drift': 0.4, 'minDeltaMs': 0.1},
    'benchmarks': benchmarks,
  });

  PerfRun run(
    Map<String, double> medians, {
    List<double> calibration = const [10, 10, 10],
    String sha = 'cur',
    DateTime? date,
    String filter = '',
  }) => PerfRun(
    sha: sha,
    ref: 'main',
    date: date ?? now,
    filter: filter,
    calibrationSamples: calibration,
    benchmarks: {
      for (final e in medians.entries)
        e.key: BenchResult(
          title: 'Title of ${e.key}',
          median: e.value,
          p90: e.value,
          passMedians: [e.value],
        ),
    },
  );

  HistoryEntry entry(
    Map<String, double> raw, {
    int daysAgo = 1,
    double calibration = 10,
    bool noisy = false,
    List<String> alerts = const [],
    String? sha,
  }) => HistoryEntry(
    sha: sha ?? 'sha$daysAgo',
    date: now.subtract(Duration(days: daysAgo)),
    calibrationMs: calibration,
    noisy: noisy,
    raw: raw,
    alerts: alerts,
  );

  /// [values] as consecutive daily runs, the last one yesterday.
  PerfHistory daily(String id, List<double> values) => PerfHistory([
    for (var i = 0; i < values.length; i++)
      entry({id: values[i]}, daysAgo: values.length - i),
  ]);

  BenchReport report(PerfComparison c, String id) =>
      c.reports.singleWhere((r) => r.id == id);

  group('scale', () {
    test('a run on a machine twice as slow is halved before any check', () {
      final c = compare(
        run: run({'a.b': 20}, calibration: const [20, 20, 20]),
        budgets: budgets({
          'a.b': {'budgetMs': 15},
        }),
        history: PerfHistory.empty,
      );
      expect(c.scale, 0.5);
      expect(report(c, 'a.b').value, 10);
      expect(c.active, isEmpty, reason: '10 ms on the reference is in budget');
    });

    test('history is rescaled by each entry\'s own calibration', () {
      // The same code measured on a slow and a fast machine is one baseline.
      final history = PerfHistory([
        entry({'a.b': 20}, daysAgo: 3, calibration: 20),
        entry({'a.b': 5}, daysAgo: 2, calibration: 5),
        entry({'a.b': 10}, daysAgo: 1),
      ]);
      final c = compare(
        run: run({'a.b': 10}),
        budgets: budgets({'a.b': {}}),
        history: history,
      );
      expect(report(c, 'a.b').baseline, 10);
      expect(report(c, 'a.b').status, BenchStatus.ok);
    });
  });

  group('budget', () {
    test('over budget is an alert even with no history', () {
      final c = compare(
        run: run({'a.b': 12}),
        budgets: budgets({
          'a.b': {'budgetMs': 10},
        }),
        history: PerfHistory.empty,
      );
      expect(c.active.map((a) => a.key), ['over_budget:a.b']);
      expect(report(c, 'a.b').status, BenchStatus.overBudget);
      expect(c.active.single.message, contains('12.0 ms'));
    });

    test('a benchmark with no budget runs and is flagged for one', () {
      final c = compare(
        run: run({'a.b': 1, 'new.one': 1}),
        budgets: budgets({'a.b': {}}),
        history: PerfHistory.empty,
      );
      expect(c.active, isEmpty);
      expect(report(c, 'new.one').unbudgeted, isTrue);
      expect(renderSummary(c), contains('Add a budget'));
    });
  });

  group('regression', () {
    final steady = [10.0, 10.1, 9.9, 10.0, 10.2, 9.8, 10.0, 10.1, 9.9, 10.0];

    test('a rise past the tolerance over the recent median alerts', () {
      final c = compare(
        run: run({'a.b': 13}),
        budgets: budgets({'a.b': {}}),
        history: daily('a.b', steady),
      );
      expect(c.active.map((a) => a.key), ['regression:a.b']);
      expect(c.newKeys, {'regression:a.b'});
      expect(report(c, 'a.b').status, BenchStatus.regression);
      expect(c.active.single.message, contains('is 30% slower'));
    });

    test('a rise inside the tolerance does not', () {
      final c = compare(
        run: run({'a.b': 12}),
        budgets: budgets({'a.b': {}}),
        history: daily('a.b', steady),
      );
      expect(c.active, isEmpty);
    });

    test('the threshold widens to the baseline\'s own noise', () {
      // ±2 ms of run-to-run wander on 10 ms: MAD 2, so 3×MAD = 60%.
      final noisy = [8.0, 12.0, 8.0, 12.0, 10.0, 8.0, 12.0, 10.0, 8.0, 12.0];
      final c = compare(
        run: run({'a.b': 14}),
        budgets: budgets({'a.b': {}}),
        history: daily('a.b', noisy),
      );
      expect(c.active, isEmpty, reason: '+40% is inside this noise');

      final worse = compare(
        run: run({'a.b': 17}),
        budgets: budgets({'a.b': {}}),
        history: daily('a.b', noisy),
      );
      expect(worse.active.map((a) => a.key), ['regression:a.b']);
    });

    test('a rise under the absolute floor never alerts', () {
      final c = compare(
        run: run({'a.b': 0.06}),
        budgets: budgets({'a.b': {}}),
        history: daily('a.b', [0.03, 0.03, 0.03, 0.03]),
      );
      expect(c.active, isEmpty, reason: '+100%, but 0.03 ms < minDeltaMs');
    });

    test('fewer than three earlier runs judge only the budget', () {
      final c = compare(
        run: run({'a.b': 30}),
        budgets: budgets({'a.b': {}}),
        history: daily('a.b', [10, 10]),
      );
      expect(c.active, isEmpty);
      expect(report(c, 'a.b').status, BenchStatus.noBaseline);
    });

    test('noisy earlier runs are left out of the baseline', () {
      final history = PerfHistory([
        for (var i = 0; i < 5; i++)
          entry({'a.b': 30}, daysAgo: 10 - i, noisy: true),
        for (var i = 0; i < 5; i++) entry({'a.b': 10}, daysAgo: 5 - i),
      ]);
      final c = compare(
        run: run({'a.b': 13}),
        budgets: budgets({'a.b': {}}),
        history: history,
      );
      expect(report(c, 'a.b').baseline, 10);
      expect(c.active.map((a) => a.key), ['regression:a.b']);
    });

    test('a clear drop is reported as faster, never as an alert', () {
      final c = compare(
        run: run({'a.b': 6}),
        budgets: budgets({'a.b': {}}),
        history: daily('a.b', steady),
      );
      expect(c.active, isEmpty);
      expect(report(c, 'a.b').status, BenchStatus.faster);
    });
  });

  group('drift', () {
    test('a slow creep no single run trips is caught against a month ago', () {
      // 10 ms two months ago, then +2% a day for 30 days: every run is
      // within 25% of the median of the ten before it.
      final history = PerfHistory([
        for (var d = 60; d > 50; d--) entry({'a.b': 10}, daysAgo: d),
        for (var d = 30; d >= 1; d--)
          entry({'a.b': 10 * (1 + 0.02 * (31 - d))}, daysAgo: d),
      ]);
      final c = compare(
        run: run({'a.b': 16.3}),
        budgets: budgets({'a.b': {}}),
        history: history,
      );
      expect(
        c.active.map((a) => a.key),
        ['drift:a.b'],
        reason: 'not a step change, so no regression — but +60% on a month ago',
      );
      expect(report(c, 'a.b').status, BenchStatus.drift);
    });

    test('runs older than 90 days are not "then"', () {
      final history = PerfHistory([
        for (var d = 120; d > 110; d--) entry({'a.b': 5}, daysAgo: d),
        for (var d = 10; d >= 1; d--) entry({'a.b': 10}, daysAgo: d),
      ]);
      final c = compare(
        run: run({'a.b': 10}),
        budgets: budgets({'a.b': {}}),
        history: history,
      );
      expect(c.active, isEmpty);
    });
  });

  group('alerts across runs', () {
    test('an alert already up is not new; one that cleared is resolved', () {
      final history = PerfHistory([
        ...daily('a.b', [10, 10, 10, 10]).entries,
        entry(
          {'a.b': 13, 'c.d': 1},
          daysAgo: 0,
          alerts: const ['regression:a.b', 'over_budget:c.d'],
        ),
      ]);
      final c = compare(
        run: run({'a.b': 14, 'c.d': 1}),
        budgets: budgets({
          'a.b': {},
          'c.d': {'budgetMs': 2},
        }),
        history: history,
      );
      expect(c.active.map((a) => a.key), ['regression:a.b']);
      expect(c.newKeys, isEmpty, reason: 'already reported');
      expect(c.resolvedKeys, {'over_budget:c.d'});
    });

    test('a benchmark that did not run alerts, and keeps its old alerts', () {
      final history = PerfHistory([
        entry({'a.b': 10}, daysAgo: 0, alerts: const ['regression:a.b']),
      ]);
      final c = compare(
        run: run({}),
        budgets: budgets({'a.b': {}}),
        history: history,
      );
      expect(c.active.map((a) => a.key).toSet(), {
        'failed:a.b',
        'regression:a.b',
      });
      expect(c.newKeys, {'failed:a.b'});
      expect(c.resolvedKeys, isEmpty, reason: 'unknown is not resolved');
      expect(report(c, 'a.b').status, BenchStatus.failed);
    });

    test('a filtered run expects only what its filter selects, and keeps '
        'the alerts of what it left out', () {
      final history = PerfHistory([
        entry(
          {'a.b': 1, 'c.d': 1},
          daysAgo: 0,
          alerts: const ['regression:c.d'],
        ),
      ]);
      final c = compare(
        run: run({'a.b': 1}, filter: r'a\.b'),
        budgets: budgets({'a.b': {}, 'c.d': {}}),
        history: history,
      );
      expect(
        c.active.map((a) => a.key),
        ['regression:c.d'],
        reason: 'c.d was not asked for, so it is neither failed nor resolved',
      );
      expect(c.newKeys, isEmpty);
      expect(c.resolvedKeys, isEmpty);
      expect(c.reports.map((r) => r.id), ['a.b']);
    });

    test('a regression stays open while the benchmark stays slow', () {
      // Ten normal runs, then six slow ones that each alerted. Were the slow
      // runs part of the baseline, its median would be 13.5 by now and the
      // alert would have cleared itself with nothing fixed.
      final history = PerfHistory([
        for (var d = 20; d > 10; d--) entry({'a.b': 10}, daysAgo: d),
        for (var d = 6; d >= 1; d--)
          entry({'a.b': 13.5}, daysAgo: d, alerts: const ['regression:a.b']),
      ]);
      final c = compare(
        run: run({'a.b': 13.5}),
        budgets: budgets({'a.b': {}}),
        history: history,
      );
      expect(c.active.map((a) => a.key), ['regression:a.b']);
      expect(report(c, 'a.b').baseline, 10);
      expect(c.newKeys, isEmpty);
    });

    test('`since` accepts a slowdown: earlier runs are not compared', () {
      final accepted = now.subtract(const Duration(days: 3, hours: 12));
      final history = PerfHistory([
        for (var d = 20; d > 10; d--) entry({'a.b': 10}, daysAgo: d),
        for (var d = 10; d > 3; d--)
          entry({'a.b': 13.5}, daysAgo: d, alerts: const ['regression:a.b']),
        // The runs since the acceptance, judged without the old baseline.
        for (var d = 3; d >= 1; d--) entry({'a.b': 13.5}, daysAgo: d),
      ]);
      final c = compare(
        run: run({'a.b': 13.5}),
        budgets: budgets({
          'a.b': {'since': accepted.toIso8601String()},
        }),
        history: history,
      );
      expect(c.active, isEmpty);
      expect(report(c, 'a.b').baseline, 13.5);

      final next = compare(
        run: run({'a.b': 18}),
        budgets: budgets({
          'a.b': {'since': accepted.toIso8601String()},
        }),
        history: history,
      );
      expect(
        next.active.map((a) => a.key),
        ['regression:a.b'],
        reason: 'the new normal is guarded like the old one',
      );
    });

    test('a slowdown that eases into drift is the same news, neither new '
        'nor resolved', () {
      // 10 ms two months ago; 14.5 ms for the last few weeks, which became
      // the recent baseline unflagged; yesterday's spike was a regression.
      // Today is back at 14.5: inside the regression threshold, still +45%
      // on a month ago.
      final history = PerfHistory([
        for (var d = 60; d > 50; d--) entry({'a.b': 10}, daysAgo: d),
        for (var d = 25; d > 1; d--) entry({'a.b': 14.5}, daysAgo: d),
        entry({'a.b': 20}, daysAgo: 1, alerts: const ['regression:a.b']),
      ]);
      final c = compare(
        run: run({'a.b': 14.5}),
        budgets: budgets({'a.b': {}}),
        history: history,
      );
      expect(c.active.map((a) => a.key), ['drift:a.b']);
      expect(c.newKeys, isEmpty, reason: 'already announced as a regression');
      expect(c.resolvedKeys, isEmpty, reason: 'it did not go away');
    });

    test('drift is not listed beside an open regression of the same '
        'benchmark', () {
      // 10 ms two months ago, 15 ms lately, 20 ms today: a regression on
      // the recent runs and a drift on the old ones — one slowdown.
      final history = PerfHistory([
        for (var d = 60; d > 50; d--) entry({'a.b': 10}, daysAgo: d),
        for (var d = 20; d >= 1; d--) entry({'a.b': 15}, daysAgo: d),
      ]);
      final c = compare(
        run: run({'a.b': 20}),
        budgets: budgets({'a.b': {}}),
        history: history,
      );
      expect(c.active.map((a) => a.key), ['regression:a.b']);
    });

    test('a commit measured again replaces its entry, and does not announce '
        'what it already did', () {
      final history = PerfHistory([
        for (var d = 10; d > 1; d--) entry({'a.b': 10}, daysAgo: d),
        entry(
          {'a.b': 14},
          daysAgo: 0,
          sha: 'cur',
          alerts: const ['regression:a.b'],
        ),
      ]);
      final c = compare(
        run: run({'a.b': 14}),
        budgets: budgets({'a.b': {}}),
        history: history,
      );
      expect(c.remeasured, isTrue);
      expect(report(c, 'a.b').baseline, 10, reason: 'not judged by itself');
      expect(c.active.map((a) => a.key), ['regression:a.b']);
      expect(c.newKeys, isEmpty);
      expect(c.previousSha, 'sha2');

      final recorded = recordRun(history, c);
      expect(recorded.entries, hasLength(history.entries.length));
      expect(recorded.entries.last.sha, 'cur');
    });

    test('a late re-run of an older commit is judged but not recorded', () {
      final history = PerfHistory([
        for (var d = 10; d > 3; d--) entry({'a.b': 10}, daysAgo: d),
        entry({'a.b': 10}, daysAgo: 3, sha: 'old'),
        entry({'a.b': 10}, daysAgo: 2),
      ]);
      final c = compare(
        run: run({'a.b': 10}, sha: 'old'),
        budgets: budgets({'a.b': {}}),
        history: history,
      );
      expect(c.stale, isTrue);
      expect(recordRun(history, c).entries, same(history.entries));
    });

    test('a noisy run judges no regression and resolves none', () {
      final history = PerfHistory([
        ...daily('a.b', [10, 10, 10, 10]).entries,
        entry({'a.b': 13}, daysAgo: 0, alerts: const ['regression:a.b']),
      ]);
      final c = compare(
        // Calibration 8–14 ms: the machine changed speed mid-run.
        run: run({'a.b': 10}, calibration: const [8, 10, 14]),
        budgets: budgets({'a.b': {}}),
        history: history,
      );
      expect(c.noisy, isTrue);
      expect(c.active.map((a) => a.key), ['regression:a.b']);
      expect(c.resolvedKeys, isEmpty);
      expect(renderSummary(c), contains('not steady'));
    });

    test('the run is recorded with its raw times and active alerts', () {
      final c = compare(
        run: run({'a.b': 12}, calibration: const [20, 20]),
        budgets: budgets({
          'a.b': {'budgetMs': 5},
        }),
        history: PerfHistory.empty,
      );
      final e = c.toEntry();
      expect(e.raw, {'a.b': 12});
      expect(e.calibrationMs, 20);
      expect(e.alerts, ['over_budget:a.b']);
    });
  });

  group('review fixes', () {
    test(
      'a regression on top of an open drift is new — a step on the creep',
      () {
        final history = PerfHistory([
          for (var d = 60; d > 50; d--) entry({'a.b': 10}, daysAgo: d),
          for (var d = 20; d > 1; d--) entry({'a.b': 15}, daysAgo: d),
          entry({'a.b': 15}, daysAgo: 1, alerts: const ['drift:a.b']),
        ]);
        final c = compare(
          run: run({'a.b': 25}),
          budgets: budgets({'a.b': {}}),
          history: history,
        );
        expect(c.newKeys, {'regression:a.b'});
        expect(c.failingKeys, contains('regression:a.b'));
      },
    );

    test('a suite-wide since accepts every benchmark at once', () {
      final history = daily('a.b', [10, 10, 10, 10, 10]);
      final c = compare(
        run: run({'a.b': 20}),
        budgets: PerfBudgets.fromJson({
          'reference': {'machine': 'ref', 'calibrationMs': 10},
          'defaults': {
            'since': now.subtract(const Duration(hours: 1)).toIso8601String(),
          },
          'benchmarks': {'a.b': <String, Object>{}},
        }),
        history: history,
      );
      expect(c.active, isEmpty, reason: 'nothing before `since` is compared');
    });

    test('"changes since" starts at the last run that could judge', () {
      final history = PerfHistory([
        entry({'a.b': 10}, daysAgo: 3, sha: 'judged'),
        entry({'a.b': 10}, daysAgo: 2, sha: 'noisy', noisy: true),
      ]);
      final c = compare(
        run: run({'a.b': 10}),
        budgets: budgets({'a.b': {}}),
        history: history,
      );
      expect(c.previousSha, 'judged');
    });

    test('a zero baseline neither throws nor alerts', () {
      final c = compare(
        run: run({'a.b': 1}),
        budgets: budgets({'a.b': {}}),
        history: daily('a.b', [0, 0, 0, 0]),
      );
      expect(c.active, isEmpty);
    });
  });

  group('what fails the run', () {
    test('a new regression fails it once; the same regression the next run '
        'does not — it lives in the issue', () {
      final steady = daily('a.b', [10, 10, 10, 10, 10]);
      final first = compare(
        run: run({'a.b': 14}),
        budgets: budgets({'a.b': {}}),
        history: steady,
      );
      expect(first.failingKeys, {'regression:a.b'});

      final next = compare(
        run: run({'a.b': 14}),
        budgets: budgets({'a.b': {}}),
        history: appendToHistory(steady, first.toEntry()),
      );
      expect(next.active.map((a) => a.key), ['regression:a.b']);
      expect(next.failingKeys, isEmpty);
    });

    test('over budget fails every run until it is fixed', () {
      final first = compare(
        run: run({'a.b': 30}),
        budgets: budgets({
          'a.b': {'budgetMs': 20},
        }),
        history: PerfHistory.empty,
      );
      expect(first.failingKeys, {'over_budget:a.b'});
      final again = compare(
        run: run({'a.b': 30}),
        budgets: budgets({
          'a.b': {'budgetMs': 20},
        }),
        history: PerfHistory([first.toEntry()]),
      );
      expect(again.newKeys, isEmpty);
      expect(again.failingKeys, {
        'over_budget:a.b',
      }, reason: 'not only when new');
    });

    test('a benchmark that stopped running fails every run', () {
      final first = compare(
        run: run({}),
        budgets: budgets({'a.b': {}}),
        history: PerfHistory.empty,
      );
      final again = compare(
        run: run({}),
        budgets: budgets({'a.b': {}}),
        history: PerfHistory([first.toEntry()]),
      );
      expect(again.failingKeys, {'failed:a.b'});
    });

    test('a late re-run of an older commit fails nothing', () {
      final history = PerfHistory([
        entry({'a.b': 10}, daysAgo: 3, sha: 'old'),
        entry({'a.b': 10}, daysAgo: 2),
      ]);
      final c = compare(
        run: run({'a.b': 99}, sha: 'old'),
        budgets: budgets({
          'a.b': {'budgetMs': 20},
        }),
        history: history,
      );
      expect(c.stale, isTrue);
      expect(c.active, isNotEmpty);
      expect(c.failingKeys, isEmpty);
    });
  });

  group('history file', () {
    test('round-trips through JSON', () {
      final h = PerfHistory([
        entry({'a.b': 1.5}, alerts: const ['drift:a.b']),
      ]);
      final back = PerfHistory.fromJson(h.toJson());
      expect(back.entries.single.raw, {'a.b': 1.5});
      expect(back.entries.single.alerts, ['drift:a.b']);
      expect(back.entries.single.date, h.entries.single.date);
    });

    test('an unknown schema is refused, not misread', () {
      expect(
        () => PerfHistory.fromJson({'schema': 99, 'entries': <Object>[]}),
        throwsFormatException,
      );
    });

    test('keeps the newest $kPerfHistoryCap runs', () {
      var h = PerfHistory.empty;
      for (var i = 0; i < kPerfHistoryCap + 5; i++) {
        h = appendToHistory(h, entry({'a.b': 1}, sha: 's$i'));
      }
      expect(h.entries, hasLength(kPerfHistoryCap));
      expect(h.entries.last.sha, 's${kPerfHistoryCap + 4}');
    });
  });

  group('rendering', () {
    test('the comment names each new alert and the mention', () {
      final c = compare(
        run: PerfRun(
          sha: 'abcdef1234567',
          ref: 'main',
          date: now,
          repoUrl: 'https://github.com/o/r',
          runUrl: 'https://github.com/o/r/actions/runs/1',
          calibrationSamples: const [10],
          benchmarks: const {
            'a.b': BenchResult(
              title: 'Thing',
              median: 9,
              p90: 9,
              passMedians: [9],
            ),
          },
        ),
        budgets: budgets({
          'a.b': {'budgetMs': 5},
        }),
        history: PerfHistory([
          entry({'a.b': 4}, sha: '1234567890abc'),
        ]),
      );
      final comment = renderNewAlertsComment(c, mention: '@someone');
      expect(comment, startsWith('@someone'));
      expect(comment, contains('**Thing** (`a.b`) is over its budget'));
      expect(
        comment,
        contains(
          'https://github.com/o/r/compare/1234567890abc...abcdef1234567',
        ),
      );
      expect(renderIssueBody(c), contains('--name "a.b"'));
    });

    test('sparkline runs low to high, and flat is flat', () {
      expect(sparkline([1, 2, 3, 4, 5, 6, 7, 8]), '▁▂▃▄▅▆▇█');
      expect(sparkline([5, 5, 5]), '▄▄▄');
      expect(sparkline(const []), '');
    });
  });
}
