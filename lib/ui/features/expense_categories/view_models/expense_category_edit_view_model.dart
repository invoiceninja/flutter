import 'package:admin/data/models/domain/expense_category.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/expense_category_repository.dart';
import 'package:admin/ui/core/edit/generic_edit_view_model.dart';

/// Drives the ExpenseCategory edit + create screen. Optimistic — `save()`
/// lands the draft in Drift via the repo, returns the saved entity, and the
/// outbox handles the server round-trip. Mirrors [ProductEditViewModel] —
/// the entity is tiny (name + color) so the bespoke setters are short.
class ExpenseCategoryEditViewModel
    extends GenericEditViewModel<ExpenseCategory> {
  ExpenseCategoryEditViewModel({
    required this.repo,
    required this.companyId,
    ExpenseCategory? existing,
    ExpenseCategory? cloneFrom,
    super.sync,
    super.connectivity,
  }) : super(
         initialDraft: cloneFrom ?? existing ?? emptyExpenseCategory(),
         original: existing,
         companyId: companyId,
       );

  final ExpenseCategoryRepository repo;
  final String companyId;

  @override
  bool draftIsNonEmpty() {
    final d = draft;
    return d.name.isNotEmpty || d.color.isNotEmpty;
  }

  @override
  Future<SaveResult<ExpenseCategory>> performSave() async {
    if (isCreate) {
      final result = await repo.create(
        companyId: companyId,
        draft: draft,
        existingTempId: recoveryTempId,
      );
      rememberCreateTempId(result.entity.id);
      return result;
    }
    return repo.save(companyId: companyId, category: draft);
  }

  void resetToEmpty() => reset(emptyDraft: emptyExpenseCategory());

  // `setStr` lives on the base; each setter just names the `copyWith`
  // projection. Closure params are named `n` (next value) to avoid
  // shadowing the outer setter argument.
  void setName(String v) => setStr((d, n) => d.copyWith(name: n), v);
  void setColor(String v) => setStr((d, n) => d.copyWith(color: n), v);
}
