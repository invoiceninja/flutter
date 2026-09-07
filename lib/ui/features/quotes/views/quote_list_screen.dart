import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/db/dao/quote_dao.dart';
import 'package:admin/data/models/domain/quote.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/entity_list_screen_scaffold.dart';
import 'package:admin/ui/core/list/entity_sort_filter_sheet.dart';
import 'package:admin/ui/core/list/master_detail_layout.dart';
import 'package:admin/ui/features/billing_shared/actions/billing_doc_bulk_pdf.dart';
import 'package:admin/ui/features/billing_shared/billing_doc_type.dart';
import 'package:admin/ui/features/billing_shared/email/billing_doc_email_sheet.dart';
import 'package:admin/ui/features/invoices/widgets/detail/run_template_dialog.dart';
import 'package:admin/ui/features/quotes/view_models/quote_edit_view_model.dart';
import 'package:admin/ui/features/quotes/view_models/quote_list_view_model.dart';
import 'package:admin/ui/features/quotes/widgets/quote_actions.dart';
import 'package:admin/ui/features/quotes/widgets/quote_list_empty_state.dart';
import 'package:admin/ui/features/quotes/widgets/quote_list_tile.dart';
import 'package:admin/ui/features/quotes/widgets/quote_token_search_field.dart';

class QuoteListScreen extends StatelessWidget {
  const QuoteListScreen({
    super.key,
    this.clientId,
    this.projectId,
    this.embedded = false,
  });

  /// When set, the list is filtered to one client.
  final String? clientId;

  /// When set, the list is filtered to one project (embedded in the
  /// Project detail screen's Quotes tab).
  final String? projectId;

  /// True when this list lives inside another screen's body (e.g. the
  /// quotes tab on `ClientDetailScreen`).
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final cid = clientId;
    final pid = projectId;
    return EntityListScreenScaffold<Quote, QuoteListViewModel>(
      titleKey: 'quotes',
      newRoute: '/quotes/new',
      newLabelKey: 'new_quote',
      embeddedNewOverride: pid != null
          ? ((ctx) => goEntityCreateFullWidth(
              ctx,
              '/quotes',
              extra: emptyQuote().copyWith(projectId: pid),
            ))
          : cid == null
          ? null
          : (ctx) => goEntityCreateFullWidth(
              ctx,
              '/quotes',
              extra: emptyQuote().copyWith(clientId: cid),
            ),
      emptyIcon: Icons.request_quote_outlined,
      emptyTitleKey: 'no_quotes_yet',
      wantsFormatter: true,
      embedded: embedded,
      buildVm: (services, companyId) => QuoteListViewModel(
        repo: services.quotes,
        companyId: companyId,
        navStateDao: services.db.navStateDao,
        userSettings: services.userSettings,
        savedViews: services.savedViews,
        clientId: clientId,
        projectId: projectId,
      ),
      sortOptions: (context) => [
        SortOption(id: QuoteFieldIds.number, label: context.tr('number')),
        SortOption(id: QuoteFieldIds.date, label: context.tr('quote_date')),
        SortOption(id: QuoteFieldIds.dueDate, label: context.tr('valid_until')),
        SortOption(id: QuoteFieldIds.amount, label: context.tr('amount')),
        SortOption(id: QuoteFieldIds.clientId, label: context.tr('client')),
        SortOption(id: QuoteFieldIds.status, label: context.tr('status')),
        SortOption(
          id: QuoteFieldIds.updatedAt,
          label: context.tr('last_updated'),
        ),
      ],
      searchFieldBuilder: (context, vm, wide) =>
          QuoteTokenSearchField(vm: vm, wide: wide),
      emptyStateBuilder: (context, vm) => QuoteListEmptyState(vm: vm),
      tileBuilder: (context, vm, quote, index, options) {
        final isUrlSelected = options.selectedId == quote.id;
        return QuoteListTile(
          quote: quote,
          columns: options.wide ? vm.columns : const [],
          wide: options.wide,
          editable: options.editable,
          hideBottomDivider: options.bottomDividerHidden,
          selecting: options.selecting,
          selected: vm.isSelected(quote.id) || isUrlSelected,
          urlSelected: isUrlSelected,
          onTap: options.selecting
              ? () => vm.toggleSelected(quote.id)
              : isUrlSelected
              ? () => MasterDetailNavScope.requestClose(
                  context,
                  basePath: '/quotes',
                )
              : () => goEntityRecord(context, vm.entityType, quote.id),
          onLongPress: () => vm.toggleSelected(quote.id),
          onSelectTap: () => vm.toggleSelected(quote.id),
          onAction: options.selecting
              ? null
              : (action) => QuoteActions.dispatch(
                  context,
                  context.read<Services>(),
                  vm.companyId,
                  quote,
                  action,
                ),
        );
      },
      bulkActions: [
        const EntityListBulkAction(
          actionId: 'archive',
          icon: Icons.archive_outlined,
          tooltipKey: 'archive',
          singleSuccessKey: 'archived_quote',
          pluralSuccessKey: 'archived_quotes',
          nothingKey: 'nothing_to_archive',
        ),
        const EntityListBulkAction(
          actionId: 'restore',
          icon: Icons.unarchive_outlined,
          tooltipKey: 'restore',
          singleSuccessKey: 'restored_quote',
          pluralSuccessKey: 'restored_quotes',
          nothingKey: 'nothing_to_restore',
        ),
        const EntityListBulkAction(
          actionId: 'delete',
          icon: Icons.delete_outline,
          tooltipKey: 'delete',
          singleSuccessKey: 'deleted_quote',
          pluralSuccessKey: 'deleted_quotes',
          nothingKey: 'nothing_to_delete',
        ),
        const EntityListBulkAction(
          actionId: 'mark_sent',
          icon: Icons.send_outlined,
          tooltipKey: 'mark_sent',
          singleSuccessKey: 'marked_sent_quote',
          pluralSuccessKey: 'marked_sent_quotes',
          nothingKey: 'nothing_to_send',
        ),
        const EntityListBulkAction(
          actionId: 'approve',
          icon: Icons.check_circle_outline,
          tooltipKey: 'approve',
          singleSuccessKey: 'approved_quote',
          pluralSuccessKey: 'approved_quotes',
          nothingKey: 'nothing_to_update',
        ),
        const EntityListBulkAction(
          actionId: 'convert_to_invoice',
          icon: Icons.swap_horiz_outlined,
          tooltipKey: 'convert_to_invoice',
          singleSuccessKey: 'converted_quote',
          pluralSuccessKey: 'converted_quotes',
          nothingKey: 'nothing_to_update',
        ),
        EntityListBulkAction(
          actionId: 'email',
          icon: Icons.email_outlined,
          tooltipKey: 'email',
          singleSuccessKey: 'emailed_quote',
          pluralSuccessKey: 'emailed_quotes',
          nothingKey: 'nothing_to_email',
          // A scheduled batch was not emailed. Both branches come back
          // through the same `applyArg`, so the message has to follow the
          // result rather than the action.
          successKeysFor: (arg) =>
              (arg is BillingEmailResult && arg.scheduledFor != null)
              ? ('email_scheduled', 'emails_scheduled')
              : ('emailed_quote', 'emailed_quotes'),
          prepare: (context) => showBillingDocEmailSheet(
            context,
            entity: BillingDocType.quote,
            entityNumber: '',
            formatter: null,
          ),
        ),
        EntityListBulkAction(
          actionId: 'run_template',
          icon: Icons.dashboard_customize_outlined,
          tooltipKey: 'run_template',
          singleSuccessKey: 'ran_template_quote',
          pluralSuccessKey: 'ran_template_quotes',
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
            final items = sel.cast<Quote>();
            return bulkDownloadBillingDocs(
              ctx,
              count: items.length,
              bulkDownload: () => services.quotes.api.bulkDownloadPdf(
                ids: [for (final q in items) q.id],
                idempotencyKey: const Uuid().v4(),
              ),
              singleFetch: () => services.quotes.api.downloadPdf(
                entityJson: items.first.toApiJson(),
                designId: items.first.designId.isEmpty
                    ? null
                    : items.first.designId,
              ),
              singleFileName:
                  'quote_${items.first.number.isEmpty ? items.first.id : items.first.number}.pdf',
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
            final items = sel.cast<Quote>();
            return bulkPrintBillingDocs(
              ctx,
              fetch: () => services.quotes.api.bulkPrintPdf(
                ids: [for (final q in items) q.id],
              ),
            );
          },
        ),
      ],
    );
  }
}
