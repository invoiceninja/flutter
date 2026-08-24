import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../_localization_helper.dart';

/// CI lint: no bundled string reaches the UI with renderable HTML markup still
/// in it.
///
/// Transifex ships presentational tags inside translated copy —
/// `fill_products_help` is `"Selecting a product will automatically <b>fill in
/// the description and cost</b>"`. Flutter's [Text] has no HTML layer, so a
/// plain `Text(context.tr(key))` paints `<b>` and `</b>` to the user. That
/// shipped as invoiceninja/flutter#75 on Product Settings, and a sweep found
/// the same defect behind the Reports "Email" toast (which was pointed at
/// `email_sent`, a *notification-preference label*, not a confirmation).
///
/// The fix at a call site is one of: render through `MarkupText`
/// (`lib/ui/core/widgets/markup_text.dart`), or — when the destination is a
/// plain [String] such as a toast or a dialog message — point at a key that
/// says what you mean.
///
/// ## Scope, deliberately narrow
///
/// Only the four tags `MarkupText` interprets are checked, and every locale
/// bundle is scanned (not just English) because a translator can add emphasis
/// English lacks. Structural tags — `<p>`, `<br>`, `<ul>`, `<a>` — appear only
/// in keys the app never renders (server-side email bodies), and `<ninja>` in
/// `variables_hint_template` names a real template tag the user has to type,
/// so flagging those would be noise.
///
/// ## What this does NOT catch
///
/// Same text-scan blind spots as `no_unsubstituted_placeholders_test`: a key
/// held in a variable, a const list, or a positional argument is invisible.
/// `design_edit_screen`'s `context.tr(isTemplate ? 'a' : 'b')` is one such
/// call today — neither branch carries markup, but a future translation could.
const kRenderableMarkupTags = {'b', 'strong', 'i', 'em'};

void main() {
  test('lib/ renders no bundled string with raw <b>/<i> markup', () {
    final markupKeys = _keysCarryingMarkup();

    // The bundle has to actually contain the thing we are linting for, or a
    // green run means nothing.
    expect(
      markupKeys,
      contains('fill_products_help'),
      reason:
          'Locale bundles no longer carry inline markup — if Transifex '
          'cleaned them up, delete this lint and MarkupText with it.',
    );

    final offenders = <String>[];
    for (final file in _dartFiles()) {
      final content = _stripComments(file.readAsStringSync());
      for (final match in _trCall.allMatches(content)) {
        final key = match.group(1)!;
        final tags = markupKeys[key];
        if (tags == null) continue;
        // `MarkupText(context.tr('k'))` is the sanctioned render. The window
        // clears the widest shape `dart format` emits — the widget name, an
        // open paren, and a wrapped argument at deep indentation.
        final head = content.substring(
          (match.start - 60).clamp(0, content.length),
          match.start,
        );
        if (head.contains('MarkupText(')) continue;
        offenders.add(
          '${file.path}:${_lineOf(content, match.start)}  '
          "tr('$key') carries ${tags.map((t) => '<$t>').join(', ')} — "
          'render it with MarkupText, or point at a markup-free key',
        );
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'A bundled string is rendered with its HTML markup intact, so the '
          'user sees the tags. Found:\n  ${offenders.join('\n  ')}',
    );
  });

  test('markup keys resolve for English so the lint sees real values', () {
    // Guards the helper, not the app: if `enStrings()` ever came back empty
    // the offender list would be empty too, and this lint would pass forever.
    expect(enStrings()['fill_products_help'], contains('<b>'));
  });
}

/// Every locale key whose value carries a tag `MarkupText` would render,
/// mapped to the tags found. Scans **all** bundles — a translator can add
/// emphasis the English source lacks.
Map<String, Set<String>> _keysCarryingMarkup() {
  final out = <String, Set<String>>{};
  final dir = Directory('assets/i18n');
  for (final file in dir.listSync().whereType<File>()) {
    if (!file.path.endsWith('.json')) continue;
    final decoded = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    decoded.forEach((key, value) {
      if (value is! String) return;
      for (final match in _markupTag.allMatches(value)) {
        final tag = match.group(1)!.toLowerCase();
        if (!kRenderableMarkupTags.contains(tag)) continue;
        (out[key] ??= <String>{}).add(tag);
      }
    });
  }
  return out;
}

final RegExp _markupTag = RegExp(r'</?([a-zA-Z][a-zA-Z0-9]*)>');

/// `tr('k')` / `context.tr('k')` / `lookup('k')`, with or without params —
/// unlike the placeholder lint, a params map does nothing about markup.
final RegExp _trCall = RegExp(
  r"""\b(?:tr|trIfDefined|lookup)\(\s*'([a-z0-9_]+)'""",
);

Iterable<File> _dartFiles() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'));

int _lineOf(String content, int offset) =>
    '\n'.allMatches(content.substring(0, offset)).length + 1;

/// Blanks `//` and `/* … */` comments, preserving length so line numbers stay
/// correct. String literals are respected so `'http://x'` can't swallow a
/// line. Mirrors `no_unsubstituted_placeholders_test._stripComments`.
String _stripComments(String source) {
  final out = source.split('');
  var i = 0;
  String? quote;
  while (i < source.length) {
    final c = source[i];
    if (quote != null) {
      if (c == r'\') {
        i += 2;
        continue;
      }
      if (c == quote) quote = null;
      i++;
      continue;
    }
    if (c == "'" || c == '"') {
      quote = c;
      i++;
      continue;
    }
    if (c == '/' && i + 1 < source.length) {
      final next = source[i + 1];
      if (next == '/') {
        while (i < source.length && source[i] != '\n') {
          out[i++] = ' ';
        }
        continue;
      }
      if (next == '*') {
        final end = source.indexOf('*/', i + 2);
        final stop = end == -1 ? source.length : end + 2;
        for (var j = i; j < stop; j++) {
          if (out[j] != '\n') out[j] = ' ';
        }
        i = stop;
        continue;
      }
    }
    i++;
  }
  return out.join();
}
