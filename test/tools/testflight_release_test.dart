import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// tools/testflight_release.py sets TestFlight's "What to Test" from the
/// release's short digest (the F-Droid changelog Google Play also takes),
/// minus any line an App Store build may not show (Apple guideline 2.3.10).
/// `--print-notes` prints exactly that text, with no network.
void main() {
  final changelogs = Directory('fastlane/metadata/android/en-US/changelogs');
  // Written independently of the script's own pattern, so a gap in one shows:
  // test/domain/release_notes_test.dart's App Store list, minus its bare
  // "google" (a digest may say "Sign in with Google").
  final otherPlatform = RegExp(
    r'android|google play|play store|f-?droid|microsoft store|\bsnap\b|'
    r'appimage',
    caseSensitive: false,
  );

  Future<ProcessResult> printNotes(int build) => Process.run('python3', [
    'tools/testflight_release.py',
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
    final build = n ~/ 10;
    test('build $build: the digest, minus other platforms', () async {
      final result = await printNotes(build);
      expect(result.exitCode, 0, reason: '${result.stderr}');
      final digest = File(
        '${changelogs.path}/$n.txt',
      ).readAsLinesSync().where((l) => l.trim().isNotEmpty);
      final kept = [
        for (final line in digest)
          if (!otherPlatform.hasMatch(line)) line,
      ];
      expect(
        result.stdout,
        kept.isEmpty ? '' : '${kept.join('\n')}\n',
        reason: 'every line not naming another platform, in order',
      );
    });
  }

  test('a release whose digest only names F-Droid sends nothing', () async {
    // 5.1.18 (build 21): "The F-Droid APKs now number each CPU architecture…"
    final result = await printNotes(21);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect(result.stdout, isEmpty);
  });

  test('a build with no digest fails', () async {
    final result = await printNotes(999999);
    expect(result.exitCode, 1);
    expect(result.stderr, contains('is missing'));
  });
}
