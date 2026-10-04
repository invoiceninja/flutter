import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/services/upload_source.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/file_drop_zone.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/ui/features/expenses/view_models/expense_edit_view_model.dart';
import 'package:admin/utils/document_upload_validation.dart';
import 'package:admin/utils/formatting.dart';

/// Whether New Expense shows its Documents card: on a new expense only (an
/// existing one's documents live on the detail screen), and only where
/// attachments are allowed at all ([AuthSession.canAttachDocuments]) — a
/// hosted plan without them gets no card rather than an upsell on every new
/// expense. The layout calls this so the card's gap goes with it.
bool showsExpenseDocumentsCard({
  required bool isCreate,
  required AuthSession? session,
}) => isCreate && (session?.canAttachDocuments ?? true);

/// Files to attach to a new expense, uploaded as its documents on Save
/// (invoiceninja/flutter#173). Where a receipt shared into the app from
/// another one shows up, and where one can be picked or dropped while the
/// expense is being written — before this, the only way was to save first and
/// upload from the detail screen's Documents tab.
///
/// Every file stays removable until the expense saves: each Save queues
/// exactly what the card lists (`ExpenseEditViewModel`), so a rejected save
/// leaves the list as it was rather than emptying it into the outbox. Locked
/// while a save is in flight or waiting on the user, and once the record
/// turns out to exist already — a file added or removed then would not match
/// what that attempt queued. (A file *shared* in while a save is out still
/// lands: the view model sends it after that attempt.)
class ExpenseEditDocumentsSection extends StatelessWidget {
  const ExpenseEditDocumentsSection({super.key, required this.vm});

  final ExpenseEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final documents = vm.documents;
    final locked = vm.isSaving || !vm.acceptsDocuments;
    return DashboardCardShell(
      title: context.tr('documents'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          FileDropZone(
            allowedExtensions: kDocumentAllowedExtensions,
            allowMultiple: true,
            enabled: !locked,
            onFiles: (sources) => _add(context, sources),
          ),
          for (final source in documents) ...[
            const SizedBox(height: InSpacing.sm),
            _PendingDocumentRow(
              key: ObjectKey(source),
              source: source,
              onRemove: locked ? null : () => vm.removeDocument(source),
            ),
          ],
          if (documents.isNotEmpty) ...[
            const SizedBox(height: InSpacing.sm),
            Text(
              context.tr('documents_upload_on_save'),
              style: TextStyle(color: tokens.ink3, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _add(BuildContext context, List<UploadSource> sources) async {
    final batch = await validateDocumentSources(sources);
    if (!context.mounted) return;
    for (final notice in batch.rejectNotices) {
      Notify.warning(context, context.tr(notice.key, notice.params));
    }
    vm.addDocuments(batch.accepted);
  }
}

class _PendingDocumentRow extends StatefulWidget {
  const _PendingDocumentRow({super.key, required this.source, this.onRemove});

  final UploadSource source;

  /// Null while a save is in flight (the ✕ shows disabled).
  final VoidCallback? onRemove;

  @override
  State<_PendingDocumentRow> createState() => _PendingDocumentRowState();
}

class _PendingDocumentRowState extends State<_PendingDocumentRow> {
  static const _imageExts = {
    'png',
    'jpg',
    'jpeg',
    'gif',
    'webp',
    'heic',
    'svg',
  };

  // Once per file, not per build: the form rebuilds on every keystroke.
  late final Future<int> _length = widget.source.length();

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final name = widget.source.fileName;
    final dot = name.lastIndexOf('.');
    final ext = dot >= 0 ? name.substring(dot + 1).toLowerCase() : '';
    return Container(
      padding: EdgeInsets.only(left: InSpacing.md(context)),
      decoration: BoxDecoration(
        border: Border.all(color: tokens.border),
        borderRadius: BorderRadius.circular(InRadii.r2),
      ),
      child: Row(
        children: [
          Icon(
            _imageExts.contains(ext)
                ? Icons.image_outlined
                : Icons.description_outlined,
            size: 20,
            color: tokens.ink2,
          ),
          SizedBox(width: InSpacing.md(context)),
          Expanded(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: tokens.ink),
            ),
          ),
          FutureBuilder<int>(
            future: _length,
            builder: (context, snapshot) {
              final size = snapshot.data ?? 0;
              if (size <= 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(left: InSpacing.sm),
                child: Text(
                  formatSize(size),
                  style: TextStyle(color: tokens.ink3),
                ),
              );
            },
          ),
          IconButton(
            tooltip: context.tr('remove'),
            icon: const Icon(Icons.close),
            // Null while a save is in flight: disabled, not hidden.
            onPressed: widget.onRemove,
          ),
        ],
      ),
    );
  }
}
