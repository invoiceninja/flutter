import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// CI lint: keep CLAUDE.md an index of rules rather than a record of
/// investigations, and keep every `§` citation in the repo resolvable.
///
/// CLAUDE.md grew from 195 KB to 366 KB in forty commits — about 4 KB each —
/// because the habit was to append a forensic paragraph to the relevant
/// section per shipped bug. The paragraphs are worth keeping; they just belong
/// in `docs/<topic>.md`. Prose alone did not survive a session that skimmed,
/// so the convention in CLAUDE.md's preamble is enforced here.
///
/// The sharp assertion is the line-length one: a rule fits on a line, an
/// investigation does not.
void main() {
  final claude = File('CLAUDE.md');
  late String text;
  late List<String> lines;

  setUpAll(() {
    expect(claude.existsSync(), isTrue, reason: 'CLAUDE.md should exist');
    text = claude.readAsStringSync();
    lines = text.split('\n');
  });

  /// Lines allowed to exceed [_maxLineChars]. Add an entry only with a reason,
  /// and prefer moving the paragraph to a doc instead.
  const allowedLongLines = <String>{};

  const maxBytes = 120 * 1024;
  const maxLineChars = 1500;
  const maxSectionBytes = 20 * 1024;
  const maxQuickIndexRows = 80;

  test('CLAUDE.md stays under ${maxBytes ~/ 1024} KB', () {
    final size = claude.lengthSync();
    expect(
      size,
      lessThanOrEqualTo(maxBytes),
      reason:
          'CLAUDE.md is ${(size / 1024).round()} KB. It is loaded into every '
          'session, so it is capped. Move a section body into docs/ and leave '
          'the rule plus a pointer — see the preamble.',
    );
  });

  test('no paragraph runs past $maxLineChars characters', () {
    final offenders = <String>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.length <= maxLineChars) continue;
      if (allowedLongLines.any(line.startsWith)) continue;
      offenders.add(
        'CLAUDE.md:${i + 1} (${line.length} chars): '
        '${line.substring(0, 90)}…',
      );
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'A rule fits on a line; an investigation does not. Move the evidence '
          'to the docs/ file named on the rule and leave the bolded lead '
          'sentence plus a pointer. Found:\n  ${offenders.join('\n  ')}',
    );
  });

  test('no ## section exceeds ${maxSectionBytes ~/ 1024} KB', () {
    final sizes = <String, int>{};
    var current = '(preamble)';
    for (final line in lines) {
      if (line.startsWith('## ')) current = line.substring(3);
      sizes[current] = (sizes[current] ?? 0) + line.length + 1;
    }
    final offenders = sizes.entries
        .where((e) => e.value > maxSectionBytes)
        .map((e) => '§ ${e.key} (${(e.value / 1024).round()} KB)')
        .toList();
    expect(
      offenders,
      isEmpty,
      reason:
          'A section past ${maxSectionBytes ~/ 1024} KB is carrying evidence '
          'that belongs in a topic doc. Found:\n  ${offenders.join('\n  ')}',
    );
  });

  test('the Quick Index stays under $maxQuickIndexRows rows', () {
    final rows = lines
        .where((l) => l.startsWith('| ') && !l.startsWith('|---'))
        .length;
    expect(
      rows,
      lessThanOrEqualTo(maxQuickIndexRows),
      reason:
          'The Quick Index has $rows rows. One row per user-visible symptom, '
          'never one per paragraph — check whether an existing left cell '
          'already covers the symptom before adding another.',
    );
  });

  test('every docs/ path named in CLAUDE.md resolves to a file', () {
    final refs = RegExp(
      r'`(docs/[A-Za-z0-9_.-]+\.md)`',
    ).allMatches(text).map((m) => m.group(1)!).toSet();
    expect(refs, isNotEmpty, reason: 'CLAUDE.md should cite its topic docs');
    final missing = refs.where((r) => !File(r).existsSync()).toList()..sort();
    expect(
      missing,
      isEmpty,
      reason: 'CLAUDE.md points at docs that do not exist: $missing',
    );
  });

  test('every `§ <Section>` citation in the repo resolves to a heading', () {
    // Headings live in CLAUDE.md, in docs/*.md and in the root companions — a
    // bare `§ Foo` citation means "the heading named Foo, wherever it lives",
    // which is how this repo has always used them (`§ Navigation` is
    // docs/architecture.md; `§ F3d` is BACKEND.md). Roughly 180 such citations
    // exist across lib/ and test/, so a heading may be moved between files but
    // must never be renamed.
    final headings = <String>{};
    void collect(File f) {
      for (final line in f.readAsLinesSync()) {
        final m = RegExp(r'^#{2,4}\s+(.+?)\s*$').firstMatch(line);
        if (m == null) continue;
        final raw = m.group(1)!;
        headings.add(_fold(raw));
        // Citations routinely shorten a heading: `§ Design system` for
        // "Design system (v2)", `§ Sync` for "Sync — non-obvious rules".
        // Aliases come off the RAW heading — _fold has already flattened the
        // parentheses and em-dash these rules key on.
        headings.add(_fold(raw.replaceAll(RegExp(r'\s*\([^)]*\)\s*$'), '')));
        headings.add(_fold(raw.split(RegExp(r'\s+[—–-]\s+')).first));
      }
    }

    collect(claude);
    for (final f in Directory('docs').listSync()) {
      if (f is File && f.path.endsWith('.md')) collect(f);
    }
    for (final f in Directory('.').listSync()) {
      if (f is File && f.path.endsWith('.md')) collect(f);
    }
    headings.removeWhere((h) => h.isEmpty);

    /// Citations that named nothing even before the docs split. Each is a
    /// call-site typo, not a missing heading; fix the comment rather than
    /// growing this set.
    const preExistingDangling = <String>{
      'default to', // task_edit_times_section.dart — quotes prose, not a heading
      'kpi strip', // kpi_cell.dart — no heading has ever had this name
      'progressive disclosure', // expense_edit_screen.dart
      'mark paid toggle', // expense_edit_payment_section.dart
    };

    final citation = RegExp(r'§\s+([A-Z][^.,;:)`\n*\x27"]{2,60})');
    final offenders = <String>[];
    for (final dir in ['lib', 'test']) {
      for (final e in Directory(dir).listSync(recursive: true)) {
        if (e is! File || !e.path.endsWith('.dart')) continue;
        if (e.path.endsWith('.g.dart') || e.path.endsWith('.freezed.dart')) {
          continue;
        }
        if (e.path.endsWith('claude_md_size_test.dart')) continue;
        for (final m in citation.allMatches(e.readAsStringSync())) {
          final folded = _fold(m.group(1)!);
          if (preExistingDangling.contains(folded)) continue;
          // A citation trails off into prose ("§ Sync forbids…"), so accept it
          // when any leading run of its words names a heading.
          final words = folded.split(' ');
          final prefixes = [
            for (var n = words.length; n > 0; n--) words.take(n).join(' '),
          ];
          // A citation resolves if any leading word-run of it names a
          // heading, or is itself a leading word-run of one — the comment may
          // wrap mid-heading (`§ Design` / `(v2)` on the next line) or trail
          // off into prose (`§ Sync forbids…`). Word boundaries both ways, so
          // a two-letter fragment cannot match everything.
          // BACKEND.md numbers its asks `F4`, `F7`, `F3d` — two characters is
          // a legitimate section name there, so allow that shape explicitly
          // rather than dropping the length floor for everything.
          final sectionCode = RegExp(r'^[a-z]\d+[a-z]?$');
          final ok = prefixes.any(
            (p) =>
                headings.contains(p) ||
                ((p.length >= 3 || sectionCode.hasMatch(p)) &&
                    headings.any((h) => h.startsWith('$p '))),
          );
          if (!ok) offenders.add('${e.path}: § ${m.group(1)!.trim()}');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'These citations name a section that exists in neither CLAUDE.md, '
          'docs/ nor the root companions. Either a heading was renamed '
          '(restore the name — ~180 citations depend on them) or the citation '
          'is wrong.\n  ${offenders.join('\n  ')}',
    );
  });
}

/// Lower-case, punctuation collapsed to single spaces. A citation is written
/// by hand in a doc comment and often wraps mid-heading, so `§ Design` must
/// still match "Design system (v2)" and `§ F3d` must match "F3d. A comment…".
String _fold(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
