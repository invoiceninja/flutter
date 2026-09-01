import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/ui/core/detail/entity_list_empty_action.dart';
import 'package:admin/ui/core/widgets/client_name_label.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/credit.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/detail/entity_detail_scaffold.dart';
import 'package:admin/ui/core/detail/entity_detail_tabs.dart';
import 'package:admin/ui/core/detail/recent_visit_recorder.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/core/detail/entity_documents_tab.dart';
import 'package:admin/ui/core/widgets/formatter_host_mixin.dart';
import 'package:admin/ui/core/widgets/watch_builder.dart';
import 'package:admin/ui/features/billing_shared/activity/billing_doc_activity_tab.dart';
import 'package:admin/ui/features/billing_shared/sends/billing_doc_sends_tab.dart';
import 'package:admin/ui/features/billing_shared/billing_doc_type.dart';
import 'package:admin/ui/features/billing_shared/pdf/billing_doc_pdf_view.dart';
import 'package:admin/ui/features/credits/view_models/credit_detail_view_model.dart';
import 'package:admin/ui/features/credits/widgets/credit_actions.dart';
import 'package:admin/ui/features/credits/widgets/credit_status_pill.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/domain/billing/totals_calculator.dart';
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

  @override
  void initState() {
    super.initState();
    _services = context.read<Services>();
    _companyId = _services.auth.session.value!.currentCompanyId;
    _vm = CreditDetailViewModel.bound(
      _services.credits.watch(companyId: _companyId, id: widget.id),
    );
    loadFormatter(_services, _companyId);
  }

  @override
  void dispose() {
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
  });

  final Credit credit;
  final Services services;
  final String companyId;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide =
            Breakpoints.isWide(constraints) && constraints.maxWidth >= 900;
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
                child: _Header(credit: credit),
              ),
              SizedBox(height: InSpacing.lg(context)),
              EntityDetailTabs(
                tabs: [
                  EntityDetailTab(
                    label: context.tr('overview'),
                    icon: Icons.dashboard_outlined,
                    bodyBuilder: (_) => Padding(
                      padding: EdgeInsets.all(InSpacing.lg(context)),
                      child: _Overview(credit: credit),
                    ),
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
                    label: context.tr('activity'),
                    icon: Icons.history_outlined,
                    bodyBuilder: (_) => BillingDocActivityTab(
                      entityWireName: 'credit',
                      entityId: credit.id,
                      companyId: companyId,
                      activitiesApi: services.activities,
                      outboxDao: services.db.outboxDao,
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
            Expanded(flex: 6, child: _PdfPane(credit: credit)),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.credit});
  final Credit credit;

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
              CreditStatusPill(
                statusId: credit.calculatedStatusId,
                hasBounce: credit.hasBouncedInvitation,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClientNameLabel(
            clientId: credit.clientId,
            link: true,
            style: TextStyle(color: tokens.ink3),
          ),
          const SizedBox(height: 12),
          BillingDatesCaption(
            formatter: formatter,
            issuedLabel: context.tr('date'),
            issued: credit.date,
            secondaryLabel: context.tr('due_date'),
            secondary: credit.partialDueDate ?? credit.dueDate,
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
          totalsInput: _creditTotalsInput(credit),
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

BillingTotalsInput _creditTotalsInput(Credit d) => BillingTotalsInput(
  lineItems: d.lineItems,
  discount: d.discount,
  isAmountDiscount: d.isAmountDiscount,
  usesInclusiveTaxes: d.usesInclusiveTaxes,
  taxName1: d.taxName1,
  taxRate1: d.taxRate1,
  taxName2: d.taxName2,
  taxRate2: d.taxRate2,
  taxName3: d.taxName3,
  taxRate3: d.taxRate3,
  customSurcharge1: d.customSurcharge1,
  customSurcharge2: d.customSurcharge2,
  customSurcharge3: d.customSurcharge3,
  customSurcharge4: d.customSurcharge4,
  customTaxes1: d.customTaxes1,
  customTaxes2: d.customTaxes2,
  customTaxes3: d.customTaxes3,
  customTaxes4: d.customTaxes4,
);

class _PdfPane extends StatelessWidget {
  const _PdfPane({required this.credit});
  final Credit credit;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    return BillingDocPdfView(
      entity: BillingDocType.credit,
      entityNumber: credit.number,
      fetcher: ({String? designId, required bool deliveryNote}) =>
          services.credits.api.downloadPdf(
            entityJson: credit.toApiJson(),
            designId:
                designId ?? (credit.designId.isEmpty ? null : credit.designId),
          ),
    );
  }
}
