import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/bank_transaction.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/widgets/bank_account_name_label.dart';
import 'package:admin/ui/core/widgets/detail_info_row.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/ui/features/transactions/widgets/transaction_matched_entities.dart';
import 'package:admin/utils/formatting.dart';

/// Everything under a transaction's standing: its reference fields, what it
/// is linked to, and — while it still needs accounting for — the panel that
/// does it.
///
/// * **≥ [Breakpoints.entityFormMultiColumn]**: two columns, split 11 : 9
///   with the record column's own gap so the gutter lines up with the one
///   between the header and the standing card above. Details on the left; on
///   the right, the linked records and the match panel. With no panel (a
///   converted transaction) the two cards are a level row that ends on one
///   line; with one, the row is top-aligned, because the panel is a form that
///   grows as the user picks things and cannot be given an intrinsic height
///   (its tab strip holds a `LayoutBuilder`).
/// * **below**: one stack, and **the work comes first** — linked, panel,
///   then Details. Reconciling a statement is stepping down a list in the
///   pane and matching each row; with the panel under a nine-row Details card
///   every step began with a scroll. The record column above this has already
///   centred and capped it.
///
/// **Every entry is gated on having content**, so a card that would draw
/// nothing is not given a gap or a column.
class TransactionDetailProfile extends StatelessWidget {
  const TransactionDetailProfile({
    super.key,
    required this.transaction,
    this.formatter,
    this.work,
  });

  final BankTransaction transaction;
  final Formatter? formatter;

  /// The match panel, when the transaction can still be matched. Null for a
  /// converted or deleted one.
  final Widget? work;

  @override
  Widget build(BuildContext context) {
    final tx = transaction;
    final rows = TransactionDetailsCard.rowsFor(
      context,
      tx,
      formatter: formatter,
    );
    final gap = SizedBox(height: InSpacing.md(context));
    final hasLinked = tx.isMatched || tx.isConverted;
    final work = this.work;

    Widget details() => DashboardCardShell(
      title: context.tr('details'),
      child: DetailRowStack(children: rows),
    );
    Widget linked() => DashboardCardShell(
      title: context.tr(tx.isConverted ? 'converted' : 'matched'),
      child: TransactionMatchedEntities(transaction: tx),
    );
    // A card around the panel, so its tab strip and form sit on the same
    // surface as the cards beside them instead of floating on the page.
    Widget workCard(Widget panel) {
      final tokens = context.inTheme;
      return Container(
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(InRadii.r3),
          border: Border.all(color: tokens.border),
          boxShadow: tokens.shadow1,
        ),
        clipBehavior: Clip.antiAlias,
        // The panel's rows (`ListTile`s, the tab buttons) paint their ink on
        // the nearest `Material`; without one of their own under this
        // coloured box Flutter asserts, because the box would hide it.
        child: Material(type: MaterialType.transparency, child: panel),
      );
    }

    final side = <Widget>[
      if (hasLinked) linked(),
      if (work != null) workCard(work),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= Breakpoints.entityFormMultiColumn;
        if (!wide || rows.isEmpty || side.isEmpty) {
          final stack = <Widget>[...side, if (rows.isNotEmpty) details()];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < stack.length; i++) ...[
                if (i > 0) gap,
                stack[i],
              ],
            ],
          );
        }
        final row = Row(
          crossAxisAlignment: work == null
              ? CrossAxisAlignment.stretch
              : CrossAxisAlignment.start,
          children: [
            Expanded(flex: _kLeadFlex, child: details()),
            SizedBox(width: InSpacing.lg(context)),
            Expanded(
              flex: _kSideFlex,
              child: work == null
                  // One card, stretched to the row.
                  ? side.single
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < side.length; i++) ...[
                          if (i > 0) gap,
                          side[i],
                        ],
                      ],
                    ),
            ),
          ],
        );
        // `IntrinsicHeight` so the two cards end on one line. Legal only
        // without the panel — neither card holds a `LayoutBuilder`.
        return work == null ? IntrinsicHeight(child: row) : row;
      },
    );
  }
}

/// `EntityRecordColumn`'s own split of its wide band (identity : standing),
/// repeated here so the two rows share a gutter.
const int _kLeadFlex = 11;
const int _kSideFlex = 9;

/// A description longer than this cannot be shown whole in the header's two
/// lines at the pane's width, so Details repeats it in full.
const int _kHeaderDescriptionChars = 48;

/// The rows of a transaction's Details card, in display order. Blank fields
/// are left out.
abstract final class TransactionDetailsCard {
  static List<Widget> rowsFor(
    BuildContext context,
    BankTransaction tx, {
    Formatter? formatter,
  }) {
    final f = formatter;
    final date = tx.date;
    // The local calendar day: these are UTC-backed server timestamps, and the
    // ISO date of the UTC instant is the wrong day across the boundary.
    String? day(DateTime dt) => f == null || dt.millisecondsSinceEpoch == 0
        ? null
        : f.date(dt.toLocal().toIso8601String().split('T').first);
    final created = day(tx.createdAt);
    final updated = day(tx.updatedAt);
    final valueStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: context.inTheme.ink,
      fontSize: 12.5,
      fontWeight: FontWeight.w500,
    );
    return [
      // In full and copyable, when the header may have cut it: a bank
      // description is what a user pastes into a search. A short one is
      // already the screen's title, and the same words twice within a
      // hundred pixels is noise.
      if (tx.description.trim().length > _kHeaderDescriptionChars)
        DetailInfoRow(
          label: context.tr('description'),
          value: tx.description.trim(),
        ),
      if (date != null && f != null)
        DetailInfoRow(
          label: context.tr('date'),
          value: f.date(date.toIso()),
          copyable: false,
        ),
      if (tx.bankAccountId.isNotEmpty)
        DetailInfoRow(
          label: context.tr('bank_account'),
          value: '',
          copyable: false,
          // Plain: the link to the account is the header's, one line up.
          child: BankAccountNameLabel(
            bankAccountId: tx.bankAccountId,
            style: valueStyle,
          ),
        ),
      if (tx.participantName.trim().isNotEmpty)
        DetailInfoRow(
          label: context.tr('participant_name'),
          value: tx.participantName.trim(),
        ),
      if (tx.participant.trim().isNotEmpty)
        DetailInfoRow(
          label: context.tr('participant'),
          value: tx.participant.trim(),
        ),
      // The bank's own bucket for it ("Transfer", "Restaurants") — not the
      // expense category it was matched to, which is on the linked card.
      if (tx.category.trim().isNotEmpty)
        DetailInfoRow(
          label: context.tr('category'),
          value: tx.category.trim(),
          copyable: false,
        ),
      if (tx.transactionId.isNotEmpty)
        DetailInfoRow(
          label: context.tr('transaction_id'),
          value: tx.transactionId,
        ),
      if (created != null)
        DetailInfoRow(
          label: context.tr('created_at'),
          value: created,
          copyable: false,
        ),
      if (updated != null)
        DetailInfoRow(
          label: context.tr('updated_at'),
          value: updated,
          copyable: false,
        ),
    ];
  }
}
