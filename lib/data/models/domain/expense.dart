import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:admin/data/models/api/expense_api_model.dart';
import 'package:admin/data/models/domain/document.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/models/value/money.dart';
import 'package:admin/data/models/value/parsing.dart';
import 'package:admin/domain/expense_status.dart';
import 'package:admin/domain/expense_tax_math.dart';

part 'expense.freezed.dart';

/// Clean domain model the UI consumes. `Expense.fromApi(...)` walks the
/// raw [ExpenseApi] DTO. The `isDirty` flag is local-only — `fromApi`
/// defaults it to `false`, and [ExpenseRepository._fromRow] overlays the
/// Drift row's value so unsaved edits survive app restart.
///
/// Money is `Decimal` (never `double`). Tax rates are also `Decimal` —
/// Product is the precedent (the CI lint test rejects `double` on tax
/// rates). Date-only fields use the custom [Date] type; timestamps stay
/// as `DateTime`.
@freezed
abstract class Expense with _$Expense {
  const factory Expense({
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
    @Default(<String>[]) List<String> tagIds,
    @Default(false) bool isDirty,
  }) = _Expense;

  factory Expense.fromApi(ExpenseApi a) => Expense(
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
    tagIds: [
      for (final t in a.tags)
        if (t.id.isNotEmpty) t.id,
    ],
  );
}

/// Computed status helpers + derived money totals. Mirrors the legacy
/// admin-portal `expense_model.dart` derivations so list filter chips +
/// detail-header status pill agree on classification.
extension ExpenseStatus on Expense {
  bool get isInvoiced => invoiceId.isNotEmpty;

  /// Paid is asserted from `payment_date` / `transaction_reference` only —
  /// matches the server's `client_status` list filter
  /// (`ExpenseFilters::clientStatus`), so the local status badge and the
  /// "Paid"/"Unpaid" list filter agree with the server. `payment_type_id`
  /// alone does NOT mark an expense paid server-side; the edit "mark paid"
  /// toggle still surfaces the type field via its own triple check.
  bool get isPaid => (paymentDate != null) || transactionReference.isNotEmpty;

  /// "Pending" = scheduled for invoicing but not yet invoiced.
  bool get isPending => !isInvoiced && shouldBeInvoiced;

  /// Status discriminator (`'1'..'5'`). Mirrors admin-portal
  /// `expense_model.dart:837-845` and React `ExpenseStatus.tsx`:
  ///   * Invoiced → '3' (any invoiced expense, paid or not)
  ///   * Pending  → '2' (flagged should-be-invoiced, not yet invoiced)
  ///   * Paid     → '5'
  ///   * Logged   → '1' (default)
  ///
  /// Both references always show "Invoiced" for an invoiced expense and never
  /// surface "Unpaid" from the derived badge — `kExpenseStatusUnpaid` is a
  /// list-filter value (invoiced-but-unpaid), not a badge state.
  String get calculatedStatusId {
    if (isInvoiced) return kExpenseStatusInvoiced;
    if (isPending) return kExpenseStatusPending;
    if (isPaid) return kExpenseStatusPaid;
    return kExpenseStatusLogged;
  }

  /// `exchangeRate == 0` is the legacy "no conversion" sentinel — return
  /// 1 so multiplied conversions don't zero out. Mirrors admin-portal
  /// `expense_model.dart:837`.
  Decimal get effectiveExchangeRate =>
      exchangeRate == Decimal.zero ? Decimal.one : exchangeRate;

  /// `Σr` — the sum of this expense's inclusive tax rates, feeding the shared
  /// divisor `1 + Σr/100` (issue #12072). Zero rates add nothing, so an
  /// inactive tier is naturally excluded.
  Decimal get _inclusiveTotalRate => taxRate1 + taxRate2 + taxRate3;

  /// Per-tier tax amount, computed from the rate (mirrors admin-portal
  /// `expense_model.dart` `calculateTaxAmountN`). In `calculateTaxByAmount`
  /// mode the stored `tax_amount*` is authoritative and returned as-is.
  ///
  /// The edit form only collects the rate (or the amount, in by-amount mode),
  /// so the stored `tax_amount*` stays 0 until a server round-trip — these
  /// getters keep gross/net/tax correct offline and on web (where writes are
  /// blocked) and immediately after editing a rate.
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

  /// Net (pre-tax) amount = gross − summed tax. For inclusive multi-rate the
  /// tiers are the additive shared-base taxes (issue #12072), so net absorbs
  /// the 1¢ rounding residual and reconciles: 1000 @ 10%+10% → 833.34. Matches
  /// the backend `InclusiveTax::backout()` (`gross − Σtax`).
  Decimal get netAmount => usesInclusiveTaxes ? amount - taxAmountSum : amount;

  Decimal get grossAmount =>
      usesInclusiveTaxes ? amount : amount + taxAmountSum;

  Decimal get convertedAmount => grossAmount * effectiveExchangeRate;
}

/// Serialize back to the JSON shape the server expects. `preserveTempId`
/// lets the local Drift cache keep the temp id; outbound `POST /expenses`
/// drops it so the server can assign the real one.
extension ExpensePayload on Expense {
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
      // Full-set replace: the server syncs attached tags to exactly this list.
      'tags': tagIds,
      'tax_name1': taxName1,
      'tax_name2': taxName2,
      'tax_name3': taxName3,
      'project_id': projectId,
      // Decimal → String so precision survives. Tax rates ship as numbers
      // (matches the wire shape the server returns).
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
