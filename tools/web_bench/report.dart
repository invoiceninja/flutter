// Turns results.jsonl into summary.md (and summary.json, the same numbers for
// a chart). Only samples that passed every assertion are counted; the report
// says how many did not.
//
// Every figure is a median across samples of a per-sample statistic, with the
// spread beside it — never a pooled mean, which one noisy sample can drag.

import 'dart:convert';
import 'dart:io';

typedef _Sample = Map<String, dynamic>;

const _labels = {
  'tour1': 'Navigation tour — first visit (15 screens)',
  'tour2': 'Navigation tour — steady state (15 screens)',
  'scroll:dashboard': 'Scroll the dashboard',
  'scroll:expenses': 'Scroll the Expenses list (78 rows, 2 pages)',
  'scroll:products': 'Scroll the Products list (50 rows)',
  'open:client': 'Open a client record',
  'open:invoice-edit': 'Open the invoice editor (first 2 s)',
  'resize:dashboard': 'Resize the window 1440 → 520 → 1440 px',
};

const _computeLabels = {
  'totals':
      'Invoice totals — one 50-line invoice (arbitrary-precision decimal)',
  'report': 'Report engine — group + sort 5,000 rows',
  'snapshot_parse':
      'Cold-boot parse — `jsonDecode` + typed `fromJson` of the 3 MB login '
      'response',
  'json_decode': '`jsonDecode` alone, same 3 MB (`JSON.parse` under dart2js)',
  'html_markdown': 'Legacy HTML → Markdown, 40 KB (regex-heavy)',
};

const _configLabels = {
  'plain': 'Plain static hosting (how the live demo is served)',
  'iso': 'Cross-origin isolated (COOP + COEP) — skwasm multi-threaded',
  'iso-st': 'Cross-origin isolated, skwasm forced single-threaded',
};

void writeReport(Directory dir) {
  final file = File('${dir.path}/results.jsonl');
  if (!file.existsSync()) {
    stderr.writeln('no ${file.path} — nothing measured yet');
    exitCode = 66;
    return;
  }
  final all = <_Sample>[
    for (final line in file.readAsLinesSync())
      if (line.trim().isNotEmpty) jsonDecode(line) as _Sample,
  ];
  final valid = [
    for (final s in all)
      if ((s['problems'] as List).isEmpty) s,
  ];
  final out = StringBuffer();
  final data = <String, dynamic>{};

  _environment(out, data, dir, all, valid);
  _sizes(out, data, dir, valid);
  for (final config in ['plain', 'iso']) {
    final mine = [
      for (final s in valid)
        if (s['config'] == config) s,
    ];
    if (mine.isEmpty) continue;
    final section = <String, dynamic>{};
    data[config] = section;
    out.writeln('\n## ${_configLabels[config]}\n');
    _startup(out, section, mine);
    _frames(out, section, mine);
    _compute(out, section, mine);
    _memory(out, section, mine);
  }
  _threads(out, data, valid);
  _method(out);

  File('${dir.path}/summary.md').writeAsStringSync(out.toString());
  File(
    '${dir.path}/summary.json',
  ).writeAsStringSync(const JsonEncoder.withIndent(' ').convert(_finite(data)));
  stdout.write(out.toString());
}

/// JSON has no NaN: a statistic over no samples becomes null.
Object? _finite(Object? value) => switch (value) {
  final double d when !d.isFinite => null,
  final Map<dynamic, dynamic> map => {
    for (final MapEntry(:key, :value) in map.entries) '$key': _finite(value),
  },
  final List<dynamic> list => [for (final item in list) _finite(item)],
  _ => value,
};

// ---------------------------------------------------------------------------
// Statistics
// ---------------------------------------------------------------------------

double _percentile(Iterable<num> values, double p) {
  final sorted = [for (final v in values) v.toDouble()]..sort();
  if (sorted.isEmpty) return double.nan;
  final rank = p / 100 * (sorted.length - 1);
  final low = rank.floor();
  final high = rank.ceil();
  return sorted[low] + (sorted[high] - sorted[low]) * (rank - low);
}

double _median(Iterable<num> values) => _percentile(values, 50);

double _mean(Iterable<num> values) {
  var sum = 0.0;
  var count = 0;
  for (final v in values) {
    sum += v;
    count++;
  }
  return count == 0 ? double.nan : sum / count;
}

String _ms(double value) {
  if (value.isNaN) return '—';
  if (value >= 100) return value.round().toString();
  if (value >= 10) return value.toStringAsFixed(1);
  return value.toStringAsFixed(2);
}

/// Median with the observed range, e.g. `412 (398–455)`.
String _spread(List<num> values) {
  if (values.isEmpty) return '—';
  final sorted = [for (final v in values) v.toDouble()]..sort();
  if (sorted.length == 1) return _ms(sorted.first);
  return '${_ms(_median(sorted))} (${_ms(sorted.first)}–${_ms(sorted.last)})';
}

/// How WASM compares on a lower-is-better measure.
String _versus(double js, double wasm) {
  if (js.isNaN || wasm.isNaN || js <= 0 || wasm <= 0) return '—';
  final ratio = js / wasm;
  if (ratio >= 1.05) return '**${ratio.toStringAsFixed(2)}× faster**';
  if (ratio <= 0.95) return '${(1 / ratio).toStringAsFixed(2)}× slower';
  return 'same';
}

String _count(double value) => value.isNaN ? '—' : '${value.round()}';

String _share(double value) =>
    value.isNaN ? '—' : '${value.toStringAsFixed(1)}%';

String _mb(num bytes) => '${(bytes / 1000000).toStringAsFixed(2)} MB';

String _percent(double js, double wasm) {
  if (js <= 0) return '—';
  final change = (wasm - js) / js * 100;
  final sign = change > 0 ? '+' : '−';
  return '$sign${change.abs().toStringAsFixed(0)}%';
}

void _table(StringBuffer out, List<String> header, List<List<String>> rows) {
  out
    ..writeln('| ${header.join(' | ')} |')
    ..writeln('|${header.map((_) => '---').join('|')}|');
  for (final row in rows) {
    out.writeln('| ${row.join(' | ')} |');
  }
}

List<_Sample> _of(List<_Sample> samples, String variant, [String? phase]) => [
  for (final s in samples)
    if (s['variant'] == variant && (phase == null || s['phase'] == phase)) s,
];

// ---------------------------------------------------------------------------
// Sections
// ---------------------------------------------------------------------------

void _environment(
  StringBuffer out,
  Map<String, dynamic> data,
  Directory dir,
  List<_Sample> all,
  List<_Sample> valid,
) {
  String run(String command, List<String> args) {
    try {
      return (Process.runSync(command, args).stdout as String).trim();
    } on Object {
      return '';
    }
  }

  final env = valid.isEmpty
      ? const <String, dynamic>{}
      : valid.first['env'] as Map<String, dynamic>? ?? const {};
  final build = File('${dir.path}/build.json');
  final stamp = build.existsSync()
      ? jsonDecode(build.readAsStringSync()) as Map<String, dynamic>
      : const <String, dynamic>{};
  final loads = [
    for (final s in valid)
      double.tryParse((s['loadavg'] as String).split(RegExp(r'\s+')).first) ??
          double.nan,
  ].where((v) => !v.isNaN).toList();
  final machine = run('sysctl', ['-n', 'machdep.cpu.brand_string']);
  final os = run('sw_vers', ['-productVersion']);
  final days = {
    for (final s in valid) (s['at'] as String).substring(0, 10),
  }.join(', ');

  out
    ..writeln('# Invoice Ninja on Flutter Web — WASM vs JS')
    ..writeln()
    ..writeln(
      'The same commit of the production app, built twice — '
      '`flutter build web --release` (dart2js + CanvasKit) and '
      '`flutter build web --release --wasm` (dart2wasm + skwasm) — and '
      'driven through the same scripted session in Chrome.',
    )
    ..writeln()
    ..writeln('| | |')
    ..writeln('|---|---|')
    ..writeln(
      '| App | Invoice Ninja admin, commit `${stamp['sha'] ?? env['sha']}` (${stamp['tree'] ?? '?'}) |',
    )
    ..writeln(
      '| Toolchain | Flutter ${stamp['flutter'] ?? '?'}, Dart '
      '${stamp['dart'] ?? '?'} |',
    )
    ..writeln(
      '| Browser | ${env['chrome']}${env['headless'] == true ? ' (headless)' : ''}, ${env['viewport']} |',
    )
    ..writeln('| GPU | ${env['gl']} |')
    ..writeln('| Machine | $machine, macOS $os |')
    ..writeln('| Display rate | ${env['rafMs']} ms per frame |')
    ..writeln(
      '| Measured | $days — ${valid.length} valid samples, ${all.length - valid.length} discarded |',
    )
    ..writeln(
      '| System load during runs | ${loads.isEmpty ? '?' : '${_ms(loads.reduce((a, b) => a < b ? a : b))}–${_ms(loads.reduce((a, b) => a > b ? a : b))} (1-min average, 12 cores)'} |',
    );
  data['environment'] = {
    ...env,
    ...stamp,
    'machine': machine,
    'os': os,
    'validSamples': valid.length,
    'discardedSamples': all.length - valid.length,
    'loadRange': loads.isEmpty
        ? null
        : '${_ms(loads.reduce((a, b) => a < b ? a : b))}–'
              '${_ms(loads.reduce((a, b) => a > b ? a : b))}',
  };
}

void _sizes(
  StringBuffer out,
  Map<String, dynamic> data,
  Directory dir,
  List<_Sample> valid,
) {
  /// What one cold load of [variant] downloaded: path → bytes on the wire.
  Map<String, int>? fetched(String variant) {
    for (final s in valid) {
      if (s['variant'] != variant || s['config'] != 'plain') continue;
      final cold = (s['loads'] as List).first as Map<String, dynamic>;
      return {
        for (final row in (cold['fetched'] as List).cast<List<dynamic>>())
          if (row[1] == 200) row[0] as String: row[2] as int,
      };
    }
    return null;
  }

  final js = fetched('js');
  final wasm = fetched('wasm');
  if (js == null || wasm == null) return;

  bool isApp(String p) => p.startsWith('/main.dart.');
  bool isEngine(String p) => p.startsWith('/canvaskit/');
  ({int raw, int wire}) total(
    String variant,
    Map<String, int> files,
    bool Function(String) test,
  ) {
    var raw = 0;
    var wire = 0;
    for (final MapEntry(:key, :value) in files.entries) {
      if (!test(key)) continue;
      wire += value;
      final file = File('${dir.path}/$variant$key');
      if (file.existsSync()) raw += file.lengthSync();
    }
    return (raw: raw, wire: wire);
  }

  out
    ..writeln('\n## Download size\n')
    ..writeln(
      'What a first visit actually downloads, taken from the server log of '
      'a cold load. "gzip" is the size on the wire.\n',
    );
  final rows = <List<String>>[];
  final section = <String, dynamic>{};
  void row(String label, bool Function(String) test) {
    final a = total('js', js, test);
    final b = total('wasm', wasm, test);
    rows
      ..add([
        '$label — raw',
        _mb(a.raw),
        _mb(b.raw),
        _percent(a.raw.toDouble(), b.raw.toDouble()),
      ])
      ..add([
        '$label — gzip',
        _mb(a.wire),
        _mb(b.wire),
        _percent(a.wire.toDouble(), b.wire.toDouble()),
      ]);
    section[label] = {
      'js': {'raw': a.raw, 'gzip': a.wire},
      'wasm': {'raw': b.raw, 'gzip': b.wire},
    };
  }

  row('App code (`main.dart.*`)', isApp);
  row('Rendering engine (`canvaskit/`)', isEngine);
  row('Everything on first load', (_) => true);
  _table(out, ['', 'JS', 'WASM', 'WASM vs JS'], rows);
  out
    ..writeln()
    ..writeln(
      'JS engine files: ${js.keys.where(isEngine).join(', ')}. '
      'WASM engine files: ${wasm.keys.where(isEngine).join(', ')}.',
    );
  data['size'] = section;
}

void _startup(StringBuffer out, Map<String, dynamic> data, List<_Sample> mine) {
  List<Map<String, dynamic>> loads(String variant, String kind) => [
    for (final s in _of(mine, variant))
      for (final load in (s['loads'] as List).cast<Map<String, dynamic>>())
        if (load['kind'] == kind && load['firstFrame'] != null) load,
  ];
  const kinds = {
    'cold': 'Cold start — first visit, empty browser profile',
    'warm1': 'Return visit 1',
    'warm2': 'Return visit 2',
    'warm3': 'Return visit 3',
  };
  final metrics = <(String, String, double Function(Map<String, dynamic>))>[
    (
      'firstFrame',
      'Time to first frame',
      (l) => (l['firstFrame'] as num).toDouble(),
    ),
    (
      'engine',
      '— download, compile, engine start (until Dart `main`)',
      (l) => (l['dartStart'] as num? ?? double.nan).toDouble(),
    ),
    (
      'appBoot',
      '— app boot (Dart `main` → first frame)',
      (l) =>
          (l['firstFrame'] as num).toDouble() -
          (l['dartStart'] as num? ?? double.nan).toDouble(),
    ),
    (
      'ready',
      'Dashboard fully loaded and drawn',
      (l) => (l['ready'] as num).toDouble(),
    ),
    (
      'blocked',
      'Main thread blocked (long tasks beyond 50 ms)',
      (l) => (l['blockedMs'] as num).toDouble(),
    ),
    (
      'cpu',
      'Main-thread CPU time',
      (l) => (l['taskSeconds'] as num).toDouble() * 1000,
    ),
  ];
  final section = <String, dynamic>{};
  var wrote = false;
  for (final MapEntry(key: kind, value: title) in kinds.entries) {
    final js = loads('js', kind);
    final wasm = loads('wasm', kind);
    if (js.isEmpty && wasm.isEmpty) continue;
    if (!wrote) {
      out.writeln('### Startup\n');
      out.writeln(
        'Milliseconds from navigation, median (min–max). Lower is better.\n',
      );
      wrote = true;
    }
    out.writeln('**$title** — ${js.length} JS / ${wasm.length} WASM loads\n');
    final rows = <List<String>>[];
    final kindData = <String, dynamic>{};
    for (final (id, label, read) in metrics) {
      final a = [for (final l in js) read(l)].where((v) => !v.isNaN).toList();
      final b = [for (final l in wasm) read(l)].where((v) => !v.isNaN).toList();
      rows.add([
        label,
        _spread(a),
        _spread(b),
        _versus(_median(a), _median(b)),
      ]);
      kindData[id] = {
        'js': _median(a),
        'wasm': _median(b),
        'jsAll': a,
        'wasmAll': b,
      };
    }
    _table(out, ['', 'JS', 'WASM', 'WASM vs JS'], rows);
    out.writeln();
    section[kind] = kindData;
  }
  if (wrote) data['startup'] = section;
}

/// One sample's frames for one scenario group, reduced to the statistics the
/// tables use. All times in milliseconds.
Map<String, double>? _frameStats(_Sample sample, String group) {
  final segments = [
    for (final seg in (sample['segments'] as List).cast<Map<String, dynamic>>())
      if (seg['group'] == group || seg['name'] == group) seg,
  ];
  if (segments.isEmpty) return null;
  final build = <double>[];
  final raster = <double>[];
  final total = <double>[];
  final gaps = <double>[];
  var blocked = 0.0;
  for (final seg in segments) {
    for (final frame in (seg['frames'] as List).cast<List<dynamic>>()) {
      final b = (frame[1] as num) / 1000;
      final r = (frame[2] as num) / 1000;
      build.add(b);
      raster.add(r);
      total.add(b + r);
    }
    gaps.addAll(
      (seg['rafGaps'] as List? ?? const []).cast<num>().map(
        (g) => g.toDouble(),
      ),
    );
    blocked += (seg['blockedMs'] as num? ?? 0).toDouble();
  }
  if (total.isEmpty) return null;
  return {
    'frames': total.length.toDouble(),
    'avg': _mean(total),
    'p50': _percentile(total, 50),
    'p90': _percentile(total, 90),
    'p99': _percentile(total, 99),
    'max': total.reduce((a, b) => a > b ? a : b),
    'buildAvg': _mean(build),
    'buildP99': _percentile(build, 99),
    'rasterAvg': _mean(raster),
    'rasterP99': _percentile(raster, 99),
    'over': total.where((t) => t > 16.67).length / total.length * 100,
    'work': total.fold<double>(0, (s, t) => s + t),
    // A fixed-window segment (a screen that never goes idle) has no
    // "until drawn" time.
    'settled': _mean([
      for (final seg in segments)
        if (seg['windowMs'] == null)
          (seg['drawnMs'] ?? seg['settledMs']) as num,
    ]),
    'dropped': gaps.isEmpty
        ? double.nan
        : gaps.where((g) => g > 25).length / gaps.length * 100,
    'blocked': blocked,
  };
}

void _frames(StringBuffer out, Map<String, dynamic> data, List<_Sample> mine) {
  final js = _of(mine, 'js', 'frames');
  final wasm = _of(mine, 'wasm', 'frames');
  if (js.isEmpty && wasm.isEmpty) return;

  Map<String, List<double>> gather(List<_Sample> samples, String group) {
    final result = <String, List<double>>{};
    for (final sample in samples) {
      final stats = _frameStats(sample, group);
      if (stats == null) continue;
      for (final MapEntry(:key, :value) in stats.entries) {
        if (!value.isNaN) (result[key] ??= []).add(value);
      }
    }
    return result;
  }

  final section = <String, dynamic>{};
  final speed = <List<String>>[];
  final tail = <List<String>>[];
  final split = <List<String>>[];
  final transitions = <List<String>>[];
  for (final MapEntry(key: group, value: label) in _labels.entries) {
    final a = gather(js, group);
    final b = gather(wasm, group);
    if (a.isEmpty && b.isEmpty) continue;
    double m(Map<String, List<double>> of, String key) =>
        _median(of[key] ?? const []);
    speed.add([
      label,
      '${_count(m(a, 'frames'))} / ${_count(m(b, 'frames'))}',
      _ms(m(a, 'avg')),
      _ms(m(b, 'avg')),
      _versus(m(a, 'avg'), m(b, 'avg')),
      _ms(m(a, 'p50')),
      _ms(m(b, 'p50')),
    ]);
    tail.add([
      label,
      _ms(m(a, 'p90')),
      _ms(m(b, 'p90')),
      _ms(m(a, 'p99')),
      _ms(m(b, 'p99')),
      _versus(m(a, 'p99'), m(b, 'p99')),
      _share(m(a, 'over')),
      _share(m(b, 'over')),
    ]);
    split.add([
      label,
      _ms(m(a, 'buildAvg')),
      _ms(m(b, 'buildAvg')),
      _versus(m(a, 'buildAvg'), m(b, 'buildAvg')),
      _ms(m(a, 'rasterAvg')),
      _ms(m(b, 'rasterAvg')),
      _versus(m(a, 'rasterAvg'), m(b, 'rasterAvg')),
    ]);
    if (!group.startsWith('scroll') && !group.startsWith('resize')) {
      transitions.add([
        label,
        _spread(a['settled'] ?? const []),
        _spread(b['settled'] ?? const []),
        _versus(m(a, 'settled'), m(b, 'settled')),
        _ms(m(a, 'work')),
        _ms(m(b, 'work')),
        _versus(m(a, 'work'), m(b, 'work')),
      ]);
    }
    section[group] = {
      'label': label,
      'js': {for (final k in a.keys) k: m(a, k)},
      'wasm': {for (final k in b.keys) k: m(b, k)},
    };
  }

  out
    ..writeln('### Frame times\n')
    ..writeln(
      '${js.length} JS / ${wasm.length} WASM sessions. A frame\'s time is the '
      'engine\'s own `FrameTiming`: **build** (the Dart framework — build, '
      'layout, paint) plus **raster** (the renderer). Milliseconds, lower is '
      'better; each cell is the median across sessions.\n',
    )
    ..writeln('**Average frame**\n');
  _table(out, [
    'Scenario',
    'Frames (JS / WASM)',
    'JS avg',
    'WASM avg',
    'WASM vs JS',
    'JS median',
    'WASM median',
  ], speed);
  out.writeln('\n**Worst frames** — the ones a user feels\n');
  _table(out, [
    'Scenario',
    'JS p90',
    'WASM p90',
    'JS p99',
    'WASM p99',
    'WASM vs JS (p99)',
    'JS over 16.7 ms',
    'WASM over 16.7 ms',
  ], tail);
  out.writeln('\n**Where the time goes** — average per frame\n');
  _table(out, [
    'Scenario',
    'JS build',
    'WASM build',
    'WASM vs JS',
    'JS raster',
    'WASM raster',
    'WASM vs JS',
  ], split);
  if (transitions.isNotEmpty) {
    out.writeln(
      '\n**Screen changes** — from the navigation to the last frame of the '
      'new screen (per screen), and the total frame work it took\n',
    );
    _table(out, [
      'Scenario',
      'JS until drawn',
      'WASM until drawn',
      'WASM vs JS',
      'JS frame work',
      'WASM frame work',
      'WASM vs JS',
    ], transitions);
  }
  out.writeln();
  data['frames'] = section;
}

/// skwasm on one thread against skwasm with its raster worker, both under the
/// same isolation headers — so the storage backend is the same and the only
/// difference is the thread.
void _threads(
  StringBuffer out,
  Map<String, dynamic> data,
  List<_Sample> valid,
) {
  List<_Sample> of(String config) => [
    for (final s in valid)
      if (s['config'] == config &&
          s['variant'] == 'wasm' &&
          s['phase'] == 'frames')
        s,
  ];
  final single = of('iso-st');
  final multi = of('iso');
  if (single.isEmpty || multi.isEmpty) return;

  double stat(List<_Sample> samples, String group, String key) => _median([
    for (final sample in samples)
      if (_frameStats(sample, group)?[key] case final double v when !v.isNaN) v,
  ]);

  final rows = <List<String>>[];
  final section = <String, dynamic>{};
  for (final MapEntry(key: group, value: label) in _labels.entries) {
    final a = stat(single, group, 'rasterAvg');
    final b = stat(multi, group, 'rasterAvg');
    if (a.isNaN || b.isNaN) continue;
    rows.add([
      label,
      _ms(a),
      _ms(b),
      _versus(a, b),
      _ms(stat(single, group, 'avg')),
      _ms(stat(multi, group, 'avg')),
      _versus(stat(single, group, 'avg'), stat(multi, group, 'avg')),
    ]);
    section[group] = {
      'label': label,
      'single': {
        'rasterAvg': a,
        'avg': stat(single, group, 'avg'),
        'p99': stat(single, group, 'p99'),
      },
      'multi': {
        'rasterAvg': b,
        'avg': stat(multi, group, 'avg'),
        'p99': stat(multi, group, 'p99'),
      },
    };
  }
  out
    ..writeln('\n## What the raster worker buys (WASM only)\n')
    ..writeln(
      'skwasm single-threaded against skwasm with its raster worker, both '
      'cross-origin isolated so everything else is equal. '
      '${single.length} single-thread / ${multi.length} multi-thread '
      'sessions; average milliseconds per frame.\n',
    );
  _table(out, [
    'Scenario',
    'Raster, 1 thread',
    'Raster, worker',
    'Worker vs 1 thread',
    'Frame, 1 thread',
    'Frame, worker',
    'Worker vs 1 thread',
  ], rows);
  out.writeln();
  data['threads'] = section;
}

void _compute(StringBuffer out, Map<String, dynamic> data, List<_Sample> mine) {
  /// Per benchmark: every run's per-unit times (ms), and the results seen.
  ({Map<String, List<List<double>>> times, Map<String, Set<String>> checks})
  runs(String variant) {
    final times = <String, List<List<double>>>{};
    final checks = <String, Set<String>>{};
    for (final sample in _of(mine, variant, 'compute')) {
      for (final r
          in (sample['compute'] as List? ?? const [])
              .cast<Map<String, dynamic>>()) {
        final ms = (r['ms'] as List?)?.cast<num>();
        if (ms == null) continue;
        final ops = (r['ops'] as num? ?? 1).toDouble();
        final name = r['name'] as String;
        (times[name] ??= []).add([for (final v in ms) v / ops]);
        (checks[name] ??= {}).add('${r['check']}');
      }
    }
    return (times: times, checks: checks);
  }

  final js = runs('js');
  final wasm = runs('wasm');
  if (js.times.isEmpty && wasm.times.isEmpty) return;
  final rows = <List<String>>[];
  final section = <String, dynamic>{};
  final disagreements = <String>[];
  for (final MapEntry(key: name, value: label) in _computeLabels.entries) {
    final a = js.times[name] ?? const <List<double>>[];
    final b = wasm.times[name] ?? const <List<double>>[];
    if (a.isEmpty && b.isEmpty) continue;
    final results = {...?js.checks[name], ...?wasm.checks[name]};
    if (results.length > 1) disagreements.add('$name: $results');
    // The first batch pays for whatever the runtime does lazily; steady state
    // is the median of the second half of the batches.
    double first(List<List<double>> of) =>
        _median([for (final r in of) r.first]);
    double steady(List<List<double>> of) =>
        _median([for (final r in of) _median(r.sublist(r.length ~/ 2))]);
    rows.add([
      label,
      _ms(first(a)),
      _ms(first(b)),
      _versus(first(a), first(b)),
      _ms(steady(a)),
      _ms(steady(b)),
      _versus(steady(a), steady(b)),
    ]);
    section[name] = {
      'label': label,
      'js': {'first': first(a), 'steady': steady(a)},
      'wasm': {'first': first(b), 'steady': steady(b)},
    };
  }
  out
    ..writeln('### Pure Dart compute\n')
    ..writeln(
      'Real app code run in the page, no widgets, identical inputs and '
      '(checked) identical results under both compilers. Milliseconds per '
      'operation, lower is better. "First" is the first batch after page '
      'load; "steady" is once the runtime has warmed up.\n',
    );
  _table(out, [
    'Workload',
    'JS first',
    'WASM first',
    'WASM vs JS',
    'JS steady',
    'WASM steady',
    'WASM vs JS',
  ], rows);
  if (disagreements.isNotEmpty) {
    out.writeln(
      '\n**The compilers disagreed on a result — these rows are not a valid '
      'comparison:** ${disagreements.join('; ')}',
    );
  }
  out.writeln();
  data['compute'] = section;
}

void _memory(StringBuffer out, Map<String, dynamic> data, List<_Sample> mine) {
  List<double> heaps(String variant) => [
    for (final s in _of(mine, variant, 'frames'))
      if (s['heap'] != null)
        ((s['heap'] as Map<String, dynamic>)['usedMb'] as num).toDouble(),
  ];
  final js = heaps('js');
  final wasm = heaps('wasm');
  if (js.isEmpty && wasm.isEmpty) return;
  out.writeln('### Memory\n');
  _table(
    out,
    ['', 'JS', 'WASM', 'WASM vs JS'],
    [
      [
        'V8 heap in use after the whole session, post-GC (MB)',
        _spread(js),
        _spread(wasm),
        _versus(
          _median(js),
          _median(wasm),
        ).replaceAll('faster', 'smaller').replaceAll('slower', 'larger'),
      ],
    ],
  );
  out.writeln();
  data['memory'] = {'js': _median(js), 'wasm': _median(wasm)};
}

void _method(StringBuffer out) {
  out.writeln('''

## How this was measured

- **Same code, same flags.** Both variants are release builds of one commit
  from one entrypoint; only `--wasm` differs. Flutter's release defaults apply
  to each (dart2js `-O4`, dart2wasm `-O2`).
- **No network in the numbers.** The app's API calls are answered from a local
  recording of the demo server, on the same origin, so startup and navigation
  measure the client and not the server's latency.
- **A fresh browser profile per sample**, variants interleaved and alternating
  who goes first. Cold start is a profile that has never seen the app; a return
  visit reuses that profile's HTTP cache, compiled-code cache, session and
  local database.
- **Frame times are Flutter's own `FrameTiming`**, the same build and raster
  durations DevTools shows. Raster is not like-for-like across renderers
  (CanvasKit and skwasm split work differently), so build + raster is the
  comparable figure.
- **A sample is discarded, not averaged,** if the wrong compiler or renderer
  loaded, the GPU was software, a request missed the recording, the page
  navigated twice, a boot stage was missing, or a screen never went idle.
- **One machine, one browser.** Ratios travel better than absolute times.
- Reproduce with `tools/web_bench/` — see `docs/web-benchmarks.md`.''');
}
