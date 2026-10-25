import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:admin/data/models/api/line_item_api_model.dart';
import 'package:admin/data/models/domain/billing/line_item_type.dart';
import 'package:admin/data/models/domain/company.dart';
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
  ///
  /// `notes` is trimmed: the wide table's Description cell is multi-line, so
  /// a stray Return types `\n`, which prints nothing but would otherwise
  /// promote the empty row into a saved, blank line.
  bool get isBlank =>
      productKey.isEmpty &&
      notes.trim().isEmpty &&
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

  /// A row of text on the PDF: no product, cost or quantity, so the server
  /// prints its description with the money columns blank
  /// (`MakesInvoiceValues::transformLineItems` blanks them only when both
  /// `quantity` and `cost` are 0). The phone edits one in
  /// `showLineItemTextDialog` and draws its card without the money.
  bool get isTextOnly =>
      typeId == LineItemType.standard &&
      productKey.isEmpty &&
      cost == Decimal.zero &&
      quantity == Decimal.zero &&
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

/// A fresh text line (see [LineItemAccessors.isTextOnly]) — [emptyLineItem]
/// with no quantity, since a quantity of 1 makes the PDF print `$0.00 1 $0.00`.
LineItem textLineItem() => emptyLineItem().copyWith(quantity: Decimal.zero);

/// Build or merge a billing line item from a product, mirroring React's
/// `useHandleProductChange` so every product-fill path agrees:
///   * unit price (`cost`) = the product's sale `price`, multiplied by
///     [conversionRate] (defaults to 1 — callers pass the company→client
///     cross-currency rate when the company's `convert_products` is on and the
///     client's currency differs, matching React's in-browser conversion).
///   * `productCost` = the product's `cost` (markup/profit reporting).
///   * `quantity` follows the company toggles: quantity disabled → always 1;
///     otherwise `default_quantity` → 1, else the product's stored quantity
///     (a 0/blank product quantity falls back to 1). On a product row this
///     deliberately overwrites any quantity already on [base] — filling a
///     product resets the line to the product's defaults, matching React's
///     `useHandleProductChange`. An hourly row keeps its hours (below).
///   * notes, taxes, tax category and custom values are copied from the
///     product — except an hourly row's non-blank notes (below). A tax slot
///     the product leaves blank (no name, no rate) takes [company]'s default
///     for it when the company taxes per line only ([defaultItemTaxes]) —
///     unless the document's party is [partyTaxExempt], whose taxes the
///     server zeroes.
///
/// When [base] is supplied the product-derived fields overwrite it while the
/// row's own discount / task / expense links are preserved; otherwise the row
/// starts from [emptyLineItem].
///
/// **An hourly [base] (`type_id` 2) is the Service for work already
/// measured**, so a pick fills the product key, taxes and customs but:
///   * the **hours** always stay (admin-portal) — for a billed task they are
///     its logged time, and a pick must not reset them to 1;
///   * a non-blank **description** stays — React's task table and admin-portal
///     both do this; a billed task's is its time log. So re-picking a service
///     keeps the first one's description, as it does in both;
///   * the **rate** stays only on a row linked to a task (`taskId`), which was
///     billed at the task's own rate (admin-portal). A free-form hourly row
///     takes the product's price like any row, so correcting a wrong service
///     corrects the money — the Service cell commits the typed search text as
///     `productKey` before the pick, so "was a product picked before?" can't be
///     read off [base] and isn't used.
LineItem lineItemFromProduct(
  Product product, {
  LineItem? base,
  bool enableProductQuantity = false,
  bool defaultQuantity = false,
  Decimal? conversionRate,
  Company? company,
  bool partyTaxExempt = false,
}) {
  final rate = conversionRate ?? Decimal.one;
  final defaults = partyTaxExempt
      ? const <int, ({String name, Decimal rate})>{}
      : defaultItemTaxes(company);
  // A rate with no name is still charged (`InvoiceItemSum` taxes the rate
  // alone), so only a slot with neither is the product's "no tax".
  ({String name, Decimal rate}) tax(int slot, String name, Decimal rate) =>
      name.trim().isEmpty && rate == Decimal.zero
      ? (defaults[slot] ?? (name: name, rate: rate))
      : (name: name, rate: rate);
  final tax1 = tax(1, product.taxName1, product.taxRate1);
  final tax2 = tax(2, product.taxName2, product.taxRate2);
  final tax3 = tax(3, product.taxName3, product.taxRate3);
  final unitPrice = rate == Decimal.one ? product.price : product.price * rate;
  final Decimal quantity;
  if (!enableProductQuantity || defaultQuantity) {
    quantity = Decimal.one;
  } else {
    quantity = product.quantity > Decimal.zero ? product.quantity : Decimal.one;
  }
  final hourly = base != null && base.typeId == LineItemType.task;
  final billedTask = hourly && (base.taskId ?? '').isNotEmpty;
  return (base ?? emptyLineItem()).copyWith(
    productKey: product.productKey,
    notes: hourly && base.notes.isNotEmpty ? base.notes : product.notes,
    cost: billedTask && base.cost != Decimal.zero ? base.cost : unitPrice,
    productCost: product.cost,
    quantity: hourly ? base.quantity : quantity,
    taxName1: tax1.name,
    taxRate1: tax1.rate,
    taxName2: tax2.name,
    taxRate2: tax2.rate,
    taxName3: tax3.name,
    taxRate3: tax3.rate,
    taxCategoryId: product.taxId,
    customValue1: product.customValue1,
    customValue2: product.customValue2,
    customValue3: product.customValue3,
    customValue4: product.customValue4,
  );
}

/// The default tax a picked product's blank tax slot takes, by slot: the
/// company's Tax Settings → Default Tax Rate (`settings.tax_name<N>` /
/// `tax_rate<N>`) for slots `1..enabled_item_tax_rates` — but only when the
/// company has no document-level tiers (`enabled_tax_rates == 0`), the one
/// configuration where that picker sets the line default rather than the
/// document's (`tax_settings_body.dart`). The company's alone, as React's
/// `useResolveInputField` fills it — a client's override of the picker is
/// not read. Empty without a [company].
Map<int, ({String name, Decimal rate})> defaultItemTaxes(Company? company) {
  if (company == null || company.enabledTaxRates > 0) return const {};
  final s = company.settings;
  final slots = <int, ({String? name, double? rate})>{
    1: (name: s.taxName1, rate: s.taxRate1),
    2: (name: s.taxName2, rate: s.taxRate2),
    3: (name: s.taxName3, rate: s.taxRate3),
  };
  return {
    for (final MapEntry(key: n, value: v) in slots.entries)
      if (n <= company.enabledItemTaxRates && (v.name ?? '').trim().isNotEmpty)
        n: (name: v.name!.trim(), rate: parseMoney(v.rate)),
  };
}

/// Cross-entity "New Invoice / Quote / Purchase Order from a product" flow
/// (`?product=<id>` on the create route — see `entity_modules.dart` and the
/// three edit screens). A brand-new doc with no client yet, so the sale price
/// is used verbatim at quantity 1; [company] supplies only the default item
/// tax. [lineItemFromProduct] does the work (and also copies the product's
/// cost / tax category / customs).
LineItem lineItemForProduct(Product product, {Company? company}) =>
    lineItemFromProduct(product, company: company);

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
  /// drops the links back to the source records — `taskId` / `expenseId`. An
  /// expense-derived row becomes a plain `standard` line; an hourly row stays
  /// hourly (`task`) unless [keepTaskType] is false, so a cloned hourly invoice
  /// still prints its lines in the PDF's task table. admin-portal keeps the
  /// type too. The purchase order is the exception — see [clonedLineItems].
  ///
  /// Without this, cloning an invoice that billed task T and then re-pointing
  /// the clone at a different client — the canonical "same work, new client"
  /// use of clone — dead-ends: `validateCrossClient` sees the line still
  /// claiming T (whose client is the ORIGINAL one), returns a `line_items`
  /// error, and `save()` hard-returns. The message names no field the form can
  /// fix, so the only way out is deleting and retyping the line. admin-portal
  /// clears both ids for exactly this reason (`InvoiceItemEntity.clone`).
  LineItem freshClone({bool keepTaskType = true}) => copyWith(
    taskId: null,
    expenseId: null,
    typeId:
        (typeId == LineItemType.task && !keepTaskType) ||
            typeId == LineItemType.expense
        ? LineItemType.standard
        : typeId,
  );
}

/// Line items for a *cloned* billing doc: every row sanitised by
/// [LineItemClone.freshClone], and server-generated unpaid-fee rows dropped
/// entirely — those are a gateway fee the server added to the ORIGINAL
/// document, and carrying one into a new draft re-bills it. Mirrors
/// admin-portal `InvoiceEntity.clone`.
///
/// Pass `keepTaskType: false` when the clone is a purchase order: the server
/// renders no task table for a PO (`PdfBuilder::taskTable`) and its product
/// table takes only types 1/4/5/6, so an hourly line would count in the
/// totals and print nowhere.
List<LineItem> clonedLineItems(
  List<LineItem> items, {
  bool keepTaskType = true,
}) => [
  for (final item in items)
    if (item.typeId != LineItemType.unpaidFee)
      item.freshClone(keepTaskType: keepTaskType),
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
