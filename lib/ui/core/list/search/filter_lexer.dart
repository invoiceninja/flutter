import 'package:admin/ui/core/list/search/filter_key.dart';

/// Parsed result of a pasted search string: zero or more `(keyId, rawValue)`
/// tokens plus whatever free text didn't match any known filter key.
typedef LexResult = ({
  List<({String keyId, String rawValue})> tokens,
  String freeText,
});

/// Paste-time lexer for the token search field. Splits the input on
/// whitespace; each piece that looks like `<key>:<value>` (where `<key>` is
/// a known [FilterKey.id] or an alias) becomes a token, otherwise it joins
/// the free-text bucket.
///
/// **Quoted and typed values stay whole.** Whitespace inside double quotes
/// does not split (`country:"United States"` used to lex as `"United` plus a
/// search for `States"`), and the quotes are unwrapped; a quote with no
/// partner is a literal character. Commas split only an unquoted value of a
/// PICK-ONLY key (`is:active,archived`, `status:draft,sent`) — a key that
/// takes typed text reads its own commas: a date window
/// (`date:2026-01-01,2026-02-01`), a date with a comma in it, a decimal comma
/// (`balance:1,5`). Splitting before the value reached the key turned a window
/// into two dates, the second overwriting the first.
LexResult lexFilterInput(String input, List<FilterKey> filterKeys) {
  final tokens = <({String keyId, String rawValue})>[];
  final freeBuf = StringBuffer();

  final keysByName = <String, FilterKey>{};
  for (final k in filterKeys) {
    keysByName[k.id] = k;
    for (final a in k.aliases) {
      keysByName[a] = k;
    }
  }

  for (final piece in _splitOutsideQuotes(input)) {
    final colon = piece.indexOf(':');
    final key = colon == -1
        ? null
        : keysByName[piece.substring(0, colon).toLowerCase()];
    if (key == null) {
      freeBuf.write('$piece ');
      continue;
    }
    var value = piece.substring(colon + 1);
    final quoted =
        value.length >= 2 && value.startsWith('"') && value.endsWith('"');
    if (quoted) value = value.substring(1, value.length - 1);
    if (value.trim().isEmpty) continue;
    final values = !quoted && !key.acceptsTypedValue
        ? value.split(',')
        : [value];
    for (final v in values) {
      final trimmed = v.trim();
      if (trimmed.isNotEmpty) tokens.add((keyId: key.id, rawValue: trimmed));
    }
  }
  return (tokens: tokens, freeText: freeBuf.toString().trim());
}

/// [input] split on runs of whitespace, except inside a pair of double
/// quotes. A `"` with no closing partner is an ordinary character.
List<String> _splitOutsideQuotes(String input) {
  final pieces = <String>[];
  final current = StringBuffer();
  var i = 0;
  while (i < input.length) {
    final ch = input[i];
    if (ch == '"') {
      final close = input.indexOf('"', i + 1);
      if (close != -1) {
        current.write(input.substring(i, close + 1));
        i = close + 1;
        continue;
      }
    }
    if (ch.trim().isEmpty) {
      if (current.isNotEmpty) pieces.add(current.toString());
      current.clear();
    } else {
      current.write(ch);
    }
    i++;
  }
  if (current.isNotEmpty) pieces.add(current.toString());
  return pieces;
}
