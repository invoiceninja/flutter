import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/document_version.dart';
import 'package:admin/data/services/document_versions_api.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/billing_shared/billing_doc_type.dart';
import 'package:admin/ui/features/billing_shared/pdf/billing_doc_pdf_view.dart';
import 'package:admin/utils/formatting.dart';

/// The wide detail layout's right-hand PDF pane, able to show either the live
/// document or one selected version of it.
///
/// **Why the pane rather than the `/pdf` route.** `extraChildRoutes` like
/// `/invoices/:id/pdf` are siblings of the `ShellRoute`, so navigating to one
/// takes the whole screen: the list, the tabs, and this pane all disappear.
/// On a desktop that is already showing the live PDF, that destroys the one
/// thing worth comparing a version against. Narrow viewports have no pane and
/// keep the route.
class VersionedPdfPane extends StatefulWidget {
  const VersionedPdfPane({
    super.key,
    required this.entity,
    required this.entityNumber,
    required this.selection,
    required this.api,
    required this.basePath,
    required this.entityId,
    required this.liveFetcher,
    this.formatter,
  });

  final BillingDocType entity;
  final String entityNumber;

  /// Null means the live document.
  final ValueNotifier<String?> selection;
  final DocumentVersionsApi api;

  /// Used to name the selected version in the banner and the download file.
  final String basePath;
  final String entityId;
  final Formatter? formatter;

  /// Fetches the live document's PDF — the pane's default.
  final Future<Uint8List> Function({
    String? designId,
    required bool deliveryNote,
  })
  liveFetcher;

  @override
  State<VersionedPdfPane> createState() => _VersionedPdfPaneState();
}

class _VersionedPdfPaneState extends State<VersionedPdfPane> {
  List<DocumentVersion> _versions = const [];
  bool _fetched = false;

  @override
  void initState() {
    super.initState();
    widget.selection.addListener(_onSelectionChanged);
    // Seed synchronously if the History tab already fetched — the common case,
    // since selection only becomes non-null by tapping a row in that tab.
    _versions =
        widget.api
            .peekForEntity(basePath: widget.basePath, id: widget.entityId)
            ?.versions ??
        const [];
  }

  @override
  void dispose() {
    widget.selection.removeListener(_onSelectionChanged);
    super.dispose();
  }

  /// Resolves the list only when a version is actually selected, so an
  /// ordinary detail view never pays for a request it will not use.
  void _onSelectionChanged() {
    // Gated on whether we have *fetched*, never on whether the seed happened
    // to be warm: a seed that suppresses the request is no longer a seed.
    if (widget.selection.value == null || _fetched) return;
    _fetched = true;
    widget.api
        .fetchForEntity(basePath: widget.basePath, id: widget.entityId)
        .then((page) {
          if (!mounted) return;
          setState(() => _versions = page.versions);
        })
        // The PDF still renders without a label; only the banner degrades.
        .catchError((Object _) {});
  }

  DocumentVersion? _selected(String? activityId) {
    if (activityId == null) return null;
    for (final v in _versions) {
      if (v.activityId == activityId) return v;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: widget.selection,
      builder: (context, activityId, _) {
        final selected = _selected(activityId);
        final label = selected == null
            ? null
            : documentVersionLabel(selected, widget.formatter);
        // **Fixed arity, always a Column.** Returning a bare
        // `BillingDocPdfView` for the live case and a `Column` for a version
        // flips the runtimeType at this slot, so `Widget.canUpdate` is false
        // and the framework rebuilds the element from scratch — discarding
        // `_bytes` and blinking to a full-pane spinner at zoom 1 on exactly
        // the two commonest transitions. That is the remount the `revision:`
        // seam below exists to avoid, so the banner slot is always occupied.
        return Column(
          children: [
            if (activityId == null)
              const SizedBox.shrink()
            else
              _ViewingVersionBanner(
                label: label,
                onReset: () => widget.selection.value = null,
              ),
            Expanded(
              child: BillingDocPdfView(
                entity: widget.entity,
                // Carries into the download file name, so two versions of one
                // document cannot save over each other.
                entityNumber: label == null
                    ? widget.entityNumber
                    : '${widget.entityNumber}_$label',
                // A frozen render has no design or delivery-note variant.
                deliveryNoteAvailable: activityId == null,
                // `revision` + a zero debounce, not a `ValueKey` remount —
                // see the Column note above. The existing generation guard
                // handles the race.
                revision: activityId,
                autoRefreshDebounce: Duration.zero,
                fetcher: activityId == null
                    ? widget.liveFetcher
                    : ({String? designId, required bool deliveryNote}) =>
                          widget.api.downloadVersionPdf(activityId),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// How a saved version is named on screen and in a download file name.
///
/// Date **and time**: same-day edits are the common case inside a 50-row
/// window, so a date-only label collides for exactly the documents that have
/// the most history. Falls back to the raw instant when no company
/// [Formatter] has loaded yet.
String documentVersionLabel(DocumentVersion version, Formatter? formatter) =>
    formatter?.date(
      version.createdAt.toIso8601String(),
      showTime: true,
      showSeconds: false,
    ) ??
    version.createdAt.toIso8601String();

/// Says the pane is not showing the live document, names which version it is
/// showing, and gives the way back.
class _ViewingVersionBanner extends StatelessWidget {
  const _ViewingVersionBanner({required this.label, required this.onReset});

  /// Null only while the version list is still resolving.
  final String? label;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: InSpacing.lg(context),
        vertical: InSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: tokens.accentSoft,
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      child: Row(
        children: [
          Icon(Icons.layers_outlined, size: 16, color: tokens.accent),
          SizedBox(width: InSpacing.md(context)),
          Expanded(
            child: Text(
              label ?? context.tr('history'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: tokens.accent),
            ),
          ),
          // An action label, not the noun the row above already carries:
          // "History · Current version" reads as a description of what is on
          // screen, which is the opposite of what this button does.
          TextButton(
            onPressed: onReset,
            child: Text(context.tr('back_to_current_version')),
          ),
        ],
      ),
    );
  }
}
