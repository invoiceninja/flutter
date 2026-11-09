import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `dart run msix:create` runs its own `flutter build windows` unless told not
/// to — without the dart-defines, over the build that carried them. The
/// hand-built Store packages shipped that way with `IN_SENTRY_DSN` empty, so
/// Windows never sent Sentry a single event. The workflow passes
/// `--build-windows false`; the pubspec key covers a package built by hand.
/// See "Build then package" in docs/setup.md.
void main() {
  test('pubspec msix_config sets build_windows: false', () {
    final lines = File('pubspec.yaml').readAsLinesSync();
    final start = lines.indexWhere((l) => l.trimRight() == 'msix_config:');
    expect(start, isNot(-1), reason: 'pubspec.yaml has no msix_config block');

    String? value;
    for (final line in lines.skip(start + 1)) {
      if (line.trim().isEmpty || line.startsWith('#')) continue;
      if (!line.startsWith(' ')) break;
      final match = RegExp(r'^\s+build_windows:\s*(\S+)').firstMatch(line);
      if (match != null) value = match.group(1);
    }
    expect(
      value,
      'false',
      reason:
          'Without `build_windows: false`, msix:create rebuilds the app '
          'without --dart-define=IN_SENTRY_DSN and the package ships with '
          'Sentry off.',
    );
  });

  test('the Store workflow builds with the DSN and packages that build', () {
    final workflow = File(
      '.github/workflows/microsoft-store.yml',
    ).readAsStringSync();
    expect(workflow, contains('--dart-define=IN_SENTRY_DSN='));
    expect(workflow, contains('msix:create --build-windows false'));
  });
}
