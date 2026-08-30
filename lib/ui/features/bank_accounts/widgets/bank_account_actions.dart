import 'package:flutter/material.dart';

import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/bank_account.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/core/detail/copy_entity_link.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/detail/standard_entity_action_items.dart';
import 'package:admin/ui/core/detail/standard_entity_actions.dart';
import 'package:admin/ui/core/sync/require_synced.dart';

/// Action set surfaced for a bank account. Mirrors the standard minimum
/// surface — edit / archive / restore / delete — since bank accounts (bank
/// integrations) carry no clone or cross-entity navigation. Mirrors
/// `ExpenseCategoryActions`.
enum BankAccountAction { edit, copyLink, archive, restore, delete }

/// Single source of truth for what BankAccount actions exist and what they
/// do. The detail header (`EntityDetailActionsRow<BankAccountAction>`)
/// consumes this.
class BankAccountActions {
  BankAccountActions._();

  /// Display label for the "Are you sure?" prompt, so a confirm fired
  /// from a long list says which record it's about. Blank is fine — the
  /// dialog just omits the line.
  static String _confirmSubject(BankAccount account) => account.name;

  static List<EntityActionItem<BankAccountAction>> itemsFor(
    BuildContext context,
    BankAccount account,
    void Function(BankAccountAction) onTap,
  ) {
    final canArchive = account.archivedAt == null && !account.isDeleted;
    final canRestore = account.archivedAt != null || account.isDeleted;

    return [
      editActionItem(
        context: context,
        kind: BankAccountAction.edit,
        onTap: () => onTap(BankAccountAction.edit),
      ),
      ?copyLinkActionItem(
        context: context,
        kind: BankAccountAction.copyLink,
        entityId: account.id,
        onTap: () => onTap(BankAccountAction.copyLink),
      ),
      ?archiveActionItem(
        context: context,
        subject: _confirmSubject(account),
        kind: BankAccountAction.archive,
        canArchive: canArchive,
        onTap: () => onTap(BankAccountAction.archive),
      ),
      ?restoreActionItem(
        context: context,
        kind: BankAccountAction.restore,
        canRestore: canRestore,
        onTap: () => onTap(BankAccountAction.restore),
      ),
      ?deleteActionItem(
        context: context,
        subject: _confirmSubject(account),
        kind: BankAccountAction.delete,
        canDelete: !account.isDeleted,
        onTap: () => onTap(BankAccountAction.delete),
      ),
    ];
  }

  static Future<void> dispatch(
    BuildContext context,
    Services services,
    String companyId,
    BankAccount account,
    BankAccountAction action,
  ) async {
    switch (action) {
      case BankAccountAction.edit:
        goEntityEdit(context, '/settings/bank_accounts', account.id);
      case BankAccountAction.copyLink:
        await copyEntityLink(context, EntityType.bankAccount, account.id);
      case BankAccountAction.archive:
        await StandardEntityActions.archive(
          context: context,
          wireName: 'bank_account',
          op: () => services.bankAccounts.archive(
            companyId: companyId,
            id: account.id,
          ),
          undoOp: () => services.bankAccounts.restore(
            companyId: companyId,
            id: account.id,
          ),
        );
      case BankAccountAction.restore:
        await StandardEntityActions.restore(
          context: context,
          wireName: 'bank_account',
          op: () => services.bankAccounts.restore(
            companyId: companyId,
            id: account.id,
          ),
        );
      case BankAccountAction.delete:
        if (!requireSynced(context, account.id)) return;
        await StandardEntityActions.delete(
          context: context,
          wireName: 'bank_account',
          op: () => services.bankAccounts.delete(
            companyId: companyId,
            id: account.id,
          ),
          undoOp: () => services.bankAccounts.restore(
            companyId: companyId,
            id: account.id,
          ),
        );
    }
  }
}
