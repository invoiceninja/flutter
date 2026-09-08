import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every `MutationKind` a repository can enqueue must have somewhere to land.
///
/// `BaseEntitySyncDispatcher.dispatch` looks up `customActions[kind]` and,
/// failing that, falls through its own switch to
///
///     throw StateError('No customActions handler registered for <kind> on <entity>')
///
/// whose comment calls it "a configuration error, not a runtime condition". It
/// is exactly that — but nothing checked for it, so the configuration error was
/// only discoverable by draining the outbox row on a real device.
///
/// That is not hypothetical: a scripted edit deleted four handlers
/// (`autoBill` on Invoice, `cancelEntity` on Quote, `runTemplate` on Credit and
/// Recurring invoice) and the entire suite stayed green, because every test
/// that touches `customActions` exercises an individual handler and none
/// asserts the registration set. The four actions enqueued their outbox row and
/// then dead-lettered on drain.
///
/// Derived, not hardcoded: the kinds each `...someHandlers<…>(` factory
/// contributes are read out of that factory's own source, so adding a factory
/// needs no edit here.
void main() {
  final wiring = File('lib/app/services_entity_wiring.dart').readAsStringSync();
  final wiringLines = wiring.split('\n');

  /// `RecurringInvoiceApi` -> `recurring_invoice`.
  String snake(String pascal) => pascal
      .replaceAllMapped(RegExp('([a-z0-9])([A-Z])'), (m) => '${m[1]}_${m[2]}')
      .toLowerCase();

  /// Kinds the dispatcher's own switch services without throwing. Everything
  /// else in that switch is a bare fall-through into the `StateError`.
  Set<String> dispatcherNativeKinds() {
    final src = File(
      'lib/domain/sync/base_entity_sync_dispatcher.dart',
    ).readAsStringSync();
    final lines = src.split('\n');
    final throwAt = lines.indexWhere((l) => l.contains('throw StateError('));
    expect(
      throwAt,
      isNot(-1),
      reason:
          'the dispatcher no longer throws on an unhandled kind — this '
          'lint reads that throw to know which kinds need a handler',
    );
    final throwing = <String>{};
    for (var i = throwAt - 1; i >= 0; i--) {
      final line = lines[i].trim();
      if (line.startsWith('//')) continue;
      final m = RegExp(r'^case MutationKind\.(\w+):$').firstMatch(line);
      if (m == null) break;
      throwing.add(m.group(1)!);
    }
    final all = RegExp(
      r'case MutationKind\.(\w+):',
    ).allMatches(src).map((m) => m.group(1)!).toSet();
    return all.difference(throwing);
  }

  /// Kinds a `...xHandlers<…>(` factory registers, read from its own source.
  final factoryKinds = <String, Set<String>>{
    for (final f in Directory('lib/app').listSync().whereType<File>().where(
      (f) => f.path.endsWith('handlers.dart'),
    )) ...{
      // Every factory is named `*Handlers`; anchoring on that avoids
      // matching the `Map<` that opens their shared return type.
      for (final fn in RegExp(
        r'\b(\w+Handlers)<',
      ).allMatches(f.readAsStringSync()).map((m) => m.group(1)!))
        fn: RegExp(
          r'MutationKind\.(\w+):',
        ).allMatches(f.readAsStringSync()).map((m) => m.group(1)!).toSet(),
    },
  };

  /// `MixinName` -> that mixin's source, for the mixins a repository can apply.
  final mixinSources = <String, List<String>>{
    for (final f in Directory(
      'lib/data/repositories',
    ).listSync().whereType<File>().where((f) => f.path.endsWith('.dart')))
      for (final m in RegExp(
        r'^mixin (\w+)',
        multiLine: true,
      ).allMatches(f.readAsStringSync()))
        m.group(1)!: [f.readAsStringSync()],
  };

  test('every enqueueable MutationKind has a handler for its entity', () {
    expect(
      mixinSources.keys,
      containsAll(<String>[
        'EntityCommentMutations',
        'BillingDocEmailMutations',
      ]),
      reason:
          'a mutation mixin was renamed — kinds it enqueues would go '
          'unchecked, which is the hole this lint shipped with',
    );
    final native = dispatcherNativeKinds();
    expect(native, contains('create'), reason: 'sanity: switch parse failed');

    // Each `reg.wire<TList, TInner>(` opens one entity's registration; the
    // block runs to the next one.
    final marks = <(int, String)>[];
    for (var i = 0; i < wiringLines.length; i++) {
      final m = RegExp(r'reg\.wire<\w+, (\w+)>\(').firstMatch(wiringLines[i]);
      if (m != null) marks.add((i, m.group(1)!));
    }
    expect(marks, isNotEmpty, reason: 'no reg.wire<> blocks found');

    final failures = <String>[];
    for (var idx = 0; idx < marks.length; idx++) {
      final (start, inner) = marks[idx];
      final end = idx + 1 < marks.length
          ? marks[idx + 1].$1
          : wiringLines.length;
      final block = wiringLines.sublist(start, end).join('\n');

      final entity = inner.replaceAll(RegExp(r'Api$'), '');
      final repoFile = File(
        'lib/data/repositories/${snake(entity)}_repository.dart',
      );
      if (!repoFile.existsSync()) continue;

      // Follow the repo's mixins too. `addComment` lives on
      // `EntityCommentMutations` and `emailEntity` / `scheduleEmail` on
      // `BillingDocEmailMutations`, so reading only the repository file misses
      // three kinds across fifteen repos — verified by mutation: deleting a
      // Quote `emailEntity` handler passed an earlier draft of this lint.
      final repoSrc = repoFile.readAsStringSync();
      final sources = <String>[
        repoSrc,
        for (final mixin
            in RegExp(r'\bwith\s+([A-Za-z0-9_,<>\s]+?)\s*(?:implements|\{)')
                .allMatches(repoSrc)
                .expand((m) => RegExp(r'\b([A-Z]\w+)<').allMatches(m.group(1)!))
                .map((m) => m.group(1)!)
                .toSet())
          ...mixinSources[mixin] ?? const <String>[],
      ];
      final enqueued = <String>{
        for (final src in sources)
          ...RegExp(
            r'kind: MutationKind\.(\w+)',
          ).allMatches(src).map((m) => m.group(1)!),
      };
      if (enqueued.isEmpty) continue;

      final registered = <String>{
        ...RegExp(
          r'MutationKind\.(\w+):',
        ).allMatches(block).map((m) => m.group(1)!),
        // Matches both `...documentMutationHandlers<T>(` spread into a larger
        // map and `customActions: documentMutationHandlers<T>(` used whole.
        for (final factory in RegExp(
          r'\b(\w+Handlers)<',
        ).allMatches(block).map((m) => m.group(1)!))
          ...?factoryKinds[factory],
      };

      final missing = enqueued.difference(registered).difference(native)
        ..removeWhere((k) => false);
      if (missing.isNotEmpty) {
        failures.add(
          '$entity enqueues ${(missing.toList()..sort()).join(', ')} '
          'but registers no handler for it',
        );
      }
    }

    expect(
      failures,
      isEmpty,
      reason:
          'these will throw StateError on drain, after the outbox row has '
          'already been written — the user\'s action silently fails:\n'
          '  ${failures.join('\n  ')}',
    );
  });

  test('the factory sources this lint reads still declare their kinds', () {
    // Guards the lint from passing vacuously: if a factory is renamed or its
    // keys move, `factoryKinds` silently goes empty and every spread stops
    // contributing, which would turn real coverage into false failures — or,
    // if paired with a matching miss, into no signal at all.
    expect(
      factoryKinds.keys,
      containsAll(<String>[
        'documentMutationHandlers',
        'reactivateEmailHandlers',
        'cloneToHandlers',
        'addCommentHandlers',
      ]),
      reason: 'a handler factory was renamed — update this lint',
    );
    expect(factoryKinds['cloneToHandlers'], hasLength(5));
    expect(factoryKinds['addCommentHandlers'], {'addComment'});
    expect(factoryKinds['documentMutationHandlers'], hasLength(3));
  });
}
