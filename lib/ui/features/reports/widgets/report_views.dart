import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/repositories/saved_views_repository.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/dialogs/confirm_action_dialog.dart';
import 'package:admin/ui/core/widgets/back_dismissible_menu_anchor.dart';
import 'package:admin/ui/core/widgets/form_save_scope.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/features/reports/view_models/reports_view_model.dart';

/// The saved views of a report: open one, save the report as it stands as a
/// new one, or bring the one it came from up to date.
///
/// A view is the whole arrangement — range, filters, columns, grouping,
/// sort, the figure charted — under a name. They are kept in the same table
/// as a list's saved views (`kReportSavedViewType`), per company.
///
/// The button says which view the report *is*: filled when it is one, with a
/// dot when it has been changed since. That dot is the whole of "unsaved
/// changes" here — nothing is lost by ignoring it, the report keeps its own
/// state either way.
class ReportViewsButton extends StatefulWidget {
  const ReportViewsButton({super.key, required this.vm});

  final ReportsViewModel vm;

  @override
  State<ReportViewsButton> createState() => _ReportViewsButtonState();
}

class _ReportViewsButtonState extends State<ReportViewsButton> {
  Stream<List<SavedReportView>>? _views;
  String? _companyId;

  @override
  void initState() {
    super.initState();
    _watch();
  }

  @override
  void didUpdateWidget(ReportViewsButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.vm.companyId != _companyId) _watch();
  }

  /// Made here, not in `build`: a stream made there is a new subscription —
  /// and a replayed first event — on every rebuild of the header.
  void _watch() {
    _companyId = widget.vm.companyId;
    final companyId = _companyId;
    _views = companyId == null || companyId.isEmpty
        ? null
        : context.read<Services>().savedViews.watchReportViews(companyId);
  }

  @override
  Widget build(BuildContext context) {
    final stream = _views;
    if (stream == null) return const SizedBox.shrink();
    final vm = widget.vm;
    final tokens = context.inTheme;
    final tr = context.tr;
    return StreamBuilder<List<SavedReportView>>(
      stream: stream,
      builder: (context, snapshot) {
        final mine = [
          for (final v in snapshot.data ?? const <SavedReportView>[])
            if (v.reportIdentifier == vm.reportIdentifier) v,
        ];
        final active = mine.where((v) => v.id == vm.viewId).firstOrNull;
        final changed =
            active != null &&
            !const DeepCollectionEquality().equals(
              active.state,
              vm.reportViewState(),
            );
        return BackDismissibleMenuAnchor(
          menuChildren: [
            for (final view in mine)
              MenuItemButton(
                leadingIcon: Icon(
                  Icons.check,
                  size: 16,
                  color: view.id == active?.id
                      ? tokens.ink2
                      : Colors.transparent,
                ),
                onPressed: () => vm.applyReportView(view.id, view.state),
                child: Text(view.name),
              ),
            if (mine.isNotEmpty) const Divider(height: 1),
            if (active != null && changed)
              MenuItemButton(
                leadingIcon: const Icon(Icons.save_outlined, size: 16),
                onPressed: () => _update(active),
                child: Text('${tr('update_view')}: ${active.name}'),
              ),
            MenuItemButton(
              key: const Key('report-save-view'),
              leadingIcon: const Icon(Icons.bookmark_add_outlined, size: 16),
              onPressed: _saveAs,
              child: Text(tr('save_view')),
            ),
            if (active != null)
              MenuItemButton(
                leadingIcon: const Icon(Icons.delete_outline, size: 16),
                onPressed: () => _delete(active),
                child: Text('${tr('delete_view')}: ${active.name}'),
              ),
          ],
          builder: (context, controller, _) => Semantics(
            // The dot is a state, and a screen reader cannot see a dot.
            label: active == null
                ? tr('saved_views')
                : '${tr('saved_views')}: ${active.name}'
                      '${changed ? ', ${tr('unsaved_changes')}' : ''}',
            button: true,
            onTap: () =>
                controller.isOpen ? controller.close() : controller.open(),
            child: ExcludeSemantics(
              child: IconButton(
                key: const Key('report-views'),
                tooltip: active?.name ?? tr('saved_views'),
                onPressed: () =>
                    controller.isOpen ? controller.close() : controller.open(),
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      active == null ? Icons.bookmark_border : Icons.bookmark,
                      size: 20,
                      color: active == null ? tokens.ink2 : tokens.accent,
                    ),
                    if (changed)
                      PositionedDirectional(
                        top: -1,
                        end: -2,
                        child: Container(
                          key: const Key('report-view-changed'),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: tokens.accent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: tokens.surface,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveAs() async {
    final vm = widget.vm;
    final companyId = vm.companyId;
    if (companyId == null || companyId.isEmpty) return;
    final views = context.read<Services>().savedViews;
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const _NameDialog(),
    );
    if (name == null || name.trim().isEmpty) return;
    final created = await views.createReportView(
      companyId: companyId,
      name: name.trim(),
      reportIdentifier: vm.reportIdentifier,
      state: vm.reportViewState(),
    );
    vm.setViewId(created.id);
  }

  Future<void> _update(SavedReportView view) =>
      context.read<Services>().savedViews.updateReportView(
        viewId: view.id,
        reportIdentifier: widget.vm.reportIdentifier,
        state: widget.vm.reportViewState(),
      );

  Future<void> _delete(SavedReportView view) async {
    final services = context.read<Services>();
    if (services.confirmActions.value) {
      final ok = await showConfirmActionDialog(
        context,
        title: context.tr('delete_view'),
        subject: view.name,
        destructive: true,
      );
      if (!ok) return;
    }
    await services.savedViews.delete(view.id);
    // The report stays as it is; it is just nobody's view now.
    if (widget.vm.viewId == view.id) widget.vm.setViewId(null);
  }
}

/// Name a view. Enter saves.
class _NameDialog extends StatefulWidget {
  const _NameDialog();

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  final _name = TextEditingController();

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_name.text.trim());

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final canSave = _name.text.trim().isNotEmpty;
    return FormSaveScope(
      onSubmit: _submit,
      enabled: canSave,
      child: AlertDialog(
        title: Text(tr('save_view')),
        content: SizedBox(
          width: 360,
          child: TextField(
            key: const Key('report-view-name'),
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            // Read from the field, not from this build's `canSave`: Enter
            // can arrive before the rebuild the last keystroke asked for.
            onSubmitted: (_) {
              if (_name.text.trim().isNotEmpty) _submit();
            },
            decoration: InputDecoration(labelText: tr('view_name')),
          ),
        ),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(tr('cancel')),
          ),
          PrimaryDialogAction(
            label: tr('save'),
            // The field owns focus; Enter reaches this through it.
            autofocus: false,
            onPressed: canSave ? _submit : null,
            // A primary that starts disabled cannot promise Enter.
            showEnterHint: false,
          ),
        ],
      ),
    );
  }
}
