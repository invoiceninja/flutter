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

  test('the conditional platform seams contribute both of their edges', () {
    // A seam is `export 'package:admin/x_web.dart' if (dart.library.io)
    // 'package:admin/x_io.dart';` — two edges, and the `_io` one sits on a
    // continuation line. Nothing above would go red if it vanished from the
    // graph: every `_io` file is its own BFS root, so the suite stays green
    // while quietly checking less. That is precisely how an anchored
    // `packageRef` lost these four edges the moment the URIs stopped being
    // relative, so the invariant is asserted rather than assumed.
    const seams = <String, List<String>>{
      'lib/data/db/database_opener.dart': [
        'lib/data/db/database_opener_web.dart',
        'lib/data/db/database_opener_io.dart',
      ],
      'lib/data/services/token_storage_factory.dart': [
        'lib/data/services/token_storage_web_factory.dart',
        'lib/data/services/token_storage_io_factory.dart',
      ],
      'lib/data/services/upload_source_seam.dart': [
        'lib/data/services/upload_source_seam_web.dart',
        'lib/data/services/upload_source_seam_io.dart',
      ],
      'lib/data/services/device_contacts_service_factory.dart': [
        'lib/data/services/device_contacts_service_web.dart',
        'lib/data/services/device_contacts_service_io.dart',
      ],
    };
    for (final seam in seams.entries) {
      expect(
        graph[seam.key],
        containsAll(seam.value),
        reason:
            '${seam.key} lost one of its two seam edges. The `_io` one is the '
            'fragile half: check that `packageRef` in _importGraph is still '
            'unanchored — an anchored pattern cannot see a conditional URI on '
            'a continuation line.',
      );
    }
  });
}

/// `package:admin/…` + relative import/export edges for every `.dart` under
/// `lib/`, keyed by repo-relative path. Conditional-import targets
/// (`if (dart.library.io) '…'`) are included — they are real edges.
///
/// `packageRef` is deliberately *not* anchored to the start of a directive: a
/// conditional seam puts its second URI on a continuation line
/// (`    if (dart.library.io) 'package:admin/…'`), and an anchored pattern
/// cannot see it. That used to be covered by `anyRef` only because those URIs
/// were relative; once they became `package:admin/…` an anchored `packageRef`
/// silently dropped the four `_io` edges.
///
/// Scanning the whole file is not a new liberty — `anyRef` below has always
/// done it, and already matches `.dart` paths written inside comments. What
/// keeps both honest is `deps.where(files.containsKey)`: a match only becomes
/// an edge if it names a file that actually exists under `lib/`. The residual
/// hole is therefore a quoted string naming a *real* lib path — an `assert`
/// reason, an error message, a doc comment using `'…'` where it should use
/// backticks. One of those would become a genuine phantom edge and could flip
/// the transitive assertions red along a nonsensical path, so write lib paths
/// in prose with backticks.
Map<String, Set<String>> _importGraph() {
  final files = <String, String>{};
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      files[entity.path] = entity.readAsStringSync();
    }
  }
  final packageRef = RegExp(
    '''['"]package:admin/([^'"]+)['"]''',
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
