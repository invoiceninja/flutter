// Shared bulk Download / Print PDF handlers for billing-document list screens
// (invoice / quote / credit / purchase_order). The fetch + print/share flow is
// identical across the four entities — only which `*Api` method to call
// differs — so the entity-specific bits arrive as injected closures (the
// domain models share no supertype, so the helpers can't be typed generically;
// closures are the clean seam, matching the rest of `billing_shared/actions/`).
//
// Both are invoked from `EntityListBulkAction.onSelection`. The screen scaffold
// wraps the call in `GenericListViewModel.runSelectionAction`, so the bulk
// buttons disable for the duration and a second tap can't double-fire.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/utils/save_bytes.dart';
import 'package:admin/ui/core/widgets/notify.dart';

/// Bulk Print: fetch the server-merged PDF (`*Api.bulkPrintPdf`) and hand it to
/// the platform print dialog. `bulk_print` is a SYNCHRONOUS server merge that
/// can take several seconds, so a "Processing" toast goes up front and is
/// dismissed once the bytes arrive.
Future<void> bulkPrintBillingDocs(
  BuildContext context, {
  required Future<Uint8List> Function() fetch,
}) async {
  Notify.info(context, context.tr('processing'));
  try {
    final bytes = await fetch();
    if (!context.mounted) return;
    // Clear the "Processing" toast before the OS print sheet takes over.
    Notify.clear(context);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  } catch (e) {
    if (!context.mounted) return;
    // Clear the "Processing" toast, then surface the failure.
    Notify.clear(context);
    Notify.error(context, context.tr('error'), error: e);
  }
}

/// Bulk Download:
///
/// * **>1 doc** → the async server export ([bulkDownload] →
///   `*Api.bulkDownloadPdf`): the server zips the PDFs and emails the user a
///   link, so there's nothing to download client-side — we just toast
///   `exported_data`. This path is a quick fire-and-forget enqueue (no
///   "Processing" toast needed).
/// * **exactly 1 doc** → the single-doc live-preview path ([singleFetch] →
///   `downloadPdf`) for an immediate file. This also sidesteps the
///   invoices/credits ">1 required" server gate on `bulk_download`.
Future<void> bulkDownloadBillingDocs(
  BuildContext context, {
  required int count,
  required Future<void> Function() bulkDownload,
  required Future<Uint8List> Function() singleFetch,
  required String singleFileName,
}) async {
  try {
    if (count == 1) {
      final download = downloadPdf(context, fileName: singleFileName);
      final bytes = await singleFetch();
      if (!context.mounted) return;
      await download(bytes);
      return;
    }
    await bulkDownload();
    if (!context.mounted) return;
    Notify.success(context, context.tr('exported_data'));
  } catch (e) {
    if (!context.mounted) return;
    Notify.error(context, context.tr('an_error_occurred'), error: e);
  }
}
