/// Bank-transaction column / sort-field id constants.
///
/// **This file must import nothing** — leaf by design. [BankTransactionFieldIds]
/// previously lived in `bank_transaction_dao.dart` while
/// [BankTransactionColumnIds] lived in `bank_transaction_columns.dart`, and each
/// file imported the other for the half it lacked — a direct import cycle
/// between the data layer and a Widget-bearing registry. Both now live here.
/// See `test/lint/layering_test.dart`.
///
/// `bank_transaction_dao.dart` re-exports this file, so its existing consumers
/// (`BankTransactionRepository`, the Transactions list screen + ViewModel) are
/// unchanged; `bank_transaction_columns.dart` re-exports it too.
library;

/// Sortable wire ids — each maps to a real Drift column on `bank_transactions`.
class BankTransactionFieldIds {
  static const String date = 'date';
  static const String amount = 'amount';
  static const String description = 'description';
  static const String participantName = 'participant_name';
  static const String statusId = 'status_id';
  static const String baseType = 'base_type';
  static const String updatedAt = 'updated_at';
  static const String createdAt = 'created_at';

  /// Real Drift column (`EntityTimestampColumns`) — sortable.
  static const String archivedAt = 'archived_at';

  /// Real Drift column (`EntityFlagColumns`) — sortable.
  static const String isDeleted = 'is_deleted';
}

/// Column id constants. Most map 1:1 to [BankTransactionFieldIds]; the
/// `deposit` / `withdrawal` ids are display-only splits of `amount` driven
/// by `baseType`. They aren't sortable on their own — sort by `amount` to
/// order both columns numerically.
class BankTransactionColumnIds {
  static const String status = BankTransactionFieldIds.statusId;
  static const String deposit = 'deposit';
  static const String withdrawal = 'withdrawal';
  static const String date = BankTransactionFieldIds.date;
  static const String participantName = BankTransactionFieldIds.participantName;
  static const String description = BankTransactionFieldIds.description;
  static const String bankAccountId = 'bank_account_id';
  static const String invoices = 'invoices';
  static const String expenses = 'expenses';
  static const String currencyId = 'currency_id';
  static const String amount = BankTransactionFieldIds.amount;
  static const String updatedAt = BankTransactionFieldIds.updatedAt;
  static const String tagIds = 'bank_transaction_tag_ids';
  static const String createdAt = BankTransactionFieldIds.createdAt;
  static const String archivedAt = BankTransactionFieldIds.archivedAt;
  static const String isDeleted = BankTransactionFieldIds.isDeleted;

  /// Derived from `archived_at` + `is_deleted` — display-only.
  static const String entityState = 'entity_state';
}
