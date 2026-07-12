import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'package:admin/data/models/domain/document.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/data/models/domain/invoice_status.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/features/settings/views/advanced/e_invoice/e_invoice_constants.dart';

/// Invoice "rectify" (Verifactu *factura rectificativa*). Mirrors React's
/// `useRectifyInvoiceModal` / `useCloneToNegativeInvoice` — a purely
/// client-side clone-into-negative-corrective-invoice. No endpoint: the
/// negated draft is handed to the standard create editor and saved as a
/// normal new invoice (carrying `modified_invoice_id` + `reason`).

/// React's gate (`Actions.tsx`): the action is **hidden** unless every one of
/// these holds. `clientCountryId` is the resolved invoice client's
/// `country_id`; `eInvoiceType` is the active company's
/// `settings.e_invoice_type`. Both are passed in (the caller resolves them).
bool isRectifyEligible({
  required Invoice invoice,
  required String? clientCountryId,
  required String? eInvoiceType,
}) {
  return rectifyPreGate(invoice) &&
      clientCountryId == kEInvoiceCountryIdSpain &&
      eInvoiceType == kEInvoiceTypeVERIFACTU;
}

/// Invoice-only subset of [isRectifyEligible]. Lets a caller skip resolving
/// the async client-country / company-e_invoice_type inputs when the cheap
/// gate already fails (the common case — most invoices aren't Verifactu).
bool rectifyPreGate(Invoice invoice) =>
    invoice.statusId == InvoiceStatus.sent &&
    invoice.backup?['document_type'] == 'F1' &&
    _gtZero(invoice.backup?['adjustable_amount']) &&
    invoice.amount > Decimal.zero &&
    !invoice.isDeleted;

/// `backup.adjustable_amount` arrives as a typed-deferred dynamic (num /
/// string depending on the server build). Treat anything that parses to a
/// positive number as "> 0".
bool _gtZero(Object? raw) {
  if (raw == null) return false;
  final n = raw is num ? raw : num.tryParse(raw.toString());
  return n != null && n > 0;
}

/// Build the negative corrective draft. Mirrors React's object literal:
/// clear identity/dates, `date`→today, zero the paid/partial state, negate
/// amount/balance and every line-item quantity, set `modified_invoice_id` +
/// `reason`. The edit VM recomputes totals from the (now negative) line
/// items; amount/balance are also set negative for React parity so the
/// initial render + payload are correct regardless of recompute timing.
Invoice rectifiedDraft(Invoice invoice, String reason) {
  final epoch0 = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  return invoice.copyWith(
    id: '',
    number: '',
    date: Date.today(),
    dueDate: null,
    partialDueDate: null,
    statusId: InvoiceStatus.draft,
    partial: Decimal.zero,
    paidToDate: Decimal.zero,
    exchangeRate: Decimal.one,
    amount: -invoice.amount.abs(),
    balance: -invoice.balance.abs(),
    projectId: '',
    vendorId: '',
    subscriptionId: '',
    archivedAt: null,
    isDeleted: false,
    isDirty: false,
    documents: const <Document>[],
    updatedAt: epoch0,
    createdAt: epoch0,
    lineItems: [
      for (final li in invoice.lineItems)
        li.copyWith(quantity: -li.quantity.abs()),
    ],
    modifiedInvoiceId: invoice.id,
    reason: reason,
  );
}

/// Required-reason prompt. Returns the trimmed reason, or null if the user
/// cancelled. Confirm stays disabled until the field is non-empty (React
/// requires the rectification reason).
Future<String?> showRectifyReasonDialog(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          final canConfirm = controller.text.trim().isNotEmpty;
          return AlertDialog(
            title: Text(ctx.tr('rectify')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ctx.tr('rectify_invoice_help')),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  maxLines: 2,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: ctx.tr('reason'),
                    hintText: ctx.tr('enter_reason'),
                  ),
                ),
              ],
            ),
            actions: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(64, 40),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(ctx.tr('cancel')),
                  ),
                  const SizedBox(width: 8),
                  PrimaryDialogAction(
                    label: ctx.tr('rectify'),
                    onPressed: () =>
                        Navigator.of(ctx).pop(controller.text.trim()),
                    enabled: canConfirm,
                    autofocus: false,
                    showEnterHint: false,
                  ),
                ],
              ),
            ],
          );
        },
      );
    },
  );
}
