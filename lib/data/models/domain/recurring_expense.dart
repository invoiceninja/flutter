import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:admin/data/models/api/recurring_expense_api_model.dart';
import 'package:admin/data/models/domain/document.dart';
import 'package:admin/data/models/domain/recurring_date.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/models/value/money.dart';
import 'package:admin/data/models/value/parsing.dart';
import 'package:admin/domain/expense_tax_math.dart';
import 'package:admin/domain/recurring_expense_status.dart';

part 'recurring_expense.freezed.dart';

/// Clean domain model the UI consumes. Mirrors [Expense] field-for-field
/// plus the recurring schedule deltas (`frequencyId`, `remainingCycles`,
/// `nextSendDate`, `lastSentDate`, `statusId`, `recurringDates`).
///
/// Money is `Decimal` (never `double`); tax rates are also `Decimal`
/// (Product convention enforced by the CI lint test). `recurringDates` is
/// ephemeral — the API populates it only when `?show_dates=true` is set,
/// and the repository does not persist it.
@freezed
abstract class RecurringExpense with _$RecurringExpense {
  const factory RecurringExpense({
    required String id,
    required String userId,
    required String assignedUserId,
    required String vendorId,
    required String invoiceId,
    required String clientId,
    required String bankId,
    required String invoiceCurrencyId,
    required String expenseCurrencyId,
    required String currencyId,
    required String categoryId,
    required String paymentTypeId,
    required String recurringExpenseId,
    required String privateNotes,
    required String publicNotes,
    required String transactionReference,
    required String transactionId,
    required Date? date,
    required String number,
    required Date? paymentDate,
    required String customValue1,
    required String customValue2,
    required String customValue3,
    required String customValue4,
    required String taxName1,
    required String taxName2,
    required String taxName3,
    required String projectId,
    required String entityType,
    // Recurring deltas.
    required String frequencyId,
    required int remainingCycles,
    required Date? nextSendDate,
    required Date? lastSentDate,
    required String? statusId,
    required Decimal amount,
    required Decimal foreignAmount,
    required Decimal exchangeRate,
    required Decimal taxAmount1,
    required Decimal taxAmount2,
    required Decimal taxAmount3,
    required Decimal taxRate1,
    required Decimal taxRate2,
    required Decimal taxRate3,
    required bool isDeleted,
    required bool shouldBeInvoiced,
    required bool invoiceDocuments,
    required bool usesInclusiveTaxes,
    required bool calculateTaxByAmount,
    required DateTime updatedAt,
    required DateTime createdAt,
    required DateTime? archivedAt,
    @Default(<Document>[]) List<Document> documents,
    @Default(<RecurringDate>[]) List<RecurringDate> recurringDates,
    @Default(false) bool isDirty,
  }) = _RecurringExpense;

  factory RecurringExpense.fromApi(RecurringExpenseApi a) => RecurringExpense(
    id: a.id,
    userId: a.userId,
    assignedUserId: a.assignedUserId,
    vendorId: a.vendorId,
    invoiceId: a.invoiceId,
    clientId: a.clientId,
    bankId: a.bankId,
    invoiceCurrencyId: a.invoiceCurrencyId,
    expenseCurrencyId: a.expenseCurrencyId,
    currencyId: a.currencyId,
    categoryId: a.categoryId,
    paymentTypeId: a.paymentTypeId,
    recurringExpenseId: a.recurringExpenseId,
    privateNotes: a.privateNotes,
    publicNotes: a.publicNotes,
    transactionReference: a.transactionReference,
    transactionId: a.transactionId,
    date: Date.tryParse(a.date),
    number: a.number,
    paymentDate: Date.tryParse(a.paymentDate),
    customValue1: a.customValue1,
    customValue2: a.customValue2,
    customValue3: a.customValue3,
    customValue4: a.customValue4,
    taxName1: a.taxName1,
    taxName2: a.taxName2,
    taxName3: a.taxName3,
    projectId: a.projectId,
    entityType: a.entityType,
    frequencyId: a.frequencyId,
    remainingCycles: a.remainingCycles,
    nextSendDate: Date.tryParse(a.nextSendDate),
    lastSentDate: Date.tryParse(a.lastSentDate),
    statusId: a.statusId,
    amount: parseMoney(a.amount),
    foreignAmount: parseMoney(a.foreignAmount),
    exchangeRate: parseMoney(a.exchangeRate),
    taxAmount1: parseMoney(a.taxAmount1),
    taxAmount2: parseMoney(a.taxAmount2),
    taxAmount3: parseMoney(a.taxAmount3),
    taxRate1: parseMoney(a.taxRate1),
    taxRate2: parseMoney(a.taxRate2),
    taxRate3: parseMoney(a.taxRate3),
    isDeleted: a.isDeleted,
    shouldBeInvoiced: a.shouldBeInvoiced,
    invoiceDocuments: a.invoiceDocuments,
    usesInclusiveTaxes: a.usesInclusiveTaxes,
    calculateTaxByAmount: a.calculateTaxByAmount,
    updatedAt: epochSecondsToUtc(a.updatedAt),
    createdAt: epochSecondsToUtc(a.createdAt),
    archivedAt: epochSecondsToUtcOrNull(a.archivedAt),
    documents: mapDocuments(a.documents),
    recurringDates: [
      for (final r in a.recurringDates ?? const <RecurringDateApi>[])
        RecurringDate.fromApi(r),
    ],
  );
}

/// Computed status helpers, parallel to `ExpenseStatus`. Mirrors admin-portal
/// `expense_model.dart:817-833` (recurring-expense branch).
extension RecurringExpenseStatus on RecurringExpense {
  /// `remainingCycles == 0` → Completed; `Active && lastSentDate == null` →
  /// Pending; otherwise the stored value (defaulting to Draft).
  String get calculatedStatusId {
    if (remainingCycles == 0) return kRecurringExpenseStatusCompleted;
    if (statusId == kRecurringExpenseStatusActive && lastSentDate == null) {
      return kRecurringExpenseStatusPending;
    }
    return statusId ?? kRecurringExpenseStatusDraft;
  }

  /// Draft + Paused are eligible to start. `null` is also eligible (server
  /// hasn't assigned a status yet on a freshly-created row).
  bool get canBeStarted =>
      statusId == null ||
      statusId == kRecurringExpenseStatusDraft ||
      statusId == kRecurringExpenseStatusPaused;

  bool get canBeStopped {
    final s = calculatedStatusId;
    return s == kRecurringExpenseStatusActive ||
        s == kRecurringExpenseStatusPending;
  }

  bool get isRunning => calculatedStatusId == kRecurringExpenseStatusActive;

  /// `exchangeRate == 0` is the legacy "no conversion" sentinel — return
  /// 1 so multiplied conversions don't zero out (parity with [Expense]).
  Decimal get effectiveExchangeRate =>
      exchangeRate == Decimal.zero ? Decimal.one : exchangeRate;

  /// `Σr` — the sum of this expense's inclusive tax rates, feeding the shared
  /// divisor `1 + Σr/100` (issue #12072). Parity with [Expense].
  Decimal get _inclusiveTotalRate => taxRate1 + taxRate2 + taxRate3;

  /// Per-tier tax amount, computed from the rate — parity with [Expense]
  /// (`taxAmount1Computed`). In `calculateTaxByAmount` mode the stored
  /// `tax_amount*` is authoritative.
  Decimal get taxAmount1Computed => calculateTaxByAmount
      ? taxAmount1
      : expenseTierTaxAmount(
          amount: amount,
          rate: taxRate1,
          usesInclusiveTaxes: usesInclusiveTaxes,
          totalRate: _inclusiveTotalRate,
        );
  Decimal get taxAmount2Computed => calculateTaxByAmount
      ? taxAmount2
      : expenseTierTaxAmount(
          amount: amount,
          rate: taxRate2,
          usesInclusiveTaxes: usesInclusiveTaxes,
          totalRate: _inclusiveTotalRate,
        );
  Decimal get taxAmount3Computed => calculateTaxByAmount
      ? taxAmount3
      : expenseTierTaxAmount(
          amount: amount,
          rate: taxRate3,
          usesInclusiveTaxes: usesInclusiveTaxes,
          totalRate: _inclusiveTotalRate,
        );

  Decimal get taxAmountSum =>
      taxAmount1Computed + taxAmount2Computed + taxAmount3Computed;

  /// Net (pre-tax) amount = gross − summed tax (parity with [Expense.netAmount];
  /// issue #12072). Inclusive multi-rate → 833.34, reconciles.
  Decimal get netAmount => usesInclusiveTaxes ? amount - taxAmountSum : amount;

  Decimal get grossAmount =>
      usesInclusiveTaxes ? amount : amount + taxAmountSum;

  Decimal get convertedAmount => grossAmount * effectiveExchangeRate;
}

/// Serialize back to the JSON shape the server expects. Mirrors
/// `ExpensePayload.toApiJson` plus the schedule fields.
/// `recurring_dates` is read-only (server populates on request); we never
/// send it.
extension RecurringExpensePayload on RecurringExpense {
  Map<String, dynamic> toApiJson({bool preserveTempId = false}) {
    return <String, dynamic>{
      if (preserveTempId || !id.startsWith('tmp_')) 'id': id,
      'user_id': userId,
      'assigned_user_id': assignedUserId,
      'vendor_id': vendorId,
      'invoice_id': invoiceId,
      'client_id': clientId,
      'bank_id': bankId,
      'invoice_currency_id': invoiceCurrencyId,
      'expense_currency_id': expenseCurrencyId,
      'currency_id': currencyId,
      'category_id': categoryId,
      'payment_type_id': paymentTypeId,
      'recurring_expense_id': recurringExpenseId,
      'private_notes': privateNotes,
      'public_notes': publicNotes,
      'transaction_reference': transactionReference,
      'transaction_id': transactionId,
      'date': date?.toIso() ?? '',
      'number': number,
      'payment_date': paymentDate?.toIso() ?? '',
      'custom_value1': customValue1,
      'custom_value2': customValue2,
      'custom_value3': customValue3,
      'custom_value4': customValue4,
      'tax_name1': taxName1,
      'tax_name2': taxName2,
      'tax_name3': taxName3,
      'project_id': projectId,
      'frequency_id': frequencyId,
      'remaining_cycles': remainingCycles,
      'next_send_date': nextSendDate?.toIso() ?? '',
      'last_sent_date': lastSentDate?.toIso() ?? '',
      if (statusId != null) 'status_id': statusId,
      'amount': amount.toString(),
      'foreign_amount': foreignAmount.toString(),
      'exchange_rate': exchangeRate.toString(),
      'tax_amount1': taxAmount1.toString(),
      'tax_amount2': taxAmount2.toString(),
      'tax_amount3': taxAmount3.toString(),
      'tax_rate1': taxRate1.toString(),
      'tax_rate2': taxRate2.toString(),
      'tax_rate3': taxRate3.toString(),
      'should_be_invoiced': shouldBeInvoiced,
      'invoice_documents': invoiceDocuments,
      'uses_inclusive_taxes': usesInclusiveTaxes,
      'calculate_tax_by_amount': calculateTaxByAmount,
    };
  }
}
