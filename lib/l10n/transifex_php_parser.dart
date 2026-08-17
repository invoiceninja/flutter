/// Pure-Dart parser for Invoice Ninja's Transifex zip files.
///
/// Each file is shaped like:
///
/// ```php
/// <?php
///
/// $lang = array(
///     'key' => 'value',
///     'another' => 'it\'s an example',
///     // 'commented_out' => 'nope',
/// );
///
/// return $lang;
/// ```
///
/// The parser walks the body, ignores comments and PHP wrapper, and emits a
/// `{ key: value }` map. Escaped single quotes (`\'`) and backslashes
/// (`\\`) inside string literals are unescaped per PHP single-quote rules
/// (only those two escapes are honored — `\n`, `\t`, etc. stay literal,
/// matching PHP's single-quote semantics).
///
/// Values are additionally run through [decodeHtmlEntities] — see that
/// function for why.
class TransifexPhpParser {
  /// Parse the file contents into a key→value map. Throws [FormatException]
  /// if the file doesn't match the expected shape.
  Map<String, String> parse(String input) {
    final out = <String, String>{};
    var i = 0;
    final n = input.length;

    bool startsWithAt(int idx, String s) {
      if (idx + s.length > n) return false;
      for (var k = 0; k < s.length; k++) {
        if (input.codeUnitAt(idx + k) != s.codeUnitAt(k)) return false;
      }
      return true;
    }

    void skipWhitespaceAndComments() {
      while (i < n) {
        final c = input[i];
        if (c == ' ' || c == '\t' || c == '\n' || c == '\r') {
          i++;
        } else if (startsWithAt(i, '//') || startsWithAt(i, '#')) {
          while (i < n && input[i] != '\n') {
            i++;
          }
        } else if (startsWithAt(i, '/*')) {
          i += 2;
          while (i + 1 < n && !(input[i] == '*' && input[i + 1] == '/')) {
            i++;
          }
          if (i + 1 < n) i += 2;
        } else {
          return;
        }
      }
    }

    String readQuotedString() {
      if (i >= n || (input[i] != "'" && input[i] != '"')) {
        throw FormatException(
          'Expected quote at offset $i, got "${i < n ? input[i] : 'EOF'}"',
        );
      }
      // Real-world Transifex output uses `"..."` when the value contains
      // a single quote (e.g. `"Tongan Pa'anga"`). Both flavors are
      // accepted; escape rules are the conservative subset PHP shares
      // between them: `\<quote>` → quote, `\\` → backslash, everything
      // else literal.
      final quote = input[i];
      i++;
      final buf = StringBuffer();
      while (i < n) {
        final c = input[i];
        if (c == '\\' && i + 1 < n) {
          final next = input[i + 1];
          if (next == quote || next == r'\') {
            buf.write(next);
            i += 2;
            continue;
          }
          buf.write(c);
          i++;
          continue;
        }
        if (c == quote) {
          i++;
          return buf.toString();
        }
        buf.write(c);
        i++;
      }
      throw const FormatException('Unterminated string literal');
    }

    // Advance past everything up to `array(`.
    final arrayIdx = input.indexOf('array(');
    if (arrayIdx < 0) {
      throw const FormatException('No `array(` found in PHP file');
    }
    i = arrayIdx + 'array('.length;

    while (i < n) {
      skipWhitespaceAndComments();
      if (i >= n) break;
      if (input[i] == ')') {
        i++;
        break;
      }
      // Trailing comma already consumed by the loop.
      final key = readQuotedString();
      skipWhitespaceAndComments();
      if (i + 1 >= n || input[i] != '=' || input[i + 1] != '>') {
        throw FormatException('Expected `=>` after key "$key" at offset $i');
      }
      i += 2;
      skipWhitespaceAndComments();
      final value = readQuotedString();
      out[key] = decodeHtmlEntities(value);
      skipWhitespaceAndComments();
      if (i < n && input[i] == ',') {
        i++;
      }
    }
    return out;
  }
}

/// Named entities worth resolving: the five XML built-ins, the two spaces,
/// and the Latin-1 letters the shipped locales actually use (French,
/// Italian, Spanish, Portuguese, German, Dutch). Anything outside this set
/// is left alone rather than guessed at — see [decodeHtmlEntities].
const Map<String, String> _kNamedEntities = {
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
  'nbsp': ' ',
  'ensp': ' ',
  'emsp': ' ',
  'aacute': 'á',
  'agrave': 'à',
  'acirc': 'â',
  'atilde': 'ã',
  'auml': 'ä',
  'aring': 'å',
  'aelig': 'æ',
  'ccedil': 'ç',
  'eacute': 'é',
  'egrave': 'è',
  'ecirc': 'ê',
  'euml': 'ë',
  'iacute': 'í',
  'igrave': 'ì',
  'icirc': 'î',
  'iuml': 'ï',
  'ntilde': 'ñ',
  'oacute': 'ó',
  'ograve': 'ò',
  'ocirc': 'ô',
  'otilde': 'õ',
  'ouml': 'ö',
  'oslash': 'ø',
  'uacute': 'ú',
  'ugrave': 'ù',
  'ucirc': 'û',
  'uuml': 'ü',
  'yacute': 'ý',
  'yuml': 'ÿ',
  'szlig': 'ß',
  'Aacute': 'Á',
  'Agrave': 'À',
  'Acirc': 'Â',
  'Atilde': 'Ã',
  'Auml': 'Ä',
  'Aring': 'Å',
  'AElig': 'Æ',
  'Ccedil': 'Ç',
  'Eacute': 'É',
  'Egrave': 'È',
  'Ecirc': 'Ê',
  'Euml': 'Ë',
  'Iacute': 'Í',
  'Igrave': 'Ì',
  'Icirc': 'Î',
  'Iuml': 'Ï',
  'Ntilde': 'Ñ',
  'Oacute': 'Ó',
  'Ograve': 'Ò',
  'Ocirc': 'Ô',
  'Otilde': 'Õ',
  'Ouml': 'Ö',
  'Oslash': 'Ø',
  'Uacute': 'Ú',
  'Ugrave': 'Ù',
  'Ucirc': 'Û',
  'Uuml': 'Ü',
  'laquo': '«',
  'raquo': '»',
  'ldquo': '“',
  'rdquo': '”',
  'lsquo': '‘',
  'rsquo': '’',
  'hellip': '…',
  'ndash': '–',
  'mdash': '—',
  'deg': '°',
  'euro': '€',
  'pound': '£',
  'yen': '¥',
  'cent': '¢',
  'copy': '©',
  'reg': '®',
  'trade': '™',
  'middot': '·',
  'bull': '•',
};

final RegExp _kEntityPattern = RegExp(
  r'&(#[0-9]{1,7}|#[xX][0-9a-fA-F]{1,6}|[a-zA-Z][a-zA-Z0-9]{1,31});',
);

/// Resolves HTML entities in a translated string.
///
/// The upstream Transifex PHP files are HTML-escaped, so a French or Italian
/// apostrophe arrives as `&#39;` and reaches the UI verbatim —
/// `Clé d&#39;accès`. Flutter's `Text` has no HTML layer to undo it, so the
/// raw entity is what the user reads. English is unaffected (it has none),
/// which is why this survived so long.
///
/// Deliberately a **single pass**: `&amp;#39;` must resolve to the literal
/// text `&#39;`, not to `'`. Running an `&amp;` replacement before a numeric
/// one would double-decode it.
///
/// Unrecognized entities are passed through untouched — a translator writing
/// a literal `&foo;` keeps it, and an entity outside [_kNamedEntities] stays
/// visible rather than being silently dropped. Markup tags (`<p>`, `<br>`)
/// are not entities and are likewise left alone.
String decodeHtmlEntities(String input) {
  if (!input.contains('&')) return input;
  return input.replaceAllMapped(_kEntityPattern, (m) {
    final body = m[1]!;
    if (body.startsWith('#')) {
      final isHex = body[1] == 'x' || body[1] == 'X';
      final digits = isHex ? body.substring(2) : body.substring(1);
      final code = int.tryParse(digits, radix: isHex ? 16 : 10);
      // Reject anything outside the Unicode scalar range, plus surrogates,
      // which `String.fromCharCode` would happily emit as a lone half.
      if (code == null ||
          code < 0x20 && code != 0x09 && code != 0x0A && code != 0x0D ||
          code > 0x10FFFF ||
          (code >= 0xD800 && code <= 0xDFFF)) {
        return m[0]!;
      }
      return String.fromCharCode(code);
    }
    return _kNamedEntities[body] ?? m[0]!;
  });
}
