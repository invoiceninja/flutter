import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:admin/data/models/api/expense_category_api_model.dart';
import 'package:admin/data/models/value/parsing.dart';

part 'expense_category.freezed.dart';

/// Clean domain model for an ExpenseCategory row. Used as a picker on the
/// Expense edit form and edited via Settings → Advanced → Expense Categories.
///
/// Mirrors [TaskStatus] without the `statusOrder` field — categories aren't
/// ordered server-side. `isDirty` is overlaid by the repository in
/// `_fromRow`; the `fromApi` factory defaults it to `false`.
@freezed
abstract class ExpenseCategory with _$ExpenseCategory {
  const factory ExpenseCategory({
    required String id,
    required String userId,
    required String assignedUserId,
    required String name,
    required String color,
    required DateTime updatedAt,
    required DateTime createdAt,
    required DateTime? archivedAt,
    required bool isDeleted,
    @Default(false) bool isDirty,
  }) = _ExpenseCategory;

  factory ExpenseCategory.fromApi(ExpenseCategoryApi a) => ExpenseCategory(
    id: a.id,
    userId: a.userId,
    assignedUserId: a.assignedUserId,
    name: a.name,
    color: a.color,
    updatedAt: epochSecondsToUtc(a.updatedAt),
    createdAt: epochSecondsToUtc(a.createdAt),
    archivedAt: epochSecondsToUtcOrNull(a.archivedAt),
    isDeleted: a.isDeleted,
  );
}

extension ExpenseCategoryPayload on ExpenseCategory {
  /// Outbox payload. Drops `tmp_<uuid>` from `id` so the server's create
  /// flow doesn't see it as an update target; pass `preserveTempId: true`
  /// for the Drift `payload` blob so the local round-trip is lossless.
  Map<String, dynamic> toApiJson({bool preserveTempId = false}) {
    return <String, dynamic>{
      if (preserveTempId || !id.startsWith('tmp_')) 'id': id,
      'name': name,
      'color': color,
    };
  }
}

/// An empty draft, for a create form and for inline create.
///
/// Lives beside the model rather than in the edit view-model so
/// `lib/ui/core/**` can build one without importing a feature package.
ExpenseCategory emptyExpenseCategory() => ExpenseCategory(
  id: '',
  userId: '',
  assignedUserId: '',
  name: '',
  color: '',
  updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  archivedAt: null,
  isDeleted: false,
);
