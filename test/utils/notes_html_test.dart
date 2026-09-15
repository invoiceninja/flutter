import 'package:flutter_test/flutter_test.dart';

import 'package:admin/utils/notes_html.dart';

void main() {
  group('htmlFromPlainText', () {
    test('a blank value stays blank', () {
      // An untouched field must not become a `<p></p>`: downstream that reads
      // as "the user entered something", and the client bulk update would arm
      // an irreversible mass-write of it.
      expect(htmlFromPlainText(''), '');
      expect(htmlFromPlainText('   \n\n  '), '');
    });

    test('a blank line starts a paragraph; a single newline is a break', () {
      expect(
        htmlFromPlainText('Hi Bob\nThanks.\n\nRegards\nJim'),
        '<p>Hi Bob<br>Thanks.</p><p>Regards<br>Jim</p>',
      );
    });

    test('never emits a newline', () {
      // `nl2br()` on the server's PDF path would turn one into a stray break.
      expect(htmlFromPlainText('a\nb\n\nc\r\nd'), isNot(contains('\n')));
    });

    test('markup the user typed stays text', () {
      expect(
        htmlFromPlainText('a < b & c > d'),
        '<p>a &lt; b &amp; c &gt; d</p>',
      );
    });

    test('markdown is not interpreted', () {
      // This is for plain fields, so the user's own words win.
      expect(htmlFromPlainText('5 * 3 * 2'), '<p>5 * 3 * 2</p>');
      expect(htmlFromPlainText('# 1 priority'), '<p># 1 priority</p>');
    });

    test('a template variable is left exactly as typed', () {
      expect(
        htmlFromPlainText(r'Dear $client.name,'),
        r'<p>Dear $client.name,</p>',
      );
    });
  });

  group('plainTextFromHtml', () {
    test('plain text passes straight through', () {
      expect(plainTextFromHtml('just words'), 'just words');
      expect(plainTextFromHtml('a\nb'), 'a\nb');
      // Prose with a `<` is not markup and must not be touched.
      expect(plainTextFromHtml('width < 5'), 'width < 5');
    });

    test('blocks become line breaks and tags disappear', () {
      expect(plainTextFromHtml('<p>one</p><p>two</p>'), 'one\n\ntwo');
      expect(plainTextFromHtml('<p>one<br>two</p>'), 'one\ntwo');
      expect(
        plainTextFromHtml('<p>a <strong>bold</strong> word</p>'),
        'a bold word',
      );
      expect(
        plainTextFromHtml('<ul><li>One</li><li>Two</li></ul>'),
        'One\n\nTwo',
      );
    });

    test('markup that renders as nothing is nothing', () {
      // What the detail cards gate on, so an empty paragraph can't open a card
      // with nothing in it.
      expect(plainTextFromHtml('<p></p>'), '');
      expect(plainTextFromHtml('<p><br></p>'), '');
    });

    test('entities are resolved', () {
      // Without this a French client's note reads `&eacute;` in the list.
      expect(
        plainTextFromHtml('<p>Caf&eacute; &amp; co &#39;95</p>'),
        "Café & co '95",
      );
    });

    test('singleLine collapses everything a table cell cannot show', () {
      expect(
        plainTextFromHtml('<p>one</p><p>two<br>three</p>', singleLine: true),
        'one two three',
      );
    });
  });
}
