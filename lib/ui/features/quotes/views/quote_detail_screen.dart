import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/ui/core/detail/entity_list_empty_action.dart';
import 'package:admin/ui/core/widgets/client_name_label.dart';
import 'package:admin/ui/core/widgets/invoice_name_label.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/quote.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/detail/entity_detail_scaffold.dart';
import 'package:admin/ui/core/detail/entity_detail_tabs.dart';
import 'package:admin/ui/core/detail/recent_visit_recorder.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/core/detail/entity_documents_tab.dart';
import 'package:admin/ui/core/widgets/formatter_host_mixin.dart';
import 'package:admin/ui/core/widgets/party_call_button.dart';
import 'package:admin/ui/core/widgets/watch_builder.dart';
import 'package:admin/ui/features/billing_shared/activity/billing_doc_activity_tab.dart';
import 'package:admin/ui/features/billing_shared/sends/billing_doc_sends_tab.dart';
import 'package:admin/ui/features/billing_shared/billing_doc_type.dart';
import 'package:admin/ui/features/billing_shared/pdf/billing_doc_pdf_view.dart';
import 'package:admin/ui/features/quotes/view_models/quote_detail_view_model.dart';
import 'package:admin/ui/features/quotes/widgets/quote_actions.dart';
import 'package:admin/ui/features/quotes/widgets/quote_status_pill.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/domain/billing/totals_calculator.dart';
import 'package:admin/ui/core/widgets/formatter_scope.dart';
import 'package:admin/ui/features/billing_shared/billing_doc_kpi_strip.dart';
import 'package:admin/ui/core/detail/custom_fields_detail_card.dart';
import 'package:admin/ui/features/billing_shared/billing_doc_overview.dart';

class QuoteDetailScreen extends StatefulWidget {
  const QuoteDetailScreen({required this.id, super.key});
  final String id;

  @override
  State<QuoteDetailScreen> createState() => _QuoteDetailScreenState();
}

class _QuoteDetailScreenState extends State<QuoteDetailScreen>
    with FormatterHostMixin {
  late final QuoteDetailViewModel _vm;
  late final Services _services;
  late final String _companyId;

  @override
  void initState() {
    super.initState();
    _services = context.read<Services>();
    _companyId = _services.auth.session.value!.currentCompanyId;
    _vm = QuoteDetailViewModel.bound(
      _services.quotes.watch(companyId: _companyId, id: widget.id),
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
          (a) =>
              QuoteActions.dispatch(context, _services, _companyId, quote, a),
        ),
      ),
      bodyBuilder: (context, quote) {
        final body = _Body(
          quote: quote,
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
    required this.quote,
    required this.services,
    required this.companyId,
  });

  final Quote quote;
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
                type: EntityType.quote,
                id: quote.id,
                label: quote.number.isEmpty
                    ? context.tr('quote')
                    : '#${quote.number}',
                child: _Header(quote: quote),
              ),
              SizedBox(height: InSpacing.lg(context)),
              EntityDetailTabs(
                tabs: [
                  EntityDetailTab(
                    label: context.tr('overview'),
                    icon: Icons.dashboard_outlined,
                    bodyBuilder: (_) => Padding(
                      padding: EdgeInsets.all(InSpacing.lg(context)),
                      child: _Overview(quote: quote),
                    ),
                  ),
                  EntityDetailTab(
                    label: quote.documents.isEmpty
                        ? context.tr('documents')
                        : context.tr('documents_with_count', {
                            'count': '${quote.documents.length}',
                          }),
                    icon: Icons.description_outlined,
                    bodyBuilder: (_) => EntityDocumentsTab(
                      entityId: quote.id,
                      documents: quote.documents,
                      onUpload: (sources) async {
                        for (final s in sources) {
                          await services.quotes.uploadDocument(
                            companyId: companyId,
                            entityId: quote.id,
                            source: s,
                          );
                        }
                      },
                      onDelete: (doc) async {
                        await services.quotes.deleteDocument(
                          companyId: companyId,
                          entityId: quote.id,
                          documentId: doc.id,
                        );
                      },
                      onToggleVisibility: (doc) async {
                        await services.quotes.setDocumentVisibility(
                          companyId: companyId,
                          entityId: quote.id,
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
                      entityWireName: 'quote',
                      entityId: quote.id,
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
                      entityWireName: 'quote',
                      entityId: quote.id,
                      invitations: quote.invitations,
                      clientId: quote.clientId,
                      isHosted: services.auth.session.value?.isHosted ?? false,
                      onReactivate: (messageId) =>
                          services.quotes.reactivateInvitationEmail(
                            companyId: companyId,
                            id: quote.id,
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
            Expanded(flex: 6, child: _PdfPane(quote: quote)),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.quote});
  final Quote quote;

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
                  quote.number.isEmpty ? '—' : '#${quote.number}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: tokens.ink,
                  ),
                ),
              ),
              SizedBox(width: InSpacing.md(context)),
              QuoteStatusPill(
                statusId: quote.calculatedStatusId,
                hasBounce: quote.hasBouncedInvitation,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Flexible(
                child: ClientNameLabel(
                  clientId: quote.clientId,
                  link: true,
                  style: TextStyle(color: tokens.ink3),
                ),
              ),
              PartyCallButton(clientId: quote.clientId),
            ],
          ),
          const SizedBox(height: 12),
          BillingDatesCaption(
            formatter: formatter,
            issuedLabel: context.tr('date'),
            issued: quote.date,
            secondaryLabel: context.tr('valid_until'),
            secondary: quote.dueDate,
            overduePrefix: context.tr('expired'),
            overdueDays: quote.isExpired && quote.dueDate != null
                ? Date.today().differenceInDays(quote.dueDate!)
                : null,
          ),
          const SizedBox(height: 16),
          WatchBuilder<Client?>(
            cacheKey: (companyId, quote.clientId),
            initialData: services.clients.peek(
              companyId: companyId,
              id: quote.clientId,
            ),
            create: () => services.clients.watch(
              companyId: companyId,
              id: quote.clientId,
            ),
            builder: (context, clientSnap) => BillingDocKpiStrip(
              formatter: formatter,
              currencyId: clientSnap.data?.currencyId,
              metrics: [
                BillingMetric(
                  label: context.tr('amount'),
                  amount: quote.amount,
                ),
              ],
            ),
          ),
          if (quote.invoiceId.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  '${context.tr('converted_to')} ',
                  style: TextStyle(fontSize: 12.5, color: tokens.ink3),
                ),
                Flexible(
                  child: InvoiceNameLabel(
                    invoiceId: quote.invoiceId,
                    link: true,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: tokens.ink,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.quote});
  final Quote quote;

  @override
  Widget build(BuildContext context) {
    final formatter = FormatterScope.maybeOf(context);
    final services = context.read<Services>();
    final companyId = services.auth.currentCompanyId ?? '';
    return WatchBuilder<Client?>(
      cacheKey: (companyId, quote.clientId),
      initialData: services.clients.peek(
        companyId: companyId,
        id: quote.clientId,
      ),
      create: () =>
          services.clients.watch(companyId: companyId, id: quote.clientId),
      builder: (context, clientSnap) {
        final currencyId = clientSnap.data?.currencyId;
        final precision =
            formatter?.precisionFor(clientCurrencyId: currencyId) ?? 2;
        return BillingDocOverview(
          totalsInput: _quoteTotalsInput(quote),
          surchargeAmounts: [
            quote.customSurcharge1,
            quote.customSurcharge2,
            quote.customSurcharge3,
            quote.customSurcharge4,
          ],
          precision: precision,
          publicNotes: quote.publicNotes,
          terms: quote.terms,
          formatter: formatter,
          currencyId: currencyId,
          entityType: 'quote',
          tagIds: quote.tagIds,
          trailing: [
            if (quote.customValue1.isNotEmpty ||
                quote.customValue2.isNotEmpty ||
                quote.customValue3.isNotEmpty ||
                quote.customValue4.isNotEmpty)
              CustomFieldsDetailCard(
                companyId: companyId,
                prefix: 'invoice',
                values: [
                  quote.customValue1,
                  quote.customValue2,
                  quote.customValue3,
                  quote.customValue4,
                ],
                formatter: formatter,
              ),
          ],
        );
      },
    );
  }
}

BillingTotalsInput _quoteTotalsInput(Quote d) => BillingTotalsInput(
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
  const _PdfPane({required this.quote});
  final Quote quote;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    return BillingDocPdfView(
      entity: BillingDocType.quote,
      entityNumber: quote.number,
      fetcher: ({String? designId, required bool deliveryNote}) =>
          services.quotes.api.downloadPdf(
            entityJson: quote.toApiJson(),
            designId:
                designId ?? (quote.designId.isEmpty ? null : quote.designId),
          ),
    );
  }
}
