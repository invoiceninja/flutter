import 'dart:typed_data';

import 'package:admin/utils/file_names.dart';
import 'package:admin/utils/pdf_bytes_guard.dart';

/// How the app can show an uploaded document's bytes.
enum DocumentPreviewKind {
  /// Rendered by `printing`'s `PdfPreview`.
  pdf,

  /// Drawn with `Image.memory`.
  image,

  /// Nothing in the app can draw it — it is saved instead.
  none,
}

/// Image types every platform's image codec decodes. `heic` and `svg` are
/// uploadable (`kDocumentAllowedExtensions`) but are left out on purpose:
/// `Image.memory` cannot draw an SVG anywhere, nor a HEIC on Android or web.
const _kPreviewableImageTypes = <String>{
  'png',
  'jpg',
  'jpeg',
  'gif',
  'webp',
  'bmp',
};

/// The kind a document should open as, judged by its type (the extension the
/// server records) before anything is fetched — so a `.docx` goes straight to
/// a save instead of opening a viewer with nothing to show.
DocumentPreviewKind previewKindForType(String type) {
  final ext = type.trim().toLowerCase();
  if (ext == 'pdf') return DocumentPreviewKind.pdf;
  if (_kPreviewableImageTypes.contains(ext)) return DocumentPreviewKind.image;
  return DocumentPreviewKind.none;
}

/// The kind to render once the bytes are in hand.
///
/// A PDF must also pass [isRenderablePdf]: `printing`'s rasterizer throws on a
/// truncated or non-PDF body, so bytes that only claim to be a PDF are saved
/// instead of drawn. An image is confirmed by the decoder itself
/// (`Image.memory`'s `errorBuilder`), which is the only honest check.
DocumentPreviewKind previewKindForBytes(String type, Uint8List bytes) {
  final kind = previewKindForType(type);
  if (kind == DocumentPreviewKind.pdf && !isRenderablePdf(bytes)) {
    return DocumentPreviewKind.none;
  }
  return kind;
}

/// An extension is letters and digits only; anything else the server sends in
/// `type` is not one and is dropped rather than written into a file name.
final _kExtension = RegExp(r'^[a-z0-9]{1,10}$');

/// A safe file name for saving or sharing a document called [name] of [type].
///
/// The base name goes through [sanitizeFileName] and the extension is put back
/// after it: sanitizing the whole name could truncate the extension off a long
/// one, and a saved `receipt` with no `.pdf` opens in nothing.
String documentFileName(String name, String type) {
  final ext = type.trim().toLowerCase();
  final hasExt = _kExtension.hasMatch(ext);
  var base = name.trim();
  if (hasExt && base.toLowerCase().endsWith('.$ext')) {
    base = base.substring(0, base.length - ext.length - 1);
  }
  final safe = sanitizeFileName(base);
  return hasExt ? '$safe.$ext' : safe;
}
