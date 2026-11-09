import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// tools/metainfo_release.py writes each release's `<release>` into the Linux
/// metainfo at bump time (tools/bump_client_version.sh), and Flathub builds
/// from the tag, so the committed file is what Flathub and GNOME Software show
/// as the changelog (docs/flatpak.md).
void main() {
  const metainfoPath = 'appimage/com.invoiceninja.InvoiceNinja.metainfo.xml';
  final release = RegExp(
    r'<release\b[^>]*\bversion="([^"]+)"[^>]*\bdate="([^"]+)"[^>]*>(.*?)</release>',
    dotAll: true,
  );

  group('the committed metainfo', () {
    final metainfo = File(metainfoPath).readAsStringSync();
    final releases = release.allMatches(metainfo).toList();

    test('names the pubspec version in its newest <release>', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final version = RegExp(
        r'^version:\s*(\d+\.\d+\.\d+)\+\d+',
        multiLine: true,
      ).firstMatch(pubspec)!.group(1);
      expect(releases, isNotEmpty);
      expect(releases.first.group(1), version);
    });

    test('lists releases newest first, each once, none dated in the future '
        '(AppStream rejects a future date)', () {
      final versions = [for (final r in releases) r.group(1)!];
      expect(versions.toSet().length, versions.length, reason: '$versions');
      List<int> parts(String v) => [for (final p in v.split('.')) int.parse(p)];
      for (var i = 1; i < versions.length; i++) {
        final a = parts(versions[i - 1]), b = parts(versions[i]);
        final newer =
            a[0] > b[0] ||
            (a[0] == b[0] && (a[1] > b[1] || (a[1] == b[1] && a[2] > b[2])));
        expect(
          newer,
          isTrue,
          reason: '${versions[i - 1]} before ${versions[i]}',
        );
      }
      final tomorrow = DateTime.now().toUtc().add(const Duration(days: 1));
      for (final r in releases) {
        expect(DateTime.parse(r.group(2)!).isBefore(tomorrow), isTrue);
      }
    });

    test('carries no link or other markup AppStream descriptions refuse', () {
      for (final r in releases) {
        expect(r.group(3), isNot(contains('<a ')), reason: r.group(1));
        expect(r.group(3), isNot(contains('](')), reason: r.group(1));
      }
    });

    test('is v1\'s Flathub ID, agreed on by every Linux identity file '
        '(docs/flatpak.md § The Linux app ID is v1\'s Flathub ID)', () {
      const id = 'com.invoiceninja.InvoiceNinja';
      expect(metainfo, contains('<id>$id</id>'));
      expect(
        metainfo,
        contains('<launchable type="desktop-id">$id.desktop</launchable>'),
      );
      expect(metainfoPath, 'appimage/$id.metainfo.xml');
      // It is v1's ID, so it no longer provides or replaces it.
      expect(metainfo, isNot(contains('<provides>')));
      expect(metainfo, isNot(contains('<replaces>')));

      final desktop = File('appimage/$id.desktop').readAsStringSync();
      expect(desktop, contains('\nIcon=$id\n'));
      expect(desktop, contains('\nStartupWMClass=$id\n'));

      final cmake = File('linux/CMakeLists.txt').readAsStringSync();
      expect(cmake, contains('set(APPLICATION_ID "$id")'));
      expect(
        File('tools/build_appimage.sh').readAsStringSync(),
        contains('--icon-filename $id '),
      );
    });

    test('the plugins still see the pre-rename ID, which keys the keyring '
        'entry holding the database key', () {
      final cmake = File('linux/CMakeLists.txt').readAsStringSync();
      expect(
        cmake,
        contains('set(KEYRING_APPLICATION_ID "com.invoiceninja.admin")'),
      );
      expect(
        cmake,
        contains(
          'set(APPLICATION_ID "\${KEYRING_APPLICATION_ID}")\n'
          'include(flutter/generated_plugins.cmake)\n'
          'set(APPLICATION_ID "\${APPLICATION_ID_FOR_APP}")\n',
        ),
      );
      expect(
        File('linux/runner/CMakeLists.txt').readAsStringSync(),
        contains('-DLEGACY_APPLICATION_ID="\${KEYRING_APPLICATION_ID}"'),
      );
      expect(
        File('linux/runner/my_application.cc').readAsStringSync(),
        contains('  migrate_legacy_data_dir();\n'),
      );
    });
  });

  group('tools/metainfo_release.py', () {
    late Directory root;

    // The script resolves its paths from its own location, so a copy in a
    // temp tree edits the temp metainfo, never the committed one.
    setUp(() {
      root = Directory.systemTemp.createTempSync('metainfo_release_');
      for (final path in ['tools/metainfo_release.py', metainfoPath]) {
        File('${root.path}/$path')
          ..createSync(recursive: true)
          ..writeAsStringSync(File(path).readAsStringSync());
      }
      File('${root.path}/fastlane/metadata/android/en-US/changelogs/991.txt')
        ..createSync(recursive: true)
        ..writeAsStringSync(
          '- Sign in with Google & a passkey\n'
          '- APKs now install over each other\n'
          '\n'
          '- Faster lists\n',
        );
      File(
        '${root.path}/fastlane/metadata/android/en-US/changelogs/981.txt',
      ).writeAsStringSync('- Fixed the Android back button\n');
    });

    tearDown(() => root.deleteSync(recursive: true));

    Future<ProcessResult> run(List<String> args) => Process.run('python3', [
      '${root.path}/tools/metainfo_release.py',
      ...args,
    ]);

    String temp() => File('${root.path}/$metainfoPath').readAsStringSync();

    test('writes the digest as the newest entry, escaped, dropping lines '
        'about another platform', () async {
      final result = await run(['9.9.9', '99', '--date', '2026-01-02']);
      expect(result.exitCode, 0, reason: '${result.stderr}');
      final first = release.firstMatch(temp())!;
      expect(first.group(1), '9.9.9');
      expect(first.group(2), '2026-01-02');
      expect(
        first.group(3),
        contains('<li>Sign in with Google &amp; a passkey</li>'),
      );
      expect(first.group(3), contains('<li>Faster lists</li>'));
      expect(first.group(3), isNot(contains('APK')));
    });

    test('a re-run replaces its entry rather than adding a second', () async {
      await run(['9.9.9', '99', '--date', '2026-01-02']);
      await run(['9.9.9', '99', '--date', '2026-01-03']);
      final entries = release
          .allMatches(temp())
          .where((r) => r.group(1) == '9.9.9');
      expect(entries.map((r) => r.group(2)), ['2026-01-03']);
    });

    test(
      'a digest with nothing left for Linux still writes an entry',
      () async {
        final result = await run(['9.9.8', '98', '--date', '2026-01-02']);
        expect(result.exitCode, 0, reason: '${result.stderr}');
        expect(
          release.firstMatch(temp())!.group(3),
          contains('<p>Fixes and improvements</p>'),
        );
      },
    );

    test('a missing digest fails and changes nothing', () async {
      final before = temp();
      final result = await run(['9.9.7', '97']);
      expect(result.exitCode, 1);
      expect(temp(), before);
    });

    test('--check passes only for a version with an entry', () async {
      await run(['9.9.9', '99', '--date', '2026-01-02']);
      expect((await run(['--check', '9.9.9'])).exitCode, 0);
      expect((await run(['--check', '9.9.6'])).exitCode, 1);
    });
  });
}
