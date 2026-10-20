/// Accent and case folding for free-text search — the one table both the
/// local SQL search (`lib/data/db/dao/_search_fold.dart`) and Dart-side
/// matchers read.
///
/// SQLite folds case for ASCII only (no ICU in either build), so `Ü` and `ü`
/// are different letters to `LIKE` and `lower()`. The server searches with
/// MySQL's `utf8mb4_unicode_ci`, which ignores case *and* accents. Folding
/// both the stored value and the typed text through this table makes the local
/// match a superset of the server's, so a row the server found is never hidden
/// again by the local re-read. See docs/local-search-matching.md.
library;

/// Folded form → the characters that fold to it. Latin-1 Supplement and Latin
/// Extended-A letters, both cases, plus the combining marks a decomposed (NFD)
/// `u` + `¨` carries — removed, so it reads as the precomposed `ü` does.
const _kFoldGroups = <String, String>{
  'a': 'àáâãäåāăąÀÁÂÃÄÅĀĂĄ',
  'c': 'çćĉċčÇĆĈĊČ',
  'd': 'ďđðĎĐÐ',
  'e': 'èéêëēĕėęěÈÉÊËĒĔĖĘĚ',
  'g': 'ĝğġģĜĞĠĢ',
  'h': 'ĥħĤĦ',
  'i': 'ìíîïĩīĭįıÌÍÎÏĨĪĬĮİ',
  'j': 'ĵĴ',
  'k': 'ķĸĶ',
  'l': 'ĺļľŀłĹĻĽĿŁ',
  'n': 'ñńņňŉŋÑŃŅŇŊ',
  'o': 'òóôõöøōŏőÒÓÔÕÖØŌŎŐ',
  'r': 'ŕŗřŔŖŘ',
  's': 'śŝşšſŚŜŞŠ',
  't': 'ţťŧŢŤŦ',
  'u': 'ùúûüũūŭůűųÙÚÛÜŨŪŬŮŰŲ',
  'w': 'ŵŴ',
  'y': 'ýÿŷÝŸŶ',
  'z': 'źżžŹŻŽ',
  'ss': 'ßẞ',
  'ae': 'æÆ',
  'oe': 'œŒ',
  'ij': 'ĳĲ',
  'th': 'þÞ',
  // Combining marks, written as escapes: in a literal they are invisible.
  '':
      '\u0300\u0301\u0302\u0303\u0304\u0306\u0307\u0308\u0309\u030A\u030B'
      '\u030C\u0327\u0328',
};

/// Every `(from, to)` pair, one character each side of the fold. The SQL
/// builder nests one `replace()` per entry, so this list *is* the SQL fold.
final List<(String, String)> kSearchFoldMap = [
  for (final MapEntry(key: to, value: chars) in _kFoldGroups.entries)
    for (final rune in chars.runes) (String.fromCharCode(rune), to),
];

final Map<int, String> _kFoldByRune = {
  for (final (from, to) in kSearchFoldMap) from.runes.single: to,
};

/// [s] with every character in [kSearchFoldMap] replaced — no case change.
String foldSearchChars(String s) {
  // Fast path: nothing outside printable ASCII, nothing to fold.
  if (!s.runes.any((r) => r > 0x7e)) return s;
  final out = StringBuffer();
  for (final rune in s.runes) {
    out.write(_kFoldByRune[rune] ?? String.fromCharCode(rune));
  }
  return out.toString();
}

/// [s] folded and lowercased, for matching one Dart string against another:
/// `foldSearchText(haystack).contains(foldSearchText(needle))`.
String foldSearchText(String s) => foldSearchChars(s).toLowerCase();

/// [values] folded, blank ones dropped, one per line — a stored text that a
/// folded search matches with a plain substring test, and that no search can
/// match across two values (a search never holds a newline).
String foldedSearchLines(Iterable<String?> values) => [
  for (final v in values)
    if (v != null && v.trim().isNotEmpty) foldSearchText(v),
].join('\n');
