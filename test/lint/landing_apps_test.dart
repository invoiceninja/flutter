import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The invoicing.co landing page (docs/web-deploy.md § The landing page) lists
/// each platform's minimum OS, and `tools/web_deploy/landing/apps.json` is the
/// only place those lines live. They are facts about this app's build, so a
/// deployment-target bump that forgets the JSON would put the wrong
/// requirement in front of every visitor with nothing failing. This test reads
/// each one back from the build files. It also keeps every link on the page
/// https, the same rule `render_landing.py` enforces when it renders.
void main() {
  final data =
      jsonDecode(File('tools/web_deploy/landing/apps.json').readAsStringSync())
          as Map<String, dynamic>;
  final platforms = {
    for (final p in (data['platforms'] as List).cast<Map<String, dynamic>>())
      p['id'] as String: p,
  };

  String minOs(String id) => platforms[id]!['min_os'] as String;

  /// `15.0` → `15`, `8.1` stays `8.1`: how a store page writes a version.
  String major(String version) => version.endsWith('.0')
      ? version.substring(0, version.length - 2)
      : version;

  String podfilePlatform(String path, String platform) {
    final match = RegExp(
      "^platform :$platform, '([0-9.]+)'",
      multiLine: true,
    ).firstMatch(File(path).readAsStringSync());
    expect(match, isNotNull, reason: '$path names no $platform platform');
    return match!.group(1)!;
  }

  test('iPhone & iPad names the iOS deployment target', () {
    final target = podfilePlatform('ios/Podfile', 'ios');
    expect(minOs('ios'), 'iOS ${major(target)} or later');
  });

  test('Mac names the macOS deployment target', () {
    final target = podfilePlatform('macos/Podfile', 'osx');
    expect(minOs('mac'), 'macOS ${major(target)} or later');
  });

  test('Android names the Android version of minSdk', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    // `minSdk = maxOf(flutter.minSdkVersion, 26)` or a plain `minSdk = 26`.
    final match = RegExp(
      r'minSdk\s*=\s*(?:maxOf\(flutter\.minSdkVersion,\s*)?(\d+)',
    ).firstMatch(gradle);
    expect(match, isNotNull, reason: 'android/app/build.gradle.kts minSdk');
    final api = int.parse(match!.group(1)!);
    // API level → the version a user sees in Settings. Extend it when minSdk
    // moves past the table, rather than guessing.
    const versions = {
      24: '7.0',
      25: '7.1',
      26: '8.0',
      27: '8.1',
      28: '9',
      29: '10',
      30: '11',
      31: '12',
      32: '12L',
      33: '13',
      34: '14',
      35: '15',
    };
    expect(versions, contains(api), reason: 'add API $api to this table');
    expect(minOs('android'), 'Android ${versions[api]} or later');
  });

  test("Windows names Flutter's Windows floor", () {
    // Flutter's Windows embedder supports Windows 10 and later; this app sets
    // no stricter floor of its own.
    expect(minOs('windows'), 'Windows 10 or later');
  });

  test('every link on the page is https', () {
    final bad = <String>[];
    void walk(Object? value, String path) {
      if (value is Map) {
        value.forEach((k, v) {
          if (!(k as String).startsWith('_')) {
            walk(v, path.isEmpty ? k : '$path.$k');
          }
        });
      } else if (value is List) {
        for (var i = 0; i < value.length; i++) {
          walk(value[i], '$path[$i]');
        }
      } else if (value is String &&
          value.contains('://') &&
          !value.startsWith('https://')) {
        bad.add('$path: $value');
      }
    }

    walk(data, '');
    expect(bad, isEmpty);
  });
}
