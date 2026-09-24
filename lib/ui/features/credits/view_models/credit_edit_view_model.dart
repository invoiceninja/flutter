import 'package:decimal/decimal.dart';

import 'package:admin/data/models/domain/credit.dart';
import 'package:admin/data/models/domain/credit_status.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/credit_repository.dart';
import 'package:admin/ui/features/billing_shared/view_models/billing_doc_edit_view_model.dart';

/// Drives the Credit edit + create screen. The shared fields, setters and
/// bridges come from [BillingDocEditViewModel] through [_creditWriter]; what
/// is the credit's own lives here — its repository calls, [validate] (a
/// credit's total may be negative) and the balance rule in
/// [copyWithStampedTotals].
class CreditEditViewModel extends BillingDocEditViewModel<Credit>
    with BillingDocPartialSetters<Credit> {
  CreditEditViewModel({
    required this.repo,
    required this.companyId,
    required this.clientRequiredMessage,
    required this.crossClientLineItemsMessage,
    required this.partialInvalidMessage,
    Credit? existing,
    Credit? cloneFrom,
    super.currencyPrecision,
    super.useCommaAsDecimalPlace,
    super.sync,
    super.connectivity,
  }) : super(
         writer: _creditWriter,
         initialDraft: cloneFrom ?? existing ?? emptyCredit(),
         original: existing,
         companyId: companyId,
       );

  final CreditRepository repo;
  @override
  final String companyId;

  /// Localized "please select a client" — injected from the screen's
  /// `buildVm` (VMs have no `BuildContext` to localize with).
  final String clientRequiredMessage;
  final String crossClientLineItemsMessage;

  /// Localized "must be greater than zero and less than the total" — the inline
  /// error for an out-of-range partial-deposit amount. Mirrors invoice.
  final String partialInvalidMessage;

  @override
  Map<String, List<String>> validate() => {
    if (draft.clientId.isEmpty) 'client_id': [clientRequiredMessage],
    // Partial deposit must sit within [0, total]; uses the fallback-precision
    // total — adequate for an inequality guard (mirrors InvoiceEditViewModel).
    // Unlike invoices/quotes, a Credit's total can be NEGATIVE — the
    // supported negative-credit / receivable flow that `markPaid` targets
    // (credit_actions.dart gates markPaid on `amount < 0`; the server's
    // Credit MarkPaid requires a negative value). So only enforce the
    // `partial <= total` upper bound for non-negative totals; otherwise a
    // default-zero `partial` (0 > negativeTotal) spuriously blocks the save.
    if (draft.partial < Decimal.zero ||
        (totals.total >= Decimal.zero && draft.partial > totals.total))
      'partial': [partialInvalidMessage],
    ...validateCrossClient(crossClientLineItemsMessage),
  };

  @override
  bool draftIsNonEmpty() {
    final d = draft;
    return d.clientId.isNotEmpty ||
        d.number.isNotEmpty ||
        d.poNumber.isNotEmpty ||
        d.publicNotes.isNotEmpty ||
        d.privateNotes.isNotEmpty ||
        d.terms.isNotEmpty ||
        d.footer.isNotEmpty ||
        d.lineItems.isNotEmpty ||
        d.amount != Decimal.zero ||
        d.discount != Decimal.zero;
  }

  @override
  Future<SaveResult<Credit>> createDocument(
    Credit draft, {
    Map<String, String>? extraQuery,
    String? existingTempId,
  }) => repo.create(
    companyId: companyId,
    draft: draft,
    extraQuery: extraQuery,
    existingTempId: existingTempId,
  );

  @override
  Future<SaveResult<Credit>> saveDocument(
    Credit draft, {
    Map<String, String>? extraQuery,
  }) => repo.save(companyId: companyId, credit: draft, extraQuery: extraQuery);

  void resetToEmpty() => reset(emptyDraft: emptyCredit());

  @override
  Credit copyWithStampedTotals(
    Credit draft, {
    required Decimal amount,
    required Decimal taxAmount,
  }) => draft.copyWith(
    amount: amount,
    // Drafts keep their stored balance — see the note on
    // `InvoiceEditViewModel.copyWithStampedTotals`; the server's
    // `InvoiceSum::setCalculatedAttributes` skips draft balances too.
    balance: draft.isDraft ? draft.balance : amount - draft.paidToDate,
    taxAmount: taxAmount,
  );

  @override
  Credit Function(Credit, Decimal) get partialWriter =>
      (d, v) => d.copyWith(partial: v);

  @override
  Credit Function(Credit, Date?) get partialDueDateWriter =>
      (d, v) => d.copyWith(partialDueDate: v);
}

/// The shared fields, written onto a [Credit] — see [BillingDocWriter].
final _creditWriter = BillingDocWriter<Credit>(
  lineItems: (d, v) => d.copyWith(lineItems: v),
  invitations: (d, v) => d.copyWith(invitations: v),
  clientId: (d, v) => d.copyWith(clientId: v),
  eInvoice: (d, v) => d.copyWith(eInvoice: v),
  number: (d, v) => d.copyWith(number: v),
  poNumber: (d, v) => d.copyWith(poNumber: v),
  date: (d, v) => d.copyWith(date: v),
  dueDate: (d, v) => d.copyWith(dueDate: v),
  vendorId: (d, v) => d.copyWith(vendorId: v),
  projectId: (d, v) => d.copyWith(projectId: v),
  assignedUserId: (d, v) => d.copyWith(assignedUserId: v),
  designId: (d, v) => d.copyWith(designId: v),
  tagIds: (d, v) => d.copyWith(tagIds: v),
  exchangeRate: (d, v) => d.copyWith(exchangeRate: v),
  discount: (d, v, isAmount) =>
      d.copyWith(discount: v, isAmountDiscount: isAmount),
  usesInclusiveTaxes: (d, v) => d.copyWith(usesInclusiveTaxes: v),
  taxName1: (d, v) => d.copyWith(taxName1: v),
  taxName2: (d, v) => d.copyWith(taxName2: v),
  taxName3: (d, v) => d.copyWith(taxName3: v),
  taxRate1: (d, v) => d.copyWith(taxRate1: v),
  taxRate2: (d, v) => d.copyWith(taxRate2: v),
  taxRate3: (d, v) => d.copyWith(taxRate3: v),
  customSurcharge1: (d, v) => d.copyWith(customSurcharge1: v),
  customSurcharge2: (d, v) => d.copyWith(customSurcharge2: v),
  customSurcharge3: (d, v) => d.copyWith(customSurcharge3: v),
  customSurcharge4: (d, v) => d.copyWith(customSurcharge4: v),
  customTaxes1: (d, v) => d.copyWith(customTaxes1: v),
  customTaxes2: (d, v) => d.copyWith(customTaxes2: v),
  customTaxes3: (d, v) => d.copyWith(customTaxes3: v),
  customTaxes4: (d, v) => d.copyWith(customTaxes4: v),
  customValue1: (d, v) => d.copyWith(customValue1: v),
  customValue2: (d, v) => d.copyWith(customValue2: v),
  customValue3: (d, v) => d.copyWith(customValue3: v),
  customValue4: (d, v) => d.copyWith(customValue4: v),
  publicNotes: (d, v) => d.copyWith(publicNotes: v),
  privateNotes: (d, v) => d.copyWith(privateNotes: v),
  terms: (d, v) => d.copyWith(terms: v),
  footer: (d, v) => d.copyWith(footer: v),
);

Credit emptyCredit() => Credit(
  id: '',
  number: '',
  poNumber: '',
  date: Date.today(),
  dueDate: null,
  partialDueDate: null,
  statusId: CreditStatus.draft,
  clientId: '',
  vendorId: '',
  projectId: '',
  designId: '',
  assignedUserId: '',
  userId: '',
  locationId: '',
  amount: Decimal.zero,
  balance: Decimal.zero,
  paidToDate: Decimal.zero,
  partial: Decimal.zero,
  taxAmount: Decimal.zero,
  discount: Decimal.zero,
  isAmountDiscount: false,
  exchangeRate: Decimal.one,
  taxName1: '',
  taxName2: '',
  taxName3: '',
  taxRate1: Decimal.zero,
  taxRate2: Decimal.zero,
  taxRate3: Decimal.zero,
  usesInclusiveTaxes: false,
  customSurcharge1: Decimal.zero,
  customSurcharge2: Decimal.zero,
  customSurcharge3: Decimal.zero,
  customSurcharge4: Decimal.zero,
  customTaxes1: false,
  customTaxes2: false,
  customTaxes3: false,
  customTaxes4: false,
  publicNotes: '',
  privateNotes: '',
  terms: '',
  footer: '',
  customValue1: '',
  customValue2: '',
  customValue3: '',
  customValue4: '',
  isDeleted: false,
  updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  archivedAt: null,
);
