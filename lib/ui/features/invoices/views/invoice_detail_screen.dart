import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/db/app_database.dart' show OutboxRow;
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/data/models/domain/invoice_status.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/quickbooks/quickbooks_invoice.dart';
import 'package:admin/domain/sync/mutation.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/activity_note_actions.dart';
import 'package:admin/ui/core/detail/activity_note_buttons.dart';
import 'package:admin/ui/core/detail/activity_reveal_controller.dart';
import 'package:admin/ui/core/detail/build_standard_documents_tab.dart';
import 'package:admin/ui/core/detail/detail_tab_indices.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/detail/entity_detail_scaffold.dart';
import 'package:admin/ui/core/detail/entity_detail_tabs.dart';
import 'package:admin/ui/core/detail/entity_list_empty_action.dart';
import 'package:admin/ui/core/detail/entity_quick_actions.dart';
import 'package:admin/ui/core/detail/entity_record_column.dart';
import 'package:admin/ui/core/detail/entity_state_banner.dart';
import 'package:admin/ui/core/detail/record_screen_controller.dart';
import 'package:admin/ui/core/widgets/client_name_label.dart';
import 'package:admin/ui/core/widgets/detail_info_row.dart';
import 'package:admin/ui/core/widgets/formatter_host_mixin.dart';
import 'package:admin/ui/core/widgets/formatter_scope.dart';
import 'package:admin/ui/core/widgets/watch_builder.dart';
import 'package:admin/ui/features/billing_shared/activity/entity_activity_tab.dart';
import 'package:admin/ui/features/billing_shared/activity/entity_activity_view_model.dart';
import 'package:admin/ui/features/billing_shared/activity/entity_comments_card.dart';
import 'package:admin/ui/features/billing_shared/billing_doc_overview.dart';
import 'package:admin/ui/features/billing_shared/billing_doc_type.dart';
import 'package:admin/ui/features/billing_shared/detail/billing_doc_due_note.dart';
import 'package:admin/ui/features/billing_shared/detail/billing_doc_profile.dart';
import 'package:admin/ui/features/billing_shared/detail/billing_doc_record_body.dart';
import 'package:admin/ui/features/billing_shared/detail/billing_doc_record_header.dart';
import 'package:admin/ui/features/billing_shared/detail/billing_doc_standing.dart';
import 'package:admin/ui/features/billing_shared/history/build_document_history_tab.dart';
import 'package:admin/ui/features/billing_shared/history/versioned_pdf_pane.dart';
import 'package:admin/ui/features/billing_shared/sends/billing_doc_sends_tab.dart';
import 'package:admin/ui/features/billing_shared/viewed_status_pill_link.dart';
import 'package:admin/ui/features/invoices/view_models/invoice_detail_view_model.dart';
import 'package:admin/ui/features/invoices/widgets/detail/invoice_applied_payments_section.dart';
import 'package:admin/ui/features/invoices/widgets/detail/invoice_lock_banner.dart';
import 'package:admin/ui/features/invoices/widgets/detail/invoice_payment_schedule_tab.dart';
import 'package:admin/ui/features/invoices/widgets/detail/invoice_quickbooks_tab.dart';
import 'package:admin/ui/features/invoices/widgets/detail/invoice_reminders_summary.dart';
import 'package:admin/ui/features/invoices/widgets/detail/invoice_unapplied_payments_section.dart';
import 'package:admin/ui/features/invoices/widgets/invoice_actions.dart';
import 'package:admin/ui/features/invoices/widgets/invoice_status_pill.dart';
import 'package:admin/ui/features/invoices/widgets/rectify_invoice.dart';
import 'package:admin/ui/features/projects/widgets/project_name_label.dart';
import 'package:admin/utils/formatting.dart';

/// The invoice record screen, on the record layout
/// (`docs/detail-screen-layout.md`): identity, quick actions, standing,
/// comments and the profile above a pinned tab strip — and, on a wide window,
/// the invoice's PDF beside all of it.
///
/// Everything the five billing documents have in common lives in
/// `billing_shared/detail/`; what is here is what only an invoice has (the
/// lock notice, its payments, reminders, the payment schedule, QuickBooks)
/// and the wiring several lints pin to this file.
class InvoiceDetailScreen extends StatefulWidget {
  const InvoiceDetailScreen({required this.id, super.key});
  final String id;

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

/// Tabs only an invoice has. Named so the strip can remember "the Payment
/// Schedule tab" across a visit to an invoice that does not have one.
const String _kUnappliedPaymentsTabId = 'unapplied_payments';
const String _kPaymentScheduleTabId = 'payment_schedule';
const String _kQuickbooksTabId = 'quickbooks';

/// Whether the invoice is still waiting on money — the only time its due date
/// says anything. The same four conditions `Invoice.isPastDueOn` applies
/// before it looks at the date, so the standing card's "Past Due" line and the
/// status pill above it cannot disagree.
bool invoiceAwaitsPayment(Invoice invoice) =>
    invoice.balance > Decimal.zero &&
    !invoice.isDraft &&
    !invoice.isPaid &&
    !invoice.isCancelled &&
    !invoice.isReversed;

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen>
    with FormatterHostMixin {
  late final InvoiceDetailViewModel _vm;
  late final Services _services;
  late final String _companyId;
  late final EntityActivityViewModel _activityVm;
  late final RecordScreenController _record;

  /// Carries "reveal the view activity" from the header's `Viewed` pill to the
  /// Activity tab, which is not mounted when the tap happens
  /// (invoiceninja/flutter#154).
  final ActivityRevealController _revealActivity = ActivityRevealController();

  /// Which saved version the wide layout's PDF pane is showing; null is the
  /// live document. Owned by the screen so the History tab and the pane stay
  /// in step — the narrow layout has no pane and routes instead.
  final ValueNotifier<String?> _selectedVersion = ValueNotifier<String?>(null);

  @override
  void initState() {
    super.initState();
    _services = context.read<Services>();
    _companyId = _services.auth.session.value!.currentCompanyId;
    _vm = InvoiceDetailViewModel.bound(
      _services.invoices.watch(companyId: _companyId, id: widget.id),
    );
    // Owned here, not by the Activity tab, so the Comments card, the
    // Comments tab and the Activity tab share one fetch. Armed from
    // `bodyBuilder`.
    _activityVm = EntityActivityViewModel(
      api: _services.activities,
      outbox: _services.db.outboxDao,
      companyId: _companyId,
      entityWireName: 'invoice',
      entityId: widget.id,
    );
    _record = RecordScreenController(
      services: _services,
      companyId: _companyId,
      routeId: widget.id,
      entityWireName: 'invoice',
      refreshRecord: (id) async {
        await _services.invoices.refreshByIds(companyId: _companyId, ids: [id]);
      },
      hasRecord: () => _vm.item != null,
      refreshWith: [_activityVm.refresh],
    );
    loadFormatter(_services, _companyId);
  }

  @override
  void dispose() {
    _record.dispose();
    _activityVm.dispose();
    _revealActivity.dispose();
    _selectedVersion.dispose();
    _vm.dispose();
    super.dispose();
  }

  void _dispatch(Invoice invoice, InvoiceAction action) =>
      InvoiceActions.dispatch(context, _services, _companyId, invoice, action);

  @override
  Widget build(BuildContext context) {
    return EntityDetailScaffold<Invoice>(
      id: widget.id,
      vm: _vm,
      hydrate: () =>
          _services.invoices.ensureLoaded(companyId: _companyId, id: widget.id),
      emptyAction: entityListEmptyAction(context, EntityType.invoice),
      emptyIcon: Icons.receipt_long_outlined,
      emptyTitle: context.tr('invoice_not_found'),
      actionsForItem: (context, invoice) => _InvoiceActionsRow(
        invoice: invoice,
        services: _services,
        companyId: _companyId,
      ),
      // What is still owed: the figure a user scrolling an invoice's history
      // most wants kept in sight.
      // In a pane or on a phone the bar gives its width to `Enter Payment`
      // first and the title what is left (`EntityDetailScaffold`).
      compactTitleForItem: (context, invoice) => BillingDocCompactTitle(
        type: BillingDocType.invoice,
        doc: invoice,
        figure: invoice.balance,
        formatter: formatter,
      ),
      // A deleted invoice is read-only until restored.
      isReadOnly: (invoice) => invoice.isDeleted,
      onRefresh: _record.refresh,
      bannerForItem: (context, invoice) => recordStateBanner<InvoiceAction>(
        context,
        items: InvoiceActions.itemsFor(
          context,
          invoice,
          (a) => _dispatch(invoice, a),
        ),
        restoreKind: InvoiceAction.restore,
        entityId: invoice.id,
        isDeleted: invoice.isDeleted,
        archivedAt: invoice.archivedAt,
        formatter: formatter,
      ),
      // Always mounted, even while `formatter` is still null: branching here
      // would change the tree shape and remount the whole body when the
      // formatter lands. `InvoiceRemindersSummary` reads the scope.
      bodyBuilder: (context, invoice) =>
          FormatterScope(formatter: formatter, child: _body(context, invoice)),
    );
  }

  Widget _body(BuildContext context, Invoice invoice) {
    _activityVm.kick();
    _record.attach(recordId: invoice.id, revision: invoice.updatedAt);
    Future<void> submit(String text) => _services.invoices.addComment(
      companyId: _companyId,
      entityId: invoice.id,
      text: text,
    );
    // Built once here, not in `initState` (`promptLogCallFor` needs a subject
    // off the resolved record) and not twice (the card and the tabs must not
    // each hold their own copy — see `EntityNoteActions`).
    //
    // A deleted invoice takes no new notes: the feed stays readable, its
    // buttons go.
    final notes = invoice.isDeleted
        ? EntityNoteActions.none
        : EntityNoteActions(
            onAddComment: () => promptAddCommentFor(
              context,
              entityId: invoice.id,
              submit: submit,
            ),
            onLogCall: () => promptLogCallFor(
              context,
              companyId: _companyId,
              entityId: invoice.id,
              subject: billingDocSubject(invoice),
              // Client only. `Invoice` declares a `vendorId` too — so do
              // Quote / Credit / RecurringInvoice / Payment, and it is a
              // real field with a shipped list column. It is just not the
              // right party here: a call logged against an invoice is a
              // call to whoever owes it. Vendor-first applies to expenses,
              // recurring expenses and purchase orders.
              clientId: invoice.clientId,
              submit: submit,
            ),
          );
    final me = _services.auth.session.value?.currentCompany;
    final canEdit = me?.can('edit_invoice') ?? false;
    final canView = canEdit || (me?.can('view_invoice') ?? false);
    return WatchBuilder<Company?>(
      cacheKey: _companyId,
      // Seeded: the QuickBooks tab hangs off this, and a first frame without
      // it would mount one tab fewer — and the profile's custom fields would
      // arrive a frame late and push the tabs down.
      initialData: _services.company.peek(
        companyId: _companyId,
        id: _companyId,
      ),
      create: () => _services.company.watchCompany(_companyId),
      builder: (context, companySnap) {
        final company = companySnap.data;
        return BillingDocRecordBody(
          record: _record,
          pdfPane: (context) => _PdfPane(
            invoice: invoice,
            selectedVersion: _selectedVersion,
            formatter: formatter,
          ),
          top: (context, hasPdfPane) =>
              _top(context, invoice, notes, company, hasPdfPane: hasPdfPane),
          tabs: (context, hasPdfPane, layout) => EntityDetailTabs(
            initialIndex: 2,
            selectTab: _record.selectTab,
            onReveal: _record.page.revealTabs,
            layoutBuilder: layout,
            tabs: [
              EntityDetailTab(
                id: DetailTabIds.comments,
                label: context.tr('comments'),
                icon: Icons.comment_outlined,
                bodyBuilder: (_) => EntityActivityTab(
                  vm: _activityVm,
                  formatter: formatter,
                  actions: notes,
                  commentsOnly: true,
                  hostWireName: 'invoice',
                ),
              ),
              EntityDetailTab(
                id: DetailTabIds.activity,
                label: context.tr('activity'),
                icon: Icons.history_outlined,
                bodyBuilder: (_) => EntityActivityTab(
                  vm: _activityVm,
                  formatter: formatter,
                  actions: notes,
                  hostWireName: 'invoice',
                  reveal: _revealActivity,
                ),
              ),
              EntityDetailTab(
                id: DetailTabIds.overview,
                label: context.tr('overview'),
                icon: Icons.dashboard_outlined,
                bodyBuilder: (_) => BillingDocOverviewOf(
                  type: BillingDocType.invoice,
                  doc: invoice,
                  formatter: formatter,
                  paidToDate: invoice.paidToDate,
                  showBalance: true,
                  trailing: (context, currencyId) => [
                    InvoiceAppliedPaymentsSection(
                      invoice: invoice,
                      services: _services,
                      companyId: _companyId,
                      formatter: formatter,
                      currencyId: currencyId,
                    ),
                    InvoiceRemindersSummary(invoice: invoice),
                  ],
                ),
              ),
              buildDocumentHistoryTab(
                context: context,
                services: _services,
                companyId: _companyId,
                basePath: _services.invoices.api.basePath,
                entityId: invoice.id,
                currentAmount: invoice.amount,
                currentUpdatedAt: invoice.updatedAt,
                formatter: formatter,
                clientId: invoice.clientId,
                selection: _selectedVersion,
                // Only the pane is ever "showing" a version; without one a
                // tap navigates, so nothing is selected.
                showSelection: hasPdfPane,
                onOpenVersion: billingDocVersionOpener(
                  context,
                  type: BillingDocType.invoice,
                  docId: invoice.id,
                  hasPdfPane: hasPdfPane,
                  selection: _selectedVersion,
                ),
              ),
              buildStandardDocumentsTab(
                context: context,
                companyId: _companyId,
                entityId: invoice.id,
                documents: invoice.documents,
                repo: _services.invoices,
                formatter: formatter,
                readOnly: invoice.isDeleted,
              ),
              EntityDetailTab(
                id: DetailTabIds.emailHistory,
                label: context.tr('email_history'),
                icon: Icons.outgoing_mail,
                bodyBuilder: (_) => BillingDocSendsTab(
                  services: _services,
                  companyId: _companyId,
                  entityWireName: 'invoice',
                  entityId: invoice.id,
                  invitations: invoice.invitations,
                  isDirty: invoice.isDirty,
                  clientId: invoice.clientId,
                  isHosted: _services.auth.session.value?.isHosted ?? false,
                  onReactivate: (messageId) =>
                      _services.invoices.reactivateInvitationEmail(
                        companyId: _companyId,
                        id: invoice.id,
                        messageId: messageId,
                      ),
                ),
              ),
              EntityDetailTab(
                id: _kUnappliedPaymentsTabId,
                label: context.tr('unapplied_payments'),
                icon: Icons.account_balance_wallet_outlined,
                bodyBuilder: (_) => InvoiceUnappliedPaymentsSection(
                  invoice: invoice,
                  services: _services,
                  companyId: _companyId,
                ),
              ),
              if (invoiceSupportsPaymentSchedule(
                invoice,
                canViewOrEdit: canView,
              ))
                EntityDetailTab(
                  id: _kPaymentScheduleTabId,
                  label: context.tr('payment_schedule'),
                  icon: Icons.event_repeat_outlined,
                  bodyBuilder: (_) =>
                      InvoicePaymentScheduleTab(invoice: invoice),
                ),
              // Last, so adding it never moves a tab the user is on
              // (invoiceninja/ui#3284). React gates it on a connection and on
              // being able to edit the invoice.
              if (quickbooksConnected(company?.quickbooks) && canEdit)
                EntityDetailTab(
                  id: _kQuickbooksTabId,
                  label: context.tr('quickbooks'),
                  icon: Icons.sync_alt_outlined,
                  bodyBuilder: (_) => InvoiceQuickbooksTab(
                    invoice: invoice,
                    services: _services,
                    companyId: _companyId,
                    quickbooks: company?.quickbooks,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Everything above the tabs.
  Widget _top(
    BuildContext context,
    Invoice invoice,
    EntityNoteActions notes,
    Company? company, {
    required bool hasPdfPane,
  }) {
    final today = Date.today();
    return EntityRecordColumn(
      header: BillingDocRecordHeader(
        type: BillingDocType.invoice,
        doc: invoice,
        formatter: formatter,
        // Unconditional on purpose: it collapses to nothing itself, so the
        // tree shape doesn't change when the reason resolves.
        banner: InvoiceLockBanner(invoice: invoice, companyId: _companyId),
        statusPill: ViewedStatusPillLink(
          isViewed: invoice.calculatedStatusId == InvoiceStatusComputed.viewed,
          invitations: invoice.invitations,
          entityWireName: 'invoice',
          companyId: _companyId,
          clients: _services.clients,
          vendors: _services.vendors,
          clientId: invoice.clientId,
          selectTab: _record.selectTab,
          reveal: _revealActivity,
          formatter: formatter,
          builder: (context, tooltip, semanticsLabel, onTap) =>
              InvoiceStatusPill(
                statusId: invoice.calculatedStatusId,
                hasBounce: invoice.hasBouncedInvitation,
                tooltip: tooltip,
                onTap: onTap,
                semanticsLabel: semanticsLabel,
                semanticsHint: onTap == null ? null : context.tr('activity'),
              ),
        ),
        party: ClientNameLabel(
          clientId: invoice.clientId,
          link: true,
          style: BillingDocRecordHeader.partyStyle(context),
        ),
      ),
      quickActions: EntityQuickActions<InvoiceAction>(
        priority: InvoiceActions.quickItemsFor(
          context,
          invoice,
          (a) => _dispatch(invoice, a),
          hasPdfPane: hasPdfPane,
        ),
      ),
      standing: BillingDocStanding(
        type: BillingDocType.invoice,
        doc: invoice,
        formatter: formatter,
        settled: invoice.paidToDate,
        dueNote: billingDocDueNote(
          due: billingDocEffectiveDue(BillingDocType.invoice, invoice),
          today: today,
          isOpen: invoiceAwaitsPayment(invoice),
        ),
      ),
      comments: EntityCommentsCard(
        vm: _activityVm,
        formatter: formatter,
        actions: notes,
        hostWireName: 'invoice',
        onViewAll: () => _record.selectTab.select(kCommentsTabIndex),
        matchFormColumn: true,
      ),
      profile: BillingDocPartyContacts(
        companyId: _companyId,
        type: BillingDocType.invoice,
        doc: invoice,
        builder: (context, contacts) => BillingDocProfile(
          type: BillingDocType.invoice,
          doc: invoice,
          company: company,
          contacts: contacts,
          formatter: formatter,
          detailRows: [
            // The recurring invoice that generated this one.
            if (invoice.recurringId.isNotEmpty)
              DetailInfoRow(
                label: context.tr('recurring_invoice'),
                value: context.tr('view'),
                copyable: false,
                onTap: () => goEntityFullDetail(
                  context,
                  '/recurring_invoices',
                  invoice.recurringId,
                ),
              ),
            if (invoice.projectId.isNotEmpty)
              billingDocLabelRow(
                context,
                'project',
                ProjectNameLabel(
                  projectId: invoice.projectId,
                  link: true,
                  style: BillingDocDetailsCard.valueStyle(context),
                ),
              ),
            if (invoice.autoBillEnabled)
              DetailInfoRow(
                label: context.tr('auto_bill'),
                value: context.tr('enabled'),
                copyable: false,
              ),
          ],
        ),
      ),
    );
  }
}

/// Invoice actions row. The Verifactu "rectify" action's visibility depends
/// on the invoice's client country + the company's `e_invoice_type` — async
/// inputs not available to the synchronous `itemsFor`. We pre-gate on the
/// cheap invoice-only subset ([rectifyPreGate]) and only subscribe the
/// client/company streams when that passes (the rare Verifactu case).
class _InvoiceActionsRow extends StatefulWidget {
  const _InvoiceActionsRow({
    required this.invoice,
    required this.services,
    required this.companyId,
  });

  final Invoice invoice;
  final Services services;
  final String companyId;

  @override
  State<_InvoiceActionsRow> createState() => _InvoiceActionsRowState();
}

class _InvoiceActionsRowState extends State<_InvoiceActionsRow> {
  /// Stable subscription — created once here, never inside `build()`. A fresh
  /// stream per build makes `StreamBuilder` retain its prior value across
  /// rebuild-induced re-subscribes; a fail-fast `sendEInvoice` failure and its
  /// shell modal are a rebuild burst that could otherwise drop the
  /// dead-excluded emission and leave the "Send E-Invoice" action
  /// stuck-suppressed. Mirrors the Sends-tab fix. `invoice.id` is stable for
  /// this screen, so capturing it once is safe.
  late final Stream<List<OutboxRow>> _sendEInvoicePending;

  @override
  void initState() {
    super.initState();
    _sendEInvoicePending = widget.services.db.outboxDao.watchPendingForEntity(
      companyId: widget.companyId,
      entityType: 'invoice',
      entityId: widget.invoice.id,
      kind: MutationKind.sendEInvoice,
    );
    _ensureClient();
  }

  @override
  void didUpdateWidget(_InvoiceActionsRow old) {
    super.didUpdateWidget(old);
    if (old.invoice.clientId != widget.invoice.clientId) _ensureClient();
  }

  /// The rectify gate needs the invoice's client in Drift (paginated lists
  /// prefetch only page 1). Mirror `ClientNameLabel._ensure`: deduped /
  /// negative-cached / safe to fire unconditionally. Only when the cheap
  /// pre-gate passes, so non-Verifactu invoice opens don't fetch the client.
  void _ensureClient() {
    final inv = widget.invoice;
    if (!rectifyPreGate(inv) || inv.clientId.isEmpty) return;
    widget.services.clients.ensureLoaded(
      companyId: widget.companyId,
      id: inv.clientId,
    );
  }

  Widget _row(
    BuildContext context,
    bool rectifyEligible,
    String? eInvoiceType,
    bool sendEInvoicePending,
  ) => EntityDetailActionsRow<InvoiceAction>(
    items: InvoiceActions.itemsFor(
      context,
      widget.invoice,
      (a) => InvoiceActions.dispatch(
        context,
        widget.services,
        widget.companyId,
        widget.invoice,
        a,
      ),
      rectifyEligible: rectifyEligible,
      eInvoiceType: eInvoiceType,
      sendEInvoicePending: sendEInvoicePending,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final inv = widget.invoice;
    // Pending `sendEInvoice` outbox row for this invoice → suppress the
    // Send action so the user can't double-enqueue a compliance
    // transmission (React uses a send cooldown). Reuses the same
    // per-entity/kind pending seam as the Activity tab.
    return StreamBuilder<List<OutboxRow>>(
      stream: _sendEInvoicePending,
      builder: (context, pendingSnap) {
        final sendPending = (pendingSnap.data ?? const []).isNotEmpty;
        // Always resolve the company's e-invoice type (cheap local Drift
        // watch) — the send/validate gate needs it for any e-invoiced
        // invoice, not just Verifactu. The client watch (for rectify) is
        // still only added when the cheap rectify pre-gate passes.
        return WatchBuilder<Company?>(
          cacheKey: widget.companyId,
          create: () => widget.services.company.watchCompany(widget.companyId),
          builder: (context, companySnap) {
            final eInvoiceType = companySnap.data?.settings.eInvoiceType;
            if (!rectifyPreGate(inv)) {
              return _row(context, false, eInvoiceType, sendPending);
            }
            return WatchBuilder<Client?>(
              cacheKey: (widget.companyId, inv.clientId),
              initialData: widget.services.clients.peek(
                companyId: widget.companyId,
                id: inv.clientId,
              ),
              create: () => widget.services.clients.watch(
                companyId: widget.companyId,
                id: inv.clientId,
              ),
              builder: (context, clientSnap) {
                final eligible = isRectifyEligible(
                  invoice: inv,
                  clientCountryId: clientSnap.data?.countryId,
                  eInvoiceType: eInvoiceType,
                );
                return _row(context, eligible, eInvoiceType, sendPending);
              },
            );
          },
        );
      },
    );
  }
}

class _PdfPane extends StatelessWidget {
  const _PdfPane({
    required this.invoice,
    required this.selectedVersion,
    this.formatter,
  });
  final Invoice invoice;
  final ValueNotifier<String?> selectedVersion;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    return VersionedPdfPane(
      entity: BillingDocType.invoice,
      entityNumber: invoice.number,
      selection: selectedVersion,
      api: services.documentVersions,
      basePath: services.invoices.api.basePath,
      entityId: invoice.id,
      formatter: formatter,
      liveFetcher: ({String? designId, required bool deliveryNote}) =>
          services.invoices.api.downloadPdf(
            entityJson: invoice.toApiJson(),
            designId:
                designId ??
                (invoice.designId.isEmpty ? null : invoice.designId),
            deliveryNote: deliveryNote,
          ),
    );
  }
}
