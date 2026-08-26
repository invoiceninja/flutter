import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/services/upload_source.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/utils/external_url.dart';
import 'package:admin/ui/core/widgets/file_drop_zone.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/features/settings/view_models/company_details_view_model.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/settings/widgets/overridable_switch_field.dart';
import 'package:admin/ui/features/settings/widgets/settings_form_shell.dart';
import 'package:admin/utils/document_upload_validation.dart';
import 'package:admin/utils/formatting.dart';
import 'package:admin/utils/url_safety.dart';

/// Searchable label keys rendered by this tab. See
/// `kCompanyDetailsDetailsSearchKeys` for the colocation pattern.
const kCompanyDetailsDocumentsSearchKeys = <String>[
  'documents',
  'documents_public_by_default',
];

/// "Documents" tab — list of file attachments on the company, plus a shared
/// drop-or-click upload affordance. Documents arrive on the company envelope
/// and are persisted in the `companies.documents` JSON column; the tab watches
/// the company stream so the list rebuilds when an upload's server response
/// lands.
///
/// The tab also hosts `documents_public_by_default` — the company-level
/// default `is_public` the server applies to every new attachment (not just
/// the company's own). It renders with `defaultValue: true` because the
/// server's historical behavior for an unset key is public.
///
/// **Until the server ships the prop, saving it visibly reverts.**
/// `CompanySettingsSaver` drops any settings key absent from
/// `CompanySettings::$casts`, and `CompanyRepository.applyUpdateResponse`
/// replaces the whole blob with the server's echo — so the key is gone from
/// Drift on the next frame and `defaultValue: true` renders the switch back
/// ON right after the "Saved" toast. Not a client bug; see `BACKEND.md`
/// § `documents_public_by_default`.
///
/// The document list reads [CompanyDetailsViewModel.initialValue], not the
/// draft: uploads and deletes land on the company row through the outbox, and
/// `DraftStreamHost` deliberately freezes the *draft* while it's dirty. Reading
/// the draft here meant that touching the toggle above froze the list, so an
/// upload would toast success and never appear.
class CompanyDetailsDocumentsScreen extends StatelessWidget {
  const CompanyDetailsDocumentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CompanyDetailsViewModel>();
    final services = context.read<Services>();
    final tokens = context.inTheme;
    final documents = vm.initialValue?.documents ?? const <Document>[];

    return SettingsFormShell(
      sections: [
        FormSection(
          title: context.tr('documents'),
          children: [
            OverridableSwitchField(
              label: context.tr('documents_public_by_default'),
              apiKey: 'documents_public_by_default',
              subtitle: context.trIfDefined('documents_public_by_default_help'),
              defaultValue: true,
            ),
            FileDropZone(
              allowedExtensions: kDocumentAllowedExtensions,
              allowMultiple: true,
              onFiles: (sources) =>
                  _validateAndUpload(context, services, vm, sources),
            ),
            // No SizedBox spacers here — FormSection interleaves
            // InSpacing.lg between adjacent children already.
            if (documents.isNotEmpty)
              _DocumentList(
                documents: documents,
                tokens: tokens,
                onView: (doc) => _openDocument(context, doc),
                onDelete: (doc) => _deleteDocument(context, services, vm, doc),
              ),
          ],
        ),
      ],
    );
  }

  /// Validate each picked / dropped file against the shared allowlist + size
  /// cap, then upload the good ones. Identical reject toasts regardless of how
  /// the file arrived — mirrors `EntityDocumentsTab._validateAndUpload`.
  Future<void> _validateAndUpload(
    BuildContext context,
    Services services,
    CompanyDetailsViewModel vm,
    List<UploadSource> sources,
  ) async {
    if (sources.isEmpty) return;
    final good = <UploadSource>[];
    var sawWrongType = false;
    var sawTooLarge = false;
    for (final s in sources) {
      final result = await validateDocumentUpload(s);
      if (result.isOk) {
        good.add(s);
      } else {
        switch (result.issue) {
          case DocumentUploadIssue.wrongExtension:
            sawWrongType = true;
          case DocumentUploadIssue.tooLarge:
            sawTooLarge = true;
          case DocumentUploadIssue.unreadable:
            sawWrongType = true;
          case null:
            break;
        }
      }
    }
    if (!context.mounted) return;
    if (sawWrongType) {
      Notify.warning(context, context.tr('dropzone_invalid_file_type'));
    }
    if (sawTooLarge) {
      Notify.warning(
        context,
        context.tr('upload_too_large_with_size', {'size': '$kDocumentMaxMb'}),
      );
    }
    if (good.isEmpty) return;
    try {
      for (final s in good) {
        await services.company.uploadDocument(
          companyId: vm.companyId,
          source: s,
        );
      }
      if (!context.mounted) return;
      Notify.success(context, context.tr('uploaded_document'));
    } catch (e) {
      if (!context.mounted) return;
      Notify.error(context, context.tr('error_uploading_document'), error: e);
    }
  }

  /// Open a document URL in the OS's external handler. Document URLs are
  /// server-supplied, so the HTTPS check guards against a hostile/compromised
  /// server pushing `javascript:` / `file:` / `intent:` URIs — mirrors
  /// `EntityDocumentsTab._onView`. Silent no-op on an unsafe/empty URL.
  Future<void> _openDocument(BuildContext context, Document doc) async {
    // Both exits used to be silent: a rejected scheme returned, and the
    // bool from `launchUrl` was discarded — so "View" simply did nothing,
    // with no toast and no `platformDefault` retry. That is the exact
    // failure `openExternalUrl` was introduced for (invoiceninja/flutter#80).
    // The https-only check itself stays: these URLs come from the server,
    // and a hostile one could otherwise push `javascript:` / `file:` /
    // `intent:` at the OS handler.
    final uri = isSafeHttpsUrl(doc.url) ? Uri.tryParse(doc.url) : null;
    if (uri != null && await launchExternalUri(uri)) return;
    if (!context.mounted) return;
    Notify.error(context, context.tr('failed_to_open_url'));
  }

  /// Enqueue a document delete + optimistic success toast. The delete is
  /// password-gated, so `ConfirmPasswordSheet` fires when the outbox row
  /// drains and the row drops from the list on confirm (remove-on-drain).
  Future<void> _deleteDocument(
    BuildContext context,
    Services services,
    CompanyDetailsViewModel vm,
    Document doc,
  ) async {
    try {
      await services.company.deleteDocument(
        companyId: vm.companyId,
        documentId: doc.id,
      );
      if (!context.mounted) return;
      Notify.success(context, context.tr('deleted_document'));
    } catch (e) {
      if (!context.mounted) return;
      Notify.error(context, context.tr('error'), error: e);
    }
  }
}

class _DocumentList extends StatelessWidget {
  const _DocumentList({
    required this.documents,
    required this.tokens,
    required this.onView,
    required this.onDelete,
  });

  final List<Document> documents;
  final InTheme tokens;
  final Future<void> Function(Document doc) onView;
  final Future<void> Function(Document doc) onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < documents.length; i++) ...[
          if (i > 0) const SizedBox(height: InSpacing.sm),
          _DocumentRow(
            doc: documents[i],
            tokens: tokens,
            onView: onView,
            onDelete: onDelete,
          ),
        ],
      ],
    );
  }
}

class _DocumentRow extends StatelessWidget {
  const _DocumentRow({
    required this.doc,
    required this.tokens,
    required this.onView,
    required this.onDelete,
  });

  final Document doc;
  final InTheme tokens;
  final Future<void> Function(Document doc) onView;
  final Future<void> Function(Document doc) onDelete;

  static const _imageExts = <String>{
    'png',
    'jpg',
    'jpeg',
    'gif',
    'webp',
    'heic',
    'svg',
    'bmp',
  };

  @override
  Widget build(BuildContext context) {
    final ext = doc.type.toLowerCase();
    final icon = _imageExts.contains(ext)
        ? Icons.image_outlined
        : Icons.description_outlined;
    final displayName = doc.name.isNotEmpty ? doc.name : doc.hash;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: InSpacing.lg(context),
        vertical: InSpacing.md(context),
      ),
      decoration: BoxDecoration(
        border: Border.all(color: tokens.border),
        borderRadius: BorderRadius.circular(InRadii.r2),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: tokens.ink2),
          SizedBox(width: InSpacing.md(context)),
          Expanded(
            child: Text(
              displayName,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: tokens.ink),
            ),
          ),
          if (doc.size > 0) ...[
            SizedBox(width: InSpacing.md(context)),
            Text(formatSize(doc.size), style: TextStyle(color: tokens.ink3)),
          ],
          const SizedBox(width: InSpacing.sm),
          PopupMenuButton<_RowAction>(
            tooltip: context.tr('actions'),
            icon: Icon(Icons.more_vert, size: 20, color: tokens.ink3),
            onSelected: (action) async {
              switch (action) {
                case _RowAction.view:
                  await onView(doc);
                case _RowAction.delete:
                  await onDelete(doc);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _RowAction.view,
                child: ListTile(
                  leading: const Icon(Icons.open_in_new),
                  title: Text(context.tr('view')),
                ),
              ),
              PopupMenuItem(
                value: _RowAction.delete,
                child: ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: Text(context.tr('delete')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _RowAction { view, delete }
