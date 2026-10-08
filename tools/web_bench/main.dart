// Web benchmark harness: dart2wasm + skwasm against dart2js + CanvasKit, on
// the real app, in the installed Chrome.
//
//   tools/web_bench/build.sh                      # the two release builds
//   dart tools/web_bench/main.dart record         # capture the demo API once
//   dart tools/web_bench/main.dart run --phase startup|frames|compute
//   dart tools/web_bench/main.dart report         # summary.md
//
// Plain `dart:io`: no package, no chromedriver, no npm. Everything about why
// it is built this way — the replay server, the assertions that throw a
// sample out, what each number does and does not mean — is in
// docs/web-benchmarks.md.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'cdp.dart';
import 'report.dart';
import 'server.dart';

const _usage = '''
usage: dart tools/web_bench/main.dart <command> [options]

commands
  probe     one cold load per variant; prints what loaded and how
  record    run every phase once against the live demo API, storing responses
  run       measure (replay only); appends to <dir>/results.jsonl
  report    write <dir>/summary.md from results.jsonl

options
  --dir <path>       builds, fixtures and results      (default build/bench)
  --port <n>         must match the port the builds were made for (8791)
  --phase <name>     startup | frames | compute        (run)
  --config <name>    plain | iso | iso-st               (default plain)
  --rounds <n>       valid samples wanted per variant  (default 5)
  --budget <secs>    stop starting samples after this  (default 450)
  --max-load <n>     wait for the 1-min load average to drop below n
                     before each sample; give up after 5 minutes
  --variants <list>  js,wasm                           (default: the config's)
  --phases <list>    phases `record` runs              (default: all three)
  --headed           show the Chrome window
  --chrome <path>    Chrome binary
''';

/// How a build is served. `plain` is what a static host such as GitHub Pages
/// does; `iso` adds the cross-origin isolation headers that let skwasm use a
/// raster worker (and switch drift to OPFS — which is why JS gets them too);
/// `iso-st` keeps those headers but forces skwasm back to one thread, so the
/// threading gain can be told apart from the storage change.
class Config {
  const Config(
    this.name, {
    required this.isolated,
    required this.forceSingleThread,
    required this.variants,
  });
  final String name;
  final bool isolated;
  final bool forceSingleThread;
  final List<String> variants;

  static const all = {
    'plain': Config(
      'plain',
      isolated: false,
      forceSingleThread: false,
      variants: ['js', 'wasm'],
    ),
    'iso': Config(
      'iso',
      isolated: true,
      forceSingleThread: false,
      variants: ['js', 'wasm'],
    ),
    'iso-st': Config(
      'iso-st',
      isolated: true,
      forceSingleThread: true,
      variants: ['wasm'],
    ),
  };
}

class Options {
  String command = '';
  String dir = 'build/bench';
  int port = 8791;
  String phase = 'startup';
  String config = 'plain';
  int rounds = 5;
  int budget = 450;
  double maxLoad = 0;
  bool headed = false;
  String chrome = kDefaultChromeBinary;
  List<String>? variants;
  List<String> recordPhases = const ['startup', 'frames', 'compute'];

  static Options parse(List<String> args) {
    final options = Options();
    if (args.isEmpty) return options;
    options.command = args.first;
    for (var i = 1; i < args.length; i++) {
      String value() {
        if (i + 1 >= args.length) {
          throw FormatException('${args[i]} needs a value');
        }
        return args[++i];
      }

      switch (args[i]) {
        case '--dir':
          options.dir = value();
        case '--port':
          options.port = int.parse(value());
        case '--phase':
          options.phase = value();
        case '--config':
          options.config = value();
        case '--rounds':
          options.rounds = int.parse(value());
        case '--budget':
          options.budget = int.parse(value());
        case '--max-load':
          options.maxLoad = double.parse(value());
        case '--variants':
          options.variants = value().split(',');
        case '--phases':
          options.recordPhases = value().split(',');
        case '--headed':
          options.headed = true;
        case '--chrome':
          options.chrome = value();
        default:
          throw FormatException('unknown option ${args[i]}');
      }
    }
    return options;
  }
}

const _width = 1440;
const _height = 900;
const _scale = 2.0;

/// A point inside the content pane at 1440×900 — right of the 232 px sidebar,
/// below the top bar — where the wheel is aimed. Never trusted: every scroll
/// asks the app which scrollable is really under it.
const _aimX = 836.0;
const _aimY = 560.0;

/// The navigation tour: every entity list the demo has rows for, the report
/// screen, a settings form, and back. Run twice — the first visit builds each
/// screen for the first time (compilers warm up very differently), the second
/// is the steady state.
const _tour = [
  '/clients',
  '/products',
  '/invoices',
  '/quotes',
  '/credits',
  '/payments',
  '/expenses',
  '/tasks',
  '/projects',
  '/vendors',
  '/recurring_invoices',
  '/transactions',
  '/reports',
  '/settings/company_details',
  '/dashboard',
];

const _computeBenchmarks = [
  'totals',
  'report',
  'snapshot_parse',
  'json_decode',
  'html_markdown',
];

/// Injected before any page script. Stamps everything on the page's own
/// `performance.now()` clock — the same clock the engine's frame timings use —
/// so nothing has to be reconciled across processes.
const _initScript = r'''
(() => {
  if (window.__benchPage) return;
  const B = { firstFrame: null, marks: [], console: [], longtasks: [], errors: [], raf: null };
  window.__benchPage = B;
  window.addEventListener('flutter-first-frame', () => {
    if (B.firstFrame === null) B.firstFrame = performance.now();
  });
  for (const level of ['log', 'info', 'warn', 'error']) {
    const original = console[level].bind(console);
    console[level] = (...args) => {
      try {
        const now = performance.now();
        const text = args.map(String).join(' ');
        const mark = /main\.boot: (.+): (\d+)ms \(t\+(\d+)ms\)/.exec(text);
        if (mark) {
          B.marks.push([mark[1], now, Number(mark[2]), Number(mark[3])]);
        } else if (B.console.length < 300) {
          B.console.push([level, Math.round(now), text.slice(0, 500)]);
        }
      } catch (e) {}
      original(...args);
    };
  }
  try {
    new PerformanceObserver((list) => {
      for (const e of list.getEntries()) B.longtasks.push([e.startTime, e.duration]);
    }).observe({ type: 'longtask', buffered: true });
  } catch (e) {}
  window.addEventListener('error', (e) => B.errors.push(String(e.message)));
  window.addEventListener('unhandledrejection', (e) => B.errors.push('unhandled: ' + String(e.reason)));
  B.rafStart = () => {
    B.raf = [];
    const tick = (t) => {
      if (B.raf === null) return;
      B.raf.push(t);
      requestAnimationFrame(tick);
    };
    requestAnimationFrame(tick);
  };
  B.rafStop = () => { const r = B.raf || []; B.raf = null; return r; };
  B.gl = () => {
    const gl = document.createElement('canvas').getContext('webgl2');
    if (!gl) return 'none';
    const ext = gl.getExtension('WEBGL_debug_renderer_info');
    return String(ext ? gl.getParameter(ext.UNMASKED_RENDERER_WEBGL) : gl.getParameter(gl.RENDERER));
  };
  B.snapshot = () => {
    const nav = performance.getEntriesByType('navigation')[0];
    const res = performance.getEntriesByType('resource')
      .filter((r) => /main\.dart\.|canvaskit|skwasm|sqlite3|drift_worker|flutter/.test(r.name))
      .map((r) => [r.name.replace(location.origin, ''), Math.round(r.startTime), Math.round(r.responseEnd), r.transferSize]);
    return JSON.stringify({
      timeOrigin: performance.timeOrigin,
      now: performance.now(),
      firstFrame: B.firstFrame,
      marks: B.marks,
      console: B.console,
      errors: B.errors,
      longtasks: B.longtasks,
      hash: location.hash,
      isolated: window.crossOriginIsolated === true,
      canvaskit: typeof window.flutterCanvasKit !== 'undefined',
      skwasm: typeof window._flutter_skwasmInstance !== 'undefined',
      responseEnd: nav ? nav.responseEnd : null,
      resources: res,
      dpr: window.devicePixelRatio,
      inner: [window.innerWidth, window.innerHeight],
      visibility: document.visibilityState,
      focus: document.hasFocus(),
    });
  };
})();
''';

Future<void> main(List<String> args) async {
  final Options options;
  try {
    options = Options.parse(args);
  } on FormatException catch (e) {
    stderr.writeln('${e.message}\n\n$_usage');
    exitCode = 64;
    return;
  }
  switch (options.command) {
    case 'probe':
      await _withServer(options, record: true, (bench) => bench.probe());
    case 'record':
      await _withServer(options, record: true, (bench) => bench.record());
    case 'run':
      await _withServer(options, record: false, (bench) => bench.run());
    case 'report':
      writeReport(Directory(options.dir));
    default:
      stdout.writeln(_usage);
      exitCode = options.command.isEmpty ? 0 : 64;
  }
}

Future<void> _withServer(
  Options options,
  Future<void> Function(Bench bench) body, {
  required bool record,
}) async {
  final dir = Directory(options.dir);
  final config = Config.all[options.config];
  if (config == null) {
    stderr.writeln('unknown --config ${options.config}');
    exitCode = 64;
    return;
  }
  for (final variant in options.variants ?? config.variants) {
    if (!File('${dir.path}/$variant/index.html').existsSync()) {
      stderr.writeln(
        'no build at ${dir.path}/$variant — run tools/web_bench/build.sh',
      );
      exitCode = 66;
      return;
    }
  }
  final server = await BenchServer.start(
    port: options.port,
    fixtureDir: Directory('${dir.path}/fixtures'),
    record: record,
  );
  if (!record) {
    final day = server.recordedDay;
    if (day != localDay()) {
      stderr.writeln(
        'fixtures were recorded on ${day ?? '(never)'}, today is '
        '${localDay()}: the dashboard asks for date-keyed data, so a '
        'recording is only replayable on its own day. Delete '
        '${dir.path}/fixtures and run `record` again.',
      );
      await server.close();
      exitCode = 65;
      return;
    }
  }
  try {
    await body(Bench(options, config, dir, server));
  } finally {
    await server.close();
  }
}

class Bench {
  Bench(this.options, this.config, this.dir, this.server);
  final Options options;
  final Config config;
  final Directory dir;
  final BenchServer server;

  List<String> get variants => options.variants ?? config.variants;
  String get _base => 'http://127.0.0.1:${options.port}';
  bool get _recording => server.record;

  // -------------------------------------------------------------------------
  // Commands
  // -------------------------------------------------------------------------

  Future<void> probe() async {
    for (final variant in variants) {
      final session = await _open(variant);
      try {
        final load = await session.load('cold');
        final env = await session.environment();
        stdout
          ..writeln('== $variant (${config.name})')
          ..writeln(const JsonEncoder.withIndent('  ').convert(env))
          ..writeln(
            const JsonEncoder.withIndent(
              '  ',
            ).convert(Map.of(load)..remove('fetched')),
          )
          ..writeln('fetched: ${load['fetched']}')
          ..writeln('scrollable: ${await session.scrollable()}');
        final step = await session.transition('probe', '/expenses');
        stdout.writeln(
          'hash nav -> ${step['hash']} frames=${(step['frames'] as List).length} '
          'timedOut=${step['timedOut']}',
        );
        final scroll = await session.scroll('probe-scroll', passes: 1);
        stdout.writeln(
          'scroll: frames=${(scroll['frames'] as List).length} '
          'moved=${scroll['moved']} max=${scroll['max']} '
          'problems=${session.problems}',
        );
      } finally {
        await session.close();
      }
    }
    stdout.writeln(
      'upstream calls: ${server.upstreamCalls}, fixtures: '
      '${server.fixtureCount}, misses: ${server.replayMisses}',
    );
  }

  /// One pass of every phase per variant with misses forwarded upstream.
  /// Repeat until it reports zero upstream calls: the second pass replays the
  /// first at full speed, which is the only way to meet the requests whose
  /// shape depends on what has already landed (a cursor'd page 1).
  Future<void> record() async {
    final out = File('${dir.path}/record.jsonl');
    for (final phase in options.recordPhases) {
      for (final variant in variants) {
        final sample = await _sample(phase, variant, 0);
        out.writeAsStringSync('${jsonEncode(sample)}\n', mode: FileMode.append);
        stdout.writeln(
          'recorded $phase/$variant: problems=${sample['problems']} '
          'upstream so far=${server.upstreamCalls}',
        );
      }
    }
    stdout.writeln(
      'record pass done: ${server.upstreamCalls} upstream calls, '
      '${server.fixtureCount} fixtures, ${server.writeGuardHits} writes '
      'refused',
    );
  }

  Future<void> run() async {
    final out = File('${dir.path}/results.jsonl');
    final have = <String, int>{for (final v in variants) v: 0};
    if (out.existsSync()) {
      for (final line in out.readAsLinesSync()) {
        if (line.trim().isEmpty) continue;
        final sample = jsonDecode(line) as Map<String, dynamic>;
        final mine =
            sample['phase'] == options.phase &&
            sample['config'] == config.name &&
            (sample['problems'] as List).isEmpty;
        if (mine && have.containsKey(sample['variant'])) {
          have[sample['variant'] as String] = have[sample['variant']]! + 1;
        }
      }
    }
    final started = DateTime.now();
    var longest = Duration.zero;
    var attempt = 0;
    while (have.values.any((n) => n < options.rounds)) {
      // Alternate who goes first, so a machine that warms up or gets busy
      // part-way through costs both variants the same.
      final order = attempt.isEven ? variants : variants.reversed.toList();
      attempt++;
      for (final variant in order) {
        if (have[variant]! >= options.rounds) continue;
        final elapsed = DateTime.now().difference(started);
        if (elapsed + longest * 1.25 > Duration(seconds: options.budget)) {
          stdout.writeln('budget reached: $have of ${options.rounds}');
          return;
        }
        if (!await _waitForQuiet()) return;
        final before = DateTime.now();
        final sample = await _sample(options.phase, variant, have[variant]!);
        final took = DateTime.now().difference(before);
        if (took > longest) longest = took;
        out.writeAsStringSync('${jsonEncode(sample)}\n', mode: FileMode.append);
        final problems = sample['problems'] as List;
        if (problems.isEmpty) have[variant] = have[variant]! + 1;
        stdout.writeln(
          '${options.phase}/${config.name}/$variant '
          '#${have[variant]} ${took.inSeconds}s '
          '${problems.isEmpty ? 'ok' : 'INVALID $problems'} '
          '${_headline(sample)}',
        );
      }
      if (attempt > options.rounds * 4) {
        stdout.writeln('giving up: too many invalid samples');
        return;
      }
    }
    stdout.writeln('complete: $have');
  }

  /// Holds a sample back while the machine is busy with something else. A
  /// build or an encode running alongside does not bias the comparison (the
  /// variants alternate) but it does wreck the tails. False = gave up.
  Future<bool> _waitForQuiet() async {
    if (options.maxLoad <= 0) return true;
    final deadline = DateTime.now().add(const Duration(minutes: 5));
    while (true) {
      final load = double.tryParse(_loadAverage().split(RegExp(r'\s+')).first);
      if (load == null || load <= options.maxLoad) return true;
      if (DateTime.now().isAfter(deadline)) {
        stdout.writeln('load average $load stayed above ${options.maxLoad}');
        return false;
      }
      await Future<void>.delayed(const Duration(seconds: 5));
    }
  }

  String _headline(Map<String, dynamic> sample) {
    final loads = (sample['loads'] as List).cast<Map<String, dynamic>>();
    final cold = loads.isEmpty ? null : loads.first;
    return 'firstFrame=${cold?['firstFrame']}ms ready=${cold?['ready']}ms '
        'load=${sample['loadavg']}';
  }

  // -------------------------------------------------------------------------
  // One sample = one Chrome on a fresh profile
  // -------------------------------------------------------------------------

  Future<Session> _open(String variant) async {
    await server.serve(
      Directory('${dir.path}/$variant'),
      isolated: config.isolated,
      forceSingleThread: config.forceSingleThread,
    );
    server.resetCounters();
    final chrome = await Chrome.launch(
      binary: options.chrome,
      headless: !options.headed,
      width: _width,
      height: _height,
      deviceScaleFactor: _scale,
      initScript: _initScript,
    );
    await chrome.send('Performance.enable');
    return Session(this, chrome, variant);
  }

  Future<Map<String, dynamic>> _sample(
    String phase,
    String variant,
    int round,
  ) async {
    final session = await _open(variant);
    final sample = <String, dynamic>{
      'v': 1,
      'phase': phase,
      'config': config.name,
      'variant': variant,
      'round': round,
      'at': DateTime.now().toIso8601String(),
      'loadavg': _loadAverage(),
      'recording': _recording,
    };
    final loads = <Map<String, dynamic>>[];
    final segments = <Map<String, dynamic>>[];
    try {
      loads.add(await session.load('cold'));
      switch (phase) {
        case 'startup':
          for (var i = 1; i <= 3; i++) {
            loads.add(await session.load('warm$i'));
          }
        case 'frames':
          for (final pass in ['tour1', 'tour2']) {
            for (final route in _tour) {
              segments.add(await session.transition(pass, route));
            }
          }
          segments.add(await session.scroll('scroll:dashboard', passes: 4));
          await session.transition('goto', '/expenses');
          segments.add(await session.scroll('scroll:expenses', passes: 3));
          await session.transition('goto', '/products');
          segments.add(await session.scroll('scroll:products', passes: 3));
          final client = _firstId('/api/v1/clients');
          final invoice = _firstId('/api/v1/invoices');
          if (client == null || invoice == null) {
            session.problems.add('no client/invoice id in the fixtures');
          } else {
            await session.transition('goto', '/clients');
            segments.add(
              await session.transition('open:client', '/clients/$client'),
            );
            await session.transition('goto', '/invoices');
            segments.add(
              await session.transition(
                'open:invoice-edit',
                '/invoices/$invoice/edit?view=full',
                window: const Duration(seconds: 2),
              ),
            );
          }
          await session.transition('goto', '/dashboard');
          segments.add(await session.resize());
          sample['heap'] = await session.heap();
        case 'compute':
          final results = <Map<String, dynamic>>[];
          for (final name in _computeBenchmarks) {
            results.add(
              await session.chrome.evalJson(
                "__inBench.compute('$name')",
                awaitPromise: true,
              ),
            );
          }
          sample['compute'] = results;
      }
      sample['env'] = await session.environment();
      session.finish();
    } on Object catch (error) {
      session.problems.add('threw: $error');
    } finally {
      await session.close();
    }
    sample['loads'] = loads;
    sample['segments'] = segments;
    sample['replayMisses'] = server.replayMisses;
    sample['missedKeys'] = server.missedKeys.take(10).toList();
    sample['upstreamCalls'] = server.upstreamCalls;
    sample['problems'] = session.problems;
    return sample;
  }

  /// The first row id of a recorded page-1 list — the record to open.
  String? _firstId(String path) {
    final bytes = server.fixtureBody(
      (key) => key.startsWith('GET $path?') && key.contains('page=1&'),
    );
    if (bytes == null) return null;
    final data =
        (jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>)['data'];
    if (data is! List || data.isEmpty) return null;
    return (data.first as Map<String, dynamic>)['id'] as String?;
  }

  String _loadAverage() {
    try {
      final result = Process.runSync('sysctl', ['-n', 'vm.loadavg']);
      return (result.stdout as String).replaceAll(RegExp('[{}]'), '').trim();
    } on Object {
      return '';
    }
  }
}

class Session {
  Session(this.bench, this.chrome, this.variant);
  final Bench bench;
  final Chrome chrome;
  final String variant;
  final List<String> problems = [];
  int _frameCursor = 0;

  BenchServer get _server => bench.server;
  bool get _recording => _server.record;

  Future<void> close() => chrome.close();

  double _round(num value) => (value * 10).roundToDouble() / 10;

  Future<double> _now() async =>
      ((await chrome.eval('performance.now()'))! as num).toDouble();

  // -------------------------------------------------------------------------
  // Loading
  // -------------------------------------------------------------------------

  /// Navigates to the dashboard and waits until it has stopped loading and
  /// drawing. `cold` is a profile that has never seen the app; `warmN` is the
  /// Nth return visit in the same profile (HTTP cache, compiled-code cache,
  /// restored session, populated local database).
  Future<Map<String, dynamic>> load(String kind) async {
    if (kind != 'cold') {
      // Never reload in place: leave the page, and wait for its workers to
      // die, or the next open finds the database still held.
      await chrome.navigate('about:blank');
      final deadline = DateTime.now().add(const Duration(seconds: 15));
      while (await chrome.backgroundWorkers(bench._base) > 0) {
        if (DateTime.now().isAfter(deadline)) {
          problems.add('$kind: workers still alive after 15 s');
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      // Chrome writes its compiled-code caches lazily after a load.
      await Future<void>.delayed(const Duration(milliseconds: 2500));
    }
    _server.takeLog();
    _frameCursor = 0;
    chrome.resetNavigationCount();
    final metricsBefore = await _taskSeconds();
    await chrome.navigate('${bench._base}/#/dashboard');

    final deadline = DateTime.now().add(
      Duration(seconds: _recording ? 180 : 90),
    );
    while (true) {
      final ready = await chrome.eval(
        'window.__benchPage && window.__benchPage.firstFrame !== null '
        '&& typeof window.__inBench !== "undefined"',
      );
      if (ready == true) break;
      if (DateTime.now().isAfter(deadline)) {
        problems.add('$kind: no first frame');
        return {'kind': kind};
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    await chrome.eval('__inBench.arm()');
    final settle = await _settle(
      quiet: const Duration(milliseconds: 800),
      timeout: Duration(seconds: _recording ? 120 : 45),
    );
    final end = await _now();
    final page = await chrome.evalJson('__benchPage.snapshot()');
    final info = await chrome.evalJson('__inBench.info()');
    final frames = await _collect(0, end);
    final metricsAfter = await _taskSeconds();
    final log = _server.takeLog();

    final origin = (page['timeOrigin'] as num).toDouble();
    final firstFrame = (page['firstFrame'] as num).toDouble();
    final marks = (page['marks'] as List).cast<List<dynamic>>();
    final apiIdle = _server.lastApiEndMicros / 1000 - origin;
    // Ready = the last API response has landed AND the frames that drew it
    // are done. Frames after a 250 ms lull are timers, not the dashboard
    // still arriving.
    var ready = firstFrame > apiIdle ? firstFrame : apiIdle;
    for (final frame in frames) {
      final end = frame[0] + frame[1] / 1000 + frame[2] / 1000;
      if (end <= apiIdle) continue;
      if (frame[0] - ready > 250) break;
      if (end > ready) ready = end;
    }
    final tasks = (page['longtasks'] as List).cast<List<dynamic>>().where(
      (t) => (t[0] as num) < ready,
    );
    final statics = [
      for (final e in log)
        if (!e.api) e.toJson(),
    ];
    final api = [
      for (final e in log)
        if (e.api) e,
    ];

    _checkLoad(kind, page, info, marks, statics, settle);
    return {
      'kind': kind,
      'firstFrame': _round(firstFrame),
      // The boot stopwatch starts as Dart `main` gets going, so the first
      // mark's own offset dates the moment the engine handed over.
      'dartStart': marks.isEmpty
          ? null
          : _round((marks.first[1] as num) - (marks.first[3] as num)),
      'apiIdle': _round(apiIdle),
      'ready': _round(ready),
      'marks': [
        for (final m in marks) [m[0], _round(m[1] as num), m[2], m[3]],
      ],
      'longTaskMs': _round(tasks.fold<double>(0, (s, t) => s + (t[1] as num))),
      'blockedMs': _round(
        tasks.fold<double>(
          0,
          (s, t) => s + ((t[1] as num) > 50 ? (t[1] as num) - 50 : 0),
        ),
      ),
      'taskSeconds': metricsAfter >= metricsBefore
          ? _round((metricsAfter - metricsBefore) * 1000) / 1000
          : metricsAfter,
      'framesToReady': frames.length,
      'navigations': chrome.mainFrameNavigations,
      'hash': page['hash'],
      'apiCalls': api.length,
      'apiBytes': api.fold<int>(0, (s, e) => s + e.bytes),
      'fetched': statics,
      'resources': page['resources'],
      'warnings': [
        for (final line in (page['console'] as List).cast<List<dynamic>>())
          if (line[0] != 'log' ||
              (line[2] as String).contains('[WARNING]') ||
              (line[2] as String).contains('[SEVERE]'))
            line[2],
      ],
      'errors': page['errors'],
      'settleTimedOut': settle,
    };
  }

  void _checkLoad(
    String kind,
    Map<String, dynamic> page,
    Map<String, dynamic> info,
    List<List<dynamic>> marks,
    List<List<Object>> statics,
    bool settleTimedOut,
  ) {
    void fail(String why) => problems.add('$kind: $why');
    final wasm = variant == 'wasm';
    if (info['wasm'] != wasm) fail('compiled as wasm=${info['wasm']}');
    if (info['release'] != true) fail('not a release build');
    if (page['skwasm'] != wasm) fail('skwasm loaded=${page['skwasm']}');
    if (page['canvaskit'] != !wasm) {
      fail('canvaskit loaded=${page['canvaskit']}');
    }
    if (page['isolated'] != bench.config.isolated) {
      fail('crossOriginIsolated=${page['isolated']}');
    }
    final hash = page['hash'] as String;
    if (!hash.startsWith('#/dashboard')) fail('landed on $hash');
    if (chrome.mainFrameNavigations != 1) {
      fail('${chrome.mainFrameNavigations} main-frame navigations');
    }
    if (page['visibility'] != 'visible') fail('page ${page['visibility']}');
    if ((page['errors'] as List).isNotEmpty) {
      fail('page errors ${page['errors']}');
    }
    if (settleTimedOut) fail('never went quiet');

    final stages = [for (final m in marks) m[0] as String];
    final expected = [
      'diagnostics',
      'db-open (incl. secure-storage key)',
      'restore (auth/theme/locale/sidebar)',
      if (kind == 'cold') 'demo token bootstrap',
      'statics warm',
      'nav-state + route resolve',
      'first frame',
    ];
    if (stages.join('|') != expected.join('|')) fail('boot marks $stages');

    if (kind == 'cold') {
      final paths = {for (final s in statics) s[0] as String};
      final binary = wasm ? '/main.dart.wasm' : '/main.dart.js';
      final other = wasm ? '/main.dart.js' : '/main.dart.wasm';
      if (!paths.contains(binary)) fail('never fetched $binary');
      if (paths.contains(other)) fail('fetched $other');
    }
    if (!_recording && _server.replayMisses > 0) {
      fail(
        '${_server.replayMisses} replay misses: ${_server.missedKeys.take(3)}',
      );
    }
    if (_server.writeGuardHits > 0) fail('${_server.writeGuardHits} writes');
  }

  Future<double> _taskSeconds() async {
    final response = await chrome.send('Performance.getMetrics');
    for (final metric
        in (response['metrics'] as List).cast<Map<String, dynamic>>()) {
      if (metric['name'] == 'TaskDuration') {
        return (metric['value'] as num).toDouble();
      }
    }
    return 0;
  }

  /// Waits until the app has neither drawn a frame, nor had one scheduled, nor
  /// had an API call open, for [quiet]. Returns true if it never happened.
  Future<bool> _settle({
    required Duration quiet,
    required Duration timeout,
  }) async {
    final started = DateTime.now();
    var lastBusy = DateTime.now();
    var lastFrames = -1;
    var lastApi = _server.lastApiEndMicros;
    while (true) {
      final pulse = await chrome.evalJson('__inBench.pulse()');
      final frames = pulse['frames'] as int;
      final busy =
          frames != lastFrames ||
          pulse['scheduled'] == true ||
          _server.inflightApi > 0 ||
          _server.lastApiEndMicros != lastApi;
      final now = DateTime.now();
      if (busy) {
        lastBusy = now;
        lastFrames = frames;
        lastApi = _server.lastApiEndMicros;
      } else if (now.difference(lastBusy) >= quiet) {
        return false;
      }
      if (now.difference(started) > timeout) return true;
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
  }

  /// Frame timings whose build started inside [from]..[to] (page ms), as
  /// `[start ms, build µs, raster µs]`. The engine only hands timings over on
  /// a frame, at most every 100 ms — so ask for one, and wait for it.
  Future<List<List<num>>> _collect(double from, double to) async {
    final rows = <List<dynamic>>[];
    for (var attempt = 0; attempt < 4; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 130));
      await chrome.eval('__inBench.flush()');
      await Future<void>.delayed(const Duration(milliseconds: 90));
      final data = await chrome.evalJson('__inBench.frames($_frameCursor)');
      _frameCursor = data['next'] as int;
      rows.addAll((data['rows'] as List).cast<List<dynamic>>());
      // The flush frame itself starts after [to]; seeing it means everything
      // before it has been delivered.
      if (rows.any((r) => (r[0] as num) / 1000 > to)) break;
    }
    return [
      for (final r in rows)
        if ((r[0] as num) / 1000 >= from && (r[0] as num) / 1000 <= to)
          [_round((r[0] as num) / 1000), r[1] as num, r[2] as num],
    ];
  }

  // -------------------------------------------------------------------------
  // Scenarios
  // -------------------------------------------------------------------------

  Future<Map<String, dynamic>> _segment(
    String group,
    String name,
    Future<void> Function() act, {
    Duration timeout = const Duration(seconds: 12),
    Duration quiet = const Duration(milliseconds: 350),
    Duration? window,
  }) async {
    final start = await chrome.eval(
      '(() => { __benchPage.rafStart(); return performance.now(); })()',
    );
    final from = (start! as num).toDouble();
    await act();
    // A screen that never stops drawing (a focused text field animates its
    // caret at 60 fps on macOS) cannot be waited out; it gets a fixed window.
    var timedOut = false;
    if (window != null) {
      await Future<void>.delayed(window);
    } else {
      timedOut = await _settle(
        quiet: quiet,
        timeout: _recording ? const Duration(seconds: 60) : timeout,
      );
    }
    final to = await _now();
    final raf = ((await chrome.eval('__benchPage.rafStop()'))! as List)
        .cast<num>();
    final frames = await _collect(from, to);
    final tasks = ((await chrome.eval('__benchPage.longtasks'))! as List)
        .cast<List<dynamic>>()
        .where((t) => (t[0] as num) >= from && (t[0] as num) <= to)
        .toList();
    if (timedOut) problems.add('$group $name: never went quiet');
    return {
      'group': group,
      'name': name,
      // From the action to the end of the last frame it caused.
      'settledMs': frames.isEmpty
          ? 0
          : _round(
              frames.last[0] +
                  frames.last[1] / 1000 +
                  frames.last[2] / 1000 -
                  from,
            ),
      'drawnMs': window == null ? _round(_burstEnd(frames, from)) : null,
      'windowMs': ?window?.inMilliseconds,
      'frames': [
        for (final f in frames) [_round(f[0] - from), f[1], f[2]],
      ],
      'rafGaps': [
        for (var i = 1; i < raf.length; i++) _round(raf[i] - raf[i - 1]),
      ],
      'blockedMs': _round(
        tasks.fold<double>(
          0,
          (s, t) => s + ((t[1] as num) > 50 ? (t[1] as num) - 50 : 0),
        ),
      ),
      'timedOut': timedOut,
    };
  }

  /// When the first run of frames after [from] ended — the moment the screen
  /// had arrived. A frame that follows a 250 ms lull is a timer firing, not
  /// the screen still arriving, and is not counted.
  double _burstEnd(List<List<num>> frames, double from) {
    double? end;
    for (final frame in frames) {
      final start = frame[0] - from;
      if (end != null && start - end > 250) break;
      end = start + frame[1] / 1000 + frame[2] / 1000;
    }
    return end ?? 0;
  }

  /// Routes the running app by its URL hash, the way a typed address or the
  /// browser's back button does.
  Future<Map<String, dynamic>> transition(
    String group,
    String route, {
    Duration? window,
  }) async {
    // The app draws one small frame about 500 ms after every navigation. A
    // quiet period shorter than that would include it for a slow build and
    // miss it for a fast one, so wait long enough to see it either way.
    final segment = await _segment(
      group,
      route,
      () async {
        await chrome.eval("location.hash = '#$route'");
      },
      quiet: const Duration(milliseconds: 700),
      window: window,
    );
    final hash = (await chrome.eval('location.hash'))! as String;
    segment['hash'] = hash;
    if (!hash.startsWith('#${route.split('?').first}')) {
      problems.add('$group $route: landed on $hash');
    }
    if (group != 'goto' &&
        group != 'probe' &&
        (segment['frames'] as List).isEmpty) {
      problems.add('$group $route: drew no frames');
    }
    return segment;
  }

  Future<Map<String, dynamic>> scrollable() =>
      chrome.evalJson('__inBench.scrollableAt($_aimX, $_aimY)');

  /// Wheels the list under the aim point to its end and back, [passes] times:
  /// one wheel event per ~16 ms, each a 60 px jump (the app applies a wheel
  /// delta immediately, so every event is a frame of newly exposed rows).
  Future<Map<String, dynamic>> scroll(
    String name, {
    required int passes,
  }) async {
    const step = 60.0;
    final before = await scrollable();
    if (before['found'] != true) {
      problems.add('$name: ${before['why']}');
      return {'group': 'scroll', 'name': name, 'frames': <Object>[]};
    }
    var farthest = 0.0;
    var extent = (before['max'] as num).toDouble();
    final segment = await _segment('scroll', name, () async {
      await chrome.mouseMove(_aimX, _aimY);
      Future<void> ticks(int count, int direction) async {
        for (var i = 0; i < count; i++) {
          final tick = DateTime.now();
          await chrome.wheel(_aimX, _aimY, direction * step);
          final spent = DateTime.now().difference(tick);
          const frame = Duration(microseconds: 16667);
          if (spent < frame) await Future<void>.delayed(frame - spent);
        }
      }

      for (var pass = 0; pass < passes; pass++) {
        var travelled = 0;
        var pixels = 0.0;
        // Down until the list really ends. Its extent is not known up front:
        // the app shows a window of rows and widens it — and fetches the next
        // page — only as the scroll gets near the edge.
        for (var leg = 0; leg < 12; leg++) {
          final count = ((extent - pixels) / step).ceil() + 4;
          await ticks(count, 1);
          travelled += count;
          await Future<void>.delayed(const Duration(milliseconds: 300));
          final probe = await scrollable();
          pixels = (probe['pixels'] as num?)?.toDouble() ?? pixels;
          extent = (probe['max'] as num?)?.toDouble() ?? extent;
          if (pixels > farthest) farthest = pixels;
          if (extent - pixels < 5) break;
        }
        await ticks(travelled, -1);
      }
    }, timeout: const Duration(seconds: 40));
    segment
      ..['moved'] = _round(farthest)
      ..['max'] = _round(extent);
    if (farthest < 200) problems.add('$name: scrolled only $farthest px');
    return segment;
  }

  /// Drags the window from 1440 px down to 520 px wide and back, 40 px at a
  /// time — every step relays out the whole dashboard and crosses the app's
  /// wide / narrow breakpoints.
  Future<Map<String, dynamic>> resize() async {
    Future<void> width(int value) =>
        chrome.send('Emulation.setDeviceMetricsOverride', {
          'width': value,
          'height': _height,
          'deviceScaleFactor': _scale,
          'mobile': false,
        });
    final segment = await _segment('resize', 'resize:dashboard', () async {
      final widths = [for (var w = _width; w >= 520; w -= 40) w];
      for (final w in [...widths, ...widths.reversed]) {
        await width(w);
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }, timeout: const Duration(seconds: 20));
    await width(_width);
    return segment;
  }

  Future<Map<String, dynamic>> heap() async {
    await chrome.send('HeapProfiler.collectGarbage');
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final usage = await chrome.send('Runtime.getHeapUsage');
    return {
      'usedMb': _round((usage['usedSize'] as num) / 1048576),
      'totalMb': _round((usage['totalSize'] as num) / 1048576),
      'taskSeconds': await _taskSeconds(),
    };
  }

  /// What the numbers were taken on — recorded with every sample so a report
  /// can refuse to mix environments.
  Future<Map<String, dynamic>> environment() async {
    final version = await chrome.browser('Browser.getVersion');
    await chrome.eval('__benchPage.rafStart()');
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final raf = ((await chrome.eval('__benchPage.rafStop()'))! as List)
        .cast<num>();
    final gaps = [for (var i = 1; i < raf.length; i++) raf[i] - raf[i - 1]]
      ..sort();
    final gl = (await chrome.eval('__benchPage.gl()'))! as String;
    final info = await chrome.evalJson('__inBench.info()');
    if (RegExp(
      'swiftshader|llvmpipe|software|none',
      caseSensitive: false,
    ).hasMatch(gl)) {
      problems.add('no hardware GL: $gl');
    }
    return {
      'chrome': version['product'],
      'gl': gl,
      'rafMs': gaps.isEmpty ? null : _round(gaps[gaps.length ~/ 2]),
      'sha': info['sha'],
      'headless': !bench.options.headed,
      'viewport': '$_width×$_height@$_scale',
    };
  }

  void finish() {
    if (!_recording && _server.replayMisses > 0) {
      problems.add(
        '${_server.replayMisses} replay misses: '
        '${_server.missedKeys.take(3).toList()}',
      );
    }
    if (_server.writeGuardHits > 0) {
      problems.add('${_server.writeGuardHits} writes refused');
    }
  }
}
