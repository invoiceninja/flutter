import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/db/dao/credit_dao.dart';
import 'package:admin/data/models/domain/credit.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/entity_list_screen_scaffold.dart';
import 'package:admin/ui/core/list/entity_sort_filter_sheet.dart';
import 'package:admin/ui/core/list/master_detail_layout.dart';
import 'package:admin/ui/features/billing_shared/actions/billing_doc_bulk_pdf.dart';
import 'package:admin/ui/features/billing_shared/billing_doc_type.dart';
import 'package:admin/ui/features/billing_shared/email/billing_doc_email_sheet.dart';
import 'package:admin/ui/features/credits/view_models/credit_edit_view_model.dart';
import 'package:admin/ui/features/credits/view_models/credit_list_view_model.dart';
import 'package:admin/ui/features/credits/widgets/credit_actions.dart';
import 'package:admin/ui/features/credits/widgets/credit_list_empty_state.dart';
import 'package:admin/ui/features/credits/widgets/credit_list_tile.dart';
import 'package:admin/ui/features/credits/widgets/credit_token_search_field.dart';
import 'package:admin/ui/features/invoices/widgets/detail/run_template_dialog.dart';

class CreditListScreen extends StatelessWidget {
  const CreditListScreen({super.key, this.clientId, this.embedded = false});

  /// When set, the list is filtered to one client.
  final String? clientId;

  /// True when this list lives inside another screen's body.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final cid = clientId;
    return EntityListScreenScaffold<Credit, CreditListViewModel>(
      titleKey: 'credits',
      newRoute: '/credits/new',
      newLabelKey: 'new_credit',
      embeddedNewOverride: cid == null
          ? null
          : (ctx) => goEntityCreateFullWidth(
              ctx,
              '/credits',
              extra: emptyCredit().copyWith(clientId: cid),
            ),
      emptyIcon: Icons.assignment_return_outlined,
      emptyTitleKey: 'no_credits_yet',
      wantsFormatter: true,
      embedded: embedded,
      buildVm: (services, companyId) => CreditListViewModel(
        repo: services.credits,
        companyId: companyId,
        navStateDao: services.db.navStateDao,
        userSettings: services.userSettings,
        savedViews: services.savedViews,
        clientId: clientId,
      ),
      sortOptions: (context) => [
        SortOption(id: CreditFieldIds.number, label: context.tr('number')),
        SortOption(id: CreditFieldIds.date, label: context.tr('credit_date')),
        SortOption(id: CreditFieldIds.dueDate, label: context.tr('due_date')),
        SortOption(id: CreditFieldIds.amount, label: context.tr('amount')),
        SortOption(id: CreditFieldIds.balance, label: context.tr('balance')),
        SortOption(id: CreditFieldIds.clientId, label: context.tr('client')),
        SortOption(id: CreditFieldIds.status, label: context.tr('status')),
        SortOption(
          id: CreditFieldIds.updatedAt,
          label: context.tr('last_updated'),
        ),
      ],
      searchFieldBuilder: (context, vm, wide) =>
          CreditTokenSearchField(vm: vm, wide: wide),
      emptyStateBuilder: (context, vm) => CreditListEmptyState(vm: vm),
      tileBuilder: (context, vm, credit, index, options) {
        final isUrlSelected = options.selectedId == credit.id;
        return CreditListTile(
          credit: credit,
          columns: options.wide ? vm.columns : const [],
          wide: options.wide,
          editable: options.editable,
          hideBottomDivider: options.bottomDividerHidden,
          selecting: options.selecting,
          selected: vm.isSelected(credit.id) || isUrlSelected,
          urlSelected: isUrlSelected,
          onTap: options.selecting
              ? () => vm.toggleSelected(credit.id)
              : isUrlSelected
              ? () => MasterDetailNavScope.requestClose(
                  context,
                  basePath: '/credits',
                )
              : () => goEntityRecord(context, vm.entityType, credit.id),
          onLongPress: () => vm.toggleSelected(credit.id),
          onSelectTap: () => vm.toggleSelected(credit.id),
          onAction: options.selecting
              ? null
              : (action) => CreditActions.dispatch(
                  context,
                  context.read<Services>(),
                  vm.companyId,
                  credit,
                  action,
                ),
        );
      },
      bulkActions: [
        const EntityListBulkAction(
          actionId: 'archive',
          icon: Icons.archive_outlined,
          tooltipKey: 'archive',
          singleSuccessKey: 'archived_credit',
          pluralSuccessKey: 'archived_credits',
          nothingKey: 'nothing_to_archive',
        ),
        const EntityListBulkAction(
          actionId: 'restore',
          icon: Icons.unarchive_outlined,
          tooltipKey: 'restore',
          singleSuccessKey: 'restored_credit',
          pluralSuccessKey: 'restored_credits',
          nothingKey: 'nothing_to_restore',
        ),
        const EntityListBulkAction(
          actionId: 'delete',
          icon: Icons.delete_outline,
          tooltipKey: 'delete',
          singleSuccessKey: 'deleted_credit',
          pluralSuccessKey: 'deleted_credits',
          nothingKey: 'nothing_to_delete',
        ),
        const EntityListBulkAction(
          actionId: 'mark_sent',
          icon: Icons.send_outlined,
          tooltipKey: 'mark_sent',
          singleSuccessKey: 'marked_sent_credit',
          pluralSuccessKey: 'marked_sent_credits',
          nothingKey: 'nothing_to_send',
        ),
        EntityListBulkAction(
          actionId: 'email',
          icon: Icons.email_outlined,
          tooltipKey: 'email',
          singleSuccessKey: 'emailed_credit',
          pluralSuccessKey: 'emailed_credits',
          nothingKey: 'nothing_to_email',
          // A scheduled batch was not emailed. Both branches come back
          // through the same `applyArg`, so the message has to follow the
          // result rather than the action.
          successKeysFor: (arg) =>
              (arg is BillingEmailResult && arg.scheduledFor != null)
              ? ('email_scheduled', 'emails_scheduled')
              : ('emailed_credit', 'emailed_credits'),
          prepare: (context) => showBillingDocEmailSheet(
            context,
            entity: BillingDocType.credit,
            entityNumber: '',
            formatter: null,
          ),
        ),
        EntityListBulkAction(
          actionId: 'run_template',
          icon: Icons.dashboard_customize_outlined,
          tooltipKey: 'run_template',
          singleSuccessKey: 'ran_template_credit',
          pluralSuccessKey: 'ran_template_credits',
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
            final items = sel.cast<Credit>();
            return bulkDownloadBillingDocs(
              ctx,
              count: items.length,
              bulkDownload: () => services.credits.api.bulkDownloadPdf(
                ids: [for (final c in items) c.id],
                idempotencyKey: const Uuid().v4(),
              ),
              singleFetch: () => services.credits.api.downloadPdf(
                entityJson: items.first.toApiJson(),
                designId: items.first.designId.isEmpty
                    ? null
                    : items.first.designId,
              ),
              singleFileName:
                  'credit_${items.first.number.isEmpty ? items.first.id : items.first.number}.pdf',
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
            final items = sel.cast<Credit>();
            return bulkPrintBillingDocs(
              ctx,
              fetch: () => services.credits.api.bulkPrintPdf(
                ids: [for (final c in items) c.id],
              ),
            );
          },
        ),
      ],
    );
  }
}
