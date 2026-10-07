import 'package:flutter_test/flutter_test.dart';

import 'package:admin/utils/editor_html.dart';
import 'package:admin/utils/html_source.dart';
import 'package:admin/utils/legacy_html_markdown.dart';

import '../_html_table_fixtures.dart';

void main() {
  group('hasTableMarkup', () {
    test('finds a table however it was written', () {
      for (final table in [
        kTipTapTable,
        kTinyMceTable,
        kIndentedTable,
        ...kBlankingTables,
      ]) {
        expect(hasTableMarkup(table), isTrue, reason: table);
      }
      expect(hasTableMarkup('<TABLE><TR><TD>a</TD></TR></TABLE>'), isTrue);
      // A fragment is still a table: a pasted row is not prose.
      expect(hasTableMarkup('<tr><td>a</td></tr>'), isTrue);
    });

    test('ordinary notes are not tables', () {
      expect(hasTableMarkup(''), isFalse);
      expect(hasTableMarkup('Thanks for your business'), isFalse);
      expect(hasTableMarkup('<p>one</p><ul><li>two</li></ul>'), isFalse);
      // Names that merely begin like a table part.
      expect(hasTableMarkup('<track><thing><column>'), isFalse);
    });

    test('prose that mentions a table is not one', () {
      // The two strings `kHtmlTagPattern` is strict in order to protect. The
      // detector is permissive about attributes, not about `<` abutting the
      // name.
      expect(hasTableMarkup('Fee applies if qty < table rate > 10'), isFalse);
      expect(hasTableMarkup('mail <form@x.com> now'), isFalse);
    });
  });

  group('foldLeftRawHtmlBlock', () {
    test('reports each shape that used to blank the editor', () {
      for (final table in kBlankingTables) {
        expect(
          foldLeftRawHtmlBlock(markdownFromLegacyHtml(table)),
          isTrue,
          reason: table,
        );
      }
    });

    test('a block the fold could not read, with no table in it', () {
      // Partial loss, not total: "Kept" survives and "Gone" is deleted, which
      // a "did the document come out blank?" check alone would wave through.
      expect(
        foldLeftRawHtmlBlock(
          markdownFromLegacyHtml('<p hidden>Gone</p><p>Kept</p>'),
        ),
        isTrue,
      );
    });

    test('a value the fold read completely leaves nothing behind', () {
      for (final value in [
        kTipTapTable,
        kTinyMceTable,
        '<p>one</p><ul><li>two</li></ul><h2>three</h2>',
        '<p><span style="color: red">red</span></p>',
      ]) {
        expect(
          foldLeftRawHtmlBlock(markdownFromLegacyHtml(value)),
          isFalse,
          reason: value,
        );
      }
    });

    test('a line that opens with `<` is not thereby a block', () {
      // Neither is an HTML block to the markdown parser, so nothing deletes
      // them — and reporting them would open a plain note as "HTML".
      expect(foldLeftRawHtmlBlock('<john@x.com> wrote:\nhello'), isFalse);
      expect(foldLeftRawHtmlBlock('<https://example.com>'), isFalse);
      expect(foldLeftRawHtmlBlock('a <td nowrap> mid-line'), isFalse);
    });
  });

  group('richEditorCannotHold', () {
    test('every table, flattened or blanked', () {
      for (final table in [
        kTipTapTable,
        kTinyMceTable,
        kIndentedTable,
        ...kBlankingTables,
      ]) {
        expect(richEditorCannotHold(table), isTrue, reason: table);
      }
    });

    test('text the editor would delete, table or not', () {
      expect(richEditorCannotHold('<p hidden>Gone</p><p>Kept</p>'), isTrue);
      expect(richEditorCannotHold('<div hidden>All of it</div>'), isTrue);
    });

    test('what the editor can hold stays in the editor', () {
      for (final value in [
        '',
        'Thanks for your business',
        '**bold** and a\nsecond line',
        '<p>Hi <strong>Bob</strong><br>Thanks</p>',
        '<ul><li><p>One</p></li><li><p>Two</p></li></ul>',
        r'<p>$client<br><br>Your invoice</p><div>$view_button</div>',
      ]) {
        expect(richEditorCannotHold(value), isFalse, reason: value);
      }
    });

    test('formatting the editor drops is not a reason', () {
      // Tables only, by decision: reporting every styled span would show most
      // web-authored notes as raw tags.
      expect(
        richEditorCannotHold(
          '<p style="text-align: center"><span style="color: red">Hi</span></p>',
        ),
        isFalse,
      );
    });

    test('a value with no words in it has nothing to lose', () {
      expect(richEditorCannotHold('<p></p>'), isFalse);
      expect(
        richEditorCannotHold('<p><img src="https://x/y.png"></p>'),
        isFalse,
      );
      expect(richEditorCannotHold('<hr>'), isFalse);
    });
  });

  group('wireHtmlFromSource', () {
    test('a value with no line break is sent as typed', () {
      expect(wireHtmlFromSource(kTipTapTable), kTipTapTable);
      expect(wireHtmlFromSource('  <p>a  b</p> '), '<p>a  b</p>');
      expect(wireHtmlFromSource(''), '');
      expect(wireHtmlFromSource(' \n '), '');
    });

    test('never emits a newline', () {
      // `nl2br()` on the PDF path turns each one into a visible break.
      for (final source in [
        kTinyMceTable,
        kIndentedTable,
        'a\r\nb\rc\n\nd',
        '<pre>\none\n  two\n</pre>',
        '<table\n  width="100%"\n>\n<tr>\n<td>a</td>\n</tr>\n</table>',
      ]) {
        final wire = wireHtmlFromSource(source);
        expect(wire, isNot(contains('\n')), reason: source);
        expect(wire, isNot(contains('\r')), reason: source);
      }
    });

    test('a break beside a block tag is formatting, and is dropped', () {
      expect(
        wireHtmlFromSource(kTinyMceTable),
        '<table style="border-collapse: collapse; width: 100%;" border="1">'
        '<colgroup><col style="width: 33.3333%;">'
        '<col style="width: 33.3333%;"><col style="width: 33.3333%;">'
        '</colgroup><tbody><tr><td>Company GmbH</td><td>Bank: ACME</td>'
        '<td>VAT: DE123</td></tr></tbody></table>',
      );
      // Indented by hand: the indentation goes with the break, and a break
      // after a `<br>` is not a second one.
      expect(
        wireHtmlFromSource(kIndentedTable),
        '<table width="100%"><tr><td>Company GmbH<br>Street 1</td>'
        '<td>Bank: ACME<br>IBAN: DE00</td><td>VAT: DE123</td></tr></table>',
      );
      expect(wireHtmlFromSource('<p>a</p>\n\n<p>b</p>'), '<p>a</p><p>b</p>');
    });

    test('a break between words is a line break, as the PDF renders it', () {
      // Collapsing it to a space would join two lines of an address the first
      // time the value was edited as source.
      expect(wireHtmlFromSource('Company\nStreet'), 'Company<br>Street');
      expect(wireHtmlFromSource('a\n\n  b'), 'a<br><br>b');
      expect(
        wireHtmlFromSource('<td>Company\n  Street</td>'),
        '<td>Company<br>Street</td>',
      );
    });

    test('an inline tag is part of the sentence, not a boundary', () {
      expect(
        wireHtmlFromSource('Dear <b>Bob</b>\nThanks'),
        'Dear <b>Bob</b><br>Thanks',
      );
      expect(
        wireHtmlFromSource('<strong>a</strong>\n<em>b</em>'),
        '<strong>a</strong><br><em>b</em>',
      );
      // A plain space between two inline tags is content and is not touched.
      expect(
        wireHtmlFromSource('<p>\n<strong>a</strong> <em>b</em>\n</p>'),
        '<p><strong>a</strong> <em>b</em></p>',
      );
    });

    test('a break inside a tag is one space', () {
      expect(
        wireHtmlFromSource(
          '<td\n    style="width: 33%"\n    align="left">a</td>',
        ),
        '<td style="width: 33%" align="left">a</td>',
      );
      // Quote-aware: the `>` in the attribute does not end the tag, so the
      // break after it is still inside one.
      expect(
        wireHtmlFromSource('<td title="a > b"\n class="x">c</td>'),
        '<td title="a > b" class="x">c</td>',
      );
    });

    test('pre keeps every line; style and script keep none', () {
      expect(
        wireHtmlFromSource('<pre>one\n  two</pre>'),
        '<pre>one<br>  two</pre>',
      );
      expect(
        wireHtmlFromSource(
          '<style>\ntd { color: red; }\nth { color: blue; }\n</style>',
        ),
        '<style> td { color: red; } th { color: blue; } </style>',
      );
    });

    test('is a fixed point', () {
      for (final source in [
        kTinyMceTable,
        kIndentedTable,
        'Company\nStreet',
        'Dear <b>Bob</b>\nThanks',
        '<pre>one\n  two</pre>',
      ]) {
        final once = wireHtmlFromSource(source);
        expect(wireHtmlFromSource(once), once, reason: source);
      }
    });
  });

  group('elideDataPayloads / restoreDataPayloads', () {
    final logo = 'iVBORw0KGgo${'A' * 4000}=';
    final stored =
        '<table><tr><td><img src="data:image/png;base64,$logo" alt="logo">'
        '</td><td>Company</td></tr></table>';

    test('an embedded image is shown as a placeholder, not as its bytes', () {
      // 300 KB of base64 is one unbreakable word: ~2 s of text layout per
      // keystroke, and the markup the user came to edit is somewhere under it.
      final shown = elideDataPayloads(stored);
      expect(
        shown.text,
        '<table><tr><td><img src="data:image/png;base64,[base64-data-1-3KB]" '
        'alt="logo"></td><td>Company</td></tr></table>',
      );
      expect(shown.payloads, [logo]);
    });

    test('what goes back on the wire is the stored string', () {
      final shown = elideDataPayloads(stored);
      expect(restoreDataPayloads(shown.text, shown.payloads), stored);
      // An edit elsewhere in the box does not disturb the image.
      expect(
        restoreDataPayloads(
          shown.text.replaceFirst('Company', 'Company AG'),
          shown.payloads,
        ),
        stored.replaceFirst('Company', 'Company AG'),
      );
    });

    test('each image keeps its own payload', () {
      final second = 'R0lGODlh${'B' * 600}';
      final two = '$stored<img src="data:image/gif;base64,$second">';
      final shown = elideDataPayloads(two);
      expect(shown.payloads, [logo, second]);
      expect(shown.text, contains('[base64-data-2-1KB]'));
      expect(restoreDataPayloads(shown.text, shown.payloads), two);
    });

    test('a deleted placeholder takes its image with it; a copied one '
        'brings it along', () {
      final shown = elideDataPayloads(stored);
      const placeholder = '[base64-data-1-3KB]';
      expect(
        restoreDataPayloads(
          shown.text.replaceFirst(placeholder, ''),
          shown.payloads,
        ),
        isNot(contains(logo)),
      );
      final twice = restoreDataPayloads(
        '${shown.text} $placeholder',
        shown.payloads,
      );
      expect(logo.allMatches(twice), hasLength(2));
    });

    test('a placeholder with nothing behind it is left as typed', () {
      // Pasted in from another field: guessing would embed the wrong image.
      expect(
        restoreDataPayloads('<img src="[base64-data-7-9KB]">', const ['x']),
        '<img src="[base64-data-7-9KB]">',
      );
    });

    test('text with no image in it is untouched', () {
      for (final value in [
        '',
        kTipTapTable,
        // Too short to be worth hiding.
        '<img src="data:image/gif;base64,R0lGODlhAQABAAAAACw=">',
      ]) {
        final shown = elideDataPayloads(value);
        expect(shown.text, value);
        expect(shown.payloads, isEmpty);
      }
    });
  });
}
