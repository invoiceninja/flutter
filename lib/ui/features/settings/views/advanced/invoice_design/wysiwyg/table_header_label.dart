import 'package:flutter/widgets.dart';

import 'package:admin/data/models/domain/design_block_wire.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/variables/variable_replacer.dart';

/// A table column's `header` as the PDF will print it.
///
/// The server prints the value exactly as stored and translates only a
/// `$…_label` token, so that is what a column is seeded with. Designs saved
/// before that carried a bare localization key (`unit_cost`, `qty`), which the
/// canvas translated and the PDF printed as the key itself; `DesignBlock.toApi`
/// rewrites those on the next save, and this resolves them the same way so the
/// canvas shows the heading the saved design will have. Anything else is the
/// user's own text and is passed through **verbatim**.
///
/// Both the canvas and the property panel's column list call this so they
/// can't disagree (invoiceninja/flutter#84).
String resolveTableHeaderLabel(
  BuildContext context,
  String? header, {
  String blockType = 'table',
}) {
  final raw = header?.trim() ?? '';
  if (raw.isEmpty) return '';
  return replaceLabelVariables(
    upgradeLegacyColumnHeader(blockType, raw),
    context.tr,
  );
}

/// An info block's `title` as the PDF will print it — the same rule as
/// [resolveTableHeaderLabel].
String resolveBlockTitle(BuildContext context, String? title) {
  final raw = title?.trim() ?? '';
  if (raw.isEmpty) return '';
  return replaceLabelVariables(upgradeLegacyTitle(raw), context.tr);
}
