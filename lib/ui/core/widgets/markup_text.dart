import 'package:flutter/widgets.dart';

/// Inline presentational markup Transifex ships inside bundled strings —
/// `fill_products_help` is literally
/// `"Selecting a product will automatically <b>fill in the description and
/// cost</b>"`, and ~45 more keys carry a tag of some kind.
///
/// Flutter's [Text] has no HTML layer, so `Text(context.tr(key))` paints the
/// tags to the user verbatim. That shipped as invoiceninja/flutter#75. Render
/// those strings with [MarkupText] instead; `test/lint/no_raw_html_markup_test`
/// fails the build if a markup-bearing key goes back through a plain [Text].
///
/// Only `<b>`/`<strong>` and `<i>`/`<em>` are interpreted, and only in their
/// bare form. Everything else is left exactly as written — the `<ninja>` in
/// `variables_hint_template` names a real template tag the user has to type,
/// and a bare `<` or an unmatched `</b>` is far more likely to be content than
/// intent. A string with no markup at all therefore renders byte-for-byte the
/// same as it would through [Text].
class MarkupText extends StatelessWidget {
  const MarkupText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(children: markupSpans(data)),
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

/// Splits [text] into spans, turning `<b>`/`<strong>` into bold runs and
/// `<i>`/`<em>` into italic ones. Nesting is tracked by depth, so
/// `<b>a<i>b</i></b>` bolds both runs and italicises the inner one.
///
/// A closing tag with no open partner is emitted as literal text rather than
/// silently swallowed — dropping it would quietly rewrite user-visible copy.
List<InlineSpan> markupSpans(String text) {
  final spans = <InlineSpan>[];
  var bold = 0;
  var italic = 0;
  var cursor = 0;

  void emit(String value) {
    if (value.isEmpty) return;
    spans.add(
      TextSpan(
        text: value,
        style: (bold > 0 || italic > 0)
            ? TextStyle(
                fontWeight: bold > 0 ? FontWeight.bold : null,
                fontStyle: italic > 0 ? FontStyle.italic : null,
              )
            : null,
      ),
    );
  }

  for (final match in _tagPattern.allMatches(text)) {
    final isClose = match.group(1) == '/';
    final tag = match.group(2)!.toLowerCase();
    final isBold = tag == 'b' || tag == 'strong';
    // Unbalanced close — leave the tag in the text stream untouched.
    if (isClose && (isBold ? bold : italic) == 0) continue;
    emit(text.substring(cursor, match.start));
    cursor = match.end;
    if (isBold) {
      bold += isClose ? -1 : 1;
    } else {
      italic += isClose ? -1 : 1;
    }
  }
  emit(text.substring(cursor));
  return spans;
}

/// The four inline tags [markupSpans] interprets, in their bare form only.
/// Kept in sync with `kRenderableMarkupTags` in
/// `test/lint/no_raw_html_markup_test.dart`.
final RegExp _tagPattern = RegExp(
  r'<(/?)(b|strong|i|em)>',
  caseSensitive: false,
);
