import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/billing_shared/line_item_editor/line_item_column_config.dart';
import 'package:admin/ui/features/billing_shared/line_item_editor/line_item_edit_dialog.dart';
import 'package:admin/ui/features/billing_shared/line_item_editor/line_item_text_dialog.dart';

/// Edit the existing line at [index] of [items] in a dialog, handing the
/// changed list to [onChanged] — nothing on Cancel.
///
/// The one flow behind a tap on a phone's line card and a tap on a line in
/// the record screen's Overview (`OpenLineItemRequest`), so the two cannot
/// open different editors for the same line.
///
/// A text line opens the text editor, whose `More Fields` hands over to the
/// full one — committing the text first, so a Cancel there keeps it.
Future<void> editLineItemAt(
  BuildContext context, {
  required String companyId,
  required List<LineItem> items,
  required int index,
  required LineItemColumnConfig config,
  required ValueChanged<List<LineItem>> onChanged,
}) async {
  if (index < 0 || index >= items.length) return;
  var initial = items[index];
  var current = items;
  if (initial.isTextOnly) {
    final text = await showLineItemTextDialog(
      context,
      initial: initial,
      label: context.tr(config.labelKey('description')),
      offerMoreFields: true,
    );
    if (text == null || !context.mounted) return;
    current = List<LineItem>.from(items)..[index] = text.item;
    onChanged(current);
    if (!text.moreFields) return;
    initial = text.item;
  }
  final fmt = context.read<Services>().formatterIfReady(companyId);
  final useComma = fmt?.settings.useCommaAsDecimalPlace ?? false;
  final result = await showLineItemEditDialog(
    context,
    initial: initial,
    config: config,
    useComma: useComma,
    formatter: fmt,
  );
  if (result == null) return;
  // The dialog is a route, so the host can go away under it — a company
  // switch, or the record closing. `onChanged` writes into the edit VM,
  // which asserts once disposed.
  if (!context.mounted) return;
  onChanged(List<LineItem>.from(current)..[index] = result);
}
