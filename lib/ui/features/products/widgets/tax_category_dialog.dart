import 'package:flutter/material.dart';

import 'package:admin/domain/product_tax_categories.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';

/// Pick a product tax category. Short fixed enum → a simple radio list
/// (no search). Returns the chosen id, or null on cancel. [current] is the
/// product's existing `taxId` (defaults the selection).
Future<String?> showTaxCategoryDialog(
  BuildContext context, {
  required String current,
}) {
  return showDialog<String?>(
    context: context,
    builder: (ctx) {
      var selected = current.isEmpty ? '1' : current;
      return StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(ctx.tr('set_tax_category')),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Plain selectable list rather than RadioGroup — matches
                  // `entity_sort_filter_sheet.dart`; RadioGroup mutates the
                  // subtree mid-frame and crashes inside dialog/sheet layout.
                  for (final entry in kProductTaxCategories.entries)
                    ListTile(
                      title: Text(ctx.tr(entry.value)),
                      contentPadding: EdgeInsets.zero,
                      selected: selected == entry.key,
                      trailing: selected == entry.key
                          ? const Icon(Icons.check)
                          : null,
                      onTap: () => setState(() => selected = entry.key),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(ctx.tr('cancel')),
            ),
            PrimaryDialogAction(
              label: ctx.tr('save'),
              onPressed: () => Navigator.of(ctx).pop(selected),
            ),
          ],
        ),
      );
    },
  );
}
