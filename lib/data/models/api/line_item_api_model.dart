import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:admin/data/models/api/json_coercion.dart';

part 'line_item_api_model.freezed.dart';
part 'line_item_api_model.g.dart';

/// Raw JSON shape of a single line item nested inside an invoice / quote /
/// credit / purchase_order / recurring_invoice envelope.
///
/// Money fields stay as `Object` (the server flips between number and
/// string); parsed via `parseMoney` in [LineItem.fromApi]. Tax rates are
/// also `Object` for the same reason — parsed to `Decimal` (not `double`)
/// to match the rest of the codebase + the CI lint test.
///
/// String fields are coerced through [jsonScalarToStringOrEmpty] (non-null) /
/// [jsonScalarToString] (nullable) for the same reason: the server emits
/// `line_items` as raw stored JSON with no read-time casting (only the
/// save-time `CleanLineItems` cleaner coerces types), so a discriminator/id
/// like `type_id` / `tax_id` can arrive as `1` (int) on older or API-created
/// invoices — a plain `as String?` cast would throw.
///
/// `type_id` is a wire-string discriminator (`'1'..'6'`); decoded via
/// [LineItemType.fromWire], which maps `''`/unknown → standard (so the
/// converter's null→`''` is equivalent to the old `'1'` default downstream).
@freezed
abstract class LineItemApi with _$LineItemApi {
  const factory LineItemApi({
    @JsonKey(name: 'product_key', fromJson: jsonScalarToStringOrEmpty)
    @Default('')
    String productKey,
    @JsonKey(fromJson: jsonScalarToStringOrEmpty) @Default('') String notes,
    @Default('0') Object cost,
    @JsonKey(name: 'product_cost') @Default('0') Object productCost,
    @Default('1') Object quantity,
    @JsonKey(name: 'tax_name1', fromJson: jsonScalarToStringOrEmpty)
    @Default('')
    String taxName1,
    @JsonKey(name: 'tax_name2', fromJson: jsonScalarToStringOrEmpty)
    @Default('')
    String taxName2,
    @JsonKey(name: 'tax_name3', fromJson: jsonScalarToStringOrEmpty)
    @Default('')
    String taxName3,
    @JsonKey(name: 'tax_rate1') @Default('0') Object taxRate1,
    @JsonKey(name: 'tax_rate2') @Default('0') Object taxRate2,
    @JsonKey(name: 'tax_rate3') @Default('0') Object taxRate3,
    @JsonKey(name: 'type_id', fromJson: jsonScalarToStringOrEmpty)
    @Default('1')
    String typeId,
    @JsonKey(name: 'custom_value1', fromJson: jsonScalarToStringOrEmpty)
    @Default('')
    String customValue1,
    @JsonKey(name: 'custom_value2', fromJson: jsonScalarToStringOrEmpty)
    @Default('')
    String customValue2,
    @JsonKey(name: 'custom_value3', fromJson: jsonScalarToStringOrEmpty)
    @Default('')
    String customValue3,
    @JsonKey(name: 'custom_value4', fromJson: jsonScalarToStringOrEmpty)
    @Default('')
    String customValue4,
    @Default('0') Object discount,
    @JsonKey(name: 'task_id', fromJson: jsonScalarToString) String? taskId,
    @JsonKey(name: 'expense_id', fromJson: jsonScalarToString)
    String? expenseId,
    // Legacy admin-portal calls this `tax_id` on the wire; the domain
    // model surfaces it as `taxCategoryId` so it doesn't collide with
    // the `taxName1` / `taxRate1` triple.
    @JsonKey(name: 'tax_id', fromJson: jsonScalarToStringOrEmpty)
    @Default('')
    String taxCategoryId,
    @JsonKey(name: 'created_at') int? createdAt,
    // A quote line the client may choose to include when approving it. Not
    // on the server yet (2026-11): the flag is new, and until the server
    // models it the field rides in the stored line JSON untouched.
    @JsonKey(name: 'is_optional', fromJson: jsonScalarToBool)
    @Default(false)
    bool isOptional,
    // Every field of the line this model doesn't name — see
    // [lineItemExtraFields]. Read by the custom [LineItemApi.fromJson], never
    // by the generated one.
    @JsonKey(includeFromJson: false, includeToJson: false)
    @Default(<String, Object?>{})
    Map<String, Object?> extra,
  }) = _LineItemApi;

  factory LineItemApi.fromJson(Map<String, dynamic> json) =>
      _$LineItemApiFromJson(json).copyWith(extra: lineItemExtraFields(json));
}

/// The wire keys [LineItemApi] models — everything else on a line is [extra].
const Set<String> kModeledLineItemKeys = {
  'product_key',
  'notes',
  'cost',
  'product_cost',
  'quantity',
  'tax_name1',
  'tax_name2',
  'tax_name3',
  'tax_rate1',
  'tax_rate2',
  'tax_rate3',
  'type_id',
  'custom_value1',
  'custom_value2',
  'custom_value3',
  'custom_value4',
  'discount',
  'task_id',
  'expense_id',
  'tax_id',
  'created_at',
  'is_optional',
};

/// Line fields the server writes on every save from the document's own
/// state (`InvoiceItemSum`: the totals, and `is_amount_discount` copied from
/// the document) — echoing a stale copy back would mean nothing.
const Set<String> kServerComputedLineItemKeys = {
  'line_total',
  'gross_line_total',
  'tax_amount',
  'net_cost',
  'is_amount_discount',
};

/// The fields of a line this app doesn't model, carried through an edit
/// untouched. The server replaces `line_items` whole on every save, so a
/// field dropped here is a field wiped: before this, any save from the app
/// reset a line's e-invoice `unit_code` to `C62` and cleared its
/// `income_account_id` (QuickBooks), `tags`, `date` and `sort_id` — and would
/// clear whatever the server adds next. Keyed as the server sent them.
Map<String, Object?> lineItemExtraFields(Map<String, dynamic> json) => {
  for (final e in json.entries)
    if (!kModeledLineItemKeys.contains(e.key) &&
        !kServerComputedLineItemKeys.contains(e.key))
      e.key: e.value,
};
