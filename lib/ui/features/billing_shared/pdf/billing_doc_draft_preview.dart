import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/billing_shared/billing_doc_type.dart';
import 'package:admin/ui/features/billing_shared/pdf/billing_doc_pdf_screen.dart';

/// Signature shared by every billing API's `downloadPdf`.
typedef BillingDocPdfFetcher =
    Future<Uint8List> Function({String? designId, required bool deliveryNote});

/// Open a full-screen preview of the **unsaved draft** (invoiceninja/flutter#140).
///
/// A modal sub-flow, not page navigation — the same `MaterialPageRoute(
/// fullscreenDialog: true)` push `showCascadeFullScreenPreview` uses (see the
/// routing rule in `docs/architecture.md` § Navigation).
///
/// Deliberately previews the draft rather than reusing the `⋮ → PDF → View
/// PDF` action, which `go`s to `/invoices/:id/pdf` — the **saved** record. The
/// two are different documents the moment the form is dirty, and on a create
/// form the saved one does not exist yet (that action is in
/// `navigatesOnCreate`, so it saves first).
///
/// The two therefore coexist on a narrow edit header and mean different
/// things, on purpose: the whole `⋮ → PDF` group (View / Download / Print /
/// Delivery note) operates on the **stored** document, and this button on
/// **what you are editing**. Note the consequence for tests — both carry
/// `Icons.picture_as_pdf_outlined`, so a `find.byIcon` with the menu open
/// matches two widgets.
///
/// [BillingDocPdfScreen] leaves `revision` null, so this fetches once. The tab
/// this replaces passed the draft and re-fetched 600 ms after every keystroke.
Future<void> openBillingDocDraftPreview(
  BuildContext context, {
  required BillingDocType entity,
  required String entityNumber,
  required BillingDocPdfFetcher fetcher,
  bool deliveryNoteAvailable = false,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => BillingDocPdfScreen(
        entity: entity,
        entityNumber: entityNumber,
        fetcher: fetcher,
        deliveryNoteAvailable: deliveryNoteAvailable,
      ),
    ),
  );
}

/// The phone edit header's PDF affordance, sitting between `Save` and the `⋮`.
///
/// It replaces the `PDF` tab in the narrow billing-doc edit strip, which cost
/// ~58 px of a strip already 1.4 screens wide and put a read-only viewer in a
/// strip whose every other entry is a group of editable fields. The desktop
/// layout (>= 1024) already agreed — it has no tab strip and renders the PDF
/// as an inline pane — as does React, whose invoice editor has no PDF tab.
///
/// Two things about where this is allowed to live. The screens render it
/// **only** below `Breakpoints.wide`, and that is what keeps it out of
/// `OverflowView`: `EntityEditScaffold` measures its own header slot, which
/// is always narrower than the screen the caller measured, so a screen that
/// says "narrow" guarantees `EntityOverflowActionBar` takes its
/// `compactBar()` branch — a plain `Row`, where an `IconButton` with a
/// `Tooltip` is safe. Inside `spreadBar()` it would not be, per the comment
/// on the Save button in `entity_edit_scaffold.dart`. (The reverse
/// disagreement is real and harmless: between roughly 600 and 680 px the
/// screen says wide while the header slot is still under 600, so the bar
/// goes compact with no preview button in it.) And it is **disabled**,
/// never hidden, when the doc has no party yet: hiding it would make the
/// header jump the moment a client is picked, and disabled is what the tab's
/// own "please select a client" body said in more words.
class BillingDocPreviewButton extends StatelessWidget {
  const BillingDocPreviewButton({
    super.key,
    required this.entity,
    required this.entityNumber,
    required this.fetcher,
    required this.enabled,
    this.deliveryNoteAvailable = false,
  });

  final BillingDocType entity;
  final String entityNumber;
  final BillingDocPdfFetcher fetcher;

  /// False until the doc has a client (a vendor, for purchase orders) — the
  /// server cannot render a preview without one.
  final bool enabled;

  final bool deliveryNoteAvailable;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: context.tr('view_pdf'),
      icon: const Icon(Icons.picture_as_pdf_outlined),
      onPressed: enabled
          ? () => openBillingDocDraftPreview(
              context,
              entity: entity,
              entityNumber: entityNumber,
              fetcher: fetcher,
              deliveryNoteAvailable: deliveryNoteAvailable,
            )
          : null,
    );
  }
}
