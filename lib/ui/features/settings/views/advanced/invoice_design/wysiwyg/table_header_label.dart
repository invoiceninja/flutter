import 'package:flutter/widgets.dart';

import 'package:admin/l10n/localization.dart';

/// Header keys that have no localization entry of their own, mapped onto the
/// one the server prints for that column.
///
/// `net_cost` is in no locale file. `HtmlEngine::generateLabelsAndValues`
/// labels `$product.net_cost` with `ctrans('texts.unit_cost')` and React does
/// the same, so without the alias the designer shows a raw slug for a column
/// the PDF titles "Unit Cost".
const _kHeaderKeyAliases = <String, String>{'net_cost': 'unit_cost'};

/// A table column's `header` rendered for display.
///
/// The value is a hybrid: the shipped column definitions (`block_library.dart`,
/// `table_block_properties._kAvailableColumns`) store a localization key
/// (`unit_cost`, `qty`, `line_total`), but the property panel exposes the same
/// field as a free-text input, so a user can type a literal heading. Resolve
/// the key when the bundle knows it and pass anything else through
/// **verbatim** — title-casing an unknown value would mangle a user's text.
///
/// Both the WYSIWYG canvas and the property panel's column list call this so
/// they can't disagree: the canvas used to paint the raw key (`unit_cost` in
/// the header cell) while the panel beside it read "Unit Cost"
/// (invoiceninja/flutter#84).
String resolveTableHeaderLabel(BuildContext context, String? header) {
  final raw = header?.trim() ?? '';
  if (raw.isEmpty) return '';
  return context.trIfDefined(_kHeaderKeyAliases[raw] ?? raw) ?? raw;
}
