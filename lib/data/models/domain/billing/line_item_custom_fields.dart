import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/data/models/domain/billing/line_item_type.dart';
import 'package:admin/data/models/domain/company_custom_fields.dart';
import 'package:admin/data/models/domain/custom_field_types.dart';
import 'package:admin/utils/formatting.dart';

/// One configured custom-field slot on a line item: which of the four
/// `customValue1..4` it reads, and the company's definition for it.
class LineItemCustomField {
  const LineItemCustomField({required this.slot, required this.field});

  /// 1-based slot — `customValue1..4`.
  final int slot;

  /// The company's parsed `"Label|type"` definition. The label is never empty
  /// — [lineItemCustomFields] drops unconfigured slots.
  final ParsedCustomField field;
}

/// The custom-field slots a line item shows, in slot order.
///
/// A line item's four `custom_value`s carry no definitions of their own: a
/// product line borrows the company's `product1..4` and an hourly line its
/// `task1..4` — the split React, admin-portal and the server's PDF tables all
/// make. A slot with no label is unconfigured and is left out, so an empty
/// result means the company has defined none.
List<LineItemCustomField> lineItemCustomFields(
  Map<String, String>? customFields, {
  required bool task,
}) {
  if (customFields == null) return const [];
  final prefix = task ? 'task' : 'product';
  final fields = <LineItemCustomField>[];
  for (var slot = 1; slot <= 4; slot++) {
    final field = parseCustomField(customFields['$prefix$slot']);
    if (field.label.isEmpty) continue;
    fields.add(LineItemCustomField(slot: slot, field: field));
  }
  return fields;
}

/// Whether [item] is labelled from the company's `task1..4` rather than
/// `product1..4`.
///
/// Keyed on the type alone, as the server's PDF builder is: only `type_id` 2
/// prints in the task table, and an expense line (type 6) is a product row.
bool lineItemUsesTaskFields(LineItem item) => item.typeId == LineItemType.task;

/// The stored value in 1-based [slot] of [item]'s four custom values.
String lineItemCustomValue(LineItem item, int slot) => switch (slot) {
  1 => item.customValue1,
  2 => item.customValue2,
  3 => item.customValue3,
  _ => item.customValue4,
};

/// [item] with 1-based [slot] of its custom values set to [value].
LineItem withLineItemCustomValue(LineItem item, int slot, String value) =>
    switch (slot) {
      1 => item.copyWith(customValue1: value),
      2 => item.copyWith(customValue2: value),
      3 => item.copyWith(customValue3: value),
      _ => item.copyWith(customValue4: value),
    };

/// `(label, display value)` for each of [fields] that [item] holds a value
/// in, for read-only summaries — the phone card and the detail table.
///
/// The same rules as `customFieldDetailRows`: an empty value is skipped, and so
/// is one that formats to nothing (a date slot holding non-ISO text), rather
/// than rendering a bare "Label:". A switch reads [yes] / [no] and a date goes
/// through [formatter]. A date slot holding text that is no date is skipped
/// even before the formatter has loaded — `displayCustomFieldValue` passes
/// the raw value through when it has none, which painted "Shipped: soon" on a
/// phone card's first frame.
///
/// Newlines in a multi-line value collapse to a space: these rows are joined
/// into one summary line, where a newline would push every field after it out
/// of a one- or two-line `Text`.
List<({String label, String value})> lineItemCustomValueRows(
  LineItem item,
  List<LineItemCustomField> fields, {
  required String yes,
  required String no,
  Formatter? formatter,
}) {
  final rows = <({String label, String value})>[];
  for (final f in fields) {
    final raw = lineItemCustomValue(item, f.slot);
    if (raw.isEmpty) continue;
    if (f.field.type == kFieldTypeDate && DateTime.tryParse(raw) == null) {
      continue;
    }
    final display = displayCustomFieldValue(
      type: f.field.type,
      value: raw,
      formatter: formatter,
      yes: yes,
      no: no,
    ).replaceAll(RegExp(r'\s*\n\s*'), ' ').trim();
    if (display.isEmpty) continue;
    rows.add((label: f.field.label, value: display));
  }
  return rows;
}
