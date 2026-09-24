import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/ui/core/detail/entity_list_empty_action.dart';
import 'package:admin/ui/core/widgets/client_name_label.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/billing/invitation.dart';
import 'package:admin/data/models/domain/credit.dart';
import 'package:admin/data/models/domain/credit_status.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/detail/entity_detail_scaffold.dart';
import 'package:admin/ui/core/detail/activity_reveal_controller.dart';
import 'package:admin/ui/core/detail/detail_tab_indices.dart';
import 'package:admin/ui/core/detail/entity_detail_tabs.dart';
import 'package:admin/ui/core/detail/recent_visit_recorder.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/core/detail/entity_documents_tab.dart';
import 'package:admin/ui/core/widgets/formatter_host_mixin.dart';
import 'package:admin/ui/core/widgets/party_call_button.dart';
import 'package:admin/ui/core/widgets/watch_builder.dart';
import 'package:admin/ui/core/detail/activity_note_actions.dart';
import 'package:admin/ui/core/detail/activity_note_buttons.dart';
import 'package:admin/ui/features/billing_shared/activity/entity_activity_tab.dart';
import 'package:admin/ui/features/billing_shared/activity/entity_activity_view_model.dart';
import 'package:admin/ui/features/billing_shared/activity/entity_comments_card.dart';
import 'package:admin/ui/features/billing_shared/sends/billing_doc_sends_tab.dart';
import 'package:admin/ui/features/billing_shared/billing_doc_type.dart';
import 'package:admin/ui/core/sync/require_synced.dart';
import 'package:admin/ui/features/billing_shared/history/build_document_history_tab.dart';
import 'package:admin/ui/features/billing_shared/history/versioned_pdf_pane.dart';
import 'package:admin/ui/features/credits/view_models/credit_detail_view_model.dart';
import 'package:admin/ui/features/credits/widgets/credit_actions.dart';
import 'package:admin/ui/features/billing_shared/viewed_status_pill_link.dart';
import 'package:admin/ui/features/credits/widgets/credit_status_pill.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/domain/billing/billing_doc_totals.dart';
import 'package:admin/ui/core/widgets/formatter_scope.dart';
import 'package:admin/ui/features/billing_shared/billing_doc_kpi_strip.dart';
import 'package:admin/ui/core/detail/custom_fields_detail_card.dart';
import 'package:admin/ui/features/billing_shared/billing_doc_overview.dart';

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
  final TabSelectionController _selectTab = TabSelectionController();

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
    loadFormatter(_services, _companyId);
  }

  @override
  void dispose() {
    _activityVm.dispose();
    _selectTab.dispose();
    _revealActivity.dispose();
    _selectedVersion.dispose();
    _vm.dispose();
    super.dispose();
  }

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
      actionsForItem: (context, credit) => EntityDetailActionsRow<CreditAction>(
        items: CreditActions.itemsFor(
          context,
          credit,
          (a) =>
              CreditActions.dispatch(context, _services, _companyId, credit, a),
        ),
      ),
      bodyBuilder: (context, credit) {
        final body = _Body(
          credit: credit,
          services: _services,
          companyId: _companyId,
          activityVm: _activityVm,
          selectTab: _selectTab,
          revealActivity: _revealActivity,
          selectedVersion: _selectedVersion,
        );
        // Always mounted, even while `formatter` is still null: branching
        // here would change the tree shape and remount the whole body when
        // the formatter lands.
        return FormatterScope(formatter: formatter, child: body);
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.credit,
    required this.services,
    required this.companyId,
    required this.activityVm,
    required this.selectTab,
    required this.revealActivity,
    required this.selectedVersion,
  });

  final Credit credit;
  final Services services;
  final ValueNotifier<String?> selectedVersion;
  final String companyId;
  final EntityActivityViewModel activityVm;
  final TabSelectionController selectTab;
  final ActivityRevealController revealActivity;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide =
            Breakpoints.isWide(constraints) && constraints.maxWidth >= 900;
        activityVm.kick();
        // Built here, not in the screen's `initState`: `promptLogCallFor`
        // needs a subject off the resolved record.
        final notes = EntityNoteActions(
          onAddComment: () => promptAddCommentFor(
            context,
            entityId: credit.id,
            submit: (text) => services.credits.addComment(
              companyId: companyId,
              entityId: credit.id,
              text: text,
            ),
          ),
          onLogCall: () => promptLogCallFor(
            context,
            companyId: companyId,
            entityId: credit.id,
            subject: credit.number.isEmpty ? '' : '#${credit.number}',
            clientId: credit.clientId,
            submit: (text) => services.credits.addComment(
              companyId: companyId,
              entityId: credit.id,
              text: text,
            ),
          ),
        );
        final main = SingleChildScrollView(
          padding: EdgeInsets.all(InSpacing.lg(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RecentVisitRecorder(
                type: EntityType.credit,
                id: credit.id,
                label: credit.number.isEmpty
                    ? context.tr('credit')
                    : '#${credit.number}',
                child: _Header(
                  credit: credit,
                  selectTab: selectTab,
                  revealActivity: revealActivity,
                ),
              ),
              SizedBox(height: InSpacing.lg(context)),
              EntityCommentsCard(
                vm: activityVm,
                formatter: FormatterScope.maybeOf(context),
                actions: notes,
                hostWireName: 'credit',
                onViewAll: () => selectTab.select(kCommentsTabIndex),
              ),
              EntityDetailTabs(
                initialIndex: 2,
                selectTab: selectTab,
                tabs: [
                  EntityDetailTab(
                    label: context.tr('comments'),
                    icon: Icons.comment_outlined,
                    bodyBuilder: (_) => EntityActivityTab(
                      vm: activityVm,
                      formatter: FormatterScope.maybeOf(context),
                      actions: notes,
                      commentsOnly: true,
                      hostWireName: 'credit',
                    ),
                  ),
                  EntityDetailTab(
                    label: context.tr('activity'),
                    icon: Icons.history_outlined,
                    bodyBuilder: (_) => EntityActivityTab(
                      vm: activityVm,
                      formatter: FormatterScope.maybeOf(context),
                      actions: notes,
                      hostWireName: 'credit',
                      reveal: revealActivity,
                    ),
                  ),
                  EntityDetailTab(
                    label: context.tr('overview'),
                    icon: Icons.dashboard_outlined,
                    bodyBuilder: (_) => Padding(
                      padding: EdgeInsets.all(InSpacing.lg(context)),
                      child: _Overview(credit: credit),
                    ),
                  ),
                  buildDocumentHistoryTab(
                    context: context,
                    services: services,
                    companyId: companyId,
                    basePath: services.credits.api.basePath,
                    entityId: credit.id,
                    currentAmount: credit.amount,
                    currentUpdatedAt: credit.updatedAt,
                    formatter: FormatterScope.maybeOf(context),
                    clientId: credit.clientId,
                    selection: selectedVersion,
                    // Only wide drives the pane; narrow navigates, so
                    // nothing there is ever "selected".
                    showSelection: wide,
                    onOpenVersion: (String? activityId) {
                      // Wide keeps the record on screen and swaps the
                      // pane; narrow has no pane, so it routes.
                      if (wide) {
                        selectedVersion.value = activityId;
                      } else if (requireSynced(context, credit.id)) {
                        context.go(
                          '/credits/${credit.id}/pdf'
                          '${activityId == null ? '' : '?activity_id=$activityId'}',
                        );
                      }
                    },
                  ),
                  EntityDetailTab(
                    label: credit.documents.isEmpty
                        ? context.tr('documents')
                        : context.tr('documents_with_count', {
                            'count': '${credit.documents.length}',
                          }),
                    icon: Icons.description_outlined,
                    bodyBuilder: (_) => EntityDocumentsTab(
                      entityId: credit.id,
                      documents: credit.documents,
                      onUpload: (sources) async {
                        for (final s in sources) {
                          await services.credits.uploadDocument(
                            companyId: companyId,
                            entityId: credit.id,
                            source: s,
                          );
                        }
                      },
                      onDelete: (doc) async {
                        await services.credits.deleteDocument(
                          companyId: companyId,
                          entityId: credit.id,
                          documentId: doc.id,
                        );
                      },
                      onToggleVisibility: (doc) async {
                        await services.credits.setDocumentVisibility(
                          companyId: companyId,
                          entityId: credit.id,
                          documentId: doc.id,
                          isPublic: !doc.isPublic,
                        );
                      },
                    ),
                  ),
                  EntityDetailTab(
                    label: context.tr('email_history'),
                    icon: Icons.outgoing_mail,
                    bodyBuilder: (_) => BillingDocSendsTab(
                      services: services,
                      companyId: companyId,
                      entityWireName: 'credit',
                      entityId: credit.id,
                      invitations: credit.invitations,
                      isDirty: credit.isDirty,
                      clientId: credit.clientId,
                      isHosted: services.auth.session.value?.isHosted ?? false,
                      onReactivate: (messageId) =>
                          services.credits.reactivateInvitationEmail(
                            companyId: companyId,
                            id: credit.id,
                            messageId: messageId,
                          ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
        if (!wide) return main;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 5, child: main),
            VerticalDivider(width: 1, color: context.inTheme.border),
            Expanded(
              flex: 6,
              child: _PdfPane(credit: credit, selectedVersion: selectedVersion),
            ),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.credit,
    required this.selectTab,
    required this.revealActivity,
  });
  final Credit credit;
  final TabSelectionController selectTab;
  final ActivityRevealController revealActivity;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final formatter = FormatterScope.maybeOf(context);
    final services = context.read<Services>();
    final companyId = services.auth.currentCompanyId ?? '';
    return Container(
      padding: EdgeInsets.all(InSpacing.lg(context)),
      decoration: BoxDecoration(
        border: Border.all(color: tokens.border),
        borderRadius: BorderRadius.circular(InRadii.r3),
        color: tokens.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  credit.number.isEmpty ? '—' : '#${credit.number}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: tokens.ink,
                  ),
                ),
              ),
              SizedBox(width: InSpacing.md(context)),
              ViewedStatusPillLink(
                isViewed:
                    credit.calculatedStatusId == CreditStatusComputed.viewed,
                invitations: credit.invitations,
                entityWireName: 'credit',
                companyId: companyId,
                clients: services.clients,
                vendors: services.vendors,
                clientId: credit.clientId,
                selectTab: selectTab,
                reveal: revealActivity,
                formatter: formatter,
                builder: (context, tooltip, semanticsLabel, onTap) =>
                    CreditStatusPill(
                      statusId: credit.calculatedStatusId,
                      hasBounce: credit.hasBouncedInvitation,
                      tooltip: tooltip,
                      onTap: onTap,
                      semanticsLabel: semanticsLabel,
                      semanticsHint: onTap == null
                          ? null
                          : context.tr('activity'),
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Flexible(
                child: ClientNameLabel(
                  clientId: credit.clientId,
                  link: true,
                  style: TextStyle(color: tokens.ink3),
                ),
              ),
              PartyCallButton(
                clientId: credit.clientId,
                // Filed against the *document*, not the party: the
                // server stamps `client_id` on it anyway, so it still
                // reaches the client's feed — and this way the note
                // also says which document the call was about.
                logTarget: (
                  type: EntityType.credit,
                  id: credit.id,
                  subject: credit.number.isEmpty ? '' : '#${credit.number}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          BillingDatesCaption(
            formatter: formatter,
            issuedLabel: context.tr('date'),
            issued: credit.date,
            secondaryLabel: context.tr('due_date'),
            secondary: credit.partialDueDate ?? credit.dueDate,
            viewedLabel: context.tr('viewed'),
            viewedIso: credit.invitations.newestViewed?.viewedDate,
          ),
          const SizedBox(height: 16),
          WatchBuilder<Client?>(
            cacheKey: (companyId, credit.clientId),
            initialData: services.clients.peek(
              companyId: companyId,
              id: credit.clientId,
            ),
            create: () => services.clients.watch(
              companyId: companyId,
              id: credit.clientId,
            ),
            builder: (context, clientSnap) => BillingDocKpiStrip(
              formatter: formatter,
              currencyId: clientSnap.data?.currencyId,
              metrics: [
                BillingMetric(
                  label: context.tr('amount'),
                  amount: credit.amount,
                ),
                BillingMetric(
                  label: context.tr('balance'),
                  amount: credit.balance,
                ),
                BillingMetric(
                  label: context.tr('applied'),
                  amount: credit.paidToDate,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.credit});
  final Credit credit;

  @override
  Widget build(BuildContext context) {
    final formatter = FormatterScope.maybeOf(context);
    final services = context.read<Services>();
    final companyId = services.auth.currentCompanyId ?? '';
    return WatchBuilder<Client?>(
      cacheKey: (companyId, credit.clientId),
      initialData: services.clients.peek(
        companyId: companyId,
        id: credit.clientId,
      ),
      create: () =>
          services.clients.watch(companyId: companyId, id: credit.clientId),
      builder: (context, clientSnap) {
        final currencyId = clientSnap.data?.currencyId;
        final precision =
            formatter?.precisionFor(clientCurrencyId: currencyId) ?? 2;
        return BillingDocOverview(
          totalsInput: credit.totalsInput,
          surchargeAmounts: [
            credit.customSurcharge1,
            credit.customSurcharge2,
            credit.customSurcharge3,
            credit.customSurcharge4,
          ],
          precision: precision,
          paidToDate: credit.paidToDate,
          balance: credit.balance,
          publicNotes: credit.publicNotes,
          terms: credit.terms,
          formatter: formatter,
          currencyId: currencyId,
          entityType: 'credit',
          tagIds: credit.tagIds,
          trailing: [
            if (credit.customValue1.isNotEmpty ||
                credit.customValue2.isNotEmpty ||
                credit.customValue3.isNotEmpty ||
                credit.customValue4.isNotEmpty)
              CustomFieldsDetailCard(
                companyId: companyId,
                prefix: 'invoice',
                values: [
                  credit.customValue1,
                  credit.customValue2,
                  credit.customValue3,
                  credit.customValue4,
                ],
                formatter: formatter,
              ),
          ],
        );
      },
    );
  }
}

class _PdfPane extends StatelessWidget {
  const _PdfPane({required this.credit, required this.selectedVersion});
  final Credit credit;
  final ValueNotifier<String?> selectedVersion;

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
      formatter: FormatterScope.maybeOf(context),
      liveFetcher: ({String? designId, required bool deliveryNote}) =>
          services.credits.api.downloadPdf(
            entityJson: credit.toApiJson(),
            designId:
                designId ?? (credit.designId.isEmpty ? null : credit.designId),
          ),
    );
  }
}
