import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/bank_account.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/copy_entity_link.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/detail/entity_quick_actions.dart';
import 'package:admin/ui/core/detail/standard_entity_action_items.dart';
import 'package:admin/ui/core/detail/standard_entity_actions.dart';
import 'package:admin/ui/core/sync/require_synced.dart';
import 'package:admin/ui/core/widgets/notify.dart';

/// Action set surfaced for a bank account. Mirrors the standard minimum
/// surface — edit / archive / restore / delete — since bank accounts (bank
/// integrations) carry no clone or cross-entity navigation. Mirrors
/// `ExpenseCategoryActions`.
enum BankAccountAction {
  edit,

  /// Quick-action strip only — see [BankAccountActions.quickItemsFor]. Not in
  /// [BankAccountActions.itemsFor], so they reach neither the `⋮` menu nor
  /// the list row's menu.
  viewTransactions,
  refreshAccounts,
  copyLink,
  archive,
  restore,
  delete,
}

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
    // Archive, restore and delete all need `edit_bank_integration` (the wire
    // name of a bank account): the server authorizes each through
    // `EntityPolicy::edit`, and there is no `delete_*` permission. Ungated, a
    // view-only user was offered Restore — one tap from the record's state
    // banner — for a mutation the server refuses.
    final me = context.read<Services>().auth.session.value?.currentCompany;
    final canEdit = me?.can('edit_bank_integration') ?? false;
    // Archive and restore go through `bank_integrations/bulk`, which is
    // admin-only (`BulkBankIntegrationRequest::authorize`) — stricter than
    // the delete beside them, which the edit policy answers.
    final isAdmin = (me?.isAdmin ?? false) || (me?.isOwner ?? false);
    final canArchive =
        isAdmin && account.archivedAt == null && !account.isDeleted;
    final canRestore =
        isAdmin && (account.archivedAt != null || account.isDeleted);

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
        canDelete: canEdit && !account.isDeleted,
        onTap: () => onTap(BankAccountAction.delete),
      ),
    ];
  }

  /// The record screen's quick-action tiles: open this account's
  /// transactions in the full workspace, and ask the provider for fresh ones.
  ///
  /// Both exist only here (see [BankAccountAction.viewTransactions]). There
  /// is deliberately no Reconnect tile: the record already carries the
  /// `ReconnectBanner`, which explains *why* and has the button.
  static List<EntityQuickAction<BankAccountAction>> quickItemsFor(
    BuildContext context,
    BankAccount account,
    void Function(BankAccountAction) onTap,
  ) {
    // A deleted account is read-only, and an unsynced one has no transactions
    // to open and nothing upstream to ask — the banner says that once.
    if (account.isDeleted || account.id.startsWith('tmp_')) return const [];
    final me = context.read<Services>().auth.session.value?.currentCompany;
    final canViewTransactions =
        (me?.moduleEnabled(EntityType.transaction) ?? false) &&
        (me?.can('view_bank_transaction') ?? false);
    return [
      EntityQuickAction(
        item: EntityActionItem(
          kind: BankAccountAction.viewTransactions,
          icon: Icons.swap_horiz,
          label: '${context.tr('transactions')}: ${context.tr('view_all')}',
          enabled: canViewTransactions,
          // Navigation only — it persists nothing.
          isNavigationOnly: true,
          onTap: () => onTap(BankAccountAction.viewTransactions),
        ),
        // Not "Transactions": the tab right under the tiles is called that,
        // and this goes somewhere else — the workspace list.
        shortLabel: context.tr('view_all'),
      ),
      EntityQuickAction(
        item: EntityActionItem(
          kind: BankAccountAction.refreshAccounts,
          icon: Icons.sync,
          label: context.tr('refresh'),
          // `AdminBankIntegrationRequest`: admins only.
          enabled: (me?.isAdmin ?? false) || (me?.isOwner ?? false),
          onTap: () => onTap(BankAccountAction.refreshAccounts),
        ),
        shortLabel: context.tr('refresh'),
        // Only an account that came from a provider has anything upstream to
        // poll, and one whose connection has dropped has to be reconnected
        // first.
        applies: account.integrationType.isNotEmpty && !account.needsReconnect,
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
      case BankAccountAction.viewTransactions:
        // The workspace list, scoped to this account — bulk actions, saved
        // views and the status tabs live there, not in the embedded list.
        context.go('/transactions?bank_account_id=${account.id}');
      case BankAccountAction.refreshAccounts:
        // Asks the server to poll the upstream provider for fresh balances and
        // transactions. Routed through the outbox (queued + retried), so this
        // toasts a transient "Processing" rather than awaiting an answer.
        await services.bankAccounts.refreshAccounts(companyId: companyId);
        if (context.mounted) Notify.info(context, context.tr('processing'));
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
