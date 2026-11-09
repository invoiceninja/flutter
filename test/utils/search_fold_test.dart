import 'package:flutter_test/flutter_test.dart';

import 'package:admin/utils/search_fold.dart';

void main() {
  test('folds case and accents the way the server collation does', () {
    expect(foldSearchText('MÜLLER'), 'muller');
    expect(foldSearchText('Müller'), 'muller');
    expect(foldSearchText('Österreich'), 'osterreich');
    expect(foldSearchText('Straße'), 'strasse');
    expect(foldSearchText('Łódź'), 'lodz');
    expect(foldSearchText('Ærø'), 'aero');
  });

  test('a decomposed umlaut folds like the precomposed one', () {
    expect(foldSearchText('Mu\u0308ller'), foldSearchText('Müller'));
  });

  test('ASCII is only lowercased, and other scripts pass through', () {
    expect(foldSearchText('Acme Corp 42%_'), 'acme corp 42%_');
    expect(foldSearchText('Δ'), 'δ');
  });

  test('every map entry is one character to ASCII', () {
    for (final (from, to) in kSearchFoldMap) {
      expect(from.runes, hasLength(1), reason: from);
      expect(RegExp(r'^[a-z]*$').hasMatch(to), isTrue, reason: '$from → $to');
    }
  });

  group('searchWords', () {
    test('splits on any whitespace, no-break spaces included', () {
      expect(searchWords('s22 120hz'), ['s22', '120hz']);
      expect(searchWords('  galaxy\ts22\u00a0oled\u202fscreen  '), [
        'galaxy',
        's22',
        'oled',
        'screen',
      ]);
    });

    test('a blank query has no words', () {
      expect(searchWords(''), isEmpty);
      expect(searchWords('   '), isEmpty);
    });

    test('drops words with no letter or digit', () {
      expect(searchWords('Acme - London'), ['Acme', 'London']);
      expect(searchWords('R&D & co'), ['R&D', 'co']);
    });

    test('a query that is only punctuation keeps its own words', () {
      expect(searchWords('-'), ['-']);
      expect(searchWords(' & '), ['&']);
      // Split as the server's ClientFilters does, so never narrower.
      expect(searchWords('- -'), ['-']);
      expect(searchWords('- &'), ['-', '&']);
    });

    test('a blank query is an empty, growable list', () {
      final words = searchWords('  ');
      expect(words, isEmpty);
      words.add('x'); // never a const list a caller cannot sort
    });

    test('dedupes after folding and drops a word inside another', () {
      expect(searchWords('Müller muller'), ['Müller']);
      expect(searchWords('s2 s22'), ['s22']);
      expect(searchWords('s22 s2'), ['s22']);
      expect(searchWords('gal galaxy ga'), ['galaxy']);
    });

    test('keeps at most $kMaxSearchWords words, the first ones typed', () {
      final words = searchWords('a1 b2 c3 d4 e5 f6 g7 h8 i9 j10');
      expect(words, hasLength(kMaxSearchWords));
      expect(words.first, 'a1');
      expect(words.last, 'h8');
    });
  });

  group('serverSearchTerms', () {
    test('a model number leads, then the longer words', () {
      expect(serverSearchTerms('s22 120hz').first, 's22');
      expect(serverSearchTerms('screen s22').first, 's22');
      expect(serverSearchTerms('128gb s22 screen').first, 's22');
      expect(serverSearchTerms('acme INV-0012').first, 'INV-0012');
      // A word with no letter goes last: the servers LIKE dates and amounts,
      // so `%2%` or `%2024%` matches nearly every invoice.
      expect(serverSearchTerms('acme 0012'), ['acme', '0012']);
      expect(serverSearchTerms('Phase 2').first, 'Phase');
      expect(serverSearchTerms('2024 acme').first, 'acme');
      expect(serverSearchTerms('s22 120hz 2024'), ['s22', '120hz', '2024']);
      expect(serverSearchTerms('galaxy oled screen'), [
        'galaxy',
        'screen',
        'oled',
      ]);
    });

    test('a blank query has no terms', () {
      expect(serverSearchTerms('  '), isEmpty);
    });
  });

  group('containsEveryWord', () {
    final name = foldSearchText(
      'Samsung Galaxy S22 5G OLED 120Hz Screen (TCGJ)',
    );

    test('the user feedback: s22 120hz', () {
      expect(containsEveryWord(name, foldedSearchWords('s22 120hz')), isTrue);
      expect(containsEveryWord(name, foldedSearchWords('120HZ S22')), isTrue);
      expect(containsEveryWord(name, foldedSearchWords('s22 iphone')), isFalse);
    });

    test('words may match different fields, never across two', () {
      final fields = foldedSearchLines(['SKU1', 'Widget']);
      expect(
        containsEveryWord(fields, foldedSearchWords('widget sku1')),
        isTrue,
      );
      expect(
        containsEveryWord(fields, foldedSearchWords('sku1widget')),
        isFalse,
      );
    });

    test('folds accents on both sides', () {
      expect(
        containsEveryWord(
          foldSearchText('Jörg Öztürk'),
          foldedSearchWords('OZTURK jorg'),
        ),
        isTrue,
      );
    });
  });

  test('fieldsMatchEveryWord: each word in some field, blank matches all', () {
    final words = foldedSearchWords('invoice ÜBER');
    expect(fieldsMatchEveryWord(words, ['Über uns', 'Invoice']), isTrue);
    expect(fieldsMatchEveryWord(words, ['Über uns', null]), isFalse);
    expect(fieldsMatchEveryWord(const [], ['anything']), isTrue);
  });

  test('squashWhitespace', () {
    expect(squashWhitespace('  Acme \u00a0  Corp '), 'Acme Corp');
  });
}
