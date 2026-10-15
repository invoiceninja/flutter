import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/custom_field_types.dart';
import 'package:admin/ui/core/edit/entity_edit_field.dart';
import 'package:admin/ui/core/widgets/in_date_field.dart';
import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';
import 'package:admin/utils/formatting.dart';

/// The form input for one configured custom-field slot, picked by the slot's
/// **type**: single-line text, multi-line text, switch (`'yes'`/`'no'`), date
/// (ISO `yyyy-MM-dd`), or a dropdown over comma-separated options.
///
/// Shared by every surface that edits a custom value — the entity edit
/// screens (through `EntityCustomFieldsSection`) and the line-item edit
/// dialog — so a field type can't reach one and miss the other. The caller
/// resolves [field] from the company's `custom_fields` and skips slots with
/// no label; this widget renders whatever it is handed.
class CustomFieldInput extends StatelessWidget {
  const CustomFieldInput({
    super.key,
    required this.field,
    required this.value,
    required this.onChanged,
    this.formatter,
  });

  /// The slot's parsed definition. Its label names the field.
  final ParsedCustomField field;

  /// The stored value — `''` when unset.
  final String value;

  /// Receives the new stored value, already in its wire shape.
  final ValueChanged<String> onChanged;

  /// Active company `Formatter`, used to render/parse a date-typed field.
  /// When null, a date falls back to ISO display + parsing.
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    switch (field.type) {
      case kFieldTypeMultiLineText:
        return EntityEditField(
          label: field.label,
          initial: value,
          onChanged: onChanged,
          minLines: 3,
          maxLines: 3,
        );
      case kFieldTypeSwitch:
        return _CustomSwitchRow(
          label: field.label,
          value: value,
          onChanged: onChanged,
        );
      case kFieldTypeDate:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: InSpacing.xs),
          child: InDateField(
            labelText: field.label,
            formatter: formatter,
            clearable: true,
            value: customFieldDate(value),
            onChanged: (d) => onChanged(d == null ? '' : customFieldIsoDate(d)),
          ),
        );
      case kFieldTypeDropdown:
        final items = customFieldDropdownItems(field, value);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: InSpacing.xs),
          child: SearchableDropdownField<String>(
            label: field.label,
            items: items,
            initialValue: items.contains(value) ? value : '',
            displayString: (o) => o,
            idOf: (o) => o,
            onChanged: (o) => onChanged(o ?? ''),
          ),
        );
      case kFieldTypeSingleLineText:
      default:
        return EntityEditField(
          label: field.label,
          initial: value,
          onChanged: onChanged,
        );
    }
  }
}

/// The options a dropdown-typed custom field offers for a stored [value].
///
/// A blank leads, so the user can clear the field and so the list is never
/// empty (an empty list renders `SearchableDropdownField`'s "loading"
/// placeholder); picking it writes `''`. A stored value that is no longer one
/// of the configured options (the options were edited after it was set, or
/// another client wrote it) is appended, so it stays visible and
/// re-selectable instead of silently rendering blank.
List<String> customFieldDropdownItems(ParsedCustomField field, String value) =>
    <String>[
      '',
      ...field.options,
      if (value.isNotEmpty && !field.options.contains(value)) value,
    ];

/// The calendar date a date-typed custom [value] holds, or null when it holds
/// none.
///
/// Only the leading `yyyy-MM-dd` is read, as a local date. The wire value is a
/// bare date, but one written by the API, an import or another client can
/// carry a time and zone (`2026-05-14T00:00:00Z`), and parsing that whole
/// gives a UTC instant `InDateField` renders through `toLocal()` — May 13 west
/// of UTC, while every read-only surface (`Formatter.date`) shows the 14th,
/// and a re-pick then saves the 13th.
DateTime? customFieldDate(String value) {
  if (value.length < 10) return DateTime.tryParse(value);
  return DateTime.tryParse(value.substring(0, 10));
}

/// ISO `yyyy-MM-dd` for a calendar date — the wire format for date-typed
/// custom values (matches React's `<input type="date">` + admin-portal).
String customFieldIsoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Switch-typed custom field: a [Switch] + label row. Stored value is the
/// canonical `'yes'` / `'no'` string.
class _CustomSwitchRow extends StatelessWidget {
  const _CustomSwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: InSpacing.xs),
      child: Row(
        children: [
          Switch(
            value: isSwitchTruthy(value),
            onChanged: (v) => onChanged(v ? kSwitchValueYes : kSwitchValueNo),
          ),
          SizedBox(width: InSpacing.sm),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}
