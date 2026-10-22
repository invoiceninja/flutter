/// Canonical custom-field type system.
///
/// The server stores each per-entity custom field in `company.custom_fields`
/// under keys like `client1..4`, `invoice1..4`, `contact1..4` — each value is
/// pipe-delimited: `"<label>|<type>"` or `"<label>|opt1,opt2"` for a dropdown.
///
/// This module is the **single source of truth** for parsing that shape. Both
/// the settings editor (`custom_field_row.dart`) and the runtime entity
/// widgets (`entity_custom_fields_section.dart`, `company_custom_fields.dart`)
/// route through [parseCustomField] so the writer and reader can never
/// diverge. Deliberately Flutter-free so it stays trivially unit-testable.
library;

import 'package:collection/collection.dart';

/// Single-line text input.
const String kFieldTypeSingleLineText = 'single_line_text';

/// Multi-line text input. **Reserved** — the settings editor writes this
/// explicit keyword, so [kReservedCustomFieldTypes] must contain it; otherwise
/// `"Notes|multi_line_text"` would mis-parse as a one-option dropdown.
const String kFieldTypeMultiLineText = 'multi_line_text';

/// Boolean toggle. The stored `custom_value` is the literal `'yes'` / `'no'`
/// (see [kSwitchValueYes] / [kSwitchValueNo]) — matches React + admin-portal.
const String kFieldTypeSwitch = 'switch';

/// Date picker. The stored `custom_value` is an ISO `yyyy-MM-dd` string.
const String kFieldTypeDate = 'date';

/// Dropdown. Options are the comma-separated suffix after the pipe; the stored
/// `custom_value` is the selected option verbatim (empty string = unselected).
const String kFieldTypeDropdown = 'dropdown';

/// Canonical stored values for a [kFieldTypeSwitch] custom value.
const String kSwitchValueYes = 'yes';
const String kSwitchValueNo = 'no';

/// Whether a stored switch [value] is "on". Writes are always canonical
/// `'yes'`/`'no'`, but reads tolerate legacy / imported `'true'` / `'1'` —
/// matching React's `InputCustomField` truthy check.
bool isSwitchTruthy(String value) =>
    value == kSwitchValueYes || value == 'true' || value == '1';

/// Type segments recognized as keywords. Anything else after the pipe is a
/// dropdown's options list. Includes [kFieldTypeMultiLineText] because the
/// settings editor emits that keyword explicitly.
const Set<String> kReservedCustomFieldTypes = {
  kFieldTypeSingleLineText,
  kFieldTypeMultiLineText,
  kFieldTypeSwitch,
  kFieldTypeDate,
};

/// Parsed view of one `custom_fields` slot value (`"<label>|<suffix>"`).
class ParsedCustomField {
  const ParsedCustomField({
    required this.label,
    required this.type,
    required this.options,
  });

  /// Display label (before the pipe). Empty when the slot is unconfigured —
  /// call sites gate visibility on `label.isEmpty`.
  final String label;

  /// One of the `kFieldType*` codes. An unconfigured slot resolves to
  /// [kFieldTypeSingleLineText] (callers gate on the empty label first).
  final String type;

  /// Dropdown options; `const []` for every non-dropdown type.
  final List<String> options;

  // Value equality: a company's definitions are re-parsed on every company
  // emission, and the line-item table compares its column config to decide
  // whether a row needs rebuilding.
  @override
  bool operator ==(Object other) =>
      other is ParsedCustomField &&
      other.label == label &&
      other.type == type &&
      const ListEquality<String>().equals(other.options, options);

  @override
  int get hashCode =>
      Object.hash(label, type, const ListEquality<String>().hash(options));
}

/// The label of a surcharge slot (`custom_fields['surcharge1'..'4']`).
///
/// This app and React store the bare label, but admin-portal saved
/// `"Label|single_line_text"` — its type dropdown is hidden for surcharges,
/// not skipped — so a label read raw showed the type keyword after it. The
/// label is everything before the first pipe, which is also how the server's
/// `Helpers::makeCustomField` reads it for the PDF. Not [parseCustomField]:
/// a surcharge has no type, and a bare label must not mean multi-line text.
String surchargeLabel(String? raw) {
  if (raw == null) return '';
  final idx = raw.indexOf('|');
  return idx < 0 ? raw : raw.substring(0, idx);
}

/// Parse a raw `custom_fields` slot value into label + type + options.
///
/// Rules (identical to the legacy `_parsedType` / `_parsedOptions` in
/// `custom_field_row.dart`, and React's `Field.tsx` `useEffect`):
/// * `null` / empty            → label `''`, [kFieldTypeSingleLineText]
/// * no pipe, non-empty        → legacy [kFieldTypeMultiLineText]
/// * empty suffix (`"Label|"`) → [kFieldTypeDropdown] with no options
/// * reserved keyword suffix   → that type
/// * any other suffix          → [kFieldTypeDropdown], options = `suffix.split(',')`
ParsedCustomField parseCustomField(String? raw) {
  if (raw == null || raw.isEmpty) {
    return const ParsedCustomField(
      label: '',
      type: kFieldTypeSingleLineText,
      options: [],
    );
  }
  final idx = raw.indexOf('|');
  if (idx < 0) {
    // Legacy shape: no pipe means multi-line text.
    return ParsedCustomField(
      label: raw,
      type: kFieldTypeMultiLineText,
      options: const [],
    );
  }
  final label = raw.substring(0, idx);
  final suffix = raw.substring(idx + 1);
  if (suffix.isEmpty) {
    // "Label|" — a dropdown with no options typed yet.
    return ParsedCustomField(
      label: label,
      type: kFieldTypeDropdown,
      options: const [],
    );
  }
  if (kReservedCustomFieldTypes.contains(suffix)) {
    return ParsedCustomField(label: label, type: suffix, options: const []);
  }
  return ParsedCustomField(
    label: label,
    type: kFieldTypeDropdown,
    options: suffix.split(','),
  );
}
