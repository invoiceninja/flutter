import 'dart:io';

import 'package:admin/domain/release_notes.dart';
import 'package:flutter_test/flutter_test.dart';

/// tools/release_notes_markdown.py writes the GitHub Release body from the
/// Dart source of kReleaseNotes (appimage.yml), so it must read every release
/// exactly as the compiler does.
void main() {
  Future<ProcessResult> run(String version) =>
      Process.run('python3', ['tools/release_notes_markdown.py', version]);

  for (final release in kReleaseNotes) {
    test('the Release body for ${release.version} is its items', () async {
      final result = await run(release.version);
      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect(
        result.stdout,
        [for (final i in release.items) '- ${i.text}\n'].join(),
      );
    });
  }

  test('a version with no entry fails and prints nothing', () async {
    final result = await run('0.0.0');
    expect(result.exitCode, 1);
    expect(result.stdout, isEmpty);
  });
}
