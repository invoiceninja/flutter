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
}
