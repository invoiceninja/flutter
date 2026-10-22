import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/custom_field_types.dart';
import 'package:admin/domain/date_placeholders.dart';
import 'package:admin/utils/formatting.dart';

/// Convenience accessors for the company's per-entity custom-field
/// configuration map.
///
/// The server stores per-entity custom field definitions in
/// `Company.customFields` under keys like `client1..4`, `product1..4`,
/// `invoice1..4`, `contact1..4` — each value follows the pipe-delimited shape
/// `"Label|type"` / `"Label|opt1,opt2"`. All parsing routes through the shared
/// [parseCustomField] so settings and consumers stay in lockstep.
extension CompanyCustomFields on Company {
  /// Parsed label for the slot at [key]. Returns the empty string when the
  /// slot is unconfigured (missing key or empty value), so call sites can
  /// gate visibility with `.isEmpty` without a nullable hop.
  ///
  /// Examples (given `customFields = {'client1': 'Region|North,South'}`):
  /// * `customFieldLabel('client1')` → `'Region'`
  /// * `customFieldLabel('client2')` → `''`
  String customFieldLabel(String key) =>
      parseCustomField(customFields[key]).label;

  /// Render type (`kFieldType*`) for the slot at [key]. An unconfigured slot
  /// resolves to [kFieldTypeSingleLineText] — callers gate on the empty label
  /// first, so the default only matters for configured slots.
  String customFieldType(String key) =>
      parseCustomField(customFields[key]).type;

  /// Dropdown options for the slot at [key]; empty for non-dropdown types.
  List<String> customFieldOptions(String key) =>
      parseCustomField(customFields[key]).options;

  /// Format a stored custom [value] for read-only display on detail screens.
  /// Switch values surface as the localized [yes] / [no]; dates run through
  /// [formatter] (ISO fallback when null); everything else shows verbatim, or
  /// with its reserved date keywords expanded when [expandDateKeywords].
  String customFieldDisplay(
    String key,
    String value, {
    Formatter? formatter,
    required String yes,
    required String no,
    bool expandDateKeywords = false,
    DateTime? now,
  }) => displayCustomFieldValue(
    type: customFieldType(key),
    value: value,
    formatter: formatter,
    yes: yes,
    no: no,
    expandDateKeywords: expandDateKeywords,
    now: now,
  );
}

/// [CompanyCustomFields.customFieldDisplay] with the slot's render type already
/// resolved.
///
/// Split out for the callers that know the type up front and would otherwise
/// re-parse the company's `"Label|type"` string on every call — the list-table
/// custom-field cells resolve it once per company emission and would otherwise
/// re-parse once per cell per frame. Both paths share this body so a new field
/// type can't reach one surface and miss the other.
///
/// [expandDateKeywords] renders a text / dropdown value's reserved date
/// keywords (`:MONTH`, `[MONTHYEAR|MONTHYEAR+12]`, …) as the dates the server
/// prints — exactly its `formatCustomFieldValue`, whose `default:` branch is
/// the only one that expands. **Display only**: pass it from a read-only
/// surface whose slot prefix passes `customFieldExpandsDateKeywords`, never
/// from an editor, where the token is the value. [now] pins the clock (tests).
String displayCustomFieldValue({
  required String type,
  required String value,
  required String yes,
  required String no,
  Formatter? formatter,
  bool expandDateKeywords = false,
  DateTime? now,
}) {
  switch (type) {
    case kFieldTypeSwitch:
      return isSwitchTruthy(value) ? yes : no;
    case kFieldTypeDate:
      return value.isEmpty ? '' : (formatter?.date(value) ?? value);
    default:
      return expandDateKeywords
          ? expandDatePlaceholders(value, formatter: formatter, now: now)
          : value;
  }
}
