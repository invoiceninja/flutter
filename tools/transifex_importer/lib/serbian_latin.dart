/// Serbian Cyrillic → Serbian Latin (gajica), letter for letter.
///
/// The app ships Serbian as `sr-Latn` (`lib/l10n/supported_locales.dart`), so
/// Material's strings are Latin, but Transifex's `sr` file mixes the two
/// scripts — about two in five values arrived in Cyrillic, and a sidebar read
/// "Klijenti, Računi … Продавци". The importer runs every `sr` value through
/// this before writing `assets/i18n/sr.json`.
///
/// The two alphabets map one to one, so the conversion is deterministic and
/// reversible except for the three letters that become digraphs — Љ → Lj,
/// Њ → Nj, Џ → Dž. Those take the case of their surroundings: title case at the
/// start of a mixed-case word (Љубав → Ljubav), all caps inside an all-caps one
/// (ЉУБАВ → LJUBAV, НАЈБОЉИ → NAJBOLJI).
///
/// Only Serbian Cyrillic letters are touched. Everything else — ASCII
/// `:placeholders`, `$variables`, URLs, HTML, digits, punctuation, Latin text —
/// passes through unchanged, as does any non-Serbian Cyrillic letter (Russian
/// ы, я, …), which [containsCyrillic] lets the caller report.
///
/// Pure Dart with no imports: the root project's `test/l10n` imports this file
/// by relative path so CI runs its tests without giving this zero-dependency
/// CLI a `package:test` dependency.
/// [serbianCyrillicToLatin], then the decomposed `ć` some Latin values carry
/// (`c` + U+0301 COMBINING ACUTE, 226 of them in the Oct 2026 bundle) composed
/// into the letter — a stacked mark is drawn by whatever the font does with it,
/// and the letter is what every other value uses.
String serbianToLatin(String input) => serbianCyrillicToLatin(
      input,
    ).replaceAll('c\u0301', '\u0107').replaceAll('C\u0301', '\u0106');

String serbianCyrillicToLatin(String input) {
  if (!containsCyrillic(input)) return input;
  final chars = input.runes.map(String.fromCharCode).toList();
  final out = StringBuffer();
  for (var i = 0; i < chars.length; i++) {
    final ch = chars[i];
    final digraph = _kUpperDigraphs[ch];
    if (digraph != null) {
      final next = i + 1 < chars.length ? chars[i + 1] : null;
      final prev = i > 0 ? chars[i - 1] : null;
      final allCaps = next != null && _isLetter(next)
          ? _isUpper(next)
          : prev != null && _isUpper(prev);
      out.write(allCaps ? digraph.toUpperCase() : digraph);
      continue;
    }
    out.write(_kLetters[ch] ?? ch);
  }
  return out.toString();
}

/// Whether [s] holds any character from the Cyrillic block (U+0400–U+04FF).
bool containsCyrillic(String s) => _kCyrillic.hasMatch(s);

final RegExp _kCyrillic = RegExp('[Ѐ-ӿ]');

bool _isLetter(String ch) => ch.toLowerCase() != ch.toUpperCase();

bool _isUpper(String ch) => _isLetter(ch) && ch == ch.toUpperCase();

/// The uppercase Cyrillic letters whose Latin form is two letters, in title
/// case; [serbianCyrillicToLatin] upper-cases the second inside a caps word.
const Map<String, String> _kUpperDigraphs = {'Љ': 'Lj', 'Њ': 'Nj', 'Џ': 'Dž'};

const Map<String, String> _kLetters = {
  'А': 'A',
  'а': 'a',
  'Б': 'B',
  'б': 'b',
  'В': 'V',
  'в': 'v',
  'Г': 'G',
  'г': 'g',
  'Д': 'D',
  'д': 'd',
  'Ђ': 'Đ',
  'ђ': 'đ',
  'Е': 'E',
  'е': 'e',
  'Ж': 'Ž',
  'ж': 'ž',
  'З': 'Z',
  'з': 'z',
  'И': 'I',
  'и': 'i',
  'Ј': 'J',
  'ј': 'j',
  'К': 'K',
  'к': 'k',
  'Л': 'L',
  'л': 'l',
  'љ': 'lj',
  'М': 'M',
  'м': 'm',
  'Н': 'N',
  'н': 'n',
  'њ': 'nj',
  'О': 'O',
  'о': 'o',
  'П': 'P',
  'п': 'p',
  'Р': 'R',
  'р': 'r',
  'С': 'S',
  'с': 's',
  'Т': 'T',
  'т': 't',
  'Ћ': 'Ć',
  'ћ': 'ć',
  'У': 'U',
  'у': 'u',
  'Ф': 'F',
  'ф': 'f',
  'Х': 'H',
  'х': 'h',
  'Ц': 'C',
  'ц': 'c',
  'Ч': 'Č',
  'ч': 'č',
  'џ': 'dž',
  'Ш': 'Š',
  'ш': 'š',
};
