import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/vendor.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/phone/phone_candidates.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/detail_scroll_scope.dart';
import 'package:admin/ui/core/detail/entity_detail_scaffold.dart';
import 'package:admin/ui/core/detail/entity_detail_tabs.dart';
import 'package:admin/ui/core/detail/build_standard_documents_tab.dart';
import 'package:admin/ui/core/detail/entity_list_empty_action.dart';
import 'package:admin/ui/core/widgets/formatter_host_mixin.dart';
import 'package:admin/ui/core/detail/activity_note_actions.dart';
import 'package:admin/ui/features/billing_shared/activity/entity_activity_tab.dart';
import 'package:admin/ui/features/billing_shared/activity/entity_activity_view_model.dart';
import 'package:admin/ui/features/billing_shared/activity/entity_comments_card.dart';
import 'package:admin/ui/core/detail/activity_note_buttons.dart';
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
  late final EntityActivityViewModel _activityVm;
  late final Services _services;
  late final String _companyId;
  final TabSelectionController _selectTab = TabSelectionController();

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
    // Owned here, not by the Activity tab, so the Comments card, the Comments
    // tab and the Activity tab share one fetch. Armed from `bodyBuilder`.
    _activityVm = EntityActivityViewModel(
      api: _services.activities,
      outbox: _services.db.outboxDao,
      companyId: _companyId,
      entityWireName: 'vendor',
      entityId: widget.id,
    );
    loadFormatter(_services, _companyId);
  }

  @override
  void dispose() {
    _activityVm.dispose();
    _selectTab.dispose();
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
        _activityVm.kick();
        Future<void> submit(String text) => _services.vendors.addComment(
          companyId: _companyId,
          vendorId: v.id,
          text: text,
        );
        // Built here rather than in `initState`: `promptLogCallFor` needs a
        // subject and phone candidates off the resolved record.
        final notes = EntityNoteActions(
          onAddComment: () =>
              promptAddCommentFor(context, entityId: v.id, submit: submit),
          onLogCall: () => promptLogCallFor(
            context,
            companyId: _companyId,
            entityId: v.id,
            subject: v.name,
            candidates: vendorPhoneCandidates(v),
            submit: submit,
          ),
        );
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
              EntityCommentsCard(
                vm: _activityVm,
                formatter: formatter,
                actions: notes,
                hostWireName: 'vendor',
                onViewAll: () => _selectTab.select(0),
                matchFormColumn: true,
              ),
              VendorDetailCardsGrid(vendor: v, formatter: formatter),
              const SizedBox(height: InSpacing.xl),
              EntityDetailTabs(
                initialIndex: 2,
                selectTab: _selectTab,
                tabs: [
                  EntityDetailTab(
                    label: context.tr('comments'),
                    icon: Icons.comment_outlined,
                    bodyBuilder: (_) => EntityActivityTab(
                      vm: _activityVm,
                      formatter: formatter,
                      actions: notes,
                      commentsOnly: true,
                      hostWireName: 'vendor',
                    ),
                  ),
                  EntityDetailTab(
                    label: context.tr('activity'),
                    icon: Icons.history_outlined,
                    bodyBuilder: (_) => EntityActivityTab(
                      vm: _activityVm,
                      formatter: formatter,
                      actions: notes,
                      hostWireName: 'vendor',
                    ),
                  ),
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
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
