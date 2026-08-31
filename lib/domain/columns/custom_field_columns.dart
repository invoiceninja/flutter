import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/company_custom_fields.dart';
import 'package:admin/data/models/domain/custom_field_types.dart';
import 'package:admin/domain/columns/column_cells.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/formatter_scope.dart';

/// Company-configurable `custom_value1..4` list columns.
///
/// Two halves. [customFieldColumns] builds the four **raw** definitions an
/// entity registers; [decorateCustomFieldColumns] is the pass the list
/// ViewModel runs whenever the active company changes, which resolves each
/// slot's configured label, formats switch / date values, and **drops** slots
/// the company hasn't configured.
///
/// Like `column_cells.dart` this lives under `lib/domain/` but is a UI helper
/// (it builds Widgets and reads `FormatterScope`); the location is the same
/// pre-existing misfiling, not a new layering regression. Nothing under
/// `lib/data/**` imports it.

/// The four raw custom-field columns for one entity.
///
/// Raw = the stored value verbatim under the entity's own `custom1` /
/// `custom_value1` translation key, which is exactly what every registry
/// rendered before this existed. The company's label and the type-aware cell
/// arrive later, via [decorateCustomFieldColumns].
///
/// [ids] is passed explicitly rather than derived because the wire ids are NOT
/// uniform: client / vendor / product / project / task persist `custom1..4`
/// while billing docs, expenses and payments persist `custom_value1..4`. Those
/// strings are shared with the legacy admin-portal through
/// `userCompany.settings.table_columns`, so renaming one silently drops a
/// user's saved column set.
///
/// [prefix] is the `Company.customFields` key prefix, which is often NOT the
/// entity name — see [CustomFieldSlot.prefix].
List<ColumnDefinition<T>> customFieldColumns<T>({
  required String prefix,
  required List<String> ids,
  required List<String Function(T entity)> values,
  double width = 140,
  bool sortable = true,
}) {
  assert(ids.length == 4, 'expected the four custom-field slot ids');
  assert(values.length == 4, 'expected the four custom-field accessors');
  return <ColumnDefinition<T>>[
    for (var i = 1; i <= 4; i++)
      ColumnDefinition<T>(
        id: ids[i - 1],
        // Every registry already used id == labelKey ('custom1' and
        // 'custom_value1' are both real keys), so an undecorated render is
        // byte-identical to what shipped before.
        labelKey: ids[i - 1],
        width: width,
        sortable: sortable,
        cellBuilder: (e, _) => cellText(values[i - 1](e)),
        // Canonical, not display: the hover-copy affordance copies what
        // round-trips back into the field, exactly as a money cell shows
        // "$1,234.50" and copies "1234.50".
        valueBuilder: (e) => cellNonZeroString(values[i - 1](e)),
        customField: CustomFieldSlot<T>(
          prefix: prefix,
          index: i,
          valueOf: values[i - 1],
        ),
      ),
  ];
}

/// [columns] with every custom-field slot either resolved against [company] or
/// removed. Non-custom columns pass through untouched, in registry order.
///
/// A slot is **dropped** when the company hasn't configured a label for it, and
/// while [company] is still null on a cold start. Both mirror
/// `CustomFieldFilterKey.isAvailable` and `customFieldDetailRows`: a slot with
/// no label has no honest header, and rendering it raw would flash the exact
/// `CUSTOM VALUE 1` header this exists to remove. Dropping is non-destructive —
/// `GenericListViewModel` keeps the id in `_columnIds` (and therefore in
/// `user_settings`), so the column reappears the moment the label comes back.
List<ColumnDefinition<T>> decorateCustomFieldColumns<T>(
  List<ColumnDefinition<T>> columns,
  Company? company,
) {
  // Most entities carry no slots at all. Returning the SAME instance keeps
  // their column resolution allocation-free and identical to before.
  if (!columns.any((c) => c.customField != null)) return columns;

  final co = company;
  if (co == null) {
    return <ColumnDefinition<T>>[
      for (final c in columns)
        if (c.customField == null) c,
    ];
  }

  final out = <ColumnDefinition<T>>[];
  for (final column in columns) {
    final slot = column.customField;
    if (slot == null) {
      out.add(column);
      continue;
    }
    final parsed = parseCustomField(co.customFields[slot.companyKey]);
    final label = parsed.label;
    if (label.isEmpty) continue;

    switch (parsed.type) {
      case kFieldTypeSwitch:
      case kFieldTypeDate:
        // Capture the parsed TYPE, not the `Company`, and go through the
        // shared [displayCustomFieldValue] rather than
        // `company.customFieldDisplay` — the latter re-runs
        // `parseCustomField` on every call, which here is once per cell per
        // build (~200 map lookups + substrings a frame at 50 rows x 4 slots)
        // for something already resolved right here. Capturing the type also
        // means the cached column list pins no `Company` instance.
        final type = parsed.type;
        final valueOf = slot.valueOf;
        out.add(
          column.withResolvedLabel(
            label: label,
            cellBuilder: (entity, context) {
              final raw = valueOf(entity);
              if (raw.isEmpty) return cellEmpty();
              final text = displayCustomFieldValue(
                type: type,
                value: raw,
                formatter: FormatterScope.maybeOf(context),
                yes: context.tr('yes'),
                no: context.tr('no'),
              );
              // A date slot holding non-ISO junk formats to '' — em-dash it
              // rather than paint a blank cell (`customFieldDetailRows` skips
              // the row for the same reason).
              return text.isEmpty ? cellEmpty() : cellText(text);
            },
          ),
        );
      default:
        // single_line_text / multi_line_text / dropdown all display verbatim,
        // so the registry's own `cellText(raw)` builder is already right.
        // Reusing it saves a `dependOnInheritedWidgetOfExactType` plus two
        // `tr` lookups per cell per build in the common case.
        out.add(column.withResolvedLabel(label: label));
    }
  }
  return out;
}

/// Everything [decorateCustomFieldColumns] reads out of [company], as one
/// comparable string. The list ViewModel stores it and rebuilds — and notifies
/// — only when it changes.
///
/// The **type** is load-bearing, not just the label: flipping `Region|switch`
/// to `Region|date` in Settings changes what every cell renders while leaving
/// every header identical, and a label-only signature (which is all
/// `ProductListViewModel`'s grouping needs) would never repaint. Dropdown
/// *options* are deliberately excluded — they don't affect display, since the
/// stored value renders verbatim either way.
String customFieldColumnSignature<T>(
  List<ColumnDefinition<T>> columns,
  Company? company,
) {
  final co = company;
  final buffer = StringBuffer();
  for (final column in columns) {
    final slot = column.customField;
    if (slot == null) continue;
    // Control-character separators, so a label that happens to contain the
    // delimiter cannot forge another slot's signature.
    buffer.write(column.id);
    buffer.write('\u0001');
    if (co != null) {
      buffer.write(co.customFieldLabel(slot.companyKey));
      buffer.write('\u0001');
      buffer.write(co.customFieldType(slot.companyKey));
    }
    buffer.write('\u0000');
  }
  return buffer.toString();
}
