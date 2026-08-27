import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The data layer must not depend on the UI layer — transitively.
///
/// `ARCHITECTURE.md` describes View → ViewModel → Repository → Drift, but for a
/// long time the compiler saw one blob: 917 of 1,602 files in `lib/` (57%) sat
/// in a single strongly-connected import component, and every `lib/data/` file
/// was inside it. Opening `client_repository.dart` pulled in 1,395 files, 929 of
/// them UI. The whole cycle came from six imports — `lib/data/**` reaching into
/// `lib/domain/columns/<entity>_columns.dart` for `static const String` id
/// constants, in files that also build Widgets and import `app/router.dart`.
///
/// The constants now live in `lib/domain/columns/ids/`, which imports nothing.
/// This test is what stops the edge growing back. It is worth having as a test
/// rather than a convention because the regression is invisible everywhere else:
/// adding `import 'package:admin/domain/columns/client_columns.dart';` to a DAO
/// analyzes clean, builds clean, and passes every other test — it just silently
/// re-attaches the entire UI graph to every data-layer compile.
void main() {
  final graph = _importGraph();

  test('lib/data does not transitively import lib/ui', () {
    final violations = <String>[];
    for (final file in graph.keys.where((f) => f.startsWith('lib/data/'))) {
      final path = _shortestPath(graph, file, (f) => f.startsWith('lib/ui/'));
      if (path != null) violations.add(path.join('\n     -> '));
    }
    expect(
      violations,
      isEmpty,
      reason:
          'A data-layer file reaches lib/ui. Shortest path(s):\n\n'
          '  ${violations.take(5).join("\n\n  ")}\n\n'
          'Move whatever it needs into a leaf (see lib/domain/columns/ids/).',
    );
  });

  test('lib/data does not import the Widget-bearing column registries', () {
    // `lib/domain/columns/*_columns.dart` declare `ColumnDefinition`s whose
    // `cellBuilder` returns Widgets; `lib/domain/columns/ids/` is the leaf half
    // the data layer is allowed to see.
    bool isRegistry(String f) =>
        f.startsWith('lib/domain/columns/') &&
        !f.startsWith('lib/domain/columns/ids/') &&
        f.endsWith('_columns.dart');

    final violations = <String>[];
    for (final file in graph.keys.where((f) => f.startsWith('lib/data/'))) {
      final path = _shortestPath(graph, file, isRegistry);
      if (path != null) violations.add(path.join('\n     -> '));
    }
    expect(
      violations,
      isEmpty,
      reason:
          'A data-layer file reaches a column registry. Import the matching '
          'lib/domain/columns/ids/<entity>_column_ids.dart leaf instead.\n\n'
          '  ${violations.take(5).join("\n\n  ")}',
    );
  });

  test('lib/domain/columns/ids/ files import nothing', () {
    final dir = Directory('lib/domain/columns/ids');
    expect(dir.existsSync(), isTrue, reason: '$dir should exist');
    final leaves = dir.listSync().whereType<File>().where(
      (f) => f.path.endsWith('.dart'),
    );
    expect(leaves, isNotEmpty);
    for (final leaf in leaves) {
      final offending = leaf
          .readAsLinesSync()
          .where((l) => l.startsWith('import ') || l.startsWith('export '))
          .toList();
      expect(
        offending,
        isEmpty,
        reason:
            '${leaf.path} must stay a leaf — that is the entire point of the '
            'file. Anything it imports is re-attached to every data-layer '
            'compile. Found: $offending',
      );
    }
  });
}

/// `package:admin/…` + relative import/export edges for every `.dart` under
/// `lib/`, keyed by repo-relative path. Conditional-import targets
/// (`if (dart.library.io) '…'`) are included — they are real edges.
Map<String, Set<String>> _importGraph() {
  final files = <String, String>{};
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      files[entity.path] = entity.readAsStringSync();
    }
  }
  final packageRef = RegExp(
    '''^\\s*(?:import|export)\\s+['"]package:admin/([^'"]+)['"]''',
    multiLine: true,
  );
  final anyRef = RegExp(
    '''['"]((?!package:|dart:)[^'"]+\\.dart)['"]''',
    multiLine: true,
  );
  final graph = <String, Set<String>>{};
  for (final entry in files.entries) {
    final deps = <String>{};
    for (final m in packageRef.allMatches(entry.value)) {
      deps.add('lib/${m.group(1)}');
    }
    // Relative targets, including the `if (dart.library.io) '…'` seams.
    final dir = File(entry.key).parent.path;
    for (final m in anyRef.allMatches(entry.value)) {
      deps.add(_normalize('$dir/${m.group(1)}'));
    }
    graph[entry.key] = deps.where(files.containsKey).toSet();
  }
  return graph;
}

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

/// Breadth-first, so a failure names the *shortest* route to the violation —
/// which is almost always the one import that should be repointed.
List<String>? _shortestPath(
  Map<String, Set<String>> graph,
  String from,
  bool Function(String) isTarget,
) {
  final queue = <List<String>>[
    [from],
  ];
  final seen = <String>{from};
  while (queue.isNotEmpty) {
    final path = queue.removeAt(0);
    final current = path.last;
    if (path.length > 1 && isTarget(current)) return path;
    for (final dep in graph[current] ?? const <String>{}) {
      if (seen.add(dep)) queue.add([...path, dep]);
    }
  }
  return null;
}
