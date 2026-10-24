import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// CI lint: the store builds' non-free SDKs are reachable only through
/// `packages/store_services`, so the F-Droid build can swap that one package
/// for its FOSS twin (`packages/store_services_foss`) and drop them entirely.
/// See docs/fdroid.md.
///
/// The old admin-portal did this with whole-file `.foss` copies that nothing
/// ever built, and they drifted until release day. Each test here pins one
/// way the swap can quietly stop working:
///
///  * an SDK imported from `lib/` again: the FOSS build no longer compiles;
///  * an SDK back in the root `pubspec.yaml`: the FOSS build compiles and
///    ships it anyway, because a plugin in the graph is linked into the APK
///    whether or not its Dart code is reached;
///  * the two packages exposing different declarations: the FOSS build no
///    longer compiles, and nothing on the store side would notice;
///  * `tools/foss/pubspec_overrides.yaml` missing one of `pubspec.yaml`'s
///    `dependency_overrides`: that file REPLACES them rather than merging, so
///    the FOSS build would silently lose an upstream workaround;
///  * `tools/foss/pubspec.lock` behind `pubspec.lock`: F-Droid's
///    `pub get --enforce-lockfile` fails, or builds versions the store build
///    never tested.
void main() {
  const nonFree = [
    'google_sign_in',
    'in_app_purchase',
    'in_app_purchase_storekit',
    'sentry',
    'sentry_flutter',
  ];

  test('lib/, test/ and integration_test/ never import a store SDK', () {
    final import = RegExp(
      r'''^\s*(?:import|export)\s+['"]package:(\w+)/''',
      multiLine: true,
    );
    final offenders = <String>[];
    var files = 0;
    for (final dir in ['lib', 'test', 'integration_test']) {
      for (final f in Directory(dir).listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        files++;
        for (final m in import.allMatches(f.readAsStringSync())) {
          if (nonFree.contains(m.group(1))) {
            offenders.add('${f.path}: package:${m.group(1)}');
          }
        }
      }
    }
    expect(files, greaterThan(100), reason: 'walked the wrong directory');
    expect(
      offenders,
      isEmpty,
      reason:
          'Import package:store_services instead, and add what you need to '
          'BOTH packages/store_services and packages/store_services_foss '
          '(docs/fdroid.md).',
    );
  });

  test('the root pubspec does not depend on a store SDK', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final deps = _section(pubspec, 'dependencies');
    expect(deps, isNotEmpty, reason: 'failed to parse pubspec.yaml');
    expect(deps.keys, contains('store_services'));
    expect(
      deps.keys.where(nonFree.contains),
      isEmpty,
      reason:
          'A store SDK here is linked into the F-Droid APK even when no Dart '
          'code reaches it. Depend on it from packages/store_services.',
    );
    expect(
      _section(pubspec, 'dev_dependencies').keys.where(nonFree.contains),
      isEmpty,
    );
  });

  test('the FOSS twin depends on nothing but Flutter', () {
    final pubspec = File(
      'packages/store_services_foss/pubspec.yaml',
    ).readAsStringSync();
    expect(_topLevel(pubspec, 'name'), 'store_services');
    expect(_section(pubspec, 'dependencies').keys, ['flutter']);
    expect(_section(pubspec, 'dependency_overrides'), isEmpty);
  });

  test('both store_services packages declare the same public API', () {
    Map<String, Set<String>> surface(String pkg) => {
      for (final f in Directory('packages/$pkg/lib').listSync(recursive: true))
        if (f is File && f.path.endsWith('.dart'))
          f.path.substring('packages/$pkg/lib/'.length): _publicDeclarations(
            f.readAsStringSync(),
          ),
    };

    final real = surface('store_services');
    final foss = surface('store_services_foss');
    expect(real.keys.toSet(), foss.keys.toSet(), reason: 'same file layout');
    // Guard against a parser that sees nothing and so compares two empties.
    expect(
      real.values.expand((names) => names),
      containsAll([
        'runWithCrashReporting',
        'GoogleSignInClient.signIn',
        'StoreBilling.isAvailable',
        'StoreBilling.purchaseStream',
        'StorePurchase()',
        'StorePurchase.storeKit1OriginalTransactionId',
        'StorePurchaseStatus.canceled',
      ]),
    );
    for (final file in real.keys) {
      expect(
        foss[file],
        real[file],
        reason:
            '$file: the FOSS twin must declare exactly what the real package '
            'does, or the F-Droid build stops compiling.',
      );
    }
  });

  test('the FOSS overrides repeat every pubspec.yaml dependency_override', () {
    final ours = _section(
      File('pubspec.yaml').readAsStringSync(),
      'dependency_overrides',
    );
    final foss = _section(
      File('tools/foss/pubspec_overrides.yaml').readAsStringSync(),
      'dependency_overrides',
    );
    expect(ours, isNotEmpty, reason: 'failed to parse pubspec.yaml');
    expect(foss['store_services'], 'path: packages/store_services_foss');
    for (final MapEntry(:key, :value) in ours.entries) {
      expect(
        foss[key],
        value,
        reason:
            'pubspec_overrides.yaml replaces pubspec.yaml\'s '
            'dependency_overrides, so `$key` must be copied into '
            'tools/foss/pubspec_overrides.yaml verbatim.',
      );
    }
  });

  test('tools/foss/pubspec.lock is pubspec.lock minus the store SDKs', () {
    const fix =
        'Run tools/prepare_foss.sh --update-lock and commit '
        'tools/foss/pubspec.lock (docs/fdroid.md).';
    final store = _lockEntries(File('pubspec.lock').readAsStringSync());
    final foss = _lockEntries(
      File('tools/foss/pubspec.lock').readAsStringSync(),
    );
    expect(store, isNotEmpty, reason: 'failed to parse pubspec.lock');

    // The FOSS graph: everything the root depends on, with store_services
    // read from its twin, walked through each package's own pubspec.
    final config = File('.dart_tool/package_config.json').readAsStringSync();
    final roots = {
      for (final m in RegExp(
        r'"name":\s*"([^"]+)",\s*"rootUri":\s*"file://([^"]+)"',
      ).allMatches(config))
        m.group(1)!: Uri.decodeFull(m.group(2)!),
      'store_services': 'packages/store_services_foss',
    };
    expect(
      roots.length,
      greaterThan(100),
      reason: 'run `flutter pub get` first',
    );
    final root = File('pubspec.yaml').readAsStringSync();
    final pending = [
      ..._section(root, 'dependencies').keys,
      ..._section(root, 'dev_dependencies').keys,
    ];
    final graph = <String>{};
    while (pending.isNotEmpty) {
      final name = pending.removeLast();
      if (!graph.add(name)) continue;
      final dir = roots[name];
      expect(dir, isNotNull, reason: '$name: run `flutter pub get` first');
      final pubspec = File('$dir/pubspec.yaml').readAsStringSync();
      pending.addAll(_section(pubspec, 'dependencies').keys);
    }

    expect(
      graph.where((name) => !foss.containsKey(name)),
      isEmpty,
      reason: 'The FOSS graph needs these, and the FOSS lock lacks them. $fix',
    );
    expect(
      foss.keys.where((name) => !graph.contains(name)),
      isEmpty,
      reason: 'The FOSS lock holds these, and nothing needs them. $fix',
    );
    expect(
      foss['store_services'],
      contains('path: "packages/store_services_foss"'),
      reason: 'store_services must point at its FOSS twin. $fix',
    );
    for (final MapEntry(:key, :value) in foss.entries) {
      if (key == 'store_services') continue;
      expect(
        value,
        store[key],
        reason: '$key is locked differently from pubspec.lock. $fix',
      );
    }
  });

  // ML Kit (receipt OCR, docs/receipt-ocr.md) is a Gradle artifact, not a
  // pub package, so the import and lockfile checks above can't see it.
  group('ML Kit stays in the store package\'s Android plugin', () {
    test('no other Gradle file names it', () {
      final offenders = <String>[];
      for (final dir in ['android', 'packages']) {
        for (final f in Directory(dir).listSync(recursive: true)) {
          if (f is! File) continue;
          final name = f.uri.pathSegments.last;
          if (!name.startsWith('build.gradle')) continue;
          if (f.path.startsWith('packages/store_services/android/')) continue;
          if (f.readAsStringSync().contains('com.google.mlkit')) {
            offenders.add(f.path);
          }
        }
      }
      expect(offenders, isEmpty);
      expect(
        File('packages/store_services/android/build.gradle').readAsStringSync(),
        contains('com.google.mlkit'),
        reason: 'the one place it belongs',
      );
    });

    test('the FOSS twin has no Android plugin', () {
      expect(
        Directory('packages/store_services_foss/android').existsSync(),
        isFalse,
      );
      expect(
        File('packages/store_services_foss/pubspec.yaml').readAsStringSync(),
        isNot(contains('plugin:')),
      );
    });

    test('prepare_foss.sh deletes it before F-Droid\'s scan, and its '
        'snapshot brings it back', () {
      final script = File('tools/prepare_foss.sh').readAsStringSync();
      expect(script, contains('rm -rf packages/store_services/android'));
      expect(
        RegExp(
          r'store_files\(\)[\s\S]*?packages/store_services/android',
        ).hasMatch(script),
        isTrue,
        reason: 'the --restore snapshot must carry the deleted folder',
      );
    });
  });
}

/// The children of a top-level YAML mapping [key], each mapped to its body
/// with comments, blank lines and indentation dropped — enough to compare two
/// dependency blocks without a YAML parser.
Map<String, String> _section(String yaml, String key) {
  final out = <String, String>{};
  String? current;
  var inSection = false;
  for (final raw in yaml.split('\n')) {
    // trimRight: a dependency's pubspec may end its lines in `\r`.
    final line = raw.replaceFirst(RegExp(r'\s+#.*$'), '').trimRight();
    if (line.trim().isEmpty || line.trimLeft().startsWith('#')) continue;
    if (!line.startsWith(' ')) {
      inSection = line == '$key:';
      current = null;
      continue;
    }
    if (!inSection) continue;
    final child = RegExp(r'^  (\w+):\s*(.*)$').firstMatch(line);
    if (child != null) {
      current = child.group(1);
      out[current!] = child.group(2)!;
    } else if (current != null) {
      final body = out[current]!;
      out[current] = [if (body.isNotEmpty) body, line.trim()].join(' ');
    }
  }
  return out;
}

/// Each package in a pubspec.lock, mapped to its entry without the
/// `dependency:` line — dropping the store SDKs legitimately turns some
/// `direct` entries `transitive`.
Map<String, String> _lockEntries(String lock) {
  final out = <String, String>{};
  String? name;
  var inPackages = false;
  for (final raw in lock.split('\n')) {
    final line = raw.trimRight();
    if (!line.startsWith(' ')) {
      inPackages = line == 'packages:';
      name = null;
      continue;
    }
    if (!inPackages) continue;
    final entry = RegExp(r'^  (\w+):$').firstMatch(line);
    if (entry != null) {
      name = entry.group(1);
      out[name!] = '';
    } else if (name != null && !line.trimLeft().startsWith('dependency:')) {
      out[name] = '${out[name]}${line.trim()}\n';
    }
  }
  return out;
}

String? _topLevel(String yaml, String key) =>
    RegExp('^$key:\\s*(\\S+)', multiLine: true).firstMatch(yaml)?.group(1);

/// Top-level classes, enums and functions, plus each class's public members
/// and constructors as `Type.member` / `Type.named()` — read off the lines at
/// class-body indent, so locals and private members never count.
Set<String> _publicDeclarations(String source) {
  final names = <String>{};
  String? type;
  for (final line in source.split('\n')) {
    final decl = RegExp(
      r'^(?:abstract |final )?(class|enum)\s+([A-Z]\w*)',
    ).firstMatch(line);
    if (decl != null) {
      type = decl.group(2);
      names.add(type!);
      // A one-line enum: its values are API too.
      final values = RegExp(r'\{(.*)\}').firstMatch(line)?.group(1);
      if (decl.group(1) == 'enum' && values != null) {
        for (final v in values.split(',')) {
          if (v.trim().isNotEmpty) names.add('$type.${v.trim()}');
        }
      }
      continue;
    }
    final topFn = RegExp(
      r'^[A-Za-z][\w<>?, ]*\s+([a-z]\w*)\s*\(',
    ).firstMatch(line);
    if (topFn != null) {
      type = null;
      names.add(topFn.group(1)!);
      continue;
    }
    if (line.startsWith('}')) type = null;
    if (type == null) continue;

    // A member starts at exactly two spaces; skip annotations and comments.
    final body = RegExp(r'^  ([A-Za-z].*)$').firstMatch(line)?.group(1);
    if (body == null) continue;
    final cut = RegExp('[(=;]').firstMatch(body);
    if (cut == null) continue;
    final ident = RegExp(
      r'([\w.]+)\s*$',
    ).firstMatch(body.substring(0, cut.start))?.group(1);
    if (ident == null) continue;
    final parts = ident.split('.');
    if (parts.first == type) {
      final named = parts.length > 1 ? parts.last : '';
      if (named.isEmpty) {
        names.add('$type()');
      } else if (!named.startsWith('_')) {
        names.add('$type.$named()');
      }
    } else if (!parts.last.startsWith('_')) {
      names.add('$type.${parts.last}');
    }
  }
  return names;
}
