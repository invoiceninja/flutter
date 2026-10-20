import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/_search_fold.dart';
import 'package:admin/utils/search_fold.dart';

/// `searchLike` builds a GLOB pattern from the search instead of folding the
/// stored value, so nothing but this test holds it to the Dart fold the
/// table defines: every value × search pair below must match in SQL exactly
/// when `foldSearchText(value).contains(foldSearchText(search))`.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<bool?> sqlMatches(String? value, String search) async {
    final expr = searchLike(
      value == null ? const Constant<String>(null) : Variable.withString(value),
      search,
    );
    final row = await db.selectExpressions([expr]).getSingle();
    return row.read(expr);
  }

  bool dartMatches(String value, String search) =>
      foldSearchText(value).contains(foldSearchText(search));

  const values = [
    'Müller',
    'MÜLLER GmbH',
    'Hans Mueller',
    'Mu\u0308ller',
    'Überseehandel',
    'Österreich AG',
    'Straße 12',
    'STRASSE',
    'Ærø Æble',
    'Łódź',
    'Smørrebrød',
    'İstanbul',
    'Дмитрий',
    'ДМИТРИЙ',
    'José García',
    '50% off_now',
    'a*b?c[d]',
    r'C:\temp\x',
    'Acme Corp',
    '🍕 Pizza',
    '𠀀 Co',
    '',
  ];
  const searches = [
    'mü',
    'MÜ',
    'mu',
    'mue',
    'müller',
    'über',
    'UBER',
    'österreich',
    'strasse',
    'straße',
    'aß',
    'as',
    'ss',
    'ae',
    'æ',
    'aero',
    'lodz',
    'smorrebrod',
    'istanbul',
    'дмитрий',
    'Дми',
    'garcia',
    'josé',
    '50%',
    '%',
    '_',
    'f_n',
    '*',
    'b?c',
    '[d]',
    r'\t',
    r'p\x',
    'acme corp',
    '🍕',
    '🍕 pizza',
    '𠀀',
    'zzz',
  ];

  test('SQL matches exactly when the Dart fold does', () async {
    for (final value in values) {
      for (final search in searches) {
        expect(
          await sqlMatches(value, search),
          dartMatches(value, search),
          reason: '"$value" ∋ "$search"',
        );
      }
    }
  });

  test('every table entry matches its folded letter, in SQL', () async {
    for (final (from, to) in kSearchFoldMap) {
      if (to.isEmpty) continue;
      expect(await sqlMatches('x${from}y', 'x${to}y'), isTrue, reason: from);
    }
  });

  test('the cases from the report', () async {
    expect(await sqlMatches('Müller', 'mü'), isTrue);
    expect(await sqlMatches('MÜLLER', 'müller'), isTrue);
    expect(await sqlMatches('Österreich', 'österreich'), isTrue);
    expect(await sqlMatches('Überseehandel', 'über'), isTrue);
    expect(await sqlMatches('Müller', 'mueller'), isFalse);
  });

  test('a NULL value never matches', () async {
    expect(await sqlMatches(null, 'a'), isNull);
  });

  test('the all-letters reading survives the variant cap', () {
    final patterns = searchGlobPatterns('ssssssssssss');
    expect(patterns.length, lessThanOrEqualTo(8));
    // Twelve one-letter classes, no `[ßẞ]` pair unit.
    expect('['.allMatches(patterns.first), hasLength(12));
  });
}
