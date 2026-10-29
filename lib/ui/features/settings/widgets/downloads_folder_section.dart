import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/downloads_folder_controller.dart';
import 'package:admin/app/env.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/utils/external_url.dart';
import 'package:admin/ui/core/utils/save_download.dart';
import 'package:admin/ui/core/widgets/ltr_value.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';

/// Search keys for the settings sidebar search — the section title, which is
/// the label a search hit reveals (`search_catalog_consistency_test`).
const kDownloadsFolderSearchKeys = <String>['downloads_folder'];

/// Whether [DownloadsFolderSection] renders on this platform — and so whether
/// settings search offers its keys. Desktop only: a mobile download is the
/// share sheet and a web one the browser's.
bool downloadsFolderSectionShown() => Env.isDesktop;

/// The folder picker, as `FilePicker.getDirectoryPath` exposes it.
typedef DirectoryPicker =
    Future<String?> Function({String? dialogTitle, String? initialDirectory});

Future<String?> _filePickerDirectory({
  String? dialogTitle,
  String? initialDirectory,
}) => FilePicker.getDirectoryPath(
  dialogTitle: dialogTitle,
  initialDirectory: initialDirectory,
);

/// Replaced by tests; production always goes through `FilePicker`.
@visibleForTesting
DirectoryPicker directoryPicker = _filePickerDirectory;

/// Device Settings card for the folder a desktop download is written to
/// (docs/file-downloads.md) — the old app's *Downloads Folder*.
///
/// Windows and Linux can choose one (Select / Reset). macOS shows its folder
/// read-only with a way to open it: a folder picked in the sandboxed build
/// loses its access on the next launch, so there it is always Downloads —
/// shown rather than hidden, so the setting never looks missing. No free-text
/// field: a typed path is how a folder that does not exist gets saved.
class DownloadsFolderSection extends StatefulWidget {
  const DownloadsFolderSection({super.key});

  @override
  State<DownloadsFolderSection> createState() => _DownloadsFolderSectionState();
}

class _DownloadsFolderSectionState extends State<DownloadsFolderSection> {
  // Resolved once: the OS answer does not change while the screen is open.
  late final Future<String?> _defaultFolder = defaultDownloadsFolder();

  @override
  Widget build(BuildContext context) {
    final controller = context.read<DownloadsFolderController?>();
    if (!downloadsFolderSectionShown() || controller == null) {
      return const SizedBox.shrink();
    }
    final editable = downloadsFolderEditable();
    return FormSection(
      title: context.tr('downloads_folder'),
      children: [
        FutureBuilder<String?>(
          future: _defaultFolder,
          builder: (context, snap) => ValueListenableBuilder<String>(
            valueListenable: controller,
            builder: (context, chosen, _) {
              final isDefault = !editable || chosen.isEmpty;
              final path = isDefault ? snap.data : chosen;
              return _FolderRow(
                path: path,
                isDefault: isDefault,
                actions: [
                  if (editable && !isDefault) ...[
                    TextButton(
                      key: const ValueKey('downloads_folder_reset'),
                      onPressed: () => controller.set(''),
                      child: Text(context.tr('reset')),
                    ),
                    SizedBox(width: InSpacing.md(context)),
                  ],
                  if (editable)
                    OutlinedButton(
                      key: const ValueKey('downloads_folder_select'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(64, 40),
                      ),
                      onPressed: () => _select(context, controller, path),
                      child: Text(context.tr('select')),
                    )
                  else if (path != null)
                    OutlinedButton(
                      key: const ValueKey('downloads_folder_open'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(64, 40),
                      ),
                      onPressed: () => _open(context, path),
                      child: Text(context.tr('open')),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _select(
    BuildContext context,
    DownloadsFolderController controller,
    String? current,
  ) async {
    final toasts = Notify.capture(context);
    final error = context.tr('an_error_occurred');
    final title = context.tr('save_files_to_this_folder');
    try {
      final picked = await directoryPicker(
        dialogTitle: title,
        initialDirectory: current,
      );
      if (picked == null || picked.isEmpty) return;
      await controller.set(picked);
    } catch (_) {
      // Linux picks through the desktop portal, which throws when none runs.
      toasts?.error(error);
    }
  }

  Future<void> _open(BuildContext context, String path) async {
    final toasts = Notify.capture(context);
    final error = context.tr('an_error_occurred');
    if (!await launchExternalUri(Uri.directory(path))) toasts?.error(error);
  }
}

class _FolderRow extends StatelessWidget {
  const _FolderRow({
    required this.path,
    required this.isDefault,
    required this.actions,
  });

  /// Null while the OS folder resolves, or when there is none — a download
  /// then opens the save dialog.
  final String? path;
  final bool isDefault;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(Icons.folder_outlined, color: tokens.ink2),
        SizedBox(width: InSpacing.md(context)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // A path is a value: in a right-to-left language the bidi
              // algorithm would reorder its separators.
              LtrText(
                path ?? '—',
                softWrap: true,
                style: theme.textTheme.bodyMedium?.copyWith(color: tokens.ink),
              ),
              if (isDefault)
                Text(
                  context.tr('default'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: tokens.ink3,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: InSpacing.sm),
        ...actions,
      ],
    );
  }
}
