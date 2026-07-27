import 'package:decimal/decimal.dart';

import 'package:admin/data/models/domain/billing/invitation.dart';
import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/data/models/domain/invoice_status.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/invoice_repository.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/domain/billing/invoice_lock.dart';
import 'package:admin/domain/billing/totals_calculator.dart';
import 'package:admin/ui/features/billing_shared/view_models/billing_doc_edit_view_model.dart';
import 'package:admin/utils/formatting.dart';

/// Drives the Invoice edit + create screen. Inherits the shared
/// line-item / invitation / eInvoice / totals plumbing from
/// [GenericBillingDocEditViewModel]; this class only owns the
/// invoice-specific bridge (`copyWith*` overrides + `performSave` +
/// per-field simple setters).
class InvoiceEditViewModel extends GenericBillingDocEditViewModel<Invoice> {
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
         initialDraft: cloneFrom ?? existing ?? emptyInvoice(),
         original: existing,
         companyId: companyId,
       );

  final InvoiceRepository repo;
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
  Future<SaveResult<Invoice>> performSave() async {
    // One-shot SAVE-PARAM query (mark_sent / paid / cancel / auto_bill)
    // set by the edit-screen action bar; null on a plain Save.
    final extraQuery = consumeSaveQuery();
    if (isCreate) {
      final result = await repo.create(
        companyId: companyId,
        draft: draft,
        extraQuery: extraQuery,
        existingTempId: recoveryTempId,
      );
      rememberCreateTempId(result.entity.id);
      return result;
    }
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

  // ── GenericBillingDocEditViewModel bridge ──────────────────────────

  @override
  List<LineItem> lineItemsOf(Invoice draft) => draft.lineItems;

  @override
  Invoice copyWithLineItems(Invoice draft, List<LineItem> items) =>
      draft.copyWith(lineItems: items);

  @override
  List<Invitation> invitationsOf(Invoice draft) => draft.invitations;

  @override
  Invoice copyWithInvitations(Invoice draft, List<Invitation> invitations) =>
      draft.copyWith(invitations: invitations);

  @override
  String clientIdOf(Invoice draft) => draft.clientId;

  @override
  Invoice copyWithClientId(Invoice draft, String clientId) =>
      draft.copyWith(clientId: clientId);

  @override
  Map<String, dynamic>? eInvoiceOf(Invoice draft) => draft.eInvoice;

  @override
  Invoice copyWithEInvoice(Invoice draft, Map<String, dynamic>? eInvoice) =>
      draft.copyWith(eInvoice: eInvoice);

  @override
  BillingTotalsInput totalsInputOf(Invoice d) => BillingTotalsInput(
    lineItems: d.lineItems,
    discount: d.discount,
    isAmountDiscount: d.isAmountDiscount,
    usesInclusiveTaxes: d.usesInclusiveTaxes,
    taxName1: d.taxName1,
    taxRate1: d.taxRate1,
    taxName2: d.taxName2,
    taxRate2: d.taxRate2,
    taxName3: d.taxName3,
    taxRate3: d.taxRate3,
    customSurcharge1: d.customSurcharge1,
    customSurcharge2: d.customSurcharge2,
    customSurcharge3: d.customSurcharge3,
    customSurcharge4: d.customSurcharge4,
    customTaxes1: d.customTaxes1,
    customTaxes2: d.customTaxes2,
    customTaxes3: d.customTaxes3,
    customTaxes4: d.customTaxes4,
  );

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

  // ── Identity / dates ───────────────────────────────────────────────

  void setClientId(String v) => updateDraft(draft.copyWith(clientId: v));
  void setTagIds(List<String> ids) => updateDraft(draft.copyWith(tagIds: ids));
  void setVendorId(String v) => updateDraft(draft.copyWith(vendorId: v));
  void setLocationId(String v) => updateDraft(draft.copyWith(locationId: v));
  void setProjectId(String v) => updateDraft(draft.copyWith(projectId: v));
  void setSubscriptionId(String v) =>
      updateDraft(draft.copyWith(subscriptionId: v));
  void setAssignedUserId(String v) =>
      updateDraft(draft.copyWith(assignedUserId: v));
  void setNumber(String v) => updateDraft(draft.copyWith(number: v));
  void setPoNumber(String v) => updateDraft(draft.copyWith(poNumber: v));
  void setDate(Date? d) => updateDraft(draft.copyWith(date: d));
  void setDueDate(Date? d) => updateDraft(draft.copyWith(dueDate: d));
  void setPartialDueDate(Date? d) =>
      updateDraft(draft.copyWith(partialDueDate: d));

  // ── Money + amounts ────────────────────────────────────────────────

  void setPartial(String input) => updateDraft(
    draft.copyWith(
      partial:
          parseDecimal(input, useCommaAsDecimalPlace: useCommaAsDecimalPlace) ??
          Decimal.zero,
    ),
  );
  void setExchangeRate(String input) => updateDraft(
    draft.copyWith(
      exchangeRate:
          parseDecimal(
            input,
            zeroIsNull: true,
            useCommaAsDecimalPlace: useCommaAsDecimalPlace,
          ) ??
          Decimal.one,
    ),
  );
  void setDiscount(String input, {required bool isAmount}) => updateDraft(
    draft.copyWith(
      discount:
          parseDecimal(input, useCommaAsDecimalPlace: useCommaAsDecimalPlace) ??
          Decimal.zero,
      isAmountDiscount: isAmount,
    ),
  );

  // ── Design + tax ───────────────────────────────────────────────────

  void setDesignId(String v) => updateDraft(draft.copyWith(designId: v));
  void setUsesInclusiveTaxes(bool v) =>
      updateDraft(draft.copyWith(usesInclusiveTaxes: v));
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

  // ── Surcharges ─────────────────────────────────────────────────────

  void setCustomSurcharge1(String input) => updateDraft(
    draft.copyWith(
      customSurcharge1:
          parseDecimal(input, useCommaAsDecimalPlace: useCommaAsDecimalPlace) ??
          Decimal.zero,
    ),
  );
  void setCustomSurcharge2(String input) => updateDraft(
    draft.copyWith(
      customSurcharge2:
          parseDecimal(input, useCommaAsDecimalPlace: useCommaAsDecimalPlace) ??
          Decimal.zero,
    ),
  );
  void setCustomSurcharge3(String input) => updateDraft(
    draft.copyWith(
      customSurcharge3:
          parseDecimal(input, useCommaAsDecimalPlace: useCommaAsDecimalPlace) ??
          Decimal.zero,
    ),
  );
  void setCustomSurcharge4(String input) => updateDraft(
    draft.copyWith(
      customSurcharge4:
          parseDecimal(input, useCommaAsDecimalPlace: useCommaAsDecimalPlace) ??
          Decimal.zero,
    ),
  );
  void setCustomTaxes1(bool v) => updateDraft(draft.copyWith(customTaxes1: v));
  void setCustomTaxes2(bool v) => updateDraft(draft.copyWith(customTaxes2: v));
  void setCustomTaxes3(bool v) => updateDraft(draft.copyWith(customTaxes3: v));
  void setCustomTaxes4(bool v) => updateDraft(draft.copyWith(customTaxes4: v));

  // ── Custom fields ──────────────────────────────────────────────────

  void setCustomValue1(String v) =>
      updateDraft(draft.copyWith(customValue1: v));
  void setCustomValue2(String v) =>
      updateDraft(draft.copyWith(customValue2: v));
  void setCustomValue3(String v) =>
      updateDraft(draft.copyWith(customValue3: v));
  void setCustomValue4(String v) =>
      updateDraft(draft.copyWith(customValue4: v));

  // ── Notes / content ────────────────────────────────────────────────

  void setPublicNotes(String v) => updateDraft(draft.copyWith(publicNotes: v));
  void setPrivateNotes(String v) =>
      updateDraft(draft.copyWith(privateNotes: v));
  void setTerms(String v) => updateDraft(draft.copyWith(terms: v));
  void setFooter(String v) => updateDraft(draft.copyWith(footer: v));

  // Line-item collection ops, invitation toggle, and eInvoice field
  // updates all live on [GenericBillingDocEditViewModel] — see the
  // copyWith* / *Of bridge methods above.

  // ── Recurring fields (used when this is a RecurringInvoice) ────────

  void setFrequencyId(String v) => updateDraft(draft.copyWith(frequencyId: v));
  void setNextSendDate(Date? d) => updateDraft(draft.copyWith(nextSendDate: d));
  void setRemainingCycles(int v) =>
      updateDraft(draft.copyWith(remainingCycles: v));
  void setAutoBill(String v) => updateDraft(draft.copyWith(autoBill: v));
  void setAutoBillEnabled(bool v) =>
      updateDraft(draft.copyWith(autoBillEnabled: v));
  void setDueDateDays(String v) => updateDraft(draft.copyWith(dueDateDays: v));
}

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
