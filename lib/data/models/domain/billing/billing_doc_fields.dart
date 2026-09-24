import 'package:decimal/decimal.dart';

import 'package:admin/data/models/domain/billing/invitation.dart';
import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/data/models/domain/document.dart';
import 'package:admin/data/models/value/date.dart';

/// The fields all five billing documents — invoice, quote, credit, purchase
/// order, recurring invoice — share, with the same names and types.
///
/// The five freezed classes were written as copies of one another, and so
/// was everything that reads them: the totals mapping existed eight times,
/// the ~40 field setters five. Implementing this lets that code be written
/// once over `T extends BillingDocFields` — the totals input
/// (`BillingDocTotals.totalsInput`) and the edit view model's setters
/// (`BillingDocEditViewModel`). Getters only: freezed classes share no
/// `copyWith`, so writes go through each entity's `BillingDocWriter`.
///
/// Not here: `statusId` (a different enum per document) and the per-entity
/// extras — invoice's `paidToDate`, the recurring fields, the purchase
/// order's `expenseId`. `partial` / `partialDueDate` are on every document
/// but the purchase order ([BillingDocPartialFields]).
abstract interface class BillingDocFields {
  String get id;
  String get number;
  String get poNumber;
  Date? get date;
  Date? get dueDate;

  String get clientId;
  String get vendorId;
  String get projectId;
  String get designId;
  String get assignedUserId;
  String get userId;
  String get locationId;

  Decimal get amount;
  Decimal get balance;
  Decimal get taxAmount;
  Decimal get discount;
  bool get isAmountDiscount;
  Decimal get exchangeRate;

  String get taxName1;
  String get taxName2;
  String get taxName3;
  Decimal get taxRate1;
  Decimal get taxRate2;
  Decimal get taxRate3;
  bool get usesInclusiveTaxes;

  Decimal get customSurcharge1;
  Decimal get customSurcharge2;
  Decimal get customSurcharge3;
  Decimal get customSurcharge4;
  bool get customTaxes1;
  bool get customTaxes2;
  bool get customTaxes3;
  bool get customTaxes4;

  String get customValue1;
  String get customValue2;
  String get customValue3;
  String get customValue4;

  String get publicNotes;
  String get privateNotes;
  String get terms;
  String get footer;

  List<LineItem> get lineItems;
  List<Invitation> get invitations;
  List<Document> get documents;
  List<String> get tagIds;
  Map<String, dynamic>? get eInvoice;

  bool get isDeleted;
  bool get isDirty;
  DateTime get updatedAt;
  DateTime get createdAt;
  DateTime? get archivedAt;
}

/// A billing document that can ask for a partial payment (a deposit) —
/// every one but the purchase order.
abstract interface class BillingDocPartialFields implements BillingDocFields {
  Decimal get partial;
  Date? get partialDueDate;
}
