import 'package:flutter/material.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/vendor.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';

/// Pick the **survivor** vendor to merge [source] into. Returns the chosen
/// vendor (kept; [source] is absorbed + deleted server-side) or null on
/// cancel. The destructive POST + the password (412) prompt happen after this
/// via the outbox gate. Mirror of `showMergeClientDialog`.
Future<Vendor?> showMergeVendorDialog(
  BuildContext context, {
  required Services services,
  required String companyId,
  required Vendor source,
}) {
  return showDialog<Vendor?>(
    context: context,
    builder: (ctx) {
      Vendor? selected;
      return StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(ctx.tr('merge')),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ctx.tr('merge_vendor_warning', {'from': source.name})),
                const SizedBox(height: 16),
                StreamBuilder<List<Vendor>>(
                  stream: services.vendors.watchPage(
                    companyId: companyId,
                    loadedPages: 100,
                  ),
                  builder: (context, snapshot) {
                    final vendors = (snapshot.data ?? const <Vendor>[])
                        .where(
                          (v) =>
                              v.id != source.id &&
                              v.archivedAt == null &&
                              !v.isDeleted,
                        )
                        .toList();
                    return SearchableDropdownField<Vendor>(
                      label: ctx.tr('merge_into'),
                      items: vendors,
                      initialValue: selected,
                      displayString: (v) => v.name,
                      idOf: (v) => v.id,
                      onChanged: (v) => setState(() => selected = v),
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(ctx.tr('cancel')),
            ),
            PrimaryDialogAction(
              label: ctx.tr('merge'),
              onPressed: () => Navigator.of(ctx).pop(selected),
              enabled: selected != null,
              // Disabled until a vendor is picked (autofocus can't land on a
              // disabled button) + dropdown eats Enter — so no Enter hint.
              autofocus: false,
              showEnterHint: false,
            ),
          ],
        ),
      );
    },
  );
}
