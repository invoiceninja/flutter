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

import 'package:admin/utils/bidi.dart';

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
/// `foldSearchText(haystack).contains(foldSearchText(needle))`. Bidi controls
/// go too — a `tr()` label carries isolates in a right-to-left locale, and a
/// prefix match must not trip over one.
String foldSearchText(String s) =>
    foldSearchChars(stripBidiControls(s)).toLowerCase();

/// [values] folded, blank ones dropped, one per line — a stored text that a
/// folded search matches with a plain substring test, and that no search can
/// match across two values (a search never holds a newline).
String foldedSearchLines(Iterable<String?> values) => [
  for (final v in values)
    if (v != null && v.trim().isNotEmpty) foldSearchText(v),
].join('\n');

/// The most words a search is split into. Each word costs one OR chain of
/// `searchLike`s in SQL, and each `searchLike` binds up to nine variables, so
/// a pasted paragraph must not become a hundred groups.
const int kMaxSearchWords = 8;

final RegExp _kWhitespace = RegExp(r'\s+', unicode: true);
final RegExp _kLetterOrDigit = RegExp(r'[\p{L}\p{N}]', unicode: true);
final RegExp _kDigit = RegExp(r'\p{N}', unicode: true);
final RegExp _kLetter = RegExp(r'\p{L}', unicode: true);
final RegExp _kLetterLed = RegExp(r'^\P{N}*\p{L}', unicode: true);

/// [query] as the words a search matches one by one: every word must match
/// some field, in any order (`s22 120hz` finds "Galaxy S22 … 120Hz Screen").
///
/// - Split on any whitespace, no-break spaces included.
/// - A word with no letter or digit (`-`, `&`) is dropped — it narrows
///   nothing a reader would mean.
/// - Duplicates go (compared folded), and so does a word inside another word:
///   every row holding `s22` also holds `s2`.
/// - At most [kMaxSearchWords] words, the first ones typed.
/// - A query that cleaning would empty (`-`, `- -`) keeps its whitespace-split
///   words as they are, never "match everything".
///
/// Always a fresh, growable list.
///
/// The words keep their typed form; each matcher folds them itself.
List<String> searchWords(String query) {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return <String>[];
  final words = <String>[];
  final folded = <String>[];
  for (final word in trimmed.split(_kWhitespace)) {
    if (!_kLetterOrDigit.hasMatch(word)) continue;
    final f = foldSearchText(word);
    if (folded.any((seen) => seen.contains(f))) continue;
    // A longer word supersedes the shorter ones it contains.
    for (var i = folded.length - 1; i >= 0; i--) {
      if (f.contains(folded[i])) {
        folded.removeAt(i);
        words.removeAt(i);
      }
    }
    words.add(word);
    folded.add(f);
  }
  if (words.isEmpty) {
    // Only punctuation: split as the server's `ClientFilters` does, deduped.
    return trimmed.split(_kWhitespace).toSet().take(kMaxSearchWords).toList();
  }
  return words.length > kMaxSearchWords
      ? words.sublist(0, kMaxSearchWords)
      : words;
}

/// [query]'s words ordered by how likely each is to narrow a server search,
/// longer before shorter within a rank, ties in typed order:
///
/// 1. letters and digits, a letter first — a model or document number
///    (`s22`, `INV-0012`), what people type when they know what they want;
/// 2. letters and digits, a digit first — a spec (`120hz`, `5g`);
/// 3. letters only (`galaxy`, `screen`);
/// 4. no letter at all (`2`, `2024`, `-`) — last, because the servers LIKE
///    dates, amounts, balances and time logs: `%2%` matches nearly every
///    invoice, so it would page through the whole table for a needle.
///
/// `.first` is the one term sent to a server whose filter matches the whole
/// text as one phrase: it returns a superset that the local, every-word
/// search then narrows. Empty for a blank query.
List<String> serverSearchTerms(String query) {
  final words = searchWords(query);
  int rank(String w) {
    final hasLetter = _kLetter.hasMatch(w);
    if (!hasLetter) return 3;
    if (!_kDigit.hasMatch(w)) return 2;
    return _kLetterLed.hasMatch(w) ? 0 : 1;
  }

  final indexed = [for (var i = 0; i < words.length; i++) (i, words[i])];
  indexed.sort((a, b) {
    final byKind = rank(a.$2).compareTo(rank(b.$2));
    if (byKind != 0) return byKind;
    final byLength = b.$2.length.compareTo(a.$2.length);
    if (byLength != 0) return byLength;
    return a.$1.compareTo(b.$1);
  });
  return [for (final (_, w) in indexed) w];
}

/// [query]'s [searchWords], folded — compute once, then test many rows with
/// [containsEveryWord].
List<String> foldedSearchWords(String query) => [
  for (final w in searchWords(query)) foldSearchText(w),
];

/// Whether every one of [foldedWords] occurs in [foldedHaystack] — the Dart
/// twin of the list search's `everyWordMatches`. Pass several fields through
/// [foldedSearchLines] to let each word match a different one: no word holds
/// a newline, so none can match across two.
bool containsEveryWord(String foldedHaystack, List<String> foldedWords) {
  for (final w in foldedWords) {
    if (!foldedHaystack.contains(w)) return false;
  }
  return true;
}

/// Whether every one of [foldedWords] ([foldedSearchWords]) occurs in at least
/// one of [fields], folded — the one-call form of [containsEveryWord] for a
/// picker that tests each option against a handful of its own fields. A
/// blank search ([foldedWords] empty) matches everything.
bool fieldsMatchEveryWord(List<String> foldedWords, Iterable<String?> fields) =>
    foldedWords.isEmpty ||
    containsEveryWord(foldedSearchLines(fields), foldedWords);

/// [s] trimmed with every whitespace run collapsed to one space — for the
/// "is this exactly an existing name" checks, so `Acme  Corp` is `Acme Corp`.
String squashWhitespace(String s) => s.trim().replaceAll(_kWhitespace, ' ');
