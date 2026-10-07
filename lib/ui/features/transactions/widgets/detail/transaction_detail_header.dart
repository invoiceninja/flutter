import 'package:flutter/material.dart';

import 'package:admin/data/models/domain/bank_transaction.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/entity_detail_header.dart';
import 'package:admin/ui/core/detail/entity_detail_header_host.dart';
import 'package:admin/ui/core/widgets/entity_tags_view.dart';
import 'package:admin/utils/formatting.dart';

/// What a transaction is called on its record: the bank's description, then
/// the counterparty, then the app's "(no name)". One cascade, shared by the
/// header and the compact title so the two cannot disagree.
String transactionDisplayName(BuildContext context, BankTransaction tx) {
  final description = tx.description.trim();
  if (description.isNotEmpty) return description;
  final participant = tx.participantName.trim();
  if (participant.isNotEmpty) return participant;
  return context.tr('no_name_fallback');
}

/// Per-entity wrapper over [EntityDetailHeaderHost] for a bank transaction:
/// the description as its name, and under it the account it moved through and
/// when.
///
/// **The bank account is a link, and it opens the account — never an edit
/// screen.** The host builds it ([bankAccount]) rather than this widget:
/// `test/lint/no_list_tile_name_link_test.dart` keeps every linked name label
/// in a short list of record screens, so that one cannot be added to a list
/// row by accident.
///
/// A description can be a whole line of bank shorthand, so the name may take
/// two lines; the Details card below carries it in full, copyable.
class TransactionDetailHeader extends StatelessWidget {
  const TransactionDetailHeader({
    super.key,
    required this.transaction,
    this.formatter,
    this.bankAccount,
    this.showStatePills = true,
  });

  final BankTransaction transaction;
  final Formatter? formatter;

  /// The account the transaction moved through, as the first subtitle
  /// segment — a link to it. Null leaves the segment out.
  final Widget? bankAccount;

  /// False when the screen is already saying Deleted / Archived in a banner.
  final bool showStatePills;

  @override
  Widget build(BuildContext context) {
    return EntityDetailHeaderHost<BankTransaction>(
      entity: transaction,
      entityType: EntityType.transaction,
      recordId: transaction.id,
      formatter: formatter,
      project: (context, tx) {
        final date = tx.date;
        final f = formatter;
        final segments = [
          ?bankAccount,
          // Not until the formatter is here: a raw ISO date in the most
          // prominent line on the screen is worse than one a frame later.
          if (date != null && f != null) Text(f.date(date.toIso())),
        ];
        return EntityHeaderFields(
          seedForAvatar: tx.id,
          displayName: transactionDisplayName(context, tx),
          createdAt: tx.createdAt,
          updatedAt: tx.updatedAt,
          isDeleted: tx.isDeleted,
          isArchived: tx.archivedAt != null,
          isDirty: tx.isDirty,
          nameMaxLines: 2,
          showStatePills: showStatePills,
          subtitle: segments.isEmpty
              ? DetailHeaderTimestamps(
                  createdAt: tx.createdAt,
                  updatedAt: tx.updatedAt,
                  formatter: formatter,
                )
              : DetailSubtitle(segments: segments),
          tags: tx.tagIds.isEmpty
              ? null
              : Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: EntityTagsView(
                    entityType: 'bank_transaction',
                    tagIds: tx.tagIds,
                  ),
                ),
        );
      },
    );
  }
}
