// The judgement half of the performance suite: a run of `benchmark/perf`
// against the budgets and the history of earlier runs. Pure — no I/O — so
// `test/tools/perf_compare_test.dart` pins every rule here.
//
// docs/performance-tracking.md carries the reasoning; the short version:
//
//  * every time is put on one scale — milliseconds on the reference machine —
//    by the calibration workload measured in the same run;
//  * "too slow" is a budget, committed in `benchmark/perf/budgets.json`;
//  * "slower" is a rise over the median of the recent runs on main, wider
//    than both the configured tolerance and the noise those runs show;
//  * "slower over time" is the same comparison against runs a month or more
//    old, which a run-to-run check cannot see when each step is small;
//  * a benchmark that stopped running is an alert, not a silence;
//  * a state that cannot be judged (a noisy run, a benchmark that failed)
//    keeps the alerts it had — unknown is not "resolved".

import 'dart:math' as math;

/// How the history file is laid out. Bump only with a reader for the old one.
const int kPerfHistorySchema = 1;

/// Runs kept in the history. A run a day keeps well over a year.
const int kPerfHistoryCap = 500;

/// Recent main runs the regression baseline is the median of.
const int kBaselineRuns = 10;

/// Fewest earlier runs a regression or drift check needs to say anything.
const int kMinBaselineRuns = 3;

/// A run whose calibration samples spread wider than this (slowest over
/// fastest) shared its machine with something else part-way through.
const double kNoisyCalibrationSpread = 1.3;

/// One benchmark in one run, as `tools/perf/main.dart run` merges it.
class BenchResult {
  const BenchResult({
    required this.title,
    required this.median,
    required this.p90,
    required this.passMedians,
  });

  factory BenchResult.fromJson(Map<String, dynamic> json) => BenchResult(
    title: json['title'] as String? ?? '',
    median: (json['median'] as num).toDouble(),
    p90: (json['p90'] as num? ?? json['median'] as num).toDouble(),
    passMedians: [
      for (final v in json['passMedians'] as List? ?? const [])
        (v as num).toDouble(),
    ],
  );

  final String title;

  /// Milliseconds on the machine that ran it: the lowest of the per-pass
  /// medians (a pass slowed by a neighbour loses to the one that was not).
  final double median;
  final double p90;
  final List<double> passMedians;

  Map<String, Object?> toJson() => {
    'title': title,
    'median': median,
    'p90': p90,
    'passMedians': passMedians,
  };
}

/// A whole run of the suite.
class PerfRun {
  const PerfRun({
    required this.sha,
    required this.ref,
    required this.date,
    required this.calibrationSamples,
    required this.benchmarks,
    this.runUrl = '',
    this.repoUrl = '',
    this.machine = const {},
    this.testsFailed = false,
    this.filter = '',
  });

  factory PerfRun.fromJson(Map<String, dynamic> json) => PerfRun(
    sha: json['sha'] as String? ?? '',
    ref: json['ref'] as String? ?? '',
    date: DateTime.parse(json['date'] as String),
    runUrl: json['runUrl'] as String? ?? '',
    repoUrl: json['repoUrl'] as String? ?? '',
    machine: Map<String, String>.from(json['machine'] as Map? ?? const {}),
    testsFailed: json['testsFailed'] as bool? ?? false,
    filter: json['filter'] as String? ?? '',
    calibrationSamples: [
      for (final v in json['calibrationSamples'] as List? ?? const [])
        (v as num).toDouble(),
    ],
    benchmarks: {
      for (final e in (json['benchmarks'] as Map? ?? const {}).entries)
        e.key as String: BenchResult.fromJson(
          Map<String, dynamic>.from(e.value as Map),
        ),
    },
  );

  final String sha;
  final String ref;
  final DateTime date;
  final String runUrl;
  final String repoUrl;
  final Map<String, String> machine;

  /// True when `flutter test` exited non-zero: some benchmark threw.
  final bool testsFailed;

  /// The `--name` regex the run was limited to, or empty for the whole suite.
  /// A benchmark the filter left out was not expected, so it is not missing.
  final String filter;

  /// Whether this run was meant to produce [id].
  bool expects(String id) => filter.isEmpty || RegExp(filter).hasMatch(id);

  /// The calibration workload's fastest time, once per benchmark file and
  /// pass.
  final List<double> calibrationSamples;
  final Map<String, BenchResult> benchmarks;

  double? get calibrationMs =>
      calibrationSamples.isEmpty ? null : median(calibrationSamples);

  bool get noisy {
    if (calibrationSamples.isEmpty) return true;
    final lo = calibrationSamples.reduce(math.min);
    final hi = calibrationSamples.reduce(math.max);
    return lo <= 0 || hi / lo > kNoisyCalibrationSpread;
  }

  Map<String, Object?> toJson() => {
    'sha': sha,
    'ref': ref,
    'date': date.toUtc().toIso8601String(),
    'runUrl': runUrl,
    'repoUrl': repoUrl,
    'machine': machine,
    'testsFailed': testsFailed,
    'filter': filter,
    'calibrationSamples': calibrationSamples,
    'benchmarks': {for (final e in benchmarks.entries) e.key: e.value.toJson()},
  };
}

/// One earlier run, as the history keeps it: raw medians plus the run's
/// calibration, so the values can be rescaled if the reference ever changes.
class HistoryEntry {
  const HistoryEntry({
    required this.sha,
    required this.date,
    required this.calibrationMs,
    required this.raw,
    this.ref = '',
    this.runUrl = '',
    this.noisy = false,
    this.alerts = const [],
  });

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
    sha: json['sha'] as String? ?? '',
    ref: json['ref'] as String? ?? '',
    date: DateTime.parse(json['date'] as String),
    runUrl: json['runUrl'] as String? ?? '',
    calibrationMs: (json['calibrationMs'] as num?)?.toDouble(),
    noisy: json['noisy'] as bool? ?? false,
    raw: {
      for (final e in (json['raw'] as Map? ?? const {}).entries)
        e.key as String: (e.value as num).toDouble(),
    },
    alerts: [for (final a in json['alerts'] as List? ?? const []) a as String],
  );

  final String sha;
  final String ref;
  final DateTime date;
  final String runUrl;
  final double? calibrationMs;
  final bool noisy;
  final Map<String, double> raw;

  /// The alert keys active after this run (`<kind>:<id>`).
  final List<String> alerts;

  Map<String, Object?> toJson() => {
    'sha': sha,
    'ref': ref,
    'date': date.toUtc().toIso8601String(),
    'runUrl': runUrl,
    'calibrationMs': calibrationMs,
    'noisy': noisy,
    'raw': raw,
    'alerts': alerts,
  };
}

class PerfHistory {
  const PerfHistory(this.entries);

  factory PerfHistory.fromJson(Map<String, dynamic> json) {
    final schema = json['schema'] as int? ?? 0;
    if (schema != kPerfHistorySchema) {
      throw FormatException(
        'perf history schema $schema, expected '
        '$kPerfHistorySchema',
      );
    }
    return PerfHistory([
      for (final e in json['entries'] as List? ?? const [])
        HistoryEntry.fromJson(Map<String, dynamic>.from(e as Map)),
    ]);
  }

  static const empty = PerfHistory([]);

  /// Oldest first.
  final List<HistoryEntry> entries;

  Map<String, Object?> toJson() => {
    'schema': kPerfHistorySchema,
    'entries': [for (final e in entries) e.toJson()],
  };
}

/// Per-benchmark limits, from `benchmark/perf/budgets.json`.
class BenchBudget {
  const BenchBudget({
    this.budgetMs,
    required this.regression,
    required this.drift,
    required this.minDeltaMs,
    this.since,
  });

  /// The ceiling, in milliseconds on the reference machine. Null: none.
  final double? budgetMs;

  /// A rise over the recent baseline larger than this fraction is a
  /// regression — unless the baseline's own noise is wider.
  final double regression;

  /// The same, against the runs a month or more ago.
  final double drift;

  /// A rise smaller than this many milliseconds is never an alert, whatever
  /// its percentage: the floor for benchmarks measured in microseconds.
  final double minDeltaMs;

  /// Runs before this are not compared with: the way to accept a slowdown
  /// that was deliberate (`"since": "2026-11-02"` in budgets.json). An open
  /// regression otherwise stays open — the baseline leaves out the runs that
  /// were alerting, so it cannot drift up to meet the slow ones.
  final DateTime? since;
}

DateTime? _later(DateTime? a, DateTime? b) =>
    a == null ? b : (b == null || a.isAfter(b) ? a : b);

DateTime? _parseSince(Object? value) {
  if (value is! String || value.isEmpty) return null;
  // A bare date is midnight UTC, like every recorded run's date.
  return DateTime.parse(value.length == 10 ? '${value}T00:00:00Z' : value);
}

class PerfBudgets {
  const PerfBudgets({
    required this.referenceCalibrationMs,
    required this.referenceMachine,
    required this.benchmarks,
  });

  factory PerfBudgets.fromJson(Map<String, dynamic> json) {
    final reference = Map<String, dynamic>.from(json['reference'] as Map);
    final defaults = Map<String, dynamic>.from(
      json['defaults'] as Map? ?? const {},
    );
    double read(Map<String, dynamic> m, String key, double fallback) =>
        (m[key] as num?)?.toDouble() ?? fallback;
    final dRegression = read(defaults, 'regression', 0.25);
    final dDrift = read(defaults, 'drift', 0.4);
    final dMinDelta = read(defaults, 'minDeltaMs', 0.1);
    // A suite-wide `since`: the procedure after a Flutter bump or a runner
    // change, which moves every number at once and would otherwise leave each
    // benchmark's regression open until it got its own `since`.
    final dSince = _parseSince(defaults['since']);
    return PerfBudgets(
      referenceCalibrationMs: (reference['calibrationMs'] as num).toDouble(),
      referenceMachine: reference['machine'] as String? ?? '',
      benchmarks: {
        for (final e in (json['benchmarks'] as Map).entries)
          e.key as String: () {
            final m = Map<String, dynamic>.from(e.value as Map);
            return BenchBudget(
              budgetMs: (m['budgetMs'] as num?)?.toDouble(),
              regression: read(m, 'regression', dRegression),
              drift: read(m, 'drift', dDrift),
              minDeltaMs: read(m, 'minDeltaMs', dMinDelta),
              since: _later(_parseSince(m['since']), dSince),
            );
          }(),
      },
    );
  }

  final double referenceCalibrationMs;
  final String referenceMachine;

  /// Every benchmark the suite is expected to produce.
  final Map<String, BenchBudget> benchmarks;
}

enum AlertKind {
  /// Expected (it has a budget) and absent from the run: it threw, or was
  /// deleted without its budget.
  failed('failed'),

  /// Over its budget.
  overBudget('over_budget'),

  /// Slower than the median of the recent runs.
  regression('regression'),

  /// Slower than it was a month or more ago.
  drift('drift');

  const AlertKind(this.wire);
  final String wire;
}

class PerfAlert {
  const PerfAlert(this.kind, this.id, this.message);

  final AlertKind kind;
  final String id;

  /// One markdown sentence naming the benchmark and the numbers.
  final String message;

  String get key => '${kind.wire}:$id';
}

enum BenchStatus {
  ok,
  faster,
  regression,
  drift,
  overBudget,
  failed,
  noBaseline,
}

class BenchReport {
  const BenchReport({
    required this.id,
    required this.title,
    required this.status,
    this.value,
    this.baseline,
    this.budget,
    this.trend = const [],
    this.unbudgeted = false,
  });

  final String id;
  final String title;
  final BenchStatus status;

  /// Milliseconds on the reference machine; null when it did not run.
  final double? value;
  final double? baseline;
  final double? budget;

  /// The last runs' values, oldest first, this one last.
  final List<double> trend;

  /// Ran, but has no entry in the budgets file.
  final bool unbudgeted;

  double? get change => value == null || baseline == null || baseline == 0
      ? null
      : value! / baseline! - 1;
}

class PerfComparison {
  const PerfComparison({
    required this.run,
    required this.scale,
    required this.noisy,
    required this.reports,
    required this.active,
    required this.newKeys,
    required this.resolvedKeys,
    required this.baselineRuns,
    required this.previousSha,
    this.remeasured = false,
    this.stale = false,
  });

  final PerfRun run;

  /// [run]'s commit is the history's last: it replaces that entry.
  final bool remeasured;

  /// [run]'s commit is recorded with newer commits after it — a late re-run
  /// of an old job. Judged against what preceded it, but not recorded, and
  /// it must not move the issue: that reflects the newer commits.
  final bool stale;

  /// What every raw time in this run was multiplied by.
  final double scale;
  final bool noisy;
  final List<BenchReport> reports;

  /// Every alert active after this run, carried-over ones included.
  final List<PerfAlert> active;

  /// Alert keys that were not active after the previous run — a `drift`
  /// that takes over from an open `regression` of the same benchmark (or the
  /// reverse) excepted.
  final Set<String> newKeys;

  /// Alert keys active after the previous run and not after this one — a
  /// `regression` handed over to a `drift` of the same benchmark (or the
  /// reverse) excepted.
  final Set<String> resolvedKeys;

  /// How many earlier runs the baseline drew on (at most [kBaselineRuns]).
  final int baselineRuns;

  /// The commit of the last recorded run, for a "changed since" range.
  final String? previousSha;

  List<PerfAlert> get newAlerts =>
      active.where((a) => newKeys.contains(a.key)).toList();

  /// The alert keys that fail the run — the gate CI applies.
  ///
  /// - **Every new alert.** A slowdown turns red the run it appears in;
  ///   after that it lives in the issue, so a regression that stays does not
  ///   turn every later run red.
  /// - **Every `over_budget` and every `failed`, new or not.** Over its budget
  ///   is "too slow" — the line nobody may cross quietly — and a benchmark
  ///   that stopped running is a hole in the suite. Both stay red on every
  ///   run until fixed, or until the budget is raised in a reviewed commit.
  /// - **Nothing, for a stale run** — a late re-run of an older commit
  ///   describes code that is no longer current.
  Set<String> get failingKeys {
    if (stale) return const {};
    return {
      ...newKeys,
      for (final a in active)
        if (a.kind == AlertKind.overBudget || a.kind == AlertKind.failed) a.key,
    };
  }

  /// [run] as the history will keep it.
  HistoryEntry toEntry() => HistoryEntry(
    sha: run.sha,
    ref: run.ref,
    date: run.date,
    runUrl: run.runUrl,
    calibrationMs: run.calibrationMs,
    noisy: noisy,
    raw: {for (final e in run.benchmarks.entries) e.key: e.value.median},
    alerts: [for (final a in active) a.key],
  );
}

/// Judges [run] against [budgets] and [history].
///
/// [history] should hold only runs of the default branch: they are what
/// "the baseline" means, whichever branch [run] measured.
PerfComparison compare({
  required PerfRun run,
  required PerfBudgets budgets,
  required PerfHistory history,
}) {
  final calibration = run.calibrationMs;
  final scale = calibration == null || calibration <= 0
      ? 1.0
      : budgets.referenceCalibrationMs / calibration;
  final noisy = run.noisy;

  double? scaled(HistoryEntry e, String id) {
    final raw = e.raw[id];
    final cal = e.calibrationMs;
    if (raw == null || cal == null || cal <= 0) return null;
    return raw * budgets.referenceCalibrationMs / cal;
  }

  // A commit already in the history is being measured again — a re-run, or
  // a second dispatch at a commit already measured. It is judged
  // against what came before its first measurement, never against itself.
  final at = run.sha.isEmpty
      ? -1
      : history.entries.lastIndexWhere((e) => e.sha == run.sha);
  final basis = at < 0 ? history.entries : history.entries.sublist(0, at);
  final clean = basis.where((e) => !e.noisy).toList();
  final previous = basis.isEmpty ? null : basis.last;
  // Where "changes since the last run" starts: the last run that could judge
  // anything. A noisy run judged no regression, so a slowdown it measured is
  // still among the changes after the run before it.
  final rangeFrom = clean.isEmpty ? previous : clean.last;
  // What has already been announced: for a commit measured again, its own
  // earlier measurement's alerts — a re-run must not announce them twice.
  final previousKeys = {
    ...?(at >= 0 ? history.entries[at].alerts : previous?.alerts),
  };

  final ids = {
    ...budgets.benchmarks.keys.where(run.expects),
    ...run.benchmarks.keys,
  }.toList()..sort();
  final reports = <BenchReport>[];
  final alerts = <PerfAlert>[];
  var baselineRuns = 0;

  for (final id in ids) {
    final result = run.benchmarks[id];
    final budget = budgets.benchmarks[id];
    final title = result?.title.isNotEmpty == true ? result!.title : id;
    final label = '**$title** (`$id`)';

    final since = budget?.since;
    final past = [
      for (final e in clean)
        if (since == null || !e.date.isBefore(since))
          if (scaled(e, id) case final v?)
            (
              date: e.date,
              value: v,
              alerting:
                  e.alerts.contains('${AlertKind.regression.wire}:$id') ||
                  e.alerts.contains('${AlertKind.drift.wire}:$id'),
            ),
    ];
    // The baseline is the runs that were not themselves alerting: once a
    // slowdown is flagged, the baseline stays where it was until the
    // benchmark comes back down or the slowdown is accepted with `since`.
    // Without that, five slow runs move the median half-way up, widen the
    // noise threshold with it, and the alert clears with nothing fixed.
    final normal = [
      for (final p in past)
        if (!p.alerting) p,
    ];
    final recent = normal.length <= kBaselineRuns
        ? normal
        : normal.sublist(normal.length - kBaselineRuns);
    final baseline = recent.length >= kMinBaselineRuns
        ? median([for (final p in recent) p.value])
        : null;
    if (baseline != null) baselineRuns = math.max(baselineRuns, recent.length);

    if (result == null) {
      // Expected and absent. Whatever it was before, it cannot be judged now,
      // so its earlier alerts stay up alongside this one.
      alerts.add(
        PerfAlert(
          AlertKind.failed,
          id,
          '$label did not produce a result — the benchmark failed or was '
          'removed without its budget. See the job log.',
        ),
      );
      _carryOver(alerts, previousKeys, id, budgets);
      reports.add(
        BenchReport(
          id: id,
          title: title,
          status: BenchStatus.failed,
          baseline: baseline,
          budget: budget?.budgetMs,
        ),
      );
      continue;
    }

    final value = result.median * scale;
    final trend = [
      for (final p in past.length <= 19 ? past : past.sublist(past.length - 19))
        p.value,
      value,
    ];
    var status = baseline == null ? BenchStatus.noBaseline : BenchStatus.ok;

    if (budget?.budgetMs case final limit? when value > limit) {
      alerts.add(
        PerfAlert(
          AlertKind.overBudget,
          id,
          '$label is over its budget: ${_ms(value)} against a budget of '
          '${_ms(limit)}.',
        ),
      );
      status = BenchStatus.overBudget;
    }

    final tolerance = budget?.regression ?? 0.25;
    final minDelta = budget?.minDeltaMs ?? 0.1;
    if (noisy) {
      // The machine was not steady, so a rise here proves nothing — and
      // neither does its absence. Keep what was up.
      _carryOver(
        alerts,
        previousKeys,
        id,
        budgets,
        kinds: const {AlertKind.regression, AlertKind.drift},
      );
    } else if (baseline != null && baseline > 0) {
      final limit = _threshold(
        [for (final p in recent) p.value],
        baseline,
        tolerance,
      );
      if (value > baseline * (1 + limit) && value - baseline >= minDelta) {
        alerts.add(
          PerfAlert(
            AlertKind.regression,
            id,
            '$label is ${_pctAbs(value / baseline - 1)} slower than its recent '
            'baseline: ${_ms(value)} against ${_ms(baseline)} (median of the '
            'last ${recent.length} runs without an alert; alert above '
            '+${(limit * 100).round()}%).',
          ),
        );
        if (status != BenchStatus.overBudget) status = BenchStatus.regression;
      } else if (value < baseline * (1 - limit)) {
        if (status == BenchStatus.ok) status = BenchStatus.faster;
      }

      // Drift: the same question against runs 30–90 days old, which a
      // run-to-run check misses when every step is small. Not asked while a
      // regression is up: it would be the same slowdown, listed twice.
      final regressed =
          status == BenchStatus.regression ||
          alerts.any((a) => a.id == id && a.kind == AlertKind.regression);
      final then = [
        for (final p in normal)
          if (run.date.difference(p.date).inDays case final age
              when age >= 30 && age <= 90)
            p.value,
      ];
      if (!regressed && then.length >= kMinBaselineRuns && median(then) > 0) {
        final old = median(then);
        final now = median([
          for (final p
              in past.length <= 4 ? past : past.sublist(past.length - 4))
            p.value,
          value,
        ]);
        final driftLimit = _threshold(then, old, budget?.drift ?? 0.4);
        if (now > old * (1 + driftLimit) && now - old >= minDelta) {
          alerts.add(
            PerfAlert(
              AlertKind.drift,
              id,
              '$label has grown ${_pctAbs(now / old - 1)} slower over time: '
              '${_ms(now)} lately against ${_ms(old)} one to three months '
              'ago.',
            ),
          );
          if (status == BenchStatus.ok || status == BenchStatus.faster) {
            status = BenchStatus.drift;
          }
        }
      }
    }

    reports.add(
      BenchReport(
        id: id,
        title: title,
        status: status,
        value: value,
        baseline: baseline,
        budget: budget?.budgetMs,
        trend: trend,
        unbudgeted: budget == null,
      ),
    );
  }

  // A run limited with `--name` says nothing about the benchmarks it left
  // out: their alerts are unknown, not resolved.
  for (final key in previousKeys) {
    final colon = key.indexOf(':');
    final id = key.substring(colon + 1);
    if (run.expects(id)) continue;
    for (final kind in AlertKind.values) {
      if (kind.wire != key.substring(0, colon)) continue;
      alerts.add(
        PerfAlert(
          kind,
          id,
          '`$id` was flagged `${kind.wire}` on the last run and was not '
          'measured in this one, so it stays open.',
        ),
      );
    }
  }

  final unique = <String, PerfAlert>{for (final a in alerts) a.key: a};
  final active = unique.values.toList();
  final activeKeys = unique.keys.toSet();
  return PerfComparison(
    run: run,
    scale: scale,
    noisy: noisy,
    reports: reports,
    active: active,
    newKeys: {
      for (final key in activeKeys.difference(previousKeys))
        if (!_continues(key, previousKeys)) key,
    },
    resolvedKeys: {
      for (final key in previousKeys.difference(activeKeys))
        if (!activeKeys.contains(_sameSlowdown(key))) key,
    },
    baselineRuns: baselineRuns,
    previousSha: rangeFrom?.sha,
    remeasured: at >= 0 && at == history.entries.length - 1,
    stale: at >= 0 && at < history.entries.length - 1,
  );
}

/// [history] after [c]'s run is recorded: appended, or — for a commit
/// measured again — in place of its earlier measurement. A stale run (a
/// commit with newer ones recorded after it) is not recorded at all: the
/// history is in commit order, and its tail is what the next run judges by.
PerfHistory recordRun(PerfHistory history, PerfComparison c) {
  if (c.stale) return history;
  if (c.remeasured) {
    return PerfHistory([
      ...history.entries.sublist(0, history.entries.length - 1),
      c.toEntry(),
    ]);
  }
  return appendToHistory(history, c.toEntry());
}

/// Whether [key] carries on an alert already in [previous] under another
/// name: a `drift` taking over from an open `regression` of the same
/// benchmark, which is what a partial fix looks like — back inside the
/// regression threshold, still well over a month ago. Not the reverse: a
/// `regression` appearing while a `drift` is open is a new step on top of the
/// creep, and is announced.
bool _continues(String key, Set<String> previous) =>
    key.startsWith('${AlertKind.drift.wire}:') &&
    previous.contains(_sameSlowdown(key));

/// The other name one slowdown goes by — `regression:<id>` ↔ `drift:<id>`.
/// A hand-over in either direction is not a *resolved* alert: the benchmark
/// is still slow.
String _sameSlowdown(String key) {
  const regression = 'regression:';
  const drift = 'drift:';
  if (key.startsWith(regression)) {
    return '$drift${key.substring(regression.length)}';
  }
  if (key.startsWith(drift)) {
    return '$regression${key.substring(drift.length)}';
  }
  return key;
}

/// Keeps the [previous] alerts of [id] (of [kinds]) up, with a note that
/// this run could not re-judge them.
void _carryOver(
  List<PerfAlert> alerts,
  Set<String> previous,
  String id,
  PerfBudgets budgets, {
  Set<AlertKind> kinds = const {
    AlertKind.overBudget,
    AlertKind.regression,
    AlertKind.drift,
  },
}) {
  for (final kind in kinds) {
    final key = '${kind.wire}:$id';
    if (!previous.contains(key)) continue;
    alerts.add(
      PerfAlert(
        kind,
        id,
        '`$id` was flagged `${kind.wire}` on the last run; this run could not '
        're-check it, so it stays open.',
      ),
    );
  }
}

/// The fractional rise that counts as real: the configured [tolerance], or
/// three times the baseline's own spread (median absolute deviation),
/// whichever is wider — a benchmark that wanders ±15% from run to run must
/// not page anyone at +20%.
double _threshold(List<double> values, double center, double tolerance) {
  if (center <= 0) return tolerance;
  final mad = median([for (final v in values) (v - center).abs()]);
  return math.max(tolerance, 3 * mad / center);
}

double median(List<double> values) {
  if (values.isEmpty) throw ArgumentError('median of nothing');
  final sorted = [...values]..sort();
  final mid = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[mid]
      : (sorted[mid - 1] + sorted[mid]) / 2;
}

/// [history] with [entry] appended, trimmed to [kPerfHistoryCap].
PerfHistory appendToHistory(PerfHistory history, HistoryEntry entry) {
  final entries = [...history.entries, entry];
  return PerfHistory(
    entries.length <= kPerfHistoryCap
        ? entries
        : entries.sublist(entries.length - kPerfHistoryCap),
  );
}

// ---------------------------------------------------------------------------
// Rendering
// ---------------------------------------------------------------------------

String _ms(double v) => v >= 100
    ? '${v.toStringAsFixed(0)} ms'
    : v >= 10
    ? '${v.toStringAsFixed(1)} ms'
    : v >= 1
    ? '${v.toStringAsFixed(2)} ms'
    : '${v.toStringAsFixed(3)} ms';

String _num(double? v) => v == null ? '—' : _ms(v).replaceAll(' ms', '');

String _pct(double fraction) {
  final p = (fraction * 100).round();
  return '${p >= 0 ? '+' : '−'}${p.abs()}%';
}

String _pctAbs(double fraction) => '${(fraction.abs() * 100).round()}%';

const _sparks = '▁▂▃▄▅▆▇█';

/// [values] as a row of block characters, low to high. Fewer than two
/// values have no trend to draw.
String sparkline(List<double> values) {
  if (values.length < 2) return '';
  final lo = values.reduce(math.min);
  final hi = values.reduce(math.max);
  if (hi - lo <= hi * 0.02) return _sparks[3] * values.length;
  return values
      .map(
        (v) => _sparks[((v - lo) / (hi - lo) * (_sparks.length - 1)).round()],
      )
      .join();
}

const _icons = {
  BenchStatus.ok: '✅',
  BenchStatus.faster: '🟢',
  BenchStatus.regression: '🔴',
  BenchStatus.drift: '🟠',
  BenchStatus.overBudget: '⛔',
  BenchStatus.failed: '❌',
  BenchStatus.noBaseline: '⚪',
};

String _shortSha(String sha) => sha.length > 10 ? sha.substring(0, 10) : sha;

String _commitLink(PerfRun run, String sha) => run.repoUrl.isEmpty
    ? '`${_shortSha(sha)}`'
    : '[`${_shortSha(sha)}`](${run.repoUrl}/commit/$sha)';

/// The changes since the last recorded run, as a compare link when possible.
String _range(PerfComparison c) {
  final prev = c.previousSha;
  final run = c.run;
  if (prev == null || prev.isEmpty || prev == run.sha) {
    return _commitLink(run, run.sha);
  }
  if (run.repoUrl.isEmpty) {
    return '`${_shortSha(prev)}..${_shortSha(run.sha)}`';
  }
  return '[`${_shortSha(prev)}..${_shortSha(run.sha)}`]'
      '(${run.repoUrl}/compare/$prev...${run.sha})';
}

String _context(PerfComparison c) {
  final run = c.run;
  final m = run.machine;
  final machine = [
    if (m['cpu']?.isNotEmpty == true) m['cpu'],
    if (m['cores']?.isNotEmpty == true) '${m['cores']} cores',
    if (m['os']?.isNotEmpty == true) m['os'],
    if (m['flutter']?.isNotEmpty == true) 'Flutter ${m['flutter']}',
  ].join(' · ');
  final cal = run.calibrationMs;
  return [
    'Commit ${_commitLink(run, run.sha)}'
        '${run.ref.isEmpty ? '' : ' on `${run.ref}`'}'
        '${run.runUrl.isEmpty ? '' : ' · [run](${run.runUrl})'}',
    if (machine.isNotEmpty) machine,
    'Times are milliseconds on the reference machine: this one ran the '
        'calibration workload in ${cal == null ? '—' : _ms(cal)}, so its '
        'times were multiplied by ${c.scale.toStringAsFixed(2)}. '
        '${c.baselineRuns == 0 ? 'No baseline yet — the first runs only check budgets.' : 'Baseline: median of the last ${c.baselineRuns} runs on main.'}',
  ].join('  \n');
}

/// The job summary: alerts first, then every benchmark.
String renderSummary(PerfComparison c) {
  final b = StringBuffer();
  final alerts = c.active;
  b.writeln(
    alerts.isEmpty
        ? '## Performance — all benchmarks within limits'
        : '## Performance — ${alerts.length} '
              '${alerts.length == 1 ? 'alert' : 'alerts'}'
              '${c.newKeys.isEmpty ? '' : ' (${c.newKeys.length} new)'}',
  );
  b
    ..writeln()
    ..writeln(_context(c))
    ..writeln();
  if (c.noisy) {
    b
      ..writeln(
        '> [!WARNING]\n> The calibration workload varied by more than '
        '${((kNoisyCalibrationSpread - 1) * 100).round()}% during this run, '
        'so the machine was not steady. Regressions were not judged; alerts '
        'already open stay open.',
      )
      ..writeln();
  }
  if (c.run.testsFailed) {
    b
      ..writeln(
        '> [!CAUTION]\n> At least one benchmark threw. Its result is missing '
        'below; the job log has the failure.',
      )
      ..writeln();
  }
  if (alerts.isNotEmpty) {
    b.writeln('### Alerts');
    for (final a in alerts) {
      b.writeln('- ${c.newKeys.contains(a.key) ? '🆕 ' : ''}${a.message}');
    }
    b
      ..writeln()
      ..writeln('Changes since the last recorded run: ${_range(c)}.')
      ..writeln();
  }
  if (c.resolvedKeys.isNotEmpty) {
    b
      ..writeln(
        'Back within limits: '
        '${c.resolvedKeys.map((k) => '`$k`').join(', ')}.',
      )
      ..writeln();
  }
  b
    ..writeln('### Benchmarks')
    ..writeln()
    ..writeln('| | Benchmark | ms | Baseline | Change | Budget | Trend |')
    ..writeln('|---|---|--:|--:|--:|--:|---|');
  for (final r in c.reports) {
    final change = r.change;
    b.writeln(
      '| ${_icons[r.status]} '
      '| ${r.title}<br>`${r.id}`${r.unbudgeted ? ' — **no budget**' : ''} '
      '| ${_num(r.value)} '
      '| ${_num(r.baseline)} '
      '| ${change == null ? '—' : _pct(change)} '
      '| ${_num(r.budget)} '
      '| ${sparkline(r.trend)} |',
    );
  }
  b
    ..writeln()
    ..writeln(
      '✅ within limits · 🟢 faster than its baseline · 🔴 slower than its '
      'baseline · 🟠 slower than a month ago · ⛔ over budget · ❌ did not run '
      '· ⚪ no baseline yet. See `docs/performance-tracking.md`.',
    );
  final unbudgeted = c.reports.where((r) => r.unbudgeted).toList();
  if (unbudgeted.isNotEmpty) {
    b
      ..writeln()
      ..writeln(
        'Add a budget to `benchmark/perf/budgets.json` for: '
        '${unbudgeted.map((r) => '`${r.id}`').join(', ')}.',
      );
  }
  return b.toString();
}

/// The body of the standing "performance regressions" issue.
String renderIssueBody(PerfComparison c) {
  final b = StringBuffer()
    ..writeln(
      'The **Performance** workflow (run by hand from the Actions tab) keeps '
      'this issue up to date and '
      'closes it when no alert remains. What each '
      'alert means and how to reproduce it locally: '
      '`docs/performance-tracking.md`.',
    )
    ..writeln()
    ..writeln('### Open alerts')
    ..writeln();
  for (final a in c.active) {
    b.writeln('- ${a.message}');
  }
  b
    ..writeln()
    ..writeln('**Latest run** — ${_context(c)}')
    ..writeln()
    ..writeln(
      'Reproduce: `dart tools/perf/main.dart run --name '
      '"${c.active.map((a) => a.id).toSet().join('|')}"`, then '
      '`dart tools/perf/main.dart compare --history history.json` with the '
      '`perf-history` artifact of the latest run.',
    );
  return b.toString();
}

/// The comment posted when alerts appear that were not up before.
String renderNewAlertsComment(PerfComparison c, {String mention = ''}) {
  final b = StringBuffer();
  if (mention.trim().isNotEmpty) b.writeln(mention.trim());
  b
    ..writeln(
      '${c.newKeys.length == 1 ? 'A new performance alert' : '${c.newKeys.length} new performance alerts'}'
      ' on ${_commitLink(c.run, c.run.sha)}'
      '${c.run.runUrl.isEmpty ? '' : ' ([run](${c.run.runUrl}))'}:',
    )
    ..writeln();
  for (final a in c.newAlerts) {
    b.writeln('- ${a.message}');
  }
  b
    ..writeln()
    ..writeln('Changes since the last recorded run: ${_range(c)}.');
  return b.toString();
}

/// The comment posted when the last alert clears. It names what cleared
/// rather than claiming everything got fast again: a `drift` also clears
/// when the slow runs age past the 90-day window, with nothing fixed.
String renderResolvedComment(PerfComparison c) =>
    'No performance alerts remain as of ${_commitLink(c.run, c.run.sha)}'
    '${c.run.runUrl.isEmpty ? '' : ' ([run](${c.run.runUrl}))'}'
    '${c.resolvedKeys.isEmpty ? '' : ' — cleared: ${(c.resolvedKeys.toList()..sort()).map((k) => '`$k`').join(', ')}'}'
    '. Closing.';
