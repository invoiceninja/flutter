import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/services/shared_intake_files.dart';
import 'package:admin/data/services/upload_source.dart';
import 'package:admin/domain/expenses/receipt_scanner.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/document_capture.dart';
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
            allowPhotos: true,
            enabled: !locked,
            onFiles: (sources) => _add(context, sources),
          ),
          for (final source in documents) ...[
            const SizedBox(height: InSpacing.sm),
            _PendingDocumentRow(
              key: ObjectKey(source),
              source: source,
              onRemove: locked ? null : () => vm.removeDocument(source),
              // Receipt reading (docs/receipt-ocr.md): offered while the form
              // can read one, this file hasn't been read, and nothing else is
              // being read; a spinner while this one is.
              reading: vm.readingReceipt == source,
              onRead:
                  !locked &&
                      vm.canReadReceipt &&
                      !vm.isReadingReceipt &&
                      !vm.receiptWasRead(source)
                  ? () => vm.readReceipt(source)
                  : null,
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
    // A photo taken here sits in the app's own folder; one the form doesn't
    // keep is handed straight back. Kept ones are the view model's to release.
    final intake = intakeOf(context);
    final batch = await validateDocumentSources(sources);
    unawaited(releaseCapturedPhotos(intake, batch.rejected));
    if (!context.mounted) {
      unawaited(releaseCapturedPhotos(intake, batch.accepted));
      return;
    }
    for (final notice in batch.rejectNotices) {
      Notify.warning(context, context.tr(notice.key, notice.params));
    }
    if (!vm.addDocuments(batch.accepted)) {
      unawaited(releaseCapturedPhotos(intake, batch.accepted));
    }
  }
}

class _PendingDocumentRow extends StatefulWidget {
  const _PendingDocumentRow({
    super.key,
    required this.source,
    this.onRemove,
    this.onRead,
    this.reading = false,
  });

  final UploadSource source;

  /// Null while a save is in flight (the ✕ shows disabled).
  final VoidCallback? onRemove;

  /// Read this file as a receipt; null when it can't be read now. Shown
  /// only for a file that is a receipt image or PDF by its first bytes.
  final VoidCallback? onRead;

  /// This file is being read as a receipt.
  final bool reading;

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

  /// What a thumbnail can be drawn from — the types every engine decodes.
  static const _thumbnailExts = {'png', 'jpg', 'jpeg', 'gif', 'webp'};

  /// Logical size of the thumbnail; decoded at 3× so it stays sharp.
  static const double _thumbnailSize = 32;

  // Once per file, not per build: the form rebuilds on every keystroke.
  late final Future<int> _length = widget.source.length();

  /// Whether this file is something a receipt can be read from — by its
  /// first bytes ([ReceiptScanner.isReadable]).
  late final Future<bool> _readable = ReceiptScanner.isReadable(widget.source);

  /// Row widths below which the size gives way to the Read button, and the
  /// button to its icon — measured on the row, not the window, which a
  /// sidebar or a two-column form shares.
  static const double _hideSizeBelow = 420;
  static const double _iconOnlyBelow = 340;

  /// A thumbnail of a photo — what lets someone who just took one see it was
  /// the right shot — or the file-type icon for anything else, and whenever
  /// the image can't be read.
  Widget _leading(InTheme tokens, String ext) {
    // In the thumbnail's box either way, so every row's name starts at the
    // same x.
    final icon = SizedBox.square(
      dimension: _thumbnailSize,
      child: Center(
        child: Icon(
          _imageExts.contains(ext)
              ? Icons.image_outlined
              : Icons.description_outlined,
          size: 20,
          color: tokens.ink2,
        ),
      ),
    );
    if (!_thumbnailExts.contains(ext)) return icon;
    final source = widget.source;
    final path = kIsWeb ? null : SharedIntakeFiles.localPathOf(source);
    final ImageProvider? image = source is BytesUploadSource
        ? MemoryImage(source.bytes)
        : path != null
        ? FileImage(File(path))
        : null;
    if (image == null) return icon;
    const decoded = (_thumbnailSize * 3) ~/ 1;
    return ClipRRect(
      borderRadius: BorderRadius.circular(InRadii.r1),
      child: Image(
        image: ResizeImage(image, width: decoded, allowUpscaling: false),
        width: _thumbnailSize,
        height: _thumbnailSize,
        fit: BoxFit.cover,
        excludeFromSemantics: true,
        errorBuilder: (_, _, _) => icon,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final name = widget.source.fileName;
    final dot = name.lastIndexOf('.');
    final ext = dot >= 0 ? name.substring(dot + 1).toLowerCase() : '';
    return Container(
      padding: EdgeInsetsDirectional.only(start: InSpacing.md(context)),
      decoration: BoxDecoration(
        border: Border.all(color: tokens.border),
        borderRadius: BorderRadius.circular(InRadii.r2),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) =>
            _row(context, tokens, name, ext, constraints.maxWidth),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    InTheme tokens,
    String name,
    String ext,
    double width,
  ) {
    final offersRead = widget.onRead != null || widget.reading;
    return Row(
      children: [
        _leading(tokens, ext),
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
            // A narrow row with the Read button can't spare it.
            if (width < _hideSizeBelow && offersRead) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsetsDirectional.only(start: InSpacing.sm),
              child: Text(
                formatSize(size),
                style: TextStyle(color: tokens.ink3),
              ),
            );
          },
        ),
        if (widget.reading)
          const Padding(
            padding: EdgeInsetsDirectional.symmetric(horizontal: 12),
            child: SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (widget.onRead != null)
          FutureBuilder<bool>(
            future: _readable,
            builder: (context, snapshot) {
              if (snapshot.data != true) return const SizedBox.shrink();
              const icon = Icon(Icons.document_scanner_outlined, size: 18);
              if (width < _iconOnlyBelow) {
                return IconButton(
                  tooltip: context.tr('read_receipt'),
                  icon: icon,
                  onPressed: widget.onRead,
                );
              }
              return TextButton.icon(
                onPressed: widget.onRead,
                icon: icon,
                label: Text(context.tr('read_receipt')),
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
    );
  }
}
