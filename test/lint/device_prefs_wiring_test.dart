import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Two things no widget test can see, because nothing a test builds runs
/// `main` or reaches past `DevicePrefsStore`.
void main() {
  String stripped(String path) => File(path)
      .readAsLinesSync()
      .map((l) {
        final i = l.indexOf('//');
        return i == -1 ? l : l.substring(0, i);
      })
      .join('\n');

  test('boot loads the device preferences', () {
    // One load serves every preference controller; drop it and each one
    // silently stops surviving a relaunch.
    expect(stripped('lib/main.dart'), contains('services.devicePrefs.load()'));
  });

  test('only DevicePrefsStore reads or writes device_prefs rows', () {
    // The store's in-memory mirror is what every controller reads. A write
    // that went around it would be invisible until the next launch, and a
    // wipe would forget it on disk but not on screen.
    final offenders = [
      for (final f in Directory('lib').listSync(recursive: true))
        if (f is File &&
            f.path.endsWith('.dart') &&
            !f.path.endsWith('.g.dart') &&
            !f.path.endsWith('device_prefs_store.dart') &&
            !f.path.endsWith('device_prefs_dao.dart') &&
            stripped(f.path).contains('devicePrefsDao'))
          f.path,
    ];
    expect(offenders, isEmpty);
  });
}
