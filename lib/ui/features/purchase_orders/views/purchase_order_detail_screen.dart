import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/purchase_order.dart';
import 'package:admin/data/models/domain/purchase_order_status.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/activity_note_actions.dart';
import 'package:admin/ui/core/detail/activity_note_buttons.dart';
import 'package:admin/ui/core/detail/activity_reveal_controller.dart';
import 'package:admin/ui/core/detail/detail_tab_indices.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/detail/entity_detail_scaffold.dart';
import 'package:admin/ui/core/detail/entity_detail_tabs.dart';
import 'package:admin/ui/core/detail/entity_list_empty_action.dart';
import 'package:admin/ui/core/detail/entity_quick_actions.dart';
import 'package:admin/ui/core/detail/entity_record_column.dart';
import 'package:admin/ui/core/detail/entity_state_banner.dart';
import 'package:admin/ui/core/detail/record_screen_controller.dart';
import 'package:admin/ui/core/widgets/detail_info_row.dart';
import 'package:admin/ui/core/widgets/expense_name_label.dart';
import 'package:admin/ui/core/widgets/formatter_host_mixin.dart';
import 'package:admin/ui/core/widgets/invoice_name_label.dart';
import 'package:admin/ui/core/widgets/vendor_name_label.dart';
import 'package:admin/ui/core/widgets/watch_builder.dart';
import 'package:admin/ui/features/billing_shared/activity/entity_activity_tab.dart';
import 'package:admin/ui/features/billing_shared/activity/entity_activity_view_model.dart';
import 'package:admin/ui/features/billing_shared/activity/entity_comments_card.dart';
import 'package:admin/ui/features/billing_shared/billing_doc_overview.dart';
import 'package:admin/ui/features/billing_shared/billing_doc_type.dart';
import 'package:admin/ui/features/billing_shared/detail/billing_doc_documents_tab.dart';
import 'package:admin/ui/features/billing_shared/detail/billing_doc_profile.dart';
import 'package:admin/ui/features/billing_shared/detail/billing_doc_record_body.dart';
import 'package:admin/ui/features/billing_shared/detail/billing_doc_record_header.dart';
import 'package:admin/ui/features/billing_shared/detail/billing_doc_standing.dart';
import 'package:admin/ui/features/billing_shared/history/build_document_history_tab.dart';
import 'package:admin/ui/features/billing_shared/history/versioned_pdf_pane.dart';
import 'package:admin/ui/features/billing_shared/sends/billing_doc_sends_tab.dart';
import 'package:admin/ui/features/billing_shared/viewed_status_pill_link.dart';
import 'package:admin/ui/features/projects/widgets/project_name_label.dart';
import 'package:admin/ui/features/purchase_orders/view_models/purchase_order_detail_view_model.dart';
import 'package:admin/ui/features/purchase_orders/widgets/purchase_order_actions.dart';
import 'package:admin/ui/features/purchase_orders/widgets/purchase_order_status_pill.dart';
import 'package:admin/utils/formatting.dart';

/// The purchase order record screen, on the record layout
/// (`docs/detail-screen-layout.md`). Everything the five billing documents
/// have in common lives in `billing_shared/detail/`; what is here is what
/// only a purchase order has — the vendor as its party, and the records it
/// came from and became — and the wiring several lints pin to this file.
class PurchaseOrderDetailScreen extends StatefulWidget {
  const PurchaseOrderDetailScreen({required this.id, super.key});
  final String id;

  @override
  State<PurchaseOrderDetailScreen> createState() =>
      _PurchaseOrderDetailScreenState();
}

class _PurchaseOrderDetailScreenState extends State<PurchaseOrderDetailScreen>
    with FormatterHostMixin {
  late final PurchaseOrderDetailViewModel _vm;
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
    _vm = PurchaseOrderDetailViewModel.bound(
      _services.purchaseOrders.watch(companyId: _companyId, id: widget.id),
    );
    // Owned here, not by the Activity tab, so the Comments card, the
    // Comments tab and the Activity tab share one fetch. Armed from
    // `bodyBuilder`.
    _activityVm = EntityActivityViewModel(
      api: _services.activities,
      outbox: _services.db.outboxDao,
      companyId: _companyId,
      entityWireName: 'purchase_order',
      entityId: widget.id,
    );
    _record = RecordScreenController(
      services: _services,
      companyId: _companyId,
      routeId: widget.id,
      entityWireName: 'purchase_order',
      refreshRecord: (id) => _services.purchaseOrders.refreshByIds(
        companyId: _companyId,
        ids: [id],
      ),
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

  void _dispatch(PurchaseOrder po, PurchaseOrderAction action) =>
      PurchaseOrderActions.dispatch(context, _services, _companyId, po, action);

  @override
  Widget build(BuildContext context) {
    return EntityDetailScaffold<PurchaseOrder>(
      id: widget.id,
      vm: _vm,
      hydrate: () => _services.purchaseOrders.ensureLoaded(
        companyId: _companyId,
        id: widget.id,
      ),
      emptyAction: entityListEmptyAction(context, EntityType.purchaseOrder),
      emptyIcon: Icons.shopping_bag_outlined,
      emptyTitle: context.tr('purchase_order_not_found'),
      actionsForItem: (context, po) => WatchBuilder<Company?>(
        // Cheap local Drift watch — the e-PO download gate needs the
        // company's e-invoice type (mirrors the invoice screen).
        // WatchBuilder, not StreamBuilder: `watchCompany` returns a fresh
        // stream per call, so building it inline would re-subscribe on every
        // rebuild and blank the action row for a frame each time.
        cacheKey: _companyId,
        create: () => _services.company.watchCompany(_companyId),
        builder: (context, companySnap) =>
            EntityDetailActionsRow<PurchaseOrderAction>(
              items: PurchaseOrderActions.itemsFor(
                context,
                po,
                (a) => _dispatch(po, a),
                eInvoiceType: companySnap.data?.settings.eInvoiceType,
              ),
            ),
      ),
      compactTitleForItem: (context, po) => BillingDocCompactTitle(
        type: BillingDocType.purchaseOrder,
        doc: po,
        figure: po.amount,
        formatter: formatter,
      ),
      // A deleted purchase order is read-only until restored.
      isReadOnly: (po) => po.isDeleted,
      onRefresh: _record.refresh,
      bannerForItem: (context, po) => recordStateBanner<PurchaseOrderAction>(
        context,
        items: PurchaseOrderActions.itemsFor(
          context,
          po,
          (a) => _dispatch(po, a),
        ),
        restoreKind: PurchaseOrderAction.restore,
        entityId: po.id,
        isDeleted: po.isDeleted,
        archivedAt: po.archivedAt,
        formatter: formatter,
      ),
      bodyBuilder: (context, po) => _body(context, po),
    );
  }

  Widget _body(BuildContext context, PurchaseOrder po) {
    _activityVm.kick();
    _record.attach(recordId: po.id, revision: po.updatedAt);
    Future<void> submit(String text) => _services.purchaseOrders.addComment(
      companyId: _companyId,
      entityId: po.id,
      text: text,
    );
    // Built once here, not in `initState` (`promptLogCallFor` needs a subject
    // off the resolved record) and not twice (the card and the tabs must not
    // each hold their own copy — see `EntityNoteActions`). A deleted order
    // takes no new notes: the feed stays readable, its buttons go.
    final notes = po.isDeleted
        ? EntityNoteActions.none
        : EntityNoteActions(
            onAddComment: () =>
                promptAddCommentFor(context, entityId: po.id, submit: submit),
            onLogCall: () => promptLogCallFor(
              context,
              companyId: _companyId,
              entityId: po.id,
              subject: billingDocSubject(po),
              // Both: the vendor wins when set, and a purchase order's
              // `clientId` is genuinely populated on a client-facing one.
              vendorId: po.vendorId,
              clientId: po.clientId,
              submit: submit,
            ),
          );
    return WatchBuilder<Company?>(
      cacheKey: _companyId,
      // Seeded, so the profile's custom fields do not arrive a frame late and
      // push the tabs down.
      initialData: _services.company.peek(
        companyId: _companyId,
        id: _companyId,
      ),
      create: () => _services.company.watchCompany(_companyId),
      builder: (context, companySnap) => BillingDocRecordBody(
        record: _record,
        pdfPane: (context) => _PdfPane(
          purchaseOrder: po,
          selectedVersion: _selectedVersion,
          formatter: formatter,
        ),
        top: (context, hasPdfPane) =>
            _top(context, po, notes, companySnap.data, hasPdfPane: hasPdfPane),
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
                hostWireName: 'purchase_order',
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
                hostWireName: 'purchase_order',
                reveal: _revealActivity,
              ),
            ),
            EntityDetailTab(
              id: DetailTabIds.overview,
              label: context.tr('overview'),
              icon: Icons.dashboard_outlined,
              // What is being ordered. This tab used to hold tags and notes
              // only — a purchase order's line items could not be read
              // without opening it for editing.
              bodyBuilder: (_) => BillingDocOverviewOf(
                type: BillingDocType.purchaseOrder,
                doc: po,
                formatter: formatter,
              ),
            ),
            buildDocumentHistoryTab(
              context: context,
              services: _services,
              companyId: _companyId,
              basePath: _services.purchaseOrders.api.basePath,
              entityId: po.id,
              currentAmount: po.amount,
              currentUpdatedAt: po.updatedAt,
              formatter: formatter,
              vendorId: po.vendorId,
              selection: _selectedVersion,
              // Only the pane is ever "showing" a version; without one a tap
              // navigates, so nothing is selected.
              showSelection: hasPdfPane,
              onOpenVersion: billingDocVersionOpener(
                context,
                type: BillingDocType.purchaseOrder,
                docId: po.id,
                hasPdfPane: hasPdfPane,
                selection: _selectedVersion,
              ),
            ),
            buildBillingDocumentsTab(
              context: context,
              companyId: _companyId,
              doc: po,
              formatter: formatter,
              upload: _services.purchaseOrders.uploadDocument,
              delete: _services.purchaseOrders.deleteDocument,
              setVisibility: _services.purchaseOrders.setDocumentVisibility,
            ),
            EntityDetailTab(
              id: DetailTabIds.emailHistory,
              label: context.tr('email_history'),
              icon: Icons.outgoing_mail,
              bodyBuilder: (_) => BillingDocSendsTab(
                services: _services,
                companyId: _companyId,
                entityWireName: 'purchase_order',
                entityId: po.id,
                invitations: po.invitations,
                isDirty: po.isDirty,
                vendorId: po.vendorId,
                isHosted: _services.auth.session.value?.isHosted ?? false,
                onReactivate: (messageId) =>
                    _services.purchaseOrders.reactivateInvitationEmail(
                      companyId: _companyId,
                      id: po.id,
                      messageId: messageId,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Everything above the tabs.
  Widget _top(
    BuildContext context,
    PurchaseOrder po,
    EntityNoteActions notes,
    Company? company, {
    required bool hasPdfPane,
  }) {
    final valueStyle = BillingDocDetailsCard.valueStyle(context);
    return EntityRecordColumn(
      header: BillingDocRecordHeader(
        type: BillingDocType.purchaseOrder,
        doc: po,
        formatter: formatter,
        statusPill: ViewedStatusPillLink(
          isViewed: po.calculatedStatusId == PurchaseOrderStatusComputed.viewed,
          invitations: po.invitations,
          entityWireName: 'purchase_order',
          companyId: _companyId,
          clients: _services.clients,
          vendors: _services.vendors,
          vendorId: po.vendorId,
          selectTab: _record.selectTab,
          reveal: _revealActivity,
          formatter: formatter,
          builder: (context, tooltip, semanticsLabel, onTap) =>
              PurchaseOrderStatusPill(
                statusId: po.calculatedStatusId,
                hasBounce: po.hasBouncedInvitation,
                tooltip: tooltip,
                onTap: onTap,
                semanticsLabel: semanticsLabel,
                semanticsHint: onTap == null ? null : context.tr('activity'),
              ),
        ),
        party: VendorNameLabel(
          vendorId: po.vendorId,
          link: true,
          style: BillingDocRecordHeader.partyStyle(context),
        ),
      ),
      quickActions: EntityQuickActions<PurchaseOrderAction>(
        priority: PurchaseOrderActions.quickItemsFor(
          context,
          po,
          (a) => _dispatch(po, a),
          hasPdfPane: hasPdfPane,
        ),
      ),
      standing: BillingDocStanding(
        type: BillingDocType.purchaseOrder,
        doc: po,
        formatter: formatter,
      ),
      comments: EntityCommentsCard(
        vm: _activityVm,
        formatter: formatter,
        actions: notes,
        hostWireName: 'purchase_order',
        onViewAll: () => _record.selectTab.select(kCommentsTabIndex),
        matchFormColumn: true,
      ),
      profile: BillingDocPartyContacts(
        companyId: _companyId,
        type: BillingDocType.purchaseOrder,
        doc: po,
        builder: (context, contacts) => BillingDocProfile(
          type: BillingDocType.purchaseOrder,
          doc: po,
          company: company,
          contacts: contacts,
          formatter: formatter,
          detailRows: [
            // The expense this order became…
            if (po.expenseId.isNotEmpty)
              billingDocLabelRow(
                context,
                'expense',
                ExpenseNameLabel(
                  expenseId: po.expenseId,
                  link: true,
                  style: valueStyle,
                ),
              ),
            // …the invoice it was produced from by the server's 2026-09-05
            // `clone_to_purchase_order` action, so the user can get back to
            // it…
            if (po.invoiceId.isNotEmpty)
              billingDocLabelRow(
                context,
                'invoice',
                InvoiceNameLabel(
                  invoiceId: po.invoiceId,
                  link: true,
                  style: valueStyle,
                ),
              ),
            // …or the quote it was converted from (React #3370). There is no
            // quote name label, so this one names the action; `view_quote` is
            // placeholder-free.
            if (po.quoteId.isNotEmpty)
              DetailInfoRow(
                label: context.tr('quote'),
                value: context.tr('view_quote'),
                copyable: false,
                onTap: () => goEntityFullDetail(context, '/quotes', po.quoteId),
              ),
            if (po.projectId.isNotEmpty)
              billingDocLabelRow(
                context,
                'project',
                ProjectNameLabel(
                  projectId: po.projectId,
                  link: true,
                  style: valueStyle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PdfPane extends StatelessWidget {
  const _PdfPane({
    required this.purchaseOrder,
    required this.selectedVersion,
    this.formatter,
  });
  final PurchaseOrder purchaseOrder;
  final ValueNotifier<String?> selectedVersion;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    return VersionedPdfPane(
      entity: BillingDocType.purchaseOrder,
      entityNumber: purchaseOrder.number,
      selection: selectedVersion,
      api: services.documentVersions,
      basePath: services.purchaseOrders.api.basePath,
      entityId: purchaseOrder.id,
      formatter: formatter,
      liveFetcher: ({String? designId, required bool deliveryNote}) =>
          services.purchaseOrders.api.downloadPdf(
            entityJson: purchaseOrder.toApiJson(),
            designId:
                designId ??
                (purchaseOrder.designId.isEmpty
                    ? null
                    : purchaseOrder.designId),
          ),
    );
  }
}
