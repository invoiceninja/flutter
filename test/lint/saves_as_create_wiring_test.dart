import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// An edit of a record whose own create failed saves by re-sending that
/// create (`GenericEditViewModel.savesAsCreate`): branching on `isCreate`, its
/// save queued an update that waited forever behind the failed create, so the
/// user's fix could never be sent from the form. Every `performSave` that can
/// re-send a create — the ones that pass `existingTempId: recoveryTempId` —
/// branches on `savesAsCreate`, never on `isCreate`. `isCreate` itself stays
/// what titles, layout and actions read.
void main() {
  test('every performSave that creates branches on savesAsCreate', () {
    final offenders = <String>[];
    var checked = 0;
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      if (!source.contains('existingTempId: recoveryTempId')) continue;
      checked++;
      final path = entity.path.replaceAll(r'\', '/');
      final start = source.indexOf('performSave()');
      if (start < 0) {
        offenders.add('$path: no performSave');
        continue;
      }
      final call = source.indexOf('existingTempId: recoveryTempId', start);
      final branch = source.substring(start, call < 0 ? source.length : call);
      if (!branch.contains('savesAsCreate') ||
          RegExp(r'if \(isCreate\)').hasMatch(branch)) {
        offenders.add(path);
      }
    }
    expect(
      checked,
      greaterThanOrEqualTo(26),
      reason: 'the scan must not be blind',
    );
    expect(
      offenders,
      isEmpty,
      reason:
          'Branch performSave on savesAsCreate, never isCreate:\n  '
          '${offenders.join('\n  ')}',
    );
  });
}
