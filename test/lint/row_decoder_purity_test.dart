import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// CI lint: a repository's row decoder (`_decode`) reads its row and nothing
/// else.
///
/// `BaseEntityRepository.decodeRow` keeps each record's decoded entity and
/// hands it back while the record's stored row is unchanged. That is correct
/// only while decoding is a pure function of the row. A decoder that also read
/// the clock, the company settings, the statics or another table would keep
/// serving what it decoded the first time — a stale "overdue", a currency
/// from before a settings change — with nothing on screen to say so, because
/// nothing about the row changed. Date-dependent questions belong in getters
/// on the domain model (`Invoice.isPastDue`), asked on access.
///
/// A source scan, so it sees only the `_decode` body itself, not the helpers it
/// calls; the helpers today (`decodeDocumentsColumn`, `epochSecondsToUtc`, the
/// `fromJson` / `fromApi` factories) are pure, and one that stopped being so
/// would want its own line here.
void main() {
  /// What a pure decoder never mentions.
  final forbidden = <String, RegExp>{
    'the clock': RegExp(r'\bDateTime\.now\b|\bDate\.today\b|\bclock\b'),
    'settings': RegExp(r'\bsettings\b|_settings\b|\bstatics\b'),
    'the services graph': RegExp(r'\bservices\b|\bServices\b'),
    'the database': RegExp(r'\bdb\.'),
    'anything awaited': RegExp(r'\bawait\b|\basync\b'),
    'a BuildContext': RegExp(r'\bcontext\b'),
    'the platform': RegExp(r'\bPlatform\.|\bEnv\.|\bkIsWeb\b'),
  };

  test('every cached row decoder reads only its row', () {
    final offenders = <String>[];
    var decoders = 0;
    for (final file in Directory('lib/data/repositories').listSync()) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final source = file.readAsStringSync();
      if (!source.contains('decodeRow(')) continue;
      final body = _methodBody(source, RegExp(r'\b_decode\([A-Z]\w* row\) \{'));
      if (body == null) {
        offenders.add('${file.path}: uses decodeRow but has no `_decode` body');
        continue;
      }
      decoders++;
      final code = _stripComments(body);
      for (final MapEntry(key: what, value: pattern) in forbidden.entries) {
        final hit = pattern.firstMatch(code);
        if (hit != null) {
          offenders.add('${file.path}: `_decode` reads $what (`${hit[0]}`)');
        }
      }
    }
    expect(
      decoders,
      greaterThanOrEqualTo(14),
      reason: 'the scan found too few decoders — it has gone blind',
    );
    expect(
      offenders,
      isEmpty,
      reason:
          'A cached row decoder must be a pure function of its row (see '
          '`BaseEntityRepository.decodeRow`). Move the dependency into a '
          'getter on the domain model, or stop routing this repository '
          'through decodeRow. Found:\n  ${offenders.join('\n  ')}',
    );
  });
}

/// The text between the braces of the method whose signature [start] matches.
String? _methodBody(String source, RegExp start) {
  final m = start.firstMatch(source);
  if (m == null) return null;
  var depth = 0;
  for (var i = m.end - 1; i < source.length; i++) {
    final c = source[i];
    if (c == '{') depth++;
    if (c == '}') {
      depth--;
      if (depth == 0) return source.substring(m.end, i);
    }
  }
  return null;
}

String _stripComments(String code) => code
    .replaceAll(RegExp(r'//[^\n]*'), '')
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
