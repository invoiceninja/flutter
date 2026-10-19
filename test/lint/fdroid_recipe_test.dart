import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// CI lint: `tools/foss/com.invoiceninja.admin.yml` is the only definition of
/// the F-Droid APK. Release CI builds it with `fdroid build`, and F-Droid
/// rebuilds it to check our signature, publishing only on a byte-for-byte
/// match (docs/fdroid.md § The F-Droid APK is built by F-Droid's own tooling).
/// Nothing else would notice the recipe drifting, so each test pins one way
/// it can:
///
///  * the prebuild that checks out CI's Flutter pin, or `ndk:` leaving that
///    Flutter's NDK: the APK F-Droid rebuilds is no longer the one CI tested;
///  * the three ABI blocks leaving the Gradle file's build * 10 + ABI
///    versionCode scheme, or the Gradle file dropping it;
///  * a build that doesn't pin `ANDROID_NDK_HOME`: Flutter then compiles the
///    SQLite hook with whichever NDK is newest on the buildserver;
///  * a malformed signing key or download URL;
///  * a plugin whose Android build file names a Maven repo F-Droid's scanner
///    doesn't know, without a `scanignore:` for it: `scandelete: .pub-cache`
///    then deletes that whole file, and Gradle fails configuring the plugin;
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
  // android/app/build.gradle.kts, below.
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

  test(
    'the Flutter srclib is checked out at the version every workflow pins',
    () {
      final pins = <String>{};
      for (final f in Directory('.github/workflows').listSync()) {
        if (f is! File || !RegExp(r'\.ya?ml$').hasMatch(f.path)) continue;
        pins.addAll(_all(f.readAsStringSync(), r'flutter-version:\s*(\S+)'));
      }
      expect(pins, hasLength(1), reason: 'the workflows disagree: $pins');

      // fdroiddata's templates/build-flutter.yml: srclib at `stable`, then the
      // tag's own pin checked out in prebuild, so F-Droid's checkupdates bot
      // builds each new tag with the Flutter it was released with.
      const readPin =
          r'''      - flutterVersion=$(sed -n -E "s/^ *flutter-version:\ ([0-9.]+) *$/\1/p" .github/workflows/appimage.yml)''';
      const prebuild = [
        '    prebuild:',
        readPin,
        "      - '[[ \$flutterVersion ]]'",
        r'      - git -C $$flutter$$ checkout -f $flutterVersion',
      ];
      for (final b in blocks) {
        expect(_all(b, r'- (flutter@\S+)$'), [
          'flutter@stable',
        ], reason: _abiOf(b));
        expect(b, contains(prebuild.join('\n')), reason: _abiOf(b));
      }

      // The prebuild's sed, applied here: one line of appimage.yml, the pin.
      final read = RegExp(r'^ *flutter-version: ([0-9.]+) *$', multiLine: true)
          .allMatches(File('.github/workflows/appimage.yml').readAsStringSync())
          .map((m) => m.group(1))
          .toList();
      expect(read, [pins.single]);
    },
  );

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

  test("versionCodes follow the Gradle file's build * 10 + ABI scheme", () {
    // F-Droid installs the highest versionCode a device can run and archives
    // all but the highest, so the ABI goes in the last digit and every ABI of
    // a new release outranks every ABI of an old one. Flutter's own split
    // scheme (<digit> * 1000 + build) doesn't, so the Gradle file overrides
    // it; a recipe that disagrees fails `fdroid build` on the APK's code.
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(
      gradle,
      contains(
        'versionCodeOverride = variant.versionCode * 10 + abiVersionCode',
      ),
      reason:
          'without the override Flutter gives the split APK '
          '<digit> * 1000 + N, which the recipe no longer names',
    );
    final abiCodes = RegExp(r'val abiCodes = mapOf\((.*)\)').firstMatch(gradle);
    expect(abiCodes, isNotNull, reason: 'android/app/build.gradle.kts');
    final digits = {
      for (final m in RegExp(
        r'"([\w-]+)" to (\d+)',
      ).allMatches(abiCodes!.group(1)!))
        m.group(1)!: int.parse(m.group(2)!),
    };
    expect(digits.keys, platforms.keys, reason: 'abiCodes covers each ABI');

    final name = _one(blocks.first, r'^  - versionName: (\S+)$');
    final number =
        int.parse(_one(blocks.first, r'^    versionCode: (\d+)$')) ~/ 10;
    for (final b in blocks) {
      final abi = _abiOf(b);
      expect(_one(b, r'^  - versionName: (\S+)$'), name, reason: abi);
      expect(
        int.parse(_one(b, r'^    versionCode: (\d+)$')),
        number * 10 + digits[abi]!,
        reason: '$abi: the Gradle file gives the split APK N * 10 + <digit>',
      );
      expect(_one(b, r'^    commit: (\S+)$'), 'v$name', reason: abi);
    }
    expect(_all(recipe, r"^  - '?(10 \* %c \+ \d+)'?$"), [
      for (final abi in platforms.keys) '10 * %c + ${digits[abi]}',
    ], reason: 'VercodeOperation must list the blocks in the same order');
    expect(_one(recipe, r'^CurrentVersion: (\S+)$'), name);
    expect(
      int.parse(_one(recipe, r'^CurrentVersionCode: (\d+)$')),
      number * 10 + digits['x86_64']!,
      reason: 'the highest of the three',
    );
  });

  test('the recipe names the version in pubspec.yaml', () {
    final pubspec = RegExp(
      r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$',
      multiLine: true,
    ).firstMatch(File('pubspec.yaml').readAsStringSync());
    expect(pubspec, isNotNull);
    final (name, build) = (pubspec!.group(1)!, int.parse(pubspec.group(2)!));
    for (final b in blocks) {
      expect(_one(b, r'^  - versionName: (\S+)$'), name, reason: _abiOf(b));
      expect(
        int.parse(_one(b, r'^    versionCode: (\d+)$')) ~/ 10,
        build,
        reason: _abiOf(b),
      );
    }
    expect(
      _one(recipe, r'^CurrentVersion: (\S+)$'),
      name,
      reason:
          'tools/bump_client_version.sh rewrites the recipe with '
          'pubspec.yaml, so the recipe already names the release that gets '
          'tagged. Run it rather than editing either by hand.',
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
      // the same fixed path, with the pub cache inside it. prebuild's first
      // three commands check out Flutter (tested above) before the move.
      for (final step in [prebuild.sublist(3), build]) {
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

  test("every plugin naming a repo F-Droid's scanner flags is scanignored", () {
    // The packages this build resolved, from `pub get`'s package_config.
    final config = File('.dart_tool/package_config.json').readAsStringSync();
    final roots = {
      for (final m in RegExp(
        r'"name":\s*"([^"]+)",\s*"rootUri":\s*"file://([^"]+)"',
      ).allMatches(config))
        m.group(1)!: Uri.decodeFull(m.group(2)!),
    };
    expect(roots, isNotEmpty, reason: 'run `flutter pub get` first');

    // fdroidserver/scanner.py `allowed_repos` (fdroidserver 5806784d).
    const allowed = [
      'repo1.maven.org/maven2',
      'jitpack.io',
      'www.jitpack.io',
      'repo.maven.apache.org/maven2',
      'oss.jfrog.org/artifactory/oss-snapshot-local',
      'central.sonatype.com/repository/maven-snapshots',
      'oss.sonatype.org/content/',
      's01.oss.sonatype.org/content/',
      'clojars.org/repo',
      'repo.clojars.org',
      's3.amazonaws.com/repo.commonsware.com',
      'plugins.gradle.org/m2',
      'maven.google.com',
    ];
    final repoUrl = RegExp(
      r'''url\s*[=(]?\s*(?:uri\()?\s*['"]https://([^'"]+)''',
    );
    final flagged = <String>{};
    for (final MapEntry(key: name, value: root) in roots.entries) {
      // Only what lands in the build's `.pub-cache` gets scanned: hosted and
      // git packages, wherever PUB_CACHE points. Flutter SDK packages live
      // in the srclib, which F-Droid doesn't scan.
      if (!RegExp(r'/(hosted|git)/').hasMatch(root)) continue;
      for (final file in ['build.gradle', 'build.gradle.kts']) {
        final f = File('$root/android/$file');
        if (!f.existsSync()) continue;
        for (final m in repoUrl.allMatches(f.readAsStringSync())) {
          if (!allowed.any(m.group(1)!.startsWith)) flagged.add(name);
        }
      }
    }

    final ignored = <String>{};
    for (final b in blocks) {
      final entries = _commands(b, 'scanignore');
      final names = {
        for (final e in entries)
          RegExp(
                r'^\.pub-cache/hosted/pub\.dev/([a-z0-9_]+)-\*/android/'
                r'build\.gradle(?:\.kts)?$',
              ).firstMatch(e)?.group(1) ??
              e,
      };
      if (ignored.isEmpty) ignored.addAll(names);
      expect(names, ignored, reason: 'every ABI block scans the same tree');
    }
    expect(
      ignored,
      flagged,
      reason:
          'One `.pub-cache/hosted/pub.dev/<plugin>-*/android/build.gradle` '
          'scanignore per plugin naming an unknown Maven repo — no more: '
          "F-Droid's scan fails on an unused scanignore entry "
          '(docs/fdroid.md § The F-Droid recipe).',
    );
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
