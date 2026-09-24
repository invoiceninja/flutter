import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every server copy of ONE record is written through the echo guard.
///
/// `applyUpdateResponse` used to be a plain upsert in every repository, so a
/// response for an older mutation replaced a newer local edit that was still
/// queued — with v1 in flight and v2 saved behind it, v1's echo put v1 back
/// and cleared the dirty flag, and if v2 then failed validation the edit form
/// reopened on v1. `BaseEntityRepository.applyEchoTemplate` checks for a newer
/// queued edit first; `applyCreateResponseTemplate` does the same for a
/// create. Nothing in the type system notices a new repository — or a new
/// line in an old one — that writes the response directly, and the failure is
/// silent until a user loses an edit, so it is scanned here.
void main() {
  Iterable<(String, String)> repositories() sync* {
    for (final f
        in Directory('lib/data/repositories')
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('_repository.dart'))) {
      final name = f.uri.pathSegments.last;
      if (name == 'base_entity_repository.dart') continue;
      final code = f
          .readAsStringSync()
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      yield (name, code);
    }
  }

  /// The body of `Future<void> <method>({` in [code], or null.
  String? bodyOf(String code, String method) {
    final start = code.indexOf('Future<void> $method({');
    if (start < 0) return null;
    final end = code.indexOf('\n  }\n', start);
    return end < 0 ? null : code.substring(start, end);
  }

  /// [body] with the paren-matched argument list of every `call(` removed.
  String without(String body, String call) {
    var out = body;
    for (var i = out.indexOf(call); i >= 0; i = out.indexOf(call)) {
      var depth = 0;
      var j = i + call.length - 1;
      for (; j < out.length; j++) {
        if (out[j] == '(') depth++;
        if (out[j] == ')' && --depth == 0) break;
      }
      out = out.substring(0, i) + out.substring(j + 1);
    }
    return out;
  }

  test('every applyUpdateResponse writes only through applyEchoTemplate', () {
    final offenders = <String>[];
    var checked = 0;
    for (final (name, code) in repositories()) {
      final body = bodyOf(code, 'applyUpdateResponse');
      if (body == null) continue;
      checked++;
      final outside = without(body, 'applyEchoTemplate(');
      final writesDirectly =
          outside.contains('.upsert(') ||
          outside.contains('db.update(') ||
          outside.contains('.write(');
      if (!body.contains('applyEchoTemplate(') || writesDirectly) {
        offenders.add(name);
      }
    }
    expect(checked, greaterThan(20), reason: 'the scan must not be blind');
    expect(
      offenders,
      isEmpty,
      reason:
          'these write a server copy of a record without checking for a newer '
          'queued edit — wrap the write in `applyEchoTemplate(companyId:, id:, '
          'write:)`:\n  ${offenders.join('\n  ')}',
    );
  });

  test('every applyCreateResponse goes through applyCreateResponseTemplate', () {
    final offenders = <String>[];
    var checked = 0;
    for (final (name, code) in repositories()) {
      final body = bodyOf(code, 'applyCreateResponse');
      if (body == null) continue;
      checked++;
      if (!body.contains('applyCreateResponseTemplate(')) offenders.add(name);
    }
    expect(checked, greaterThan(20), reason: 'the scan must not be blind');
    expect(
      offenders,
      isEmpty,
      reason:
          'these apply a create response by hand, so an edit saved while the '
          'create was in flight is overwritten by the older server copy — use '
          '`applyCreateResponseTemplate`:\n  ${offenders.join('\n  ')}',
    );
  });
}
