import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/entity_detail_tabs.dart';
import 'package:admin/ui/core/detail/build_standard_documents_tab.dart';
import 'package:admin/ui/features/billing_shared/ledger/ledger_tab.dart';
import 'package:admin/utils/formatting.dart';
import 'package:admin/ui/core/detail/activity_note_buttons.dart';
import 'package:admin/ui/features/billing_shared/activity/entity_activity_tab.dart';
import 'package:admin/ui/features/billing_shared/activity/entity_activity_view_model.dart';
import 'package:admin/ui/features/clients/widgets/detail/client_email_history_tab.dart';
import 'package:admin/ui/features/clients/widgets/detail/client_locations_tab.dart';
import 'package:admin/ui/features/clients/widgets/detail/client_system_logs_tab.dart';
import 'package:admin/ui/features/credits/views/credit_list_screen.dart';
import 'package:admin/ui/features/expenses/views/expense_list_screen.dart';
import 'package:admin/ui/features/invoices/views/invoice_list_screen.dart';
import 'package:admin/ui/features/payments/views/payment_list_screen.dart';
import 'package:admin/ui/features/projects/views/project_list_screen.dart';
import 'package:admin/ui/features/quotes/views/quote_list_screen.dart';
import 'package:admin/ui/features/recurring_invoices/views/recurring_invoice_list_screen.dart';
import 'package:admin/ui/features/tasks/views/task_list_screen.dart';

/// Bottom of the client detail screen: a tab strip listing every related-
/// entity table (Invoices, Quotes, Payments, …) plus Activity + Documents.
///
/// Each related-entity tab embeds the corresponding workspace list screen
/// in `embedded: true` mode scoped to this client via its `clientId`
/// constructor param. The embedded scaffold renders its own slim toolbar
/// (filter + parent-prefilled "New") and grows with the detail page (no
/// nested scrollbar).
///
/// The related-entity tabs keep the order of the React reference at
/// `react/src/pages/clients/show/hooks/useTabs.tsx`, but the record's own
/// history leads the strip: Comments then Activity, both views of one feed.
/// Activity used to sit 15th of 15, which on the 440-560 px pane is four
/// screens of horizontal scrolling away (invoiceninja/flutter#122). React
/// diverges here anyway — it puts `History / Activity` 10th of 12, ahead of
/// Documents and Settings.
/// Tab scaffolding is delegated to [EntityDetailTabs] in
/// `lib/ui/core/detail/entity_detail_tabs.dart` so other detail screens
/// reuse the same strip + lazy-mount semantics.
class ClientDetailTabs extends StatelessWidget {
  const ClientDetailTabs({
    required this.client,
    required this.formatter,
    required this.activityVm,
    required this.selectTab,
    required this.notes,
    super.key,
  });

  final Client client;
  final Formatter? formatter;

  /// Owned by `ClientDetailScreen` so the Comments card above this strip and
  /// the two feed tabs below it share one fetch.
  final EntityActivityViewModel activityVm;
  final TabSelectionController selectTab;

  /// Built once by the screen and shared with the Comments card above this
  /// strip — see `EntityNoteActions`. Building a second one here is what let
  /// the two surfaces drift the last time.
  final EntityNoteActions notes;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final session = services.auth.session.value;
    if (session == null) return const SizedBox.shrink();
    final companyId = session.currentCompanyId;

    final clientId = client.id;
    // Hide related-entity tabs whose module is disabled for this company.
    final me = session.currentCompany;
    return EntityDetailTabs(
      initialIndex: 2,
      selectTab: selectTab,
      tabs: [
        EntityDetailTab(
          label: context.tr('comments'),
          icon: Icons.comment_outlined,
          bodyBuilder: (_) => EntityActivityTab(
            vm: activityVm,
            formatter: formatter,
            actions: notes,
            commentsOnly: true,
            hostWireName: 'client',
          ),
        ),
        EntityDetailTab(
          label: context.tr('activity'),
          icon: Icons.history_outlined,
          bodyBuilder: (_) => EntityActivityTab(
            vm: activityVm,
            formatter: formatter,
            actions: notes,
            hostWireName: 'client',
          ),
        ),
        if (me?.moduleEnabled(EntityType.invoice) ?? false)
          EntityDetailTab(
            label: context.tr('invoices'),
            icon: Icons.receipt_long_outlined,
            bodyBuilder: (_) =>
                InvoiceListScreen(clientId: clientId, embedded: true),
          ),
        if (me?.moduleEnabled(EntityType.quote) ?? false)
          EntityDetailTab(
            label: context.tr('quotes'),
            icon: Icons.request_quote_outlined,
            bodyBuilder: (_) =>
                QuoteListScreen(clientId: clientId, embedded: true),
          ),
        if (me?.moduleEnabled(EntityType.payment) ?? false)
          EntityDetailTab(
            label: context.tr('payments'),
            icon: Icons.payments_outlined,
            bodyBuilder: (_) =>
                PaymentListScreen(clientId: clientId, embedded: true),
          ),
        if (me?.moduleEnabled(EntityType.recurringInvoice) ?? false)
          EntityDetailTab(
            label: context.tr('recurring_invoices'),
            icon: Icons.autorenew,
            bodyBuilder: (_) =>
                RecurringInvoiceListScreen(clientId: clientId, embedded: true),
          ),
        if (me?.moduleEnabled(EntityType.credit) ?? false)
          EntityDetailTab(
            label: context.tr('credits'),
            icon: Icons.credit_card_outlined,
            bodyBuilder: (_) =>
                CreditListScreen(clientId: clientId, embedded: true),
          ),
        if (me?.moduleEnabled(EntityType.project) ?? false)
          EntityDetailTab(
            label: context.tr('projects'),
            icon: Icons.folder_outlined,
            bodyBuilder: (_) =>
                ProjectListScreen(clientId: clientId, embedded: true),
          ),
        if (me?.moduleEnabled(EntityType.task) ?? false)
          EntityDetailTab(
            label: context.tr('tasks'),
            icon: Icons.check_circle_outline,
            bodyBuilder: (_) =>
                TaskListScreen(clientId: clientId, embedded: true),
          ),
        if (me?.moduleEnabled(EntityType.expense) ?? false)
          EntityDetailTab(
            label: context.tr('expenses'),
            icon: Icons.account_balance_wallet_outlined,
            bodyBuilder: (_) =>
                ExpenseListScreen(clientId: clientId, embedded: true),
          ),
        EntityDetailTab(
          label: context.tr('ledger'),
          icon: Icons.account_balance_outlined,
          bodyBuilder: (_) => LedgerTab(
            scope: LedgerScope.client,
            companyId: companyId,
            entityId: clientId,
            formatter: formatter,
            summaryBalance: client.balance,
            summaryPaidToDate: client.paidToDate,
            summaryCreditBalance: client.creditBalance,
            openingAt: client.createdAt,
          ),
        ),
        EntityDetailTab(
          label: context.tr('locations'),
          icon: Icons.place_outlined,
          bodyBuilder: (_) => ClientLocationsTab(client: client),
        ),
        buildStandardDocumentsTab(
          context: context,
          companyId: companyId,
          entityId: client.id,
          documents: client.documents,
          repo: services.clients,
          formatter: formatter,
        ),
        EntityDetailTab(
          label: context.tr('email_history'),
          icon: Icons.outgoing_mail,
          bodyBuilder: (_) =>
              ClientEmailHistoryTab(client: client, formatter: formatter),
        ),
        // System Logs (gateway/email/webhook events scoped to this client) —
        // admin/owner only, matching the endpoint's 403 gate.
        if (me?.isAdmin == true || me?.isOwner == true)
          EntityDetailTab(
            label: context.tr('system_logs'),
            icon: Icons.terminal_outlined,
            bodyBuilder: (_) => ClientSystemLogsTab(client: client),
          ),
      ],
    );
  }
}
