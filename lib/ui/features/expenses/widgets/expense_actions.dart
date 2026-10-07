import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/expense.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/expense_invoice_line_item.dart';
import 'package:admin/domain/expense_recurring_conversion.dart';
import 'package:admin/domain/quick_create.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/activity_note_actions.dart';
import 'package:admin/ui/core/detail/copy_entity_link.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/detail/entity_quick_actions.dart';
import 'package:admin/ui/core/detail/standard_entity_action_items.dart';
import 'package:admin/ui/core/detail/standard_entity_actions.dart';
import 'package:admin/ui/core/sync/require_synced.dart';
import 'package:admin/ui/core/widgets/add_to_invoice_dialog.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/features/billing_shared/add_unbilled/invoice_append_context.dart';
import 'package:admin/ui/features/invoices/view_models/invoice_edit_view_model.dart';
import 'package:admin/ui/features/invoices/widgets/detail/run_template_dialog.dart';

/// Action set surfaced for an expense. Mirrors `ProjectAction` — all
/// branches do work.
enum ExpenseAction {
  edit,
  clone,
  cloneToRecurring,
  invoiceExpense,
  addToInvoice,
  runTemplate,
  addComment,
  logCall,
  viewVendor,
  copyLink,
  archive,
  restore,
  delete,
}

class ExpenseActions {
  ExpenseActions._();

  /// Actions the old admin-portal hid on a brand-new (unsaved) record.
  /// Fed to `filterForEditScreen` so the create screen drops clone /
  /// clone-to-recurring / archive / restore / delete.
  static bool isLifecycle(ExpenseAction action) {
    switch (action) {
      case ExpenseAction.clone:
      case ExpenseAction.cloneToRecurring:
      case ExpenseAction.archive:
      case ExpenseAction.restore:
      case ExpenseAction.delete:
        return true;
      default:
        return false;
    }
  }

  /// Display label for the "Are you sure?" prompt, so a confirm fired
  /// from a long list says which record it's about. Blank is fine — the
  /// dialog just omits the line.
  static String _confirmSubject(Expense expense) =>
      expense.number.isEmpty ? '' : '#${expense.number}';

  static List<EntityActionItem<ExpenseAction>> itemsFor(
    BuildContext context,
    Expense expense,
    void Function(ExpenseAction) onTap,
  ) {
    final me = context.read<Services>().auth.session.value?.currentCompany;
    // Archive, restore and delete all need `edit_expense`: the server
    // authorizes each through `EntityPolicy::edit` (there is no `delete_*`
    // permission). Ungated, a view-only user was offered Restore — one tap
    // from the record's state banner — for a mutation the server refuses.
    // The server's rule, not just the permission: the record's creator or
    // assignee may change it too (`AuthSession.canEditRecord`).
    final canEdit =
        context.read<Services>().auth.session.value?.canEditRecord(
          'expense',
          createdBy: expense.userId,
          assignedTo: expense.assignedUserId,
          recordId: expense.id,
        ) ??
        false;
    final canArchive =
        canEdit && expense.archivedAt == null && !expense.isDeleted;
    final canRestore =
        canEdit && (expense.archivedAt != null || expense.isDeleted);
    // Permission gate for the labelled "go to the vendor" item. Read lazily
    // here (itemsFor runs per build) so it re-resolves on a company switch.
    final canViewVendor = me?.can('view_vendor') ?? false;
    // An action that makes a new record needs `create_<entity>` — edit rights
    // never imply it — and, where the record is another kind, that kind's
    // module. A clone is a new expense; its own module is on or this expense
    // would not be on screen.
    bool canCreate(EntityType type) =>
        (me?.moduleEnabled(type) ?? false) &&
        (me?.can(createPermissionFor(type)) ?? false);
    final canClone = me?.can(createPermissionFor(EntityType.expense)) ?? false;

    return [
      // Everything that changes the expense, copies it or bills it. Hidden
      // entirely on a soft-deleted one — only the link, the vendor and
      // Restore remain, as on a deleted client: the server refuses an edit of
      // a deleted record, and the screen says it is read-only.
      if (!expense.isDeleted) ...[
        editActionItem(
          context: context,
          kind: ExpenseAction.edit,
          onTap: () => onTap(ExpenseAction.edit),
        ),
        if (canClone)
          EntityActionItem(
            kind: ExpenseAction.clone,
            icon: Icons.copy_outlined,
            label: context.tr('clone_expense'),
            enabled: true,
            onTap: () => onTap(ExpenseAction.clone),
          ),
        if (canCreate(EntityType.recurringExpense))
          EntityActionItem(
            kind: ExpenseAction.cloneToRecurring,
            icon: Icons.event_repeat_outlined,
            label: context.tr('clone_to_recurring'),
            enabled: true,
            onTap: () => onTap(ExpenseAction.cloneToRecurring),
          ),
        if (canCreate(EntityType.invoice))
          EntityActionItem(
            kind: ExpenseAction.invoiceExpense,
            icon: Icons.outbox_outlined,
            label: context.tr('invoice_expense'),
            enabled:
                !expense.id.startsWith('tmp_') && expense.invoiceId.isEmpty,
            onTap: () => onTap(ExpenseAction.invoiceExpense),
          ),
        // Appends to an invoice that already exists, so it is an edit of that
        // invoice rather than a new one — which the server allows its creator
        // too. Which invoice is not known until it is picked, so anyone who
        // could own one is asked.
        if ((me?.moduleEnabled(EntityType.invoice) ?? false) &&
            ((me?.can('edit_invoice') ?? false) ||
                (me?.can(createPermissionFor(EntityType.invoice)) ?? false)))
          EntityActionItem(
            kind: ExpenseAction.addToInvoice,
            icon: Icons.playlist_add_outlined,
            // `action_add_to_invoice`, not `add_to_invoice` — the latter is
            // "Add to invoice :invoice" (invoiceninja/flutter#35).
            label: context.tr('action_add_to_invoice'),
            // Mirrors admin-portal: an un-invoiced expense tied to a client
            // can be appended to one of that client's existing invoices.
            enabled:
                !expense.id.startsWith('tmp_') &&
                expense.invoiceId.isEmpty &&
                expense.clientId.isNotEmpty,
            onTap: () => onTap(ExpenseAction.addToInvoice),
          ),
        EntityActionItem(
          kind: ExpenseAction.runTemplate,
          icon: Icons.auto_awesome_outlined,
          label: context.tr('run_template'),
          enabled: !expense.id.startsWith('tmp_'),
          onTap: () => onTap(ExpenseAction.runTemplate),
        ),
        EntityActionItem(
          kind: ExpenseAction.addComment,
          icon: Icons.chat_bubble_outline,
          label: context.tr('add_comment'),
          enabled: true,
          onTap: () => onTap(ExpenseAction.addComment),
        ),
        EntityActionItem(
          kind: ExpenseAction.logCall,
          icon: Icons.phone_in_talk_outlined,
          label: context.tr('log_call'),
          enabled: true,
          onTap: () => onTap(ExpenseAction.logCall),
        ),
      ],
      if (expense.vendorId.isNotEmpty && canViewVendor)
        EntityActionItem(
          kind: ExpenseAction.viewVendor,
          icon: Icons.storefront_outlined,
          label: context.tr('view_vendor'),
          enabled: true,
          // Navigation only — must not reach the edit screen, where
          // `EntityEditScaffold._onAction` would save the dirty form (or
          // create the record) before dispatching it.
          isNavigationOnly: true,
          onTap: () => onTap(ExpenseAction.viewVendor),
        ),
      ?copyLinkActionItem(
        context: context,
        kind: ExpenseAction.copyLink,
        entityId: expense.id,
        onTap: () => onTap(ExpenseAction.copyLink),
      ),
      ?archiveActionItem(
        context: context,
        subject: _confirmSubject(expense),
        kind: ExpenseAction.archive,
        canArchive: canArchive,
        onTap: () => onTap(ExpenseAction.archive),
      ),
      ?restoreActionItem(
        context: context,
        kind: ExpenseAction.restore,
        canRestore: canRestore,
        onTap: () => onTap(ExpenseAction.restore),
      ),
      ?deleteActionItem(
        context: context,
        subject: _confirmSubject(expense),
        kind: ExpenseAction.delete,
        canDelete: canEdit && !expense.isDeleted,
        onTap: () => onTap(ExpenseAction.delete),
      ),
    ];
  }

  /// The expense screen's quick-action strip, most-used first. The strip
  /// shows the first few that apply (`pickQuickActions`); the rest stay one
  /// tap further away in the `⋮` menu, which still lists everything.
  ///
  /// Every tile is the *same item* [itemsFor] builds, looked up by kind, so
  /// its module and permission gates and its unsynced guard cannot drift from
  /// the menu's.
  ///
  /// `applies` is about relevance, not ability. Billing an expense is the one
  /// thing worth a tile while it has not been billed and is pointless once it
  /// has — and Add to Invoice needs a client whose invoices it could join. An
  /// expense that is done with shows the tiles for making the next one.
  static List<EntityQuickAction<ExpenseAction>> quickItemsFor(
    BuildContext context,
    Expense expense,
    void Function(ExpenseAction) onTap,
  ) {
    // A deleted expense is read-only, and an unsynced one would answer most
    // tiles with "sync first" — the banner says that once instead.
    if (expense.isDeleted || expense.id.startsWith('tmp_')) return const [];
    final items = itemsFor(context, expense, onTap);
    EntityQuickAction<ExpenseAction>? pick(
      ExpenseAction kind,
      String shortLabel, {
      bool applies = true,
    }) {
      final item = findActionItem<ExpenseAction>(items, kind);
      if (item == null) return null;
      return EntityQuickAction(
        item: item,
        shortLabel: shortLabel,
        applies: applies,
      );
    }

    final unbilled = expense.invoiceId.isEmpty;
    return [
      // "+ Invoice", not "Invoice Expense": the entity noun is one word in
      // every bundled locale, where the verb phrase will not fit a tile.
      ?pick(
        ExpenseAction.invoiceExpense,
        '+ ${context.tr('invoice')}',
        applies: unbilled,
      ),
      ?pick(
        ExpenseAction.addToInvoice,
        context.tr('action_add_to_invoice'),
        applies: unbilled && expense.clientId.isNotEmpty,
      ),
      ?pick(ExpenseAction.clone, context.tr('clone')),
      ?pick(ExpenseAction.cloneToRecurring, context.tr('recurring')),
      ?pick(ExpenseAction.runTemplate, context.tr('run_template')),
    ];
  }

  static Future<void> dispatch(
    BuildContext context,
    Services services,
    String companyId,
    Expense expense,
    ExpenseAction action,
  ) async {
    switch (action) {
      case ExpenseAction.edit:
        goEntityEdit(context, '/expenses', expense.id);
      case ExpenseAction.clone:
        final draft = expense.copyWith(
          id: '',
          number: '',
          // Mirror admin-portal's clone: drop attachments and reset the date
          // to today so the copy starts fresh.
          documents: const [],
          date: Date.today(),
          archivedAt: null,
          isDeleted: false,
          isDirty: false,
          invoiceId: '',
          paymentDate: null,
          paymentTypeId: '',
          transactionReference: '',
          transactionId: '',
          updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        );
        // A clone copies its source, so the create form skips the company's
        // new-expense defaults for it.
        goEntityCreateFullWidth(
          context,
          '/expenses',
          extra: draft,
          isClone: true,
        );
      case ExpenseAction.cloneToRecurring:
        // Convert to a real [RecurringExpense] clone seed (default monthly
        // schedule) before navigating. Expense and RecurringExpense are
        // distinct Freezed types, so the recurring create form's typed
        // `takeCreateSeed<RecurringExpense>` would drop an Expense — handing it
        // the converted object preserves the data.
        goEntityCreateFullWidth(
          context,
          '/recurring_expenses',
          extra: expense.toRecurringExpenseClone(),
          isClone: true,
        );
      case ExpenseAction.logCall:
        await promptLogCallFor(
          context,
          companyId: companyId,
          entityId: expense.id,
          subject: _confirmSubject(expense),
          vendorId: expense.vendorId,
          clientId: expense.clientId,
          submit: (text) => services.expenses.addComment(
            companyId: companyId,
            entityId: expense.id,
            text: text,
          ),
        );
      case ExpenseAction.addComment:
        await promptAddCommentFor(
          context,
          entityId: expense.id,
          submit: (text) => services.expenses.addComment(
            companyId: companyId,
            entityId: expense.id,
            text: text,
          ),
        );
      case ExpenseAction.viewVendor:
        if (expense.vendorId.isEmpty) return;
        goEntityFullDetail(context, '/vendors', expense.vendorId);
      case ExpenseAction.copyLink:
        await copyEntityLink(context, EntityType.expense, expense.id);
      case ExpenseAction.archive:
        await StandardEntityActions.archive(
          context: context,
          wireName: 'expense',
          op: () =>
              services.expenses.archive(companyId: companyId, id: expense.id),
          undoOp: () =>
              services.expenses.restore(companyId: companyId, id: expense.id),
        );
      case ExpenseAction.restore:
        await StandardEntityActions.restore(
          context: context,
          wireName: 'expense',
          op: () =>
              services.expenses.restore(companyId: companyId, id: expense.id),
        );
      case ExpenseAction.delete:
        if (!requireSynced(context, expense.id)) return;
        await StandardEntityActions.delete(
          context: context,
          wireName: 'expense',
          op: () =>
              services.expenses.delete(companyId: companyId, id: expense.id),
          undoOp: () =>
              services.expenses.restore(companyId: companyId, id: expense.id),
        );
      case ExpenseAction.invoiceExpense:
        if (!requireSynced(context, expense.id)) return;
        if (expense.invoiceId.isNotEmpty) {
          Notify.error(context, context.tr('expense_already_invoiced'));
          return;
        }
        // A new invoice adopts the expense's inclusive-tax mode (React parity),
        // so the carried line tax is interpreted the same way it was on the
        // expense.
        final draft = emptyInvoice().copyWith(
          clientId: expense.clientId,
          projectId: expense.projectId,
          vendorId: expense.vendorId,
          usesInclusiveTaxes: expense.usesInclusiveTaxes,
          lineItems: [
            expenseInvoiceLineItem(
              expense,
              invoiceInclusive: expense.usesInclusiveTaxes,
            ),
          ],
        );
        goEntityCreateFullWidth(context, '/invoices', extra: draft);
      case ExpenseAction.runTemplate:
        if (!requireSynced(context, expense.id)) return;
        final templateId = await showRunTemplateDialog(context);
        if (templateId == null || !context.mounted) return;
        await services.expenses.runTemplate(
          companyId: companyId,
          id: expense.id,
          templateId: templateId,
        );
        if (!context.mounted) return;
        Notify.success(context, context.tr('template_queued'));
      case ExpenseAction.addToInvoice:
        if (!requireSynced(context, expense.id)) return;
        if (expense.invoiceId.isNotEmpty) {
          Notify.error(context, context.tr('expense_already_invoiced'));
          return;
        }
        if (expense.clientId.isEmpty) {
          Notify.error(context, context.tr('please_select_a_client'));
          return;
        }
        final formatter = await services.formatterFor(companyId);
        if (!context.mounted) return;
        final target = await showAddToInvoiceDialog(
          context,
          services: services,
          companyId: companyId,
          clientId: expense.clientId,
          formatter: formatter,
        );
        if (target == null || !context.mounted) return;
        // The target invoice's tax mode is fixed — seed the line cost to match
        // it so the line total lands on the expense's gross either way.
        final addItem = expenseInvoiceLineItem(
          expense,
          invoiceInclusive: target.usesInclusiveTaxes,
        );
        context.go(
          '/invoices/${target.id}/edit',
          extra: target.copyWith(lineItems: [...target.lineItems, addItem]),
        );
    }
  }

  // ─── Bulk (list selection) ───────────────────────────────────────────

  /// The billable part of a selection, or null when it can't be used (the
  /// user has been told why). Expenses for more than one client can't share
  /// an invoice — counted over the billable rows only, so an already-invoiced
  /// expense of another client in the selection doesn't block the rest.
  static List<Expense>? _billableSelection(
    BuildContext context,
    List<Expense> expenses,
  ) {
    final selection = bulkBillableSelection(expenses);
    if (selection.billable.isEmpty) {
      Notify.info(context, context.tr('no_billable_expenses'));
      return null;
    }
    if (selection.multipleClients) {
      Notify.error(context, context.tr('multiple_client_error'));
      return null;
    }
    return selection.billable;
  }

  /// Silently dropping rows from a bulk selection reads as a bug.
  static void _reportSkipped(BuildContext context, int used, int selected) {
    if (used >= selected) return;
    Notify.info(
      context,
      context.tr('added_expense_items_partial', {
        'count': '$used',
        'total': '$selected',
      }),
    );
  }

  /// An expense recorded in another currency with no conversion lands on the
  /// invoice at its own amount, in the wrong currency. Worth a warning when a
  /// selection mixes them.
  static void _warnMixedCurrencies(BuildContext context, List<Expense> items) {
    String billedIn(Expense e) =>
        e.invoiceCurrencyId.isNotEmpty && e.foreignAmount > Decimal.zero
        ? e.invoiceCurrencyId
        : e.currencyId;
    if (items.map(billedIn).where((c) => c.isNotEmpty).toSet().length > 1) {
      Notify.warning(context, context.tr('expense_currency_mismatch'));
    }
  }

  /// "Invoice Expense" over a selection: one new invoice with a line per
  /// expense (React #3382). The invoice takes the first expense's
  /// inclusive-tax mode, and every line is costed for that same mode — a
  /// mixed selection would otherwise read half its lines the wrong way.
  /// Project and vendor carry over only when every expense agrees.
  static Future<void> invoiceExpenses(
    BuildContext context,
    List<Expense> expenses,
  ) async {
    final billable = _billableSelection(context, expenses);
    if (billable == null) return;
    final inclusive = billable.first.usesInclusiveTaxes;
    String shared(String Function(Expense) of) {
      final values = billable.map(of).toSet();
      return values.length == 1 ? values.single : '';
    }

    _warnMixedCurrencies(context, billable);
    _reportSkipped(context, billable.length, expenses.length);
    goEntityCreateFullWidth(
      context,
      '/invoices',
      extra: emptyInvoice().copyWith(
        clientId: billable
            .map((e) => e.clientId)
            .firstWhere((c) => c.isNotEmpty, orElse: () => ''),
        projectId: shared((e) => e.projectId),
        vendorId: shared((e) => e.vendorId),
        usesInclusiveTaxes: inclusive,
        lineItems: [
          for (final e in billable)
            expenseInvoiceLineItem(e, invoiceInclusive: inclusive),
        ],
      ),
    );
  }

  /// "Add to invoice" over a selection: appends the expenses to one of the
  /// client's open invoices, skipping any already on it.
  static Future<void> addExpensesToInvoice(
    BuildContext context,
    Services services,
    String companyId,
    List<Expense> expenses,
  ) async {
    final billable = _billableSelection(context, expenses);
    if (billable == null) return;
    final clientId = billable
        .map((e) => e.clientId)
        .firstWhere((c) => c.isNotEmpty, orElse: () => '');
    if (clientId.isEmpty) {
      Notify.error(context, context.tr('please_select_a_client'));
      return;
    }
    final formatter = await services.formatterFor(companyId);
    if (!context.mounted) return;
    final target = await showAddToInvoiceDialog(
      context,
      services: services,
      companyId: companyId,
      clientId: clientId,
      formatter: formatter,
    );
    if (target == null || !context.mounted) return;
    final existing = await InvoiceAppendContext.of(services, companyId, target);
    if (!context.mounted) return;
    final fresh = billable
        .where((e) => !existing.expenseIds.contains(e.id))
        .toList();
    if (fresh.isEmpty) {
      Notify.info(context, context.tr('no_billable_expenses'));
      return;
    }
    _warnMixedCurrencies(context, fresh);
    _reportSkipped(context, fresh.length, expenses.length);
    // The target invoice's tax mode is fixed — cost every line for it.
    goEntityEditWithDraft(
      context,
      '/invoices',
      target.id,
      target.copyWith(
        lineItems: [
          ...target.lineItems,
          for (final e in fresh)
            expenseInvoiceLineItem(
              e,
              invoiceInclusive: target.usesInclusiveTaxes,
            ),
        ],
      ),
    );
  }
}
