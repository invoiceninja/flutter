import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/company_custom_fields.dart';
import 'package:admin/domain/date_placeholders.dart';
import 'package:admin/utils/formatting.dart';

/// `(label, display value)` pairs for read-only custom-field rows on entity
/// detail screens.
///
/// A slot is included only when its label is configured in the company's
/// `custom_fields` **and** the stored value is non-empty — mirroring React,
/// which hides custom fields that have no configured label. The display value
/// is type-aware: switch → localized [yes] / [no], date → [formatter] (ISO
/// fallback), everything else verbatim — except that a text or dropdown value
/// under a prefix the server expands reserved date keywords in
/// ([customFieldExpandsDateKeywords]) shows the dates it will print as, the
/// same as a product's description does (invoiceninja/flutter#93).
///
/// [values] are `customValue1..4` in order; [prefix] is the entity key prefix
/// (e.g. `'client'`, `'task'`, `'expense'`). Returns `const []` while the
/// company is still loading (null) so callers can collapse the card. [now]
/// pins the keyword clock (tests).
List<({String label, String value})> customFieldDetailRows({
  required Company? company,
  required String prefix,
  required List<String> values,
  required String yes,
  required String no,
  Formatter? formatter,
  DateTime? now,
}) {
  if (company == null) return const [];
  final expand = customFieldExpandsDateKeywords(prefix);
  final rows = <({String label, String value})>[];
  for (var i = 1; i <= 4; i++) {
    final key = '$prefix$i';
    final label = company.customFieldLabel(key);
    final raw = values[i - 1];
    if (label.isEmpty || raw.isEmpty) continue;
    final display = company.customFieldDisplay(
      key,
      raw,
      formatter: formatter,
      yes: yes,
      no: no,
      expandDateKeywords: expand,
      now: now,
    );
    // A date-typed slot holding non-ISO garbage formats to '' — skip rather
    // than render a "Label: <blank>" row.
    if (display.isEmpty) continue;
    rows.add((label: label, value: display));
  }
  return rows;
}
