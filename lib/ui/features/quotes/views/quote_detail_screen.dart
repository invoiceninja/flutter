import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/quote.dart';
import 'package:admin/data/models/domain/quote_status.dart';
import 'package:admin/data/models/value/date.dart';
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
import 'package:admin/ui/core/widgets/invoice_name_label.dart';
import 'package:admin/ui/core/widgets/watch_builder.dart';
import 'package:admin/ui/features/billing_shared/activity/entity_activity_tab.dart';
import 'package:admin/ui/features/billing_shared/activity/entity_activity_view_model.dart';
import 'package:admin/ui/features/billing_shared/activity/entity_comments_card.dart';
import 'package:admin/ui/features/billing_shared/billing_doc_overview.dart';
import 'package:admin/ui/features/billing_shared/billing_doc_type.dart';
import 'package:admin/ui/features/billing_shared/detail/billing_doc_documents_tab.dart';
import 'package:admin/ui/features/billing_shared/detail/billing_doc_due_note.dart';
import 'package:admin/ui/features/billing_shared/detail/billing_doc_profile.dart';
import 'package:admin/ui/features/billing_shared/detail/billing_doc_record_body.dart';
import 'package:admin/ui/features/billing_shared/detail/billing_doc_record_header.dart';
import 'package:admin/ui/features/billing_shared/detail/billing_doc_standing.dart';
import 'package:admin/ui/features/billing_shared/history/build_document_history_tab.dart';
import 'package:admin/ui/features/billing_shared/history/versioned_pdf_pane.dart';
import 'package:admin/ui/features/billing_shared/sends/billing_doc_sends_tab.dart';
import 'package:admin/ui/features/billing_shared/viewed_status_pill_link.dart';
import 'package:admin/ui/features/projects/widgets/project_name_label.dart';
import 'package:admin/ui/features/quotes/view_models/quote_detail_view_model.dart';
import 'package:admin/ui/features/quotes/widgets/quote_actions.dart';
import 'package:admin/ui/features/quotes/widgets/quote_status_pill.dart';
import 'package:admin/utils/formatting.dart';

/// The quote record screen, on the record layout
/// (`docs/detail-screen-layout.md`). Everything the five billing documents
/// have in common lives in `billing_shared/detail/`; what is here is what
/// only a quote has — the invoice it became — and the wiring several lints
/// pin to this file.
class QuoteDetailScreen extends StatefulWidget {
  const QuoteDetailScreen({required this.id, super.key});
  final String id;

  @override
  State<QuoteDetailScreen> createState() => _QuoteDetailScreenState();
}

/// Whether the quote is still waiting on an answer — the only time its
/// valid-until date says anything. The same four terminal statuses
/// `Quote.isExpired` rules out before it looks at the date, so the standing
/// card's "Expired" line and the status pill above it cannot disagree.
bool quoteAwaitsAnswer(Quote quote) =>
    !quote.isConverted &&
    !quote.isApproved &&
    !quote.isRejected &&
    !quote.isCancelled;

class _QuoteDetailScreenState extends State<QuoteDetailScreen>
    with FormatterHostMixin {
  late final QuoteDetailViewModel _vm;
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
    _vm = QuoteDetailViewModel.bound(
      _services.quotes.watch(companyId: _companyId, id: widget.id),
    );
    // Owned here, not by the Activity tab, so the Comments card, the
    // Comments tab and the Activity tab share one fetch. Armed from
    // `bodyBuilder`.
    _activityVm = EntityActivityViewModel(
      api: _services.activities,
      outbox: _services.db.outboxDao,
      companyId: _companyId,
      entityWireName: 'quote',
      entityId: widget.id,
    );
    _record = RecordScreenController(
      services: _services,
      companyId: _companyId,
      routeId: widget.id,
      entityWireName: 'quote',
      refreshRecord: (id) =>
          _services.quotes.refreshByIds(companyId: _companyId, ids: [id]),
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

  void _dispatch(Quote quote, QuoteAction action) =>
      QuoteActions.dispatch(context, _services, _companyId, quote, action);

  @override
  Widget build(BuildContext context) {
    return EntityDetailScaffold<Quote>(
      id: widget.id,
      vm: _vm,
      hydrate: () =>
          _services.quotes.ensureLoaded(companyId: _companyId, id: widget.id),
      emptyAction: entityListEmptyAction(context, EntityType.quote),
      emptyIcon: Icons.request_quote_outlined,
      emptyTitle: context.tr('quote_not_found'),
      actionsForItem: (context, quote) => EntityDetailActionsRow<QuoteAction>(
        items: QuoteActions.itemsFor(
          context,
          quote,
          (a) => _dispatch(quote, a),
        ),
      ),
      compactTitleForItem: (context, quote) => BillingDocCompactTitle(
        type: BillingDocType.quote,
        doc: quote,
        figure: quote.amount,
        formatter: formatter,
      ),
      // A deleted quote is read-only until restored.
      isReadOnly: (quote) => quote.isDeleted,
      onRefresh: _record.refresh,
      bannerForItem: (context, quote) => recordStateBanner<QuoteAction>(
        context,
        items: QuoteActions.itemsFor(
          context,
          quote,
          (a) => _dispatch(quote, a),
        ),
        restoreKind: QuoteAction.restore,
        entityId: quote.id,
        isDeleted: quote.isDeleted,
        archivedAt: quote.archivedAt,
        formatter: formatter,
      ),
      bodyBuilder: (context, quote) => _body(context, quote),
    );
  }

  Widget _body(BuildContext context, Quote quote) {
    _activityVm.kick();
    _record.attach(recordId: quote.id, revision: quote.updatedAt);
    Future<void> submit(String text) => _services.quotes.addComment(
      companyId: _companyId,
      entityId: quote.id,
      text: text,
    );
    // Built once here, not in `initState` (`promptLogCallFor` needs a subject
    // off the resolved record) and not twice (the card and the tabs must not
    // each hold their own copy — see `EntityNoteActions`). A deleted quote
    // takes no new notes: the feed stays readable, its buttons go.
    final notes = quote.isDeleted
        ? EntityNoteActions.none
        : EntityNoteActions(
            onAddComment: () => promptAddCommentFor(
              context,
              entityId: quote.id,
              submit: submit,
            ),
            onLogCall: () => promptLogCallFor(
              context,
              companyId: _companyId,
              entityId: quote.id,
              subject: billingDocSubject(quote),
              clientId: quote.clientId,
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
          quote: quote,
          selectedVersion: _selectedVersion,
          formatter: formatter,
        ),
        top: (context, hasPdfPane) => _top(
          context,
          quote,
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
                hostWireName: 'quote',
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
                hostWireName: 'quote',
                reveal: _revealActivity,
              ),
            ),
            EntityDetailTab(
              id: DetailTabIds.overview,
              label: context.tr('overview'),
              icon: Icons.dashboard_outlined,
              bodyBuilder: (_) => BillingDocOverviewOf(
                type: BillingDocType.quote,
                doc: quote,
                formatter: formatter,
              ),
            ),
            buildDocumentHistoryTab(
              context: context,
              services: _services,
              companyId: _companyId,
              basePath: _services.quotes.api.basePath,
              entityId: quote.id,
              currentAmount: quote.amount,
              currentUpdatedAt: quote.updatedAt,
              formatter: formatter,
              clientId: quote.clientId,
              selection: _selectedVersion,
              // Only the pane is ever "showing" a version; without one a tap
              // navigates, so nothing is selected.
              showSelection: hasPdfPane,
              onOpenVersion: billingDocVersionOpener(
                context,
                type: BillingDocType.quote,
                docId: quote.id,
                hasPdfPane: hasPdfPane,
                selection: _selectedVersion,
              ),
            ),
            buildBillingDocumentsTab(
              context: context,
              companyId: _companyId,
              doc: quote,
              formatter: formatter,
              upload: _services.quotes.uploadDocument,
              delete: _services.quotes.deleteDocument,
              setVisibility: _services.quotes.setDocumentVisibility,
            ),
            EntityDetailTab(
              id: DetailTabIds.emailHistory,
              label: context.tr('email_history'),
              icon: Icons.outgoing_mail,
              bodyBuilder: (_) => BillingDocSendsTab(
                services: _services,
                companyId: _companyId,
                entityWireName: 'quote',
                entityId: quote.id,
                invitations: quote.invitations,
                isDirty: quote.isDirty,
                clientId: quote.clientId,
                isHosted: _services.auth.session.value?.isHosted ?? false,
                onReactivate: (messageId) =>
                    _services.quotes.reactivateInvitationEmail(
                      companyId: _companyId,
                      id: quote.id,
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
    Quote quote,
    EntityNoteActions notes,
    Company? company, {
    required bool hasPdfPane,
  }) {
    return EntityRecordColumn(
      header: BillingDocRecordHeader(
        type: BillingDocType.quote,
        doc: quote,
        formatter: formatter,
        statusPill: ViewedStatusPillLink(
          isViewed: quote.calculatedStatusId == QuoteStatusComputed.viewed,
          invitations: quote.invitations,
          entityWireName: 'quote',
          companyId: _companyId,
          clients: _services.clients,
          vendors: _services.vendors,
          clientId: quote.clientId,
          selectTab: _record.selectTab,
          reveal: _revealActivity,
          formatter: formatter,
          builder: (context, tooltip, semanticsLabel, onTap) => QuoteStatusPill(
            statusId: quote.calculatedStatusId,
            hasBounce: quote.hasBouncedInvitation,
            tooltip: tooltip,
            onTap: onTap,
            semanticsLabel: semanticsLabel,
            semanticsHint: onTap == null ? null : context.tr('activity'),
          ),
        ),
        party: ClientNameLabel(
          clientId: quote.clientId,
          link: true,
          style: BillingDocRecordHeader.partyStyle(context),
        ),
      ),
      quickActions: EntityQuickActions<QuoteAction>(
        priority: QuoteActions.quickItemsFor(
          context,
          quote,
          (a) => _dispatch(quote, a),
          hasPdfPane: hasPdfPane,
        ),
      ),
      standing: BillingDocStanding(
        type: BillingDocType.quote,
        doc: quote,
        formatter: formatter,
        dueNote: billingDocDueNote(
          due: billingDocEffectiveDue(BillingDocType.quote, quote),
          today: Date.today(),
          isOpen: quoteAwaitsAnswer(quote),
        ),
      ),
      comments: EntityCommentsCard(
        vm: _activityVm,
        formatter: formatter,
        actions: notes,
        hostWireName: 'quote',
        onViewAll: () => _record.selectTab.select(kCommentsTabIndex),
        matchFormColumn: true,
      ),
      profile: BillingDocPartyContacts(
        companyId: _companyId,
        type: BillingDocType.quote,
        doc: quote,
        builder: (context, contacts) => BillingDocProfile(
          type: BillingDocType.quote,
          doc: quote,
          company: company,
          contacts: contacts,
          formatter: formatter,
          detailRows: [
            // The invoice this quote became.
            if (quote.invoiceId.isNotEmpty)
              billingDocLabelRow(
                context,
                'invoice',
                InvoiceNameLabel(
                  invoiceId: quote.invoiceId,
                  link: true,
                  style: BillingDocDetailsCard.valueStyle(context),
                ),
              ),
            if (quote.projectId.isNotEmpty)
              billingDocLabelRow(
                context,
                'project',
                ProjectNameLabel(
                  projectId: quote.projectId,
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
    required this.quote,
    required this.selectedVersion,
    this.formatter,
  });
  final Quote quote;
  final ValueNotifier<String?> selectedVersion;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    return VersionedPdfPane(
      entity: BillingDocType.quote,
      entityNumber: quote.number,
      selection: selectedVersion,
      api: services.documentVersions,
      basePath: services.quotes.api.basePath,
      entityId: quote.id,
      formatter: formatter,
      liveFetcher: ({String? designId, required bool deliveryNote}) =>
          services.quotes.api.downloadPdf(
            entityJson: quote.toApiJson(),
            designId:
                designId ?? (quote.designId.isEmpty ? null : quote.designId),
          ),
    );
  }
}
