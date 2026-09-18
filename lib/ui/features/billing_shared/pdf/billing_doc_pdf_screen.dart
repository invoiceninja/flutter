import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/document_version.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/back_dismissible_menu_anchor.dart';
import 'package:admin/ui/features/billing_shared/billing_doc_type.dart';
import 'package:admin/ui/features/billing_shared/history/versioned_pdf_pane.dart';
import 'package:admin/ui/features/billing_shared/pdf/billing_doc_pdf_view.dart';
import 'package:admin/utils/formatting.dart';

/// Full-screen route wrapping [BillingDocPdfView]. Reached via
/// `/invoices/:id/pdf` (and the analogous routes for quote / credit / PO /
/// recurring). The view's built-in `printing` toolbar handles print / share /
/// download — this scaffold just provides the title strip + back affordance,
/// plus the version picker when the route carries `?activity_id=`.
class BillingDocPdfScreen extends StatelessWidget {
  const BillingDocPdfScreen({
    super.key,
    required this.entity,
    required this.entityNumber,
    required this.fetcher,
    this.initialDeliveryNote = false,
    this.deliveryNoteAvailable = true,
    this.revision,
    this.autoRefreshDebounce,
    this.versions = const [],
    this.selectedActivityId,
    this.onVersionChanged,
    this.formatter,
  });

  final BillingDocType entity;
  final String entityNumber;
  final Future<Uint8List> Function({
    String? designId,
    required bool deliveryNote,
  })
  fetcher;

  /// Forwarded to [BillingDocPdfView.initialDeliveryNote] — opens the
  /// preview with the delivery-note variant pre-selected (invoices only).
  final bool initialDeliveryNote;

  /// Forwarded to [BillingDocPdfView.deliveryNoteAvailable]. The
  /// delivery-note route needs a real (saved) id, so the draft preview
  /// opened from an edit screen passes `false` while the doc is still
  /// `tmp_<uuid>`; a frozen version render passes `false` too, having no
  /// variant to switch to.
  final bool deliveryNoteAvailable;

  /// Forwarded to [BillingDocPdfView.revision] — change it to refetch.
  ///
  /// This is the seam a version switch uses, in preference to re-keying this
  /// widget: this widget *is* the `Scaffold` + `AppBar`, so a remount would
  /// tear down the picker the user just tapped (and `MenuAnchor` closes after
  /// its item callback runs, so the dismissal bookkeeping would never fire).
  final Object? revision;

  /// Forwarded to [BillingDocPdfView.autoRefreshDebounce]. A version switch
  /// passes [Duration.zero]; an edit-screen live preview wants the default.
  final Duration? autoRefreshDebounce;

  /// Selectable versions, newest first. Empty hides the picker.
  final List<DocumentVersion> versions;

  /// Null means the live document.
  final String? selectedActivityId;
  final void Function(String? activityId)? onVersionChanged;

  /// Names the versions in the picker. Optional — without it they fall back
  /// to an ISO timestamp.
  final Formatter? formatter;

  String _versionLabel(BuildContext context, DocumentVersion v) =>
      documentVersionLabel(v, formatter);

  @override
  Widget build(BuildContext context) {
    final number = entityNumber.isEmpty ? '' : ' · #$entityNumber';
    final selected = selectedActivityId;
    final current = selected == null
        ? null
        : versions.where((v) => v.activityId == selected).firstOrNull;
    // The title names the version, so a screenshot or a shared window is not
    // ambiguous about which one is on screen.
    final suffix = selected == null
        ? ''
        : ' · ${current == null ? context.tr('history') : _versionLabel(context, current)}';

    return Scaffold(
      appBar: AppBar(
        title: Text('${context.tr('view_pdf')}$number$suffix'),
        actions: [
          if (versions.isNotEmpty && onVersionChanged != null)
            _VersionPicker(
              versions: versions,
              selectedActivityId: selected,
              onChanged: onVersionChanged!,
              labelOf: (v) => _versionLabel(context, v),
            ),
        ],
      ),
      body: BillingDocPdfView(
        entity: entity,
        // Carries into the downloaded file name so two versions of one
        // document cannot save over each other. Date **and time**, via the
        // shared label: a date-only suffix collides for same-day edits,
        // which is the common case inside a 50-row window.
        entityNumber: selected == null || current == null
            ? entityNumber
            : '${entityNumber}_${_versionLabel(context, current)}',
        fetcher: fetcher,
        initialDeliveryNote: initialDeliveryNote,
        deliveryNoteAvailable: deliveryNoteAvailable,
        revision: revision,
        autoRefreshDebounce:
            autoRefreshDebounce ?? const Duration(milliseconds: 600),
      ),
    );
  }
}

/// Version chooser for the narrow route.
///
/// A menu rather than a form dropdown: it has to live in an `AppBar`, Android
/// back must dismiss it (which `BackDismissibleMenuAnchor` handles and a bare
/// `MenuAnchor` does not), and the list is bounded by the server's own
/// 50-activity window.
class _VersionPicker extends StatelessWidget {
  const _VersionPicker({
    required this.versions,
    required this.selectedActivityId,
    required this.onChanged,
    required this.labelOf,
  });

  final List<DocumentVersion> versions;
  final String? selectedActivityId;
  final void Function(String? activityId) onChanged;
  final String Function(DocumentVersion) labelOf;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return BackDismissibleMenuAnchor(
      consumeOutsideTap: true,
      menuChildren: [
        // `Semantics(checked:)`, not the glyph alone: a screen reader would
        // otherwise hear a list of identical timestamps with no way to tell
        // which one is on screen.
        _PickerItem(
          label: context.tr('current_version'),
          checked: selectedActivityId == null,
          onPressed: () => onChanged(null),
          tint: tokens.ink3,
        ),
        for (final v in versions)
          _PickerItem(
            label: labelOf(v),
            checked: selectedActivityId == v.activityId,
            onPressed: () => onChanged(v.activityId),
            tint: tokens.ink3,
          ),
      ],
      builder: (context, controller, _) => IconButton(
        icon: const Icon(Icons.layers_outlined),
        tooltip: context.tr('history'),
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}

class _PickerItem extends StatelessWidget {
  const _PickerItem({
    required this.label,
    required this.checked,
    required this.onPressed,
    required this.tint,
  });

  final String label;
  final bool checked;
  final VoidCallback onPressed;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: checked,
      child: MenuItemButton(
        leadingIcon: Icon(
          checked ? Icons.radio_button_checked : Icons.radio_button_unchecked,
          size: 16,
          color: tint,
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}
