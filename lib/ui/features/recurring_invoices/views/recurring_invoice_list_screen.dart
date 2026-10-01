import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/db/dao/recurring_invoice_dao.dart';
import 'package:admin/data/models/domain/recurring_invoice.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/entity_list_screen_scaffold.dart';
import 'package:admin/ui/core/list/entity_sort_filter_sheet.dart';
import 'package:admin/ui/core/list/master_detail_layout.dart';
import 'package:admin/ui/features/billing_shared/email/recipient_email_fix.dart';
import 'package:admin/ui/features/invoices/widgets/detail/run_template_dialog.dart';
import 'package:admin/ui/features/recurring_invoices/view_models/recurring_invoice_edit_view_model.dart';
import 'package:admin/ui/features/recurring_invoices/view_models/recurring_invoice_list_view_model.dart';
import 'package:admin/ui/features/recurring_invoices/widgets/increase_prices_dialog.dart';
import 'package:admin/ui/features/recurring_invoices/widgets/recurring_invoice_actions.dart';
import 'package:admin/ui/features/recurring_invoices/widgets/recurring_invoice_list_empty_state.dart';
import 'package:admin/ui/features/recurring_invoices/widgets/recurring_invoice_list_tile.dart';
import 'package:admin/ui/features/recurring_invoices/widgets/recurring_invoice_token_search_field.dart';

class RecurringInvoiceListScreen extends StatelessWidget {
  const RecurringInvoiceListScreen({
    super.key,
    this.clientId,
    this.embedded = false,
  });

  /// When set, the list is filtered to one client.
  final String? clientId;

  /// True when this list lives inside another screen's body.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final cid = clientId;
    return EntityListScreenScaffold<
      RecurringInvoice,
      RecurringInvoiceListViewModel
    >(
      titleKey: 'recurring_invoices',
      newRoute: '/recurring_invoices/new',
      newLabelKey: 'new_recurring_invoice',
      embeddedNewOverride: cid == null
          ? null
          : (ctx) => goEntityCreateFullWidth(
              ctx,
              '/recurring_invoices',
              extra: emptyRecurringInvoice().copyWith(clientId: cid),
            ),
      emptyIcon: Icons.event_repeat_outlined,
      emptyTitleKey: 'no_recurring_invoices_yet',
      wantsFormatter: true,
      embedded: embedded,
      buildVm: (services, companyId) => RecurringInvoiceListViewModel(
        repo: services.recurringInvoices,
        companyId: companyId,
        navStateDao: services.db.navStateDao,
        userSettings: services.userSettings,
        savedViews: services.savedViews,
        clientId: clientId,
      ),
      sortOptions: (context) => [
        SortOption(
          id: RecurringInvoiceFieldIds.number,
          label: context.tr('number'),
        ),
        SortOption(
          id: RecurringInvoiceFieldIds.amount,
          label: context.tr('amount'),
        ),
        SortOption(
          id: RecurringInvoiceFieldIds.clientId,
          label: context.tr('client'),
        ),
        SortOption(
          id: RecurringInvoiceFieldIds.status,
          label: context.tr('status'),
        ),
        SortOption(
          id: RecurringInvoiceFieldIds.nextSendDate,
          label: context.tr('next_send_date'),
        ),
        SortOption(
          id: RecurringInvoiceFieldIds.frequencyId,
          label: context.tr('frequency'),
        ),
        SortOption(
          id: RecurringInvoiceFieldIds.updatedAt,
          label: context.tr('last_updated'),
        ),
      ],
      searchFieldBuilder: (context, vm, wide) =>
          RecurringInvoiceTokenSearchField(vm: vm, wide: wide),
      emptyStateBuilder: (context, vm) =>
          RecurringInvoiceListEmptyState(vm: vm),
      tileBuilder: (context, vm, ri, index, options) {
        final isUrlSelected = options.selectedId == ri.id;
        return RecurringInvoiceListTile(
          recurringInvoice: ri,
          columns: options.wide ? vm.columns : const [],
          wide: options.wide,
          editable: options.editable,
          hideBottomDivider: options.bottomDividerHidden,
          selecting: options.selecting,
          selected: vm.isSelected(ri.id) || isUrlSelected,
          urlSelected: isUrlSelected,
          onTap: options.selecting
              ? () => vm.toggleSelected(ri.id)
              : isUrlSelected
              ? () => MasterDetailNavScope.requestClose(
                  context,
                  basePath: '/recurring_invoices',
                )
              : () => goEntityRecord(context, vm.entityType, ri.id),
          onLongPress: () => vm.toggleSelected(ri.id),
          onSelectTap: () => vm.toggleSelected(ri.id),
          onAction: options.selecting
              ? null
              : (action) => RecurringInvoiceActions.dispatch(
                  context,
                  context.read<Services>(),
                  vm.companyId,
                  ri,
                  action,
                ),
        );
      },
      bulkActions: [
        const EntityListBulkAction(
          actionId: 'archive',
          icon: Icons.archive_outlined,
          tooltipKey: 'archive',
          singleSuccessKey: 'archived_recurring_invoice',
          pluralSuccessKey: 'archived_recurring_invoices',
          nothingKey: 'nothing_to_archive',
        ),
        const EntityListBulkAction(
          actionId: 'restore',
          icon: Icons.unarchive_outlined,
          tooltipKey: 'restore',
          singleSuccessKey: 'restored_recurring_invoice',
          pluralSuccessKey: 'restored_recurring_invoices',
          nothingKey: 'nothing_to_restore',
        ),
        const EntityListBulkAction(
          actionId: 'delete',
          icon: Icons.delete_outline,
          tooltipKey: 'delete',
          singleSuccessKey: 'deleted_recurring_invoice',
          pluralSuccessKey: 'deleted_recurring_invoices',
          nothingKey: 'nothing_to_delete',
        ),
        EntityListBulkAction(
          actionId: 'send_now',
          icon: Icons.send_outlined,
          tooltipKey: 'send_now',
          singleSuccessKey: 'sent_now_recurring_invoice',
          pluralSuccessKey: 'sent_now_recurring_invoices',
          nothingKey: 'nothing_to_send',
          // Send Now emails the invoice it creates — but creates it either
          // way, so the ones whose client has no address are named, not
          // dropped (invoiceninja/ui#3400).
          preflight: (ctx, eligible) =>
              preflightRecipientEmails<RecurringInvoice>(
                ctx,
                ctx.read<Services>(),
                companyId: ctx
                    .read<Services>()
                    .auth
                    .session
                    .value!
                    .currentCompanyId,
                eligible: eligible,
                clientIdOf: (d) => d.clientId,
                invitationsOf: (d) => d.invitations,
                numberOf: (d) => d.number,
                keepUnaddressed: true,
              ),
        ),
        const EntityListBulkAction(
          actionId: 'start',
          icon: Icons.play_arrow_outlined,
          tooltipKey: 'start',
          singleSuccessKey: 'started_recurring_invoice',
          pluralSuccessKey: 'started_recurring_invoices',
          nothingKey: 'nothing_to_start',
        ),
        const EntityListBulkAction(
          actionId: 'stop',
          icon: Icons.stop_outlined,
          tooltipKey: 'stop',
          singleSuccessKey: 'stopped_recurring_invoice',
          pluralSuccessKey: 'stopped_recurring_invoices',
          nothingKey: 'nothing_to_stop',
        ),
        EntityListBulkAction(
          actionId: 'run_template',
          icon: Icons.dashboard_customize_outlined,
          tooltipKey: 'run_template',
          singleSuccessKey: 'ran_template_recurring_invoice',
          pluralSuccessKey: 'ran_template_recurring_invoices',
          nothingKey: 'nothing_to_update',
          prepare: showRunTemplateDialog,
        ),
        const EntityListBulkAction(
          actionId: 'update_prices',
          icon: Icons.refresh_outlined,
          tooltipKey: 'update_prices',
          singleSuccessKey: 'updated_prices',
          pluralSuccessKey: 'updated_prices',
          nothingKey: 'nothing_to_update',
        ),
        EntityListBulkAction(
          actionId: 'increase_prices',
          icon: Icons.trending_up_outlined,
          tooltipKey: 'increase_prices',
          singleSuccessKey: 'updated_prices',
          pluralSuccessKey: 'updated_prices',
          nothingKey: 'nothing_to_update',
          prepare: (ctx) {
            final services = ctx.read<Services>();
            final companyId =
                services.auth.session.value?.currentCompanyId ?? '';
            return showIncreasePricesDialog(
              ctx,
              useCommaAsDecimalPlace:
                  services
                      .formatterIfReady(companyId)
                      ?.settings
                      .useCommaAsDecimalPlace ??
                  false,
            );
          },
        ),
      ],
    );
  }
}
