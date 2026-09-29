import 'package:decimal/decimal.dart';

import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/expense.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/expense_repository.dart';
import 'package:admin/ui/core/edit/generic_edit_view_model.dart';
import 'package:admin/utils/formatting.dart';

/// Drives the Expense edit + create screen. Optimistic — `save()` lands the
/// draft in Drift via the repo, returns the saved entity, and the outbox
/// handles the server round-trip.
class ExpenseEditViewModel extends GenericEditViewModel<Expense> {
  ExpenseEditViewModel({
    required this.repo,
    required this.companyId,
    Expense? existing,
    Expense? cloneFrom,
    super.sync,
    super.connectivity,
    super.useCommaAsDecimalPlace,
  }) : super(
         initialDraft: cloneFrom ?? existing ?? emptyExpense(),
         original: existing,
         companyId: companyId,
         prefilled: existing == null && cloneFrom != null,
       );

  final ExpenseRepository repo;
  final String companyId;

  /// Dirty is "differs from what the untouched form held", for every field
  /// at once — the billing view models' rule. The hand-kept list this
  /// replaced missed the date, the number and the assignee, so a new expense
  /// holding only those left without the Discard prompt. A form opened on a
  /// staged draft (a clone, a "New expense" from a vendor) holds unsaved
  /// content from the start.
  @override
  bool draftIsNonEmpty() => draft != createBaseline || prefilled;

  @override
  Future<SaveResult<Expense>> performSave() async {
    if (savesAsCreate) {
      final result = await repo.create(
        companyId: companyId,
        draft: draft,
        existingTempId: recoveryTempId,
      );
      rememberCreateTempId(result.entity.id);
      return result;
    }
    return repo.save(companyId: companyId, expense: draft);
  }

  void resetToEmpty() => reset(emptyDraft: emptyExpense());

  @override
  void reset({required Expense emptyDraft}) {
    _userTouchedInclusive = false;
    super.reset(emptyDraft: emptyDraft);
    // The only way a rebased blank draft carries a payment date is the
    // company's mark-paid default being re-applied, which follows the date.
    // An edit form's reset restores the stored record, whose payment date is
    // the user's and never follows.
    _paymentDateFollowsDate = isCreate && draft.paymentDate != null;
  }

  bool _userTouchedInclusive = false;

  /// Whether [setDate] also moves the payment date. Set whenever the app fills
  /// the payment date in from the expense date — [markPaid], the company's
  /// mark-paid default in [seedCompanyDefaults], and that default's
  /// re-application on Discard ([reset]) — so never for a stored payment date
  /// on an existing expense. Cleared the moment the user edits the payment
  /// date themselves ([setPaymentDate]) or unticks Mark paid.
  bool _paymentDateFollowsDate = false;

  /// Seed a new expense from the company's Expense Settings — what React's
  /// `Create.tsx` and admin-portal's `ExpenseEntity` constructor do, and what
  /// the server does NOT do for a manually created expense (it applies these
  /// only in bank matching and the recurring cron). Without it every one of
  /// those settings toggles was inert here.
  ///
  /// The edit screen calls this only for a genuine new expense — never for a
  /// clone, which copies its source. Each default goes through
  /// [seedCreateDefault], so an untouched form stays clean and a Discard
  /// re-applies it, and each is skipped once the user has changed the field
  /// it would set.
  void seedCompanyDefaults(Company company) {
    final base = createBaseline;
    // An amount is net or gross by the mode it was typed in, so the mode is
    // the user's once there is one.
    if (!_userTouchedInclusive && draft.amount == Decimal.zero) {
      seedCreateDefault(
        (d) => d.copyWith(usesInclusiveTaxes: company.expenseInclusiveTaxes),
      );
    }
    // Same reasoning for rate vs amount entry: once a tax is entered, the
    // mode it was entered in is what it means.
    if (draft.calculateTaxByAmount == base.calculateTaxByAmount &&
        !_hasTaxEntered(draft)) {
      seedCreateDefault(
        (d) => d.copyWith(
          calculateTaxByAmount: company.calculateExpenseTaxByAmount,
        ),
      );
    }
    if (draft.shouldBeInvoiced == base.shouldBeInvoiced) {
      seedCreateDefault(
        (d) => d.copyWith(shouldBeInvoiced: company.markExpensesInvoiceable),
      );
    }
    if (draft.invoiceDocuments == base.invoiceDocuments) {
      seedCreateDefault(
        (d) => d.copyWith(invoiceDocuments: company.invoiceExpenseDocuments),
      );
    }
    if (company.markExpensesPaid && !draft.isPaid) {
      final typeId = _usablePaymentTypeId(
        company.settings.defaultExpensePaymentTypeId,
      );
      final applied = seedCreateDefault((d) => _markedPaid(d, typeId));
      if (applied) _paymentDateFollowsDate = true;
    }
  }

  /// Tick "Mark paid": the payment date defaults to the expense's own date
  /// (today when it has none) — a receipt back-dated to last week was paid
  /// last week far more often than today — and the payment type to the
  /// company's default expense payment type. Until the user edits the
  /// payment date, changing the expense date moves it too ([setDate]).
  void markPaid({String? defaultPaymentTypeId}) {
    if (draft.paymentDate == null) _paymentDateFollowsDate = true;
    updateDraft(_markedPaid(draft, _usablePaymentTypeId(defaultPaymentTypeId)));
  }

  /// Untick "Mark paid": clears the whole payment-metadata triple.
  void unmarkPaid() {
    _paymentDateFollowsDate = false;
    updateDraft(
      draft.copyWith(
        paymentDate: null,
        paymentTypeId: '',
        transactionReference: '',
      ),
    );
  }

  static Expense _markedPaid(Expense d, String defaultPaymentTypeId) =>
      d.copyWith(
        paymentDate: d.paymentDate ?? d.date ?? Date.today(),
        paymentTypeId: d.paymentTypeId.isEmpty
            ? defaultPaymentTypeId
            : d.paymentTypeId,
      );

  /// The server's "no default" is `'0'` (`CompanySettings::
  /// $default_expense_payment_type_id`), not an empty string.
  static String _usablePaymentTypeId(String? id) =>
      (id == null || id.isEmpty || id == '0') ? '' : id;

  static bool _hasTaxEntered(Expense d) => [
    d.taxRate1,
    d.taxRate2,
    d.taxRate3,
    d.taxAmount1,
    d.taxAmount2,
    d.taxAmount3,
  ].any((v) => v != Decimal.zero);

  // ── Field setters ──────────────────────────────────────────────────

  void setVendorId(String v) => updateDraft(draft.copyWith(vendorId: v));
  void setTagIds(List<String> ids) => updateDraft(draft.copyWith(tagIds: ids));
  void setClientId(String v) => updateDraft(draft.copyWith(clientId: v));
  void setProjectId(String v) => updateDraft(draft.copyWith(projectId: v));
  void setCategoryId(String v) => updateDraft(draft.copyWith(categoryId: v));
  void setCurrencyId(String v) => updateDraft(draft.copyWith(currencyId: v));

  /// Set the invoice currency. Clearing it resets the conversion (rate → 1,
  /// foreign → 0); setting it recomputes the foreign amount from the current
  /// rate. Mirrors React `AdditionalInfo` useEffect on `invoice_currency_id`.
  /// The edit screen separately seeds the exchange rate from the two
  /// currencies' base rates via [setExchangeRate].
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
  void setDate(Date? d) {
    var next = draft.copyWith(date: d);
    if (_paymentDateFollowsDate && d != null && next.paymentDate != null) {
      next = next.copyWith(paymentDate: d);
    }
    updateDraft(next);
  }

  /// The user's own payment date — from here on it no longer follows the
  /// expense date.
  void setPaymentDate(Date? d) {
    _paymentDateFollowsDate = false;
    updateDraft(draft.copyWith(paymentDate: d));
  }

  void setPaymentTypeId(String v) =>
      updateDraft(draft.copyWith(paymentTypeId: v));
  void setTransactionReference(String v) =>
      updateDraft(draft.copyWith(transactionReference: v));
  void setTransactionId(String v) =>
      updateDraft(draft.copyWith(transactionId: v));
  void setBankId(String v) => updateDraft(draft.copyWith(bankId: v));
  void setAmount(String input) {
    final amount =
        parseDecimal(input, useCommaAsDecimalPlace: useCommaAsDecimalPlace) ??
        Decimal.zero;
    var d = draft.copyWith(amount: amount);
    // Keep the converted (foreign) amount in step with the entered amount.
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
  void setUsesInclusiveTaxes(bool v) {
    _userTouchedInclusive = true;
    updateDraft(draft.copyWith(usesInclusiveTaxes: v));
  }

  void setCalculateTaxByAmount(bool v) =>
      updateDraft(draft.copyWith(calculateTaxByAmount: v));
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

/// Empty draft for new expenses. Defaults match admin-portal's create
/// factory: `exchange_rate = 1`, `date = today`, and the rest are zero /
/// empty until the user picks values. Currency cascades are seeded in the
/// edit screen's identity section: the vendor's currency → `currencyId` and
/// the client's currency → `invoiceCurrencyId` (each only when still empty).
Expense emptyExpense() => Expense(
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
