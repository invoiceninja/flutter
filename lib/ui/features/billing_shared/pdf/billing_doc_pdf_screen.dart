import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/billing_shared/billing_doc_type.dart';
import 'package:admin/ui/features/billing_shared/pdf/billing_doc_pdf_view.dart';

/// Full-screen route wrapping [BillingDocPdfView]. Reached via
/// `/invoices/:id/pdf` (and the analogous routes for quote / credit / PO /
/// recurring once those land). The view's built-in `printing` toolbar
/// handles print / share / download — this scaffold just provides the
/// title strip + back affordance.
class BillingDocPdfScreen extends StatelessWidget {
  const BillingDocPdfScreen({
    super.key,
    required this.entity,
    required this.entityNumber,
    required this.fetcher,
    this.initialDeliveryNote = false,
    this.deliveryNoteAvailable = true,
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
  /// `tmp_<uuid>`; the `/:id/pdf` routes watch saved records and keep the
  /// default.
  final bool deliveryNoteAvailable;

  @override
  Widget build(BuildContext context) {
    final number = entityNumber.isEmpty ? '' : ' · #$entityNumber';
    return Scaffold(
      appBar: AppBar(title: Text('${context.tr('view_pdf')}$number')),
      body: BillingDocPdfView(
        entity: entity,
        entityNumber: entityNumber,
        fetcher: fetcher,
        initialDeliveryNote: initialDeliveryNote,
        deliveryNoteAvailable: deliveryNoteAvailable,
      ),
    );
  }
}
