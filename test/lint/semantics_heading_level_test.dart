import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// CI lint: a `Semantics` / `SemanticsProperties` that passes `header: true`
/// must also pass `headingLevel:`.
///
/// Since Flutter 3.47, `header` does nothing on iOS or Android: the engine
/// reads only `headingLevel` there (`UIAccessibilityTraitHeader`,
/// `View.setHeading`). The desktop accessibility bridge and the web still take
/// the heading role from `header` (`is_header`), so neither flag works on
/// every platform alone, and both are kept. Nothing fails to compile and no
/// widget test notices. A heading that sets only `header` just stops being a
/// heading for VoiceOver and TalkBack. docs/screen-reader-headings.md.
void main() {
  final offenders = <String>[];
  final scanned = <String>[];

  for (final file in _dartFiles('lib')) {
    final raw = file.readAsStringSync();
    if (!raw.contains('header: true')) continue;
    final source = _stripComments(raw);
    for (final call in _semanticsCalls(source)) {
      if (!RegExp(r'^\s*true\b').hasMatch(_topLevelArg(call.args, 'header'))) {
        continue;
      }
      scanned.add('${file.path}:${call.line}');
      if (_topLevelArg(call.args, 'headingLevel').isEmpty) {
        offenders.add('${file.path}:${call.line}');
      }
    }
  }

  test('every header: true also sets headingLevel', () {
    expect(
      offenders,
      isEmpty,
      reason:
          'header: true alone is a no-op on iOS and Android since Flutter '
          '3.47. Add `headingLevel: 1` (dialog or sheet title) or '
          '`headingLevel: 2` (a section heading) beside it. Keep `header` too, '
          'because desktop and web still read it',
    );
  });

  test('the scan finds the headings', () {
    // A floor, not an exact count: a scan that silently stops matching would
    // otherwise pass on zero hosts.
    expect(
      scanned.length,
      greaterThanOrEqualTo(9),
      reason:
          'only ${scanned.length} headings found, so the scan has gone blind',
    );
    expect(
      scanned.where((s) => s.contains('analytics_kit.dart')),
      isNotEmpty,
      reason: 'a call written on one line must be scanned too',
    );
  });

  test('the rule can fire, and a nested headingLevel does not satisfy it', () {
    const offender = '''
Semantics(
  header: true,
  child: Semantics(headingLevel: 2, child: title),
)''';
    final outer = _semanticsCalls(offender).first;
    expect(_topLevelArg(outer.args, 'header'), contains('true'));
    expect(
      _topLevelArg(outer.args, 'headingLevel'),
      isEmpty,
      reason: "the child's own headingLevel is a different node",
    );
    expect(
      _topLevelArg(
        _semanticsCalls(
          'SemanticsProperties(header: true, headingLevel: 1)',
        ).single.args,
        'headingLevel',
      ),
      isNotEmpty,
    );
  });

  test('a cell() style flag named header is not a Semantics call', () {
    // `report_document_view.dart` passes `header: true` to a local `cell()`
    // helper that picks a text style; it builds no Semantics.
    expect(
      scanned.where((s) => s.contains('report_document_view.dart')),
      hasLength(1),
    );
  });
}

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

/// Every `Semantics(` / `SemanticsProperties(` invocation's own argument text.
List<_Call> _semanticsCalls(String source) {
  final calls = <_Call>[];
  final pattern = RegExp(r'(?<![A-Za-z0-9_.])Semantics(Properties)?\(');
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

/// The text after `name:` when [args] passes it at its own level (ignoring
/// nested calls), or `''` when it does not.
String _topLevelArg(String args, String name) {
  var depth = 0;
  final pattern = RegExp('(?<![A-Za-z0-9_])$name:');
  for (var i = 0; i < args.length; i++) {
    final c = args[i];
    if (c == '(' || c == '[' || c == '{') {
      depth++;
    } else if (c == ')' || c == ']' || c == '}') {
      depth--;
    } else if (depth == 0) {
      final match = pattern.matchAsPrefix(args, i);
      if (match != null) return args.substring(match.end);
    }
  }
  return '';
}

List<File> _dartFiles(String dir) => Directory(dir)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList(growable: false);
