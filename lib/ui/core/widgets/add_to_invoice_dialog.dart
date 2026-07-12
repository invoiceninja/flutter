import 'package:flutter/material.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';
import 'package:admin/utils/formatting.dart';

/// Pick an existing editable invoice for the active [clientId] so a task /
/// expense line item can be appended to it. Returns the chosen [Invoice]
/// (the caller appends the line item and routes to its edit screen, where
/// the normal outbox update applies) or null on cancel.
///
/// Mirrors `showMergeClientDialog` — a `SearchableDropdownField` inside an
/// `AlertDialog`, backed by a Drift watch stream. Offline-first: the list
/// is whatever the client's invoices the local cache holds (the client's
/// Invoices tab / list browsing populates it); no direct network read.
Future<Invoice?> showAddToInvoiceDialog(
  BuildContext context, {
  required Services services,
  required String companyId,
  required String clientId,
  required Formatter formatter,
}) {
  return showDialog<Invoice?>(
    context: context,
    builder: (ctx) {
      Invoice? selected;
      return StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(ctx.tr('add_to_invoice')),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: StreamBuilder<List<Invoice>>(
              stream: services.invoices.watchForClient(
                companyId: companyId,
                clientId: clientId,
              ),
              builder: (context, snapshot) {
                final invoices =
                    (snapshot.data ?? const <Invoice>[])
                        .where((i) => !i.isDeleted && i.archivedAt == null)
                        .toList()
                      ..sort((a, b) => b.number.compareTo(a.number));
                return SearchableDropdownField<Invoice>(
                  label: ctx.tr('invoice'),
                  items: invoices,
                  initialValue: selected,
                  emptyHintKey: 'no_records_found',
                  displayString: (i) {
                    final number = i.number.isEmpty
                        ? ctx.tr('pending')
                        : i.number;
                    return '$number  ·  ${formatter.money(i.balanceOrAmount)}';
                  },
                  idOf: (i) => i.id,
                  onChanged: (i) => setState(() => selected = i),
                );
              },
            ),
          ),
          actions: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(ctx.tr('cancel')),
            ),
            PrimaryDialogAction(
              label: ctx.tr('add_to_invoice'),
              enabled: selected != null,
              // Dropdown picker: Enter selects an option (SearchableDropdownField
              // never fires the primary), so no Enter hint.
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
