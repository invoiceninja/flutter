import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/bank_account.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/widgets/detail_info_row.dart';
import 'package:admin/ui/core/widgets/detail_row_columns.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/utils/formatting.dart';

/// A bank account's reference fields, with the one setting worth changing
/// from here: Auto Sync.
///
/// **Auto Sync is a switch, on the record.** It is by far the most-flipped
/// field on a bank account, and a trip through the edit form for one boolean
/// is the reason this screen had a quick-edit row at all. It flips the single
/// field and saves through the outbox like any other edit; while that save is
/// still queued a small spinner beside the label says so.
///
/// [onAutoSyncChanged] null draws the switch inert — a deleted account is
/// read-only, and so is one this user may not edit.
class BankAccountDetailProfile extends StatelessWidget {
  const BankAccountDetailProfile({
    super.key,
    required this.account,
    required this.onAutoSyncChanged,
    this.formatter,
  });

  final BankAccount account;
  final ValueChanged<bool>? onAutoSyncChanged;

  /// For the dates. Null (still loading) leaves them out.
  final Formatter? formatter;

  /// The rows above the switch, in display order. Blank fields are left out.
  static List<Widget> rowsFor(
    BuildContext context,
    BankAccount account, {
    Formatter? formatter,
  }) {
    final f = formatter;
    // The local calendar day: these are UTC-backed server timestamps, and the
    // ISO date of the UTC instant is the wrong day across the boundary.
    String? day(DateTime dt) => f == null || dt.millisecondsSinceEpoch == 0
        ? null
        : f.date(dt.toLocal().toIso8601String().split('T').first);
    final from = account.fromDate;
    final created = day(account.createdAt);
    final updated = day(account.updatedAt);
    return [
      if (account.provider.trim().isNotEmpty)
        DetailInfoRow(
          label: context.tr('provider'),
          value: account.provider.trim(),
          copyable: false,
        ),
      if (account.type.trim().isNotEmpty)
        DetailInfoRow(
          label: context.tr('account_type'),
          value: account.type.trim(),
          copyable: false,
        ),
      DetailInfoRow(
        label: context.tr('integration_type'),
        value: context.tr(labelKeyForProvider(account.integrationType)),
        copyable: false,
      ),
      if (account.status.trim().isNotEmpty)
        DetailInfoRow(
          label: context.tr('status'),
          value: account.status.trim(),
          copyable: false,
        ),
      if (account.currency.trim().isNotEmpty)
        DetailInfoRow(
          label: context.tr('currency'),
          value: account.currency.trim().toUpperCase(),
          copyable: false,
        ),
      if (from != null && f != null)
        DetailInfoRow(
          label: context.tr('sync_from'),
          value: f.date(from.toIso()),
          copyable: false,
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

  @override
  Widget build(BuildContext context) {
    final rows = rowsFor(context, account, formatter: formatter);
    // Details is the only card an account has, so on a wide window its rows
    // run in two columns rather than leaving most of a full-width card blank.
    // The switch keeps the full width under them.
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= Breakpoints.entityFormMultiColumn;
        return DashboardCardShell(
          title: context.tr('details'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              DetailRowColumns(columns: wide ? 2 : 1, children: rows),
              if (rows.isNotEmpty) const DetailRowDivider(),
              _AutoSyncRow(account: account, onChanged: onAutoSyncChanged),
            ],
          ),
        );
      },
    );
  }
}

class _AutoSyncRow extends StatelessWidget {
  const _AutoSyncRow({required this.account, required this.onChanged});

  final BankAccount account;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.inTheme;
    final label = context.tr('auto_sync');
    return Padding(
      padding: const EdgeInsets.only(top: InSpacing.xs),
      child: MergeSemantics(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: tokens.ink,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      // An outbox row is pending — the change is queued, not
                      // yet on the server.
                      if (account.isDirty) ...[
                        const SizedBox(width: InSpacing.sm),
                        SizedBox.square(
                          dimension: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: tokens.ink3,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.tr('auto_sync_help'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: tokens.ink2,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: InSpacing.sm),
            Switch(value: account.autoSync, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}
