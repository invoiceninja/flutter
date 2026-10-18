import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/document_record.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/detail_scroll_scope.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/detail/entity_detail_scaffold.dart';
import 'package:admin/ui/core/detail/entity_list_empty_action.dart';
import 'package:admin/ui/core/detail/entity_record_column.dart';
import 'package:admin/ui/core/detail/record_screen_controller.dart';
import 'package:admin/ui/core/widgets/centered_form_column.dart';
import 'package:admin/ui/core/widgets/formatter_host_mixin.dart';
import 'package:admin/ui/features/documents/view_models/document_detail_view_model.dart';
import 'package:admin/ui/features/documents/widgets/detail/document_detail_header.dart';
import 'package:admin/ui/features/documents/widgets/detail/document_detail_profile.dart';
import 'package:admin/ui/features/documents/widgets/detail/document_preview_card.dart';
import 'package:admin/ui/features/documents/widgets/document_actions.dart';

/// The record screen for one uploaded file: its identity, a Details card
/// (what it is attached to, type, size, uploader, dates) and an inline
/// preview. No tabs and no standing card — a file has no related lists and
/// no figures (`docs/detail-screen-layout.md`).
class DocumentDetailScreen extends StatefulWidget {
  const DocumentDetailScreen({required this.id, super.key});
  final String id;

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen>
    with FormatterHostMixin {
  late final DocumentDetailViewModel _vm;
  late final RecordScreenController _record;
  late final Services _services;
  late final String _companyId;

  @override
  void initState() {
    super.initState();
    _services = context.read<Services>();
    _companyId = _services.auth.session.value!.currentCompanyId;
    _vm = DocumentDetailViewModel.bound(
      _services.documents.watch(companyId: _companyId, id: widget.id),
    );
    _record = RecordScreenController(
      services: _services,
      companyId: _companyId,
      routeId: widget.id,
      entityWireName: 'document',
      refreshRecord: (id) =>
          _services.documents.refreshByIds(companyId: _companyId, ids: [id]),
      hasRecord: () => _vm.item != null,
    );
    loadFormatter(_services, _companyId);
  }

  @override
  void dispose() {
    _record.dispose();
    _vm.dispose();
    super.dispose();
  }

  void _dispatch(DocumentRecord d, DocumentAction action) =>
      DocumentActions.dispatch(context, _services, _companyId, d, action);

  @override
  Widget build(BuildContext context) {
    return EntityDetailScaffold<DocumentRecord>(
      id: widget.id,
      vm: _vm,
      // A link to a file the recipient's device has never listed — the
      // normal case for a shared link (`docs/deep-links.md`).
      hydrate: () => _services.documents.ensureLoaded(
        companyId: _companyId,
        id: widget.id,
      ),
      emptyAction: entityListEmptyAction(context, EntityType.document),
      emptyIcon: Icons.description_outlined,
      emptyTitle: context.tr('document'),
      actionsForItem: (context, d) => EntityDetailActionsRow<DocumentAction>(
        items: DocumentActions.itemsFor(context, d, (a) => _dispatch(d, a)),
      ),
      compactTitleForItem: (context, d) => Text(
        d.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: context.inTheme.ink,
          fontWeight: FontWeight.w600,
        ),
      ),
      // The Edit action's own rule (deleted, plan, permission): `E` must not
      // open an editor the menu hides. Read when the key is pressed.
      isReadOnly: (d) => !documentEditable(_services.auth.session.value, d),
      onRefresh: _record.refresh,
      bodyBuilder: (context, d) {
        _record.attach(recordId: d.id, revision: d.updatedAt);
        return _DocumentRecordBody(
          onRefresh: _record.refresh,
          child: EntityRecordColumn(
            header: DocumentDetailHeader(document: d, formatter: formatter),
            profile: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DocumentDetailProfile(document: d, formatter: formatter),
                if (DocumentPreviewCard.canPreview(d)) ...[
                  SizedBox(height: InSpacing.lg(context)),
                  // Keyed on the file so stepping to another record starts a
                  // fresh (debounced) fetch rather than keeping the last one.
                  DocumentPreviewCard(
                    key: ValueKey('preview:${d.id}'),
                    document: d,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The page's one scroll view: centred and capped like every single-column
/// record, scrolled by the controller `EntityDetailScaffold` publishes (it
/// fades the compact title in once the header has gone), and pullable to
/// refresh — `AlwaysScrollableScrollPhysics` because it is handed a
/// controller, which would otherwise make a short record unpullable
/// (`docs/pull-to-refresh.md`).
class _DocumentRecordBody extends StatelessWidget {
  const _DocumentRecordBody({required this.child, required this.onRefresh});

  final Widget child;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        controller: DetailScrollScope.maybeOf(context),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(InSpacing.lg(context)),
        children: [CenteredFormColumn(child: child)],
      ),
    );
  }
}
