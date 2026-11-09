import 'dart:async';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/data/models/docuninja/dn_models.dart';
import 'package:admin/data/services/docuninja/docuninja_api.dart';
import 'package:admin/data/services/docuninja/docuninja_client.dart';
import 'package:admin/data/services/shared_intake_files.dart';
import 'package:admin/data/services/upload_source.dart';
import 'package:admin/domain/docuninja/docuninja_create.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/document_capture.dart';
import 'package:admin/ui/core/widgets/file_drop_zone.dart';
import 'package:admin/ui/core/widgets/form_save_scope.dart';
import 'package:admin/ui/core/widgets/icon_label_tile.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';

final _log = Logger('DocuNinjaCreateDialog');

/// React's New Document page (`pages/documents/create/Create.tsx`) as a
/// dialog: a name and the files, then Save creates the document. Its fields
/// are placed afterwards, in the builder. Returns the new document, or null.
Future<DnDocument?> showDocuNinjaCreateDialog(
  BuildContext context, {
  required DocuNinjaApi api,
  VoidCallback? onMaybeCreated,
}) => showDialog<DnDocument>(
  context: context,
  builder: (_) => _CreateDialog(api: api, onMaybeCreated: onMaybeCreated),
);

class _CreateDialog extends StatefulWidget {
  const _CreateDialog({required this.api, this.onMaybeCreated});

  final DocuNinjaApi api;

  /// The upload timed out and may have landed.
  final VoidCallback? onMaybeCreated;

  @override
  State<_CreateDialog> createState() => _CreateDialogState();
}

class _CreateDialogState extends State<_CreateDialog> {
  final _name = TextEditingController();
  final _files = <UploadSource>[];

  /// The name was typed, so a later pick no longer replaces it (React only
  /// replaces its untouched default).
  bool _nameTyped = false;
  bool _saving = false;
  String? _nameError;
  String? _filesError;

  /// The app's photo folder, read up front: a photo taken here sits in it
  /// until handed back, and the dialog hands back every one it took (sent,
  /// removed, refused or abandoned) when it closes, since the upload reads
  /// them before it does. A receipt or contract is personal data, and the
  /// launch sweep would otherwise leave it on the device for a day.
  SharedIntakeFiles? _intake;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _intake ??= intakeOf(context);
  }

  @override
  void dispose() {
    unawaited(releaseCapturedPhotos(_intake, _files));
    _name.dispose();
    super.dispose();
  }

  void _remove(int i) {
    final removed = _files[i];
    setState(() => _files.removeAt(i));
    unawaited(releaseCapturedPhotos(_intake, [removed]));
  }

  Future<void> _add(List<UploadSource> sources) async {
    final accepted = [
      for (final s in sources)
        if (dnAcceptsUpload(s)) s,
    ];
    unawaited(
      releaseCapturedPhotos(
        _intake,
        sources.where((s) => !accepted.contains(s)),
      ),
    );
    if (accepted.length < sources.length) {
      Notify.error(context, context.tr('invalid_file'));
    }
    if (accepted.isEmpty) return;
    setState(() {
      if (!_nameTyped && _files.isEmpty) {
        _name.text = dnDocumentNameFromFile(
          accepted.first.fileName,
          fallback: context.tr('untitled_document'),
        );
      }
      _files.addAll(accepted);
      _filesError = null;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_files.isEmpty) {
      setState(() => _filesError = context.tr('select_file'));
      return;
    }
    setState(() {
      _saving = true;
      _nameError = null;
    });
    final parts = await dnUploadParts(context, _files);
    if (!mounted) return;
    if (parts == null) {
      setState(() => _saving = false);
      Notify.error(context, context.tr('pdf_password_required'));
      return;
    }
    final name = _name.text.trim();
    try {
      final doc = await widget.api.createDocument(
        description: name.isEmpty ? context.tr('untitled_document') : name,
        files: parts,
      );
      if (!mounted) return;
      Navigator.of(context).pop(doc);
    } on DocuNinjaException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 408) {
        // The upload timed out but may have landed: close rather than
        // invite a second document (no "try again"), and the list re-reads.
        Notify.error(context, context.tr('an_error_occurred'));
        widget.onMaybeCreated?.call();
        Navigator.of(context).pop();
        return;
      }
      setState(() {
        _saving = false;
        _nameError = e.fieldErrors['description']?.first;
        final fileError = e.fieldErrors.entries
            .where((x) => x.key.startsWith('files'))
            .map((x) => x.value.first)
            .firstOrNull;
        _filesError = fileError;
      });
      if (_nameError == null && _filesError == null) {
        Notify.error(context, context.tr('an_error_occurred_try_again'));
      }
    } on Object catch (e, st) {
      _log.warning('Creating a DocuNinja document failed', e, st);
      if (!mounted) return;
      setState(() => _saving = false);
      Notify.error(context, context.tr('an_error_occurred_try_again'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return PopScope(
      // An upload in flight: closing would leave it running unseen.
      canPop: !_saving,
      child: AlertDialog(
        scrollable: true,
        title: Text(context.tr('new_document')),
        content: SizedBox(
          width: 480,
          child: FormSaveScope(
            onSubmit: _save,
            enabled: !_saving,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _name,
                  // The name is optional: on touch a keyboard raised at once
                  // covered the file pickers below it, the dialog's one
                  // required input.
                  autofocus: !Env.isTouchPrimary,
                  enabled: !_saving,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: context.tr('name'),
                    // React starts the name as this; it is what an empty
                    // field saves as.
                    hintText: context.tr('untitled_document'),
                    errorText: _nameError,
                  ),
                  onChanged: (_) => _nameTyped = true,
                  onSubmitted: (_) => _save(),
                ),
                SizedBox(height: InSpacing.md(context)),
                FileDropZone(
                  allowedExtensions: kDnUploadExtensions,
                  allowMultiple: true,
                  allowPhotos: true,
                  enabled: !_saving,
                  onFiles: _add,
                ),
                if (_filesError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _filesError!,
                      style: TextStyle(color: tokens.overdue, fontSize: 12),
                    ),
                  ),
                if (_files.isNotEmpty) ...[
                  const SizedBox(height: InSpacing.sm),
                  Wrap(
                    spacing: InSpacing.sm,
                    runSpacing: InSpacing.sm,
                    children: [
                      for (var i = 0; i < _files.length; i++)
                        InputChip(
                          label: Text(_files[i].fileName),
                          deleteButtonTooltipMessage: context.tr('remove'),
                          onDeleted: _saving ? null : () => _remove(i),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: Text(context.tr('cancel')),
          ),
          PrimaryDialogAction(
            label: context.tr('save'),
            // The name field takes the focus (with a pointer).
            autofocus: false,
            busy: _saving,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}

/// The file is one DocuNinja takes ([kDnUploadExtensions]).
bool dnAcceptsUpload(UploadSource s) {
  final name = s.fileName;
  final dot = name.lastIndexOf('.');
  final ext = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  return kDnUploadExtensions.contains(ext);
}

/// The multipart parts for [files]. React asks for a password-protected
/// PDF's password and uploads it as `name.pdf|password`. Null when the user
/// cancels a password prompt.
///
/// The check here only sees that the file is encrypted. A PDF with just an
/// owner password (permissions, no password to open it) is encrypted too,
/// and React would not ask; so the prompt takes an empty answer as "it
/// opens without one" and uploads the file as it is.
Future<List<DnUploadPart>?> dnUploadParts(
  BuildContext context,
  List<UploadSource> files,
) async {
  final parts = <DnUploadPart>[];
  for (final f in files) {
    String? filename;
    if (f.fileName.toLowerCase().endsWith('.pdf') && await _isProtected(f)) {
      if (!context.mounted) return null;
      final password = await showDialog<String>(
        context: context,
        builder: (context) => _PasswordDialog(fileName: f.fileName),
      );
      if (password == null) return null;
      if (password.isNotEmpty) {
        filename = dnProtectedFileName(f.fileName, password);
      }
    }
    parts.add((field: 'files[]', source: f, filename: filename));
  }
  return parts;
}

const _probe = 1024 * 1024;

Future<bool> _isProtected(UploadSource f) async {
  try {
    final length = await f.length();
    final head = await f.readRange(0, math.min(length, _probe));
    final tail = await f.readRange(math.max(0, length - _probe), length);
    return dnLooksPasswordProtected(head, tail);
  } on Object catch (e, st) {
    _log.warning('Could not read ${f.fileName} to check for a password', e, st);
    return false;
  }
}

/// React's drop zone above its documents table
/// (`DocumentCreationDropZone.tsx`): drop or pick files and the document is
/// created at once, named after the first file, with no dialog. On a phone
/// or tablet it is Camera / Photos / Files. [onCreated] runs even when the
/// zone has gone meanwhile, so the host can still land on the new document.
class DocuNinjaDropZone extends StatefulWidget {
  const DocuNinjaDropZone({
    super.key,
    required this.api,
    required this.onCreated,
    this.companyOf,
    this.onMaybeCreated,
  });

  final DocuNinjaApi api;

  /// The new document, and the company it was dropped for ([companyOf] at
  /// the drop): the host must not open it under a company switched to
  /// while it uploaded.
  final void Function(DnDocument doc, String? companyId) onCreated;

  /// The active company, read when the files arrive.
  final String? Function()? companyOf;

  /// The upload timed out and may have landed.
  final VoidCallback? onMaybeCreated;

  @override
  State<DocuNinjaDropZone> createState() => _DocuNinjaDropZoneState();
}

class _DocuNinjaDropZoneState extends State<DocuNinjaDropZone> {
  bool _busy = false;

  Future<void> _onFiles(List<UploadSource> sources) async {
    if (_busy) return;
    // Read now: the upload may outlive the zone, and the company may change.
    final companyId = widget.companyOf?.call();
    setState(() => _busy = true);
    try {
      await dnCreateDocumentFromFiles(
        context,
        api: widget.api,
        sources: sources,
        companyId: companyId,
        onCreated: widget.onCreated,
        onMaybeCreated: widget.onMaybeCreated,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FileDropZone(
    allowedExtensions: kDnUploadExtensions,
    allowMultiple: true,
    allowPhotos: true,
    enabled: !_busy,
    preview: _busy
        ? const SizedBox.square(
            dimension: 32,
            child: Padding(
              padding: EdgeInsets.all(4),
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          )
        : null,
    onFiles: _onFiles,
  );
}

/// Makes a document of [sources] at once, named after the first file, with
/// no dialog: the drop zone's upload, and the phone's create sheet's.
/// [onCreated] gets the new document and [companyId] (the company the files
/// were picked for), even when [context] has gone meanwhile, so the host can
/// still land on it. A refused file, a cancelled password prompt and a
/// failure are toasts; a failure is said from the root navigator when
/// [context] has gone. Every photo in [sources] is handed back once the
/// upload has read it.
Future<void> dnCreateDocumentFromFiles(
  BuildContext context, {
  required DocuNinjaApi api,
  required List<UploadSource> sources,
  required void Function(DnDocument doc, String? companyId) onCreated,
  String? companyId,
  VoidCallback? onMaybeCreated,
}) async {
  // Read now: the upload may outlive the caller.
  final intake = intakeOf(context);
  final accepted = sources.where(dnAcceptsUpload).toList();
  if (accepted.length < sources.length) {
    Notify.error(context, context.tr('invalid_file'));
  }
  if (accepted.isEmpty) {
    unawaited(releaseCapturedPhotos(intake, sources));
    return;
  }
  final fallback = context.tr('untitled_document');
  final tryAgain = context.tr('an_error_occurred_try_again');
  final mayHaveLanded = context.tr('an_error_occurred');
  // The caller can go while the upload runs (the list goes offline, the
  // company changes): its failure is still said, from the root.
  final host = Navigator.of(context, rootNavigator: true).context;
  void fail(String message) {
    final at = context.mounted ? context : host;
    if (at.mounted) Notify.error(at, message);
  }

  try {
    final parts = await dnUploadParts(context, accepted);
    if (!context.mounted) return;
    if (parts == null) {
      Notify.error(context, context.tr('pdf_password_required'));
      return;
    }
    final doc = await api.createDocument(
      description: dnDocumentNameFromFile(
        accepted.first.fileName,
        fallback: fallback,
      ),
      files: parts,
    );
    onCreated(doc, companyId);
  } on DocuNinjaException catch (e) {
    if (e.statusCode == 408) {
      // May have landed: the list re-reads rather than invite a retry.
      onMaybeCreated?.call();
    }
    final fieldError = e.fieldErrors.values
        .map((v) => v.firstOrNull)
        .nonNulls
        .firstOrNull;
    fail(e.statusCode == 408 ? mayHaveLanded : fieldError ?? tryAgain);
  } on Object catch (e, st) {
    _log.warning('Creating a DocuNinja document failed', e, st);
    fail(tryAgain);
  } finally {
    // The upload has read them: a photo taken here goes back now.
    unawaited(releaseCapturedPhotos(intake, sources));
  }
}

/// What the phone's create sheet ([showDocuNinjaCreateSheet]) was asked
/// for: a capture or pick that uploads at once, or [named], the New
/// Document dialog.
enum DnCreateSource { camera, photos, files, named }

/// The phone's create sheet, behind the documents list's `+` button: Camera,
/// Photos and Files, which upload at once as the drop zone's tiles do, and
/// the New Document dialog for a name first. Resolves to the pick once the
/// sheet has closed (so the camera or picker it starts has no modal route
/// in its way), or null when dismissed. Camera and Photos only on a native
/// phone ([Env.isMobile]), as `FileDropZone.allowPhotos` has them.
Future<DnCreateSource?> showDocuNinjaCreateSheet(BuildContext context) =>
    showModalBottomSheet<DnCreateSource>(
      context: context,
      // Over the shell's running-timer pill, as the dashboard's sheet.
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => DnCreateSheet(
        onSelected: (source) => Navigator.of(sheetContext).pop(source),
      ),
    );

/// The body of [showDocuNinjaCreateSheet]; public for a widget test.
class DnCreateSheet extends StatelessWidget {
  const DnCreateSheet({super.key, required this.onSelected});

  final ValueChanged<DnCreateSource> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final gutter = InSpacing.lg(context);
    Widget tile(DnCreateSource source, IconData icon, String labelKey) =>
        IconLabelTile(
          icon: icon,
          label: context.tr(labelKey),
          onTap: () => onSelected(source),
        );
    final tiles = [
      if (Env.isMobile) ...[
        tile(
          DnCreateSource.camera,
          Icons.photo_camera_outlined,
          'photo_source_camera',
        ),
        tile(
          DnCreateSource.photos,
          Icons.photo_library_outlined,
          'photo_source_photos',
        ),
      ],
      tile(
        DnCreateSource.files,
        Icons.insert_drive_file_outlined,
        'photo_source_files',
      ),
    ];
    return SafeArea(
      top: false,
      child: Padding(
        // No top padding: the drag handle above already spaces the heading.
        padding: EdgeInsetsDirectional.fromSTEB(gutter, 0, gutter, gutter),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                headingLevel: 1,
                child: Text(
                  context.tr('new_document'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: tokens.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SizedBox(height: InSpacing.md(context)),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < tiles.length; i++) ...[
                      if (i > 0) const SizedBox(width: InSpacing.sm),
                      Expanded(child: tiles[i]),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: InSpacing.sm),
              // A name first: the New Document dialog.
              Material(
                color: tokens.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(InRadii.r2),
                  side: BorderSide(color: tokens.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  leading: Icon(Icons.edit_note_outlined, color: tokens.ink2),
                  title: Text(context.tr('docuninja_name_and_upload')),
                  onTap: () => onSelected(DnCreateSource.named),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The files a create-sheet pick ([source]) yields: a photo taken, photos
/// picked, or files from the device's picker (DocuNinja's types). Empty for
/// a cancel, and for [DnCreateSource.named], which picks nothing here.
Future<List<UploadSource>> dnPickCreateSources(
  BuildContext context,
  DnCreateSource source,
) async {
  switch (source) {
    case DnCreateSource.camera:
      return captureDocumentPhoto(context);
    case DnCreateSource.photos:
      return pickGalleryPhotos(context, multiple: true);
    case DnCreateSource.files:
      // An empty list is a cancel.
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: kDnUploadExtensions,
      );
      return uploadSourcesFromPicked(files);
    case DnCreateSource.named:
      return const [];
  }
}

/// React's "PDF password required" prompt for one file.
class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog({required this.fileName});

  final String fileName;

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  /// Empty is an answer: the file opens without a password.
  void _ok() => Navigator.of(context).pop(_password.text);

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(context.tr('pdf_password_required')),
    content: FormSaveScope(
      onSubmit: _ok,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.fileName),
          const SizedBox(height: InSpacing.sm),
          TextField(
            controller: _password,
            autofocus: true,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: TextInputType.visiblePassword,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(labelText: context.tr('password')),
            onSubmitted: (_) => _ok(),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(context.tr('cancel')),
      ),
      PrimaryDialogAction(
        label: context.tr('ok'),
        autofocus: false,
        onPressed: _ok,
      ),
    ],
  );
}
