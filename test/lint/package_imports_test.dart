import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// CI lint: enforce CLAUDE.md's "always `package:admin/...`, never relative"
/// rule — the part of it `always_use_package_imports` never actually covered.
///
/// The analyzer rule is named in CLAUDE.md as the enforcer, but it has two
/// guards that between them let every real violation through:
///
///  1. it only visits files **inside `lib/`**, and
///  2. it registers **`visitImportDirective` only** — an `export` is invisible.
///
/// Both halves are measured, not assumed. A relative `import` planted in
/// `lib/l10n/supported_locales.dart` is reported ("Use 'package:' imports for
/// files in the 'lib' directory"); the six relative `export`s that had
/// accumulated in `lib/` were not, and `dart analyze` stayed clean the whole
/// time. Four of those six were the conditional platform seams
/// (`export 'x_web.dart' if (dart.library.io) 'x_io.dart';`) — doubly hidden,
/// because the second URI sits on a continuation line where a line-oriented
/// grep does not look either.
///
/// The second test is the other half of the rule, and it is the one that keeps
/// the first half honest. A `package:` URI resolves **only** into `lib/`, so a
/// test importing a test helper (`test/_localization_helper.dart` and friends)
/// has no package form available and must stay relative — that is not a
/// violation and must never be "fixed". What is banned outside `lib/` is a
/// relative path that reaches *into* `lib/`, because that is app code, and app
/// code always has a package URI.
void main() {
  test('every import/export in lib/ uses a package: or dart: URI', () {
    final offenders = <String>[];
    var filesWalked = 0;
    var directivesMatched = 0;

    for (final file in _dartFiles([Directory('lib')], skipGenerated: true)) {
      filesWalked++;
      final source = file.readAsStringSync();
      for (final directive in _directive.allMatches(source)) {
        directivesMatched++;
        final text = directive.group(0)!;
        for (final uri in _uri.allMatches(text)) {
          final value = uri.group(1)!;
          if (value.startsWith('package:') || value.startsWith('dart:')) {
            continue;
          }
          final line = '\n'.allMatches(source.substring(0, directive.start));
          offenders.add(
            '${file.path}:${line.length + 1}  '
            '${text.split(RegExp(r'\s+')).join(' ')}',
          );
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'CLAUDE.md § Strict rules: inside lib/ every import AND export is '
          '`package:admin/...`. Both branches of a conditional seam count — '
          "`export 'package:admin/a_web.dart' if (dart.library.io) "
          "'package:admin/a_io.dart';`. Found:\n  ${offenders.join('\n  ')}",
    );
    _expectNotBlind(filesWalked, directivesMatched, 'lib/');
  });

  test('nothing outside lib/ reaches into lib/ with a relative path', () {
    final offenders = <String>[];
    var filesWalked = 0;
    var directivesMatched = 0;

    final roots = _rootsOutsideLib
        .map(Directory.new)
        .where((d) => d.existsSync());
    for (final file in _dartFiles(roots, skipGenerated: false)) {
      filesWalked++;
      final source = file.readAsStringSync();
      for (final directive in _directive.allMatches(source)) {
        directivesMatched++;
        for (final uri in _uri.allMatches(directive.group(0)!)) {
          final value = uri.group(1)!;
          if (value.startsWith('package:') || value.startsWith('dart:')) {
            continue;
          }
          final target = _normalize('${file.parent.path}/$value');
          if (target.startsWith('lib/')) {
            offenders.add('${file.path}  ->  $value  (= $target)');
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'A file outside lib/ reached app code by relative path. App code '
          'always has a package URI — use `package:admin/...`. (Importing a '
          'test helper relatively is fine and expected: `package:` resolves '
          'only into lib/, so test/ helpers have no package form.) Found:\n'
          '  ${offenders.join('\n  ')}',
    );
    _expectNotBlind(
      filesWalked,
      directivesMatched,
      _rootsOutsideLib.join(', '),
    );
  });
}

/// Every root-package directory outside `lib/` that holds `.dart` files.
///
/// `test_driver/` is the one most likely to regress — relatively importing the
/// integration-test entrypoint from its driver is the standard Flutter idiom.
/// Two traps for whoever extends this list: `tool/` (singular) also exists but
/// holds only `totals_oracle.php`, and `tools/transifex_importer/` is a
/// *separate package*, excluded by [_inNestedPackage] rather than by name.
const _rootsOutsideLib = <String>[
  'test',
  'integration_test',
  'test_driver',
  'tools',
  'web',
];

/// A whole `import` / `export` directive, keyword through `;`.
///
/// Matching the directive rather than the line is the point: it is what reaches
/// the `if (dart.library.io) '…'` URI on a conditional seam's second line.
///
/// `\b` rather than `\s`, because `import'foo.dart';` with no space is legal
/// Dart and `\s` misses it. The boundary still rejects identifiers, which
/// continue a word character (`importFoo(`, `exports;`).
///
/// `part` is deliberately not matched — the codegen `part 'x.freezed.dart';`
/// directives are *required* to be relative and must never be flagged.
final RegExp _directive = RegExp(
  r'^[ \t]*(?:import|export)\b[^;]*;',
  multiLine: true,
);

/// Every quoted URI inside a directive — a conditional seam has two.
final RegExp _uri = RegExp('''['"]([^'"]*)['"]''');

/// Fails when a scan silently stopped seeing anything.
///
/// This is the failure mode the whole file exists to document, so it would be
/// absurd to be vulnerable to it: a broken walk or a broken [_directive] makes
/// `offenders` empty and the test green while checking nothing at all. Several
/// sibling lint tests carry the same counter — see
/// `field_input_types_test.dart` and `no_can_launch_url_test.dart`. The floors
/// are deliberately far below the real numbers (lib/ alone walks ~1,540 files
/// and ~12,300 directives) so ordinary growth never has to touch them.
void _expectNotBlind(int files, int directives, String where) {
  expect(
    files,
    greaterThan(200),
    reason:
        'Only $files .dart files walked under $where — the walk is probably '
        'broken, so a relative import could pass unseen.',
  );
  expect(
    directives,
    greaterThan(1000),
    reason:
        'Only $directives import/export directives matched under $where — '
        '`_directive` is probably broken, so a relative import could pass '
        'unseen.',
  );
}

Iterable<File> _dartFiles(
  Iterable<Directory> dirs, {
  required bool skipGenerated,
}) sync* {
  const generated = ['.g.dart', '.freezed.dart', '.drift.dart', '.gr.dart'];
  for (final dir in dirs) {
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      // `skipGenerated` mirrors `analysis_options.yaml`'s `exclude:` for the
      // lib/ scan. The scan outside lib/ deliberately passes `false`: it wants
      // `test/generated/**` (drift's schema snapshots, also excluded from
      // analysis) included, because a generated file reaching into lib/ would
      // be just as wrong — it simply never does, since its imports resolve
      // inside `test/generated/`.
      if (skipGenerated && generated.any(entity.path.endsWith)) continue;
      if (_inNestedPackage(entity)) continue;
      yield entity;
    }
  }
}

/// Whether [file] belongs to a package nested inside this repo rather than to
/// `admin` itself — i.e. some ancestor below the repo root has its own
/// `pubspec.yaml`. Such a file's relative imports are correct, and its paths
/// can never resolve into our `lib/`. `tools/transifex_importer/` is the live
/// example; detecting it structurally means a second nested package needs no
/// edit here.
bool _inNestedPackage(File file) {
  var dir = file.parent;
  while (dir.path.contains('/')) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) return true;
    dir = dir.parent;
  }
  // Stop at the top-level directory — the repo root's own pubspec.yaml is
  // `admin`'s, and matching it would exclude everything.
  return File('${dir.path}/pubspec.yaml').existsSync();
}

/// Collapses `.` / `..` segments so a relative URI can be compared against
/// `lib/`. Same shape as `layering_test.dart`'s copy.
String _normalize(String path) {
  final out = <String>[];
  for (final part in path.split('/')) {
    if (part == '.' || part.isEmpty) continue;
    if (part == '..') {
      if (out.isNotEmpty) out.removeLast();
    } else {
      out.add(part);
    }
  }
  return out.join('/');
}
