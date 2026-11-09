import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// A DocuNinja user's saved signature or initials (`e_signature` /
/// `e_initials`): a JPEG data URL, compressed as React compresses it
/// (`common/helpers/image-compression.ts`: white background, at most
/// 600 × 200 for a signature and 200 × 150 for initials, quality 0.7).
/// docs/docuninja.md § Users.
enum DnSignatureKind {
  signature(600, 200),
  initials(200, 150);

  const DnSignatureKind(this.maxWidth, this.maxHeight);

  final int maxWidth;
  final int maxHeight;
}

/// React's JPEG quality, 0.7 on its 0–1 scale.
const int kDnSignatureJpegQuality = 70;

/// The space kept around the ink when [dnTrimToInk] crops (React's typed
/// signature keeps 40 px on its 1200 × 600 canvas).
const int kDnSignaturePadding = 40;

/// [image] as React stores it: scaled down (never up) to fit [kind], laid on
/// white (a transparent pad or PNG would otherwise turn black in a JPEG),
/// and encoded as a `data:image/jpeg;base64,` URL.
String dnSignatureDataUrl(img.Image image, DnSignatureKind kind) {
  var out = image;
  if (out.width > kind.maxWidth || out.height > kind.maxHeight) {
    final scale = [
      kind.maxWidth / out.width,
      kind.maxHeight / out.height,
    ].reduce((a, b) => a < b ? a : b);
    out = img.copyResize(
      out,
      width: (out.width * scale).round().clamp(1, kind.maxWidth),
      height: (out.height * scale).round().clamp(1, kind.maxHeight),
      interpolation: img.Interpolation.average,
    );
  }
  final flat = img.Image(width: out.width, height: out.height)
    ..clear(img.ColorRgb8(255, 255, 255));
  img.compositeImage(flat, out);
  final jpeg = img.encodeJpg(flat, quality: kDnSignatureJpegQuality);
  return 'data:image/jpeg;base64,${base64Encode(jpeg)}';
}

/// Raw RGBA pixels (as `dart:ui` hands them over, from a pad, typed text or
/// a decoded upload) as an image [dnSignatureDataUrl] and [dnTrimToInk] take.
/// The app decodes with `dart:ui`, so only the JPEG encoder of `image` is
/// ever linked in.
img.Image dnImageFromRgba(Uint8List rgba, int width, int height) =>
    img.Image.fromBytes(
      width: width,
      height: height,
      bytes: rgba.buffer,
      bytesOffset: rgba.offsetInBytes,
      numChannels: 4,
      order: img.ChannelOrder.rgba,
    );

/// [image] cropped to its ink (anything not near-white and not transparent)
/// with [padding] kept around it, so a signature placed in a field is not
/// mostly empty margin. An image with no ink comes back as it is.
img.Image dnTrimToInk(img.Image image, {int padding = kDnSignaturePadding}) {
  var left = image.width;
  var top = image.height;
  var right = -1;
  var bottom = -1;
  for (final p in image) {
    final ink = p.a > 16 && (p.r < 240 || p.g < 240 || p.b < 240);
    if (!ink) continue;
    if (p.x < left) left = p.x;
    if (p.x > right) right = p.x;
    if (p.y < top) top = p.y;
    if (p.y > bottom) bottom = p.y;
  }
  if (right < 0) return image;
  final x = (left - padding).clamp(0, image.width - 1);
  final y = (top - padding).clamp(0, image.height - 1);
  final w = ((right + padding).clamp(0, image.width - 1) - x) + 1;
  final h = ((bottom + padding).clamp(0, image.height - 1) - y) + 1;
  return img.copyCrop(image, x: x, y: y, width: w, height: h);
}

/// Whether [image] has any ink at all (an untouched pad has none).
bool dnHasInk(img.Image image) => !identical(dnTrimToInk(image), image);

/// The image bytes of a stored `data:` URL, or null when [dataUrl] is not
/// one (an empty value, or a URL some other client stored).
Uint8List? dnSignatureBytes(String dataUrl) {
  if (!dataUrl.startsWith('data:')) return null;
  return Uri.tryParse(dataUrl)?.data?.contentAsBytes();
}
