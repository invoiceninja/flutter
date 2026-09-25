import 'package:decimal/decimal.dart';

import 'package:admin/data/models/domain/quote.dart';
import 'package:admin/data/models/domain/quote_status.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/quote_repository.dart';
import 'package:admin/ui/features/billing_shared/view_models/billing_doc_edit_view_model.dart';

/// Drives the Quote edit + create screen. The shared fields, setters and
/// bridges come from [BillingDocEditViewModel] through [_quoteWriter]; what
/// is the quote's own lives here — its repository calls, [validate] and the
/// balance rule in [copyWithStampedTotals].
class QuoteEditViewModel extends BillingDocEditViewModel<Quote>
    with BillingDocPartialSetters<Quote> {
  QuoteEditViewModel({
    required this.repo,
    required this.companyId,
    required this.clientRequiredMessage,
    required this.crossClientLineItemsMessage,
    required this.partialInvalidMessage,
    Quote? existing,
    Quote? cloneFrom,
    super.currencyPrecision,
    super.useCommaAsDecimalPlace,
    super.sync,
    super.connectivity,
  }) : super(
         writer: _quoteWriter,
         initialDraft: cloneFrom ?? existing ?? emptyQuote(),
         original: existing,
         companyId: companyId,
       );

  final QuoteRepository repo;
  @override
  final String companyId;

  /// Localized "please select a client" — injected from the screen's
  /// `buildVm` (VMs have no `BuildContext` to localize with).
  final String clientRequiredMessage;
  final String crossClientLineItemsMessage;
  final String partialInvalidMessage;

  @override
  Map<String, List<String>> validate() {
    final errors = <String, List<String>>{
      if (draft.clientId.isEmpty) 'client_id': [clientRequiredMessage],
      ...validateCrossClient(crossClientLineItemsMessage),
    };
    // Deposit/partial must sit within [0, total] — mirrors the invoice rule.
    final partial = draft.partial;
    if (partial < Decimal.zero || partial > totals.total) {
      errors['partial'] = [partialInvalidMessage];
    }
    return errors;
  }

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
  Future<SaveResult<Quote>> createDocument(
    Quote draft, {
    Map<String, String>? extraQuery,
    String? existingTempId,
  }) => repo.create(
    companyId: companyId,
    draft: draft,
    extraQuery: extraQuery,
    existingTempId: existingTempId,
  );

  @override
  Future<SaveResult<Quote>> saveDocument(
    Quote draft, {
    Map<String, String>? extraQuery,
  }) => repo.save(companyId: companyId, quote: draft, extraQuery: extraQuery);

  void resetToEmpty() => reset(emptyDraft: emptyQuote());

  @override
  Quote copyWithStampedTotals(
    Quote draft, {
    required Decimal amount,
    required Decimal taxAmount,
  }) => draft.copyWith(
    amount: amount,
    // Drafts keep their stored balance — `InvoiceSum::setCalculatedAttributes`
    // skips a draft's balance for every doc type, and `balance` isn't
    // `$fillable`, so the value we PUT is discarded anyway. Stamping one
    // locally showed a balance the server would report as 0.
    balance: draft.isDraft ? draft.balance : amount,
    taxAmount: taxAmount,
  );

  @override
  Quote Function(Quote, Decimal) get partialWriter =>
      (d, v) => d.copyWith(partial: v);

  @override
  Quote Function(Quote, Date?) get partialDueDateWriter =>
      (d, v) => d.copyWith(partialDueDate: v);
}

/// The shared fields, written onto a [Quote] — see [BillingDocWriter].
final _quoteWriter = BillingDocWriter<Quote>(
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

Quote emptyQuote() => Quote(
  id: '',
  number: '',
  poNumber: '',
  date: Date.today(),
  dueDate: null,
  partialDueDate: null,
  statusId: QuoteStatus.draft,
  clientId: '',
  vendorId: '',
  projectId: '',
  designId: '',
  assignedUserId: '',
  userId: '',
  locationId: '',
  subscriptionId: '',
  invoiceId: '',
  amount: Decimal.zero,
  balance: Decimal.zero,
  taxAmount: Decimal.zero,
  discount: Decimal.zero,
  partial: Decimal.zero,
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
