import 'package:decimal/decimal.dart';

import 'package:admin/data/models/domain/recurring_expense.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/recurring_expense_repository.dart';
import 'package:admin/domain/recurring_frequency.dart';
import 'package:admin/ui/core/edit/generic_edit_view_model.dart';
import 'package:admin/utils/formatting.dart';

/// Drives the Recurring Expense edit + create screen. Mirrors
/// `ExpenseEditViewModel` plus the recurring schedule setters
/// (`frequencyId`, `remainingCycles`, `nextSendDate`, `statusId`).
class RecurringExpenseEditViewModel
    extends GenericEditViewModel<RecurringExpense> {
  RecurringExpenseEditViewModel({
    required this.repo,
    required this.companyId,
    RecurringExpense? existing,
    RecurringExpense? cloneFrom,
    super.sync,
    super.connectivity,
    super.useCommaAsDecimalPlace,
  }) : super(
         initialDraft: cloneFrom ?? existing ?? emptyRecurringExpense(),
         original: existing,
         companyId: companyId,
       );

  final RecurringExpenseRepository repo;
  final String companyId;

  @override
  bool draftIsNonEmpty() {
    final d = draft;
    return d.vendorId.isNotEmpty ||
        d.clientId.isNotEmpty ||
        d.projectId.isNotEmpty ||
        d.categoryId.isNotEmpty ||
        d.amount != Decimal.zero ||
        d.publicNotes.isNotEmpty ||
        d.privateNotes.isNotEmpty ||
        d.transactionReference.isNotEmpty;
  }

  @override
  Future<SaveResult<RecurringExpense>> performSave() async {
    if (isCreate) {
      final result = await repo.create(
        companyId: companyId,
        draft: draft,
        existingTempId: recoveryTempId,
      );
      rememberCreateTempId(result.entity.id);
      return result;
    }
    return repo.save(companyId: companyId, recurringExpense: draft);
  }

  void resetToEmpty() => reset(emptyDraft: emptyRecurringExpense());

  // ── Identity / links ──────────────────────────────────────────────

  void setVendorId(String v) => updateDraft(draft.copyWith(vendorId: v));
  void setClientId(String v) => updateDraft(draft.copyWith(clientId: v));
  void setTagIds(List<String> ids) => updateDraft(draft.copyWith(tagIds: ids));
  void setProjectId(String v) => updateDraft(draft.copyWith(projectId: v));
  void setCategoryId(String v) => updateDraft(draft.copyWith(categoryId: v));
  void setCurrencyId(String v) => updateDraft(draft.copyWith(currencyId: v));

  /// See `ExpenseEditViewModel.setInvoiceCurrencyId` — clearing resets the
  /// conversion (rate → 1, foreign → 0); setting recomputes the foreign
  /// amount from the current rate.
  void setInvoiceCurrencyId(String v) {
    if (v.isEmpty) {
      updateDraft(
        draft.copyWith(
          invoiceCurrencyId: '',
          exchangeRate: Decimal.one,
          foreignAmount: Decimal.zero,
        ),
      );
      return;
    }
    final d = draft.copyWith(invoiceCurrencyId: v);
    updateDraft(d.copyWith(foreignAmount: d.amount * d.exchangeRate));
  }

  void setAssignedUserId(String v) =>
      updateDraft(draft.copyWith(assignedUserId: v));
  void setNumber(String v) => updateDraft(draft.copyWith(number: v));
  void setDate(Date? d) => updateDraft(draft.copyWith(date: d));

  // ── Recurring schedule ────────────────────────────────────────────

  void setFrequencyId(String v) => updateDraft(draft.copyWith(frequencyId: v));

  /// `-1` = endless. The edit screen renders the affordance as a
  /// "Endless" checkbox + a disabled-when-checked number input; both
  /// paths flow through this single setter.
  void setRemainingCycles(int n) =>
      updateDraft(draft.copyWith(remainingCycles: n));

  void setEndlessCycles(bool endless) =>
      updateDraft(draft.copyWith(remainingCycles: endless ? -1 : 1));

  void setNextSendDate(Date? d) => updateDraft(draft.copyWith(nextSendDate: d));

  /// Stored Draft/Active/Paused/Completed/Pending. Mostly server-managed;
  /// the edit form rarely writes this directly (Start/Stop actions do).
  void setStatusId(String? v) => updateDraft(draft.copyWith(statusId: v));

  // ── Payment ────────────────────────────────────────────────────────

  void setPaymentDate(Date? d) => updateDraft(draft.copyWith(paymentDate: d));
  void setPaymentTypeId(String v) =>
      updateDraft(draft.copyWith(paymentTypeId: v));
  void setTransactionReference(String v) =>
      updateDraft(draft.copyWith(transactionReference: v));
  void setTransactionId(String v) =>
      updateDraft(draft.copyWith(transactionId: v));
  void setBankId(String v) => updateDraft(draft.copyWith(bankId: v));

  // ── Money / tax ────────────────────────────────────────────────────

  void setAmount(String input) {
    final amount =
        parseDecimal(input, useCommaAsDecimalPlace: useCommaAsDecimalPlace) ??
        Decimal.zero;
    var d = draft.copyWith(amount: amount);
    if (d.invoiceCurrencyId.isNotEmpty) {
      d = d.copyWith(foreignAmount: amount * d.exchangeRate);
    }
    updateDraft(d);
  }

  /// Editing the foreign amount back-computes the exchange rate
  /// (`foreign / amount`) — mirrors React's `foreign_amount` onChange.
  void setForeignAmount(String input) {
    final foreign =
        parseDecimal(input, useCommaAsDecimalPlace: useCommaAsDecimalPlace) ??
        Decimal.zero;
    var d = draft.copyWith(foreignAmount: foreign);
    if (d.amount != Decimal.zero) {
      d = d.copyWith(
        exchangeRate: (foreign / d.amount).toDecimal(
          scaleOnInfinitePrecision: 10,
        ),
      );
    }
    updateDraft(d);
  }

  void setExchangeRate(String input) {
    final rate =
        parseDecimal(
          input,
          zeroIsNull: true,
          useCommaAsDecimalPlace: useCommaAsDecimalPlace,
        ) ??
        Decimal.one;
    var d = draft.copyWith(exchangeRate: rate);
    if (d.invoiceCurrencyId.isNotEmpty) {
      d = d.copyWith(foreignAmount: d.amount * rate);
    }
    updateDraft(d);
  }

  void setTaxName1(String v) => updateDraft(draft.copyWith(taxName1: v));
  void setTaxName2(String v) => updateDraft(draft.copyWith(taxName2: v));
  void setTaxName3(String v) => updateDraft(draft.copyWith(taxName3: v));
  void setTaxRate1(String input) => updateDraft(
    draft.copyWith(
      taxRate1:
          parseDecimal(input, useCommaAsDecimalPlace: useCommaAsDecimalPlace) ??
          Decimal.zero,
    ),
  );
  void setTaxRate2(String input) => updateDraft(
    draft.copyWith(
      taxRate2:
          parseDecimal(input, useCommaAsDecimalPlace: useCommaAsDecimalPlace) ??
          Decimal.zero,
    ),
  );
  void setTaxRate3(String input) => updateDraft(
    draft.copyWith(
      taxRate3:
          parseDecimal(input, useCommaAsDecimalPlace: useCommaAsDecimalPlace) ??
          Decimal.zero,
    ),
  );
  void setTaxAmount1(String input) => updateDraft(
    draft.copyWith(
      taxAmount1:
          parseDecimal(input, useCommaAsDecimalPlace: useCommaAsDecimalPlace) ??
          Decimal.zero,
    ),
  );
  void setTaxAmount2(String input) => updateDraft(
    draft.copyWith(
      taxAmount2:
          parseDecimal(input, useCommaAsDecimalPlace: useCommaAsDecimalPlace) ??
          Decimal.zero,
    ),
  );
  void setTaxAmount3(String input) => updateDraft(
    draft.copyWith(
      taxAmount3:
          parseDecimal(input, useCommaAsDecimalPlace: useCommaAsDecimalPlace) ??
          Decimal.zero,
    ),
  );
  void setUsesInclusiveTaxes(bool v) =>
      updateDraft(draft.copyWith(usesInclusiveTaxes: v));
  void setCalculateTaxByAmount(bool v) =>
      updateDraft(draft.copyWith(calculateTaxByAmount: v));

  // ── Invoicing / notes / custom fields ─────────────────────────────

  void setShouldBeInvoiced(bool v) =>
      updateDraft(draft.copyWith(shouldBeInvoiced: v));
  void setInvoiceDocuments(bool v) =>
      updateDraft(draft.copyWith(invoiceDocuments: v));
  void setPublicNotes(String v) => updateDraft(draft.copyWith(publicNotes: v));
  void setPrivateNotes(String v) =>
      updateDraft(draft.copyWith(privateNotes: v));
  void setCustomValue1(String v) =>
      updateDraft(draft.copyWith(customValue1: v));
  void setCustomValue2(String v) =>
      updateDraft(draft.copyWith(customValue2: v));
  void setCustomValue3(String v) =>
      updateDraft(draft.copyWith(customValue3: v));
  void setCustomValue4(String v) =>
      updateDraft(draft.copyWith(customValue4: v));
}

/// Empty draft for new recurring expenses. Defaults match admin-portal's
/// create factory: monthly frequency, endless cycles, no status (server
/// assigns Draft on create), `exchange_rate = 1`.
RecurringExpense emptyRecurringExpense() => RecurringExpense(
  id: '',
  userId: '',
  assignedUserId: '',
  vendorId: '',
  invoiceId: '',
  clientId: '',
  bankId: '',
  invoiceCurrencyId: '',
  expenseCurrencyId: '',
  currencyId: '',
  categoryId: '',
  paymentTypeId: '',
  recurringExpenseId: '',
  privateNotes: '',
  publicNotes: '',
  transactionReference: '',
  transactionId: '',
  date: Date.today(),
  number: '',
  paymentDate: null,
  customValue1: '',
  customValue2: '',
  customValue3: '',
  customValue4: '',
  taxName1: '',
  taxName2: '',
  taxName3: '',
  projectId: '',
  entityType: '',
  frequencyId: kRecurringFrequencyMonthly,
  remainingCycles: -1,
  nextSendDate: Date.today(),
  lastSentDate: null,
  statusId: null,
  amount: Decimal.zero,
  foreignAmount: Decimal.zero,
  exchangeRate: Decimal.one,
  taxAmount1: Decimal.zero,
  taxAmount2: Decimal.zero,
  taxAmount3: Decimal.zero,
  taxRate1: Decimal.zero,
  taxRate2: Decimal.zero,
  taxRate3: Decimal.zero,
  isDeleted: false,
  shouldBeInvoiced: false,
  invoiceDocuments: false,
  usesInclusiveTaxes: false,
  calculateTaxByAmount: false,
  updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  archivedAt: null,
);
