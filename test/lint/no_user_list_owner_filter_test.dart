import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// CI lint for the product decision behind invoiceninja/flutter#46: the user
/// roster shows **every** company user, the account owner and the logged-in
/// user included.
///
/// `hideOwnerUsers` and `without=<id>` are real, honoured `UserFilters` methods
/// on the server. Sending either strips rows the app needs — `hideOwnerUsers`
/// takes no parameter, so its mere presence excludes every owner, and on an
/// account where all users are owners the list comes back empty. The same
/// query also backs every assigned-user picker, so re-adding them would once
/// again make the owner unassignable app-wide.
///
/// This is a deliberate divergence from the React client, which does send both
/// — so "restore parity with React" is exactly the refactor this lint exists to
/// catch. Comments may name the params (several explain why they're gone);
/// only executable code is scanned.
void main() {
  test('lib/ does not re-add the users-list owner/self exclusion', () {
    final pattern = RegExp(r"hideOwnerUsers|'without'|\bwithout=");
    final offenders = <String>[];
    final libDir = Directory('lib');
    expect(libDir.existsSync(), isTrue, reason: 'lib/ should exist');

    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('.g.dart')) continue;
      if (entity.path.endsWith('.freezed.dart')) continue;

      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        // Doc/line comments are allowed — they carry the rationale.
        if (line.trimLeft().startsWith('//')) continue;
        if (pattern.hasMatch(line)) {
          offenders.add('${entity.path}:${i + 1}:  ${line.trim()}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'The users list must not send `hideOwnerUsers` or `without=` — that '
          'hides the account owner from User Management and from every '
          'assigned-user picker (invoiceninja/flutter#46). Found:\n'
          '  ${offenders.join('\n  ')}',
    );
  });
}
