import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/domain/clients/client_past_due.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/standing_card.dart';

/// The line under a client's balance that says how much of it is late.
///
/// Three states, and the difference between the last two is the point:
///
///  * **late** — the amount and the number of invoices, in the overdue ink,
///    and a link to exactly those invoices;
///  * **nothing late** — a zero in neutral ink. Worth a line: under a balance
///    it is the answer to the question the balance raises;
///  * **not known** — the host passes nothing and no line is drawn. A dash or
///    a zero here would be a claim.
///
/// Label–value pairs rather than a sentence ("3 invoices past due"): the
/// bundles have no plural forms, and `overdue` cannot be used at all — the
/// French translation of that key reads "unpaid".
class ClientPastDueLine extends StatelessWidget {
  const ClientPastDueLine({
    super.key,
    required this.pastDue,
    required this.amount,
    this.onTap,
  });

  final ClientPastDue pastDue;

  /// [pastDue]'s amount, already formatted in the client's currency.
  final String amount;

  /// Opens the invoices this line counted. Ignored when nothing is late.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.inTheme;
    final late = pastDue.amount > Decimal.zero;
    final color = late ? tokens.overdue : tokens.ink2;
    final text = late
        ? '${context.tr('past_due')}: $amount'
              ' · ${context.tr('invoices')}: ${pastDue.count}'
        : '${context.tr('past_due')}: $amount';
    final onTap = late ? this.onTap : null;
    final line = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (late) ...[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: tokens.overdue,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: InSpacing.sm),
        ],
        Flexible(
          // Scales down like the figures above it: an amount with its tail
          // cut off is a different amount.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              text,
              maxLines: 1,
              softWrap: false,
              style: theme.textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: late ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
        if (onTap != null) ...[
          const SizedBox(width: 2),
          Icon(Icons.chevron_right, size: 14, color: color),
        ],
      ],
    );
    // The gap above is this line's own — see `StandingCard.footnote`.
    return Padding(
      padding: const EdgeInsets.only(top: kStandingFootnoteGap),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: onTap == null
            ? line
            : Semantics(
                button: true,
                label: text,
                hint: context.tr('past_due_invoices'),
                onTap: onTap,
                excludeSemantics: true,
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(InRadii.r1),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: Env.isTouchPrimary
                            ? InSizes.touchTarget
                            : 28,
                      ),
                      child: line,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
