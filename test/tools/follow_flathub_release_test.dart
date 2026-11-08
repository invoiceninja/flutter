import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// tools/follow_flathub_release.sh is Deploy to all's `flathub` leg: it reads
/// the Flathub repo's update PR and the listing, and says how far the release
/// got (docs/flatpak.md). `gh` and `curl` are stubbed on PATH here with canned
/// answers; the shapes are the real ones (`gh pr checks --json bucket` on a
/// Flathub PR reports flathub/build et al.; the appstream API's
/// `.releases[0].version`).
void main() {
  setUp(() {
    _root = Directory.systemTemp.createTempSync('follow_flathub_');
    final bin = Directory('${_root.path}/bin')..createSync();
    // gh: answers from files the test writes; `repos/...` exists unless
    // NO_REPO is set.
    File('${bin.path}/gh')
      ..writeAsStringSync(r'''#!/usr/bin/env bash
case "$1 $2" in
  "api repos/"*) [[ -z "${NO_REPO:-}" ]] ;;
  "pr list") cat "$STUB/pr_list.json" ;;
  "pr view") cat "$STUB/pr_state" ;;
  "pr checks") cat "$STUB/checks" ;;
  *) echo "unexpected gh $*" >&2; exit 2 ;;
esac
''')
      ..createSync();
    File('${bin.path}/curl')
      ..writeAsStringSync('#!/usr/bin/env bash\ncat "\$STUB/appstream.json"\n')
      ..createSync();
    for (final f in ['gh', 'curl']) {
      Process.runSync('chmod', ['+x', '${bin.path}/$f']);
    }
    write(
      'pr_list.json',
      '[{"number":7,"url":"https://example/pr/7","state":"OPEN"}]',
    );
    write('pr_state', 'MERGED');
    write('checks', 'pass\npass\n');
    write('appstream.json', '{"releases":[{"version":"9.9.9"}]}');
  });

  tearDown(() => _root.deleteSync(recursive: true));

  Future<ProcessResult> run({Map<String, String> env = const {}}) {
    final summary = File('${_root.path}/summary.md')..writeAsStringSync('');
    return Process.run(
      'bash',
      ['tools/follow_flathub_release.sh', '9.9.9'],
      environment: {
        'PATH': '${_root.path}/bin:${Platform.environment['PATH']}',
        'STUB': _root.path,
        'GITHUB_STEP_SUMMARY': summary.path,
        'FLATHUB_POLL_SECONDS': '0',
        'FLATHUB_PR_WAIT_MINUTES': '0',
        'FLATHUB_MERGE_WAIT_MINUTES': '0',
        'FLATHUB_PUBLISH_WAIT_MINUTES': '0',
        ...env,
      },
    );
  }

  String summary() => File('${_root.path}/summary.md').readAsStringSync();

  test('merged and listed is published', () async {
    final result = await run();
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    expect(summary(), contains('9.9.9 is published'));
  });

  test('merged but not listed yet still succeeds, saying so', () async {
    write('appstream.json', '{"releases":[{"version":"9.9.8"}]}');
    final result = await run();
    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect(summary(), contains('is merged'));
    expect(summary(), contains('lists 9.9.8'));
  });

  test('a failed test build fails, naming the PR', () async {
    write('pr_state', 'OPEN');
    write('checks', 'pass\nfail\n');
    final result = await run();
    expect(result.exitCode, 1);
    expect(summary(), contains('test build for 9.9.9 failed'));
    expect(summary(), contains('https://example/pr/7'));
  });

  test('a passed build nobody merged ends green, asking for the merge — '
      'Flathub may not grant auto-merge', () async {
    write('pr_state', 'OPEN');
    write('checks', 'pass\nskipping\n');
    final result = await run();
    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect(summary(), contains('merge https://example/pr/7'));
  });

  test('a build still running at the deadline fails', () async {
    write('pr_state', 'OPEN');
    write('checks', 'pass\npending\n');
    final result = await run();
    expect(result.exitCode, 1);
    expect(summary(), contains('still running'));
  });

  test('a PR closed unmerged fails', () async {
    write('pr_state', 'CLOSED');
    expect((await run()).exitCode, 1);
    expect(summary(), contains('was closed'));
  });

  test(
    'no update PR by the deadline fails, pointing at the update workflow',
    () async {
      write('pr_list.json', '[]');
      final result = await run();
      expect(result.exitCode, 1);
      expect(summary(), contains('no update PR for 9.9.9'));
    },
  );

  test('no Flathub repo (before acceptance) fails at once', () async {
    final result = await run(env: {'NO_REPO': '1'});
    expect(result.exitCode, 1);
    expect('${result.stdout}${result.stderr}', contains('not on Flathub yet'));
  });
}

late Directory _root;
void write(String name, String content) =>
    File('${_root.path}/$name').writeAsStringSync(content);
