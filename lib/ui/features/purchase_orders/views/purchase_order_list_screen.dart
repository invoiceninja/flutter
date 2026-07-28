import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/db/dao/purchase_order_dao.dart';
import 'package:admin/data/models/domain/purchase_order.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/entity_list_screen_scaffold.dart';
import 'package:admin/ui/core/list/entity_sort_filter_sheet.dart';
import 'package:admin/ui/core/list/master_detail_layout.dart';
import 'package:admin/ui/features/billing_shared/actions/billing_doc_bulk_pdf.dart';
import 'package:admin/ui/features/billing_shared/billing_doc_type.dart';
import 'package:admin/ui/features/billing_shared/email/billing_doc_email_sheet.dart';
import 'package:admin/ui/features/invoices/widgets/detail/run_template_dialog.dart';
import 'package:admin/ui/features/purchase_orders/view_models/purchase_order_edit_view_model.dart';
import 'package:admin/ui/features/purchase_orders/view_models/purchase_order_list_view_model.dart';
import 'package:admin/ui/features/purchase_orders/widgets/purchase_order_actions.dart';
import 'package:admin/ui/features/purchase_orders/widgets/purchase_order_list_empty_state.dart';
import 'package:admin/ui/features/purchase_orders/widgets/purchase_order_list_tile.dart';
import 'package:admin/ui/features/purchase_orders/widgets/purchase_order_token_search_field.dart';

class PurchaseOrderListScreen extends StatelessWidget {
  const PurchaseOrderListScreen({
    super.key,
    this.vendorId,
    this.embedded = false,
  });

  /// When set, the list is filtered to one vendor.
  final String? vendorId;

  /// True when this list lives inside another screen's body.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final vid = vendorId;
    return EntityListScreenScaffold<PurchaseOrder, PurchaseOrderListViewModel>(
      titleKey: 'purchase_orders',
      newRoute: '/purchase_orders/new',
      newLabelKey: 'new_purchase_order',
      embeddedNewOverride: vid == null
          ? null
          : (ctx) => goEntityCreateFullWidth(
              ctx,
              '/purchase_orders',
              extra: emptyPurchaseOrder().copyWith(vendorId: vid),
            ),
      emptyIcon: Icons.shopping_bag_outlined,
      emptyTitleKey: 'no_purchase_orders_yet',
      wantsFormatter: true,
      embedded: embedded,
      buildVm: (services, companyId) => PurchaseOrderListViewModel(
        repo: services.purchaseOrders,
        companyId: companyId,
        navStateDao: services.db.navStateDao,
        userSettings: services.userSettings,
        savedViews: services.savedViews,
        vendorId: vendorId,
      ),
      sortOptions: (context) => [
        SortOption(
          id: PurchaseOrderFieldIds.number,
          label: context.tr('number'),
        ),
        SortOption(id: PurchaseOrderFieldIds.date, label: context.tr('date')),
        SortOption(
          id: PurchaseOrderFieldIds.dueDate,
          label: context.tr('due_date'),
        ),
        SortOption(
          id: PurchaseOrderFieldIds.amount,
          label: context.tr('amount'),
        ),
        SortOption(
          id: PurchaseOrderFieldIds.vendorId,
          label: context.tr('vendor'),
        ),
        SortOption(
          id: PurchaseOrderFieldIds.status,
          label: context.tr('status'),
        ),
        SortOption(
          id: PurchaseOrderFieldIds.updatedAt,
          label: context.tr('last_updated'),
        ),
      ],
      searchFieldBuilder: (context, vm, wide) =>
          PurchaseOrderTokenSearchField(vm: vm, wide: wide),
      emptyStateBuilder: (context, vm) => PurchaseOrderListEmptyState(vm: vm),
      tileBuilder: (context, vm, po, index, options) {
        final isUrlSelected = options.selectedId == po.id;
        return PurchaseOrderListTile(
          purchaseOrder: po,
          columns: options.wide ? vm.columns : const [],
          wide: options.wide,
          editable: options.editable,
          hideBottomDivider: options.bottomDividerHidden,
          selecting: options.selecting,
          selected: vm.isSelected(po.id) || isUrlSelected,
          urlSelected: isUrlSelected,
          onTap: options.selecting
              ? () => vm.toggleSelected(po.id)
              : isUrlSelected
              ? () => MasterDetailNavScope.requestClose(
                  context,
                  basePath: '/purchase_orders',
                )
              : () => goEntityRecord(context, vm.entityType, po.id),
          onLongPress: () => vm.toggleSelected(po.id),
          onSelectTap: () => vm.toggleSelected(po.id),
          onAction: options.selecting
              ? null
              : (action) => PurchaseOrderActions.dispatch(
                  context,
                  context.read<Services>(),
                  vm.companyId,
                  po,
                  action,
                ),
        );
      },
      bulkActions: [
        const EntityListBulkAction(
          actionId: 'archive',
          icon: Icons.archive_outlined,
          tooltipKey: 'archive',
          singleSuccessKey: 'archived_purchase_order',
          pluralSuccessKey: 'archived_purchase_orders',
          nothingKey: 'nothing_to_archive',
        ),
        const EntityListBulkAction(
          actionId: 'restore',
          icon: Icons.unarchive_outlined,
          tooltipKey: 'restore',
          singleSuccessKey: 'restored_purchase_order',
          pluralSuccessKey: 'restored_purchase_orders',
          nothingKey: 'nothing_to_restore',
        ),
        const EntityListBulkAction(
          actionId: 'delete',
          icon: Icons.delete_outline,
          tooltipKey: 'delete',
          singleSuccessKey: 'deleted_purchase_order',
          pluralSuccessKey: 'deleted_purchase_orders',
          nothingKey: 'nothing_to_delete',
        ),
        const EntityListBulkAction(
          actionId: 'mark_sent',
          icon: Icons.send_outlined,
          tooltipKey: 'mark_sent',
          singleSuccessKey: 'marked_sent_purchase_order',
          pluralSuccessKey: 'marked_sent_purchase_orders',
          nothingKey: 'nothing_to_send',
        ),
        // NOT `accept`: a PO is accepted by the vendor through the portal, and
        // the server has no admin accept route (it isn't in
        // `BulkPurchaseOrderRequest`'s allow-list) — see the class doc on
        // `PurchaseOrderActions`. `add_to_inventory` is the real bulk verb the
        // server exposes here, and it matches the row menu's own gate
        // (`canEdit && po.isAccepted`).
        const EntityListBulkAction(
          actionId: 'add_to_inventory',
          icon: Icons.inventory_2_outlined,
          tooltipKey: 'add_to_inventory',
          singleSuccessKey: 'added_to_inventory_purchase_order',
          pluralSuccessKey: 'added_to_inventory_purchase_orders',
          nothingKey: 'nothing_to_update',
        ),
        const EntityListBulkAction(
          actionId: 'convert_to_expense',
          icon: Icons.swap_horiz_outlined,
          tooltipKey: 'convert_to_expense',
          singleSuccessKey: 'converted_purchase_order',
          pluralSuccessKey: 'converted_purchase_orders',
          nothingKey: 'nothing_to_update',
        ),
        EntityListBulkAction(
          actionId: 'email',
          icon: Icons.email_outlined,
          tooltipKey: 'email',
          singleSuccessKey: 'emailed_purchase_order',
          pluralSuccessKey: 'emailed_purchase_orders',
          nothingKey: 'nothing_to_email',
          prepare: (context) => showBillingDocEmailSheet(
            context,
            entity: BillingDocType.purchaseOrder,
            entityNumber: '',
            formatter: null,
          ),
        ),
        EntityListBulkAction(
          actionId: 'run_template',
          icon: Icons.dashboard_customize_outlined,
          tooltipKey: 'run_template',
          singleSuccessKey: 'ran_template_purchase_order',
          pluralSuccessKey: 'ran_template_purchase_orders',
          nothingKey: 'nothing_to_update',
          prepare: showRunTemplateDialog,
        ),
        EntityListBulkAction(
          actionId: 'download_pdf',
          icon: Icons.download_outlined,
          tooltipKey: 'download_pdf',
          singleSuccessKey: 'download_pdf', // unused for onSelection
          pluralSuccessKey: 'download_pdf', // unused for onSelection
          nothingKey: 'nothing_to_download',
          onSelection: (ctx, sel) {
            final services = ctx.read<Services>();
            final items = sel.cast<PurchaseOrder>();
            return bulkDownloadBillingDocs(
              ctx,
              count: items.length,
              bulkDownload: () => services.purchaseOrders.api.bulkDownloadPdf(
                ids: [for (final po in items) po.id],
                idempotencyKey: const Uuid().v4(),
              ),
              singleFetch: () => services.purchaseOrders.api.downloadPdf(
                entityJson: items.first.toApiJson(),
                designId: items.first.designId.isEmpty
                    ? null
                    : items.first.designId,
              ),
              singleFileName:
                  'purchase_order_${items.first.number.isEmpty ? items.first.id : items.first.number}.pdf',
            );
          },
        ),
        EntityListBulkAction(
          actionId: 'print_pdf',
          icon: Icons.print_outlined,
          tooltipKey: 'print_pdf',
          singleSuccessKey: 'print_pdf', // unused for onSelection
          pluralSuccessKey: 'print_pdf', // unused for onSelection
          nothingKey: 'nothing_to_print',
          onSelection: (ctx, sel) {
            final services = ctx.read<Services>();
            final items = sel.cast<PurchaseOrder>();
            return bulkPrintBillingDocs(
              ctx,
              fetch: () => services.purchaseOrders.api.bulkPrintPdf(
                ids: [for (final po in items) po.id],
              ),
            );
          },
        ),
      ],
    );
  }
}
