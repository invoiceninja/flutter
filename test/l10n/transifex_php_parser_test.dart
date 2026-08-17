import 'package:admin/l10n/transifex_php_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// These tests target the PHP parser's job: given Transifex output, return
/// the right key→value map. They use a hand-written subset of the real
/// `textsphp-en_au.php` format so we don't depend on a shipped zip.

const _simple = '''
<?php

\$lang = array(
    'organization' => 'Organisation',
    'name' => 'Name',
);

return \$lang;
''';

const _withEscapes = r"""
<?php
$lang = array(
    'apostrophe' => 'it\'s fine',
    'backslash' => 'C:\\Users',
    // a comment between entries
    'plain' => 'plain',
    # also a comment
    'no_trailing_comma' => 'last'
);
""";

const _blockComment = r"""
<?php
$lang = array(
    /* multi
       line
       comment */
    'kept' => 'survives',
);
""";

void main() {
  final parser = TransifexPhpParser();

  group('basic shape', () {
    test('parses a flat key→value map', () {
      final map = parser.parse(_simple);
      expect(map, {'organization': 'Organisation', 'name': 'Name'});
    });

    test('throws when array() opener is missing', () {
      expect(
        () => parser.parse('<?php return 1;'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('PHP escape rules (single-quoted strings)', () {
    test(r"unescapes \' to ' and \\ to \", () {
      final map = parser.parse(_withEscapes);
      expect(map['apostrophe'], "it's fine");
      expect(map['backslash'], r'C:\Users');
    });

    test('preserves all other backslash sequences literally', () {
      final map = parser.parse(r"""
<?php
$lang = array(
    'kept' => 'line\nbreak',
);
""");
      // PHP single-quote rule: \n is literally backslash-n, not a newline.
      expect(map['kept'], r'line\nbreak');
    });
  });

  group('double-quoted strings (mixed with single)', () {
    test(
      "real Transifex output mixes 'single' and \"double\" quotes — both parse",
      () {
        // From textsphp-en.php: when the value contains a single quote
        // (e.g. "Pa'anga"), Transifex emits the entry with double quotes
        // around both key and value.
        final map = parser.parse(r'''
<?php
$lang = array(
    "currency_tongan_pa_anga" => "Tongan Pa'anga",
    'plain' => 'still works',
);
''');
        expect(map['currency_tongan_pa_anga'], "Tongan Pa'anga");
        expect(map['plain'], 'still works');
      },
    );

    test('double-quoted string can contain unescaped single quotes', () {
      final map = parser.parse(r'''
<?php
$lang = array(
    "msg" => "it's mixed",
);
''');
      expect(map['msg'], "it's mixed");
    });
  });

  group('comments + trailing commas', () {
    test('ignores // and # line comments between entries', () {
      final map = parser.parse(_withEscapes);
      expect(
        map.keys,
        containsAll(['apostrophe', 'plain', 'no_trailing_comma']),
      );
    });

    test('ignores /* block comments */', () {
      final map = parser.parse(_blockComment);
      expect(map, {'kept': 'survives'});
    });

    test('allows the last entry to omit the trailing comma', () {
      final map = parser.parse(_withEscapes);
      expect(map['no_trailing_comma'], 'last');
    });
  });

  // The upstream PHP is HTML-escaped, so every French/Italian apostrophe
  // arrives as `&#39;` and — with nothing to undo it — reaches the UI as the
  // literal text `Cl&#39;e d&#39;acc&egrave;s`. 504 shipped strings across 7
  // locales were affected; English has none, which is why it went unnoticed.
  group('HTML entity decoding', () {
    test('parse() decodes entities in values', () {
      final map = parser.parse(r'''
<?php
$lang = array(
    'access_key' => 'Cl&eacute; d&#39;acc&egrave;s',
);
''');
      expect(map['access_key'], "Clé d'accès");
    });

    test('resolves named, decimal, and hex entities', () {
      expect(decodeHtmlEntities('a&amp;b'), 'a&b');
      expect(decodeHtmlEntities('d&#39;accord'), "d'accord");
      expect(decodeHtmlEntities('&#x27;quoted&#x27;'), "'quoted'");
      expect(decodeHtmlEntities('&eacute;&eacute;n'), 'één');
      expect(decodeHtmlEntities('Settings &gt; Users'), 'Settings > Users');
      expect(decodeHtmlEntities('&quot;quoted&quot;'), '"quoted"');
    });

    test('is a single pass — &amp;#39; stays literal text', () {
      // Decoding `&amp;` first and then re-scanning would turn this into an
      // apostrophe, silently destroying a translator's escaped example.
      expect(decodeHtmlEntities('&amp;#39;'), '&#39;');
      expect(decodeHtmlEntities('&amp;amp;'), '&amp;');
    });

    test('leaves unrecognized entities and bare ampersands alone', () {
      expect(decodeHtmlEntities('&notanentity;'), '&notanentity;');
      expect(decodeHtmlEntities('R&D'), 'R&D');
      expect(decodeHtmlEntities('Tom & Jerry'), 'Tom & Jerry');
    });

    test('leaves markup tags alone — only entities are decoded', () {
      // Several help strings ship real `<p>`/`<li>` markup for the rich-text
      // renderer; decoding must not touch it.
      expect(
        decodeHtmlEntities('<p>Use &quot;:MONTH&quot; &gt;&gt; July</p>'),
        '<p>Use ":MONTH" >> July</p>',
      );
    });

    test('rejects out-of-range and surrogate code points', () {
      // `String.fromCharCode` would emit a lone surrogate half rather than
      // throwing, producing an unpaired UTF-16 unit in a shipped asset.
      expect(decodeHtmlEntities('&#xD800;'), '&#xD800;');
      expect(decodeHtmlEntities('&#99999999;'), '&#99999999;');
      expect(decodeHtmlEntities('&#0;'), '&#0;');
    });

    test('preserves strings with no ampersand untouched', () {
      const plain = 'Nothing to decode here';
      expect(identical(decodeHtmlEntities(plain), plain), isTrue);
    });
  });
}
