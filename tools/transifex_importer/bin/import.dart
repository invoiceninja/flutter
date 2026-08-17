// ignore_for_file: avoid_print
//
// Standalone Dart CLI. Lives in its own pubspec so `dart run` doesn't have
// to load the host Flutter project — which would force a full Flutter
// framework compile and hit any SDK/analyzer mismatch.
//
// Usage (from repo root):
//   cd tools/transifex_importer
//   dart pub get
//   dart run bin/import.dart <path-to-zip>
//
// The PHP parser + locale list are duplicated from
// `lib/l10n/transifex_php_parser.dart` and `lib/l10n/transifex_files.dart`.
// Keep them in sync — the runtime copy is unit-tested
// (`test/l10n/transifex_php_parser_test.dart`).

import 'dart:collection';
import 'dart:convert';
import 'dart:io';

const Map<String, String> _kTransifexFileNames = {
  'en': 'textsphp-en.php',
  'en_AU': 'textsphp-en_au.php',
  'en_GB': 'textsphp-en_gb.php',
  'es': 'textsphp-es.php',
  'fr': 'textsphp-fr.php',
  'de': 'textsphp-de.php',
  'it': 'textsphp-it.php',
  'nl': 'textsphp-nl.php',
  'pt_BR': 'textsphp-pt_br.php',
  'ja': 'textsphp-ja.php',
  'zh_CN': 'textsphp-zh_cn.php',
};

Future<int> main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart run bin/import.dart <path-to-zip>');
    return 64;
  }
  final zipPath = args.first;
  final zip = File(zipPath);
  if (!await zip.exists()) {
    print('No such zip: $zipPath');
    return 66;
  }

  // Resolve `assets/i18n/` relative to the repo root, regardless of where
  // the CLI was invoked from. The script lives in
  // `tools/transifex_importer/bin/`, so the repo root is three levels up.
  final scriptPath = Platform.script.toFilePath();
  final scriptDir = Directory(scriptPath).parent;
  final repoRoot = scriptDir.parent.parent.parent;
  final outDir = Directory('${repoRoot.path}/assets/i18n');

  final tempDir = await Directory.systemTemp.createTemp('tx_import_');
  try {
    final unzip = await Process.run('unzip', [
      '-q',
      '-o',
      zipPath,
      '-d',
      tempDir.path,
    ]);
    if (unzip.exitCode != 0) {
      stderr.writeln('unzip failed:\n${unzip.stderr}');
      return unzip.exitCode;
    }

    if (!await outDir.exists()) {
      await outDir.create(recursive: true);
    }

    final missing = <String>[];
    var ok = 0;

    for (final entry in _kTransifexFileNames.entries) {
      final localeKey = entry.key;
      final phpName = entry.value;
      final phpFile = File('${tempDir.path}/$phpName');
      if (!await phpFile.exists()) {
        missing.add('$localeKey ($phpName)');
        continue;
      }
      final content = await phpFile.readAsString();
      final Map<String, String> map;
      try {
        map = _parsePhp(content);
      } on FormatException catch (e) {
        stderr.writeln('Parse error in $phpName: ${e.message}');
        return 1;
      }
      final sorted = SplayTreeMap<String, String>.from(map);
      final jsonOut = const JsonEncoder.withIndent('  ').convert(sorted);
      final outFile = File('${outDir.path}/$localeKey.json');
      await outFile.writeAsString('$jsonOut\n');
      print('${outFile.path}  (${map.length} keys)');
      ok++;
    }

    if (missing.isNotEmpty) {
      stderr.writeln('Missing locales: ${missing.join(', ')}');
    }
    print('Imported $ok / ${_kTransifexFileNames.length} locales.');
    return 0;
  } finally {
    await tempDir.delete(recursive: true);
  }
}

/// PHP `$lang = array('k' => 'v', ...)` parser. Kept in sync with
/// `lib/l10n/transifex_php_parser.dart` (which is unit-tested).
Map<String, String> _parsePhp(String input) {
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

  void skipWsAndComments() {
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

  String readQuoted() {
    if (i >= n || (input[i] != "'" && input[i] != '"')) {
      throw FormatException(
        'Expected quote at offset $i, got "${i < n ? input[i] : 'EOF'}"',
      );
    }
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

  final arrayIdx = input.indexOf('array(');
  if (arrayIdx < 0) {
    throw const FormatException('No `array(` found in PHP file');
  }
  i = arrayIdx + 'array('.length;

  while (i < n) {
    skipWsAndComments();
    if (i >= n) break;
    if (input[i] == ')') {
      i++;
      break;
    }
    final key = readQuoted();
    skipWsAndComments();
    if (i + 1 >= n || input[i] != '=' || input[i + 1] != '>') {
      throw FormatException('Expected `=>` after key "$key" at offset $i');
    }
    i += 2;
    skipWsAndComments();
    final value = readQuoted();
    out[key] = _decodeHtmlEntities(value);
    skipWsAndComments();
    if (i < n && input[i] == ',') {
      i++;
    }
  }
  return out;
}

/// Mirror of `decodeHtmlEntities` in `lib/l10n/transifex_php_parser.dart`
/// (unit-tested there). The upstream PHP is HTML-escaped, so without this a
/// French apostrophe ships to the UI as the literal text `&#39;`.
const Map<String, String> _kNamedEntities = {
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
  'nbsp': ' ',
  'ensp': ' ',
  'emsp': ' ',
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

String _decodeHtmlEntities(String input) {
  if (!input.contains('&')) return input;
  return input.replaceAllMapped(_kEntityPattern, (m) {
    final body = m[1]!;
    if (body.startsWith('#')) {
      final isHex = body[1] == 'x' || body[1] == 'X';
      final digits = isHex ? body.substring(2) : body.substring(1);
      final code = int.tryParse(digits, radix: isHex ? 16 : 10);
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
