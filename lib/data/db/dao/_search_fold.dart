import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import 'package:admin/utils/search_fold.dart';

/// Case- and accent-insensitive substring match of [search] in [value] — the
/// only way a local list search may compare text. Matches exactly when
/// `foldSearchText(value).contains(foldSearchText(search))` would.
///
/// SQLite folds case for ASCII only, and folding every stored value in SQL
/// (one `replace()` per accented letter) cost ten times the old `LIKE`. So the
/// fold runs the other way:
///
/// - a value that is all ASCII (`length = octet_length`, nearly every row)
///   takes a plain `LIKE` of the folded search — SQLite's ASCII case folding
///   is the whole fold there, and a non-ASCII search letter can't match it;
/// - any other value is matched by a `GLOB` pattern in which each letter is a
///   class of every character that folds to it (`garcia` →
///   `*[gGĝğ…][aAàá…]…*`), after its combining marks are stripped.
///
/// Both patterns are bound as variables, never written into the SQL.
/// See docs/local-search-matching.md.
Expression<bool> searchLike(Expression<String> value, String search) {
  final target = _stripMarks(value);
  final unicode = searchGlobPatterns(search)
      .map<Expression<bool>>(
        (p) => FunctionCallExpression<bool>('glob', [
          Variable.withString(p),
          target,
        ]),
      )
      .reduce((a, b) => a | b);
  final escaped = foldSearchText(
    search,
  ).replaceAllMapped(RegExp(r'[\\%_]'), (m) => r'\' + m[0]!);
  return CaseWhenExpression<bool>(
    cases: [
      CaseWhen(
        FunctionCallExpression<int>('length', [
          value,
        ]).equalsExp(FunctionCallExpression<int>('octet_length', [value])),
        then: value.like('%$escaped%', escapeChar: r'\'),
      ),
    ],
    orElse: unicode,
  );
}

/// The contact fields a client's `contact_search` column holds — what
/// `ClientFilters::filter` searches. The billing documents' server filters
/// search only the first three; the phone on top is a harmless superset.
const kClientContactSearchKeys = ['first_name', 'last_name', 'email', 'phone'];

/// The contact fields a vendor's `contact_search` column holds — what
/// `VendorFilters::filter` searches.
const kVendorContactSearchKeys = ['first_name', 'last_name', 'email'];

/// Whether any of a client's or vendor's contacts has a field matching
/// [search], the way [searchLike] would match it.
///
/// [column] is the row's `contact_search`: those [keys] of every contact,
/// already folded, one per line, so a match is a plain `instr`. Parsing the
/// contacts out of the payload instead made the client search ten times
/// slower. A row stored before that column existed holds NULL until
/// `fillContactSearch` reaches it, and is matched through [payload]'s
/// contacts meanwhile.
Expression<bool> contactSearchMatches({
  required Expression<String> column,
  required Expression<String> payload,
  required List<String> keys,
  required String search,
}) => CaseWhenExpression<bool>(
  cases: [
    CaseWhen(
      column.isNull(),
      then: _JsonArraySearchLike(payload, r'$.contacts', keys, search),
    ),
  ],
  orElse: FunctionCallExpression<int>('instr', [
    column,
    Variable.withString(foldSearchText(search)),
  ]).isBiggerThanValue(0),
);

/// Fill `contact_search` on [table]'s rows for [companyId] that predate it,
/// [batchSize] at a time, from each row's payload. Returns how many rows it
/// filled.
///
/// Never in front of the first frame: an upgrade that walked every payload
/// would hold up the open, so the column arrives NULL and this runs after a
/// company activates. A row a mapper writes meanwhile already has its value,
/// and the `IS NULL` on the update leaves it alone. Nothing is notified — the
/// search returns the same rows either way, only faster.
Future<int> fillContactSearchColumn(
  DatabaseConnectionUser db,
  TableInfo<Table, Object?> table, {
  required String companyId,
  required List<String> keys,
  int batchSize = 200,
}) async {
  final name = table.actualTableName;
  var filled = 0;
  while (true) {
    final rows = await db
        .customSelect(
          'SELECT id, payload FROM $name '
          'WHERE company_id = ? AND contact_search IS NULL LIMIT ?',
          variables: [
            Variable.withString(companyId),
            Variable.withInt(batchSize),
          ],
        )
        .get();
    if (rows.isEmpty) return filled;
    await db.transaction(() async {
      for (final row in rows) {
        await db.customUpdate(
          'UPDATE $name SET contact_search = ? '
          'WHERE company_id = ? AND id = ? AND contact_search IS NULL',
          variables: [
            Variable.withString(
              _contactSearchOf(row.read<String>('payload'), keys),
            ),
            Variable.withString(companyId),
            Variable.withString(row.read<String>('id')),
          ],
        );
      }
    });
    filled += rows.length;
  }
}

/// The `contact_search` value a payload's contacts make — '' for a payload
/// with no contacts or one that isn't JSON, so the row is not picked again.
String _contactSearchOf(String payload, List<String> keys) {
  final Object? decoded;
  try {
    decoded = jsonDecode(payload);
  } on FormatException {
    return '';
  }
  final contacts = decoded is Map ? decoded['contacts'] : null;
  if (contacts is! List) return '';
  return foldedSearchLines([
    for (final c in contacts)
      if (c is Map)
        for (final k in keys) c[k]?.toString(),
  ]);
}

/// The `GLOB` patterns [searchLike] ORs together — more than one only when
/// the search holds a pair a single letter folds to (`ss` ← `ß`, `ae` ← `æ`).
@visibleForTesting
List<String> searchGlobPatterns(String search) {
  final chars = foldSearchText(search).runes.map(String.fromCharCode).toList();
  final variants = <List<_Unit>>[];
  // Letters first, so the all-letters reading is always the first variant
  // and survives the cap.
  void walk(int i, List<_Unit> units) {
    if (i == chars.length) {
      variants.add(units);
      return;
    }
    walk(i + 1, [...units, (text: chars[i], pair: false)]);
    if (i + 1 < chars.length && variants.length < _kMaxVariants) {
      final pair = chars[i] + chars[i + 1];
      if (_kSources.containsKey(pair)) {
        walk(i + 2, [...units, (text: pair, pair: true)]);
      }
    }
  }

  walk(0, const []);
  return [
    for (final units in variants.take(_kMaxVariants))
      '*${[for (var i = 0; i < units.length; i++) _globUnit(units, i)].join()}*',
  ];
}

/// One position of a pattern: a single character of the folded search, or a
/// pair a ligature folds to. A flag rather than the text's length, because a
/// character past U+FFFF (an emoji) is two code units long too.
typedef _Unit = ({String text, bool pair});

/// Enough for a search with three `ss` / `ae` / … pairs in it; past that the
/// later pairs match only as two letters.
const _kMaxVariants = 8;

/// Folded form → every character that folds to it, e.g. `u` → `ùú…ÙÚ…`.
final Map<String, String> _kSources = () {
  final out = <String, String>{};
  for (final (from, to) in kSearchFoldMap) {
    if (to.isNotEmpty) out[to] = (out[to] ?? '') + from;
  }
  return out;
}();

/// One position of a pattern: a class of every character that folds to
/// `units[i]`. A pair a ligature folds to can also be cut in half by the
/// match's edges — `as` is in `aß` (`ass`) — so the first unit also takes the
/// ligatures ending in its letter, and the last those starting with it.
String _globUnit(List<_Unit> units, int i) {
  final (:text, :pair) = units[i];
  final members = <String>{};
  if (!pair) {
    members.add(text);
    final upper = text.toUpperCase();
    if (upper.runes.length == 1) members.add(upper);
    for (final MapEntry(key: lig, value: sources) in _kSources.entries) {
      if (lig.length != 2) continue;
      if ((i == 0 && lig[1] == text) ||
          (i == units.length - 1 && lig[0] == text)) {
        members.addAll(sources.split(''));
      }
    }
  }
  final sources = _kSources[text];
  if (sources != null) members.addAll(sources.split(''));
  if (members.length == 1) {
    // `*`, `?` and `[` are GLOB syntax; a one-character class is a literal.
    return '*?['.contains(text) ? '[$text]' : text;
  }
  // Only letters reach a class, so no `]`, `^` or `-` needs placing.
  return '[${members.join()}]';
}

/// The combining marks [kSearchFoldMap] removes — a decomposed `u` + `¨` reads
/// as `ü` once they are gone.
final List<String> _kMarks = [
  for (final (from, to) in kSearchFoldMap)
    if (to.isEmpty) from,
];

/// [value] without [_kMarks]; a NULL stays NULL, so it never matches.
///
/// Every mark in [_kMarks] encodes in UTF-8 with the lead byte `0xCC`, which
/// is never a continuation byte — so a byte search for it, a `memchr` over
/// the value, tells the rows with a mark from the rest and skips the
/// `replace()` chain for nearly all of them. A `GLOB '*[marks]*'` guard cost
/// fifteen times as much.
Expression<String> _stripMarks(Expression<String> value) {
  var stripped = value;
  for (final mark in _kMarks) {
    stripped = FunctionCallExpression<String>('replace', [
      stripped,
      Constant(mark),
      const Constant(''),
    ]);
  }
  return CaseWhenExpression<String>(
    cases: [
      CaseWhen(
        FunctionCallExpression<int>('instr', [
          value.cast<Uint8List>(),
          const CustomExpression<Uint8List>("x'CC'"),
        ]).isBiggerThanValue(0),
        then: stripped,
      ),
    ],
    orElse: value,
  );
}

class _JsonArraySearchLike extends Expression<bool> {
  _JsonArraySearchLike(this.json, this.path, this.keys, this.search);

  final Expression<String> json;
  final String path;
  final List<String> keys;
  final String search;

  @override
  Precedence get precedence => Precedence.primary;

  @override
  void writeInto(GenerationContext context) {
    // A shape check, not `json_valid`: that parses every payload a second
    // time and doubled the search. Payloads are written by `jsonEncode`, so
    // one that opens with `{` is an object; anything else ('' on an old row)
    // reads as no contacts.
    //
    // `json_tree` walks the contacts once; `json_extract` per key re-parsed
    // each contact object for every field asked about.
    context.buffer.write('EXISTS (SELECT 1 FROM json_tree(CASE WHEN substr(');
    json.writeInto(context);
    context.buffer.write(", 1, 1) = '{' THEN ");
    json.writeInto(context);
    context.buffer.write(" ELSE '{}' END, '$path') AS je WHERE je.key IN (");
    context.buffer.write(keys.map((k) => "'$k'").join(', '));
    context.buffer.write(') AND ');
    searchLike(
      const CustomExpression<String>('je.value'),
      search,
    ).writeInto(context);
    context.buffer.write(')');
  }
}
