// The performance suite's command line. docs/performance-tracking.md.
//
//   dart tools/perf/main.dart run [--passes 2] [--name <regex>]
//       Runs `benchmark/perf` (one file at a time, so nothing times against a
//       neighbour) and merges the passes into build/perf/run.json.
//
//   dart tools/perf/main.dart compare [--history <file>] [--record]
//                                     [--fail-on never|gate|new|any]
//       Judges build/perf/run.json against benchmark/perf/budgets.json and
//       the history, and writes build/perf/: summary.md, alerts.json,
//       issue.md, comment.md, resolved.md — and history.json, with this run
//       appended when --record is given.
//
//   dart tools/perf/main.dart budgets [--history <file>] [--headroom 2.5]
//       Prints budgets.json with every budget re-derived from the recorded
//       runs (or from run.json alone): the median times the headroom.
//
// Plain dart:io, like tools/web_bench: nothing to install.

import 'dart:convert';
import 'dart:io';

import 'perf_compare.dart';

const _outDir = 'build/perf';
const _runFile = '$_outDir/run.json';
const _budgetsFile = 'benchmark/perf/budgets.json';
const _suiteDir = 'benchmark/perf';

Future<void> main(List<String> args) async {
  if (args.isEmpty) _usage();
  final options = _parse(args.skip(1).toList());
  switch (args.first) {
    case 'run':
      exitCode = await _run(options);
    case 'compare':
      exitCode = _compare(options);
    case 'budgets':
      exitCode = _budgets(options);
    default:
      _usage();
  }
}

Never _usage() {
  stderr.writeln(
    'usage: dart tools/perf/main.dart run|compare|budgets [options]\n'
    'See docs/performance-tracking.md.',
  );
  exit(64);
}

Map<String, String> _parse(List<String> args) {
  final out = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (!arg.startsWith('--')) _usage();
    final name = arg.substring(2);
    final hasValue = i + 1 < args.length && !args[i + 1].startsWith('--');
    out[name] = hasValue ? args[++i] : 'true';
  }
  return out;
}

// ---------------------------------------------------------------------------
// run
// ---------------------------------------------------------------------------

Future<int> _run(Map<String, String> options) async {
  final passes = int.parse(options['passes'] ?? '2');
  Directory(_outDir).createSync(recursive: true);
  final perPass = <Map<String, List<Map<String, dynamic>>>>[];
  var failed = false;

  for (var pass = 1; pass <= passes; pass++) {
    final out = File('$_outDir/pass-$pass.jsonl');
    if (out.existsSync()) out.deleteSync();
    stdout.writeln('\n== perf pass $pass of $passes ==\n');
    final process = await Process.start(
      'flutter',
      [
        'test',
        _suiteDir,
        // One file at a time: two files timing at once would measure each
        // other, and the calibration would not describe either.
        '--concurrency=1',
        '--no-pub',
        '--reporter=expanded',
        if (options['name'] case final name?) ...['--name', name],
      ],
      environment: {'PERF_OUT': out.absolute.path},
      mode: ProcessStartMode.inheritStdio,
      runInShell: Platform.isWindows,
    );
    final code = await process.exitCode;
    if (code != 0) {
      failed = true;
      stderr.writeln('perf pass $pass: flutter test exited $code');
    }
    final records = <String, List<Map<String, dynamic>>>{};
    if (out.existsSync()) {
      for (final line in out.readAsLinesSync()) {
        if (line.trim().isEmpty) continue;
        final record = jsonDecode(line) as Map<String, dynamic>;
        (records[record['kind'] as String] ??= []).add(record);
      }
    }
    perPass.add(records);
  }

  final calibration = <double>[
    for (final pass in perPass)
      for (final r in pass['calibration'] ?? const <Map<String, dynamic>>[])
        (r['min'] as num).toDouble(),
  ];
  final runCalibration = calibration.isEmpty ? null : median(calibration);
  // Each pass's own calibration: a pass slowed throughout is compared on its
  // own scale, not on the run's average of both.
  final passCalibration = [
    for (final pass in perPass)
      () {
        final samples = [
          for (final r in pass['calibration'] ?? const <Map<String, dynamic>>[])
            (r['min'] as num).toDouble(),
        ];
        return samples.isEmpty ? runCalibration : median(samples);
      }(),
  ];
  final byId = <String, List<({Map<String, dynamic> record, double? cal})>>{};
  for (var i = 0; i < perPass.length; i++) {
    for (final r in perPass[i]['benchmark'] ?? const <Map<String, dynamic>>[]) {
      (byId[r['id'] as String] ??= []).add((
        record: r,
        cal: passCalibration[i],
      ));
    }
  }
  final benchmarks = {
    for (final e in byId.entries)
      e.key: () {
        // The lowest pass median, each on its own pass's scale: a pass that
        // shared the machine with something loses to one that did not.
        double scaled(({Map<String, dynamic> record, double? cal}) p) {
          final m = (p.record['median'] as num).toDouble();
          final cal = p.cal;
          return cal == null || cal <= 0 || runCalibration == null
              ? m
              : m * runCalibration / cal;
        }

        final best = e.value.reduce((a, b) => scaled(a) <= scaled(b) ? a : b);
        // Reported on the run's scale, which `compare` divides by.
        final factor = scaled(best) / (best.record['median'] as num).toDouble();
        return BenchResult(
          title: best.record['title'] as String,
          median: scaled(best),
          p90:
              (best.record['p90'] as num).toDouble() *
              (factor.isFinite ? factor : 1),
          passMedians: [for (final p in e.value) scaled(p)],
        );
      }(),
  };

  final env = Platform.environment;
  final server = env['GITHUB_SERVER_URL'];
  final repo = env['GITHUB_REPOSITORY'];
  final runId = env['GITHUB_RUN_ID'];
  final run = PerfRun(
    sha: env['GITHUB_SHA'] ?? await _git(['rev-parse', 'HEAD']),
    ref:
        env['GITHUB_REF_NAME'] ??
        await _git(['rev-parse', '--abbrev-ref', 'HEAD']),
    date: DateTime.now().toUtc(),
    repoUrl: server != null && repo != null ? '$server/$repo' : '',
    runUrl: server != null && repo != null && runId != null
        ? '$server/$repo/actions/runs/$runId'
        : '',
    machine: await _machine(),
    testsFailed: failed,
    filter: options['name'] ?? '',
    calibrationSamples: calibration,
    benchmarks: benchmarks,
  );
  File(
    _runFile,
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(run.toJson()));
  stdout.writeln(
    '\nperf: ${benchmarks.length} benchmarks, calibration '
    '${run.calibrationMs?.toStringAsFixed(1) ?? '—'} ms '
    '(${calibration.length} samples) → $_runFile',
  );
  // A benchmark that threw is reported by `compare` as an alert; the run
  // itself succeeded in producing what it could.
  return 0;
}

Future<String> _git(List<String> args) async {
  try {
    final result = await Process.run('git', args);
    return result.exitCode == 0 ? (result.stdout as String).trim() : '';
  } on ProcessException {
    return '';
  }
}

Future<Map<String, String>> _machine() async {
  var cpu = '';
  try {
    if (Platform.isLinux) {
      final line = File('/proc/cpuinfo').readAsLinesSync().firstWhere(
        (l) => l.startsWith('model name'),
        orElse: () => '',
      );
      cpu = line.contains(':') ? line.split(':').last.trim() : '';
    } else if (Platform.isMacOS) {
      final r = await Process.run('sysctl', ['-n', 'machdep.cpu.brand_string']);
      cpu = (r.stdout as String).trim();
    }
  } on Object {
    // Best effort: the CPU name is for people, not for the comparison.
  }
  var flutter = '';
  try {
    final r = await Process.run('flutter', [
      '--version',
      '--machine',
    ], runInShell: Platform.isWindows);
    final json = jsonDecode(r.stdout as String) as Map<String, dynamic>;
    flutter = json['frameworkVersion'] as String? ?? '';
  } on Object {
    // Same.
  }
  return {
    'os': Platform.operatingSystem,
    'cpu': cpu,
    'cores': '${Platform.numberOfProcessors}',
    'flutter': flutter,
  };
}

// ---------------------------------------------------------------------------
// compare
// ---------------------------------------------------------------------------

int _compare(Map<String, String> options) {
  final runFile = File(options['run'] ?? _runFile);
  if (!runFile.existsSync()) {
    stderr.writeln('no ${runFile.path} — run `dart tools/perf/main.dart run`');
    return 66;
  }
  final run = PerfRun.fromJson(_readJson(runFile));
  final budgets = PerfBudgets.fromJson(
    _readJson(File(options['budgets'] ?? _budgetsFile)),
  );
  final record = options['record'] == 'true';
  final history = _readHistory(options['history'], forRecord: record);
  if (history == null) return 65;
  final c = compare(run: run, budgets: budgets, history: history);

  Directory(_outDir).createSync(recursive: true);
  void write(String name, String text) =>
      File('$_outDir/$name').writeAsStringSync(text);

  write('summary.md', renderSummary(c));
  write('issue.md', renderIssueBody(c));
  write(
    'comment.md',
    renderNewAlertsComment(c, mention: options['mention'] ?? ''),
  );
  write('resolved.md', renderResolvedComment(c));
  write(
    'alerts.json',
    const JsonEncoder.withIndent('  ').convert({
      'active': [for (final a in c.active) a.key],
      'new': c.newKeys.toList()..sort(),
      'failing': c.failingKeys.toList()..sort(),
      'resolved': c.resolvedKeys.toList()..sort(),
      'noisy': c.noisy,
      'stale': c.stale,
      'remeasured': c.remeasured,
    }),
  );
  final kept = record ? recordRun(history, c) : history;
  if (c.stale) {
    stdout.writeln(
      'perf: ${c.run.sha} is older than the newest recorded run — judged, '
      'not recorded.',
    );
  }
  write(
    'history.json',
    const JsonEncoder.withIndent(' ').convert(kept.toJson()),
  );

  stdout.write(renderSummary(c));
  return switch (options['fail-on'] ?? 'never') {
    // What CI applies: see `PerfComparison.failingKeys`.
    'gate' when c.failingKeys.isNotEmpty => 1,
    'any' when c.active.isNotEmpty => 1,
    'new' when c.newKeys.isNotEmpty => 1,
    'never' || 'gate' || 'any' || 'new' => 0,
    final other => () {
      stderr.writeln('--fail-on $other: expected never, gate, new or any');
      return 64;
    }(),
  };
}

/// The history at [path]. Null when it exists but cannot be read and the
/// caller is about to record into it ([forRecord]): starting over there would
/// upload a one-entry history as the newest, and every later run would chain
/// from it — the whole history gone without anyone deciding so. Read-only
/// callers just warn and judge by budgets.
PerfHistory? _readHistory(String? path, {bool forRecord = false}) {
  if (path == null) return PerfHistory.empty;
  final file = File(path);
  if (!file.existsSync()) {
    // stderr: `budgets` prints the new budgets file on stdout.
    stderr.writeln('perf: no history at $path — budgets only.');
    return PerfHistory.empty;
  }
  try {
    return PerfHistory.fromJson(_readJson(file));
  } on Object catch (e) {
    if (forRecord) {
      stderr.writeln(
        'perf: cannot read the history at $path ($e). Not recording over it: '
        'fix the reader (a schema bump needs one for the old schema), or '
        'delete the perf-history artifacts to start over on purpose.',
      );
      return null;
    }
    stderr.writeln('perf: ignoring unreadable history $path: $e');
    return PerfHistory.empty;
  }
}

Map<String, dynamic> _readJson(File file) =>
    jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

// ---------------------------------------------------------------------------
// budgets
// ---------------------------------------------------------------------------

int _budgets(Map<String, String> options) {
  final headroom = double.parse(options['headroom'] ?? '2.5');
  final budgetsFile = File(options['budgets'] ?? _budgetsFile);
  final json = _readJson(budgetsFile);
  final budgets = PerfBudgets.fromJson(json);
  final history = _readHistory(options['history']) ?? PerfHistory.empty;

  // Values on the reference scale, per benchmark, from the history's clean
  // runs — or from run.json alone when there is no history yet.
  final values = <String, List<double>>{};
  for (final e in history.entries.where((e) => !e.noisy)) {
    final cal = e.calibrationMs;
    if (cal == null || cal <= 0) continue;
    for (final r in e.raw.entries) {
      // Only the runs since a slowdown was accepted describe today.
      final since = budgets.benchmarks[r.key]?.since;
      if (since != null && e.date.isBefore(since)) continue;
      (values[r.key] ??= []).add(
        r.value * budgets.referenceCalibrationMs / cal,
      );
    }
  }
  // The benchmarks that exist today: the newest run's. A benchmark deleted
  // from the suite (and from the budgets) lives on in the history, and must
  // not come back as a budget that every later run then reports as missing.
  final latest = <String>{
    if (history.entries.isNotEmpty) ...history.entries.last.raw.keys,
  };
  if (values.isEmpty && File(_runFile).existsSync()) {
    final run = PerfRun.fromJson(_readJson(File(_runFile)));
    latest.addAll(run.benchmarks.keys);
    final cal = run.calibrationMs;
    if (cal != null && cal > 0) {
      for (final r in run.benchmarks.entries) {
        values[r.key] = [r.value.median * budgets.referenceCalibrationMs / cal];
      }
    }
  }
  if (values.isEmpty) {
    stderr.writeln('perf: no runs to derive budgets from');
    return 66;
  }

  final current = Map<String, dynamic>.from(json['benchmarks'] as Map);
  final next = <String, dynamic>{};
  for (final id in {...current.keys, ...latest}.toList()..sort()) {
    final entry = Map<String, dynamic>.from(current[id] as Map? ?? const {});
    final v = values[id];
    if (v != null) {
      final recent = v.length <= kBaselineRuns
          ? v
          : v.sublist(v.length - kBaselineRuns);
      entry['budgetMs'] = _roundUp(median(recent) * headroom);
    }
    next[id] = entry;
  }
  json['benchmarks'] = next;
  stdout.writeln(const JsonEncoder.withIndent('  ').convert(json));
  return 0;
}

/// Rounded up to two significant figures: 17.3 → 18, 2.74 → 2.8,
/// 0.243 → 0.25, 1234 → 1300.
num _roundUp(double v) {
  if (v <= 0) return 0;
  var magnitude = 1.0;
  while (v >= magnitude * 100) {
    magnitude *= 10;
  }
  while (v < magnitude * 10) {
    magnitude /= 10;
  }
  final rounded = double.parse(
    ((v / magnitude).ceil() * magnitude).toStringAsPrecision(2),
  );
  return rounded == rounded.roundToDouble() ? rounded.round() : rounded;
}
