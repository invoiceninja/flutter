import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// CI lint: `.github/workflows/deploy-all.yml` ships a release everywhere from
/// one dispatch — the readiness check, then appimage.yml (whose test gate is
/// the one test run), then the five store workflows with their own test gate
/// skipped, and the Flathub leg that follows the release onto Flathub
/// (docs/store-deployment-setup.md § 0 Start here, docs/flatpak.md).
///
/// GitHub validates none of this until a real release is dispatched, and the
/// worst ways it drifts are silent: a store call without `secrets: inherit`
/// ships with Sentry off, an appimage.yml call trigger without `publish`
/// goes green having published nothing, and a store whose test gate ignores
/// `skip_tests` runs the suite five more times. Each test pins one of them.
void main() {
  const dir = '.github/workflows';
  const stores = [
    'snapcraft.yml',
    'playstore.yml',
    'microsoft-store.yml',
    'appstore-ios.yml',
    'appstore-macos.yml',
  ];
  final deployAll = File('$dir/deploy-all.yml').readAsStringSync();
  final jobs = _jobs(deployAll);

  /// The deploy-all job that calls [workflow].
  MapEntry<String, String> callOf(String workflow) {
    final calls = jobs.entries
        .where((j) => j.value.contains('uses: ./$dir/$workflow\n'))
        .toList();
    expect(calls, hasLength(1), reason: 'deploy-all.yml calls $workflow once');
    return calls.single;
  }

  test('every publish workflow is called once, with the secrets', () {
    for (final workflow in ['appimage.yml', ...stores]) {
      final call = callOf(workflow);
      expect(
        call.value,
        contains('    secrets: inherit\n'),
        reason:
            '${call.key} (→ $workflow): without it IN_SENTRY_DSN is empty '
            'and the build ships with Sentry silently off.',
      );
    }
  });

  test('the release runs the tests; the stores skip theirs after it', () {
    final release = callOf('appimage.yml');
    expect(
      release.value,
      isNot(contains('    with:\n')),
      reason:
          'appimage.yml takes no inputs here: its test gate is the one test '
          'run, and publish keeps its default of true.',
    );
    expect(release.value, contains('    needs: ready\n'));
    expect(release.value, contains('      contents: write\n'));
    for (final workflow in stores) {
      final call = callOf(workflow);
      expect(call.value, contains('    needs: release\n'), reason: call.key);
      expect(
        call.value,
        contains('    with:\n      skip_tests: true\n'),
        reason: call.key,
      );
    }
  });

  test('the readiness check runs before anything is built', () {
    final ready = jobs['ready'];
    expect(ready, isNotNull);
    expect(ready, contains('fetch-depth: 0'));
    expect(ready, contains('run: tools/check_release_ready.sh\n'));
  });

  test('each store gate skips only on the call, and the deploy still runs', () {
    for (final workflow in stores) {
      final text = File('$dir/$workflow').readAsStringSync();
      final storeJobs = _jobs(text);
      expect(
        text,
        contains('  workflow_call:\n    inputs:\n      skip_tests:\n'),
        reason: '$workflow: deploy-all.yml passes skip_tests',
      );
      // Under workflow_call only: a manual dispatch can never skip the suite.
      // (A dispatch may take other inputs, such as playstore.yml's track.)
      final dispatch = RegExp(
        r'^  workflow_dispatch:\n(.*?)^  workflow_call:',
        multiLine: true,
        dotAll: true,
      ).firstMatch(text);
      expect(dispatch, isNotNull, reason: workflow);
      expect(
        dispatch!.group(1),
        isNot(matches(RegExp(r'^\s+skip_tests:', multiLine: true))),
        reason: workflow,
      );
      expect(
        storeJobs['test'],
        allOf(
          contains(r'    if: ${{ !inputs.skip_tests }}'),
          contains('    uses: ./$dir/_test.yaml\n'),
        ),
        reason: workflow,
      );
      final deploys = storeJobs.entries.where((j) => j.key != 'test').toList();
      expect(deploys, isNotEmpty, reason: workflow);
      for (final job in deploys) {
        expect(job.value, contains('    needs: test\n'), reason: job.key);
        // A skipped `needs` skips the job unless it states its own condition.
        expect(
          job.value,
          contains(
            "    if: \${{ !cancelled() && (needs.test.result == 'success' "
            "|| needs.test.result == 'skipped') }}\n",
          ),
          reason: '$workflow ${job.key}',
        );
      }
    }
  });

  test('the Flathub leg only reads, and waits for the launch flag', () {
    final call = callOf('flathub.yml');
    expect(call.value, contains('    needs: release\n'));
    expect(
      call.value,
      contains("    if: vars.FLATHUB_ENABLED == 'true'\n"),
      reason:
          'Until the submission is accepted there is no flathub/com.invoiceninja.admin, and every '
          'deploy would fail waiting for it (docs/going-live.md).',
    );
    expect(
      call.value,
      isNot(contains('secrets: inherit')),
      reason: 'It writes nothing anywhere, so it gets no secrets.',
    );
    final text = File('$dir/flathub.yml').readAsStringSync();
    expect(text, contains('\n  workflow_call:\n'));
    expect(
      text,
      contains('\npermissions:\n  contents: read\n\njobs:\n'),
      reason:
          'Read-only, and a called workflow cannot ask for more than '
          "deploy-all.yml's contents: read.",
    );
    expect(text, isNot(contains('secrets.')));
    expect(text, contains('run: tools/follow_flathub_release.sh'));
  });

  test('appimage.yml declares publish on the call trigger too', () {
    final text = File('$dir/appimage.yml').readAsStringSync();
    final call = RegExp(
      r'^  workflow_call:\n    inputs:\n      publish:\n(?:        .*\n)*',
      multiLine: true,
    ).firstMatch(text);
    expect(
      call,
      isNotNull,
      reason:
          'without it inputs.publish is null when called: preflight takes the '
          'dry-run branch and the release publishes nothing.',
    );
    expect(call!.group(0), contains('        default: true\n'));
  });

  test('the readiness check passes on the tree as committed', () {
    // --offline: the tag checks need origin, and HEAD's version is normally
    // already released. What is left is the notes entry, the F-Droid
    // changelogs and the version files agreeing — which a hand edit breaks.
    final result = Process.runSync('bash', [
      'tools/check_release_ready.sh',
      '--offline',
    ]);
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
  });
}

/// The top-level jobs of a workflow, id → that job's lines.
Map<String, String> _jobs(String workflow) {
  final body = workflow.substring(workflow.indexOf('\njobs:\n') + 7);
  final jobs = <String, String>{};
  String? id;
  final buffer = StringBuffer();
  void flush() {
    if (id != null) jobs[id] = buffer.toString();
    buffer.clear();
  }

  for (final line in body.split('\n')) {
    final m = RegExp(r'^  ([A-Za-z0-9_-]+):\s*$').firstMatch(line);
    if (m != null) {
      flush();
      id = m.group(1);
    } else if (id != null) {
      buffer.writeln(line);
    }
  }
  flush();
  return jobs;
}
