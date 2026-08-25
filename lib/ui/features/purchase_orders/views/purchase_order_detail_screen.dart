import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/ui/core/widgets/entity_tags_view.dart';
import 'package:admin/ui/core/widgets/vendor_name_label.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/purchase_order.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/detail/custom_fields_detail_card.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/detail/entity_detail_scaffold.dart';
import 'package:admin/ui/core/detail/entity_detail_tabs.dart';
import 'package:admin/ui/core/detail/recent_visit_recorder.dart';
import 'package:admin/domain/date_placeholders.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/core/detail/entity_documents_tab.dart';
import 'package:admin/ui/core/widgets/formatter_host_mixin.dart';
import 'package:admin/ui/core/widgets/party_money_cell.dart';
import 'package:admin/utils/formatting.dart';
import 'package:admin/ui/features/billing_shared/activity/billing_doc_activity_tab.dart';
import 'package:admin/ui/features/billing_shared/sends/billing_doc_sends_tab.dart';
import 'package:admin/ui/features/billing_shared/billing_doc_type.dart';
import 'package:admin/ui/features/billing_shared/pdf/billing_doc_pdf_view.dart';
import 'package:admin/ui/features/purchase_orders/view_models/purchase_order_detail_view_model.dart';
import 'package:admin/ui/features/purchase_orders/widgets/purchase_order_actions.dart';
import 'package:admin/ui/features/purchase_orders/widgets/purchase_order_status_pill.dart';

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

  @override
  void initState() {
    super.initState();
    _services = context.read<Services>();
    _companyId = _services.auth.session.value!.currentCompanyId;
    _vm = PurchaseOrderDetailViewModel.bound(
      _services.purchaseOrders.watch(companyId: _companyId, id: widget.id),
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
    return EntityDetailScaffold<PurchaseOrder>(
      vm: _vm,
      emptyIcon: Icons.shopping_bag_outlined,
      emptyTitle: context.tr('purchase_order_not_found'),
      actionsForItem: (context, po) => StreamBuilder<Company?>(
        // Cheap local Drift watch — the e-PO download gate needs the
        // company's e-invoice type (mirrors invoice_detail_screen).
        stream: _services.company.watchCompany(_companyId),
        builder: (context, companySnap) =>
            EntityDetailActionsRow<PurchaseOrderAction>(
              items: PurchaseOrderActions.itemsFor(
                context,
                po,
                (a) => PurchaseOrderActions.dispatch(
                  context,
                  _services,
                  _companyId,
                  po,
                  a,
                ),
                eInvoiceType: companySnap.data?.settings.eInvoiceType,
              ),
            ),
      ),
      bodyBuilder: (context, po) => _Body(
        purchaseOrder: po,
        services: _services,
        companyId: _companyId,
        formatter: formatter,
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.purchaseOrder,
    required this.services,
    required this.companyId,
    this.formatter,
  });

  final PurchaseOrder purchaseOrder;
  final Services services;
  final String companyId;
  final Formatter? formatter;

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
                type: EntityType.purchaseOrder,
                id: purchaseOrder.id,
                label: purchaseOrder.number.isEmpty
                    ? context.tr('purchase_order')
                    : '#${purchaseOrder.number}',
                child: _Header(
                  purchaseOrder: purchaseOrder,
                  formatter: formatter,
                ),
              ),
              SizedBox(height: InSpacing.lg(context)),
              EntityDetailTabs(
                tabs: [
                  EntityDetailTab(
                    label: context.tr('overview'),
                    icon: Icons.dashboard_outlined,
                    bodyBuilder: (_) => Padding(
                      padding: EdgeInsets.all(InSpacing.lg(context)),
                      child: _Overview(
                        purchaseOrder: purchaseOrder,
                        companyId: companyId,
                        formatter: formatter,
                      ),
                    ),
                  ),
                  EntityDetailTab(
                    label: purchaseOrder.documents.isEmpty
                        ? context.tr('documents')
                        : context.tr('documents_with_count', {
                            'count': '${purchaseOrder.documents.length}',
                          }),
                    icon: Icons.description_outlined,
                    bodyBuilder: (_) => EntityDocumentsTab(
                      entityId: purchaseOrder.id,
                      documents: purchaseOrder.documents,
                      onUpload: (sources) async {
                        for (final s in sources) {
                          await services.purchaseOrders.uploadDocument(
                            companyId: companyId,
                            entityId: purchaseOrder.id,
                            source: s,
                          );
                        }
                      },
                      onDelete: (doc) async {
                        await services.purchaseOrders.deleteDocument(
                          companyId: companyId,
                          entityId: purchaseOrder.id,
                          documentId: doc.id,
                        );
                      },
                      onToggleVisibility: (doc) async {
                        await services.purchaseOrders.setDocumentVisibility(
                          companyId: companyId,
                          entityId: purchaseOrder.id,
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
                      entityWireName: 'purchase_order',
                      entityId: purchaseOrder.id,
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
                      entityWireName: 'purchase_order',
                      entityId: purchaseOrder.id,
                      invitations: purchaseOrder.invitations,
                      vendorId: purchaseOrder.vendorId,
                      isHosted: services.auth.session.value?.isHosted ?? false,
                      onReactivate: (messageId) =>
                          services.purchaseOrders.reactivateInvitationEmail(
                            companyId: companyId,
                            id: purchaseOrder.id,
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
            Expanded(flex: 6, child: _PdfPane(purchaseOrder: purchaseOrder)),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.purchaseOrder, this.formatter});
  final PurchaseOrder purchaseOrder;

  /// Company-scoped formatter for money/date. Null until it resolves; callers
  /// fall back to the raw value so the row never renders blank.
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
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
              Text(
                purchaseOrder.number.isEmpty ? '—' : '#${purchaseOrder.number}',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: tokens.ink,
                ),
              ),
              const SizedBox(width: 12),
              PurchaseOrderStatusPill(
                statusId: purchaseOrder.calculatedStatusId,
                hasBounce: purchaseOrder.hasBouncedInvitation,
              ),
            ],
          ),
          const SizedBox(height: 8),
          VendorNameLabel(
            vendorId: purchaseOrder.vendorId,
            link: true,
            style: TextStyle(color: tokens.ink3),
          ),
          const SizedBox(height: 16),
          // Purchase orders are denominated in the *vendor's* currency, not the
          // company default — resolve it once and thread it through the money
          // values (mirrors how invoice/quote detail resolve client currency).
          PartyCurrencyBuilder(
            vendorId: purchaseOrder.vendorId,
            builder: (context, currencyId) => Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                _LabelValue(
                  label: context.tr('amount'),
                  mono: true,
                  value:
                      formatter?.money(
                        purchaseOrder.amount,
                        vendorCurrencyId: currencyId,
                      ) ??
                      purchaseOrder.amount.toString(),
                ),
                _LabelValue(
                  label: context.tr('balance'),
                  mono: true,
                  value:
                      formatter?.money(
                        purchaseOrder.balance,
                        vendorCurrencyId: currencyId,
                      ) ??
                      purchaseOrder.balance.toString(),
                ),
                if (purchaseOrder.dueDate != null)
                  _LabelValue(
                    label: context.tr('due_date'),
                    value:
                        formatter?.date(purchaseOrder.dueDate!.toIso()) ??
                        purchaseOrder.dueDate!.toIso(),
                  ),
                if (purchaseOrder.expenseId.isNotEmpty)
                  _ExpenseLink(expenseId: purchaseOrder.expenseId),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({
    required this.purchaseOrder,
    required this.companyId,
    this.formatter,
  });
  final PurchaseOrder purchaseOrder;
  final String companyId;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final hasCustomFields =
        purchaseOrder.customValue1.isNotEmpty ||
        purchaseOrder.customValue2.isNotEmpty ||
        purchaseOrder.customValue3.isNotEmpty ||
        purchaseOrder.customValue4.isNotEmpty;
    final hasNotes = purchaseOrder.publicNotes.isNotEmpty;
    final hasTerms = purchaseOrder.terms.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (purchaseOrder.tagIds.isNotEmpty) ...[
          Text(
            context.tr('tags'),
            style: TextStyle(
              fontSize: 12,
              color: tokens.ink3,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          EntityTagsView(
            entityType: 'purchase_order',
            tagIds: purchaseOrder.tagIds,
          ),
          if (hasNotes || hasTerms || hasCustomFields)
            SizedBox(height: InSpacing.md(context)),
        ],
        if (hasNotes) ...[
          Text(
            context.tr('public_notes'),
            style: TextStyle(
              fontSize: 12,
              color: tokens.ink3,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            expandDatePlaceholders(
              purchaseOrder.publicNotes,
              formatter: formatter,
            ),
            style: TextStyle(color: tokens.ink),
          ),
        ],
        if (hasTerms) ...[
          if (hasNotes) SizedBox(height: InSpacing.md(context)),
          Text(
            context.tr('terms'),
            style: TextStyle(
              fontSize: 12,
              color: tokens.ink3,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            expandDatePlaceholders(purchaseOrder.terms, formatter: formatter),
            style: TextStyle(color: tokens.ink),
          ),
        ],
        // Purchase orders reuse the `invoice` custom-field config slots — no
        // separate purchase_order keys exist server-side (matches admin-portal).
        if (hasCustomFields) ...[
          if (hasNotes || hasTerms) SizedBox(height: InSpacing.md(context)),
          CustomFieldsDetailCard(
            companyId: companyId,
            prefix: 'invoice',
            values: [
              purchaseOrder.customValue1,
              purchaseOrder.customValue2,
              purchaseOrder.customValue3,
              purchaseOrder.customValue4,
            ],
            formatter: formatter,
          ),
        ],
      ],
    );
  }
}

class _PdfPane extends StatelessWidget {
  const _PdfPane({required this.purchaseOrder});
  final PurchaseOrder purchaseOrder;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    return BillingDocPdfView(
      entity: BillingDocType.purchaseOrder,
      entityNumber: purchaseOrder.number,
      fetcher: ({String? designId, required bool deliveryNote}) =>
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

class _LabelValue extends StatelessWidget {
  const _LabelValue({
    required this.label,
    required this.value,
    this.mono = false,
  });
  final String label;
  final String value;

  /// Render the value in the mono money typeface. Money fields (amount,
  /// balance) set this; the date field keeps the sans UI font.
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: tokens.ink3)),
        const SizedBox(height: 2),
        Text(
          value,
          style: mono
              ? moneyTextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: tokens.ink,
                )
              : TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: tokens.ink,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
        ),
      ],
    );
  }
}

/// "Expense" header field rendered as a tappable link to the converted
/// expense (`/expenses/<id>`), instead of a raw UUID. Shown only when the PO
/// has been converted (`expenseId` set).
class _ExpenseLink extends StatelessWidget {
  const _ExpenseLink({required this.expenseId});
  final String expenseId;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.tr('expense'),
          style: TextStyle(fontSize: 11, color: tokens.ink3),
        ),
        const SizedBox(height: 2),
        InkWell(
          onTap: () => context.go('/expenses/$expenseId'),
          child: Text(
            // `view_expense_label`: `view_expense` is "View expense # :expense"
            // and no number is substituted here.
            context.tr('view_expense_label'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}
