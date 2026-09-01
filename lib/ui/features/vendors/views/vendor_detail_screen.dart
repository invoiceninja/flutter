import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/vendor.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/detail_scroll_scope.dart';
import 'package:admin/ui/core/detail/entity_detail_scaffold.dart';
import 'package:admin/ui/core/detail/entity_detail_tabs.dart';
import 'package:admin/ui/core/detail/build_standard_documents_tab.dart';
import 'package:admin/ui/core/detail/entity_list_empty_action.dart';
import 'package:admin/ui/core/widgets/formatter_host_mixin.dart';
import 'package:admin/ui/features/billing_shared/activity/billing_doc_activity_tab.dart';
import 'package:admin/ui/features/billing_shared/ledger/ledger_tab.dart';
import 'package:admin/ui/features/expenses/views/expense_list_screen.dart';
import 'package:admin/ui/features/purchase_orders/views/purchase_order_list_screen.dart';
import 'package:admin/ui/features/recurring_expenses/views/recurring_expense_list_screen.dart';
import 'package:admin/ui/features/vendors/view_models/vendor_detail_view_model.dart';
import 'package:admin/ui/features/vendors/widgets/detail/vendor_detail_actions_row.dart';
import 'package:admin/ui/features/vendors/widgets/detail/vendor_detail_cards.dart';
import 'package:admin/ui/features/vendors/widgets/detail/vendor_detail_header.dart';
import 'package:admin/ui/features/vendors/widgets/detail/vendor_detail_kpi_strip.dart';

class VendorDetailScreen extends StatefulWidget {
  const VendorDetailScreen({required this.id, super.key});
  final String id;

  @override
  State<VendorDetailScreen> createState() => _VendorDetailScreenState();
}

class _VendorDetailScreenState extends State<VendorDetailScreen>
    with FormatterHostMixin {
  late final VendorDetailViewModel _vm;
  late final Services _services;
  late final String _companyId;

  @override
  void initState() {
    super.initState();
    _services = context.read<Services>();
    _companyId = _services.auth.session.value!.currentCompanyId;
    _vm = VendorDetailViewModel(
      repo: _services.vendors,
      companyId: _companyId,
      id: widget.id,
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
    return EntityDetailScaffold<Vendor>(
      id: widget.id,
      vm: _vm,
      hydrate: () =>
          _services.vendors.ensureLoaded(companyId: _companyId, id: widget.id),
      emptyAction: entityListEmptyAction(context, EntityType.vendor),
      emptyIcon: Icons.store_outlined,
      emptyTitle: context.tr('vendor_not_found'),
      emptySubtitle: context.tr('vendor_not_found_subtitle'),
      actionsForItem: (context, v) => VendorDetailActionsRow(
        vendor: v,
        services: _services,
        companyId: _companyId,
      ),
      bodyBuilder: (context, v) {
        // Hide related-entity tabs whose module is disabled for this company.
        final me = _services.auth.session.value?.currentCompany;
        return SingleChildScrollView(
          controller: DetailScrollScope.maybeOf(context),
          padding: EdgeInsets.all(InSpacing.lg(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              VendorDetailHeader(vendor: v, formatter: formatter),
              const SizedBox(height: InSpacing.xl),
              VendorDetailKpiStrip(
                vendor: v,
                companyId: _companyId,
                formatter: formatter,
              ),
              SizedBox(height: InSpacing.lg(context)),
              VendorDetailCardsGrid(vendor: v, formatter: formatter),
              const SizedBox(height: InSpacing.xl),
              EntityDetailTabs(
                tabs: [
                  if (me?.moduleEnabled(EntityType.purchaseOrder) ?? false)
                    EntityDetailTab(
                      label: context.tr('purchase_orders'),
                      icon: Icons.shopping_bag_outlined,
                      bodyBuilder: (_) => PurchaseOrderListScreen(
                        vendorId: v.id,
                        embedded: true,
                      ),
                    ),
                  if (me?.moduleEnabled(EntityType.expense) ?? false)
                    EntityDetailTab(
                      label: context.tr('expenses'),
                      icon: Icons.account_balance_wallet_outlined,
                      bodyBuilder: (_) =>
                          ExpenseListScreen(vendorId: v.id, embedded: true),
                    ),
                  if (me?.moduleEnabled(EntityType.recurringExpense) ?? false)
                    EntityDetailTab(
                      label: context.tr('recurring_expenses'),
                      icon: Icons.event_repeat_outlined,
                      bodyBuilder: (_) => RecurringExpenseListScreen(
                        vendorId: v.id,
                        embedded: true,
                      ),
                    ),
                  EntityDetailTab(
                    label: context.tr('ledger'),
                    icon: Icons.account_balance_outlined,
                    bodyBuilder: (_) => LedgerTab(
                      scope: LedgerScope.vendor,
                      companyId: _companyId,
                      entityId: v.id,
                      formatter: formatter,
                      openingAt: v.createdAt,
                    ),
                  ),
                  buildStandardDocumentsTab(
                    context: context,
                    companyId: _companyId,
                    entityId: v.id,
                    documents: v.documents,
                    repo: _services.vendors,
                    formatter: formatter,
                  ),
                  EntityDetailTab(
                    label: context.tr('activity'),
                    icon: Icons.history_outlined,
                    bodyBuilder: (_) => BillingDocActivityTab(
                      entityWireName: 'vendor',
                      entityId: v.id,
                      companyId: _companyId,
                      activitiesApi: _services.activities,
                      outboxDao: _services.db.outboxDao,
                      formatter: formatter,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
