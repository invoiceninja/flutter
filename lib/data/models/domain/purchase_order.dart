import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:admin/data/models/api/purchase_order_api_model.dart';
import 'package:admin/data/models/domain/billing/invitation.dart';
import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/data/models/domain/document.dart';
import 'package:admin/data/models/domain/purchase_order_status.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/models/value/money.dart';
import 'package:admin/data/models/value/parsing.dart';

part 'purchase_order.freezed.dart';

/// Clean domain model the UI consumes. Mirrors [Quote] shape;
/// vendor-centric instead of client-centric, and carries `expenseId`
/// for the receipt → expense conversion linkage.
@freezed
abstract class PurchaseOrder with _$PurchaseOrder {
  const factory PurchaseOrder({
    required String id,
    required String number,
    required String poNumber,
    required Date? date,
    required Date? dueDate,
    required PurchaseOrderStatus statusId,
    required String clientId,
    required String vendorId,
    required String projectId,
    required String expenseId,
    required String designId,
    required String assignedUserId,
    required String userId,
    required String locationId,
    required Decimal amount,
    required Decimal balance,
    required Decimal taxAmount,
    required Decimal discount,
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
    required bool isDeleted,
    required DateTime updatedAt,
    required DateTime createdAt,
    required DateTime? archivedAt,
    @Default(<LineItem>[]) List<LineItem> lineItems,
    @Default(<Invitation>[]) List<Invitation> invitations,
    @Default(<Document>[]) List<Document> documents,
    @Default(<String>[]) List<String> tagIds,
    Map<String, dynamic>? eInvoice,
    @Default(false) bool isDirty,
  }) = _PurchaseOrder;

  factory PurchaseOrder.fromApi(PurchaseOrderApi a) => PurchaseOrder(
    id: a.id,
    number: a.number,
    poNumber: a.poNumber,
    date: Date.tryParse(a.date),
    dueDate: Date.tryParse(a.dueDate),
    statusId: PurchaseOrderStatus.fromWire(a.statusId),
    clientId: a.clientId,
    vendorId: a.vendorId,
    projectId: a.projectId,
    expenseId: a.expenseId,
    designId: a.designId,
    assignedUserId: a.assignedUserId,
    userId: a.userId,
    locationId: a.locationId,
    amount: parseMoney(a.amount),
    balance: parseMoney(a.balance),
    taxAmount: parseMoney(a.totalTaxes),
    discount: parseMoney(a.discount),
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
  );
}

extension PurchaseOrderCalculation on PurchaseOrder {
  Decimal get netAmount => amount - taxAmount;
  Decimal get balanceOrAmount =>
      statusId == PurchaseOrderStatus.draft ? amount : balance;

  bool get isDraft => statusId == PurchaseOrderStatus.draft;
  bool get isSent => statusId == PurchaseOrderStatus.sent;
  bool get isAccepted => statusId == PurchaseOrderStatus.accepted;
  bool get isReceived => statusId == PurchaseOrderStatus.received;
  bool get isCancelled => statusId == PurchaseOrderStatus.cancelled;

  bool get hasViewedInvitation => invitations.any((i) => i.hasBeenViewed);

  /// Any invitation whose email bounced or errored — drives the red
  /// alert overlay on the list status chip.
  bool get hasBouncedInvitation =>
      invitations.any((i) => i.hasBounced || i.hasError);

  String get calculatedStatusId {
    if (statusId == PurchaseOrderStatus.sent && hasViewedInvitation) {
      return PurchaseOrderStatusComputed.viewed;
    }
    return statusId.wireId;
  }
}

extension PurchaseOrderPayload on PurchaseOrder {
  Map<String, dynamic> toApiJson({bool preserveTempId = false}) {
    return <String, dynamic>{
      if (preserveTempId || !id.startsWith('tmp_')) 'id': id,
      'number': number,
      'po_number': poNumber,
      'date': date?.toIso() ?? '',
      'due_date': dueDate?.toIso() ?? '',
      'status_id': statusId.wireId,
      'client_id': clientId,
      'vendor_id': vendorId,
      'project_id': projectId,
      'expense_id': expenseId,
      'design_id': designId,
      'assigned_user_id': assignedUserId,
      'user_id': userId,
      'location_id': locationId,
      'amount': amount.toString(),
      'balance': balance.toString(),
      'total_taxes': taxAmount.toString(),
      'discount': discount.toString(),
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
      if (eInvoice != null) 'e_invoice': eInvoice,
    };
  }
}
