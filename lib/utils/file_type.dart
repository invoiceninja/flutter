import 'dart:typed_data';

/// What a file is, from its first bytes — never its name, which a photo
/// picker or a share sheet may have made up (`IMG_1.heic` holding a JPEG).
/// Twelve bytes are enough for every type here.

bool _startsWith(Uint8List b, int offset, List<int> bytes) {
  if (b.length < offset + bytes.length) return false;
  for (var i = 0; i < bytes.length; i++) {
    if (b[offset + i] != bytes[i]) return false;
  }
  return true;
}

/// `jpg` / `png` / `gif` / `webp` from a file's first bytes, or null for
/// anything else — the four image types the server's upload rule takes.
String? imageExtensionOf(Uint8List head) {
  if (_startsWith(head, 0, const [0xFF, 0xD8, 0xFF])) return 'jpg';
  if (_startsWith(head, 0, const [0x89, 0x50, 0x4E, 0x47])) return 'png';
  if (_startsWith(head, 0, 'GIF8'.codeUnits)) return 'gif';
  if (_startsWith(head, 0, 'RIFF'.codeUnits) &&
      _startsWith(head, 8, 'WEBP'.codeUnits)) {
    return 'webp';
  }
  return null;
}

/// HEIC / HEIF (`ftyp` + a HEIF brand) — an iPhone original, which the
/// server won't take but an OCR engine may read.
bool isHeic(Uint8List head) =>
    _startsWith(head, 4, 'ftyp'.codeUnits) &&
    const [
      'heic',
      'heix',
      'hevc',
      'hevx',
      'mif1',
      'msf1',
    ].any((brand) => _startsWith(head, 8, brand.codeUnits));

/// A PDF: `%PDF`.
bool isPdf(Uint8List head) => _startsWith(head, 0, '%PDF'.codeUnits);
