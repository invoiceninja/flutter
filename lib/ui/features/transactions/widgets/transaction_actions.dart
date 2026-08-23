import 'package:flutter/material.dart';

import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/bank_transaction.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/detail/standard_entity_action_items.dart';
import 'package:admin/ui/core/detail/standard_entity_actions.dart';
import 'package:admin/ui/core/list/master_detail_layout.dart'
    show MasterDetailNavScope;
import 'package:admin/ui/core/sync/require_synced.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';

/// Row + detail-screen actions for a bank transaction. Edit + the standard
/// archive/restore/delete trio plus two transaction-specific actions:
/// `convert` (matched → converted server-side) and `unlink` (matched or
/// converted → unmatched, detaches from linked entities).
enum TransactionAction { edit, convert, unlink, archive, restore, delete }

class TransactionActions {
  TransactionActions._();

  /// Actions the old admin-portal hid on a brand-new (unsaved) record.
  /// Fed to `filterForEditScreen` so the create screen drops archive /
  /// restore / delete.
  static bool isLifecycle(TransactionAction action) {
    switch (action) {
      case TransactionAction.archive:
      case TransactionAction.restore:
      case TransactionAction.delete:
        return true;
      default:
        return false;
    }
  }

  /// Display label for the "Are you sure?" prompt, so a confirm fired
  /// from a long list says which record it's about. Blank is fine — the
  /// dialog just omits the line.
  static String _confirmSubject(BankTransaction transaction) =>
      transaction.description;

  static List<EntityActionItem<TransactionAction>> itemsFor(
    BuildContext context,
    BankTransaction transaction,
    void Function(TransactionAction) onTap,
  ) {
    final canArchive = transaction.archivedAt == null && !transaction.isDeleted;
    final canRestore = transaction.archivedAt != null || transaction.isDeleted;
    final canConvert = transaction.isMatched;
    final canUnlink = transaction.isMatched || transaction.isConverted;

    return [
      editActionItem(
        context: context,
        kind: TransactionAction.edit,
        onTap: () => onTap(TransactionAction.edit),
      ),
      if (canConvert)
        EntityActionItem(
          kind: TransactionAction.convert,
          icon: Icons.auto_fix_high_outlined,
          label: context.tr('convert'),
          enabled: true,
          onTap: () => onTap(TransactionAction.convert),
        ),
      if (canUnlink)
        EntityActionItem(
          kind: TransactionAction.unlink,
          confirm: true,
          confirmSubject: _confirmSubject(transaction),
          icon: Icons.link_off,
          label: context.tr('unlink'),
          enabled: true,
          onTap: () => onTap(TransactionAction.unlink),
        ),
      ?archiveActionItem(
        context: context,
        subject: _confirmSubject(transaction),
        kind: TransactionAction.archive,
        canArchive: canArchive,
        onTap: () => onTap(TransactionAction.archive),
      ),
      ?restoreActionItem(
        context: context,
        kind: TransactionAction.restore,
        canRestore: canRestore,
        onTap: () => onTap(TransactionAction.restore),
      ),
      ?deleteActionItem(
        context: context,
        subject: _confirmSubject(transaction),
        kind: TransactionAction.delete,
        canDelete: !transaction.isDeleted,
        onTap: () => onTap(TransactionAction.delete),
      ),
    ];
  }

  /// Dispatch the picked action. Convert and Unlink enqueue a bulk mutation
  /// whose custom-action dispatcher applies every returned row via
  /// `applyUpdateResponse`, so the local `status_id` updates reactively —
  /// no manual `refreshAll` (which raced the drain and could revert status).
  static Future<void> dispatch(
    BuildContext context,
    Services services,
    String companyId,
    BankTransaction transaction,
    TransactionAction action,
  ) async {
    switch (action) {
      case TransactionAction.edit:
        goEntityEdit(context, '/transactions', transaction.id);
      case TransactionAction.convert:
        final ok = await _confirmConvert(context, count: 1);
        if (ok != true) return;
        // Capture the next-row id BEFORE the mutation so we walk the
        // pre-mutation ordering — converting a row removes it from the
        // Matched filter, which would otherwise shift indices under us.
        final nextId = context.mounted
            ? MasterDetailNavScope.maybeOf(context)?.nextId()
            : null;
        await services.bankTransactions.convertMatched(
          companyId: companyId,
          transactionIds: [transaction.id],
        );
        if (context.mounted) {
          Notify.success(context, context.tr('converted_transaction'));
          // Linear-style auto-advance: if we're inside a slide-over
          // pane and the user has more rows to work, jump to the next
          // one so batch-converting is a single-click loop. With no
          // pane (narrow viewport / direct nav) this is a no-op and
          // the user stays on the freshly-converted row.
          if (nextId != null) {
            goEntityRecord(context, EntityType.transaction, nextId);
          }
        }
      case TransactionAction.unlink:
        await services.bankTransactions.unlinkTransactions(
          companyId: companyId,
          transactionIds: [transaction.id],
        );
        if (context.mounted) {
          Notify.success(context, context.tr('unlinked_transaction'));
        }
      case TransactionAction.archive:
        await StandardEntityActions.archive(
          context: context,
          wireName: 'transaction',
          op: () => services.bankTransactions.archive(
            companyId: companyId,
            id: transaction.id,
          ),
          undoOp: () => services.bankTransactions.restore(
            companyId: companyId,
            id: transaction.id,
          ),
        );
      case TransactionAction.restore:
        await StandardEntityActions.restore(
          context: context,
          wireName: 'transaction',
          op: () => services.bankTransactions.restore(
            companyId: companyId,
            id: transaction.id,
          ),
        );
      case TransactionAction.delete:
        if (!requireSynced(context, transaction.id)) return;
        await StandardEntityActions.delete(
          context: context,
          wireName: 'transaction',
          op: () => services.bankTransactions.delete(
            companyId: companyId,
            id: transaction.id,
          ),
          undoOp: () => services.bankTransactions.restore(
            companyId: companyId,
            id: transaction.id,
          ),
        );
    }
  }

  /// Confirmation dialog for `convert`. Server-side cost is real (creates
  /// payments/expenses), so we always confirm — even for single-row.
  static Future<bool?> _confirmConvert(
    BuildContext context, {
    required int count,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('convert')),
        content: Text(
          count == 1
              ? ctx.tr('convert_transactions_confirm_singular')
              : ctx.tr('convert_transactions_confirm_plural', {
                  'count': count.toString(),
                }),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(64, 40)),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.tr('cancel')),
          ),
          const SizedBox(width: 8),
          PrimaryDialogAction(
            label: ctx.tr('convert'),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
  }
}
