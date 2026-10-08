// Web benchmark entrypoint — the real app plus a small measurement bridge.
//
// Built by `tools/web_bench/build.sh` once with dart2js and once with
// dart2wasm, then driven by `tools/web_bench/main.dart` over the Chrome
// DevTools Protocol. See `docs/web-benchmarks.md`.
//
// This file adds nothing to the app's own behaviour: it installs
// `globalThis.__inBench` and then runs the unmodified `main()`, so the boot
// path, the Drift WASM store and every screen are the production ones. It must
// NOT touch the Flutter binding itself — `main()` initialises it inside its
// guarded zone, and a binding created out here would live in the root zone.

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui' show FramePhase, FrameTiming;

import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import 'package:admin/data/models/api/login_response_api_model.dart';
import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/data/models/domain/billing/line_item_type.dart';
import 'package:admin/data/models/domain/report_preview.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/domain/billing/totals_calculator.dart';
import 'package:admin/domain/reports/report_column_types.dart';
import 'package:admin/domain/reports/report_engine.dart';
import 'package:admin/main.dart' as app;
import 'package:admin/utils/legacy_html_markdown.dart';

const _gitSha = String.fromEnvironment('BENCH_GIT_SHA');

void main() {
  _installBridge();
  unawaited(app.main());
}

void _installBridge() {
  final bridge = JSObject();
  bridge['info'] = _jsInfo.toJS;
  bridge['arm'] = _jsArm.toJS;
  bridge['pulse'] = _jsPulse.toJS;
  bridge['flush'] = _jsFlush.toJS;
  bridge['frames'] = _jsFrames.toJS;
  bridge['scrollableAt'] = _jsScrollableAt.toJS;
  bridge['compute'] = _jsCompute.toJS;
  globalContext['__inBench'] = bridge;
}

JSString _jsInfo() => jsonEncode(_info()).toJS;

JSBoolean _jsArm() => _arm().toJS;

JSString _jsPulse() => jsonEncode(_pulse()).toJS;

void _jsFlush() => SchedulerBinding.instance.scheduleFrame();

JSString _jsFrames(JSNumber from) => _frames(from.toDartInt).toJS;

JSString _jsScrollableAt(JSNumber x, JSNumber y) =>
    jsonEncode(_scrollableAt(x.toDartDouble, y.toDartDouble)).toJS;

JSPromise<JSString> _jsCompute(JSString name) =>
    _compute(name.toDart).then((r) => jsonEncode(r).toJS).toJS;

Map<String, Object?> _info() => {
  'wasm': kIsWasm,
  'release': kReleaseMode,
  'sha': _gitSha,
};

// ---------------------------------------------------------------------------
// Frame timings
// ---------------------------------------------------------------------------

final List<FrameTiming> _timings = [];
bool _armed = false;
int _frameCount = 0;

/// Starts recording. Called by the harness once the first frame is up, so the
/// binding exists. Idempotent.
bool _arm() {
  if (_armed) return true;
  _armed = true;
  final scheduler = SchedulerBinding.instance;
  scheduler.addTimingsCallback(_timings.addAll);
  scheduler.addPersistentFrameCallback((_) => _frameCount++);
  return true;
}

/// A live "is the app still drawing" probe. The engine batches [FrameTiming]
/// reports (100 ms, and only on a frame), so the timings list lags; the
/// persistent-callback counter does not.
Map<String, Object?> _pulse() => {
  'frames': _frameCount,
  'scheduled': SchedulerBinding.instance.hasScheduledFrame,
};

/// Timings from [from] on, one row per frame, all in microseconds on the
/// page's `performance.now()` clock:
/// `[buildStart, build, raster, vsyncStart, rasterFinish]`.
String _frames(int from) {
  final out = <List<int>>[];
  for (var i = from; i < _timings.length; i++) {
    final t = _timings[i];
    out.add([
      t.timestampInMicroseconds(FramePhase.buildStart),
      t.buildDuration.inMicroseconds,
      t.rasterDuration.inMicroseconds,
      t.timestampInMicroseconds(FramePhase.vsyncStart),
      t.timestampInMicroseconds(FramePhase.rasterFinish),
    ]);
  }
  return jsonEncode({'next': _timings.length, 'rows': out});
}

// ---------------------------------------------------------------------------
// Scroll probe
// ---------------------------------------------------------------------------

/// The innermost vertical scrollable actually under the logical point
/// ([x], [y]) — found by hit test, so an offstage shell branch or a route
/// buried under another one is never reported.
Map<String, Object?> _scrollableAt(double x, double y) {
  final binding = WidgetsBinding.instance;
  final root = binding.rootElement;
  if (root == null) return {'found': false, 'why': 'no root element'};

  final byRenderObject = <RenderObject, ScrollableState>{};
  void visit(Element element) {
    if (element is StatefulElement && element.state is ScrollableState) {
      final state = element.state as ScrollableState;
      final ro = element.findRenderObject();
      if (ro != null) byRenderObject[ro] = state;
    }
    element.visitChildren(visit);
  }

  root.visitChildren(visit);

  final view = binding.platformDispatcher.implicitView;
  if (view == null) return {'found': false, 'why': 'no implicit view'};
  final result = HitTestResult();
  binding.hitTestInView(result, Offset(x, y), view.viewId);
  for (final entry in result.path) {
    final target = entry.target;
    if (target is! RenderObject) continue;
    final state = byRenderObject[target];
    if (state == null) continue;
    final position = state.position;
    if (position.axis != Axis.vertical) continue;
    if (!position.hasPixels || !position.hasContentDimensions) continue;
    final box = target is RenderBox ? target : null;
    final origin = box?.localToGlobal(Offset.zero);
    return {
      'found': true,
      'pixels': position.pixels,
      'min': position.minScrollExtent,
      'max': position.maxScrollExtent,
      'viewport': position.viewportDimension,
      'left': origin?.dx,
      'top': origin?.dy,
      'width': box?.size.width,
      'height': box?.size.height,
      'scrollables': byRenderObject.length,
    };
  }
  return {
    'found': false,
    'why': 'no vertical scrollable under the point',
    'scrollables': byRenderObject.length,
  };
}

// ---------------------------------------------------------------------------
// Compute micro-benchmarks — real app code, no widgets
// ---------------------------------------------------------------------------

Future<Map<String, Object?>> _compute(String name) async {
  switch (name) {
    case 'totals':
      final inputs = _totalsInputs();
      return _time(name, iterations: 20, ops: inputs.length, () {
        var sum = Decimal.zero;
        for (final input in inputs) {
          sum += computeTotals(input, 2).total;
        }
        return sum.toString();
      });
    case 'report':
      final preview = _reportPreview();
      const engine = ReportEngine();
      const ui = ReportUiState(
        group: 'client.name',
        sortField: 'invoice.amount',
        sortAscending: false,
      );
      return _time(name, iterations: 20, ops: 5, () {
        var check = '';
        for (var i = 0; i < 5; i++) {
          final view = engine.compute(
            preview: preview,
            ui: ui,
            exchangeRates: const {},
            companyCurrencyId: '1',
          );
          check = '${view.totalRowCount}/${view.groups.length}';
        }
        return check;
      });
    case 'html_markdown':
      final html = _legacyHtml();
      return _time(name, iterations: 15, ops: 60, () {
        var length = 0;
        for (var i = 0; i < 60; i++) {
          length = markdownFromLegacyHtml(html).length;
        }
        return '$length';
      });
    case 'json_decode':
      final text = await _snapshotText();
      return _time(name, iterations: 15, ops: 10, () {
        var keys = 0;
        for (var i = 0; i < 10; i++) {
          keys = (jsonDecode(text) as Map<String, dynamic>).length;
        }
        return '$keys';
      }, extra: {'bytes': text.length});
    case 'snapshot_parse':
      // What a cold boot does with the login response: decode it, then type
      // it. Decoded afresh every time — dart2js hands back lazily-converted
      // maps, so re-reading one that was already walked would flatter it.
      final text = await _snapshotText();
      return _time(name, iterations: 15, ops: 10, () {
        var companies = 0;
        for (var i = 0; i < 10; i++) {
          final decoded = jsonDecode(text) as Map<String, dynamic>;
          companies = LoginResponseApi.fromJson(decoded).data.length;
        }
        return '$companies';
      }, extra: {'bytes': text.length});
  }
  return {'name': name, 'error': 'unknown benchmark'};
}

/// Runs [body] [iterations] times and returns every iteration's wall time in
/// milliseconds, first call included. [ops] is how many units of work one
/// iteration does (a batch, so each is long enough to time on a clock the
/// browser coarsens to 0.1 ms), and `check` is the body's own result, so the
/// report can assert both compilers computed the same thing.
Map<String, Object?> _time(
  String name,
  String Function() body, {
  required int iterations,
  required int ops,
  Map<String, Object?> extra = const {},
}) {
  final ms = <double>[];
  var check = '';
  final sw = Stopwatch();
  for (var i = 0; i < iterations; i++) {
    sw
      ..reset()
      ..start();
    check = body();
    sw.stop();
    ms.add(sw.elapsedMicroseconds / 1000);
  }
  return {'name': name, 'ms': ms, 'ops': ops, 'check': check, ...extra};
}

String? _snapshot;

/// The recorded `/refresh?first_load=true` body the harness serves — the same
/// payload the app parses on every cold start.
Future<String> _snapshotText() async {
  return _snapshot ??= await http.read(
    Uri.base.resolve('/__bench/refresh.json'),
  );
}

/// A tiny deterministic generator, so both compilers get the same inputs.
/// Park–Miller, whose products stay far below 2^53: dart2js integers are JS
/// doubles, and a generator that overflows them yields a different sequence
/// there than under dart2wasm's 64-bit ints.
class _Lcg {
  _Lcg(this._state);
  int _state;

  int next(int bound) {
    _state = (_state * 48271) % 2147483647;
    return _state % bound;
  }
}

/// 5 invoices of 50 lines each, with item discounts, three tax slots and
/// surcharges, half of them tax-inclusive.
List<BillingTotalsInput> _totalsInputs() {
  final rng = _Lcg(20261008);
  Decimal cents(int value) => Decimal.fromInt(value).shift(-2);
  return [
    for (var invoice = 0; invoice < 5; invoice++)
      BillingTotalsInput(
        lineItems: [
          for (var line = 0; line < 50; line++)
            LineItem(
              productKey: 'P$line',
              notes: '',
              cost: cents(100 + rng.next(250000)),
              productCost: Decimal.zero,
              quantity: cents(25 + rng.next(2000)),
              taxName1: 'VAT',
              taxName2: line.isEven ? 'City' : '',
              taxName3: '',
              taxRate1: cents(500 + rng.next(2000)),
              taxRate2: line.isEven ? cents(rng.next(900)) : Decimal.zero,
              taxRate3: Decimal.zero,
              typeId: LineItemType.standard,
              customValue1: '',
              customValue2: '',
              customValue3: '',
              customValue4: '',
              discount: cents(rng.next(1500)),
              taxCategoryId: '',
            ),
        ],
        discount: cents(rng.next(1000)),
        isAmountDiscount: invoice % 3 == 0,
        usesInclusiveTaxes: invoice.isOdd,
        taxName1: 'State',
        taxRate1: cents(rng.next(800)),
        customSurcharge1: cents(rng.next(5000)),
        customTaxes1: invoice % 4 == 0,
      ),
  ];
}

/// 5,000 invoice rows across 60 clients: grouped by client, sorted by amount.
ReportPreview _reportPreview() {
  final rng = _Lcg(77);
  const columns = [
    ReportColumn(
      identifier: 'client.name',
      displayLabel: 'Client',
      type: ReportColumnType.string,
    ),
    ReportColumn(
      identifier: 'invoice.number',
      displayLabel: 'Number',
      type: ReportColumnType.string,
    ),
    ReportColumn(
      identifier: 'invoice.amount',
      displayLabel: 'Amount',
      type: ReportColumnType.money,
    ),
    ReportColumn(
      identifier: 'invoice.balance',
      displayLabel: 'Balance',
      type: ReportColumnType.money,
    ),
    ReportColumn(
      identifier: 'invoice.date',
      displayLabel: 'Date',
      type: ReportColumnType.date,
    ),
    ReportColumn(
      identifier: 'invoice.status',
      displayLabel: 'Status',
      type: ReportColumnType.string,
    ),
  ];
  const statuses = ['Draft', 'Sent', 'Partial', 'Paid', 'Overdue'];
  return ReportPreview(
    columns: columns,
    rows: [
      for (var i = 0; i < 5000; i++)
        ReportRow(
          cells: [
            ReportStringCell(value: 'Client ${rng.next(60)}'),
            ReportStringCell(value: 'INV-${10000 + i}'),
            ReportNumberCell(
              value: Decimal.fromInt(rng.next(900000)).shift(-2),
              isMoney: true,
              currencyId: '1',
            ),
            ReportNumberCell(
              value: Decimal.fromInt(rng.next(90000)).shift(-2),
              isMoney: true,
              currencyId: '1',
            ),
            ReportDateCell(
              value: Date(
                2024 + rng.next(3),
                1 + rng.next(12),
                1 + rng.next(28),
              ),
            ),
            ReportStringCell(value: statuses[rng.next(statuses.length)]),
          ],
        ),
    ],
  );
}

/// About 40 KB of the tag soup a legacy notes field carries.
String _legacyHtml() {
  final buffer = StringBuffer();
  for (var i = 0; i < 120; i++) {
    buffer
      ..write('<p>Thank you for your <b>business</b>, invoice <i>#$i</i> is ')
      ..write('due on receipt.<br>Pay at <a href="https://example.com/pay/$i">')
      ..write('example.com/pay/$i</a> &amp; quote ref&nbsp;<u>R-$i</u>.</p>')
      ..write('<ul><li>Net 30 &ndash; late fee 1.5%</li><li><strong>Wire')
      ..write('</strong> or <em>card</em></li><li>Questions&#39; welcome</li>')
      ..write('</ul><div>Terms &amp; conditions apply.<br/><br/>Regards</div>');
  }
  return buffer.toString();
}
