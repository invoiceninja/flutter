import 'package:flutter/material.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';

/// Pick the **survivor** client to merge [source] into. Returns the chosen
/// client (kept; [source] is absorbed + deleted server-side) or null on
/// cancel. The destructive POST + the password (412) prompt happen after
/// this, via the outbox gate — matching React's MergeClientModal /
/// admin-portal's `_MergClientPicker`.
Future<Client?> showMergeClientDialog(
  BuildContext context, {
  required Services services,
  required String companyId,
  required Client source,
}) {
  return showDialog<Client?>(
    context: context,
    builder: (ctx) {
      Client? selected;
      return StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(ctx.tr('merge')),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ctx.tr('merge_client_warning', {
                    'from': source.displayName.isEmpty
                        ? source.name
                        : source.displayName,
                  }),
                ),
                const SizedBox(height: 16),
                StreamBuilder<List<Client>>(
                  stream: services.clients.watchPage(
                    companyId: companyId,
                    loadedPages: 100,
                  ),
                  builder: (context, snapshot) {
                    final clients = (snapshot.data ?? const <Client>[])
                        .where(
                          (c) =>
                              c.id != source.id &&
                              c.archivedAt == null &&
                              !c.isDeleted,
                        )
                        .toList();
                    return SearchableDropdownField<Client>(
                      label: ctx.tr('merge_into'),
                      items: clients,
                      initialValue: selected,
                      displayString: (c) =>
                          c.displayName.isEmpty ? c.name : c.displayName,
                      idOf: (c) => c.id,
                      onChanged: (c) => setState(() => selected = c),
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
              enabled: selected != null,
              // Dropdown picker: Enter selects an option, it doesn't submit —
              // so no Enter hint.
              autofocus: false,
              showEnterHint: false,
              onPressed: () => Navigator.of(ctx).pop(selected),
            ),
          ],
        ),
      );
    },
  );
}
