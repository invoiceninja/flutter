// The benchmark harness behind `benchmark/perf/*_perf_test.dart`.
//
// Each benchmark is an ordinary `test` / `testWidgets`, so the suite runs
// under `flutter test` on any machine with no device and no network. What it
// adds: warm-up, a fixed number of timed samples, a JSON line per benchmark in
// `$PERF_OUT`, and a calibration workload measured at both ends of every file
// so a run on slower hardware can be scaled back to the reference machine.
//
// See `docs/performance-tracking.md`. Run the suite with
// `dart tools/perf/main.dart run`, never bare `flutter test benchmark/perf`:
// the runner forces `--concurrency=1`, and two files timing at once on the
// same cores would measure each other.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Where results go, one JSON object per line. Unset, results are printed
/// only — the way to run one file while working on it.
final String? _outPath = Platform.environment['PERF_OUT'];

/// Defeats dead-code elimination: every timed body's result is folded in.
Object? perfSink;

/// Measures the calibration workload before the file's first benchmark and
/// after its last.
///
/// Call first thing in every benchmark file's `main`. The workload is plain
/// `dart:core` + `dart:convert`, so no change to the app can move it — only
/// the machine, the SDK, or a busy neighbour can. `tools/perf` divides every
/// result by it to put runs on different hardware on one scale, and reads a
/// wide spread between the samples as a machine that changed speed mid-run.
/// Both ends of the file, because a slowdown that starts half-way through it
/// is invisible to a sample taken only before.
void perfCalibration() {
  setUpAll(() => _calibrate('start'));
  tearDownAll(() => _calibrate('end'));
}

void _calibrate(String at) {
  // The first rounds pay for compiling the workload; keep only the rest.
  for (var i = 0; i < 3; i++) {
    perfSink = calibrationWorkload();
  }
  final ms = <double>[];
  final watch = Stopwatch();
  for (var i = 0; i < 9; i++) {
    watch
      ..reset()
      ..start();
    perfSink = calibrationWorkload();
    watch.stop();
    ms.add(watch.elapsedMicroseconds / 1000);
  }
  _emit({
    'kind': 'calibration',
    'at': at,
    'samples': _round(ms),
    'min': _round3(ms.reduce((a, b) => a < b ? a : b)),
    'median': _round3(_percentile(ms, 50)),
  });
}

/// The fixed workload [perfCalibration] times: building, encoding, decoding
/// and sorting a few thousand small maps — the shape of most work in this app.
///
/// **Never change it.** Every recorded run is scaled by its time; a different
/// workload is a different unit, and the whole history would shift.
int calibrationWorkload() {
  final rows = <Map<String, Object>>[
    for (var i = 0; i < 4000; i++)
      {
        'id': 'row_$i',
        'number': (i * 7919) % 10007,
        'name': 'Customer ${(i * 31) % 997}',
        'amount': (i * 104729) % 1000003 / 100,
        'tags': ['a$i', 'b${i % 13}'],
      },
  ];
  final text = jsonEncode(rows);
  final decoded = (jsonDecode(text) as List).cast<Map<String, dynamic>>();
  decoded.sort((a, b) {
    final byName = (a['name'] as String).compareTo(b['name'] as String);
    return byName != 0 ? byName : (a['number'] as int) - (b['number'] as int);
  });
  final buffer = StringBuffer();
  for (final row in decoded) {
    buffer
      ..write(row['id'])
      ..write(':')
      ..write((row['amount'] as num).toStringAsFixed(2))
      ..write(';');
  }
  return buffer.length + text.length;
}

/// Accumulates only the spans a widget benchmark asks it to time, so the
/// untimed parts of a sample — letting Drift answer, waiting for a row to
/// appear — stay out of the number.
class PerfTimer {
  final Stopwatch _watch = Stopwatch();

  /// Times [body] and adds it to this sample.
  Future<T> time<T>(Future<T> Function() body) async {
    _watch.start();
    try {
      return await body();
    } finally {
      _watch.stop();
    }
  }

  void _reset() => _watch.reset();

  double get _ms => _watch.elapsedMicroseconds / 1000;
}

/// A benchmark of code that needs no widget tree.
///
/// [id] is the stable key the history and the budgets are filed under:
/// `<area>.<what>`, lower snake case. **Renaming one starts its history over**
/// and orphans its budget, so do it only on purpose. [title] is what a person
/// reads in the summary and the alert.
///
/// [run] is one operation; a sample runs it [batch] times and records the time
/// per operation, so a sub-millisecond body is timed in a batch long enough
/// to measure. [setUp] runs once, untimed, before warm-up; [reset] runs after
/// every sample (and warm-up round), untimed — for an operation that leaves
/// something behind to tear down, which rules out a [batch].
void benchmark(
  String id, {
  required String title,
  required FutureOr<Object?> Function() run,
  FutureOr<void> Function()? setUp,
  FutureOr<void> Function()? reset,
  FutureOr<void> Function()? tearDown,
  int batch = 1,
  int warmup = 3,
  int samples = 15,
  Timeout timeout = const Timeout(Duration(minutes: 3)),
}) {
  assert(_validId.hasMatch(id), 'benchmark id "$id" is not <area>.<what>');
  assert(reset == null || batch == 1, 'a reset runs between single runs');
  test(id, () async {
    await setUp?.call();
    try {
      for (var i = 0; i < warmup; i++) {
        for (var b = 0; b < batch; b++) {
          perfSink = await run();
        }
        await reset?.call();
      }
      final ms = <double>[];
      final watch = Stopwatch();
      for (var i = 0; i < samples; i++) {
        watch
          ..reset()
          ..start();
        for (var b = 0; b < batch; b++) {
          perfSink = await run();
        }
        watch.stop();
        ms.add(watch.elapsedMicroseconds / 1000 / batch);
        await reset?.call();
      }
      _report(id, title, ms, batch: batch);
    } finally {
      await tearDown?.call();
    }
  }, timeout: timeout);
}

/// A benchmark of a mounted screen.
///
/// [setUp] mounts it and waits until it is ready; [run] is one sample, and
/// times only what it passes to [PerfTimer.time] — a frame, a resize, a
/// scroll step. [tearDown] runs whatever happens, inside the test body: a
/// screen over a real Drift database leaves timers that the binding checks
/// for before any `addTearDown` callback would run.
void widgetBenchmark(
  String id, {
  required String title,
  required Future<void> Function(WidgetTester tester) setUp,
  required Future<void> Function(WidgetTester tester, PerfTimer timer) run,
  Future<void> Function(WidgetTester tester)? tearDown,
  int warmup = 3,
  int samples = 15,
  Timeout timeout = const Timeout(Duration(minutes: 3)),
}) {
  assert(_validId.hasMatch(id), 'benchmark id "$id" is not <area>.<what>');
  testWidgets(
    id,
    (tester) async {
      try {
        await setUp(tester);
        final timer = PerfTimer();
        for (var i = 0; i < warmup; i++) {
          timer._reset();
          await run(tester, timer);
        }
        final ms = <double>[];
        for (var i = 0; i < samples; i++) {
          timer._reset();
          await run(tester, timer);
          ms.add(timer._ms);
        }
        _report(id, title, ms);
      } finally {
        await tearDown?.call(tester);
      }
      // Semantics off. An app builds its semantics tree only when an assistive
      // technology asks for it, so timing it here would count work most sessions
      // never do — and `flutter_test`'s always-on semantics intermittently
      // tripped a framework assertion on the invoice editor
      // (`!childSemantics.renderObject._needsLayout`) after every sample had
      // already been measured.
    },
    timeout: timeout,
    semanticsEnabled: false,
  );
}

final RegExp _validId = RegExp(r'^[a-z0-9_]+(\.[a-z0-9_]+)+$');

void _report(String id, String title, List<double> ms, {int batch = 1}) {
  final median = _percentile(ms, 50);
  final record = {
    'kind': 'benchmark',
    'id': id,
    'title': title,
    'unit': 'ms',
    'batch': batch,
    'samples': _round(ms),
    'median': _round3(median),
    'min': _round3(ms.reduce((a, b) => a < b ? a : b)),
    'p90': _round3(_percentile(ms, 90)),
  };
  _emit(record);
  // ignore: avoid_print
  print(
    'PERF $id  median ${median.toStringAsFixed(3)} ms  '
    'p90 ${record['p90']} ms  (n=${ms.length}${batch > 1 ? ' ×$batch' : ''})',
  );
}

void _emit(Map<String, Object?> record) {
  final path = _outPath;
  if (path == null || path.isEmpty) return;
  File(path).writeAsStringSync(
    '${jsonEncode(record)}\n',
    mode: FileMode.append,
    flush: true,
  );
}

double _percentile(List<double> values, int p) {
  final sorted = [...values]..sort();
  final rank = (p / 100) * (sorted.length - 1);
  final lo = rank.floor();
  final hi = rank.ceil();
  return sorted[lo] + (sorted[hi] - sorted[lo]) * (rank - lo);
}

double _round3(double v) => (v * 1000).roundToDouble() / 1000;
List<double> _round(List<double> values) => values.map(_round3).toList();
