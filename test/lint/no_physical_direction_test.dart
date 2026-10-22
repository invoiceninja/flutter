import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Opt-out marker — see the doc below.
const String _kAllowMarker = 'rtl: physical';

/// CI lint: layout in `lib/` says start / end, never left / right.
///
/// Arabic, Persian and Hebrew lay the app out right-to-left
/// (`GlobalWidgetsLocalizations` sets `Directionality` from the locale). Every
/// directional API mirrors with it — `EdgeInsetsDirectional`,
/// `AlignmentDirectional`, `PositionedDirectional`, `BorderDirectional`,
/// `BorderRadiusDirectional`, `TextAlign.start` / `end` — and every physical
/// one stays put, so an indent lands on the outer edge, a button hugs the far
/// side of its row, a badge sits on the wrong corner. It analyzes clean,
/// throws nothing, and every widget test that pumps in English passes.
///
/// Flagged, outside comments: an asymmetric `EdgeInsets.only` (a `left:` or
/// `right:` without the other at the same value) or `EdgeInsets.fromLTRB`, any
/// `Alignment.centerLeft` / `topRight` / …, a `Positioned` with `left:` xor
/// `right:`, a `BorderRadius.only` whose corners don't mirror, any
/// `BorderRadius.horizontal`, a `Border` with `left:` xor `right:`, and
/// `TextAlign.left` / `right`. Symmetric uses are fine — they look the same
/// both ways.
///
/// **Some things are physical**: the drawn window buttons and the title bar
/// (the OS chrome), the invoice designer's page (a picture of a PDF), a chart's
/// time axis, a colour picker's hue strip. Put `// rtl: physical <reason>` on
/// the line or the line above it. See `docs/right-to-left-layout.md`.
void main() {
  test('lib/ lays out with start / end, not left / right', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('.g.dart')) continue;
      if (entity.path.endsWith('.freezed.dart')) continue;
      final source = entity.readAsStringSync();
      for (final hit in physicalDirectionHits(source)) {
        offenders.add('${entity.path}:${hit.line}:  ${hit.text}');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Use the directional form (EdgeInsetsDirectional, '
          'AlignmentDirectional.centerStart/End, PositionedDirectional, '
          'BorderDirectional, BorderRadiusDirectional, TextAlign.start/end) '
          'so the layout mirrors in Arabic, Persian and Hebrew. If the side '
          'really is physical, mark it `// $_kAllowMarker <reason>`. '
          'Found ${offenders.length}:\n  ${offenders.join('\n  ')}',
    );
  });

  group('physicalDirectionHits', () {
    List<int> lines(String s) =>
        physicalDirectionHits(s).map((h) => h.line).toList();

    test('flags the asymmetric forms', () {
      expect(lines('x(EdgeInsets.only(left: 8));'), [1]);
      expect(lines('x(EdgeInsets.fromLTRB(16, 4, 4, 4));'), [1]);
      expect(lines('x(Alignment.centerLeft);'), [1]);
      expect(lines('Positioned(\n  right: 0,\n  child: y)'), [1]);
      expect(lines('BorderRadius.only(topLeft: r)'), [1]);
      expect(lines('BorderRadius.horizontal(left: r)'), [1]);
      expect(lines('Border(left: side)'), [1]);
      expect(lines('Text(a, textAlign: TextAlign.right)'), [1]);
      expect(
        lines('EdgeInsets.only(\n  left: InSpacing.md(context),\n  top: 4)'),
        [1],
      );
    });

    test('passes the symmetric and directional forms', () {
      expect(lines('EdgeInsets.only(top: 8, bottom: 4)'), isEmpty);
      expect(lines('EdgeInsets.only(left: 8, right: 8)'), isEmpty);
      expect(lines('EdgeInsets.fromLTRB(8, 4, 8, 12)'), isEmpty);
      expect(lines('EdgeInsetsDirectional.only(start: 8)'), isEmpty);
      expect(lines('AlignmentDirectional.centerStart'), isEmpty);
      expect(lines('Positioned(left: 0, right: 0, child: y)'), isEmpty);
      expect(lines('Positioned.fill(child: y)'), isEmpty);
      expect(lines('PositionedDirectional(start: 0)'), isEmpty);
      expect(lines('BorderRadius.only(topLeft: r, topRight: r)'), isEmpty);
      expect(lines('BorderDirectional(start: side)'), isEmpty);
      expect(lines('Border(left: s, right: s)'), isEmpty);
      expect(lines('// EdgeInsets.only(left: 8)'), isEmpty);
    });

    test('honours the opt-out on the line or the line above', () {
      expect(lines('Alignment.centerLeft // rtl: physical canvas'), isEmpty);
      expect(
        lines('// rtl: physical title bar\nPositioned(left: 0, child: y)'),
        isEmpty,
      );
    });
  });
}

typedef PhysicalHit = ({int line, String text});

final _call = RegExp(
  r'\b(EdgeInsets\.only|EdgeInsets\.fromLTRB|Positioned|BorderRadius\.only|'
  r'BorderRadius\.horizontal|Border)\(',
);
final _token = RegExp(
  r'\bAlignment\.(?:center|top|bottom)(?:Left|Right)\b|\bTextAlign\.(?:left|right)\b',
);

/// Every physical-side layout use in [source], by 1-based line.
List<PhysicalHit> physicalDirectionHits(String source) {
  final code = _blankComments(source);
  final rawLines = source.split('\n');
  final hits = <int>{};

  int lineOf(int offset) => '\n'.allMatches(code.substring(0, offset)).length;

  for (final m in _token.allMatches(code)) {
    hits.add(lineOf(m.start));
  }
  for (final m in _call.allMatches(code)) {
    final args = _argsFrom(code, m.end);
    if (args == null) continue;
    if (_isPhysical(m.group(1)!, args)) hits.add(lineOf(m.start));
  }

  bool allowed(int i) =>
      rawLines[i].contains(_kAllowMarker) ||
      (i > 0 && rawLines[i - 1].contains(_kAllowMarker));

  return [
    for (final i in hits.toList()..sort())
      if (!allowed(i)) (line: i + 1, text: rawLines[i].trim()),
  ];
}

bool _isPhysical(String call, String args) {
  final named = _namedArgs(args);
  bool has(String k) => named.containsKey(k);
  bool sameValue(String a, String b) => named[a] == named[b];
  switch (call) {
    case 'EdgeInsets.only':
      if (!has('left') && !has('right')) return false;
      return !(has('left') && has('right') && sameValue('left', 'right'));
    case 'EdgeInsets.fromLTRB':
      final parts = _splitTopLevel(args);
      return parts.length == 4 && parts[0].trim() != parts[2].trim();
    case 'Positioned':
      return has('left') != has('right');
    case 'BorderRadius.horizontal':
      return true;
    case 'BorderRadius.only':
      return has('topLeft') != has('topRight') ||
          has('bottomLeft') != has('bottomRight') ||
          (has('topLeft') && !sameValue('topLeft', 'topRight')) ||
          (has('bottomLeft') && !sameValue('bottomLeft', 'bottomRight'));
    case 'Border':
      return has('left') != has('right');
  }
  return false;
}

/// The top-level `name: value` arguments of a call, values trimmed.
Map<String, String> _namedArgs(String args) {
  final out = <String, String>{};
  for (final part in _splitTopLevel(args)) {
    final m = RegExp(r'^\s*(\w+)\s*:\s*([\s\S]*)$').firstMatch(part);
    if (m != null) out[m.group(1)!] = m.group(2)!.trim();
  }
  return out;
}

List<String> _splitTopLevel(String args) {
  final parts = <String>[];
  var depth = 0;
  var start = 0;
  for (var i = 0; i < args.length; i++) {
    final c = args[i];
    if ('([{'.contains(c)) depth++;
    if (')]}'.contains(c)) depth--;
    if (c == ',' && depth == 0) {
      parts.add(args.substring(start, i));
      start = i + 1;
    }
  }
  final tail = args.substring(start);
  if (tail.trim().isNotEmpty) parts.add(tail);
  return parts;
}

/// The text between the `(` ending at [open] and its matching `)`.
String? _argsFrom(String code, int open) {
  var depth = 1;
  for (var i = open; i < code.length; i++) {
    final c = code[i];
    if ('([{'.contains(c)) depth++;
    if (')]}'.contains(c)) depth--;
    if (depth == 0) return code.substring(open, i);
  }
  return null;
}

/// [source] with `//` comments replaced by spaces (string literals kept), so
/// offsets and line numbers still line up.
String _blankComments(String source) {
  final out = StringBuffer();
  var i = 0;
  String? quote;
  while (i < source.length) {
    final c = source[i];
    if (quote != null) {
      out.write(c);
      if (c == r'\' && i + 1 < source.length) {
        out.write(source[i + 1]);
        i += 2;
        continue;
      }
      if (c == quote || c == '\n') quote = null;
      i++;
      continue;
    }
    if (c == "'" || c == '"') {
      quote = c;
      out.write(c);
      i++;
      continue;
    }
    if (c == '/' && i + 1 < source.length && source[i + 1] == '/') {
      while (i < source.length && source[i] != '\n') {
        out.write(' ');
        i++;
      }
      continue;
    }
    out.write(c);
    i++;
  }
  return out.toString();
}
