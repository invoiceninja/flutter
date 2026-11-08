import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/docuninja/dn_models.dart';
import 'package:admin/data/services/docuninja/docuninja_api.dart';
import 'package:admin/data/services/docuninja/docuninja_client.dart';
import 'package:admin/data/services/upload_source.dart';
import 'package:admin/domain/docuninja/docuninja_create.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/file_drop_zone.dart';
import 'package:admin/ui/core/widgets/form_save_scope.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';

final _log = Logger('DocuNinjaCreateDialog');

/// React's New Document page (`pages/documents/create/Create.tsx`) as a
/// dialog: a name and the files, then Save creates the document. Its fields
/// are placed afterwards, in the builder. Returns the new document, or null.
Future<DnDocument?> showDocuNinjaCreateDialog(
  BuildContext context, {
  required DocuNinjaApi api,
}) => showDialog<DnDocument>(
  context: context,
  builder: (_) => _CreateDialog(api: api),
);

class _CreateDialog extends StatefulWidget {
  const _CreateDialog({required this.api});

  final DocuNinjaApi api;

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

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _add(List<UploadSource> sources) async {
    final accepted = [
      for (final s in sources)
        if (kDnUploadExtensions.contains(_extension(s.fileName))) s,
    ];
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

  static String _extension(String name) {
    final dot = name.lastIndexOf('.');
    return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  }

  /// React asks for a password-protected PDF's password and uploads it as
  /// `name.pdf|password`. Null when the user cancels.
  ///
  /// The check here only sees that the file is encrypted. A PDF with just an
  /// owner password (permissions, no password to open it) is encrypted too,
  /// and React would not ask; so the prompt takes an empty answer as "it
  /// opens without one" and uploads the file as it is.
  Future<List<DnUploadPart>?> _parts() async {
    final parts = <DnUploadPart>[];
    for (final f in _files) {
      String? filename;
      if (_extension(f.fileName) == 'pdf' && await _isProtected(f)) {
        if (!mounted) return null;
        final password = await _askPassword(f.fileName);
        if (password == null) return null;
        if (password.isNotEmpty) {
          filename = dnProtectedFileName(f.fileName, password);
        }
      }
      parts.add((field: 'files[]', source: f, filename: filename));
    }
    return parts;
  }

  static const _probe = 1024 * 1024;

  Future<bool> _isProtected(UploadSource f) async {
    try {
      final length = await f.length();
      final head = await f.readRange(0, math.min(length, _probe));
      final tail = await f.readRange(math.max(0, length - _probe), length);
      return dnLooksPasswordProtected(head, tail);
    } on Object catch (e, st) {
      _log.warning(
        'Could not read ${f.fileName} to check for a password',
        e,
        st,
      );
      return false;
    }
  }

  Future<String?> _askPassword(String fileName) => showDialog<String>(
    context: context,
    builder: (context) => _PasswordDialog(fileName: fileName),
  );

  Future<void> _save() async {
    if (_saving) return;
    if (_files.isEmpty) {
      setState(() => _filesError = context.tr('dropzone_default_message'));
      return;
    }
    setState(() {
      _saving = true;
      _nameError = null;
    });
    final parts = await _parts();
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
                  enabled: !_saving,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: context.tr('name'),
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
                          onDeleted: _saving
                              ? null
                              : () => setState(() => _files.removeAt(i)),
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
            busy: _saving,
            onPressed: _save,
          ),
        ],
      ),
    );
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
