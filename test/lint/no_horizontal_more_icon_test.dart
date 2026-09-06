import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Opt-out marker — see the doc below.
const String _kAllowMarker = 'lint: allow-more-horiz';

/// Matches every horizontal-dots spelling Material ships.
///
/// **No trailing `\b`**, deliberately: `_` is a word character, so a boundary
/// there would match `Icons.more_horiz` and miss `more_horiz_rounded`,
/// `more_horiz_outlined` and `more_horiz_sharp` — three of the four ways a
/// reintroduction would actually be spelled. (`no_ink_widget_test.dart`, which
/// this file is modelled on, gets away with a closing `\(` because a call
/// always has one; there is no such delimiter after an icon name.) The
/// `pattern catches every spelling` test below pins that, because a source scan
/// can only ever prove the absence of what it can already see.
final RegExp _kMoreHorizPattern = RegExp(r'\bIcons\.more_horiz');

/// CI lint: no `Icons.more_horiz` in `lib/`. Every overflow / "more" menu in
/// the app uses the vertical `Icons.more_vert`, whatever the surface:
///
/// * the labeled `⋮ More` button on the wide detail / edit header and the
///   multi-select bulk bar (`_MoreMenu`, `entity_detail_actions_row.dart`),
/// * the compact `⋮` trigger one breakpoint down (`_OverflowMenuButton`),
/// * every list row (`EntityActionsPopupButton`, which deliberately has no
///   icon parameter — the glyph is not a per-call-site choice).
///
/// The two `IconData`s are interchangeable at every call site and nothing
/// type-checks the difference, so a mismatch neither fails to compile nor
/// throws — it just renders the wrong glyph. That is exactly how the app came
/// to ship both at once: 15 of the 17 entity tiles passed
/// `icon: Icons.more_horiz` for their narrow row while Clients and Vendors
/// passed nothing and took the `more_vert` default, so the same list showed a
/// different menu icon depending on which entity you opened. It survived
/// review for the life of those files, and no widget test could see it —
/// each one asserted whichever glyph its own widget happened to pass.
///
/// **A second test below catches the same bug spelled as an absence.**
/// `PopupMenuButton` defaults its trigger to `Icon(Icons.adaptive.more)`
/// (`material/popup_menu.dart`), and `Icons.adaptive.more` resolves to
/// `Icons.more_horiz` on **iOS and macOS** — both of which this app ships
/// (`icons.dart`: `_isCupertino()` is true for `TargetPlatform.iOS` and
/// `.macOS`). So a `PopupMenuButton` that passes neither `icon:` nor `child:`
/// renders the horizontal glyph on two of the five supported platforms while
/// every other overflow surface renders `⋮` — and no grep for `more_horiz`
/// can see it, because the offending token is the argument that *isn't there*.
/// Four sites were in exactly that state, including one class named
/// `SettingsEntityOverflowMenu`. A `child:` is fine: it replaces the icon
/// outright, so a labeled trigger renders no dots at all.
///
/// **House style, not a law of physics.** Material's own convention pairs a
/// *labeled* overflow with `⋯` and reserves `⋮` for a bare icon; the app
/// trades that for one glyph everywhere. If a surface genuinely needs the
/// horizontal ellipsis — a text-truncation affordance, say, which is a
/// different idea wearing the same dots — put `// lint: allow-more-horiz` on
/// the line or the line above it, with a reason.
void main() {
  test('lib/ does not use Icons.more_horiz', () {
    final pattern = _kMoreHorizPattern;
    final offenders = <String>[];
    final libDir = Directory('lib');
    expect(libDir.existsSync(), isTrue, reason: 'lib/ should exist');

    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('.g.dart')) continue;
      if (entity.path.endsWith('.freezed.dart')) continue;

      final lines = entity.readAsStringSync().split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (!pattern.hasMatch(lines[i])) continue;
        final line = lines[i].trim();
        // A line whose trimmed form starts with `//` cannot hold live code, so
        // prose about `Icons.more_horiz` — including the doc comment on
        // `EntityActionsPopupButton` explaining this very ban — costs nothing.
        if (line.startsWith('//')) continue;
        if (line.contains(_kAllowMarker)) continue;
        if (i > 0 && lines[i - 1].contains(_kAllowMarker)) continue;
        offenders.add('${entity.path}:${i + 1}:  $line');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Overflow menus use the vertical Icons.more_vert everywhere — the '
          'labeled "More" button, the compact trigger and every list row. The '
          'two glyphs are interchangeable IconData, so a mismatch compiles, '
          'runs, and simply renders the wrong icon; that is how 15 entity '
          'tiles once shipped a different menu glyph from Clients and '
          'Vendors. If a surface truly needs the horizontal ellipsis, opt out '
          'with `// $_kAllowMarker` plus a reason. Found:\n  '
          '${offenders.join('\n  ')}',
    );
  });

  test('the pattern catches every horizontal-dots spelling', () {
    // The scan above can only report what it matches, so a silent narrowing of
    // the regex would make it pass forever. Pin the match set here instead.
    for (final name in const [
      'Icons.more_horiz',
      'Icons.more_horiz_rounded',
      'Icons.more_horiz_outlined',
      'Icons.more_horiz_sharp',
    ]) {
      expect(
        _kMoreHorizPattern.hasMatch('        icon: const Icon($name),'),
        isTrue,
        reason: '$name must be caught',
      );
    }

    // The vertical glyph — the whole point — must not match, nor may an
    // identifier that merely ends in the banned name.
    expect(_kMoreHorizPattern.hasMatch('Icons.more_vert'), isFalse);
    expect(_kMoreHorizPattern.hasMatch('MyIcons.more_horiz'), isFalse);
  });

  test('every PopupMenuButton in lib/ declares its trigger', () {
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('.g.dart')) continue;
      if (entity.path.endsWith('.freezed.dart')) continue;

      final raw = entity.readAsStringSync();
      // Comments and string literals are blanked first: several files discuss
      // `PopupMenuButton<T>` in prose, and a doc-comment mention is not a call.
      final src = _blankCommentsAndStrings(raw);

      for (final m in RegExp(r'\bPopupMenuButton\s*<').allMatches(src)) {
        final open = src.indexOf('(', m.end);
        if (open < 0) continue;
        final args = _balanced(src, open);
        if (args == null) continue;
        final keys = _topLevelArgNames(src.substring(open, args + 1));
        if (keys.contains('icon') || keys.contains('child')) continue;
        final line = '\n'.allMatches(src.substring(0, m.start)).length + 1;
        if (raw.split('\n')[line - 1].contains(_kAllowMarker)) continue;
        offenders.add('${entity.path}:$line');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'A PopupMenuButton with neither `icon:` nor `child:` falls back to '
          'Icon(Icons.adaptive.more), which is Icons.more_horiz on iOS and '
          'macOS — so it renders the horizontal glyph on two shipped '
          'platforms while every other overflow menu renders the vertical one. '
          'Pass `icon: const Icon(Icons.more_vert)`, or a `child:` if the '
          'trigger is labeled. Found:\n  ${offenders.join('\n  ')}',
    );
  });
}

/// Replaces every comment and string literal with spaces, preserving offsets
/// and line breaks so match positions still map to real line numbers.
String _blankCommentsAndStrings(String src) {
  final out = StringBuffer();
  var i = 0;
  while (i < src.length) {
    if (src.startsWith('//', i)) {
      final end = src.indexOf('\n', i);
      final stop = end < 0 ? src.length : end;
      out.write(' ' * (stop - i));
      i = stop;
    } else if (src.startsWith('/*', i)) {
      final end = src.indexOf('*/', i + 2);
      final stop = end < 0 ? src.length : end + 2;
      out.write(src.substring(i, stop).replaceAll(RegExp('[^\n]'), ' '));
      i = stop;
    } else if (src[i] == "'" || src[i] == '"') {
      final quote = src[i];
      var j = i + 1;
      while (j < src.length && src[j] != quote) {
        j += src[j] == r'\' ? 2 : 1;
      }
      final stop = j >= src.length ? src.length : j + 1;
      out.write(src.substring(i, stop).replaceAll(RegExp('[^\n]'), ' '));
      i = stop;
    } else {
      out.write(src[i]);
      i++;
    }
  }
  return out.toString();
}

/// Index of the `)` matching the `(` at [open], or null if unbalanced.
int? _balanced(String src, int open) {
  var depth = 0;
  for (var i = open; i < src.length; i++) {
    if (src[i] == '(') depth++;
    if (src[i] == ')') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return null;
}

/// Named-argument labels at the top nesting level of an argument list that
/// starts at `(` and ends at its matching `)`.
List<String> _topLevelArgNames(String body) {
  final names = <String>[];
  final label = RegExp(r'([A-Za-z_]\w*)\s*:');
  var depth = 0;
  var i = 0;
  while (i < body.length) {
    final c = body[i];
    if (c == '(' || c == '[' || c == '{') {
      depth++;
      i++;
      continue;
    }
    if (c == ')' || c == ']' || c == '}') {
      depth--;
      i++;
      continue;
    }
    if (depth == 1) {
      final m = label.matchAsPrefix(body, i);
      final prev = i == 0 ? ' ' : body[i - 1];
      if (m != null && !RegExp(r'[\w.]').hasMatch(prev)) {
        names.add(m.group(1)!);
        i = m.end;
        continue;
      }
    }
    i++;
  }
  return names;
}
