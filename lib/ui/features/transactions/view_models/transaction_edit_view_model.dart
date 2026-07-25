import 'package:decimal/decimal.dart';

import 'package:admin/data/models/domain/bank_transaction.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/bank_transaction_repository.dart';
import 'package:admin/ui/core/edit/generic_edit_view_model.dart';

/// Drives the manual `/transactions/new` + `/:id/edit` form. Bank-fed
/// transactions land via sync; this VM is for the rare manual-entry
/// path. The form covers the wire fields the API accepts on create:
/// amount, currency, date, bank-account, description, baseType.
class TransactionEditViewModel extends GenericEditViewModel<BankTransaction> {
  TransactionEditViewModel({
    required this.repo,
    required this.companyId,
    required this.bankAccountRequiredMessage,
    BankTransaction? existing,
    super.sync,
    super.connectivity,
  }) : super(
         initialDraft: existing ?? _emptyTransaction(),
         original: existing,
         companyId: companyId,
       );

  final BankTransactionRepository repo;
  final String companyId;

  /// Localized message surfaced inline (via [fieldErrorFor]) when no bank
  /// account is selected. The server requires `bank_integration_id` on both
  /// create and update, and an offline create enqueues optimistically (the
  /// form closes before the drain), so a 422 would never reach this screen —
  /// validate client-side instead.
  final String bankAccountRequiredMessage;

  @override
  Map<String, List<String>> validate() => {
    if (draft.bankAccountId.isEmpty)
      'bank_integration_id': [bankAccountRequiredMessage],
  };

  @override
  bool draftIsNonEmpty() =>
      draft.amount != Decimal.zero ||
      draft.description.isNotEmpty ||
      draft.bankAccountId.isNotEmpty;

  @override
  Future<SaveResult<BankTransaction>> performSave() async {
    if (isCreate) {
      final result = await repo.create(
        companyId: companyId,
        draft: draft,
        existingTempId: recoveryTempId,
      );
      rememberCreateTempId(result.entity.id);
      return result;
    }
    return repo.save(companyId: companyId, transaction: draft);
  }

  void resetToEmpty() => reset(emptyDraft: _emptyTransaction());

  void setAmount(Decimal v) => updateDraft(draft.copyWith(amount: v));
  void setCurrencyId(String v) => updateDraft(draft.copyWith(currencyId: v));
  void setDate(Date? v) => updateDraft(draft.copyWith(date: v));
  void setBankAccountId(String v) =>
      updateDraft(draft.copyWith(bankAccountId: v));
  void setDescription(String v) => updateDraft(draft.copyWith(description: v));
  void setBaseType(String v) => updateDraft(draft.copyWith(baseType: v));
  void setTagIds(List<String> v) => updateDraft(draft.copyWith(tagIds: v));
}

BankTransaction _emptyTransaction() => BankTransaction(
  id: '',
  amount: Decimal.zero,
  currencyId: '',
  category: '',
  baseType: kTransactionTypeCredit,
  date: Date.today(),
  bankAccountId: '',
  description: '',
  statusId: kTransactionStatusUnmatched,
  categoryId: '',
  invoiceIds: '',
  paymentId: '',
  expenseId: '',
  vendorId: '',
  transactionId: '',
  transactionRuleId: '',
  participantName: '',
  participant: '',
  isDeleted: false,
  updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  archivedAt: null,
);
