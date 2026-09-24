import 'package:decimal/decimal.dart';

import 'package:admin/data/models/domain/recurring_invoice.dart';
import 'package:admin/data/models/domain/recurring_invoice_status.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/recurring_invoice_repository.dart';
import 'package:admin/ui/features/billing_shared/view_models/billing_doc_edit_view_model.dart';

/// Drives the RecurringInvoice edit + create screen. The shared fields,
/// setters and bridges come from [BillingDocEditViewModel] through
/// [_recurringInvoiceWriter]; what is the recurring invoice's own lives here
/// — its repository calls, [validate], the balance rule and the schedule
/// setters (frequency, next send date, remaining cycles, auto-bill).
class RecurringInvoiceEditViewModel
    extends BillingDocEditViewModel<RecurringInvoice> {
  RecurringInvoiceEditViewModel({
    required this.repo,
    required this.companyId,
    required this.clientRequiredMessage,
    required this.crossClientLineItemsMessage,
    RecurringInvoice? existing,
    RecurringInvoice? cloneFrom,
    super.currencyPrecision,
    super.useCommaAsDecimalPlace,
    super.sync,
    super.connectivity,
  }) : super(
         writer: _recurringInvoiceWriter,
         initialDraft: cloneFrom ?? existing ?? emptyRecurringInvoice(),
         original: existing,
         companyId: companyId,
       );

  final RecurringInvoiceRepository repo;
  @override
  final String companyId;

  /// Localized "please select a client" — injected from the screen's
  /// `buildVm` (VMs have no `BuildContext` to localize with).
  final String clientRequiredMessage;
  final String crossClientLineItemsMessage;

  @override
  Map<String, List<String>> validate() => {
    if (draft.clientId.isEmpty) 'client_id': [clientRequiredMessage],
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
        d.discount != Decimal.zero ||
        // A new recurring invoice starts monthly, so only a different choice
        // is input — this used to test `isNotEmpty`, which the default always
        // passed, and every untouched new form asked to discard its changes.
        d.frequencyId != kDefaultRecurringFrequencyId;
  }

  @override
  Future<SaveResult<RecurringInvoice>> createDocument(
    RecurringInvoice draft, {
    Map<String, String>? extraQuery,
    String? existingTempId,
  }) => repo.create(
    companyId: companyId,
    draft: draft,
    extraQuery: extraQuery,
    existingTempId: existingTempId,
  );

  @override
  Future<SaveResult<RecurringInvoice>> saveDocument(
    RecurringInvoice draft, {
    Map<String, String>? extraQuery,
  }) => repo.save(
    companyId: companyId,
    recurringInvoice: draft,
    extraQuery: extraQuery,
  );

  void resetToEmpty() => reset(emptyDraft: emptyRecurringInvoice());

  @override
  RecurringInvoice copyWithStampedTotals(
    RecurringInvoice draft, {
    required Decimal amount,
    required Decimal taxAmount,
  }) => draft.copyWith(amount: amount, balance: amount, taxAmount: taxAmount);

  // Recurring-specific setters

  void setFrequencyId(String v) => updateDraft(draft.copyWith(frequencyId: v));
  // Only next_send_date is user-editable. next_send_datetime is server-managed
  // (recomputed from this date + the company send time) — intentionally left
  // untouched here; see RecurringInvoice.toApiJson.
  void setNextSendDate(Date? d) => updateDraft(draft.copyWith(nextSendDate: d));
  void setRemainingCycles(int v) =>
      updateDraft(draft.copyWith(remainingCycles: v));
  void setDueDateDays(String v) => updateDraft(draft.copyWith(dueDateDays: v));
  // `auto_bill_enabled` is server-derived from `auto_bill` for recurring
  // invoices (Store/UpdateRecurringInvoiceRequest::setAutoBillFlag: always /
  // optout → true, else false) and overwritten on save — so there is no
  // separate user toggle. We mirror that derivation locally so the optimistic
  // Drift copy matches the server before the save response returns.
  void setAutoBill(String v) => updateDraft(
    draft.copyWith(
      autoBill: v,
      autoBillEnabled: v == 'always' || v == 'optout',
    ),
  );
}

/// The shared fields, written onto a [RecurringInvoice] — see [BillingDocWriter].
final _recurringInvoiceWriter = BillingDocWriter<RecurringInvoice>(
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

/// Monthly — what a new recurring invoice starts on.
const kDefaultRecurringFrequencyId = '5';

RecurringInvoice emptyRecurringInvoice() => RecurringInvoice(
  id: '',
  number: '',
  poNumber: '',
  date: Date.today(),
  dueDate: null,
  partialDueDate: null,
  statusId: RecurringInvoiceStatus.draft,
  clientId: '',
  vendorId: '',
  projectId: '',
  designId: '',
  assignedUserId: '',
  userId: '',
  locationId: '',
  subscriptionId: '',
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
  // Defaults mirror admin-portal / React new-recurring-invoice forms: monthly
  // frequency, "use payment terms", endless cycles. An empty frequency_id is a
  // 422 risk on save and a poor blank-form UX.
  frequencyId: kDefaultRecurringFrequencyId,
  nextSendDate: null,
  nextSendDatetime: '',
  lastSentDate: null,
  remainingCycles: -1, // endless
  dueDateDays: 'terms',
  autoBill: 'off',
  autoBillEnabled: false,
  isDeleted: false,
  updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  archivedAt: null,
);
