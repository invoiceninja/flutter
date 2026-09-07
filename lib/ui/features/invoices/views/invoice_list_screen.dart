import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/db/dao/invoice_dao.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/entity_list_screen_scaffold.dart';
import 'package:admin/ui/core/list/entity_sort_filter_sheet.dart';
import 'package:admin/ui/core/list/master_detail_layout.dart';
import 'package:admin/ui/features/billing_shared/actions/billing_doc_bulk_pdf.dart';
import 'package:admin/ui/features/billing_shared/billing_doc_type.dart';
import 'package:admin/ui/features/billing_shared/email/billing_doc_email_sheet.dart';
import 'package:admin/ui/features/invoices/view_models/invoice_edit_view_model.dart';
import 'package:admin/ui/features/invoices/view_models/invoice_list_view_model.dart';
import 'package:admin/ui/features/invoices/widgets/detail/run_template_dialog.dart';
import 'package:admin/ui/features/invoices/widgets/invoice_actions.dart';
import 'package:admin/ui/features/invoices/widgets/invoice_list_empty_state.dart';
import 'package:admin/ui/features/invoices/widgets/invoice_list_tile.dart';
import 'package:admin/ui/features/invoices/widgets/invoice_token_search_field.dart';

/// Invoices list screen — pure config + per-entity widgets. Mirrors
/// `ExpenseListScreen`; the screen-level chrome lives in
/// `EntityListScreenScaffold`. M2 adds the status-filter chip strip via
/// the scaffold's `extraAppBarActions` slot; M3 adds the sticky-totals
/// footer.
///
/// The same widget powers the embedded list inside `ClientDetailScreen`'s
/// Invoices tab — pass [clientId] to scope to one client and [embedded]
/// to suppress the outer Scaffold + AppBar.
class InvoiceListScreen extends StatelessWidget {
  const InvoiceListScreen({
    super.key,
    this.clientId,
    this.projectId,
    this.embedded = false,
  });

  /// When set, the list is filtered to one client.
  final String? clientId;

  /// When set, the list is filtered to one project (embedded in the
  /// Project detail screen's Invoices tab).
  final String? projectId;

  /// True when this list lives inside another screen's body (e.g. the
  /// invoices tab on `ClientDetailScreen`). Skips the outer Scaffold
  /// chrome.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final cid = clientId;
    final pid = projectId;
    return EntityListScreenScaffold<Invoice, InvoiceListViewModel>(
      titleKey: 'invoices',
      newRoute: '/invoices/new',
      newLabelKey: 'new_invoice',
      embeddedNewOverride: pid != null
          ? ((ctx) => goEntityCreateFullWidth(
              ctx,
              '/invoices',
              extra: emptyInvoice().copyWith(projectId: pid),
            ))
          : cid == null
          ? null
          : (ctx) => goEntityCreateFullWidth(
              ctx,
              '/invoices',
              extra: emptyInvoice().copyWith(clientId: cid),
            ),
      emptyIcon: Icons.receipt_long_outlined,
      emptyTitleKey: 'no_invoices_yet',
      wantsFormatter: true,
      embedded: embedded,
      buildVm: (services, companyId) => InvoiceListViewModel(
        repo: services.invoices,
        companyId: companyId,
        navStateDao: services.db.navStateDao,
        userSettings: services.userSettings,
        savedViews: services.savedViews,
        clientId: clientId,
        projectId: projectId,
      ),
      sortOptions: (context) => [
        SortOption(id: InvoiceFieldIds.number, label: context.tr('number')),
        SortOption(id: InvoiceFieldIds.date, label: context.tr('invoice_date')),
        SortOption(id: InvoiceFieldIds.dueDate, label: context.tr('due_date')),
        SortOption(id: InvoiceFieldIds.amount, label: context.tr('amount')),
        SortOption(id: InvoiceFieldIds.balance, label: context.tr('balance')),
        SortOption(id: InvoiceFieldIds.clientId, label: context.tr('client')),
        SortOption(id: InvoiceFieldIds.status, label: context.tr('status')),
        SortOption(
          id: InvoiceFieldIds.updatedAt,
          label: context.tr('last_updated'),
        ),
      ],
      searchFieldBuilder: (context, vm, wide) =>
          InvoiceTokenSearchField(vm: vm, wide: wide),
      emptyStateBuilder: (context, vm) => InvoiceListEmptyState(vm: vm),
      tileBuilder: (context, vm, invoice, index, options) {
        final isUrlSelected = options.selectedId == invoice.id;
        return InvoiceListTile(
          invoice: invoice,
          columns: options.wide ? vm.columns : const [],
          wide: options.wide,
          editable: options.editable,
          hideBottomDivider: options.bottomDividerHidden,
          selecting: options.selecting,
          selected: vm.isSelected(invoice.id) || isUrlSelected,
          urlSelected: isUrlSelected,
          onTap: options.selecting
              ? () => vm.toggleSelected(invoice.id)
              : isUrlSelected
              ? () => MasterDetailNavScope.requestClose(
                  context,
                  basePath: '/invoices',
                )
              : () => goEntityRecord(context, vm.entityType, invoice.id),
          onLongPress: () => vm.toggleSelected(invoice.id),
          onSelectTap: () => vm.toggleSelected(invoice.id),
          onAction: options.selecting
              ? null
              : (action) => InvoiceActions.dispatch(
                  context,
                  context.read<Services>(),
                  vm.companyId,
                  invoice,
                  action,
                ),
        );
      },
      bulkActions: [
        const EntityListBulkAction(
          actionId: 'archive',
          icon: Icons.archive_outlined,
          tooltipKey: 'archive',
          singleSuccessKey: 'archived_invoice',
          pluralSuccessKey: 'archived_invoices',
          nothingKey: 'nothing_to_archive',
        ),
        const EntityListBulkAction(
          actionId: 'restore',
          icon: Icons.unarchive_outlined,
          tooltipKey: 'restore',
          singleSuccessKey: 'restored_invoice',
          pluralSuccessKey: 'restored_invoices',
          nothingKey: 'nothing_to_restore',
        ),
        const EntityListBulkAction(
          actionId: 'delete',
          icon: Icons.delete_outline,
          tooltipKey: 'delete',
          singleSuccessKey: 'deleted_invoice',
          pluralSuccessKey: 'deleted_invoices',
          nothingKey: 'nothing_to_delete',
        ),
        const EntityListBulkAction(
          actionId: 'mark_sent',
          icon: Icons.send_outlined,
          tooltipKey: 'mark_sent',
          singleSuccessKey: 'marked_sent_invoice',
          pluralSuccessKey: 'marked_sent_invoices',
          nothingKey: 'nothing_to_send',
        ),
        const EntityListBulkAction(
          actionId: 'mark_paid',
          icon: Icons.price_check_outlined,
          tooltipKey: 'mark_paid',
          singleSuccessKey: 'marked_paid_invoice',
          pluralSuccessKey: 'marked_paid_invoices',
          nothingKey: 'nothing_to_update',
        ),
        const EntityListBulkAction(
          actionId: 'auto_bill',
          icon: Icons.autorenew_outlined,
          tooltipKey: 'auto_bill',
          singleSuccessKey: 'auto_billed_invoice',
          pluralSuccessKey: 'auto_billed_invoices',
          nothingKey: 'nothing_to_update',
        ),
        EntityListBulkAction(
          actionId: 'email',
          icon: Icons.email_outlined,
          tooltipKey: 'email',
          singleSuccessKey: 'emailed_invoice',
          pluralSuccessKey: 'emailed_invoices',
          nothingKey: 'nothing_to_email',
          // A scheduled batch was not emailed. Both branches come back
          // through the same `applyArg`, so the message has to follow the
          // result rather than the action.
          successKeysFor: (arg) =>
              (arg is BillingEmailResult && arg.scheduledFor != null)
              ? ('email_scheduled', 'emails_scheduled')
              : ('emailed_invoice', 'emailed_invoices'),
          prepare: (context) => showBillingDocEmailSheet(
            context,
            entity: BillingDocType.invoice,
            entityNumber: '',
            formatter: null,
          ),
        ),
        EntityListBulkAction(
          actionId: 'run_template',
          icon: Icons.dashboard_customize_outlined,
          tooltipKey: 'run_template',
          singleSuccessKey: 'ran_template_invoice',
          pluralSuccessKey: 'ran_template_invoices',
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
            final items = sel.cast<Invoice>();
            return bulkDownloadBillingDocs(
              ctx,
              count: items.length,
              bulkDownload: () => services.invoices.api.bulkDownloadPdf(
                ids: [for (final i in items) i.id],
                idempotencyKey: const Uuid().v4(),
              ),
              singleFetch: () => services.invoices.api.downloadPdf(
                entityJson: items.first.toApiJson(),
                designId: items.first.designId.isEmpty
                    ? null
                    : items.first.designId,
              ),
              singleFileName:
                  'invoice_${items.first.number.isEmpty ? items.first.id : items.first.number}.pdf',
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
            final items = sel.cast<Invoice>();
            return bulkPrintBillingDocs(
              ctx,
              fetch: () => services.invoices.api.bulkPrintPdf(
                ids: [for (final i in items) i.id],
              ),
            );
          },
        ),
      ],
    );
  }
}
