import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:admin/l10n/transifex_php_parser.dart';

/// Guards against HTML-escaped translations shipping to users.
///
/// The upstream Transifex PHP files are HTML-escaped, so a French or Italian
/// apostrophe arrives as `&#39;`. Flutter's `Text` has no HTML layer to undo
/// it, so whatever is in the JSON is literally what the user reads — Settings
/// once showed `Colore dell&#39;accento` in Italian and `Cl&eacute; d&#39;acc&egrave;s`
/// in French. 504 strings across 7 locales were affected. English has zero
/// entities, which is why it survived so long unnoticed.
///
/// [TransifexPhpParser] now decodes on import. This test is the backstop for
/// a locale file that arrives by some other route.
///
/// The invariant is expressed as "decoding is a no-op" rather than "no `&`
/// appears", so a legitimate `Tom & Jerry` or an unrecognized `&foo;` still
/// passes — those are exactly what [decodeHtmlEntities] leaves alone.
void main() {
  test('no shipped translation contains a decodable HTML entity', () {
    final dir = Directory('assets/i18n');
    expect(dir.existsSync(), isTrue, reason: 'run from the repo root');

    final offenders = <String>[];

    for (final file in dir.listSync().whereType<File>()) {
      final name = file.uri.pathSegments.last;
      if (!name.endsWith('.json')) continue;

      final map = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      for (final entry in map.entries) {
        final value = entry.value;
        if (value is! String) continue;
        final decoded = decodeHtmlEntities(value);
        if (decoded != value) {
          offenders.add('$name → ${entry.key}: "$value"');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'These translations still carry HTML entities and would render raw '
          'to the user. Re-run tools/import_transifex_zip.dart, which decodes '
          'them on import.\n  ${offenders.take(20).join('\n  ')}'
          '${offenders.length > 20 ? '\n  … and ${offenders.length - 20} more' : ''}',
    );
  });
}
