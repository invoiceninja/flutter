import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/payment.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/payments/widgets/edit/payment_allocations_section.dart';
import 'package:admin/utils/formatting.dart';

/// Narrow-mode tappable card representing a single paymentable. Mirrors the
/// shape of `line_item_card_list_mobile.dart`'s `_ItemCard` — identity on
/// the left, amount on the right, trailing remove icon. Tap opens the
/// edit dialog.
class PaymentAllocationCard extends StatelessWidget {
  const PaymentAllocationCard({
    super.key,
    required this.kind,
    required this.row,
    required this.targets,
    required this.onTap,
    required this.onRemove,
    this.formatter,
    this.currencyId,
  });

  final AllocationKind kind;
  final Paymentable row;

  /// Used to resolve `row.invoiceId` / `row.creditId` → display number.
  /// Falls back to the raw id when not found.
  final List<AllocationTarget> targets;

  final VoidCallback onTap;
  final VoidCallback onRemove;

  /// Optional active-company [Formatter] for the amount + balance text.
  /// Null falls back to raw `Decimal.toString()`.
  final Formatter? formatter;

  /// Payment currency — see `PaymentAllocationsSection.currencyId`.
  final String? currencyId;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final id = kind == AllocationKind.invoice ? row.invoiceId : row.creditId;
    AllocationTarget? target;
    for (final t in targets) {
      if (t.id == id) {
        target = t;
        break;
      }
    }
    final label = target == null || target.number.isEmpty
        ? context.tr('pending')
        : '#${target.number}';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: tokens.border),
        borderRadius: BorderRadius.circular(InRadii.r2),
        color: tokens.surface,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(InRadii.r2),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: InSpacing.md(context),
            vertical: 10,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.ink,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (target != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${context.tr('balance')} ${formatter == null ? target.balance.toString() : formatter!.money(target.balance, clientCurrencyId: currencyId)}',
                        style: TextStyle(color: tokens.ink3, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatter == null
                    ? row.amount.toString()
                    : formatter!.money(
                        row.amount,
                        clientCurrencyId: currencyId,
                      ),
                style: moneyTextStyle(
                  color: tokens.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.clear, size: 20),
                color: tokens.ink3,
                onPressed: onRemove,
                tooltip: context.tr('remove'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
