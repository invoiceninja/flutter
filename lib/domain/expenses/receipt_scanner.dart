import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:collection/collection.dart';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

import 'package:admin/data/services/receipt_text_recognizer.dart';
import 'package:admin/data/services/shared_intake_files.dart';
import 'package:admin/data/services/upload_source.dart';
import 'package:admin/domain/expenses/receipt_parser.dart';
import 'package:admin/domain/expenses/vendor_matcher.dart';
import 'package:admin/utils/file_type.dart';

/// What reading one receipt found, ready to fill a New Expense.
class ReceiptRead {
  const ReceiptRead({
    required this.scan,
    this.vendorId,
    this.vendorName,
    this.vendorCurrencyId,
  });

  final ReceiptScan scan;

  /// The company's vendor the receipt is from ([matchVendor]); null when
  /// none clearly is. `scan.vendorName` is still there to offer a create.
  final String? vendorId;

  /// That vendor's own name — what the form shows, not the till's
  /// `WHOLEFDS MKT #10234`.
  final String? vendorName;

  /// That vendor's currency, for the same step the vendor picker takes.
  final String? vendorCurrencyId;
}

/// Reads a photo or PDF attached to a New Expense into expense fields, on
/// the device (`docs/receipt-ocr.md`). Provided at the root as a nullable
/// `ReceiptScanner?`, so screens and their tests work without one.
class ReceiptScanner {
  ReceiptScanner({
    required ReceiptTextRecognizer recognizer,
    required Future<ReceiptParseContext> Function(String companyId) contextFor,
    required Future<List<({String id, String name})>> Function(String companyId)
    vendorsFor,
    required Future<String?> Function(String companyId, String vendorId)
    vendorCurrencyFor,
    required Future<List<Uint8List>> Function(Uint8List pdf) rasterizePdf,
    this.timeout = const Duration(seconds: 15),
  }) : _recognizer = recognizer,
       _contextFor = contextFor,
       _vendorsFor = vendorsFor,
       _vendorCurrencyFor = vendorCurrencyFor,
       _rasterizePdf = rasterizePdf;

  final ReceiptTextRecognizer _recognizer;
  final Future<ReceiptParseContext> Function(String companyId) _contextFor;
  final Future<List<({String id, String name})>> Function(String companyId)
  _vendorsFor;
  final Future<String?> Function(String companyId, String vendorId)
  _vendorCurrencyFor;
  final Future<List<Uint8List>> Function(Uint8List pdf) _rasterizePdf;
  final Duration timeout;

  Future<bool> isSupported() => _recognizer.isSupported();

  /// Whether [source] is something a receipt can be read from: an image the
  /// engines decode, or a PDF — by its first bytes, never its name. HEIC is
  /// not, on Windows: decoding it needs the Store's HEIF/HEVC extensions.
  static Future<bool> isReadable(UploadSource source) async {
    final head = await _head(source);
    if (isHeic(head)) {
      return kIsWeb || defaultTargetPlatform != TargetPlatform.windows;
    }
    return imageExtensionOf(head) != null || isPdf(head);
  }

  /// [source] read as a receipt for [companyId]. Null when it couldn't be
  /// read — not an image or PDF, no text, the engine gave up, or it took
  /// longer than [timeout]. Never throws.
  Future<ReceiptRead?> scan(UploadSource source, String companyId) async {
    try {
      return await _scan(source, companyId).timeout(timeout);
    } catch (_) {
      return null;
    }
  }

  Future<ReceiptRead?> _scan(UploadSource source, String companyId) async {
    if (!await _recognizer.isSupported()) return null;
    final head = await _head(source);
    final pages = <List<OcrFragment>>[];
    if (isPdf(head)) {
      final bytes = await source.readRange(0, await source.length());
      for (final png in await _rasterizePdf(bytes)) {
        final page = await _recognizer.recognize(bytes: png);
        if (page != null && page.isNotEmpty) pages.add(page);
      }
    } else if (imageExtensionOf(head) != null || isHeic(head)) {
      // A file the native side can open itself: no copy of a 25 MB photo
      // over the channel.
      final path = kIsWeb ? null : SharedIntakeFiles.localPathOf(source);
      final page = path != null
          ? await _recognizer.recognize(path: path)
          : await _recognizer.recognize(
              bytes: await source.readRange(0, await source.length()),
            );
      if (page != null && page.isNotEmpty) pages.add(page);
    }
    if (pages.isEmpty) return null;

    final ctx = await _contextFor(companyId);
    final scan = _merge([for (final p in pages) parseReceiptText(p, ctx)]);
    if (scan.isEmpty) return null;

    String? vendorId;
    String? vendorName;
    String? vendorCurrencyId;
    final name = scan.vendorName;
    if (name != null) {
      final vendors = await _vendorsFor(companyId);
      vendorId = matchVendor(name, vendors);
      if (vendorId != null) {
        vendorName = vendors.firstWhere((v) => v.id == vendorId).name;
        vendorCurrencyId = await _vendorCurrencyFor(companyId, vendorId);
      }
    }
    return ReceiptRead(
      scan: scan,
      vendorId: vendorId,
      vendorName: vendorName,
      vendorCurrencyId: vendorCurrencyId,
    );
  }

  /// One reading of a PDF's first and last page: the vendor, date, currency
  /// and number from the first page that has them; the total — and the
  /// taxes printed with it — from the last page with a sure one, else the
  /// last with any (a fallback largest-amount guess on a terms page must not
  /// beat a labelled TOTAL on the first).
  static ReceiptScan _merge(List<ReceiptScan> pages) {
    if (pages.length == 1) return pages.single;
    final withTotal =
        pages.lastWhereOrNull(
          (p) => p.total?.confidence == ReceiptConfidence.sure,
        ) ??
        pages.lastWhereOrNull((p) => p.total != null) ??
        pages.first;
    T? first<T>(T? Function(ReceiptScan p) of) {
      for (final p in pages) {
        final v = of(p);
        if (v != null) return v;
      }
      return null;
    }

    return ReceiptScan(
      total: withTotal.total,
      taxes: withTotal.taxes.isNotEmpty
          ? withTotal.taxes
          : first((p) => p.taxes.isEmpty ? null : p.taxes) ?? const [],
      date: first((p) => p.date),
      vendorName: first((p) => p.vendorName),
      currencyCode: first((p) => p.currencyCode),
      receiptNumber: first((p) => p.receiptNumber),
    );
  }

  static Future<Uint8List> _head(UploadSource source) async {
    try {
      final length = await source.length();
      return await source.readRange(0, math.min(12, length));
    } catch (_) {
      return Uint8List(0);
    }
  }
}
