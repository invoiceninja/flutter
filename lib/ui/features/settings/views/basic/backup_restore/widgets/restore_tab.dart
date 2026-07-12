import 'dart:io' show FileSystemException;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/services/upload_source.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/file_drop_zone.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/settings/widgets/settings_form_shell.dart';

/// Search keys rendered by this tab.
const kRestoreTabSearchKeys = <String>[
  'restore',
  'import_settings',
  'import_data',
  'company_backup_file',
];

/// Restore tab body — chunked `.zip` upload to `/api/v1/import_json`. The
/// server runs the restore asynchronously and emails the user when it
/// finishes; the success toast here just confirms the upload was accepted.
class RestoreTabBody extends StatefulWidget {
  const RestoreTabBody({super.key});

  @override
  State<RestoreTabBody> createState() => _RestoreTabBodyState();
}

class _RestoreTabBodyState extends State<RestoreTabBody> {
  UploadSource? _source;
  String _fileName = '';
  int _fileLength = 0;
  bool _importSettings = false;
  // Both default off — the user must opt in. import_data drives the server's
  // destructive purge-and-replace, so don't pre-check it (matches React).
  bool _importData = false;
  bool _busy = false;
  bool _cancelRequested = false;
  bool _completedNeedsBanner = false;
  int _sent = 0;
  int _total = 1;

  bool get _canRestore =>
      _source != null && (_importSettings || _importData) && !_busy;

  Future<void> _accept(UploadSource source, String name) async {
    if (!name.toLowerCase().endsWith('.zip')) {
      if (!mounted) return;
      Notify.warning(context, context.tr('dropzone_invalid_file_type'));
      return;
    }
    // Capture length once so the build pass doesn't hit the disk on every
    // frame; also lets us reject 0-byte files before the upload spins
    // forever at 0%.
    int length = 0;
    try {
      length = await source.length();
    } catch (_) {
      length = 0;
    }
    if (length <= 0) {
      if (!mounted) return;
      Notify.warning(context, context.tr('dropzone_invalid_file_type'));
      return;
    }
    // Server caps the restore at 1000 chunks (ImportJsonController); at the 2 MiB
    // client chunk size that's ~1.95 GiB. Reject early instead of 500-ing on the
    // first chunk with a generic error.
    const maxChunks = 1000;
    const chunkMb = 2; // matches uploadMultipartChunked's default chunkBytes
    const maxMb = maxChunks * chunkMb; // 2000
    const maxBytes = maxMb * 1024 * 1024;
    if (length > maxBytes) {
      if (!mounted) return;
      Notify.warning(
        context,
        context.tr('upload_too_large_with_size', {'size': '$maxMb'}),
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      _source = source;
      _fileName = name;
      _fileLength = length;
      _completedNeedsBanner = false;
    });
  }

  Future<void> _onFiles(List<UploadSource> sources) async {
    if (sources.isEmpty) return;
    final source = sources.first;
    await _accept(source, source.fileName);
  }

  Future<void> _confirmAndRestore() async {
    if (!_canRestore) return;
    if (Env.demoMode) {
      Notify.warning(context, context.tr('demo_mode_disabled'));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('restore')),
        content: Text(ctx.tr('restore_confirm_message')),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.tr('cancel')),
          ),
          PrimaryDialogAction(
            label: ctx.tr('continue'),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    await _runUpload();
  }

  Future<void> _runUpload() async {
    final source = _source;
    if (source == null) return;
    final services = context.read<Services>();
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() {
      _busy = true;
      _cancelRequested = false;
      _sent = 0;
      _total = 1;
    });
    final idempotencyKey = const Uuid().v4();
    try {
      await services.apiClient.uploadMultipartChunked(
        path: '/api/v1/import_json',
        source: source,
        commonFields: {
          'import_settings': '$_importSettings',
          'import_data': '$_importData',
        },
        commonQueryTrue: {
          if (_importSettings) 'import_settings': 'true',
          if (_importData) 'import_data': 'true',
        },
        idempotencyKey: idempotencyKey,
        onProgress: (sent, total) {
          if (!mounted) return;
          setState(() {
            _sent = sent;
            _total = total;
          });
        },
        isCancelled: () => _cancelRequested,
      );
      if (!mounted) return;
      Notify.success(
        context,
        context.tr('import_started'),
        messenger: messenger,
      );
      // Keep the file row visible with an inline banner so the user doesn't
      // bounce between "Restore" button and a blank form. They navigate
      // away (or re-pick) to clear.
      setState(() {
        _completedNeedsBanner = true;
        _importSettings = false;
        _importData = false;
      });
    } on UploadCancelledException {
      // User-initiated stop — silent.
    } on DemoModeException {
      if (!mounted) return;
      Notify.warning(
        context,
        context.tr('demo_mode_disabled'),
        messenger: messenger,
      );
    } on FileSystemException {
      // The picked file was deleted/moved between pick and read.
      if (!mounted) return;
      Notify.warning(
        context,
        context.tr('file_no_longer_available'),
        messenger: messenger,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      Notify.error(
        context,
        context.tr('error_title'),
        error: e,
        messenger: messenger,
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _cancelRequested = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsFormShell(
      sections: [
        FormSection(
          title: context.tr('restore'),
          children: [
            if (_source == null)
              FileDropZone(
                allowedExtensions: const ['zip'],
                enabled: !_busy,
                idleLabelKey: 'company_backup_file',
                onFiles: _onFiles,
              )
            else
              Container(
                padding: EdgeInsets.all(InSpacing.lg(context)),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(InRadii.r2),
                  border: Border.all(color: context.inTheme.border),
                ),
                child: _PickedFileRow(
                  name: _fileName,
                  sizeText: _formatBytes(_fileLength),
                  onClear: _busy
                      ? null
                      : () => setState(() {
                          _source = null;
                          _fileName = '';
                          _fileLength = 0;
                          _completedNeedsBanner = false;
                        }),
                ),
              ),
            SizedBox(height: InSpacing.lg(context)),
            _ImportToggles(
              importSettings: _importSettings,
              importData: _importData,
              onSettings: _busy
                  ? null
                  : (v) => setState(() => _importSettings = v),
              onData: _busy ? null : (v) => setState(() => _importData = v),
            ),
            if (_busy) ...[
              SizedBox(height: InSpacing.lg(context)),
              _UploadProgress(
                sent: _sent,
                total: _total,
                stopping: _cancelRequested,
                onCancel: () => setState(() => _cancelRequested = true),
              ),
            ] else if (_completedNeedsBanner) ...[
              SizedBox(height: InSpacing.lg(context)),
              _QueuedBanner(
                onRestoreAnother: () => setState(() {
                  _source = null;
                  _fileName = '';
                  _fileLength = 0;
                  _completedNeedsBanner = false;
                }),
              ),
            ] else ...[
              SizedBox(height: InSpacing.lg(context)),
              LayoutBuilder(
                builder: (context, constraints) {
                  final narrow = constraints.maxWidth < 480;
                  final button = FilledButton.icon(
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: Text(context.tr('restore')),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(120, 44),
                      // Centers icon+label when the parent stretches the
                      // button full-width on mobile; on desktop the button
                      // wraps its content normally, so this is a no-op.
                      alignment: Alignment.center,
                    ),
                    onPressed: _canRestore ? _confirmAndRestore : null,
                  );
                  if (narrow) {
                    return SizedBox(width: double.infinity, child: button);
                  }
                  return Align(alignment: Alignment.centerLeft, child: button);
                },
              ),
            ],
          ],
        ),
      ],
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
}

class _PickedFileRow extends StatelessWidget {
  const _PickedFileRow({
    required this.name,
    required this.sizeText,
    required this.onClear,
  });
  final String name;
  final String sizeText;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Row(
      children: [
        Icon(Icons.folder_zip_outlined, color: tokens.accent, size: 28),
        SizedBox(width: InSpacing.md(context)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: Theme.of(context).textTheme.titleSmall,
                overflow: TextOverflow.ellipsis,
              ),
              if (sizeText.isNotEmpty)
                Text(sizeText, style: TextStyle(color: tokens.ink3)),
            ],
          ),
        ),
        IconButton(
          tooltip: context.tr('cancel'),
          icon: const Icon(Icons.close),
          onPressed: onClear,
        ),
      ],
    );
  }
}

class _ImportToggles extends StatelessWidget {
  const _ImportToggles({
    required this.importSettings,
    required this.importData,
    required this.onSettings,
    required this.onData,
  });

  final bool importSettings;
  final bool importData;
  final ValueChanged<bool>? onSettings;
  final ValueChanged<bool>? onData;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Column(
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(context.tr('import_settings')),
          subtitle: Text(
            context.tr('import_settings_help'),
            style: TextStyle(color: tokens.ink3),
          ),
          value: importSettings,
          onChanged: onSettings,
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(context.tr('import_data')),
          subtitle: Text(
            context.tr('import_data_help'),
            style: TextStyle(color: tokens.ink3),
          ),
          value: importData,
          onChanged: onData,
        ),
      ],
    );
  }
}

class _UploadProgress extends StatelessWidget {
  const _UploadProgress({
    required this.sent,
    required this.total,
    required this.stopping,
    required this.onCancel,
  });

  final int sent;
  final int total;
  final bool stopping;
  final VoidCallback onCancel;

  String _mb(int bytes) => (bytes / 1024 / 1024).toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final ratio = total <= 0 ? 0.0 : (sent / total).clamp(0.0, 1.0);
    final percent = (ratio * 100).round();
    // Cancellation only fires between chunks; while waiting, the bar fill
    // *and track* desaturate together (`ink3` on `ink4` keeps the bar
    // visible in both modes) and the button shows a spinner so the user
    // knows the tap took.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(InRadii.r1),
          child: LinearProgressIndicator(
            value: ratio,
            valueColor: stopping ? AlwaysStoppedAnimation(tokens.ink3) : null,
            backgroundColor: stopping ? tokens.ink4 : null,
          ),
        ),
        SizedBox(height: InSpacing.sm),
        Row(
          children: [
            Expanded(
              child: Text(
                '${_mb(sent)} / ${_mb(total)} MB · $percent% ${context.tr('uploaded')}',
                style: TextStyle(color: tokens.ink2),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: InSpacing.md(context)),
            OutlinedButton.icon(
              icon: stopping
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.stop_circle_outlined),
              label: Text(
                stopping ? context.tr('stopping') : context.tr('stop'),
              ),
              style: OutlinedButton.styleFrom(minimumSize: const Size(120, 40)),
              onPressed: stopping ? null : onCancel,
            ),
          ],
        ),
      ],
    );
  }
}

class _QueuedBanner extends StatelessWidget {
  const _QueuedBanner({required this.onRestoreAnother});

  final VoidCallback onRestoreAnother;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    // Narrow widths: stack action under the message. Otherwise the long
    // localised `import_started` ellipsises and the action button hugs the
    // right edge regardless of message length.
    return Container(
      padding: EdgeInsets.all(InSpacing.md(context)),
      decoration: BoxDecoration(
        color: tokens.accentSoft,
        borderRadius: BorderRadius.circular(InRadii.r2),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 480;
          final iconAndMessage = Row(
            children: [
              Icon(Icons.mark_email_read_outlined, color: tokens.accent),
              SizedBox(width: InSpacing.md(context)),
              Expanded(
                child: Text(
                  context.tr('import_started'),
                  style: TextStyle(color: tokens.ink),
                ),
              ),
            ],
          );
          final action = FilledButton.tonal(
            // In the wide branch this sits directly in a Row; without an
            // explicit minimumSize the filledButtonTheme default
            // (Size.fromHeight(44) = infinite width) overflows the Row (and
            // stretches full-width in the narrow Align branch). See theme.dart.
            style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
            onPressed: onRestoreAnother,
            child: Text(context.tr('restore_another')),
          );
          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                iconAndMessage,
                SizedBox(height: InSpacing.md(context)),
                Align(alignment: Alignment.centerLeft, child: action),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: iconAndMessage),
              SizedBox(width: InSpacing.md(context)),
              action,
            ],
          );
        },
      ),
    );
  }
}
