import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/billing_shared/billing_doc_type.dart';

/// Bottom-sheet target picker for the clone-to-X actions. Returns the
/// chosen target [BillingDocType] (one of the four destination variants —
/// `invoice` if source is invoice/quote/credit/PO, `quote`/`credit`/PO
/// for cross-conversions, `recurringInvoice` to spawn a recurring
/// template).
///
/// The host (e.g. `InvoiceActions.dispatch`) maps the chosen target to
/// the corresponding `MutationKind.cloneTo*` and enqueues the action.
/// Null return means the user cancelled.
Future<BillingDocType?> showCloneOptionsSheet(
  BuildContext context, {
  required BillingDocType source,
}) {
  return showModalBottomSheet<BillingDocType>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _CloneOptionsSheet(source: source),
  );
}

class _CloneOptionsSheet extends StatelessWidget {
  const _CloneOptionsSheet({required this.source});

  /// The billing-doc type the user is currently viewing. Used to decide
  /// which clone targets to surface (e.g. you can't clone a credit *to*
  /// itself, etc. — though for M3 we surface every variant and let the
  /// server reject impossible conversions).
  final BillingDocType source;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    // Always surface all five targets — admin-portal does too. Server
    // rejects impossible conversions (e.g. recurring → recurring) with
    // 422; the outbox surfaces that as a dead row.
    final targets = const <_CloneTarget>[
      _CloneTarget(
        type: BillingDocType.invoice,
        labelKey: 'clone_to_invoice',
        icon: Icons.receipt_long_outlined,
      ),
      _CloneTarget(
        type: BillingDocType.quote,
        labelKey: 'clone_to_quote',
        icon: Icons.request_quote_outlined,
      ),
      _CloneTarget(
        type: BillingDocType.credit,
        labelKey: 'clone_to_credit',
        icon: Icons.assignment_return_outlined,
      ),
      _CloneTarget(
        type: BillingDocType.recurringInvoice,
        labelKey: 'clone_to_recurring',
        icon: Icons.event_repeat_outlined,
      ),
      _CloneTarget(
        type: BillingDocType.purchaseOrder,
        labelKey: 'clone_to_purchase_order',
        icon: Icons.shopping_bag_outlined,
      ),
    ];
    return Material(
      color: tokens.surface,
      borderRadius: BorderRadius.vertical(top: Radius.circular(InRadii.r3)),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                InSpacing.lg(context),
                InSpacing.md(context),
                InSpacing.md(context),
                0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.tr('clone'),
                      style: TextStyle(
                        color: tokens.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: tokens.border),
            for (final t in targets)
              ListTile(
                leading: Icon(t.icon, color: tokens.ink2),
                title: Text(context.tr(t.labelKey)),
                onTap: () => Navigator.of(context).pop(t.type),
              ),
            SizedBox(height: InSpacing.md(context)),
          ],
        ),
      ),
    );
  }
}

class _CloneTarget {
  const _CloneTarget({
    required this.type,
    required this.labelKey,
    required this.icon,
  });
  final BillingDocType type;
  final String labelKey;
  final IconData icon;
}
