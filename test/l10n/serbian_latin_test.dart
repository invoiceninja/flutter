import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The importer is a zero-dependency CLI with no test runner of its own, so its
// transliteration is tested here, where CI runs it. Its `lib/` is that
// package's, not this app's.
// ignore: avoid_relative_lib_imports
import '../../tools/transifex_importer/lib/serbian_latin.dart';

/// Serbian ships as Latin script (`sr-Latn` in `kSupportedLocales`, so
/// Material's own strings match), and Transifex's `sr` file mixes Cyrillic
/// into it — the importer transliterates every value. See
/// `docs/translated-string-rendering.md`.
void main() {
  test('serbianToLatin composes a decomposed ć', () {
    expect(serbianToLatin('Rac\u0301un'), 'Ra\u0107un');
    expect(serbianToLatin('C\u0301ao'), '\u0106ao');
    expect(serbianToLatin('Продавци'), 'Prodavci');
  });

  group('serbianCyrillicToLatin', () {
    test('maps every letter of the alphabet', () {
      expect(
        serbianCyrillicToLatin('абвгдђежзијклљмнњопрстћуфхцчџш'),
        'abvgdđežzijklljmnnjoprstćufhcčdžš',
      );
      expect(
        serbianCyrillicToLatin('АБВГДЂЕЖЗИЈКЛМНОПРСТЋУФХЦЧШ'),
        'ABVGDĐEŽZIJKLMNOPRSTĆUFHCČŠ',
      );
    });

    test('the real strings that mixed scripts in the sidebar', () {
      expect(serbianCyrillicToLatin('Продавци'), 'Prodavci');
      expect(serbianCyrillicToLatin('Наруџбенице'), 'Narudžbenice');
      expect(serbianCyrillicToLatin('Трансакције'), 'Transakcije');
    });

    test('a digraph is title case in a mixed-case word', () {
      expect(serbianCyrillicToLatin('Љубав'), 'Ljubav');
      expect(serbianCyrillicToLatin('Њега'), 'Njega');
      expect(serbianCyrillicToLatin('Џеп'), 'Džep');
      expect(serbianCyrillicToLatin('Љ'), 'Lj');
      expect(serbianCyrillicToLatin('Љ.'), 'Lj.');
    });

    test('a digraph is all caps inside an all-caps word', () {
      expect(serbianCyrillicToLatin('ЉУБАВ'), 'LJUBAV');
      expect(serbianCyrillicToLatin('ЊЕГА'), 'NJEGA');
      expect(serbianCyrillicToLatin('ЏЕП'), 'DŽEP');
      // At the end of a caps word the letter before it decides.
      expect(serbianCyrillicToLatin('НАЈБОЉ'), 'NAJBOLJ');
      expect(serbianCyrillicToLatin('НАЈБОЉИ ПДФ'), 'NAJBOLJI PDF');
      // A capital digraph alone after a space reads as a word start.
      expect(serbianCyrillicToLatin('ПДФ Љ'), 'PDF Lj');
    });

    test('placeholders, variables, URLs and HTML pass through untouched', () {
      expect(
        serbianCyrillicToLatin('Е-фактура :invoice за :client је послата'),
        'E-faktura :invoice za :client je poslata',
      );
      expect(
        serbianCyrillicToLatin(
          'Платите <a href="https://invoicing.co/x?a=1&b=2">овде</a> \$amount',
        ),
        'Platite <a href="https://invoicing.co/x?a=1&b=2">ovde</a> \$amount',
      );
      const ascii = r':count $client.name <b>https://a.b/c</b> 9:00 {x}';
      expect(serbianCyrillicToLatin(ascii), ascii);
    });

    test('Latin input, and Cyrillic that is not Serbian, are left alone', () {
      expect(serbianCyrillicToLatin('Računi i čćžšđ'), 'Računi i čćžšđ');
      expect(serbianCyrillicToLatin('Привет, мы'), 'Privet, mы');
      expect(containsCyrillic(serbianCyrillicToLatin('мы')), isTrue);
    });
  });

  for (final file in ['sr.json', '_app_pending_sr.json']) {
    test('$file is all Latin script', () {
      final path = 'assets/i18n/$file';
      if (!File(path).existsSync()) return;
      final map = (jsonDecode(File(path).readAsStringSync()) as Map)
          .cast<String, Object?>();
      final cyrillic = map.entries
          .where(
            (e) => e.value is String && containsCyrillic(e.value! as String),
          )
          .map((e) => e.key)
          .toList();
      expect(
        cyrillic,
        isEmpty,
        reason:
            'Serbian ships as sr-Latn; run the values through '
            'serbianToLatin (the importer does): $cyrillic',
      );
      final decomposed = map.entries
          .where((e) => e.value is String && '${e.value}'.contains('\u0301'))
          .map((e) => e.key)
          .toList();
      expect(decomposed, isEmpty, reason: 'compose ć (serbianToLatin)');
    });
  }
}
