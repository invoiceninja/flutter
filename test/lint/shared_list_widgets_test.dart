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

  /// Every scan below must actually find files; otherwise a directory move or
  /// a renamed suffix turns the lint into `expect([], isEmpty)` — green, and
  /// guarding nothing.
  void expectScanned(int n, String what) => expect(
    n,
    greaterThan(5),
    reason: 'only $n $what found — the glob is no longer matching',
  );

  test('no empty state re-implements the archived/deleted predicate', () {
    // The tell is the predicate, not the widget: a screen may legitimately
    // wrap EntityListEmptyState, but re-deriving `onlyArchived` from the VM
    // means it has copied the whole thing again.
    final offenders = <String>[];
    var scanned = 0;
    for (final f
        in Directory('lib/ui/features')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('_list_empty_state.dart'))) {
      scanned++;
      final src = f.readAsStringSync();
      if (src.contains('EntityState.archived') &&
          src.contains('vm.customFilters.isEmpty')) {
        offenders.add(f.uri.pathSegments.last);
      }
    }
    expectScanned(scanned, 'empty states');
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
    var scanned = 0;
    for (final f
        in Directory('lib/ui/features')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('_kpi_strip.dart'))) {
      scanned++;
      final src = f.readAsStringSync();
      final declaresCell =
          src.contains('class _KpiCell ') || src.contains('class _Cell ');
      if (declaresCell && src.contains('final Widget value;')) {
        offenders.add(f.uri.pathSegments.last);
      }
    }
    expectScanned(scanned, 'KPI strips');
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
    var scanned = 0;
    for (final f
        in Directory('lib/ui/features')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('_token_search_field.dart'))) {
      scanned++;
      final src = f.readAsStringSync();
      if (src.contains('List<FilterKey>? _keys')) {
        offenders.add(f.uri.pathSegments.last);
      }
    }
    expectScanned(scanned, 'token search fields');
    expect(
      offenders,
      isEmpty,
      reason:
          'use EntityTokenSearchField from '
          'lib/ui/core/list/search/entity_token_search_field.dart:\n'
          '  ${offenders.join('\n  ')}',
    );
  });

  test('a VM-only filter flag still reaches the shared empty state', () {
    // `EntityListEmptyState` reads narrowing state off `GenericListViewModel`.
    // Payments' unapplied-funds toggle is the one filter that bypasses it — a
    // bare bool on the VM that still reaches the Drift query — so it has to be
    // threaded in three places. Sharing the widget dropped all of them at once
    // (the flag appeared four times in the hand-written copy and zero times
    // after), and nothing noticed, because nothing currently sets the flag: the
    // breakage is dormant until the "Has unapplied funds" chip is wired up.
    final vm = File(
      'lib/ui/features/payments/view_models/payment_list_view_model.dart',
    ).readAsStringSync();
    final emptyState = File(
      'lib/ui/features/payments/widgets/payment_list_empty_state.dart',
    ).readAsStringSync();
    if (!vm.contains('hasUnappliedFundsOnly')) return; // flag retired: fine

    expect(
      vm.contains('bool get hasActiveFilters'),
      isTrue,
      reason:
          'PaymentListViewModel must fold hasUnappliedFundsOnly into '
          'hasActiveFilters, or the first-run "No payments yet" copy shows '
          'over a filtered empty list',
    );
    expect(
      vm.contains('Future<void> clearAllFilters()'),
      isTrue,
      reason:
          'PaymentListViewModel must clear hasUnappliedFundsOnly in '
          'clearAllFilters, or the Clear-filters button leaves the list '
          'empty with no way back',
    );
    expect(
      emptyState.contains('extraNarrowing: vm.hasUnappliedFundsOnly'),
      isTrue,
      reason:
          'PaymentListEmptyState must pass extraNarrowing, or the archived / '
          'deleted branches claim "No archived payments" when the real reason '
          'is the unapplied filter',
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
