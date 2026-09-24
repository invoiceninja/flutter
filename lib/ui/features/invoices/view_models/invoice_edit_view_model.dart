import 'package:decimal/decimal.dart';

import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/data/models/domain/invoice_status.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/invoice_repository.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/domain/billing/invoice_lock.dart';
import 'package:admin/ui/features/billing_shared/view_models/billing_doc_edit_view_model.dart';

/// Drives the Invoice edit + create screen. The shared fields, setters and
/// bridges come from [BillingDocEditViewModel] through [_invoiceWriter];
/// what is the invoice's own lives here — its repository calls (with the
/// lock backstop), [validate], the balance rule in [copyWithStampedTotals]
/// and the auto-bill toggle.
class InvoiceEditViewModel extends BillingDocEditViewModel<Invoice>
    with BillingDocPartialSetters<Invoice> {
  InvoiceEditViewModel({
    required this.repo,
    required this.companyId,
    required this.clientRequiredMessage,
    required this.crossClientLineItemsMessage,
    required this.partialInvalidMessage,
    Invoice? existing,
    Invoice? cloneFrom,
    super.currencyPrecision,
    super.useCommaAsDecimalPlace,
    super.sync,
    super.connectivity,
  }) : super(
         writer: _invoiceWriter,
         initialDraft: cloneFrom ?? existing ?? emptyInvoice(),
         original: existing,
         companyId: companyId,
       );

  final InvoiceRepository repo;
  @override
  final String companyId;

  /// Localized "please select a client" — injected from the screen's
  /// `buildVm` (VMs have no `BuildContext` to localize with).
  final String clientRequiredMessage;

  /// Localized "all tasks/expenses must belong to the doc's client" —
  /// injected from the screen (same reason as `clientRequiredMessage`).
  final String crossClientLineItemsMessage;

  /// Localized "must be greater than zero and less than the total" — the
  /// inline error for an out-of-range partial-payment amount (`partial_value`).
  final String partialInvalidMessage;

  @override
  Map<String, List<String>> validate() {
    final errors = <String, List<String>>{
      if (draft.clientId.isEmpty) 'client_id': [clientRequiredMessage],
      ...validateCrossClient(crossClientLineItemsMessage),
    };
    // Partial-payment amount must sit within (0, total]. v1 rejects negative
    // and partial > total; zero (no partial payment) is fine. Uses the
    // fallback-precision total — adequate for an inequality guard.
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
  Future<SaveResult<Invoice>> createDocument(
    Invoice draft, {
    Map<String, String>? extraQuery,
    String? existingTempId,
  }) => repo.create(
    companyId: companyId,
    draft: draft,
    extraQuery: extraQuery,
    existingTempId: existingTempId,
  );

  @override
  Future<SaveResult<Invoice>> saveDocument(
    Invoice draft, {
    Map<String, String>? extraQuery,
  }) async {
    try {
      return await repo.save(
        companyId: companyId,
        invoice: draft,
        extraQuery: extraQuery,
      );
    } on InvoiceLockedException catch (e) {
      // Unreachable through the UI (the action-dispatch gate and the
      // edit-screen guard both hard-block first); this is the repo backstop
      // for any future / deep-link caller. Surface it through the standard
      // save-error path instead of a raw exception toString. The detail
      // text is intentionally English — this path is never user-visible in
      // normal flows, and the VM has no BuildContext to localize with.
      throw ValidationException(_lockedSaveMessage(e.reason), const {});
    }
  }

  String _lockedSaveMessage(InvoiceLockReason reason) {
    switch (reason) {
      case InvoiceLockReason.paid:
        return 'Paid invoices are locked';
      case InvoiceLockReason.sent:
        return 'Sent invoices are locked';
      case InvoiceLockReason.endOfMonth:
        return 'Invoices are locked at the end of the month';
      case InvoiceLockReason.server:
      case InvoiceLockReason.none:
        return 'This invoice is locked';
    }
  }

  void resetToEmpty() => reset(emptyDraft: emptyInvoice());

  @override
  Invoice copyWithStampedTotals(
    Invoice draft, {
    required Decimal amount,
    required Decimal taxAmount,
  }) => draft.copyWith(
    amount: amount,
    // A DRAFT keeps its stored balance (0). The server does the same —
    // `InvoiceSum::setCalculatedAttributes` only recomputes `balance` when
    // `status_id != STATUS_DRAFT`, and `balance` isn't `$fillable`, so the
    // value we PUT is discarded anyway. Stamping `amount - paidToDate` here
    // gave drafts a non-zero local balance, which lit up the red "Past Due"
    // pill on back-dated drafts and — worse — made them eligible targets for
    // the payment screen's "Auto-apply oldest" (whose server-side
    // `applyPayment` calls `markSent()` first, so a draft would get sent AND
    // paid).
    balance: draft.isDraft ? draft.balance : amount - draft.paidToDate,
    taxAmount: taxAmount,
  );

  void setAutoBillEnabled(bool v) =>
      updateDraft(draft.copyWith(autoBillEnabled: v));

  @override
  Invoice Function(Invoice, Decimal) get partialWriter =>
      (d, v) => d.copyWith(partial: v);

  @override
  Invoice Function(Invoice, Date?) get partialDueDateWriter =>
      (d, v) => d.copyWith(partialDueDate: v);
}

/// The shared fields, written onto an [Invoice] — see [BillingDocWriter].
final _invoiceWriter = BillingDocWriter<Invoice>(
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

/// Empty draft for new invoices. Defaults match admin-portal's create
/// factory: `exchange_rate = 1`, `date = today`, status = Draft, and the
/// rest are zero / empty. Currency / client cascade is handled in the
/// edit screen by reading the active company settings.
Invoice emptyInvoice() => Invoice(
  id: '',
  number: '',
  poNumber: '',
  date: Date.today(),
  dueDate: null,
  partialDueDate: null,
  statusId: InvoiceStatus.draft,
  clientId: '',
  vendorId: '',
  projectId: '',
  designId: '',
  assignedUserId: '',
  userId: '',
  locationId: '',
  subscriptionId: '',
  parentInvoiceId: '',
  recurringId: '',
  amount: Decimal.zero,
  balance: Decimal.zero,
  paidToDate: Decimal.zero,
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
  reminder1Sent: null,
  reminder2Sent: null,
  reminder3Sent: null,
  reminderLastSent: null,
  reminderSchedule: '',
  frequencyId: '',
  nextSendDate: null,
  nextSendDatetime: '',
  lastSentDate: null,
  remainingCycles: 0,
  dueDateDays: '',
  autoBill: '',
  autoBillEnabled: false,
  isLocked: false,
  isDeleted: false,
  updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  archivedAt: null,
);
