import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// tools/msstore_release_notes.py puts the release's short digest (the F-Droid
/// changelog Google Play also takes) into the Microsoft Store listing's release
/// notes. `--print-notes` prints exactly that text, with no network.
void main() {
  final changelogs = Directory('fastlane/metadata/android/en-US/changelogs');

  Future<ProcessResult> printNotes(int build) => Process.run('python3', [
    'tools/msstore_release_notes.py',
    '--print-notes',
    '--build',
    '$build',
  ]);

  final digests =
      changelogs
          .listSync()
          .whereType<File>()
          .map((f) => int.tryParse(f.uri.pathSegments.last.split('.').first))
          .whereType<int>()
          .where((n) => n % 10 == 1)
          .toList()
        ..sort();

  test('there are digests to check', () => expect(digests, isNotEmpty));

  for (final n in digests) {
    test('build ${n ~/ 10}: the whole digest, within the 1500 limit', () async {
      final result = await printNotes(n ~/ 10);
      expect(result.exitCode, 0, reason: '${result.stderr}');
      final digest = File(
        '${changelogs.path}/$n.txt',
      ).readAsLinesSync().where((l) => l.trim().isNotEmpty).join('\n');
      expect(result.stdout, '$digest\n');
      expect(digest.length, lessThanOrEqualTo(1500));
    });
  }

  test('a build with no digest fails', () async {
    final result = await printNotes(999999);
    expect(result.exitCode, 1);
    expect(result.stderr, contains('is missing'));
  });
}
