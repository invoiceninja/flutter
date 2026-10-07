import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/detail_tab_indices.dart';
import 'package:admin/ui/core/detail/entity_detail_tabs.dart';
import 'package:admin/ui/core/detail/related_tab_counts.dart';
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
    this.layoutBuilder,
    this.onReveal,
    this.readOnly = false,
    this.counts,
    super.key,
  });

  /// How many records each related tab holds, when the server has said. Null
  /// (a host that does not count) and "not known yet" both draw no badge.
  final TabCounts? counts;

  /// The client is deleted. The tabs that write straight to it — Documents
  /// and Locations — list what is there and offer nothing else. (The related
  /// lists get the same news through `EmbeddedListParentScope`.)
  final bool readOnly;

  /// The related-record tabs this company's modules allow, by id.
  ///
  /// The one gate for both halves of the screen: [build] draws a tab only for
  /// an id in this set, and the standing card links a figure only to one. A
  /// figure with a chevron that opens nothing is what two copies of this list
  /// would eventually produce.
  static Set<String> relatedTabIds(bool Function(EntityType) moduleEnabled) => {
    if (moduleEnabled(EntityType.invoice)) DetailTabIds.invoices,
    if (moduleEnabled(EntityType.quote)) DetailTabIds.quotes,
    if (moduleEnabled(EntityType.payment)) DetailTabIds.payments,
    if (moduleEnabled(EntityType.recurringInvoice))
      DetailTabIds.recurringInvoices,
    if (moduleEnabled(EntityType.credit)) DetailTabIds.credits,
    if (moduleEnabled(EntityType.project)) DetailTabIds.projects,
    if (moduleEnabled(EntityType.task)) DetailTabIds.tasks,
    if (moduleEnabled(EntityType.expense)) DetailTabIds.expenses,
  };

  /// Passed straight to [EntityDetailTabs] — the record page uses these to pin
  /// the strip and to bring it into view. See there.
  final EntityDetailTabsLayoutBuilder? layoutBuilder;
  final VoidCallback? onReveal;

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
    final related = relatedTabIds((t) => me?.moduleEnabled(t) ?? false);
    final locationCount = client.locations.where((l) => !l.isDeleted).length;
    final counts = this.counts;
    if (counts == null) {
      return _tabs(context, companyId, clientId, related, locationCount);
    }
    // A count lands after the strip is on screen; only the strip's own
    // subtree needs to hear about it.
    return ListenableBuilder(
      listenable: counts,
      builder: (context, _) =>
          _tabs(context, companyId, clientId, related, locationCount),
    );
  }

  /// Keys an embedded list on the client's id.
  ///
  /// A list builds its view model once, with the id it was first given. A
  /// client opened while still `tmp_…` and synced with the screen open comes
  /// back through here with its server id — and without a key the list would
  /// keep asking about, and watching for, an id that no longer exists.
  static Widget _scoped(String clientId, Widget list) =>
      KeyedSubtree(key: ValueKey<String>(clientId), child: list);

  Widget _tabs(
    BuildContext context,
    String companyId,
    String clientId,
    Set<String> related,
    int locationCount,
  ) {
    final services = context.read<Services>();
    final me = services.auth.session.value?.currentCompany;
    return EntityDetailTabs(
      initialIndex: 2,
      selectTab: selectTab,
      layoutBuilder: layoutBuilder,
      onReveal: onReveal,
      tabs: [
        EntityDetailTab(
          id: DetailTabIds.comments,
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
          id: DetailTabIds.activity,
          label: context.tr('activity'),
          icon: Icons.history_outlined,
          bodyBuilder: (_) => EntityActivityTab(
            vm: activityVm,
            formatter: formatter,
            actions: notes,
            hostWireName: 'client',
          ),
        ),
        if (related.contains(DetailTabIds.invoices))
          EntityDetailTab(
            id: DetailTabIds.invoices,
            count: counts?.countFor(DetailTabIds.invoices),
            label: context.tr('invoices'),
            icon: Icons.receipt_long_outlined,
            bodyBuilder: (_) => _scoped(
              clientId,
              InvoiceListScreen(clientId: clientId, embedded: true),
            ),
          ),
        if (related.contains(DetailTabIds.quotes))
          EntityDetailTab(
            id: DetailTabIds.quotes,
            count: counts?.countFor(DetailTabIds.quotes),
            label: context.tr('quotes'),
            icon: Icons.request_quote_outlined,
            bodyBuilder: (_) => _scoped(
              clientId,
              QuoteListScreen(clientId: clientId, embedded: true),
            ),
          ),
        if (related.contains(DetailTabIds.payments))
          EntityDetailTab(
            id: DetailTabIds.payments,
            count: counts?.countFor(DetailTabIds.payments),
            label: context.tr('payments'),
            icon: Icons.payments_outlined,
            bodyBuilder: (_) => _scoped(
              clientId,
              PaymentListScreen(clientId: clientId, embedded: true),
            ),
          ),
        if (related.contains(DetailTabIds.recurringInvoices))
          EntityDetailTab(
            id: DetailTabIds.recurringInvoices,
            count: counts?.countFor(DetailTabIds.recurringInvoices),
            label: context.tr('recurring_invoices'),
            icon: Icons.autorenew,
            bodyBuilder: (_) => _scoped(
              clientId,
              RecurringInvoiceListScreen(clientId: clientId, embedded: true),
            ),
          ),
        if (related.contains(DetailTabIds.credits))
          EntityDetailTab(
            id: DetailTabIds.credits,
            count: counts?.countFor(DetailTabIds.credits),
            label: context.tr('credits'),
            icon: Icons.credit_card_outlined,
            bodyBuilder: (_) => _scoped(
              clientId,
              CreditListScreen(clientId: clientId, embedded: true),
            ),
          ),
        if (related.contains(DetailTabIds.projects))
          EntityDetailTab(
            id: DetailTabIds.projects,
            count: counts?.countFor(DetailTabIds.projects),
            label: context.tr('projects'),
            icon: Icons.folder_outlined,
            bodyBuilder: (_) => _scoped(
              clientId,
              ProjectListScreen(clientId: clientId, embedded: true),
            ),
          ),
        if (related.contains(DetailTabIds.tasks))
          EntityDetailTab(
            id: DetailTabIds.tasks,
            count: counts?.countFor(DetailTabIds.tasks),
            label: context.tr('tasks'),
            icon: Icons.check_circle_outline,
            bodyBuilder: (_) => _scoped(
              clientId,
              TaskListScreen(clientId: clientId, embedded: true),
            ),
          ),
        if (related.contains(DetailTabIds.expenses))
          EntityDetailTab(
            id: DetailTabIds.expenses,
            count: counts?.countFor(DetailTabIds.expenses),
            label: context.tr('expenses'),
            icon: Icons.account_balance_wallet_outlined,
            bodyBuilder: (_) => _scoped(
              clientId,
              ExpenseListScreen(clientId: clientId, embedded: true),
            ),
          ),
        EntityDetailTab(
          id: DetailTabIds.ledger,
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
          id: DetailTabIds.locations,
          // Exact: locations ride on the client's own payload.
          count: locationCount,
          label: context.tr('locations'),
          icon: Icons.place_outlined,
          bodyBuilder: (_) =>
              ClientLocationsTab(client: client, readOnly: readOnly),
        ),
        buildStandardDocumentsTab(
          context: context,
          companyId: companyId,
          entityId: client.id,
          documents: client.documents,
          repo: services.clients,
          formatter: formatter,
          readOnly: readOnly,
        ),
        EntityDetailTab(
          id: DetailTabIds.emailHistory,
          label: context.tr('email_history'),
          icon: Icons.outgoing_mail,
          bodyBuilder: (_) =>
              ClientEmailHistoryTab(client: client, formatter: formatter),
        ),
        // System Logs (gateway/email/webhook events scoped to this client) —
        // admin/owner only, matching the endpoint's 403 gate.
        if (me?.isAdmin == true || me?.isOwner == true)
          EntityDetailTab(
            id: DetailTabIds.systemLogs,
            label: context.tr('system_logs'),
            icon: Icons.terminal_outlined,
            bodyBuilder: (_) => ClientSystemLogsTab(client: client),
          ),
      ],
    );
  }
}
