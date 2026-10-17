import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/db/dao/document_dao.dart';
import 'package:admin/data/models/domain/document_record.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/entity_list_screen_scaffold.dart';
import 'package:admin/ui/core/list/entity_sort_filter_sheet.dart';
import 'package:admin/ui/core/list/master_detail_layout.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/features/documents/view_models/document_list_view_model.dart';
import 'package:admin/ui/features/documents/widgets/document_actions.dart';
import 'package:admin/ui/features/documents/widgets/document_list_tile.dart';
import 'package:admin/ui/features/documents/widgets/document_token_search_field.dart';

/// `/documents` — every file uploaded anywhere in the company: on an invoice,
/// a client, an expense, the company itself (`docs/documents-list.md`).
///
/// No New button, FAB or `N`: a file is uploaded on its record, so the list
/// has nothing to create (`newRoute: null`).
class DocumentListScreen extends StatelessWidget {
  const DocumentListScreen({super.key});

  static const _basePath = '/documents';

  @override
  Widget build(BuildContext context) {
    return EntityListScreenScaffold<DocumentRecord, DocumentListViewModel>(
      titleKey: 'documents',
      newRoute: null,
      newLabelKey: null,
      emptyIcon: Icons.description_outlined,
      emptyTitleKey: 'no_documents_found',
      buildVm: (services, companyId) => DocumentListViewModel(
        repo: services.documents,
        // Read at tap time, so a plan or permission change applies at once.
        canEdit: (d) => documentEditable(services.auth.session.value, d),
        companyId: companyId,
        navStateDao: services.db.navStateDao,
        userSettings: services.userSettings,
        savedViews: services.savedViews,
      ),
      sortOptions: (context) => [
        SortOption(
          id: DocumentFieldIds.createdAt,
          label: context.tr('created_at'),
        ),
        SortOption(id: DocumentFieldIds.name, label: context.tr('name')),
        SortOption(id: DocumentFieldIds.size, label: context.tr('size')),
        SortOption(
          id: DocumentFieldIds.updatedAt,
          label: context.tr('last_updated'),
        ),
      ],
      searchFieldBuilder: (context, vm, wide) =>
          DocumentTokenSearchField(vm: vm, wide: wide),
      tileBuilder: (context, vm, document, index, options) {
        final isUrlSelected = options.selectedId == document.id;
        return DocumentListTile(
          document: document,
          columns: options.wide ? vm.columns : const [],
          wide: options.wide,
          formatter: options.formatter,
          hideBottomDivider: options.bottomDividerHidden,
          selecting: options.selecting,
          selected: vm.isSelected(document.id) || isUrlSelected,
          urlSelected: isUrlSelected,
          onTap: options.selecting
              ? () => vm.toggleSelected(document.id)
              : isUrlSelected
              ? () => MasterDetailNavScope.requestClose(
                  context,
                  basePath: _basePath,
                )
              : () => goEntityRecord(context, vm.entityType, document.id),
          onLongPress: () => vm.toggleSelected(document.id),
          onSelectTap: () => vm.toggleSelected(document.id),
          onAction: options.selecting
              ? null
              : (action) => DocumentActions.dispatch(
                  context,
                  context.read<Services>(),
                  vm.companyId,
                  document,
                  action,
                ),
        );
      },
      bulkActions: [
        EntityListBulkAction(
          actionId: 'download',
          icon: Icons.download_outlined,
          tooltipKey: 'bulk_download',
          singleSuccessKey: 'exported_data',
          pluralSuccessKey: 'exported_data',
          nothingKey: 'no_documents_to_download',
          onSelection: (ctx, sel) =>
              _downloadSelection(ctx, sel.cast<DocumentRecord>()),
        ),
        const EntityListBulkAction(
          actionId: 'delete',
          icon: Icons.delete_outline,
          tooltipKey: 'delete',
          singleSuccessKey: 'deleted_document',
          pluralSuccessKey: 'deleted_documents',
          nothingKey: 'nothing_to_delete',
        ),
      ],
    );
  }

  /// One request for the whole selection: the server zips the files and
  /// emails a download link (`POST /documents/bulk {action: download}`).
  static Future<void> _downloadSelection(
    BuildContext context,
    List<DocumentRecord> selected,
  ) async {
    final ids = [
      for (final d in selected)
        if (!d.id.startsWith('tmp_')) d.id,
    ];
    if (ids.isEmpty) {
      Notify.info(context, context.tr('no_documents_to_download'));
      return;
    }
    try {
      await context.read<Services>().documents.bulkDownload(ids: ids);
      if (!context.mounted) return;
      Notify.success(context, context.tr('exported_data'));
    } catch (e) {
      if (!context.mounted) return;
      Notify.error(context, context.tr('an_error_occurred'), error: e);
    }
  }
}
