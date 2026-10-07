import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/recurring_invoice.dart';
import 'package:admin/data/models/domain/recurring_schedule_date.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/gateway_constants.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/activity_note_actions.dart';
import 'package:admin/ui/core/detail/activity_note_buttons.dart';
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
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/core/widgets/error_view.dart';
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
import 'package:admin/ui/features/projects/widgets/project_name_label.dart';
import 'package:admin/ui/features/recurring_invoices/view_models/recurring_invoice_detail_view_model.dart';
import 'package:admin/ui/features/recurring_invoices/widgets/recurring_invoice_actions.dart';
import 'package:admin/ui/features/recurring_invoices/widgets/recurring_invoice_status_pill.dart';
import 'package:admin/utils/formatting.dart';

/// The recurring invoice record screen, on the record layout
/// (`docs/detail-screen-layout.md`). Everything the five billing documents
/// have in common lives in `billing_shared/detail/`; what is here is what
/// only a recurring invoice has — its schedule — and the wiring several lints
/// pin to this file.
///
/// It has no document date and no due date of its own: when it next goes out
/// is the second figure on its standing card, how often and for how long is
/// the line under it, and the dates it will produce are the Schedule tab.
class RecurringInvoiceDetailScreen extends StatefulWidget {
  const RecurringInvoiceDetailScreen({required this.id, super.key});
  final String id;

  @override
  State<RecurringInvoiceDetailScreen> createState() =>
      _RecurringInvoiceDetailScreenState();
}

class _RecurringInvoiceDetailScreenState
    extends State<RecurringInvoiceDetailScreen>
    with FormatterHostMixin {
  late final RecurringInvoiceDetailViewModel _vm;
  late final Services _services;
  late final String _companyId;
  late final EntityActivityViewModel _activityVm;
  late final RecordScreenController _record;

  /// Which saved version the wide layout's PDF pane is showing; null is the
  /// live document. Owned by the screen so the History tab and the pane stay
  /// in step — the narrow layout has no pane and routes instead.
  final ValueNotifier<String?> _selectedVersion = ValueNotifier<String?>(null);

  @override
  void initState() {
    super.initState();
    _services = context.read<Services>();
    _companyId = _services.auth.session.value!.currentCompanyId;
    _vm = RecurringInvoiceDetailViewModel.bound(
      _services.recurringInvoices.watch(companyId: _companyId, id: widget.id),
    );
    // Owned here, not by the Activity tab, so the Comments card, the
    // Comments tab and the Activity tab share one fetch. Armed from
    // `bodyBuilder`.
    _activityVm = EntityActivityViewModel(
      api: _services.activities,
      outbox: _services.db.outboxDao,
      companyId: _companyId,
      entityWireName: 'recurring_invoice',
      entityId: widget.id,
    );
    _record = RecordScreenController(
      services: _services,
      companyId: _companyId,
      routeId: widget.id,
      entityWireName: 'recurring_invoice',
      refreshRecord: (id) => _services.recurringInvoices.refreshByIds(
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
    _selectedVersion.dispose();
    _vm.dispose();
    super.dispose();
  }

  void _dispatch(RecurringInvoice ri, RecurringInvoiceAction action) =>
      RecurringInvoiceActions.dispatch(
        context,
        _services,
        _companyId,
        ri,
        action,
      );

  @override
  Widget build(BuildContext context) {
    return EntityDetailScaffold<RecurringInvoice>(
      id: widget.id,
      vm: _vm,
      hydrate: () => _services.recurringInvoices.ensureLoaded(
        companyId: _companyId,
        id: widget.id,
      ),
      emptyAction: entityListEmptyAction(context, EntityType.recurringInvoice),
      emptyIcon: Icons.event_repeat_outlined,
      emptyTitle: context.tr('recurring_invoice_not_found'),
      actionsForItem: (context, ri) =>
          EntityDetailActionsRow<RecurringInvoiceAction>(
            items: RecurringInvoiceActions.itemsFor(
              context,
              ri,
              (a) => _dispatch(ri, a),
            ),
          ),
      compactTitleForItem: (context, ri) => BillingDocCompactTitle(
        type: BillingDocType.recurringInvoice,
        doc: ri,
        figure: ri.amount,
        formatter: formatter,
      ),
      // A deleted recurring invoice is read-only until restored.
      isReadOnly: (ri) => ri.isDeleted,
      onRefresh: _record.refresh,
      bannerForItem: (context, ri) => recordStateBanner<RecurringInvoiceAction>(
        context,
        items: RecurringInvoiceActions.itemsFor(
          context,
          ri,
          (a) => _dispatch(ri, a),
        ),
        restoreKind: RecurringInvoiceAction.restore,
        entityId: ri.id,
        isDeleted: ri.isDeleted,
        archivedAt: ri.archivedAt,
        formatter: formatter,
      ),
      bodyBuilder: (context, ri) => _body(context, ri),
    );
  }

  Widget _body(BuildContext context, RecurringInvoice ri) {
    _activityVm.kick();
    _record.attach(recordId: ri.id, revision: ri.updatedAt);
    Future<void> submit(String text) => _services.recurringInvoices.addComment(
      companyId: _companyId,
      entityId: ri.id,
      text: text,
    );
    // Built once here, not in `initState` (`promptLogCallFor` needs a subject
    // off the resolved record) and not twice (the card and the tabs must not
    // each hold their own copy — see `EntityNoteActions`). A deleted one takes
    // no new notes: the feed stays readable, its buttons go.
    final notes = ri.isDeleted
        ? EntityNoteActions.none
        : EntityNoteActions(
            onAddComment: () =>
                promptAddCommentFor(context, entityId: ri.id, submit: submit),
            onLogCall: () => promptLogCallFor(
              context,
              companyId: _companyId,
              entityId: ri.id,
              subject: billingDocSubject(ri),
              clientId: ri.clientId,
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
          recurringInvoice: ri,
          selectedVersion: _selectedVersion,
          formatter: formatter,
        ),
        top: (context, hasPdfPane) =>
            _top(context, ri, notes, companySnap.data, hasPdfPane: hasPdfPane),
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
                hostWireName: 'recurring_invoice',
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
                hostWireName: 'recurring_invoice',
              ),
            ),
            EntityDetailTab(
              id: DetailTabIds.overview,
              label: context.tr('overview'),
              icon: Icons.dashboard_outlined,
              // What every invoice in the series will carry. This tab used to
              // hold tags and notes only — a recurring invoice's line items
              // could not be read without opening it for editing.
              bodyBuilder: (_) => BillingDocOverviewOf(
                type: BillingDocType.recurringInvoice,
                doc: ri,
                formatter: formatter,
              ),
            ),
            EntityDetailTab(
              id: DetailTabIds.schedule,
              label: context.tr('schedule'),
              icon: Icons.calendar_month_outlined,
              bodyBuilder: (_) => _ScheduleTab(
                recurringInvoiceId: ri.id,
                services: _services,
                formatter: formatter,
              ),
            ),
            buildDocumentHistoryTab(
              context: context,
              services: _services,
              companyId: _companyId,
              basePath: _services.recurringInvoices.api.basePath,
              entityId: ri.id,
              currentAmount: ri.amount,
              currentUpdatedAt: ri.updatedAt,
              formatter: formatter,
              clientId: ri.clientId,
              selection: _selectedVersion,
              // Only the pane is ever "showing" a version; without one a tap
              // navigates, so nothing is selected.
              showSelection: hasPdfPane,
              onOpenVersion: billingDocVersionOpener(
                context,
                type: BillingDocType.recurringInvoice,
                docId: ri.id,
                hasPdfPane: hasPdfPane,
                selection: _selectedVersion,
              ),
            ),
            buildBillingDocumentsTab(
              context: context,
              companyId: _companyId,
              doc: ri,
              formatter: formatter,
              upload: _services.recurringInvoices.uploadDocument,
              delete: _services.recurringInvoices.deleteDocument,
              setVisibility: _services.recurringInvoices.setDocumentVisibility,
            ),
            EntityDetailTab(
              id: DetailTabIds.emailHistory,
              label: context.tr('email_history'),
              icon: Icons.outgoing_mail,
              bodyBuilder: (_) => BillingDocSendsTab(
                services: _services,
                companyId: _companyId,
                entityWireName: 'recurring_invoice',
                entityId: ri.id,
                invitations: ri.invitations,
                isDirty: ri.isDirty,
                clientId: ri.clientId,
                isHosted: _services.auth.session.value?.isHosted ?? false,
                onReactivate: (messageId) =>
                    _services.recurringInvoices.reactivateInvitationEmail(
                      companyId: _companyId,
                      id: ri.id,
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
    RecurringInvoice ri,
    EntityNoteActions notes,
    Company? company, {
    required bool hasPdfPane,
  }) {
    final f = formatter;
    final lastSent = ri.lastSentDate;
    return EntityRecordColumn(
      header: BillingDocRecordHeader(
        type: BillingDocType.recurringInvoice,
        doc: ri,
        formatter: formatter,
        statusPill: RecurringInvoiceStatusPill(
          statusId: ri.calculatedStatusId,
          hasBounce: ri.hasBouncedInvitation,
        ),
        party: ClientNameLabel(
          clientId: ri.clientId,
          link: true,
          style: BillingDocRecordHeader.partyStyle(context),
        ),
        // The one date it has that is behind it. What is ahead is on the
        // standing card.
        facts: [
          if (lastSent != null && f != null)
            Text(
              '${context.tr('last_sent_date')}: ${f.date(lastSent.toIso())}',
            ),
        ],
      ),
      quickActions: EntityQuickActions<RecurringInvoiceAction>(
        priority: RecurringInvoiceActions.quickItemsFor(
          context,
          ri,
          (a) => _dispatch(ri, a),
          hasPdfPane: hasPdfPane,
        ),
      ),
      standing: BillingDocStanding(
        type: BillingDocType.recurringInvoice,
        doc: ri,
        formatter: formatter,
        nextSendDate: ri.nextSendDate,
        frequencyId: ri.frequencyId,
        remainingCycles: ri.remainingCycles,
      ),
      comments: EntityCommentsCard(
        vm: _activityVm,
        formatter: formatter,
        actions: notes,
        hostWireName: 'recurring_invoice',
        onViewAll: () => _record.selectTab.select(kCommentsTabIndex),
        matchFormColumn: true,
      ),
      profile: BillingDocPartyContacts(
        companyId: _companyId,
        type: BillingDocType.recurringInvoice,
        doc: ri,
        builder: (context, contacts) => BillingDocProfile(
          type: BillingDocType.recurringInvoice,
          doc: ri,
          company: company,
          contacts: contacts,
          formatter: formatter,
          detailRows: [
            if (_dueDateLabel(context, ri.dueDateDays) case final due?)
              DetailInfoRow(
                label: context.tr('due_date'),
                value: due,
                copyable: false,
              ),
            if (_autoBillLabel(context, ri.autoBill) case final autoBill?)
              DetailInfoRow(
                label: context.tr('auto_bill'),
                value: autoBill,
                copyable: false,
              ),
            if (ri.projectId.isNotEmpty)
              billingDocLabelRow(
                context,
                'project',
                ProjectNameLabel(
                  projectId: ri.projectId,
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

/// When each invoice in the series falls due, when that is something other
/// than the client's own payment terms — the default, and not worth a row.
/// The same wording the edit screen's picker uses.
String? _dueDateLabel(BuildContext context, String dueDateDays) =>
    switch (dueDateDays) {
      '' || 'terms' => null,
      '1' => context.tr('first_day_of_the_month'),
      '31' => context.tr('last_day_of_the_month'),
      _ =>
        int.tryParse(dueDateDays) != null
            ? context.tr('day_count', {'count': dueDateDays})
            : dueDateDays,
    };

/// The auto-bill mode, when there is one. `always` reads "Enabled", as it does
/// on the edit screen and in React.
String? _autoBillLabel(BuildContext context, String autoBill) =>
    switch (autoBill) {
      kAutoBillAlways => context.tr('enabled'),
      kAutoBillOptOut => context.tr('opt_out'),
      kAutoBillOptIn => context.tr('opt_in'),
      _ => null,
    };

/// Read-only "Schedule" tab: the server-computed upcoming send + due dates
/// (`GET ?show_dates=true`). Fetched on demand — not part of the synced
/// entity — and rendered through the company [Formatter] so dates honor the
/// configured format. Mirrors React's Schedule tab.
class _ScheduleTab extends StatefulWidget {
  const _ScheduleTab({
    required this.recurringInvoiceId,
    required this.services,
    required this.formatter,
  });

  final String recurringInvoiceId;
  final Services services;
  final Formatter? formatter;

  @override
  State<_ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<_ScheduleTab> {
  late Future<List<RecurringScheduleDate>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<RecurringScheduleDate>> _load() => widget
      .services
      .recurringInvoices
      .api
      .fetchSchedule(id: widget.recurringInvoiceId);

  // Never render a raw ISO string — fall back to a placeholder until the
  // formatter is ready (see the Formatter rule in CLAUDE.md).
  String _fmt(Date? d) =>
      d == null ? '—' : (widget.formatter?.date(d.toIso()) ?? '—');

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return FutureBuilder<List<RecurringScheduleDate>>(
      future: _future,
      builder: (context, snap) {
        // A gap under the strip and nothing at the sides: the record page
        // already insets a tab's body to the edge the cards above it share.
        Widget pad(Widget child) => Padding(
          padding: EdgeInsets.only(top: InSpacing.lg(context)),
          child: child,
        );

        if (snap.connectionState == ConnectionState.waiting) {
          return pad(const Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError) {
          return pad(
            ErrorView(
              message: context.tr('an_error_occurred'),
              onRetry: () => setState(() => _future = _load()),
            ),
          );
        }
        final rows = snap.data ?? const <RecurringScheduleDate>[];
        if (rows.isEmpty) {
          return pad(
            EmptyState(
              icon: Icons.calendar_month_outlined,
              title: context.tr('no_records_found'),
            ),
          );
        }

        TextStyle headStyle() => TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: tokens.ink3,
        );
        Widget cell(String text, {bool head = false}) => Expanded(
          child: Text(
            text,
            style: head ? headStyle() : TextStyle(color: tokens.ink),
          ),
        );
        Widget row(Widget a, Widget b) => Padding(
          padding: EdgeInsets.symmetric(
            horizontal: InSpacing.lg(context),
            vertical: InSpacing.md(context),
          ),
          child: Row(
            children: [
              a,
              SizedBox(width: InSpacing.md(context)),
              b,
            ],
          ),
        );

        return pad(
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: tokens.border),
              borderRadius: BorderRadius.circular(InRadii.r3),
              color: tokens.surface,
            ),
            child: Column(
              children: [
                row(
                  cell(context.tr('send_date'), head: true),
                  cell(context.tr('due_date'), head: true),
                ),
                for (final r in rows) ...[
                  Divider(height: 1, color: tokens.border),
                  row(cell(_fmt(r.sendDate)), cell(_fmt(r.dueDate))),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PdfPane extends StatelessWidget {
  const _PdfPane({
    required this.recurringInvoice,
    required this.selectedVersion,
    this.formatter,
  });
  final RecurringInvoice recurringInvoice;
  final ValueNotifier<String?> selectedVersion;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    return VersionedPdfPane(
      entity: BillingDocType.recurringInvoice,
      entityNumber: recurringInvoice.number,
      selection: selectedVersion,
      api: services.documentVersions,
      basePath: services.recurringInvoices.api.basePath,
      entityId: recurringInvoice.id,
      formatter: formatter,
      liveFetcher: ({String? designId, required bool deliveryNote}) =>
          services.recurringInvoices.api.downloadPdf(
            entityJson: recurringInvoice.toApiJson(),
            designId:
                designId ??
                (recurringInvoice.designId.isEmpty
                    ? null
                    : recurringInvoice.designId),
          ),
    );
  }
}
