import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Opt-out marker — see the doc below.
const String _kAllowMarker = 'lint: allow-controlled-refresh-scroll';

/// CI lint: in a file that builds a `RefreshIndicator`, a vertical scroll view
/// that is handed a `controller:` must ask for `AlwaysScrollableScrollPhysics`.
///
/// `ScrollView` only defaults a vertical list to that physics when it has **no**
/// controller (the `physics =` initializer in the SDK's `scroll_view.dart`).
/// Pass one — for load-more, scroll-to-row, anything — and the list silently
/// drops back to the platform physics, which refuse a drag on content that
/// fits the viewport (`ScrollPhysics.shouldAcceptUserOffset`). `RefreshIndicator`
/// only ever starts on a drag, so a list shorter than the screen can then never
/// be pulled. Nothing throws; a long list hides it completely; and a desktop
/// review with a mouse never pulls at all. It shipped as
/// invoiceninja/flutter#163 — "pull-to-refresh doesn't work in Quotes", for a
/// user whose quotes happened to fit on one phone screen, while every
/// standalone entity list had the same bug at that length.
///
/// The fix is `physics: const AlwaysScrollableScrollPhysics()` — bare, so
/// `Scrollable` layers it over the platform's own clamping / bouncing rather
/// than replacing them. The evidence is in `docs/pull-to-refresh.md`, and
/// `test/ui/core/list/entity_list_pull_to_refresh_test.dart` proves the
/// behaviour on the real list scaffold; this scan is what reaches every other
/// refreshable surface, today's and tomorrow's.
///
/// Opt out with `// $_kAllowMarker <reason>` on the scroll view's line or the
/// one above it, the placement `semantics_excludes_need_ontap_test.dart` uses.
///
/// Know the limits. The scan is per file: a scroll view built in another file
/// and handed in as the indicator's child (`MobileDashboardBody`, say) is
/// invisible to it, and so is physics passed through a variable — both are
/// fine today because neither takes a controller. The depth walk that keeps a
/// nested call's arguments out of the match does not know about quotes, so a
/// bracket inside a string literal would confuse it; no site does that. And it
/// reads `ListView` / `GridView` (any named constructor), `CustomScrollView`
/// and `SingleChildScrollView` — nothing in `lib/` refreshes anything else.
void main() {
  final hosts = <String>[];
  final scanned = <String>[];
  final offenders = <String>[];

  for (final file in _dartFiles('lib')) {
    final raw = file.readAsStringSync();
    if (!raw.contains('RefreshIndicator')) continue;
    // Scan code, not prose: `mobile_dashboard_body.dart` names
    // `RefreshIndicator` only in a doc comment, and must not become a host.
    final source = _stripComments(raw);
    if (!_refreshIndicatorCall.hasMatch(source)) continue;
    hosts.add(file.path);

    final lines = raw.split('\n');
    for (final call in _scrollViewCalls(source)) {
      if (!_needsAlwaysScrollable(call.args)) continue;
      // The marker is a comment, so it has to be read off the untouched source.
      final line = lines[call.line - 1];
      final above = call.line > 1 ? lines[call.line - 2] : '';
      if (line.contains(_kAllowMarker) || above.contains(_kAllowMarker)) {
        continue;
      }
      scanned.add('${file.path}:${call.line}');
      if (!_asksForAlwaysScrollable(call.args)) {
        offenders.add('${file.path}:${call.line}');
      }
    }
  }

  test('a controlled scroll view under a RefreshIndicator stays pullable', () {
    expect(
      offenders,
      isEmpty,
      reason:
          'these vertical scroll views take a `controller:` in a file that '
          'builds a `RefreshIndicator`, so they no longer default to '
          '`AlwaysScrollableScrollPhysics` — a list shorter than its viewport '
          'can then never be pulled (invoiceninja/flutter#163). Add '
          '`physics: const AlwaysScrollableScrollPhysics()`, or '
          '`// $_kAllowMarker <reason>` on that line or the one above.',
    );
  });

  test('the scan is not blind', () {
    // A floor, not an exact list: a new refreshable screen should not fail the
    // build, but a host pattern that silently stops matching should.
    expect(
      hosts.length,
      greaterThanOrEqualTo(3),
      reason:
          'only ${hosts.length} RefreshIndicator hosts found (the entity list '
          'scaffold, the activity screen and the dashboard all build one) — '
          'the host pattern has gone blind',
    );
    // The one site that needs the physics today, and the one #163 was.
    expect(
      scanned.where((s) => s.contains('entity_list_screen_scaffold.dart')),
      isNotEmpty,
      reason:
          "the list scaffold's controlled ListView.builder must be scanned — "
          'if it is not, the scroll-view pattern or the controller check broke',
    );
    expect(
      hosts.where((h) => h.contains('mobile_dashboard_body.dart')),
      isEmpty,
      reason: 'a RefreshIndicator named only in a comment is not a host',
    );
  });

  test('an offending shape is flagged, and only its own physics count', () {
    // Without this the file is vacuous: make `_asksForAlwaysScrollable`
    // return true and the tests above still pass, because they only assert
    // that today's tree is clean. This is the one that proves the rule fires.
    const offender = '''
RefreshIndicator(
  onRefresh: refresh,
  child: ListView.builder(
    controller: scroll,
    itemBuilder: (context, i) => ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [],
    ),
  ),
)''';
    expect(_refreshIndicatorCall.hasMatch(offender), isTrue);
    final calls = _scrollViewCalls(offender);
    expect(calls, hasLength(2), reason: 'the nested list is its own call');
    expect(calls.first.line, 3);
    expect(_needsAlwaysScrollable(calls.first.args), isTrue);
    expect(
      _asksForAlwaysScrollable(calls.first.args),
      isFalse,
      reason: "a nested list's physics are not the outer list's",
    );

    // The shape the list scaffold ships: embedded lists never scroll
    // themselves, standalone ones always can.
    const fixed =
        'ListView.builder(shrinkWrap: embedded, physics: embedded '
        '? const NeverScrollableScrollPhysics() '
        ': const AlwaysScrollableScrollPhysics(), controller: embedded '
        '? null : scroll, itemBuilder: build)';
    final fixedArgs = _scrollViewCalls(fixed).single.args;
    expect(_needsAlwaysScrollable(fixedArgs), isTrue);
    expect(_asksForAlwaysScrollable(fixedArgs), isTrue);

    // A platform physics is precisely the bug, spelled out.
    const platformOnly =
        'const CustomScrollView(controller: c, '
        'physics: ClampingScrollPhysics(), slivers: s)';
    final platformArgs = _scrollViewCalls(platformOnly).single.args;
    expect(_needsAlwaysScrollable(platformArgs), isTrue);
    expect(_asksForAlwaysScrollable(platformArgs), isFalse);
  });

  test('what does not need the physics is never a host', () {
    for (final exempt in const [
      // The list scaffold's wide table pans sideways under the rows; a pull
      // is vertical, so the horizontal view's physics are irrelevant.
      'SingleChildScrollView(scrollDirection: Axis.horizontal, '
          'controller: h, child: table)',
      // Controller-less: `ScrollView` already picks
      // AlwaysScrollableScrollPhysics, as the activity feed relies on.
      'ListView(children: rows)',
      // A row's own field controller is not the list's.
      'ListView.builder(itemCount: n, itemBuilder: (c, i) => '
          'TextField(controller: fields[i]))',
      'GridView.count(crossAxisCount: 2, controller: null, children: c)',
    ]) {
      expect(
        _needsAlwaysScrollable(_scrollViewCalls(exempt).first.args),
        isFalse,
        reason: exempt,
      );
    }
    // Neither of these is a scroll view the rule reads.
    expect(_scrollViewCalls('ReorderableListView(controller: c)'), isEmpty);
    expect(_scrollViewCalls('_buildListView(controller: c)'), isEmpty);
  });
}

/// A `RefreshIndicator` actually being built — either constructor.
final _refreshIndicatorCall = RegExp(
  r'(?<![A-Za-z0-9_.])RefreshIndicator(\.adaptive)?\(',
);

/// Drop `//` comment tails so the scan reads code, not prose. Per line, never
/// dropping a line, so the reported line numbers still point at the source.
String _stripComments(String source) => source
    .split('\n')
    .map((line) {
      final i = line.indexOf('//');
      return i == -1 ? line : line.substring(0, i);
    })
    .join('\n');

class _Call {
  const _Call(this.args, this.line);
  final String args;
  final int line;
}

/// Every scroll view invocation's own argument text, in source order, with
/// nested calls kept intact but nested scroll views also returned as separate
/// entries.
List<_Call> _scrollViewCalls(String source) {
  final calls = <_Call>[];
  final pattern = RegExp(
    r'(?<![A-Za-z0-9_.])'
    r'((ListView|GridView)(\.[a-z]\w*)?|CustomScrollView|SingleChildScrollView)'
    r'\(',
  );
  for (final match in pattern.allMatches(source)) {
    var depth = 1;
    var i = match.end;
    while (i < source.length && depth > 0) {
      final c = source[i];
      if (c == '(') {
        depth++;
      } else if (c == ')') {
        depth--;
      }
      i++;
    }
    calls.add(
      _Call(
        source.substring(match.end, i - 1),
        '\n'.allMatches(source.substring(0, match.start)).length + 1,
      ),
    );
  }
  return calls;
}

/// Whether this scroll view has given up the always-scrollable default: it
/// takes a (non-null) controller and scrolls vertically.
bool _needsAlwaysScrollable(String args) {
  final controller = _topLevelArgValue(args, 'controller');
  if (controller == null || controller == 'null') return false;
  final direction = _topLevelArgValue(args, 'scrollDirection');
  return !(direction?.contains('Axis.horizontal') ?? false);
}

/// Whether its own `physics:` names AlwaysScrollableScrollPhysics — on any
/// branch of a conditional, which is how the list scaffold spells it.
bool _asksForAlwaysScrollable(String args) {
  final physics = _topLevelArgValue(args, 'physics');
  return physics != null && physics.contains('AlwaysScrollableScrollPhysics');
}

/// The value text of the `name:` argument at [args]' own level, or null when
/// it does not pass one. Nested calls are skipped, so a child widget's
/// `physics:` never stands in for the outer scroll view's.
String? _topLevelArgValue(String args, String name) {
  final pattern = RegExp('(?<![A-Za-z0-9_])$name:');
  var depth = 0;
  for (var i = 0; i < args.length; i++) {
    final c = args[i];
    if (c == '(' || c == '[' || c == '{') {
      depth++;
    } else if (c == ')' || c == ']' || c == '}') {
      depth--;
    } else if (depth == 0) {
      final match = pattern.matchAsPrefix(args, i);
      if (match == null) continue;
      // The value runs to the next comma at this same level, or to the end.
      var inner = 0;
      for (var j = match.end; j < args.length; j++) {
        final v = args[j];
        if (v == '(' || v == '[' || v == '{') {
          inner++;
        } else if (v == ')' || v == ']' || v == '}') {
          inner--;
        } else if (v == ',' && inner == 0) {
          return args.substring(match.end, j).trim();
        }
      }
      return args.substring(match.end).trim();
    }
  }
  return null;
}

List<File> _dartFiles(String dir) => Directory(dir)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList(growable: false);
