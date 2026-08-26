import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:admin/data/models/api/line_item_api_model.dart';
import 'package:admin/data/models/domain/billing/line_item_type.dart';
import 'package:admin/data/models/domain/product.dart';
import 'package:admin/data/models/value/money.dart';

part 'line_item.freezed.dart';

/// One row inside an invoice / quote / credit / purchase_order / recurring
/// invoice. Shared across all five billing-document types — the only thing
/// that varies between them is the wrapping entity model, not the line
/// items.
///
/// Stored as JSON inside the parent entity's Drift `payload` column (no
/// separate `line_items` table). Round-trips via [LineItem.fromApi] →
/// [LineItemPayload.toApiJson].
///
/// Money/qty/rate use `Decimal`. Tax rates round to 3 decimals during
/// totals math; this domain layer keeps full precision and lets the
/// totals calculator decide how to round.
///
/// All `Decimal` fields are `required` (freezed's `@Default` only accepts
/// const literals, and `Decimal.zero` isn't const-constructible). Callers
/// construct via [LineItem.fromApi] or [emptyLineItem]; per-field setters
/// in the edit VM thread defaults through.
@freezed
abstract class LineItem with _$LineItem {
  const factory LineItem({
    required String productKey,
    required String notes,
    required Decimal cost,
    required Decimal productCost,
    required Decimal quantity,
    required String taxName1,
    required String taxName2,
    required String taxName3,
    required Decimal taxRate1,
    required Decimal taxRate2,
    required Decimal taxRate3,
    required LineItemType typeId,
    required String customValue1,
    required String customValue2,
    required String customValue3,
    required String customValue4,
    required Decimal discount,
    String? taskId,
    String? expenseId,
    required String taxCategoryId,
    int? createdAt,
  }) = _LineItem;

  factory LineItem.fromApi(LineItemApi a) => LineItem(
    productKey: a.productKey,
    notes: a.notes,
    cost: parseMoney(a.cost),
    productCost: parseMoney(a.productCost),
    quantity: _parseQuantity(a.quantity) ?? Decimal.one,
    taxName1: a.taxName1,
    taxName2: a.taxName2,
    taxName3: a.taxName3,
    taxRate1: parseMoney(a.taxRate1),
    taxRate2: parseMoney(a.taxRate2),
    taxRate3: parseMoney(a.taxRate3),
    typeId: LineItemType.fromWire(a.typeId),
    customValue1: a.customValue1,
    customValue2: a.customValue2,
    customValue3: a.customValue3,
    customValue4: a.customValue4,
    discount: parseMoney(a.discount),
    taskId: (a.taskId ?? '').isEmpty ? null : a.taskId,
    expenseId: (a.expenseId ?? '').isEmpty ? null : a.expenseId,
    taxCategoryId: a.taxCategoryId,
    createdAt: a.createdAt,
  );
}

extension LineItemAccessors on LineItem {
  /// Convenience: `cost * quantity` (pre-discount, pre-tax).
  Decimal get gross => cost * quantity;

  /// True when no user-meaningful identifier has been touched. Used by
  /// the desktop inline-editable table to decide whether to keep a
  /// trailing empty row visible (matches admin-portal's
  /// always-one-blank-row UX) and by `stripEmptyLineItems` on save.
  ///
  /// Identifier-driven: any non-empty `productKey` or `notes` marks the
  /// row as user-typed, regardless of cost / quantity / tax values.
  /// (Without this, a row where the user only typed `quantity: 0`
  /// would be silently dropped on save.) Cost/discount/tax/customs are
  /// only considered "user-meaningful" via the productKey/notes signal
  /// — a blank row that happens to carry a default tax rate from a
  /// previous edit is still blank.
  bool get isBlank =>
      productKey.isEmpty &&
      notes.isEmpty &&
      cost == Decimal.zero &&
      discount == Decimal.zero &&
      taxName1.isEmpty &&
      taxName2.isEmpty &&
      taxName3.isEmpty &&
      customValue1.isEmpty &&
      customValue2.isEmpty &&
      customValue3.isEmpty &&
      customValue4.isEmpty &&
      taskId == null &&
      expenseId == null;
}

/// Empty line item — quantity defaults to 1, everything else zero/empty.
/// Used by the edit VM when the user taps "Add item".
LineItem emptyLineItem() => LineItem(
  productKey: '',
  notes: '',
  cost: Decimal.zero,
  productCost: Decimal.zero,
  quantity: Decimal.one,
  taxName1: '',
  taxName2: '',
  taxName3: '',
  taxRate1: Decimal.zero,
  taxRate2: Decimal.zero,
  taxRate3: Decimal.zero,
  typeId: LineItemType.standard,
  customValue1: '',
  customValue2: '',
  customValue3: '',
  customValue4: '',
  discount: Decimal.zero,
  taskId: null,
  expenseId: null,
  taxCategoryId: '',
  createdAt: null,
);

/// Build or merge a billing line item from a product, mirroring React's
/// `useHandleProductChange` so every product-fill path agrees:
///   * unit price (`cost`) = the product's sale `price`, multiplied by
///     [conversionRate] (defaults to 1 — callers pass the company→client
///     cross-currency rate when the company's `convert_products` is on and the
///     client's currency differs, matching React's in-browser conversion).
///   * `productCost` = the product's `cost` (markup/profit reporting).
///   * `quantity` follows the company toggles: quantity disabled → always 1;
///     otherwise `default_quantity` → 1, else the product's stored quantity
///     (a 0/blank product quantity falls back to 1). This deliberately
///     overwrites any quantity already on [base] — filling a product resets the
///     line to the product's defaults, matching React's `useHandleProductChange`.
///   * notes, taxes, tax category and custom values are copied from the product.
///
/// When [base] is supplied the product-derived fields overwrite it while the
/// row's own discount / task / expense links are preserved; otherwise the row
/// starts from [emptyLineItem].
LineItem lineItemFromProduct(
  Product product, {
  LineItem? base,
  bool enableProductQuantity = false,
  bool defaultQuantity = false,
  Decimal? conversionRate,
}) {
  final rate = conversionRate ?? Decimal.one;
  final unitPrice = rate == Decimal.one ? product.price : product.price * rate;
  final Decimal quantity;
  if (!enableProductQuantity || defaultQuantity) {
    quantity = Decimal.one;
  } else {
    quantity = product.quantity > Decimal.zero ? product.quantity : Decimal.one;
  }
  return (base ?? emptyLineItem()).copyWith(
    productKey: product.productKey,
    notes: product.notes,
    cost: unitPrice,
    productCost: product.cost,
    quantity: quantity,
    taxName1: product.taxName1,
    taxRate1: product.taxRate1,
    taxName2: product.taxName2,
    taxRate2: product.taxRate2,
    taxName3: product.taxName3,
    taxRate3: product.taxRate3,
    taxCategoryId: product.taxId,
    customValue1: product.customValue1,
    customValue2: product.customValue2,
    customValue3: product.customValue3,
    customValue4: product.customValue4,
  );
}

/// Cross-entity "New Invoice / Quote / Purchase Order from a product" flow
/// (`?product=<id>` on the create route — see `entity_modules.dart` and the
/// three edit screens). A brand-new doc with no client/company context yet, so
/// the sale price is used verbatim at quantity 1; [lineItemFromProduct] does
/// the work (and now also copies the product's cost / tax category / customs).
LineItem lineItemForProduct(Product product) => lineItemFromProduct(product);

/// Tolerant `Decimal` parser for the `quantity` wire field. Same shape as
/// `parseMoney` but returns null for unparseable/empty input so the domain
/// can substitute the `1` default rather than `0`.
Decimal? _parseQuantity(Object? raw) {
  if (raw == null) return null;
  if (raw is num) return Decimal.parse(raw.toString());
  if (raw is String) {
    if (raw.isEmpty) return null;
    return Decimal.tryParse(raw);
  }
  return null;
}

/// Serialize back to the JSON shape the server expects. The repository
/// embeds the result inside the parent entity's `line_items` array.
extension LineItemClone on LineItem {
  /// A line-item copy suitable for a *cloned* billing doc: keeps what the user
  /// typed (product, description, cost, quantity, taxes, custom values) but
  /// drops the links back to the source records — `taskId` / `expenseId` — and
  /// resets a task/expense-derived row to a plain `standard` line.
  ///
  /// Without this, cloning an invoice that billed task T and then re-pointing
  /// the clone at a different client — the canonical "same work, new client"
  /// use of clone — dead-ends: `validateCrossClient` sees the line still
  /// claiming T (whose client is the ORIGINAL one), returns a `line_items`
  /// error, and `save()` hard-returns. The message names no field the form can
  /// fix, so the only way out is deleting and retyping the line. admin-portal
  /// clears both ids for exactly this reason (`InvoiceItemEntity.clone`).
  LineItem freshClone() => copyWith(
    taskId: null,
    expenseId: null,
    typeId: typeId == LineItemType.task || typeId == LineItemType.expense
        ? LineItemType.standard
        : typeId,
  );
}

/// Line items for a *cloned* billing doc: every row sanitised by
/// [LineItemClone.freshClone], and server-generated unpaid-fee rows dropped
/// entirely — those are a gateway fee the server added to the ORIGINAL
/// document, and carrying one into a new draft re-bills it. Mirrors
/// admin-portal `InvoiceEntity.clone`.
List<LineItem> clonedLineItems(List<LineItem> items) => [
  for (final item in items)
    if (item.typeId != LineItemType.unpaidFee) item.freshClone(),
];

extension LineItemPayload on LineItem {
  Map<String, dynamic> toApiJson() => <String, dynamic>{
    'product_key': productKey,
    'notes': notes,
    'cost': cost.toString(),
    'product_cost': productCost.toString(),
    'quantity': quantity.toString(),
    'tax_name1': taxName1,
    'tax_name2': taxName2,
    'tax_name3': taxName3,
    'tax_rate1': taxRate1.toString(),
    'tax_rate2': taxRate2.toString(),
    'tax_rate3': taxRate3.toString(),
    'type_id': typeId.wireId,
    'custom_value1': customValue1,
    'custom_value2': customValue2,
    'custom_value3': customValue3,
    'custom_value4': customValue4,
    'discount': discount.toString(),
    if (taskId != null) 'task_id': taskId,
    if (expenseId != null) 'expense_id': expenseId,
    'tax_id': taxCategoryId,
    if (createdAt != null) 'created_at': createdAt,
  };
}
