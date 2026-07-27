import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:admin/data/models/api/invoice_api_model.dart';
import 'package:admin/data/models/domain/billing/invitation.dart';
import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/data/models/domain/document.dart';
import 'package:admin/data/models/domain/invoice_status.dart';
import 'package:admin/data/models/domain/schedule_item.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/models/value/money.dart';
import 'package:admin/data/models/value/parsing.dart';

part 'invoice.freezed.dart';

/// Clean domain model the UI consumes. `Invoice.fromApi(...)` walks the
/// raw [InvoiceApi] DTO. The `isDirty` flag is local-only —
/// [InvoiceRepository._fromRow] overlays the Drift row's value so unsaved
/// edits survive app restart.
///
/// Money is `Decimal`. Dates are the custom [Date] type. `statusId` is
/// the [InvoiceStatus] enum; the computed-pseudo statuses (`past_due`,
/// `unpaid`, `viewed`) come from the [InvoiceCalculation.calculatedStatusId]
/// extension below — never stored.
///
/// Recurring fields are kept on every invoice. The server populates them
/// when an invoice was generated from a recurring template (so the linkage
/// can be displayed on the detail screen); they're empty on standalone
/// invoices and reused verbatim by `RecurringInvoice` later.
@freezed
abstract class Invoice with _$Invoice {
  const factory Invoice({
    required String id,
    required String number,
    required String poNumber,
    required Date? date,
    required Date? dueDate,
    required Date? partialDueDate,
    required InvoiceStatus statusId,
    required String clientId,
    required String vendorId,
    required String projectId,
    required String designId,
    required String assignedUserId,
    required String userId,
    required String locationId,
    required String subscriptionId,
    required String parentInvoiceId,
    required String recurringId,
    required Decimal amount,
    required Decimal balance,
    required Decimal paidToDate,
    required Decimal taxAmount,
    required Decimal discount,
    required Decimal partial,
    required bool isAmountDiscount,
    required Decimal exchangeRate,
    required String taxName1,
    required String taxName2,
    required String taxName3,
    required Decimal taxRate1,
    required Decimal taxRate2,
    required Decimal taxRate3,
    required bool usesInclusiveTaxes,
    required Decimal customSurcharge1,
    required Decimal customSurcharge2,
    required Decimal customSurcharge3,
    required Decimal customSurcharge4,
    required bool customTaxes1,
    required bool customTaxes2,
    required bool customTaxes3,
    required bool customTaxes4,
    required String publicNotes,
    required String privateNotes,
    required String terms,
    required String footer,
    required String customValue1,
    required String customValue2,
    required String customValue3,
    required String customValue4,
    required Date? reminder1Sent,
    required Date? reminder2Sent,
    required Date? reminder3Sent,
    required Date? reminderLastSent,
    required String reminderSchedule,
    required String frequencyId,
    required Date? nextSendDate,
    required String nextSendDatetime,
    required Date? lastSentDate,
    required int remainingCycles,
    required String dueDateDays,
    required String autoBill,
    required bool autoBillEnabled,
    required bool isLocked,
    required bool isDeleted,
    required DateTime updatedAt,
    required DateTime createdAt,
    required DateTime? archivedAt,
    @Default(<LineItem>[]) List<LineItem> lineItems,
    @Default(<Invitation>[]) List<Invitation> invitations,
    @Default(<Document>[]) List<Document> documents,
    @Default(<String>[]) List<String> tagIds,
    Map<String, dynamic>? eInvoice,
    Map<String, dynamic>? backup,
    Map<String, dynamic>? taxInfo,
    String? modifiedInvoiceId,
    String? reason,
    @Default(<ScheduleItem>[]) List<ScheduleItem> schedule,
    @Default(false) bool isDirty,
  }) = _Invoice;

  factory Invoice.fromApi(InvoiceApi a) => Invoice(
    id: a.id,
    number: a.number,
    poNumber: a.poNumber,
    date: Date.tryParse(a.date),
    dueDate: Date.tryParse(a.dueDate),
    partialDueDate: Date.tryParse(a.partialDueDate),
    statusId: InvoiceStatus.fromWire(a.statusId),
    clientId: a.clientId,
    vendorId: a.vendorId,
    projectId: a.projectId,
    designId: a.designId,
    assignedUserId: a.assignedUserId,
    userId: a.userId,
    locationId: a.locationId,
    subscriptionId: a.subscriptionId,
    parentInvoiceId: a.parentInvoiceId,
    recurringId: a.recurringId,
    amount: parseMoney(a.amount),
    balance: parseMoney(a.balance),
    paidToDate: parseMoney(a.paidToDate),
    taxAmount: parseMoney(a.totalTaxes),
    discount: parseMoney(a.discount),
    partial: parseMoney(a.partial),
    isAmountDiscount: a.isAmountDiscount,
    exchangeRate: parseMoney(a.exchangeRate),
    taxName1: a.taxName1,
    taxName2: a.taxName2,
    taxName3: a.taxName3,
    taxRate1: parseMoney(a.taxRate1),
    taxRate2: parseMoney(a.taxRate2),
    taxRate3: parseMoney(a.taxRate3),
    usesInclusiveTaxes: a.usesInclusiveTaxes,
    customSurcharge1: parseMoney(a.customSurcharge1),
    customSurcharge2: parseMoney(a.customSurcharge2),
    customSurcharge3: parseMoney(a.customSurcharge3),
    customSurcharge4: parseMoney(a.customSurcharge4),
    customTaxes1: a.customTaxes1,
    customTaxes2: a.customTaxes2,
    customTaxes3: a.customTaxes3,
    customTaxes4: a.customTaxes4,
    publicNotes: a.publicNotes,
    privateNotes: a.privateNotes,
    terms: a.terms,
    footer: a.footer,
    customValue1: a.customValue1,
    customValue2: a.customValue2,
    customValue3: a.customValue3,
    customValue4: a.customValue4,
    reminder1Sent: Date.tryParse(a.reminder1Sent),
    reminder2Sent: Date.tryParse(a.reminder2Sent),
    reminder3Sent: Date.tryParse(a.reminder3Sent),
    reminderLastSent: Date.tryParse(a.reminderLastSent),
    reminderSchedule: a.reminderSchedule,
    frequencyId: a.frequencyId,
    nextSendDate: Date.tryParse(a.nextSendDate),
    nextSendDatetime: a.nextSendDatetime,
    lastSentDate: Date.tryParse(a.lastSentDate),
    remainingCycles: a.remainingCycles,
    dueDateDays: a.dueDateDays,
    autoBill: a.autoBill,
    autoBillEnabled: a.autoBillEnabled,
    isLocked: a.isLocked,
    isDeleted: a.isDeleted,
    updatedAt: epochSecondsToUtc(a.updatedAt),
    createdAt: epochSecondsToUtc(a.createdAt),
    archivedAt: epochSecondsToUtcOrNull(a.archivedAt),
    lineItems: a.lineItems.map(LineItem.fromApi).toList(growable: false),
    invitations: a.invitations.map(Invitation.fromApi).toList(growable: false),
    documents: mapDocuments(a.documents),
    tagIds: [
      for (final t in a.tags)
        if (t.id.isNotEmpty) t.id,
    ],
    eInvoice: a.eInvoice,
    backup: a.backup,
    taxInfo: a.taxInfo,
    modifiedInvoiceId: a.modifiedInvoiceId,
    reason: a.reason,
    schedule: (a.schedule ?? const [])
        .map(ScheduleItem.fromApi)
        .toList(growable: false),
  );
}

/// Computed status helpers + cheap derived totals. Mirrors admin-portal
/// `InvoiceEntity` accessors so the list filter chips, detail-header
/// status pill, and edit-screen "is past due" banner agree.
extension InvoiceCalculation on Invoice {
  /// `amount - taxAmount`. Net total before tax — grand total minus the summed
  /// tax breakdown, so `net + tax == total` reconciles. For multi-rate
  /// inclusive tax the breakdown tiers are the additive shared-base amounts
  /// (issue #12072) and net = gross − Σtax = 833.34, matching
  /// `Expense.netAmount` and the backend `InclusiveTax::backout()`.
  Decimal get netAmount => amount - taxAmount;

  /// `balance` once the invoice has been sent; falls back to `amount`
  /// for drafts (so the list-screen "amount" column never reads 0 on a
  /// draft whose balance hasn't been computed yet).
  Decimal get balanceOrAmount =>
      statusId == InvoiceStatus.draft ? amount : balance;

  bool get isDraft => statusId == InvoiceStatus.draft;
  bool get isSent =>
      statusId == InvoiceStatus.sent ||
      statusId == InvoiceStatus.partial ||
      statusId == InvoiceStatus.paid;
  bool get isPaid => statusId == InvoiceStatus.paid;
  bool get isPartial => statusId == InvoiceStatus.partial;
  bool get isCancelled => statusId == InvoiceStatus.cancelled;
  bool get isReversed => statusId == InvoiceStatus.reversed;

  bool get hasViewedInvitation => invitations.any((i) => i.hasBeenViewed);

  /// Any invitation whose email bounced or errored — drives the red
  /// alert overlay on the list status chip (mirrors admin-portal
  /// `invoice_model.dart` `isBounced`).
  bool get hasBouncedInvitation =>
      invitations.any((i) => i.hasBounced || i.hasError);

  /// True iff the active due date (partial first, then full) is in the past
  /// AND the invoice still has a non-zero balance. Mirrors admin-portal
  /// `invoice_model.dart` `isPastDue` logic.
  bool get isPastDue {
    if (balance <= Decimal.zero) return false;
    // A draft is never past due — it hasn't been sent, so there is nothing
    // owed yet. The server keeps a draft's balance at 0 so this never fired
    // server-side; the client's optimistic totals stamp could produce a
    // non-zero local balance and light up the pill. Mirrors admin-portal's
    // `isPastDue`, which requires `isSent`.
    if (isDraft) return false;
    if (isPaid || isCancelled || isReversed) return false;
    final today = Date.today();
    final effectiveDue = partialDueDate ?? dueDate;
    if (effectiveDue == null) return false;
    return effectiveDue.compareTo(today) < 0;
  }

  /// Status discriminator surfaced to the UI. Returns one of the stored
  /// [InvoiceStatus.wireId] values OR one of the computed-only ids in
  /// [InvoiceStatusComputed]. Mirrors admin-portal `invoice_model.dart`
  /// `calculatedStatusId`.
  String get calculatedStatusId {
    if (isCancelled) return InvoiceStatus.cancelled.wireId;
    if (isReversed) return InvoiceStatus.reversed.wireId;
    if (isPaid) return InvoiceStatus.paid.wireId;
    if (isPastDue) return InvoiceStatusComputed.pastDue;
    if (statusId == InvoiceStatus.sent && hasViewedInvitation) {
      return InvoiceStatusComputed.viewed;
    }
    return statusId.wireId;
  }
}

/// Serialize back to the JSON shape the server expects. `preserveTempId`
/// lets the local Drift cache keep the temp id; outbound `POST /invoices`
/// drops it so the server can assign the real one.
extension InvoicePayload on Invoice {
  Map<String, dynamic> toApiJson({bool preserveTempId = false}) {
    return <String, dynamic>{
      if (preserveTempId || !id.startsWith('tmp_')) 'id': id,
      'number': number,
      'po_number': poNumber,
      'date': date?.toIso() ?? '',
      'due_date': dueDate?.toIso() ?? '',
      'partial_due_date': partialDueDate?.toIso() ?? '',
      'status_id': statusId.wireId,
      'client_id': clientId,
      'vendor_id': vendorId,
      'project_id': projectId,
      'design_id': designId,
      'assigned_user_id': assignedUserId,
      'user_id': userId,
      'location_id': locationId,
      'subscription_id': subscriptionId,
      'invoice_id': parentInvoiceId,
      'recurring_id': recurringId,
      'amount': amount.toString(),
      'balance': balance.toString(),
      'paid_to_date': paidToDate.toString(),
      'total_taxes': taxAmount.toString(),
      'discount': discount.toString(),
      'partial': partial.toString(),
      'is_amount_discount': isAmountDiscount,
      'exchange_rate': exchangeRate.toString(),
      'tax_name1': taxName1,
      'tax_name2': taxName2,
      'tax_name3': taxName3,
      'tax_rate1': taxRate1.toString(),
      'tax_rate2': taxRate2.toString(),
      'tax_rate3': taxRate3.toString(),
      'uses_inclusive_taxes': usesInclusiveTaxes,
      'custom_surcharge1': customSurcharge1.toString(),
      'custom_surcharge2': customSurcharge2.toString(),
      'custom_surcharge3': customSurcharge3.toString(),
      'custom_surcharge4': customSurcharge4.toString(),
      'custom_surcharge_tax1': customTaxes1,
      'custom_surcharge_tax2': customTaxes2,
      'custom_surcharge_tax3': customTaxes3,
      'custom_surcharge_tax4': customTaxes4,
      'public_notes': publicNotes,
      'private_notes': privateNotes,
      'terms': terms,
      'footer': footer,
      'custom_value1': customValue1,
      'custom_value2': customValue2,
      'custom_value3': customValue3,
      'custom_value4': customValue4,
      // Full-set replace: the server syncs attached tags to exactly this list.
      'tags': tagIds,
      'line_items': lineItems.map((l) => l.toApiJson()).toList(),
      'invitations': invitations.map((i) => i.toApiJson()).toList(),
      'reminder_schedule': reminderSchedule,
      'frequency_id': frequencyId,
      'next_send_date': nextSendDate?.toIso() ?? '',
      'next_send_datetime': nextSendDatetime,
      'remaining_cycles': remainingCycles,
      'due_date_days': dueDateDays,
      'auto_bill': autoBill,
      'auto_bill_enabled': autoBillEnabled,
      if (eInvoice != null) 'e_invoice': eInvoice,
      if (modifiedInvoiceId != null && modifiedInvoiceId!.isNotEmpty)
        'modified_invoice_id': modifiedInvoiceId,
      if (reason != null && reason!.isNotEmpty) 'reason': reason,
    };
  }
}
