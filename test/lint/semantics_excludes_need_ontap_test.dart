import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Opt-out marker — see the doc below.
const String _kAllowMarker = 'lint: allow-semantics-no-ontap';

/// CI lint: a `Semantics` that declares an interactive **role** and **excludes
/// its own subtree** must re-declare `onTap`.
///
/// `ExcludeSemantics` (and the `excludeSemantics: true` property, which is the
/// same thing spelled differently) drops every descendant node, and for an
/// `InkWell` / `GestureDetector` that subtree is where the `SemanticsAction.tap`
/// lives — `InkResponse` builds its own `Semantics(onTap: simulateTap)` and
/// notably does **not** set `button`, so the role and the action come from two
/// different nodes. Exclude the child and you keep the role and lose the
/// action: TalkBack announces a button it cannot activate, and Switch Access
/// never enumerates it at all, because it scans for clickable nodes.
///
/// CLAUDE.md states the rule three times (§ the narrow-list-row paragraph, §
/// the task-calendar panel, § the billing-doc call button) and it has still
/// been broken six times: `detail_info_row.dart` (#109),
/// `phone_number_value.dart` (#128), the #137 calendar cell, and then
/// `activity_feed_row.dart`, `kpi_card.dart` and `activity_record_row.dart`
/// (invoiceninja/flutter#143).
///
/// **Both spellings have gone wrong, and only one of them was ever named.** The
/// first three are `excludeSemantics: true` — the property form the rule is
/// written about — and each was found and fixed one issue at a time. The last
/// three are `child: ExcludeSemantics(…)`, the spelling no rule mentions, and
/// every one of that spelling's role-bearing sites was live in `lib/`
/// simultaneously until #143 went looking (its other five excludes carry no
/// role, so there is nothing for them to re-declare). Prose
/// caught the form it described and missed the form it did not; that asymmetry
/// is the argument for a scan. Nothing about either shape looks different at
/// the call site, none of it fails to compile, and a widget test only catches
/// it if someone thinks to assert `hasAction`.
///
/// Opt out with `// $_kAllowMarker <reason>` on the offending line or the one
/// above it, the placement `no_horizontal_more_icon_test.dart` already uses.
///
/// Not flagged, deliberately: an exclude with no interactive role
/// (`key_cap.dart` labels a decorative chip), and one paired with
/// `IgnorePointer` / `enabled: false` to *suppress* interaction
/// (`reports_body.dart`, `task_calendar_card.dart`, `activity_filter_sheet.dart`,
/// `shortcut_hint_overlay.dart`). Both are correct by construction: there is no
/// action to re-declare.
///
/// Four limits worth knowing rather than discovering. The scan reads
/// `Semantics(`, so a `Semantics.fromProperties(` would be invisible to it —
/// nothing in `lib/` uses that spelling today, and this is the note that says
/// so. The depth counter that keeps a nested call's arguments out of the match
/// does not know about quotes, so a `button:` or `onTap:` inside a string
/// literal would read as an argument; no site does that either. The role and
/// `onTap` predicates match at **depth 0** while the exclude match deliberately
/// does not — an `ExcludeSemantics` nested under a `Padding` still prunes the
/// subtree, whereas an `onTap:` on a child cannot stand in for the wrapper's
/// own. The cost of that asymmetry is a partial exclude spelled `child:` — one
/// that drops only a decorative leaf while the tap node survives, as
/// `sidebar_footer_actions.dart` does under the name `glyph:` — which would
/// read as an offender; that is what the marker is for.
void main() {
  final offenders = <String>[];
  final scanned = <String>[];

  for (final file in _dartFiles('lib')) {
    final raw = file.readAsStringSync();
    if (!raw.contains('Semantics(')) continue;
    // Scan code, not prose. Without this the lint fails on the very comment
    // that explains it: three files in `lib/` carry the sentence "`InkResponse`'s
    // own `Semantics(onTap:)`", and an *unbalanced* `Semantics(` in a comment
    // would run the depth walk to end-of-file, swallowing every real call below
    // it. `no_list_tile_name_link_test.dart` learned this first.
    final lines = raw.split('\n');
    final source = _stripComments(raw);

    for (final call in _semanticsCalls(source)) {
      // The marker is a comment, so it has to be read off the untouched source.
      final line = lines[call.line - 1];
      final above = call.line > 1 ? lines[call.line - 2] : '';
      if (line.contains(_kAllowMarker) || above.contains(_kAllowMarker)) {
        continue;
      }
      final args = call.args;
      final declaresRole =
          _hasTopLevelArg(args, 'button') || _hasTopLevelArg(args, 'link');
      if (!declaresRole || !_excludesSubtree(args)) continue;

      scanned.add('${file.path}:${call.line}');
      if (!_hasTopLevelArg(args, 'onTap')) {
        offenders.add('${file.path}:${call.line}');
      }
    }
  }

  test('an excluding Semantics with a role re-declares its tap action', () {
    expect(
      offenders,
      isEmpty,
      reason:
          'these announce a role whose action was excluded with the subtree — '
          'add `onTap:` beside the role, or `// $_kAllowMarker <reason>` on '
          'that line or the one above if the role genuinely cannot be '
          'activated',
    );
  });

  test('the scan reaches both spellings', () {
    // A substring rule for one spelling scores the other's files as zero hosts
    // and passes them silently — which is exactly how the three widget-form
    // sites drifted while the four property-form sites stayed correct.
    expect(
      scanned.where((s) => s.contains('link_text.dart')),
      isNotEmpty,
      reason: 'the property form must be scanned (`excludeSemantics: true`)',
    );
    expect(
      scanned.where((s) => s.contains('activity_record_row.dart')),
      isNotEmpty,
      reason: 'the widget form must be scanned (`child: ExcludeSemantics(`)',
    );
    // A floor, not an exact count: a new correct site should not fail the
    // build, but a scan that silently stops finding most of them should.
    expect(
      scanned.length,
      greaterThanOrEqualTo(10),
      reason: 'only ${scanned.length} hosts found — the scan has gone blind',
    );
  });

  test('an offending shape is flagged, and a nested onTap does not save it', () {
    // Without this the whole file is vacuous: replace the `onTap` predicate
    // with `=> true` and every other test here still passes, because they only
    // ever assert that today's tree is clean. This is the one that asserts the
    // rule can fire — and it pins the depth discipline at the same time, which
    // no site in `lib/` currently exercises: the excluded child's own `onTap`
    // is precisely what the wrapper must not be credited with.
    const offender = '''
Semantics(
  button: true,
  child: ExcludeSemantics(child: InkWell(onTap: open, child: row)),
)''';
    final call = _semanticsCalls(offender).single;
    expect(_hasTopLevelArg(call.args, 'button'), isTrue);
    expect(_excludesSubtree(call.args), isTrue);
    expect(
      _hasTopLevelArg(call.args, 'onTap'),
      isFalse,
      reason: "the InkWell's own onTap is exactly what the exclude drops",
    );

    const fixed = '''
Semantics(
  button: true,
  onTap: open,
  child: ExcludeSemantics(child: InkWell(onTap: open, child: row)),
)''';
    expect(
      _hasTopLevelArg(_semanticsCalls(fixed).single.args, 'onTap'),
      isTrue,
      reason: 're-declaring it beside the role is what clears the rule',
    );
  });

  test('an exclude that excludes nothing is not an exclude', () {
    // `excludeSemantics: false` and `excluding: false` are no-ops, so the
    // subtree — and its tap action — survives and there is nothing to
    // re-declare. Every site in `lib/` passes a literal true today, so only a
    // fixture can hold this.
    for (final inert in const [
      'Semantics(button: true, excludeSemantics: false, child: x)',
      'Semantics(button: true, child: ExcludeSemantics(excluding: false, '
          'child: x))',
    ]) {
      expect(
        _excludesSubtree(_semanticsCalls(inert).single.args),
        isFalse,
        reason: inert,
      );
    }
    expect(
      _excludesSubtree(
        _semanticsCalls(
          'Semantics(button: true, child: const ExcludeSemantics(child: x))',
        ).single.args,
      ),
      isTrue,
      reason: 'a `const` before the widget must not hide it',
    );
  });

  test('a deliberately inert exclude is never a host', () {
    // The doc above claims these are "not flagged, deliberately". This is what
    // makes that true rather than lucky: it is the role — not the exclude —
    // that selects a host, so an over-broad predicate later starts demanding
    // an action from a decorative or a disabled subtree, and says so here.
    for (final inert in const [
      'key_cap.dart', // a labelled, decorative chip
      'reports_body.dart', // `enabled: false` + IgnorePointer
      'task_calendar_card.dart', // suppressed while unloaded
      'activity_filter_sheet.dart', // suppressed while the lens is narrowed
      'shortcut_hint_overlay.dart', // IgnorePointer over the whole overlay
    ]) {
      expect(
        scanned.where((s) => s.contains(inert)),
        isEmpty,
        reason: '$inert excludes nothing interactive and must not be a host',
      );
    }
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

/// Every `Semantics(` invocation's own argument text, with nested calls kept
/// intact but nested `Semantics(` invocations returned as separate entries.
List<_Call> _semanticsCalls(String source) {
  final calls = <_Call>[];
  final pattern = RegExp(r'(?<![A-Za-z0-9_.])Semantics\(');
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

/// Whether this `Semantics` drops its own descendants' nodes — either spelling,
/// and only when it actually does: an `excluding: false` excludes nothing.
bool _excludesSubtree(String args) {
  if (RegExp(r'(?<![A-Za-z0-9_])excludeSemantics:\s*true').hasMatch(args)) {
    return true;
  }
  final widget = RegExp(
    r'(?<![A-Za-z0-9_])child:\s*(const\s+)?ExcludeSemantics\(',
  ).firstMatch(args);
  if (widget == null) return false;
  return !RegExp(r'excluding:\s*false').hasMatch(args.substring(widget.end));
}

/// Whether [args] passes `name:` at its own level, ignoring nested calls —
/// an `onTap:` on a child widget must not satisfy the outer `Semantics`.
bool _hasTopLevelArg(String args, String name) {
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
      if (match != null) return true;
    }
  }
  return false;
}

List<File> _dartFiles(String dir) => Directory(dir)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList(growable: false);
