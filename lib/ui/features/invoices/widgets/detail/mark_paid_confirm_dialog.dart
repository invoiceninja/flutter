import 'package:flutter/material.dart';

import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';

/// Confirmation dialog for the "Mark paid" action. Issues a simple
/// `PUT /api/v1/invoices/{id}?paid=true` (handled by the dispatcher's
/// `markPaid` customActions handler), which causes the server to record a
/// synthetic payment for the full outstanding balance and flip the invoice
/// status to Paid.
///
/// Future iterations (per the plan file's UX improvement #1) replace this
/// confirm with a richer dialog that lets the user enter amount / date /
/// payment type / reference — gated on the Payments module landing.
Future<bool> showMarkPaidConfirmDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: Text(ctx.tr('mark_paid')),
        content: Text(ctx.tr('mark_paid_confirm')),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(64, 40),
                ),
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(ctx.tr('cancel')),
              ),
              const SizedBox(width: 8),
              PrimaryDialogAction(
                label: ctx.tr('mark_paid'),
                onPressed: () => Navigator.of(ctx).pop(true),
              ),
            ],
          ),
        ],
      );
    },
  );
  return result ?? false;
}
