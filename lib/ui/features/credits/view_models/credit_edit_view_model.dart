import 'package:decimal/decimal.dart';

import 'package:admin/data/models/domain/billing/invitation.dart';
import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/data/models/domain/credit.dart';
import 'package:admin/data/models/domain/credit_status.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/credit_repository.dart';
import 'package:admin/domain/billing/totals_calculator.dart';
import 'package:admin/ui/features/billing_shared/view_models/billing_doc_edit_view_model.dart';
import 'package:admin/utils/formatting.dart';

/// Drives the Credit edit + create screen. Mirrors [QuoteEditViewModel]'s
/// shape — only the entity-specific bridge + simple per-field setters live
/// here; all line-item / invitation / eInvoice / totals plumbing comes
/// from [GenericBillingDocEditViewModel].
class CreditEditViewModel extends GenericBillingDocEditViewModel<Credit> {
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
         initialDraft: cloneFrom ?? existing ?? emptyCredit(),
         original: existing,
         companyId: companyId,
       );

  final CreditRepository repo;
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
  Future<SaveResult<Credit>> performSave() async {
    // One-shot SAVE-PARAM query (mark_sent) set by the edit-screen action
    // bar; null on a plain Save.
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
    return repo.save(
      companyId: companyId,
      credit: draft,
      extraQuery: extraQuery,
    );
  }

  void resetToEmpty() => reset(emptyDraft: emptyCredit());

  // ── GenericBillingDocEditViewModel bridge ──────────────────────────

  @override
  List<LineItem> lineItemsOf(Credit draft) => draft.lineItems;

  @override
  Credit copyWithLineItems(Credit draft, List<LineItem> items) =>
      draft.copyWith(lineItems: items);

  @override
  List<Invitation> invitationsOf(Credit draft) => draft.invitations;

  @override
  Credit copyWithInvitations(Credit draft, List<Invitation> invitations) =>
      draft.copyWith(invitations: invitations);

  @override
  String clientIdOf(Credit draft) => draft.clientId;

  @override
  Credit copyWithClientId(Credit draft, String clientId) =>
      draft.copyWith(clientId: clientId);

  @override
  Map<String, dynamic>? eInvoiceOf(Credit draft) => draft.eInvoice;

  @override
  Credit copyWithEInvoice(Credit draft, Map<String, dynamic>? eInvoice) =>
      draft.copyWith(eInvoice: eInvoice);

  @override
  BillingTotalsInput totalsInputOf(Credit d) => BillingTotalsInput(
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

  // ── Setters ────────────────────────────────────────────────────────

  void setClientId(String v) => updateDraft(draft.copyWith(clientId: v));
  void setTagIds(List<String> ids) => updateDraft(draft.copyWith(tagIds: ids));
  void setVendorId(String v) => updateDraft(draft.copyWith(vendorId: v));
  void setProjectId(String v) => updateDraft(draft.copyWith(projectId: v));
  void setAssignedUserId(String v) =>
      updateDraft(draft.copyWith(assignedUserId: v));
  void setNumber(String v) => updateDraft(draft.copyWith(number: v));
  void setPoNumber(String v) => updateDraft(draft.copyWith(poNumber: v));
  void setDate(Date? d) => updateDraft(draft.copyWith(date: d));
  void setDueDate(Date? d) => updateDraft(draft.copyWith(dueDate: d));
  void setPartialDueDate(Date? d) =>
      updateDraft(draft.copyWith(partialDueDate: d));
  void setPartial(String input) => updateDraft(
    draft.copyWith(
      partial:
          parseDecimal(input, useCommaAsDecimalPlace: useCommaAsDecimalPlace) ??
          Decimal.zero,
    ),
  );
  void setDesignId(String v) => updateDraft(draft.copyWith(designId: v));
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

  void setCustomValue1(String v) =>
      updateDraft(draft.copyWith(customValue1: v));
  void setCustomValue2(String v) =>
      updateDraft(draft.copyWith(customValue2: v));
  void setCustomValue3(String v) =>
      updateDraft(draft.copyWith(customValue3: v));
  void setCustomValue4(String v) =>
      updateDraft(draft.copyWith(customValue4: v));

  void setPublicNotes(String v) => updateDraft(draft.copyWith(publicNotes: v));
  void setPrivateNotes(String v) =>
      updateDraft(draft.copyWith(privateNotes: v));
  void setTerms(String v) => updateDraft(draft.copyWith(terms: v));
  void setFooter(String v) => updateDraft(draft.copyWith(footer: v));
}

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
