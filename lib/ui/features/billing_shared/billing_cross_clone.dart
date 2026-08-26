import 'package:decimal/decimal.dart';

import 'package:admin/data/models/domain/billing/invitation.dart';
import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/data/models/domain/credit.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/data/models/domain/purchase_order.dart';
import 'package:admin/data/models/domain/quote.dart';
import 'package:admin/data/models/domain/recurring_invoice.dart';
import 'package:admin/ui/features/credits/view_models/credit_edit_view_model.dart'
    show emptyCredit;
import 'package:admin/ui/features/invoices/view_models/invoice_edit_view_model.dart'
    show emptyInvoice;
import 'package:admin/ui/features/purchase_orders/view_models/purchase_order_edit_view_model.dart'
    show emptyPurchaseOrder;
import 'package:admin/ui/features/quotes/view_models/quote_edit_view_model.dart'
    show emptyQuote;
import 'package:admin/ui/features/recurring_invoices/view_models/recurring_invoice_edit_view_model.dart'
    show emptyRecurringInvoice;

/// Cross-type clone between the five billing documents (Invoice / Quote /
/// Credit / PurchaseOrder / RecurringInvoice), built entirely client-side.
///
/// The server's bulk `performAction` cross-type clone is unusable: the two
/// paths it wires (invoice→quote, quote→invoice) 500 (an unsaved factory + a
/// runtime-swapped transformer — review #17 / BACKEND.md), and it clones
/// nothing for Credit / PO / Recurring — so a server-routed cross-type clone
/// either 500s or 400s into a dead outbox row while falsely toasting success.
/// Instead ALL cross-type clones are produced on the client (React +
/// admin-portal do the same): an **extract → apply** pair. The extractor pulls
/// the carry-over *content* off the source into a [BillingCloneData]; the
/// applier starts from the target's `empty*()` draft — which already supplies
/// Draft status, today's date and clean accounting fields — and copies that
/// content in. The caller navigates to the target's create screen with the
/// result as `extra:` (those screens accept a same-type `cloneFrom`). Used by
/// every billing-doc action menu's cross-type "clone to …" items.

/// Carry-over content shared by all five billing documents. Holds only the
/// fields that should survive a cross-type clone — never ids, numbers,
/// statuses, dates, balances or other per-document lifecycle state (the
/// target's `empty*()` supplies fresh values for those).
class BillingCloneData {
  const BillingCloneData({
    required this.clientId,
    required this.poNumber,
    required this.assignedUserId,
    required this.discount,
    required this.isAmountDiscount,
    required this.taxName1,
    required this.taxName2,
    required this.taxName3,
    required this.taxRate1,
    required this.taxRate2,
    required this.taxRate3,
    required this.usesInclusiveTaxes,
    required this.customSurcharge1,
    required this.customSurcharge2,
    required this.customSurcharge3,
    required this.customSurcharge4,
    required this.customTaxes1,
    required this.customTaxes2,
    required this.customTaxes3,
    required this.customTaxes4,
    required this.publicNotes,
    required this.privateNotes,
    required this.terms,
    required this.footer,
    required this.customValue1,
    required this.customValue2,
    required this.customValue3,
    required this.customValue4,
    required this.lineItems,
    required this.invitations,
  });

  /// Source client. Empty when the source is a PurchaseOrder (vendor-billed:
  /// the user picks the client on the target create screen).
  final String clientId;
  final String poNumber;
  final String assignedUserId;
  final Decimal discount;
  final bool isAmountDiscount;
  final String taxName1;
  final String taxName2;
  final String taxName3;
  final Decimal taxRate1;
  final Decimal taxRate2;
  final Decimal taxRate3;
  final bool usesInclusiveTaxes;
  final Decimal customSurcharge1;
  final Decimal customSurcharge2;
  final Decimal customSurcharge3;
  final Decimal customSurcharge4;
  final bool customTaxes1;
  final bool customTaxes2;
  final bool customTaxes3;
  final bool customTaxes4;
  final String publicNotes;
  final String privateNotes;
  final String terms;
  final String footer;
  final String customValue1;
  final String customValue2;
  final String customValue3;
  final String customValue4;
  final List<LineItem> lineItems;

  /// Fresh client-contact invitations (every lifecycle field cleared). Empty
  /// when the source is a PurchaseOrder — its invitations are vendor-contact
  /// based and don't transfer to a client document.
  final List<Invitation> invitations;
}

/// Fresh invitations keyed to the same contacts, with every server-side
/// lifecycle field cleared (the new document has never been sent).
List<Invitation> _freshInvitations(List<Invitation> src) => [
  for (final i in src)
    Invitation(
      id: '',
      key: '',
      link: '',
      clientContactId: i.clientContactId,
      vendorContactId: i.vendorContactId,
      sentDate: '',
      viewedDate: '',
      openedDate: '',
      emailStatus: '',
      emailError: '',
      messageId: '',
    ),
];

// ---------------------------------------------------------------------------
// Extractors — source document → BillingCloneData
// ---------------------------------------------------------------------------

BillingCloneData billingCloneFromInvoice(Invoice src) => BillingCloneData(
  clientId: src.clientId,
  poNumber: src.poNumber,
  assignedUserId: src.assignedUserId,
  discount: src.discount,
  isAmountDiscount: src.isAmountDiscount,
  taxName1: src.taxName1,
  taxName2: src.taxName2,
  taxName3: src.taxName3,
  taxRate1: src.taxRate1,
  taxRate2: src.taxRate2,
  taxRate3: src.taxRate3,
  usesInclusiveTaxes: src.usesInclusiveTaxes,
  customSurcharge1: src.customSurcharge1,
  customSurcharge2: src.customSurcharge2,
  customSurcharge3: src.customSurcharge3,
  customSurcharge4: src.customSurcharge4,
  customTaxes1: src.customTaxes1,
  customTaxes2: src.customTaxes2,
  customTaxes3: src.customTaxes3,
  customTaxes4: src.customTaxes4,
  publicNotes: src.publicNotes,
  privateNotes: src.privateNotes,
  terms: src.terms,
  footer: src.footer,
  customValue1: src.customValue1,
  customValue2: src.customValue2,
  customValue3: src.customValue3,
  customValue4: src.customValue4,
  lineItems: src.lineItems,
  invitations: _freshInvitations(src.invitations),
);

BillingCloneData billingCloneFromQuote(Quote src) => BillingCloneData(
  clientId: src.clientId,
  poNumber: src.poNumber,
  assignedUserId: src.assignedUserId,
  discount: src.discount,
  isAmountDiscount: src.isAmountDiscount,
  taxName1: src.taxName1,
  taxName2: src.taxName2,
  taxName3: src.taxName3,
  taxRate1: src.taxRate1,
  taxRate2: src.taxRate2,
  taxRate3: src.taxRate3,
  usesInclusiveTaxes: src.usesInclusiveTaxes,
  customSurcharge1: src.customSurcharge1,
  customSurcharge2: src.customSurcharge2,
  customSurcharge3: src.customSurcharge3,
  customSurcharge4: src.customSurcharge4,
  customTaxes1: src.customTaxes1,
  customTaxes2: src.customTaxes2,
  customTaxes3: src.customTaxes3,
  customTaxes4: src.customTaxes4,
  publicNotes: src.publicNotes,
  privateNotes: src.privateNotes,
  terms: src.terms,
  footer: src.footer,
  customValue1: src.customValue1,
  customValue2: src.customValue2,
  customValue3: src.customValue3,
  customValue4: src.customValue4,
  lineItems: src.lineItems,
  invitations: _freshInvitations(src.invitations),
);

BillingCloneData billingCloneFromCredit(Credit src) => BillingCloneData(
  clientId: src.clientId,
  poNumber: src.poNumber,
  assignedUserId: src.assignedUserId,
  discount: src.discount,
  isAmountDiscount: src.isAmountDiscount,
  taxName1: src.taxName1,
  taxName2: src.taxName2,
  taxName3: src.taxName3,
  taxRate1: src.taxRate1,
  taxRate2: src.taxRate2,
  taxRate3: src.taxRate3,
  usesInclusiveTaxes: src.usesInclusiveTaxes,
  customSurcharge1: src.customSurcharge1,
  customSurcharge2: src.customSurcharge2,
  customSurcharge3: src.customSurcharge3,
  customSurcharge4: src.customSurcharge4,
  customTaxes1: src.customTaxes1,
  customTaxes2: src.customTaxes2,
  customTaxes3: src.customTaxes3,
  customTaxes4: src.customTaxes4,
  publicNotes: src.publicNotes,
  privateNotes: src.privateNotes,
  terms: src.terms,
  footer: src.footer,
  customValue1: src.customValue1,
  customValue2: src.customValue2,
  customValue3: src.customValue3,
  customValue4: src.customValue4,
  lineItems: src.lineItems,
  invitations: _freshInvitations(src.invitations),
);

/// PurchaseOrder source: drop the client + (vendor-contact) invitations — the
/// user selects the client on the target create screen, and vendor invitations
/// don't transfer to a client document.
BillingCloneData billingCloneFromPurchaseOrder(PurchaseOrder src) =>
    BillingCloneData(
      clientId: '',
      poNumber: src.poNumber,
      assignedUserId: src.assignedUserId,
      discount: src.discount,
      isAmountDiscount: src.isAmountDiscount,
      taxName1: src.taxName1,
      taxName2: src.taxName2,
      taxName3: src.taxName3,
      taxRate1: src.taxRate1,
      taxRate2: src.taxRate2,
      taxRate3: src.taxRate3,
      usesInclusiveTaxes: src.usesInclusiveTaxes,
      customSurcharge1: src.customSurcharge1,
      customSurcharge2: src.customSurcharge2,
      customSurcharge3: src.customSurcharge3,
      customSurcharge4: src.customSurcharge4,
      customTaxes1: src.customTaxes1,
      customTaxes2: src.customTaxes2,
      customTaxes3: src.customTaxes3,
      customTaxes4: src.customTaxes4,
      publicNotes: src.publicNotes,
      privateNotes: src.privateNotes,
      terms: src.terms,
      footer: src.footer,
      customValue1: src.customValue1,
      customValue2: src.customValue2,
      customValue3: src.customValue3,
      customValue4: src.customValue4,
      lineItems: src.lineItems,
      invitations: const [],
    );

BillingCloneData billingCloneFromRecurringInvoice(RecurringInvoice src) =>
    BillingCloneData(
      clientId: src.clientId,
      poNumber: src.poNumber,
      assignedUserId: src.assignedUserId,
      discount: src.discount,
      isAmountDiscount: src.isAmountDiscount,
      taxName1: src.taxName1,
      taxName2: src.taxName2,
      taxName3: src.taxName3,
      taxRate1: src.taxRate1,
      taxRate2: src.taxRate2,
      taxRate3: src.taxRate3,
      usesInclusiveTaxes: src.usesInclusiveTaxes,
      customSurcharge1: src.customSurcharge1,
      customSurcharge2: src.customSurcharge2,
      customSurcharge3: src.customSurcharge3,
      customSurcharge4: src.customSurcharge4,
      customTaxes1: src.customTaxes1,
      customTaxes2: src.customTaxes2,
      customTaxes3: src.customTaxes3,
      customTaxes4: src.customTaxes4,
      publicNotes: src.publicNotes,
      privateNotes: src.privateNotes,
      terms: src.terms,
      footer: src.footer,
      customValue1: src.customValue1,
      customValue2: src.customValue2,
      customValue3: src.customValue3,
      customValue4: src.customValue4,
      lineItems: src.lineItems,
      invitations: _freshInvitations(src.invitations),
    );

// ---------------------------------------------------------------------------
// Appliers — BillingCloneData → fresh target draft
// ---------------------------------------------------------------------------

Invoice cloneToInvoice(BillingCloneData data) => emptyInvoice().copyWith(
  clientId: data.clientId,
  poNumber: data.poNumber,
  assignedUserId: data.assignedUserId,
  discount: data.discount,
  isAmountDiscount: data.isAmountDiscount,
  taxName1: data.taxName1,
  taxName2: data.taxName2,
  taxName3: data.taxName3,
  taxRate1: data.taxRate1,
  taxRate2: data.taxRate2,
  taxRate3: data.taxRate3,
  usesInclusiveTaxes: data.usesInclusiveTaxes,
  customSurcharge1: data.customSurcharge1,
  customSurcharge2: data.customSurcharge2,
  customSurcharge3: data.customSurcharge3,
  customSurcharge4: data.customSurcharge4,
  customTaxes1: data.customTaxes1,
  customTaxes2: data.customTaxes2,
  customTaxes3: data.customTaxes3,
  customTaxes4: data.customTaxes4,
  publicNotes: data.publicNotes,
  privateNotes: data.privateNotes,
  terms: data.terms,
  footer: data.footer,
  customValue1: data.customValue1,
  customValue2: data.customValue2,
  customValue3: data.customValue3,
  customValue4: data.customValue4,
  lineItems: clonedLineItems(data.lineItems),
  invitations: data.invitations,
);

Quote cloneToQuote(BillingCloneData data) => emptyQuote().copyWith(
  clientId: data.clientId,
  poNumber: data.poNumber,
  assignedUserId: data.assignedUserId,
  discount: data.discount,
  isAmountDiscount: data.isAmountDiscount,
  taxName1: data.taxName1,
  taxName2: data.taxName2,
  taxName3: data.taxName3,
  taxRate1: data.taxRate1,
  taxRate2: data.taxRate2,
  taxRate3: data.taxRate3,
  usesInclusiveTaxes: data.usesInclusiveTaxes,
  customSurcharge1: data.customSurcharge1,
  customSurcharge2: data.customSurcharge2,
  customSurcharge3: data.customSurcharge3,
  customSurcharge4: data.customSurcharge4,
  customTaxes1: data.customTaxes1,
  customTaxes2: data.customTaxes2,
  customTaxes3: data.customTaxes3,
  customTaxes4: data.customTaxes4,
  publicNotes: data.publicNotes,
  privateNotes: data.privateNotes,
  terms: data.terms,
  footer: data.footer,
  customValue1: data.customValue1,
  customValue2: data.customValue2,
  customValue3: data.customValue3,
  customValue4: data.customValue4,
  lineItems: clonedLineItems(data.lineItems),
  invitations: data.invitations,
);

Credit cloneToCredit(BillingCloneData data) => emptyCredit().copyWith(
  clientId: data.clientId,
  poNumber: data.poNumber,
  assignedUserId: data.assignedUserId,
  discount: data.discount,
  isAmountDiscount: data.isAmountDiscount,
  taxName1: data.taxName1,
  taxName2: data.taxName2,
  taxName3: data.taxName3,
  taxRate1: data.taxRate1,
  taxRate2: data.taxRate2,
  taxRate3: data.taxRate3,
  usesInclusiveTaxes: data.usesInclusiveTaxes,
  customSurcharge1: data.customSurcharge1,
  customSurcharge2: data.customSurcharge2,
  customSurcharge3: data.customSurcharge3,
  customSurcharge4: data.customSurcharge4,
  customTaxes1: data.customTaxes1,
  customTaxes2: data.customTaxes2,
  customTaxes3: data.customTaxes3,
  customTaxes4: data.customTaxes4,
  publicNotes: data.publicNotes,
  privateNotes: data.privateNotes,
  terms: data.terms,
  footer: data.footer,
  customValue1: data.customValue1,
  customValue2: data.customValue2,
  customValue3: data.customValue3,
  customValue4: data.customValue4,
  lineItems: clonedLineItems(data.lineItems),
  invitations: data.invitations,
);

RecurringInvoice cloneToRecurringInvoice(BillingCloneData data) =>
    emptyRecurringInvoice().copyWith(
      clientId: data.clientId,
      poNumber: data.poNumber,
      assignedUserId: data.assignedUserId,
      discount: data.discount,
      isAmountDiscount: data.isAmountDiscount,
      taxName1: data.taxName1,
      taxName2: data.taxName2,
      taxName3: data.taxName3,
      taxRate1: data.taxRate1,
      taxRate2: data.taxRate2,
      taxRate3: data.taxRate3,
      usesInclusiveTaxes: data.usesInclusiveTaxes,
      customSurcharge1: data.customSurcharge1,
      customSurcharge2: data.customSurcharge2,
      customSurcharge3: data.customSurcharge3,
      customSurcharge4: data.customSurcharge4,
      customTaxes1: data.customTaxes1,
      customTaxes2: data.customTaxes2,
      customTaxes3: data.customTaxes3,
      customTaxes4: data.customTaxes4,
      publicNotes: data.publicNotes,
      privateNotes: data.privateNotes,
      terms: data.terms,
      footer: data.footer,
      customValue1: data.customValue1,
      customValue2: data.customValue2,
      customValue3: data.customValue3,
      customValue4: data.customValue4,
      lineItems: clonedLineItems(data.lineItems),
      invitations: data.invitations,
      // frequencyId intentionally left at the empty default — the user picks
      // the recurrence schedule on the create screen.
    );

/// PurchaseOrder is vendor-billed: copy content only, never the client or
/// invitations — the user selects the vendor on the create screen.
PurchaseOrder cloneToPurchaseOrder(BillingCloneData data) =>
    emptyPurchaseOrder().copyWith(
      poNumber: data.poNumber,
      assignedUserId: data.assignedUserId,
      discount: data.discount,
      isAmountDiscount: data.isAmountDiscount,
      taxName1: data.taxName1,
      taxName2: data.taxName2,
      taxName3: data.taxName3,
      taxRate1: data.taxRate1,
      taxRate2: data.taxRate2,
      taxRate3: data.taxRate3,
      usesInclusiveTaxes: data.usesInclusiveTaxes,
      customSurcharge1: data.customSurcharge1,
      customSurcharge2: data.customSurcharge2,
      customSurcharge3: data.customSurcharge3,
      customSurcharge4: data.customSurcharge4,
      customTaxes1: data.customTaxes1,
      customTaxes2: data.customTaxes2,
      customTaxes3: data.customTaxes3,
      customTaxes4: data.customTaxes4,
      publicNotes: data.publicNotes,
      privateNotes: data.privateNotes,
      terms: data.terms,
      footer: data.footer,
      customValue1: data.customValue1,
      customValue2: data.customValue2,
      customValue3: data.customValue3,
      customValue4: data.customValue4,
      lineItems: clonedLineItems(data.lineItems),
    );
