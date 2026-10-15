import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// CI lint: every list row's floor and padding go through the list-density
/// helpers, so the Normal / Compact preference reaches all of them
/// (docs/list-density.md).
///
/// A literal is invisible at review time and silently opts its row out:
/// Compact would tighten sixteen lists and leave the seventeenth at 72 px, and
/// nothing would throw. Three ways that happens, each pinned below:
///
///  * a `*_list_tile.dart` hard-coding its vertical padding
///    (`fromSTEB(16, 10, …)` / `fromSTEB(16, 14, …)`) instead of
///    `listRowPadding(context)`;
///  * code reading `kEntityListRowHeight` directly — as a `minHeight:`, a
///    `SizedBox(height:)`, an `itemExtent:` or anything else — instead of
///    `entityListRowHeight(context)` / `EntityListRowFloor`.
///    `kEntityListRowHeight` is only the Normal value, so outside
///    `entity_list_constants.dart` it may appear in comments only;
///  * `main.dart` no longer mounting `ListDensityScope` — with no scope every
///    reader answers Normal, which is exactly what every widget test that
///    doesn't mount one expects, so no other test would notice.
///
/// And one the other way round: only the list scaffold passes `dense:` to
/// `EntityListStatusTabs`. The dashboard's Invoices & Quotes panel reuses that
/// strip in its wrapped form, and the dashboard is outside the density's
/// scope.
void main() {
  test('every entity-list tile pads through listRowPadding', () {
    final tiles = Directory('lib/ui/features')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('_list_tile.dart'))
        .toList();
    expect(tiles, isNotEmpty);

    final literal = RegExp(r'fromSTEB\(\s*16\s*,\s*1[04]\s*,');
    final offenders = <String>[];
    final missing = <String>[];
    for (final f in tiles) {
      final src = f.readAsStringSync();
      if (literal.hasMatch(src)) offenders.add(f.path);
      if (!src.contains('listRowPadding(')) missing.add(f.path);
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'These tiles hard-code their row padding, so the Compact list '
          'density never reaches them. Use listRowPadding(context) '
          '(normalVertical: for a tile whose Normal padding differs).',
    );
    expect(
      missing,
      isEmpty,
      reason: 'These tiles do not pad through listRowPadding(context).',
    );
  });

  test('only entity_list_constants.dart reads the Normal row height', () {
    final bare = RegExp(r'\bkEntityListRowHeight\b');
    final offenders = <String>[
      for (final f in _dartFiles('lib'))
        if (!f.path.endsWith('entity_list_constants.dart') &&
            bare.hasMatch(_stripComments(f.readAsStringSync())))
          f.path,
    ];
    expect(
      offenders,
      isEmpty,
      reason:
          'kEntityListRowHeight is the Normal floor only. Size a list row '
          'with entityListRowHeight(context) or EntityListRowFloor so the '
          'Compact list density reaches it.',
    );
  });

  test('main.dart mounts the ListDensityScope', () {
    expect(
      _stripComments(File('lib/main.dart').readAsStringSync()),
      contains('ListDensityScope('),
      reason:
          'Without the scope every list renders Normal and the List density '
          'setting silently does nothing.',
    );
  });

  test('only the list scaffold densifies the status-tab strip', () {
    final call = RegExp(r'EntityListStatusTabs\(');
    final offenders = <String>[];
    var seenScaffold = false;
    for (final f in _dartFiles('lib')) {
      final code = _stripComments(f.readAsStringSync());
      for (final m in call.allMatches(code)) {
        final args = _callArgs(code, m.end);
        if (!RegExp(r'\bdense\s*:').hasMatch(args)) continue;
        if (f.path.endsWith('entity_list_screen_scaffold.dart')) {
          seenScaffold = true;
        } else {
          offenders.add(f.path);
        }
      }
    }
    expect(
      seenScaffold,
      isTrue,
      reason: 'The list scaffold must pass `dense:` to its status strip.',
    );
    expect(
      offenders,
      isEmpty,
      reason:
          'Only the entity list follows the list density. The dashboard '
          'reuses this strip and is out of the density\'s scope.',
    );
  });
}

Iterable<File> _dartFiles(String root) => Directory(root)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

/// Drops `//` comments (doc comments included) so prose naming a symbol is
/// never mistaken for code — the same cut `call_note_wiring_test.dart` makes.
String _stripComments(String source) => source
    .split('\n')
    .map((line) {
      final i = line.indexOf('//');
      return i == -1 ? line : line.substring(0, i);
    })
    .join('\n');

/// The argument text of the call whose `(` ends at [open], up to its
/// matching `)`.
String _callArgs(String code, int open) {
  var depth = 1;
  for (var i = open; i < code.length; i++) {
    final c = code[i];
    if (c == '(') depth++;
    if (c == ')' && --depth == 0) return code.substring(open, i);
  }
  return code.substring(open);
}
