import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/version.dart';

void main() {
  // `clientBuild` is the last dotted segment of [AppVersion.kClientVersion].
  // Derive it here so these assertions survive a `kClientVersion` bump rather
  // than hard-coding today's value.
  final build = AppVersion.kClientVersion.split('.').last;

  group('AppVersion.versionLabel', () {
    test('combines server version, platform letter, and client build', () {
      expect(
        AppVersion.versionLabel(serverVersion: '5.11.40', platformLetter: 'M'),
        'v5.11.40-M$build',
      );
    });

    test('uses the platform letter it is given', () {
      expect(
        AppVersion.versionLabel(serverVersion: '5.11.40', platformLetter: 'C'),
        'v5.11.40-C$build',
      );
    });

    test('renders an empty server section when the server version is null', () {
      expect(
        AppVersion.versionLabel(serverVersion: null, platformLetter: 'C'),
        'v-C$build',
      );
    });

    test('trims surrounding whitespace from the server version', () {
      expect(
        AppVersion.versionLabel(
          serverVersion: '  5.11.40 ',
          platformLetter: 'W',
        ),
        'v5.11.40-W$build',
      );
    });
  });

  test('snapcraft.yaml display version matches the pubspec triplet — '
      'tools/bump_client_version.sh keeps them in lockstep (the manual bump '
      'drifted 4 releases before it was automated)', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final pubspecVersion = RegExp(
      r'^version:\s*(\d+\.\d+\.\d+)\+\d+',
      multiLine: true,
    ).firstMatch(pubspec)?.group(1);
    final snapcraft = File('snap/snapcraft.yaml').readAsStringSync();
    final snapVersion = RegExp(
      r"^version:\s*'([^']+)'",
      multiLine: true,
    ).firstMatch(snapcraft)?.group(1);

    expect(pubspecVersion, isNotNull);
    expect(snapVersion, pubspecVersion);
  });
}
