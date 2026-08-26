import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/document.dart';
import 'package:admin/data/services/upload_source.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/utils/external_url.dart';
import 'package:admin/ui/core/widgets/file_drop_zone.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/features/settings/widgets/plan_gate_banner.dart';
import 'package:admin/utils/document_upload_validation.dart';
import 'package:admin/utils/formatting.dart';
import 'package:admin/utils/url_safety.dart';

/// Reusable per-entity Documents tab body. Used on the Client and Product
/// detail screens (and any future entity that supports attachments).
///
/// The widget is entity-agnostic — the host wires the four callbacks to
/// the right repository methods (`uploadDocument`, `deleteDocument`,
/// `setDocumentVisibility`) and supplies the document list. The tab
/// short-circuits to a save-first message when [entityId] is a tmp id
/// (the entity doesn't exist server-side yet — uploads would 404).
class EntityDocumentsTab extends StatefulWidget {
  const EntityDocumentsTab({
    super.key,
    required this.entityId,
    required this.documents,
    required this.onUpload,
    required this.onDelete,
    required this.onToggleVisibility,
    this.formatter,
    this.readOnly = false,
  });

  /// Server id of the parent entity. When it starts with `tmp_`, only the
  /// "save first" banner renders — the entity has to round-trip to the
  /// server before its documents URL is reachable.
  final String entityId;

  /// Current document list, derived from the entity's domain row by the
  /// host (typically `vm.client.documents` / `vm.product.documents`).
  final List<Document> documents;

  /// Callback for one or more newly picked / dropped files, each wrapped in
  /// an [UploadSource] (native file path or in-memory web bytes). The host
  /// typically does `sources.forEach(repo.uploadDocument)` — the outbox
  /// handles sequencing.
  final Future<void> Function(List<UploadSource> sources) onUpload;

  /// Callback when the user picks **Delete** on a row. The host enqueues
  /// `repo.deleteDocument`; the sync engine prompts for the password
  /// because `requiresPasswordFor(MutationKind.documentDelete)` is true.
  /// No pre-confirmation dialog — typing the password is the
  /// confirmation.
  final Future<void> Function(Document doc) onDelete;

  /// Callback for the Set Private / Set Public menu items.
  final Future<void> Function(Document doc) onToggleVisibility;

  /// Optional [Formatter] for rendering dates in the company's preferred
  /// `date_format_id`. When null, falls back to the iso `YYYY-MM-DD`.
  final Formatter? formatter;

  /// When true, hide the upload affordance + per-row actions menu. Used
  /// when the user lacks `edit_<entity>` permission, mirroring React's
  /// `disableEditableOptions`.
  final bool readOnly;

  @override
  State<EntityDocumentsTab> createState() => _EntityDocumentsTabState();
}

class _EntityDocumentsTabState extends State<EntityDocumentsTab> {
  bool get _isTmp => widget.entityId.startsWith('tmp_');

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    if (_isTmp) {
      return Padding(
        padding: EdgeInsets.all(InSpacing.lg(context)),
        child: Text(
          context.tr('save_to_upload_documents'),
          style: TextStyle(color: tokens.ink3),
        ),
      );
    }
    // Document attachments are an Enterprise feature on hosted (parity with
    // admin-portal `document_grid.dart` & React `Upload.tsx`). Trialing users
    // keep access (`hasEnterpriseAccess` is trial-aware). Existing documents
    // stay viewable / downloadable (read-value policy) — only upload and the
    // per-row mutate actions are gated.
    //
    // This is a shared leaf reused in widget tests that don't mount a
    // `Services` provider; resolve it defensively (no provider → ungated,
    // matching pre-gate behaviour) instead of throwing.
    Services? services;
    try {
      services = context.watch<Services>();
    } catch (_) {
      services = null;
    }
    final session = services?.auth.session.value;
    final planGated =
        session != null && session.isHosted && !session.hasEnterpriseAccess;
    final readOnly = widget.readOnly || planGated;
    final sorted = [...widget.documents]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return Padding(
      padding: EdgeInsets.all(InSpacing.lg(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (planGated)
            const PlanGateBanner(
              style: PlanGateStyle.inset,
              level: PlanGateLevel.enterprise,
            ),
          if (!readOnly) _buildUploadAffordance(context),
          if (sorted.isEmpty)
            Padding(
              padding: EdgeInsets.only(
                top: readOnly ? 0 : InSpacing.lg(context),
              ),
              child: Text(
                context.tr('no_records_found'),
                style: TextStyle(color: tokens.ink3),
              ),
            )
          else ...[
            SizedBox(height: InSpacing.lg(context)),
            _DocumentList(
              documents: sorted,
              formatter: widget.formatter,
              readOnly: readOnly,
              onView: _onView,
              onDelete: widget.onDelete,
              onToggleVisibility: widget.onToggleVisibility,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUploadAffordance(BuildContext context) {
    return FileDropZone(
      allowedExtensions: kDocumentAllowedExtensions,
      allowMultiple: true,
      onFiles: _validateAndUpload,
    );
  }

  Future<void> _validateAndUpload(List<UploadSource> sources) async {
    if (sources.isEmpty) return;
    final good = <UploadSource>[];
    bool sawWrongType = false;
    bool sawTooLarge = false;
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
            sawWrongType = true; // surface as generic reject
          case null:
            break;
        }
      }
    }
    if (!mounted) return;
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
      await widget.onUpload(good);
      if (!mounted) return;
      Notify.success(context, context.tr('uploaded_document'));
    } catch (e) {
      if (!mounted) return;
      Notify.error(context, context.tr('error_uploading_document'), error: e);
    }
  }

  Future<void> _onView(Document doc) async {
    // Document URLs are server-supplied. Without this scheme check, a
    // hostile or compromised server could push javascript:, file:, or
    // intent:// URIs and have them dispatched to the OS handler when the
    // user taps "View document".
    // Both exits used to be silent: a rejected scheme returned, and the
    // bool from `launchUrl` was discarded — so "View" simply did nothing,
    // with no toast and no `platformDefault` retry. That is the exact
    // failure `openExternalUrl` was introduced for (invoiceninja/flutter#80).
    // The https-only check itself stays: these URLs come from the server,
    // and a hostile one could otherwise push `javascript:` / `file:` /
    // `intent:` at the OS handler.
    final uri = isSafeHttpsUrl(doc.url) ? Uri.tryParse(doc.url) : null;
    if (uri != null && await launchExternalUri(uri)) return;
    if (!mounted) return;
    Notify.error(context, context.tr('failed_to_open_url'));
  }
}

class _DocumentList extends StatelessWidget {
  const _DocumentList({
    required this.documents,
    required this.formatter,
    required this.readOnly,
    required this.onView,
    required this.onDelete,
    required this.onToggleVisibility,
  });

  final List<Document> documents;
  final Formatter? formatter;
  final bool readOnly;
  final Future<void> Function(Document doc) onView;
  final Future<void> Function(Document doc) onDelete;
  final Future<void> Function(Document doc) onToggleVisibility;

  static const _narrowBreakpoint = 720.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < _narrowBreakpoint;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < documents.length; i++) ...[
              if (i > 0) const SizedBox(height: InSpacing.sm),
              _DocumentRow(
                doc: documents[i],
                narrow: narrow,
                formatter: formatter,
                readOnly: readOnly,
                onView: onView,
                onDelete: onDelete,
                onToggleVisibility: onToggleVisibility,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _DocumentRow extends StatelessWidget {
  const _DocumentRow({
    required this.doc,
    required this.narrow,
    required this.formatter,
    required this.readOnly,
    required this.onView,
    required this.onDelete,
    required this.onToggleVisibility,
  });

  final Document doc;
  final bool narrow;
  final Formatter? formatter;
  final bool readOnly;
  final Future<void> Function(Document doc) onView;
  final Future<void> Function(Document doc) onDelete;
  final Future<void> Function(Document doc) onToggleVisibility;

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

  String _formatDate(BuildContext context) {
    if (doc.updatedAt <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(
      doc.updatedAt * 1000,
      isUtc: true,
    );
    final iso =
        '${dt.year.toString().padLeft(4, '0')}-'
        '${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')}';
    return formatter?.date(iso) ?? iso;
  }

  IconData _typeIcon() {
    final ext = doc.type.toLowerCase();
    return _imageExts.contains(ext)
        ? Icons.image_outlined
        : Icons.description_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final displayName = doc.name.isNotEmpty ? doc.name : doc.hash;
    final dateLabel = _formatDate(context);
    final sizeLabel = doc.size > 0 ? formatSize(doc.size) : '';
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: InSpacing.lg(context),
        vertical: InSpacing.md(context),
      ),
      decoration: BoxDecoration(
        border: Border.all(color: tokens.border),
        borderRadius: BorderRadius.circular(InRadii.r2),
      ),
      child: narrow
          ? _NarrowLayout(
              icon: _typeIcon(),
              displayName: displayName,
              isPrivate: !doc.isPublic,
              dateLabel: dateLabel,
              sizeLabel: sizeLabel,
              tokens: tokens,
              trailing: readOnly
                  ? null
                  : _ActionsMenu(
                      doc: doc,
                      onView: onView,
                      onDelete: onDelete,
                      onToggleVisibility: onToggleVisibility,
                    ),
            )
          : _WideLayout(
              icon: _typeIcon(),
              displayName: displayName,
              isPrivate: !doc.isPublic,
              dateLabel: dateLabel,
              sizeLabel: sizeLabel,
              tokens: tokens,
              trailing: readOnly
                  ? null
                  : _ActionsMenu(
                      doc: doc,
                      onView: onView,
                      onDelete: onDelete,
                      onToggleVisibility: onToggleVisibility,
                    ),
            ),
    );
  }
}

class _WideLayout extends StatelessWidget {
  const _WideLayout({
    required this.icon,
    required this.displayName,
    required this.isPrivate,
    required this.dateLabel,
    required this.sizeLabel,
    required this.tokens,
    required this.trailing,
  });

  final IconData icon;
  final String displayName;
  final bool isPrivate;
  final String dateLabel;
  final String sizeLabel;
  final InTheme tokens;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: tokens.ink2),
        SizedBox(width: InSpacing.md(context)),
        Expanded(
          flex: 4,
          child: Row(
            children: [
              Flexible(
                child: Text(
                  displayName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: tokens.ink),
                ),
              ),
              if (isPrivate) ...[
                const SizedBox(width: InSpacing.sm),
                Icon(Icons.lock_outline, size: 14, color: tokens.ink3),
              ],
            ],
          ),
        ),
        SizedBox(width: InSpacing.md(context)),
        Expanded(
          flex: 2,
          child: Text(dateLabel, style: TextStyle(color: tokens.ink3)),
        ),
        SizedBox(width: InSpacing.md(context)),
        SizedBox(
          width: 80,
          child: Text(
            sizeLabel,
            textAlign: TextAlign.right,
            style: TextStyle(color: tokens.ink3),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: InSpacing.sm),
          trailing!,
        ],
      ],
    );
  }
}

class _NarrowLayout extends StatelessWidget {
  const _NarrowLayout({
    required this.icon,
    required this.displayName,
    required this.isPrivate,
    required this.dateLabel,
    required this.sizeLabel,
    required this.tokens,
    required this.trailing,
  });

  final IconData icon;
  final String displayName;
  final bool isPrivate;
  final String dateLabel;
  final String sizeLabel;
  final InTheme tokens;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final subtitleParts = <String>[
      if (dateLabel.isNotEmpty) dateLabel,
      if (sizeLabel.isNotEmpty) sizeLabel,
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: tokens.ink2),
        SizedBox(width: InSpacing.md(context)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      displayName,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: tokens.ink),
                    ),
                  ),
                  if (isPrivate) ...[
                    const SizedBox(width: InSpacing.sm),
                    Icon(Icons.lock_outline, size: 14, color: tokens.ink3),
                  ],
                ],
              ),
              if (subtitleParts.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    subtitleParts.join(' · '),
                    style: TextStyle(color: tokens.ink3, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: InSpacing.sm),
          trailing!,
        ],
      ],
    );
  }
}

enum _RowAction { view, toggleVisibility, delete }

class _ActionsMenu extends StatelessWidget {
  const _ActionsMenu({
    required this.doc,
    required this.onView,
    required this.onDelete,
    required this.onToggleVisibility,
  });

  final Document doc;
  final Future<void> Function(Document doc) onView;
  final Future<void> Function(Document doc) onDelete;
  final Future<void> Function(Document doc) onToggleVisibility;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_RowAction>(
      tooltip: context.tr('actions'),
      icon: const Icon(Icons.more_vert),
      onSelected: (action) async {
        switch (action) {
          case _RowAction.view:
            await onView(doc);
          case _RowAction.toggleVisibility:
            await onToggleVisibility(doc);
          case _RowAction.delete:
            // Deliberately NOT behind the "Confirm actions" gate
            // (invoiceninja/flutter#49): `MutationKind.documentDelete` is in
            // every document-bearing entity's `requiresPasswordFor`, so the
            // sync engine already raises `ConfirmPasswordSheet` — and a
            // password prompt *is* the confirmation. Same reasoning keeps bulk
            // delete untagged in `standardCrudBulkActions`.
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
          value: _RowAction.toggleVisibility,
          child: ListTile(
            leading: Icon(
              doc.isPublic ? Icons.lock_outline : Icons.lock_open_outlined,
            ),
            title: Text(
              context.tr(doc.isPublic ? 'set_private' : 'set_public'),
            ),
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
    );
  }
}
