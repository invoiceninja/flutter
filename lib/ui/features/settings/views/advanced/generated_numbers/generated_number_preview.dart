import 'package:intl/intl.dart';

import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/company_custom_fields.dart';

/// Sample stand-in values for the record-derived tokens that have no real value
/// on the settings screen (there's no client / vendor / user record in scope).
/// The deterministic tokens — counter, year, date, user_id — render real values.
const _kSampleNumber = '0001';
const _kSampleIdNumber = 'ID-0001';

/// Build the read-only preview string for an entity's generated number.
///
/// Mirrors Invoice Ninja's `GeneratesCounter::getFormattedEntityNumber`
/// (`app/Utils/Traits/GeneratesCounter.php`): the [counter] is zero-padded to
/// [padding] first, then the `{$...}` tokens are substituted. [now] and
/// [company] are injected so the same pure call powers both the live UI
/// (`now: DateTime.now()`) and deterministic unit tests. [now] is device-local,
/// not the company timezone (the backend renders `{$year}`/`{$date:…}` in the
/// company tz); for a read-only preview that only diverges near midnight across
/// zones that's an accepted approximation — the app bundles no tzdb.
///
/// [showClient] / [showVendor] mirror the tab's chip gating: a token whose group
/// isn't shown (e.g. `{$vendor_number}` on an invoice tab) is left literal —
/// matching the chip set the user actually has, and the fact it wouldn't
/// generate for that entity server-side.
String buildNumberPreview({
  required String pattern,
  required int counter,
  required int padding,
  required DateTime now,
  required bool showClient,
  required bool showVendor,
  required Company company,
  bool showVendorIdNumber = false,
}) {
  final padded = counter.toString().padLeft(padding, '0');

  // An empty pattern generates just the padded counter — the backend appends
  // `{$counter}` to a falsy pattern.
  if (pattern.trim().isEmpty) return padded;

  var result = pattern;

  // The backend appends `{$counter}` to any pattern >1 char that doesn't
  // already reference a counter token (GeneratesCounter.php), so a counter-less
  // pattern still gets its incrementing number. CONFIRMED on the demo server
  // (2026-07-16): the pattern `{$year}` generated `20260028` (year + counter).
  // Mirror it before substitution, else the preview shows a number the server
  // would never actually generate.
  if (pattern.length > 1 && !pattern.toLowerCase().contains('counter')) {
    result = '$result{\$counter}';
  }

  // Date tokens first, so a `{$date:...}` format string can't be clobbered by
  // the fixed-token pass. The capture group is the PHP `date()` format.
  result = result.replaceAllMapped(RegExp(r'\{\$date:(.*?)\}'), (m) {
    final fmt = m.group(1) ?? '';
    if (fmt.trim().isNotEmpty) {
      try {
        // No explicit locale: PHP `date()` renders English month/day names
        // regardless of the company locale, so the default (en_US) matches the
        // server — and it needs no `initializeDateFormatting`. Numeric formats
        // (Y-m-d, d/m/Y) are locale-independent.
        return DateFormat(phpDateFormatToIntl(fmt, now: now)).format(now);
      } catch (_) {
        // Unparseable format → fall through to the ISO fallback.
      }
    }
    return _manualIso(now);
  });

  // Fixed tokens. Every token ends in `}` with no prefix overlaps, so the
  // replace order is irrelevant. All three counter tokens render the padded
  // counter (backend renders them identically).
  final replacements = <String, String>{
    r'{$counter}': padded,
    r'{$client_counter}': padded,
    r'{$group_counter}': padded,
    r'{$year}': now.year.toString().padLeft(4, '0'),
    r'{$user_id}': '00', // backend pads user_id to 2 digits; 0 with no entity
    if (showClient) ...{
      r'{$client_number}': _kSampleNumber,
      r'{$client_id_number}': _kSampleIdNumber,
    },
    if (showVendor) r'{$vendor_number}': _kSampleNumber,
    // {$vendor_id_number} is the one vendor token the backend substitutes for a
    // Vendor entity too (not just Expense), so the Vendors tab shows it alone.
    if (showVendor || showVendorIdNumber)
      r'{$vendor_id_number}': _kSampleIdNumber,
  };
  replacements.forEach((token, value) {
    result = result.replaceAll(token, value);
  });

  // Custom-field tokens → the slot's configured label (e.g. "Region"). Left
  // literal when the slot has no label, so the token isn't silently swallowed.
  if (showClient) result = _replaceCustom(result, company, 'client');
  if (showVendor) result = _replaceCustom(result, company, 'vendor');
  result = _replaceCustom(result, company, 'user');

  return result;
}

String _replaceCustom(String input, Company company, String prefix) {
  var result = input;
  for (var i = 1; i <= 4; i++) {
    final label = company.customFieldLabel('$prefix$i');
    if (label.isEmpty) continue;
    result = result.replaceAll('{\$${prefix}_custom$i}', label);
  }
  return result;
}

/// ISO fallback that never touches locale data, so it can't throw.
String _manualIso(DateTime now) =>
    '${now.year.toString().padLeft(4, '0')}-'
    '${now.month.toString().padLeft(2, '0')}-'
    '${now.day.toString().padLeft(2, '0')}';

/// English ordinal suffix for a day-of-month: `1` → `st`, `2` → `nd`,
/// `3` → `rd`, everything else → `th`; `11`–`13` are always `th`. Mirrors PHP's
/// `date('S')`.
String _ordinalSuffix(int day) {
  if (day >= 11 && day <= 13) return 'th';
  switch (day % 10) {
    case 1:
      return 'st';
    case 2:
      return 'nd';
    case 3:
      return 'rd';
    default:
      return 'th';
  }
}

/// Convert a PHP `date()` format string to an `intl` [DateFormat] pattern.
///
/// Known PHP format letters map to their intl equivalents; every other run of
/// characters is single-quote-escaped so `DateFormat` treats it as a literal
/// and never throws on an unknown letter. PHP backslash escapes (`\X`) emit a
/// literal `X`.
///
/// PHP `S` (English ordinal suffix, e.g. `jS` → "3rd") has no intl token, so
/// when [now] is supplied the computed suffix for `now.day` is spliced in as a
/// literal. Without [now] it stays the bare letter. Other PHP letters with no
/// clean intl analogue (`N`, `w`, `t`, `L`, `o`, `U`, `W`, `z`, `c`, `r`) are
/// intentionally left literal — this powers a read-only preview, not exact PHP.
String phpDateFormatToIntl(String php, {DateTime? now}) {
  const map = <String, String>{
    'Y': 'yyyy',
    'y': 'yy',
    'm': 'MM',
    'n': 'M',
    'M': 'MMM',
    'F': 'MMMM',
    'd': 'dd',
    'j': 'd',
    'D': 'EEE',
    'l': 'EEEE',
    'H': 'HH',
    'G': 'H',
    'h': 'hh',
    'g': 'h',
    'i': 'mm',
    's': 'ss',
    'A': 'a',
    'a': 'a',
  };
  final out = StringBuffer();
  final literal = StringBuffer();
  void flush() {
    if (literal.isEmpty) return;
    // intl escapes a literal single quote as two single quotes.
    out.write("'${literal.toString().replaceAll("'", "''")}'");
    literal.clear();
  }

  for (var i = 0; i < php.length; i++) {
    final ch = php[i];
    if (ch == '\\') {
      if (i + 1 < php.length) {
        literal.write(php[i + 1]);
        i++;
      }
      continue;
    }
    if (ch == 'S' && now != null) {
      // `S` (ordinal suffix) has no intl token — append the computed suffix to
      // the `literal` buffer so flush() folds it into one quoted run with any
      // neighboring literals. Emitting it as its own `'rd'` adjacent to another
      // quoted literal (`'rd''X'`) would read as an escaped apostrophe in ICU.
      literal.write(_ordinalSuffix(now.day));
      continue;
    }
    final mapped = map[ch];
    if (mapped != null) {
      flush();
      out.write(mapped);
    } else {
      literal.write(ch);
    }
  }
  flush();
  return out.toString();
}
