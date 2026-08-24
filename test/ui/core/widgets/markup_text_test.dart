import 'package:admin/ui/core/widgets/markup_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// `MarkupText` exists because Transifex ships `<b>` inside translated copy
/// and Flutter's `Text` paints it verbatim (invoiceninja/flutter#75).
void main() {
  String plainText(List<InlineSpan> spans) =>
      spans.map((s) => (s as TextSpan).text).join();

  List<TextSpan> typed(List<InlineSpan> spans) => spans.cast<TextSpan>();

  group('markupSpans', () {
    test('leaves a markup-free string as a single span', () {
      final spans = typed(markupSpans('Selecting a product'));
      expect(spans, hasLength(1));
      expect(spans.single.text, 'Selecting a product');
      expect(spans.single.style, isNull);
    });

    test('bolds a <b> run and strips the tags', () {
      final spans = typed(
        markupSpans(
          'Selecting a product will automatically '
          '<b>fill in the description and cost</b>',
        ),
      );
      expect(
        plainText(spans),
        'Selecting a product will automatically '
        'fill in the description and cost',
      );
      expect(spans.first.style, isNull);
      expect(spans.last.style?.fontWeight, FontWeight.bold);
    });

    test('treats <strong>/<em> as <b>/<i> and nests them', () {
      final spans = typed(markupSpans('a<b>b<i>c</i></b>d'));
      expect(plainText(spans), 'abcd');
      final bold = spans.firstWhere((s) => s.text == 'b');
      final both = spans.firstWhere((s) => s.text == 'c');
      expect(bold.style?.fontWeight, FontWeight.bold);
      expect(bold.style?.fontStyle, isNull);
      expect(both.style?.fontWeight, FontWeight.bold);
      expect(both.style?.fontStyle, FontStyle.italic);
      expect(spans.last.style, isNull);

      expect(plainText(typed(markupSpans('<strong>x</strong>'))), 'x');
      expect(
        typed(markupSpans('<em>x</em>')).single.style?.fontStyle,
        FontStyle.italic,
      );
    });

    test('leaves an unmatched closing tag as literal text', () {
      // Dropping it would quietly rewrite user-visible copy.
      expect(plainText(markupSpans('a</b>b')), 'a</b>b');
    });

    test('leaves tags it does not interpret alone', () {
      // `variables_hint_template` names a real template tag the user types.
      const hint = 'auto-wrapped in <ninja> if outside one';
      expect(plainText(markupSpans(hint)), hint);
      expect(plainText(markupSpans('line<br>break')), 'line<br>break');
    });
  });

  testWidgets('MarkupText renders the tag content without the tags', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MarkupText('before <b>bold</b> after')),
      ),
    );

    final text = tester.widget<Text>(find.byType(Text));
    expect(text.textSpan!.toPlainText(), 'before bold after');
    expect(find.textContaining('<b>'), findsNothing);
  });
}
