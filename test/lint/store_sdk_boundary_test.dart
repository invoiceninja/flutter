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
///    the FOSS build would silently lose an upstream workaround.
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
}

/// The children of a top-level YAML mapping [key], each mapped to its body
/// with comments, blank lines and indentation dropped — enough to compare two
/// dependency blocks without a YAML parser.
Map<String, String> _section(String yaml, String key) {
  final out = <String, String>{};
  String? current;
  var inSection = false;
  for (final raw in yaml.split('\n')) {
    final line = raw.replaceFirst(RegExp(r'\s+#.*$'), '');
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
