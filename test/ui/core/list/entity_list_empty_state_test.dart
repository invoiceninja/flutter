import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/ui/core/list/entity_list_empty_state.dart';
import 'package:admin/ui/core/list/generic_list_view_model.dart';

import '../../../_localization_helper.dart';

/// Behavioural coverage for the empty state now shared by fifteen entity
/// lists.
///
/// It had none. Before it was shared there were thirteen hand-written copies
/// and three test files in the whole repo referenced any of them, which is how
/// they drifted; the copies are gone now, so one test here protects every
/// list. That is the payoff of sharing, and it goes unclaimed unless someone
/// writes this.
///
/// The [EntityListEmptyState.extraNarrowing] case is not hypothetical: sharing
/// this widget silently dropped Payments' unapplied-funds term from three
/// branches and its reset from the Clear button, because that flag is filter
/// state the base ViewModel cannot see.
class _FakeVm implements GenericListViewModel<dynamic> {
  _FakeVm({
    this.states = const {EntityState.active},
    this.search = '',
    this.customFilters = const {},
    this.extraFilters = const {},
    this.hasEntityStates = true,
  });

  @override
  final bool hasEntityStates;
  @override
  final Set<EntityState> states;
  @override
  final String search;
  @override
  final Map<int, Set<String>> customFilters;
  @override
  final Map<String, Set<String>> extraFilters;

  var cleared = false;
  Set<EntityState>? statesSet;
  var badgeModeCleared = false;

  @override
  String? get activeBadgeModeId {
    final values = extraFilters['badge_mode'];
    return (values == null || values.isEmpty) ? null : values.first;
  }

  @override
  Future<void> setBadgeMode(String? modeId) async {
    if (modeId == null) badgeModeCleared = true;
  }

  @override
  Future<void> setStates(Set<EntityState> next) async => statesSet = next;

  /// Mirrors the base implementation closely enough for this widget:
  /// `{active}` is "no state filter". (`{}` used to be folded in with it;
  /// since #126 the real VM can't produce an empty set, and the base no
  /// longer special-cases one — see `GenericListViewModel.hasActiveFilters`.)
  @override
  bool get hasActiveFilters {
    if (states.isNotEmpty &&
        (states.length != 1 || !states.contains(EntityState.active))) {
      return true;
    }
    if (customFilters.values.any((v) => v.isNotEmpty)) return true;
    if (extraFilters.values.any((v) => v.isNotEmpty)) return true;
    return search.isNotEmpty;
  }

  @override
  Future<void> clearAllFilters() async => cleared = true;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected VM call: ${invocation.memberName}');
}

void main() {
  Future<void> pump(
    WidgetTester tester,
    _FakeVm vm, {
    bool extraNarrowing = false,
    Widget? emptyAction,
    Widget? emptyOverride,
  }) => tester.pumpWidget(
    MaterialApp(
      // EmptyState's subtitle reads `context.inTheme.ink3`.
      theme: buildInTheme(InTheme.light),
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: kTestSupportedLocales,
      home: Scaffold(
        body: EntityListEmptyState(
          vm: vm,
          extraNarrowing: extraNarrowing,
          icon: Icons.receipt_long_outlined,
          emptyTitle: 'FIRST RUN',
          emptySubtitle: 'SUBTITLE',
          emptyAction: emptyAction,
          emptyOverride: emptyOverride,
          archivedTitle: 'NO ARCHIVED',
          deletedTitle: 'NO DELETED',
          noMatchTitle: 'NO MATCHES',
        ),
      ),
    ),
  );

  testWidgets('no filters → the first-run copy, with its subtitle', (
    tester,
  ) async {
    await pump(tester, _FakeVm());
    expect(find.text('FIRST RUN'), findsOneWidget);
    expect(find.text('SUBTITLE'), findsOneWidget);
    expect(find.byIcon(Icons.receipt_long_outlined), findsOneWidget);
  });

  testWidgets('the archived tab alone → the archived copy', (tester) async {
    await pump(tester, _FakeVm(states: const {EntityState.archived}));
    expect(find.text('NO ARCHIVED'), findsOneWidget);
    expect(find.byIcon(Icons.archive_outlined), findsOneWidget);
  });

  testWidgets('the deleted tab alone → the deleted copy', (tester) async {
    await pump(tester, _FakeVm(states: const {EntityState.deleted}));
    expect(find.text('NO DELETED'), findsOneWidget);
  });

  testWidgets('a search on top of the archived tab → no-match, not archived', (
    tester,
  ) async {
    // The archived/deleted copy may only claim "nothing archived" when the
    // lifecycle state is the ONLY thing narrowing — otherwise it hides the
    // real reason the list is empty.
    await pump(
      tester,
      _FakeVm(states: const {EntityState.archived}, search: 'acme'),
    );
    expect(find.text('NO MATCHES'), findsOneWidget);
    expect(find.text('NO ARCHIVED'), findsNothing);
  });

  testWidgets('a custom-field filter on the archived tab → no-match', (
    tester,
  ) async {
    // Each term of the predicate needs its own case: dropping the
    // `customFilters` check alone still passed a search-only test.
    await pump(
      tester,
      _FakeVm(
        states: const {EntityState.archived},
        customFilters: const {
          1: {'north'},
        },
      ),
    );
    expect(find.text('NO MATCHES'), findsOneWidget);
    expect(find.text('NO ARCHIVED'), findsNothing);
  });

  testWidgets('a status-tab filter on the deleted tab → no-match', (
    tester,
  ) async {
    await pump(
      tester,
      _FakeVm(
        states: const {EntityState.deleted},
        extraFilters: const {
          'badge_mode': {'overdue'},
        },
      ),
    );
    expect(find.text('NO MATCHES'), findsOneWidget);
    expect(find.text('NO DELETED'), findsNothing);
  });

  testWidgets('the no-match branch offers a working Clear filters button', (
    tester,
  ) async {
    final vm = _FakeVm(search: 'acme');
    await pump(tester, vm);
    expect(find.text('NO MATCHES'), findsOneWidget);
    await tester.tap(find.text('Clear Filters'));
    expect(vm.cleared, isTrue);
  });

  group('the no-match branch offers the narrowing it can undo', () {
    testWidgets('Show archived adds archived and keeps the search', (
      tester,
    ) async {
      final vm = _FakeVm(search: 'acme');
      await pump(tester, vm);
      await tester.tap(find.text('Show archived'));
      expect(vm.statesSet, {EntityState.active, EntityState.archived});
      expect(vm.cleared, isFalse);
    });

    testWidgets('Show archived is not offered once archived is shown', (
      tester,
    ) async {
      await pump(
        tester,
        _FakeVm(
          states: const {EntityState.active, EntityState.archived},
          search: 'acme',
        ),
      );
      expect(find.text('Show archived'), findsNothing);
      expect(find.text('Clear Filters'), findsOneWidget);
    });

    testWidgets('Show archived is not offered on a list with no lifecycle', (
      tester,
    ) async {
      // Documents: the server never archives a file and the list never reads
      // the State filter, so the button would change nothing.
      await pump(tester, _FakeVm(search: 'acme', hasEntityStates: false));
      expect(find.text('Show archived'), findsNothing);
      expect(find.text('Clear Filters'), findsOneWidget);
    });

    testWidgets('All statuses drops only the status tab', (tester) async {
      final vm = _FakeVm(
        search: 'acme',
        extraFilters: const {
          'badge_mode': {'overdue'},
        },
      );
      await pump(tester, vm);
      await tester.tap(find.text('All statuses'));
      expect(vm.badgeModeCleared, isTrue);
      expect(vm.cleared, isFalse);
    });

    testWidgets('All statuses hides when the tab is the only narrowing — '
        'Clear filters does the same then', (tester) async {
      await pump(
        tester,
        _FakeVm(
          extraFilters: const {
            'badge_mode': {'overdue'},
          },
        ),
      );
      expect(find.text('All statuses'), findsNothing);
      expect(find.text('Clear Filters'), findsOneWidget);
    });

    testWidgets('three actions wrap at phone width instead of overflowing', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pump(
        tester,
        _FakeVm(
          search: 'acme',
          extraFilters: const {
            'badge_mode': {'overdue'},
          },
        ),
      );
      expect(find.text('All statuses'), findsOneWidget);
      expect(find.text('Show archived'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('extraNarrowing — a filter the base ViewModel cannot see', () {
    testWidgets('suppresses the archived copy', (tester) async {
      // Payments' unapplied-funds toggle. Its VM folds the flag into
      // `hasActiveFilters`, which covers the first-run branch; only this
      // parameter can reach the two lifecycle branches.
      await pump(
        tester,
        _FakeVm(states: const {EntityState.archived}),
        extraNarrowing: true,
      );
      expect(find.text('NO MATCHES'), findsOneWidget);
      expect(find.text('NO ARCHIVED'), findsNothing);
    });

    testWidgets('suppresses the deleted copy', (tester) async {
      await pump(
        tester,
        _FakeVm(states: const {EntityState.deleted}),
        extraNarrowing: true,
      );
      expect(find.text('NO MATCHES'), findsOneWidget);
      expect(find.text('NO DELETED'), findsNothing);
    });

    testWidgets('leaves the branch alone when false', (tester) async {
      await pump(tester, _FakeVm(states: const {EntityState.archived}));
      expect(find.text('NO ARCHIVED'), findsOneWidget);
    });
  });

  testWidgets('emptyAction rides on the first-run branch only', (tester) async {
    final action = OutlinedButton(onPressed: () {}, child: const Text('ADD'));
    await pump(tester, _FakeVm(), emptyAction: action);
    expect(find.text('ADD'), findsOneWidget);

    await pump(tester, _FakeVm(search: 'x'), emptyAction: action);
    expect(find.text('ADD'), findsNothing);
  });

  testWidgets('emptyOverride replaces the first-run branch but no other', (
    tester,
  ) async {
    const override = Text('BESPOKE');
    await pump(tester, _FakeVm(), emptyOverride: override);
    expect(find.text('BESPOKE'), findsOneWidget);
    expect(find.text('FIRST RUN'), findsNothing);

    // Transactions supplies one; its archived/deleted/no-match copy is still
    // the shared text.
    await pump(
      tester,
      _FakeVm(states: const {EntityState.archived}),
      emptyOverride: override,
    );
    expect(find.text('NO ARCHIVED'), findsOneWidget);
    expect(find.text('BESPOKE'), findsNothing);
  });
}
