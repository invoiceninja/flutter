import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The per-entity list widgets that collapsed into shared ones must stay
/// collapsed.
///
/// Each of these shipped as one hand-copied class per entity, and each drifted
/// while nothing compared them — `_CellSlot` diverged in brace style across
/// seventeen files, and the empty states in whether they had been kept in step
/// with the localization bundle at all. Only three test files in the repo
/// referenced any of them, so the divergence was invisible.
void main() {
  final tiles = Directory('lib/ui/features')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('_list_tile.dart'))
      .toList();

  test('no list tile re-declares a private cell-slot widget', () {
    expect(tiles, isNotEmpty, reason: 'no list tiles found — check the glob');
    final offenders = [
      for (final f in tiles)
        if (f.readAsStringSync().contains('class _CellSlot'))
          f.uri.pathSegments.last,
    ];
    expect(
      offenders,
      isEmpty,
      reason:
          'use CellSlot<T> from lib/ui/core/list/cell_slot.dart — a private '
          'copy renders identically and diverges silently:\n'
          '  ${offenders.join('\n  ')}',
    );
  });

  test('no empty state re-implements the archived/deleted predicate', () {
    // The tell is the predicate, not the widget: a screen may legitimately
    // wrap EntityListEmptyState, but re-deriving `onlyArchived` from the VM
    // means it has copied the whole thing again.
    final offenders = <String>[];
    for (final f
        in Directory('lib/ui/features')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('_list_empty_state.dart'))) {
      final src = f.readAsStringSync();
      if (src.contains('EntityState.archived') &&
          src.contains('vm.customFilters.isEmpty')) {
        offenders.add(f.uri.pathSegments.last);
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'use EntityListEmptyState from '
          'lib/ui/core/list/entity_list_empty_state.dart:\n'
          '  ${offenders.join('\n  ')}',
    );
  });

  test('no detail KPI strip re-declares the pre-built-Widget cell', () {
    // Scoped to the `Widget value` variant. CLAUDE.md documents three variants
    // and only this one is shared — Client's takes a Decimal + Formatter and
    // Projects' a String with a '—' sentinel, and those must stay separate.
    final offenders = <String>[];
    for (final f
        in Directory('lib/ui/features')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('_kpi_strip.dart'))) {
      final src = f.readAsStringSync();
      final declaresCell =
          src.contains('class _KpiCell ') || src.contains('class _Cell ');
      if (declaresCell && src.contains('final Widget value;')) {
        offenders.add(f.uri.pathSegments.last);
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'use KpiCell from lib/ui/core/detail/kpi_cell.dart:\n'
          '  ${offenders.join('\n  ')}',
    );
  });

  test('no token search field re-implements the key cache', () {
    // The cache is the whole point: TagFilterKey opens a Drift subscription in
    // its constructor, so rebuilding the key list on every stream re-emit
    // leaks one live query per rebuild. Thirteen hand-written copies had
    // already drifted into two different caching implementations.
    //
    // The three fields whose keys need no streams (gateways, expense
    // categories, payment links) are plain StatelessWidgets with no cache, so
    // the tell is the cache field, not the widget kind.
    final offenders = <String>[];
    for (final f
        in Directory('lib/ui/features')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('_token_search_field.dart'))) {
      final src = f.readAsStringSync();
      if (src.contains('List<FilterKey>? _keys')) {
        offenders.add(f.uri.pathSegments.last);
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'use EntityTokenSearchField from '
          'lib/ui/core/list/search/entity_token_search_field.dart:\n'
          '  ${offenders.join('\n  ')}',
    );
  });

  test('the shared widgets these replaced still exist', () {
    // Guards the lints above from passing vacuously after a rename or move.
    for (final path in const [
      'lib/ui/core/list/cell_slot.dart',
      'lib/ui/core/list/entity_list_empty_state.dart',
      'lib/ui/core/detail/kpi_cell.dart',
      'lib/ui/core/list/search/entity_token_search_field.dart',
    ]) {
      expect(File(path).existsSync(), isTrue, reason: '$path is gone');
    }
  });
}
