// `createExpenseCategoryInline` — the picker's "Create «name»" for categories.
// The rule worth pinning is the archived one: the server's unique-name rule
// ignores soft-deletes, so a name an archived or deleted category holds would
// 422 the create and kill the expense queued behind its tmp_ id.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/domain/expense_category.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/expense_category_repository.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/ui/features/expense_categories/widgets/expense_category_inline_create.dart';

import '../../../_localization_helper.dart';

class _FakeCategories implements ExpenseCategoryRepository {
  _FakeCategories(this.rows);

  final List<ExpenseCategory> rows;
  final created = <ExpenseCategory>[];
  Set<EntityState>? lastStates;

  bool _inStates(ExpenseCategory c, Set<EntityState> states) {
    final state = c.isDeleted
        ? EntityState.deleted
        : c.archivedAt != null
        ? EntityState.archived
        : EntityState.active;
    return states.contains(state);
  }

  @override
  Stream<List<ExpenseCategory>> watchPage({
    required String companyId,
    int loadedPages = 1,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    String sortField = 'name',
    bool sortAscending = true,
  }) {
    lastStates = states;
    return Stream.value(
      rows
          .where((c) => _inStates(c, states))
          .where(
            (c) =>
                search == null ||
                c.name.toLowerCase().contains(search.toLowerCase()),
          )
          .toList(),
    );
  }

  @override
  Future<SaveResult<ExpenseCategory>> create({
    required String companyId,
    required ExpenseCategory draft,
    String? existingTempId,
  }) async {
    final stored = draft.copyWith(id: 'tmp_${created.length}');
    created.add(stored);
    return SaveResult(entity: stored, outboxRowId: created.length);
  }

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError(i.memberName.toString());
}

class _FakeServices implements Services {
  _FakeServices(this.expenseCategories);

  @override
  final ExpenseCategoryRepository expenseCategories;

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError(i.memberName.toString());
}

ExpenseCategory _cat(String id, String name, {bool archived = false}) =>
    emptyExpenseCategory().copyWith(
      id: id,
      name: name,
      archivedAt: archived ? DateTime.utc(2026) : null,
    );

void main() {
  late BuildContext ctx;

  Future<ExpenseCategory?> run(
    WidgetTester tester,
    _FakeCategories repo,
    String query,
  ) async {
    await tester.pumpWidget(
      Provider<Services>.value(
        value: _FakeServices(repo),
        child: MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          home: Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    final result = createExpenseCategoryInline(
      ctx,
      companyId: 'c1',
      query: query,
    );
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('creates a category from the typed name', (tester) async {
    final repo = _FakeCategories([_cat('c1', 'Travel')]);
    final c = await run(tester, repo, 'Meals');
    expect(repo.created.map((c) => c.name), ['Meals']);
    expect(c?.id, 'tmp_0');
  });

  testWidgets('checks archived and deleted categories too', (tester) async {
    final repo = _FakeCategories([]);
    await run(tester, repo, 'Meals');
    expect(repo.lastStates, EntityState.values.toSet());
  });

  testWidgets('an active category with the same name is selected', (
    tester,
  ) async {
    final repo = _FakeCategories([_cat('c1', 'Meals')]);
    final c = await run(tester, repo, 'meals');
    expect(repo.created, isEmpty);
    expect(c?.id, 'c1');
  });

  testWidgets('an archived category with the same name blocks the create', (
    tester,
  ) async {
    final repo = _FakeCategories([_cat('c1', 'Meals', archived: true)]);
    final c = await run(tester, repo, 'Meals');
    expect(c, isNull);
    expect(repo.created, isEmpty);
  });
}
