import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/phone/phone_candidates.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/activity_note_actions.dart';
import 'package:admin/ui/core/detail/copy_entity_link.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/detail/standard_entity_action_items.dart';
import 'package:admin/ui/core/detail/standard_entity_actions.dart';
import 'package:admin/ui/core/sync/require_synced.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/features/clients/widgets/client_portal.dart';
import 'package:admin/ui/features/clients/widgets/detail/assign_group_dialog.dart';
import 'package:admin/ui/features/clients/widgets/detail/merge_client_dialog.dart';
import 'package:admin/ui/features/clients/widgets/detail/purge_client_dialog.dart';
import 'package:admin/ui/features/credits/view_models/credit_edit_view_model.dart';
import 'package:admin/ui/features/expenses/view_models/expense_edit_view_model.dart';
import 'package:admin/ui/features/invoices/view_models/invoice_edit_view_model.dart';
import 'package:admin/ui/features/payments/view_models/payment_edit_view_model.dart';
import 'package:admin/ui/features/quotes/view_models/quote_edit_view_model.dart';
import 'package:admin/ui/features/recurring_invoices/view_models/recurring_invoice_edit_view_model.dart';
import 'package:admin/ui/features/settings/state/settings_level_controller.dart';
import 'package:admin/ui/features/tasks/view_models/task_edit_view_model.dart';

/// Full action set surfaced for a client. Mirrors the actions exposed in
/// admin-portal's `client_model.dart#getActions`, minus a few multiselect-
/// only / role-gated ones we don't have analogues for yet. Consumed by
/// both the detail-screen header and the list-row popup so the two
/// surfaces stay in sync — see [ClientActions.itemsFor].
enum ClientAction {
  edit,
  viewStatement,
  clientPortal,
  settings,
  assignGroup,
  addComment,
  logCall,
  clone,
  newGroup,
  newInvoice,
  newRecurringInvoice,
  newQuote,
  newCredit,
  newPayment,
  newTask,
  newExpense,
  merge,
  copyLink,
  archive,
  restore,
  delete,
  purge,
}

/// Single source of truth for what client actions exist and what they do.
/// The list-row popup (`ClientListTile`) and the detail header
/// (`ClientDetailScreen`) both consume this — mirrors admin-portal's
/// `entity.getActions(...)` pattern.
class ClientActions {
  ClientActions._();

  /// Actions the old admin-portal hid on a brand-new (unsaved) record.
  /// Fed to `filterForEditScreen` so the create screen drops clone /
  /// archive / restore / delete (the clone group collapses as a whole).
  static bool isLifecycle(ClientAction action) {
    switch (action) {
      case ClientAction.clone:
      case ClientAction.archive:
      case ClientAction.restore:
      case ClientAction.delete:
        return true;
      default:
        return false;
    }
  }

  /// After-save actions whose [dispatch] navigates unconditionally; the
  /// create-mode edit scaffold uses this to keep that navigation instead of
  /// redirecting to the detail screen. See `InvoiceActions.navigatesOnCreate`.
  /// `clientPortal` (empty-URL early return) and `settings` (a global
  /// settings-scope jump, not entity navigation) are deliberately excluded.
  static bool navigatesOnCreate(ClientAction action) {
    switch (action) {
      case ClientAction.viewStatement:
        return true;
      default:
        return false;
    }
  }

  /// Item list shown by both the detail header row and the list-row popup.
  /// [onTap] receives the action; the caller wires it to [dispatch] (or
  /// any other handler).
  /// Display label for the "Are you sure?" prompt, so a confirm fired
  /// from a long list says which record it's about. Blank is fine — the
  /// dialog just omits the line.
  static String _confirmSubject(Client client) => client.displayName;

  static List<EntityActionItem<ClientAction>> itemsFor(
    BuildContext context,
    Client client,
    void Function(ClientAction) onTap,
  ) {
    final canArchive = client.archivedAt == null && !client.isDeleted;
    final canRestore = client.archivedAt != null || client.isDeleted;
    // Merge + Purge are admin/owner-only — matches React's `isAdmin ||
    // isOwner` gate (admin-portal gates both on `isAdmin`). Reading via
    // `context.read` from inside the action builder keeps the gate
    // centralized here instead of plumbing the flag through ClientListTile
    // and EntityDetailActionsRow.
    final me = context.read<Services>().auth.session.value?.currentCompany;
    final isAdminOrOwner = (me?.isAdmin ?? false) || (me?.isOwner ?? false);

    // The primary contact (falling back to the first) carries the portal
    // link. A `tmp_` client's contacts have no server link yet, so the
    // action disables itself rather than opening a dead URL.
    final portalContact = client.contacts.isEmpty
        ? null
        : client.contacts.firstWhere(
            (c) => c.isPrimary,
            orElse: () => client.contacts.first,
          );
    final hasPortalLink =
        (portalContact?.link.isNotEmpty ?? false) &&
        !client.id.startsWith('tmp_');

    return [
      // Single-record view / create / clone actions. Hidden entirely on a
      // soft-deleted client — only Restore + Purge remain, matching
      // admin-portal's `!isDeleted` grouping and React.
      if (!client.isDeleted) ...[
        editActionItem(
          context: context,
          kind: ClientAction.edit,
          onTap: () => onTap(ClientAction.edit),
        ),
        EntityActionItem(
          kind: ClientAction.viewStatement,
          icon: Icons.picture_as_pdf,
          label: context.tr('view_statement'),
          enabled: true,
          onTap: () => onTap(ClientAction.viewStatement),
        ),
        EntityActionItem(
          kind: ClientAction.clientPortal,
          icon: Icons.cloud_outlined,
          label: context.tr('client_portal'),
          // Opens the primary contact's portal with silent auto-login.
          enabled: hasPortalLink,
          onTap: () => onTap(ClientAction.clientPortal),
        ),
        EntityActionItem(
          kind: ClientAction.settings,
          icon: Icons.settings_outlined,
          label: context.tr('settings'),
          enabled: true,
          onTap: () => onTap(ClientAction.settings),
        ),
        EntityActionItem(
          kind: ClientAction.assignGroup,
          icon: Icons.group_outlined,
          label: context.tr('assign_group'),
          enabled: true,
          onTap: () => onTap(ClientAction.assignGroup),
        ),
        EntityActionItem(
          kind: ClientAction.addComment,
          icon: Icons.add_comment_outlined,
          label: context.tr('add_comment'),
          enabled: true,
          onTap: () => onTap(ClientAction.addComment),
        ),
        EntityActionItem(
          kind: ClientAction.logCall,
          icon: Icons.phone_in_talk_outlined,
          label: context.tr('log_call'),
          enabled: true,
          onTap: () => onTap(ClientAction.logCall),
        ),
        EntityActionItem(
          kind: ClientAction.clone,
          icon: Icons.copy_outlined,
          label: context.tr('clone'),
          enabled: true,
          onTap: () => onTap(ClientAction.clone),
        ),
        if ((me?.moduleEnabled(EntityType.invoice) ?? false) ||
            (me?.moduleEnabled(EntityType.recurringInvoice) ?? false) ||
            (me?.moduleEnabled(EntityType.quote) ?? false) ||
            (me?.moduleEnabled(EntityType.credit) ?? false) ||
            (me?.moduleEnabled(EntityType.payment) ?? false) ||
            (me?.moduleEnabled(EntityType.task) ?? false) ||
            (me?.moduleEnabled(EntityType.expense) ?? false))
          newGroupActionItem(
            context: context,
            kind: ClientAction.newGroup,
            children: [
              if (me?.moduleEnabled(EntityType.invoice) ?? false)
                EntityActionItem(
                  kind: ClientAction.newInvoice,
                  icon: Icons.receipt_long_outlined,
                  label: context.tr('new_invoice'),
                  enabled: true,
                  onTap: () => onTap(ClientAction.newInvoice),
                ),
              if (me?.moduleEnabled(EntityType.recurringInvoice) ?? false)
                EntityActionItem(
                  kind: ClientAction.newRecurringInvoice,
                  icon: Icons.autorenew,
                  label: context.tr('new_recurring_invoice'),
                  enabled: true,
                  onTap: () => onTap(ClientAction.newRecurringInvoice),
                ),
              if (me?.moduleEnabled(EntityType.quote) ?? false)
                EntityActionItem(
                  kind: ClientAction.newQuote,
                  icon: Icons.request_quote_outlined,
                  label: context.tr('new_quote'),
                  enabled: true,
                  onTap: () => onTap(ClientAction.newQuote),
                ),
              if (me?.moduleEnabled(EntityType.credit) ?? false)
                EntityActionItem(
                  kind: ClientAction.newCredit,
                  icon: Icons.account_balance_wallet_outlined,
                  label: context.tr('new_credit'),
                  enabled: true,
                  onTap: () => onTap(ClientAction.newCredit),
                ),
              if (me?.moduleEnabled(EntityType.payment) ?? false)
                EntityActionItem(
                  kind: ClientAction.newPayment,
                  icon: Icons.payments_outlined,
                  label: context.tr('new_payment'),
                  enabled: true,
                  onTap: () => onTap(ClientAction.newPayment),
                ),
              if (me?.moduleEnabled(EntityType.task) ?? false)
                EntityActionItem(
                  kind: ClientAction.newTask,
                  icon: Icons.check_circle_outline,
                  label: context.tr('new_task'),
                  enabled: true,
                  onTap: () => onTap(ClientAction.newTask),
                ),
              if (me?.moduleEnabled(EntityType.expense) ?? false)
                EntityActionItem(
                  kind: ClientAction.newExpense,
                  icon: Icons.attach_money,
                  label: context.tr('new_expense'),
                  enabled: true,
                  onTap: () => onTap(ClientAction.newExpense),
                ),
            ],
          ),
      ],
      // Merge is admin/owner-only and never offered on a deleted client.
      if (isAdminOrOwner && !client.isDeleted)
        EntityActionItem(
          kind: ClientAction.merge,
          icon: Icons.merge_type,
          label: context.tr('merge'),
          // Destructive + server round-trip: only on a synced, active client.
          enabled: client.archivedAt == null && !client.id.startsWith('tmp_'),
          onTap: () => onTap(ClientAction.merge),
        ),
      ?copyLinkActionItem(
        context: context,
        kind: ClientAction.copyLink,
        entityId: client.id,
        onTap: () => onTap(ClientAction.copyLink),
      ),
      ?archiveActionItem(
        context: context,
        subject: _confirmSubject(client),
        kind: ClientAction.archive,
        canArchive: canArchive,
        onTap: () => onTap(ClientAction.archive),
      ),
      ?restoreActionItem(
        context: context,
        kind: ClientAction.restore,
        canRestore: canRestore,
        onTap: () => onTap(ClientAction.restore),
      ),
      ?deleteActionItem(
        context: context,
        subject: _confirmSubject(client),
        kind: ClientAction.delete,
        canDelete: !client.isDeleted,
        onTap: () => onTap(ClientAction.delete),
      ),
      ?purgeActionItem(
        context: context,
        subject: _confirmSubject(client),
        // `dispatch` opens the stronger bespoke `showPurgeClientDialog`
        // warning, so the generic gate would be a second prompt in front of it.
        confirm: false,
        kind: ClientAction.purge,
        canPurge: isAdminOrOwner,
        onTap: () => onTap(ClientAction.purge),
      ),
    ];
  }

  /// Runs [action] for [client]. Single dispatch path for both the
  /// detail-screen header and the list-row popup. Placeholder branches
  /// `break;` so the enum stays exhaustive and future wiring is grep-able.
  static Future<void> dispatch(
    BuildContext context,
    Services services,
    String companyId,
    Client client,
    ClientAction action,
  ) async {
    switch (action) {
      case ClientAction.newGroup:
        break; // Submenu parent — never dispatched; children carry the action.
      case ClientAction.edit:
        goEntityEdit(context, '/clients', client.id);
      case ClientAction.viewStatement:
        // A `tmp_` client lives only in the local outbox — the server doesn't
        // know it yet, so a statement POST would 404. Tell the user to sync.
        if (!requireSynced(context, client.id)) return;
        // `go` (not `push`) so the inner Navigator resolves the full route
        // chain — `/clients/:id` + `statement` — and lands both pages on
        // its stack. `push` from the bare list URL drops the missing `:id`
        // parent: the URL updates (row paints as selected) but the
        // sub-route never makes it into the pane. Matches the working
        // `payment_actions.dart` refund pattern. Offline is surfaced inside
        // the screen by `ClientStatementViewModel`.
        context.go('/clients/${client.id}/statement');
      case ClientAction.clientPortal:
        if (!requireSynced(context, client.id)) return;
        // Open the primary contact's portal (falling back to the first),
        // with silent auto-login + client_hash — matches admin-portal /
        // React. The item is disabled in itemsFor when no link exists, so
        // the empty-url guard here is just defensive.
        final portalContact = client.contacts.isEmpty
            ? null
            : client.contacts.firstWhere(
                (c) => c.isPrimary,
                orElse: () => client.contacts.first,
              );
        final portalUrl = portalContact == null
            ? ''
            : clientPortalUrl(
                contactLink: portalContact.link,
                clientHash: client.clientHash,
              );
        if (portalUrl.isEmpty) return;
        await launchClientPortal(context, portalUrl);
      case ClientAction.copyLink:
        await copyEntityLink(context, EntityType.client, client.id);
      case ClientAction.archive:
        await StandardEntityActions.archive(
          context: context,
          wireName: 'client',
          op: () =>
              services.clients.archive(companyId: companyId, id: client.id),
          undoOp: () =>
              services.clients.restore(companyId: companyId, id: client.id),
        );
      case ClientAction.restore:
        await StandardEntityActions.restore(
          context: context,
          wireName: 'client',
          op: () =>
              services.clients.restore(companyId: companyId, id: client.id),
        );
      case ClientAction.settings:
        if (!requireSynced(context, client.id)) return;
        services.settingsLevel.setLevel(
          SettingsLevel.client,
          targetId: client.id,
          targetName: client.displayName,
        );
        // Localization mirrors admin-portal's default landing for client
        // scope and is the first non-company-only entry in the filtered
        // sidebar — picking it explicitly keeps the two heuristics in
        // agreement.
        context.go('/settings/localization');
      case ClientAction.assignGroup:
        if (!requireSynced(context, client.id)) return;
        // Best-effort cache warm — a user opening this action from a fresh
        // login may never have visited Group Settings, so the local Drift
        // table can be empty even when the server has groups. The dialog's
        // empty-list state covers offline / failed-refresh cases.
        unawaited(services.groupSettings.refreshAll(companyId: companyId));
        if (!context.mounted) return;
        final result = await showAssignGroupDialog(
          context,
          client: client,
          services: services,
          companyId: companyId,
        );
        if (!result.changed || !context.mounted) return;
        try {
          await services.clients.save(
            companyId: companyId,
            client: client.copyWith(groupSettingsId: result.groupId ?? ''),
          );
          if (context.mounted) {
            Notify.success(context, context.tr('updated_client'));
          }
        } catch (e) {
          if (context.mounted) {
            Notify.error(context, context.tr('could_not_save'), error: e);
          }
        }
      case ClientAction.logCall:
        await promptLogCallFor(
          context,
          companyId: companyId,
          entityId: client.id,
          subject: _confirmSubject(client),
          candidates: clientPhoneCandidates(client),
          submit: (text) => services.clients.addComment(
            companyId: companyId,
            clientId: client.id,
            text: text,
          ),
        );
      case ClientAction.addComment:
        await promptAddCommentFor(
          context,
          entityId: client.id,
          submit: (text) => services.clients.addComment(
            companyId: companyId,
            clientId: client.id,
            text: text,
          ),
        );
      case ClientAction.delete:
        // `tmp_` ids only exist locally — the server has no row to delete
        // yet. Block instead of enqueuing a delete that the dispatcher
        // would 404 once the create round-trips. Matches the gate on
        // viewStatement / settings / addComment.
        if (!requireSynced(context, client.id)) return;
        await StandardEntityActions.delete(
          context: context,
          wireName: 'client',
          op: () =>
              services.clients.delete(companyId: companyId, id: client.id),
          undoOp: () =>
              services.clients.restore(companyId: companyId, id: client.id),
        );
      case ClientAction.purge:
        if (!requireSynced(context, client.id)) return;
        final ok = await showPurgeClientDialog(
          context,
          displayName: client.displayName,
        );
        if (!ok || !context.mounted) return;
        await StandardEntityActions.purge(
          context: context,
          wireName: 'client',
          op: () => services.clients.purge(companyId: companyId, id: client.id),
        );
        // Leave the detail screen before the dispatcher hard-deletes the
        // local row; without this, EntityDetailScaffold flips to the
        // "client not found" empty state right after the user confirms
        // purge — reads as an error rather than as confirmation. Going
        // to the list from the list popup is a no-op.
        if (context.mounted) context.go('/clients');
      case ClientAction.clone:
        final draft = client.copyWith(
          id: '',
          number: '',
          balance: Decimal.zero,
          paidToDate: Decimal.zero,
          creditBalance: Decimal.zero,
          archivedAt: null,
          isDeleted: false,
          isDirty: false,
          updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          contacts: [
            for (final c in client.contacts)
              c.copyWith(
                id: '',
                updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
                isDeleted: false,
              ),
          ],
        );
        goEntityCreateFullWidth(context, '/clients', extra: draft);
      case ClientAction.newInvoice:
        if (!requireSynced(context, client.id)) return;
        goEntityCreateFullWidth(
          context,
          '/invoices',
          extra: emptyInvoice().copyWith(clientId: client.id),
        );
      case ClientAction.newRecurringInvoice:
        if (!requireSynced(context, client.id)) return;
        goEntityCreateFullWidth(
          context,
          '/recurring_invoices',
          extra: emptyRecurringInvoice().copyWith(clientId: client.id),
        );
      case ClientAction.newQuote:
        if (!requireSynced(context, client.id)) return;
        goEntityCreateFullWidth(
          context,
          '/quotes',
          extra: emptyQuote().copyWith(clientId: client.id),
        );
      case ClientAction.newCredit:
        if (!requireSynced(context, client.id)) return;
        goEntityCreateFullWidth(
          context,
          '/credits',
          extra: emptyCredit().copyWith(clientId: client.id),
        );
      case ClientAction.newPayment:
        if (!requireSynced(context, client.id)) return;
        // `/payments/new` defaults to the slide-over sidebar (see
        // `_kEditDefaultsToSlide` in `master_detail_layout.dart`); do not
        // force `?view=full` here. Stage the seed on `Services` (survives the
        // cross-branch hop + screen reuse, unlike `extra:`).
        services.stageCreateDraft(
          '/payments',
          emptyPayment().copyWith(clientId: client.id),
        );
        context.go('/payments/new');
      case ClientAction.newTask:
        if (!requireSynced(context, client.id)) return;
        goEntityCreateFullWidth(
          context,
          '/tasks',
          extra: emptyTask().copyWith(clientId: client.id),
        );
      case ClientAction.newExpense:
        if (!requireSynced(context, client.id)) return;
        goEntityCreateFullWidth(
          context,
          '/expenses',
          extra: emptyExpense().copyWith(clientId: client.id),
        );
      case ClientAction.merge:
        if (!requireSynced(context, client.id)) return;
        final survivor = await showMergeClientDialog(
          context,
          services: services,
          companyId: companyId,
          source: client,
        );
        if (survivor == null || !context.mounted) return;
        try {
          // Password-gated server-side; the outbox 412 gate surfaces the
          // ConfirmPasswordSheet exactly as it does for delete/purge.
          await services.clients.merge(
            companyId: companyId,
            mergeIntoId: survivor.id,
            mergeFromId: client.id,
          );
          if (!context.mounted) return;
          Notify.success(context, context.tr('merged_clients'));
          // The absorbed client's detail route is now dead — leave it.
          context.go('/clients');
        } catch (e) {
          if (context.mounted) {
            Notify.error(context, context.tr('could_not_save'), error: e);
          }
        }
    }
  }
}
