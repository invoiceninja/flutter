import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/credit.dart';
import 'package:admin/data/models/domain/credit_status.dart';
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
import 'package:admin/ui/core/widgets/client_name_label.dart';
import 'package:admin/ui/core/widgets/formatter_host_mixin.dart';
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
import 'package:admin/ui/features/credits/view_models/credit_detail_view_model.dart';
import 'package:admin/ui/features/credits/widgets/credit_actions.dart';
import 'package:admin/ui/features/credits/widgets/credit_status_pill.dart';
import 'package:admin/utils/formatting.dart';

/// The credit record screen, on the record layout
/// (`docs/detail-screen-layout.md`). Everything the five billing documents
/// have in common lives in `billing_shared/detail/`; what is here is the
/// wiring several lints pin to this file.
class CreditDetailScreen extends StatefulWidget {
  const CreditDetailScreen({required this.id, super.key});
  final String id;

  @override
  State<CreditDetailScreen> createState() => _CreditDetailScreenState();
}

class _CreditDetailScreenState extends State<CreditDetailScreen>
    with FormatterHostMixin {
  late final CreditDetailViewModel _vm;
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
    _vm = CreditDetailViewModel.bound(
      _services.credits.watch(companyId: _companyId, id: widget.id),
    );
    // Owned here, not by the Activity tab, so the Comments card, the
    // Comments tab and the Activity tab share one fetch. Armed from
    // `bodyBuilder`.
    _activityVm = EntityActivityViewModel(
      api: _services.activities,
      outbox: _services.db.outboxDao,
      companyId: _companyId,
      entityWireName: 'credit',
      entityId: widget.id,
    );
    _record = RecordScreenController(
      services: _services,
      companyId: _companyId,
      routeId: widget.id,
      entityWireName: 'credit',
      refreshRecord: (id) =>
          _services.credits.refreshByIds(companyId: _companyId, ids: [id]),
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

  void _dispatch(Credit credit, CreditAction action) =>
      CreditActions.dispatch(context, _services, _companyId, credit, action);

  @override
  Widget build(BuildContext context) {
    return EntityDetailScaffold<Credit>(
      id: widget.id,
      vm: _vm,
      hydrate: () =>
          _services.credits.ensureLoaded(companyId: _companyId, id: widget.id),
      emptyAction: entityListEmptyAction(context, EntityType.credit),
      emptyIcon: Icons.assignment_return_outlined,
      emptyTitle: context.tr('credit_not_found'),
      // The company's e-invoice type gates Validate (a cheap local watch),
      // the same way the invoice detail resolves it.
      actionsForItem: (context, credit) => WatchBuilder<Company?>(
        cacheKey: _companyId,
        create: () => _services.company.watchCompany(_companyId),
        builder: (context, companySnap) => EntityDetailActionsRow<CreditAction>(
          items: CreditActions.itemsFor(
            context,
            credit,
            (a) => _dispatch(credit, a),
            eInvoiceType: companySnap.data?.settings.eInvoiceType,
          ),
        ),
      ),
      // What is left of it: the figure a credit is opened to check.
      compactTitleForItem: (context, credit) => BillingDocCompactTitle(
        type: BillingDocType.credit,
        doc: credit,
        figure: credit.balance,
        formatter: formatter,
      ),
      // A deleted credit is read-only until restored.
      isReadOnly: (credit) => credit.isDeleted,
      onRefresh: _record.refresh,
      bannerForItem: (context, credit) => recordStateBanner<CreditAction>(
        context,
        items: CreditActions.itemsFor(
          context,
          credit,
          (a) => _dispatch(credit, a),
        ),
        restoreKind: CreditAction.restore,
        entityId: credit.id,
        isDeleted: credit.isDeleted,
        archivedAt: credit.archivedAt,
        formatter: formatter,
      ),
      bodyBuilder: (context, credit) => _body(context, credit),
    );
  }

  Widget _body(BuildContext context, Credit credit) {
    _activityVm.kick();
    _record.attach(recordId: credit.id, revision: credit.updatedAt);
    Future<void> submit(String text) => _services.credits.addComment(
      companyId: _companyId,
      entityId: credit.id,
      text: text,
    );
    // Built once here, not in `initState` (`promptLogCallFor` needs a subject
    // off the resolved record) and not twice (the card and the tabs must not
    // each hold their own copy — see `EntityNoteActions`). A deleted credit
    // takes no new notes: the feed stays readable, its buttons go.
    final notes = credit.isDeleted
        ? EntityNoteActions.none
        : EntityNoteActions(
            onAddComment: () => promptAddCommentFor(
              context,
              entityId: credit.id,
              submit: submit,
            ),
            onLogCall: () => promptLogCallFor(
              context,
              companyId: _companyId,
              entityId: credit.id,
              subject: billingDocSubject(credit),
              clientId: credit.clientId,
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
          credit: credit,
          selectedVersion: _selectedVersion,
          formatter: formatter,
        ),
        top: (context, hasPdfPane) => _top(
          context,
          credit,
          notes,
          companySnap.data,
          hasPdfPane: hasPdfPane,
        ),
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
                hostWireName: 'credit',
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
                hostWireName: 'credit',
                reveal: _revealActivity,
              ),
            ),
            EntityDetailTab(
              id: DetailTabIds.overview,
              label: context.tr('overview'),
              icon: Icons.dashboard_outlined,
              bodyBuilder: (_) => BillingDocOverviewOf(
                type: BillingDocType.credit,
                doc: credit,
                formatter: formatter,
                paidToDate: credit.paidToDate,
                showBalance: true,
              ),
            ),
            buildDocumentHistoryTab(
              context: context,
              services: _services,
              companyId: _companyId,
              basePath: _services.credits.api.basePath,
              entityId: credit.id,
              currentAmount: credit.amount,
              currentUpdatedAt: credit.updatedAt,
              formatter: formatter,
              clientId: credit.clientId,
              selection: _selectedVersion,
              // Only the pane is ever "showing" a version; without one a tap
              // navigates, so nothing is selected.
              showSelection: hasPdfPane,
              onOpenVersion: billingDocVersionOpener(
                context,
                type: BillingDocType.credit,
                docId: credit.id,
                hasPdfPane: hasPdfPane,
                selection: _selectedVersion,
              ),
            ),
            buildBillingDocumentsTab(
              context: context,
              companyId: _companyId,
              doc: credit,
              formatter: formatter,
              upload: _services.credits.uploadDocument,
              delete: _services.credits.deleteDocument,
              setVisibility: _services.credits.setDocumentVisibility,
            ),
            EntityDetailTab(
              id: DetailTabIds.emailHistory,
              label: context.tr('email_history'),
              icon: Icons.outgoing_mail,
              bodyBuilder: (_) => BillingDocSendsTab(
                services: _services,
                companyId: _companyId,
                entityWireName: 'credit',
                entityId: credit.id,
                invitations: credit.invitations,
                isDirty: credit.isDirty,
                clientId: credit.clientId,
                isHosted: _services.auth.session.value?.isHosted ?? false,
                onReactivate: (messageId) =>
                    _services.credits.reactivateInvitationEmail(
                      companyId: _companyId,
                      id: credit.id,
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
    Credit credit,
    EntityNoteActions notes,
    Company? company, {
    required bool hasPdfPane,
  }) {
    return EntityRecordColumn(
      header: BillingDocRecordHeader(
        type: BillingDocType.credit,
        doc: credit,
        formatter: formatter,
        statusPill: ViewedStatusPillLink(
          isViewed: credit.calculatedStatusId == CreditStatusComputed.viewed,
          invitations: credit.invitations,
          entityWireName: 'credit',
          companyId: _companyId,
          clients: _services.clients,
          vendors: _services.vendors,
          clientId: credit.clientId,
          selectTab: _record.selectTab,
          reveal: _revealActivity,
          formatter: formatter,
          builder: (context, tooltip, semanticsLabel, onTap) =>
              CreditStatusPill(
                statusId: credit.calculatedStatusId,
                hasBounce: credit.hasBouncedInvitation,
                tooltip: tooltip,
                onTap: onTap,
                semanticsLabel: semanticsLabel,
                semanticsHint: onTap == null ? null : context.tr('activity'),
              ),
        ),
        party: ClientNameLabel(
          clientId: credit.clientId,
          link: true,
          style: BillingDocRecordHeader.partyStyle(context),
        ),
      ),
      quickActions: EntityQuickActions<CreditAction>(
        priority: CreditActions.quickItemsFor(
          context,
          credit,
          (a) => _dispatch(credit, a),
          hasPdfPane: hasPdfPane,
        ),
      ),
      standing: BillingDocStanding(
        type: BillingDocType.credit,
        doc: credit,
        formatter: formatter,
        // What has been applied — the credit's "paid".
        settled: credit.paidToDate,
      ),
      comments: EntityCommentsCard(
        vm: _activityVm,
        formatter: formatter,
        actions: notes,
        hostWireName: 'credit',
        onViewAll: () => _record.selectTab.select(kCommentsTabIndex),
        matchFormColumn: true,
      ),
      profile: BillingDocPartyContacts(
        companyId: _companyId,
        type: BillingDocType.credit,
        doc: credit,
        builder: (context, contacts) => BillingDocProfile(
          type: BillingDocType.credit,
          doc: credit,
          company: company,
          contacts: contacts,
          formatter: formatter,
          detailRows: [
            if (credit.projectId.isNotEmpty)
              billingDocLabelRow(
                context,
                'project',
                ProjectNameLabel(
                  projectId: credit.projectId,
                  link: true,
                  style: BillingDocDetailsCard.valueStyle(context),
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
    required this.credit,
    required this.selectedVersion,
    this.formatter,
  });
  final Credit credit;
  final ValueNotifier<String?> selectedVersion;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    return VersionedPdfPane(
      entity: BillingDocType.credit,
      entityNumber: credit.number,
      selection: selectedVersion,
      api: services.documentVersions,
      basePath: services.credits.api.basePath,
      entityId: credit.id,
      formatter: formatter,
      liveFetcher: ({String? designId, required bool deliveryNote}) =>
          services.credits.api.downloadPdf(
            entityJson: credit.toApiJson(),
            designId:
                designId ?? (credit.designId.isEmpty ? null : credit.designId),
          ),
    );
  }
}
