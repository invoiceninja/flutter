import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// CI lint: `tools/foss/com.invoiceninja.admin.yml` is the only definition of
/// the F-Droid APK. Release CI builds it with `fdroid build`, and F-Droid
/// rebuilds it to check our signature, publishing only on a byte-for-byte
/// match (docs/fdroid.md § The F-Droid APK is built by F-Droid's own tooling).
/// Nothing else would notice the recipe drifting, so each test pins one way
/// it can:
///
///  * `flutter@` / `ndk:` leaving CI's Flutter pin, or that Flutter's NDK: the
///    APK F-Droid rebuilds is no longer the one CI tested;
///  * the three ABI blocks leaving Flutter's split versionCode scheme;
///  * a build that doesn't pin `ANDROID_NDK_HOME`: Flutter then compiles the
///    SQLite hook with whichever NDK is newest on the buildserver;
///  * a malformed signing key or download URL;
///  * `android/app/build.gradle.kts` in a shape F-Droid's signing stripper
///    doesn't fully remove: F-Droid's APK then comes out debug-signed and can
///    never carry our signature.
///
/// Regex parsing, like store_sdk_boundary_test.dart: `yaml` is not a direct
/// dependency, and the recipe's shape is ours to keep simple.
void main() {
  const recipePath = 'tools/foss/com.invoiceninja.admin.yml';
  final recipe = File(recipePath).readAsStringSync();
  final blocks = _buildBlocks(recipe);

  // ABI -> Flutter's --target-platform. The versionCode digit is read from
  // the Flutter SDK itself, below.
  const platforms = {
    'armeabi-v7a': 'android-arm',
    'arm64-v8a': 'android-arm64',
    'x86_64': 'android-x64',
  };

  test('there is one build block per ABI, in versionCode order', () {
    expect(
      blocks.map(_abiOf).toList(),
      ['armeabi-v7a', 'arm64-v8a', 'x86_64'],
      reason:
          'Each block outputs build/app/outputs/flutter-apk/'
          'app-<abi>-release.apk; that is how tools/fdroid_build.sh finds it.',
    );
  });

  test('the Flutter srclib is the version every workflow pins', () {
    final srclibs = {for (final b in blocks) ..._all(b, r'- (flutter@\S+)$')};
    final pins = <String>{};
    for (final f in Directory('.github/workflows').listSync()) {
      if (f is! File || !RegExp(r'\.ya?ml$').hasMatch(f.path)) continue;
      pins.addAll(_all(f.readAsStringSync(), r'flutter-version:\s*(\S+)'));
    }
    expect(pins, hasLength(1), reason: 'the workflows disagree: $pins');
    expect(srclibs, {'flutter@${pins.single}'});
  });

  test("the NDK is the one that Flutter's Gradle plugin pins", () {
    final kotlin = File(
      '${_flutterRoot()}/packages/flutter_tools/gradle/src/main/kotlin/'
      'FlutterExtension.kt',
    ).readAsStringSync();
    final pinned = RegExp(
      r'val ndkVersion: String = "([^"]+)"',
    ).firstMatch(kotlin)?.group(1);
    expect(pinned, isNotNull, reason: 'FlutterExtension.kt changed shape');
    for (final b in blocks) {
      expect(_one(b, r'^    ndk: (\S+)$'), pinned, reason: _abiOf(b));
    }
  });

  test("versionCodes follow Flutter's split-per-ABI scheme", () {
    final constants = File(
      '${_flutterRoot()}/packages/flutter_tools/gradle/src/main/kotlin/'
      'FlutterPluginConstants.kt',
    ).readAsStringSync();
    int abiDigit(String arch) =>
        int.parse(RegExp('$arch to (\\d+)').firstMatch(constants)!.group(1)!);
    final digits = {
      'armeabi-v7a': abiDigit('ARCH_ARM32'),
      'arm64-v8a': abiDigit('ARCH_ARM64'),
      'x86_64': abiDigit('ARCH_X86_64'),
    };

    final name = _one(blocks.first, r'^  - versionName: (\S+)$');
    final number =
        int.parse(_one(blocks.first, r'^    versionCode: (\d+)$')) -
        digits['armeabi-v7a']! * 1000;
    for (final b in blocks) {
      final abi = _abiOf(b);
      expect(_one(b, r'^  - versionName: (\S+)$'), name, reason: abi);
      expect(
        int.parse(_one(b, r'^    versionCode: (\d+)$')),
        digits[abi]! * 1000 + number,
        reason: '$abi: Flutter gives the split APK <abi digit> * 1000 + N',
      );
      expect(_one(b, r'^    commit: (\S+)$'), 'v$name', reason: abi);
    }
    expect(
      _all(recipe, r"^  - '(%c \+ \d+)'$"),
      [for (final abi in platforms.keys) '%c + ${digits[abi]! * 1000}'],
      reason: 'VercodeOperation must list the blocks in the same order',
    );
    expect(_one(recipe, r'^CurrentVersion: (\S+)$'), name);
    expect(
      int.parse(_one(recipe, r'^CurrentVersionCode: (\d+)$')),
      digits['x86_64']! * 1000 + number,
      reason: 'the highest of the three',
    );
  });

  test('each block builds its own ABI the way the template does', () {
    for (final b in blocks) {
      final abi = _abiOf(b);
      final build = _commands(b, 'build');
      final prebuild = _commands(b, 'prebuild');
      expect(
        build,
        contains(
          r'$$flutter$$/bin/flutter build apk --release --split-per-abi '
          '--target-platform=${platforms[abi]}',
        ),
        reason: abi,
      );
      expect(
        build,
        contains(r'export ANDROID_NDK_HOME=$$NDK$$'),
        reason:
            '$abi: without it Flutter compiles the SQLite hook with the '
            'newest NDK installed (flutter_tools android_sdk.dart '
            'getNdkBinaryPath), not the one this block asks F-Droid for',
      );
      expect(
        build.indexOf(r'export ANDROID_NDK_HOME=$$NDK$$'),
        lessThan(build.indexWhere((c) => c.contains('flutter build apk'))),
        reason: abi,
      );
      expect(
        prebuild,
        contains(r'FLUTTER=$$flutter$$/bin/flutter tools/prepare_foss.sh'),
        reason: abi,
      );
      // The build path is embedded in libapp.so, so both steps must run at
      // the same fixed path, with the pub cache inside it.
      for (final step in [prebuild, build]) {
        expect(step, contains('export repo=/build/com.invoiceninja.admin'));
        expect(step, contains(r'export PUB_CACHE=$(pwd)/.pub-cache'));
        expect(step.first, 'export repo=/build/com.invoiceninja.admin');
        expect(step.last, r'mv $repo com.invoiceninja.admin');
      }
      expect(
        _one(b, r'^    binary:\s+(\S+)$'),
        'https://github.com/invoiceninja/flutter/releases/download/'
        'v%v/InvoiceNinja-%v-$abi.apk',
        reason: '$abi: tools/fdroid_build.sh sign names the asset from this',
      );
      expect(
        b,
        contains('    binary: \n      https://'),
        reason:
            '$abi: `fdroid rewritemeta` moves a value this long to the '
            'next line (after a trailing space), and the release lint step '
            'fails on any other layout',
      );
    }
  });

  test('the signing key is a SHA-256 fingerprint', () {
    expect(
      _one(recipe, r'^AllowedAPKSigningKeys: (\S+)$'),
      matches(RegExp(r'^[0-9a-f]{64}$')),
      reason:
          'lowercase hex, as `apksigner verify --print-certs` prints it. '
          'Anything else makes preflight (appimage.yml) publish Releases '
          'without the APKs, and F-Droid then skips every such version. '
          'Rotating the key: docs/store-deployment-setup.md § F-Droid '
          'signing key.',
    );
  });

  test("F-Droid's signing stripper leaves an unsigned release build", () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(
      gradle,
      contains(
        'signingConfig = signingConfigs.getByName(releaseSigningConfig)',
      ),
      reason:
          'the release type no longer picks its signing config on the '
          'one line the stripper removes',
    );
    final stripped = _removeSigningKeys(gradle);
    expect(stripped, isNot(gradle), reason: 'the stripper removed nothing');
    expect(
      stripped,
      isNot(contains(RegExp(r'^\s*signingConfig\s*=', multiLine: true))),
      reason:
          'a signingConfig the stripper left behind: F-Droid would build '
          'a signed (debug) APK, which never verifies against ours',
    );
    expect(stripped, isNot(contains('signingConfigs.getByName')));
    expect(
      '{'.allMatches(stripped).length,
      '}'.allMatches(stripped).length,
      reason: 'the stripped build file no longer compiles',
    );
  });
}

/// The `Builds:` list, one string per block.
List<String> _buildBlocks(String recipe) {
  final start = recipe.indexOf('\nBuilds:\n');
  final end = recipe.indexOf(RegExp(r'^\S', multiLine: true), start + 9);
  final builds = recipe.substring(start + 9, end);
  return builds
      .split(RegExp(r'^(?=  - versionName:)', multiLine: true))
      .where((b) => b.trim().isNotEmpty)
      .toList();
}

String _abiOf(String block) => _one(
  block,
  r'^    output: build/app/outputs/flutter-apk/app-(\S+)-release\.apk$',
);

/// The `    <key>:` list of a block, one string per command.
List<String> _commands(String block, String key) {
  final m = RegExp(
    '^    $key:\\n((?:      - .*\\n)+)',
    multiLine: true,
  ).firstMatch(block);
  expect(m, isNotNull, reason: 'no $key: in\n$block');
  return [
    for (final line in m!.group(1)!.trimRight().split('\n'))
      line.substring('      - '.length),
  ];
}

String _one(String text, String pattern) {
  final all = _all(text, pattern);
  expect(all, hasLength(1), reason: '/$pattern/ in\n$text');
  return all.single;
}

List<String> _all(String text, String pattern) => [
  for (final m in RegExp(pattern, multiLine: true).allMatches(text))
    m.group(1)!,
];

/// The Flutter SDK running this test: `flutter test` exports FLUTTER_ROOT,
/// and the tester binary lives under `<root>/bin/cache` otherwise. Never a
/// skip — a test that can't find the SDK would pass vacuously.
String _flutterRoot() {
  final env = Platform.environment['FLUTTER_ROOT'];
  if (env != null && Directory(env).existsSync()) return env;
  var dir = File(Platform.resolvedExecutable).parent;
  while (dir.parent.path != dir.path) {
    if (dir.path.endsWith('${Platform.pathSeparator}bin') &&
        Directory('${dir.path}/cache').existsSync()) {
      return dir.parent.path;
    }
    dir = dir.parent;
  }
  fail('cannot find the Flutter SDK (no FLUTTER_ROOT)');
}

/// A port of the Gradle half of `fdroidserver.common.remove_signing_keys`,
/// which `fdroid build` runs on every build.gradle(.kts) before the recipe:
/// it drops a `signingConfigs {` block (by brace count) and any line matching
/// one of three patterns, passing comment lines through untouched.
String _removeSigningKeys(String gradle) {
  final comment = RegExp(r'^[ ]*//');
  final block = RegExp(r'^[\t ]*signingConfigs[ \t]*{[ \t]*$');
  final lineMatches = [
    RegExp(r'^[\t ]*signingConfig\s*[= ]\s*[^ ]*$'),
    RegExp(r'.*android\.signingConfigs\.[^{]*$'),
    RegExp(r'.*release\.signingConfig *= *'),
  ];
  final lines = gradle.split('\n');
  final out = <String>[];
  var opened = 0;
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i];
    while (line.endsWith(r'\') && i + 1 < lines.length) {
      line = line.substring(0, line.length - 1) + lines[++i];
    }
    if (comment.hasMatch(line)) {
      out.add(line);
      continue;
    }
    if (opened > 0) {
      opened += '{'.allMatches(line).length - '}'.allMatches(line).length;
      continue;
    }
    if (block.hasMatch(line)) {
      opened++;
      continue;
    }
    if (lineMatches.any((r) => r.hasMatch(line))) continue;
    out.add(line);
  }
  return out.join('\n');
}
