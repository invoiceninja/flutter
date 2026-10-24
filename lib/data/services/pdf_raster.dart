import 'dart:typed_data';

import 'package:printing/printing.dart';

/// The first and last page of [pdf] as PNGs, for reading a receipt or an
/// invoice: the vendor and date are on the first, an e-commerce invoice's
/// total usually on the last. A one-page PDF gives one image. Pages past
/// [maxPages] are never rendered. Throws for a PDF the renderer can't open
/// (an encrypted one), which the caller reads as "couldn't read".
Future<List<Uint8List>> rasterizeReceiptPdf(
  Uint8List pdf, {
  double dpi = 200,
  int maxPages = 20,
}) async {
  // Only the two kept pages are encoded: a PNG of a 200 dpi page is the
  // slow half, and a middle page's would be thrown away.
  PdfRaster? first;
  PdfRaster? last;
  var index = 0;
  await for (final page in Printing.raster(pdf, dpi: dpi)) {
    if (index == 0) {
      first = page;
    } else {
      last = page;
    }
    index++;
    if (index >= maxPages) break;
  }
  return [
    if (first != null) await first.toPng(),
    if (last != null) await last.toPng(),
  ];
}
