import 'dart:convert';

import 'package:admin/domain/docuninja/docuninja_signature.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// A transparent canvas with a black bar drawn at [x],[y].
img.Image _pad(int w, int h, {int x = 0, int y = 0, int bw = 0, int bh = 0}) {
  final image = img.Image(width: w, height: h, numChannels: 4);
  if (bw > 0) {
    img.fillRect(
      image,
      x1: x,
      y1: y,
      x2: x + bw - 1,
      y2: y + bh - 1,
      color: img.ColorRgba8(0, 0, 0, 255),
    );
  }
  return image;
}

img.Image _decode(String dataUrl) {
  expect(dataUrl, startsWith('data:image/jpeg;base64,'));
  return img.decodeJpg(base64Decode(dataUrl.split(',').last))!;
}

void main() {
  test('a signature is a white JPEG no larger than React stores', () {
    final out = _decode(
      dnSignatureDataUrl(
        _pad(1200, 600, x: 100, y: 100, bw: 50, bh: 50),
        DnSignatureKind.signature,
      ),
    );
    expect(out.width, lessThanOrEqualTo(600));
    expect(out.height, lessThanOrEqualTo(200));
    // A transparent pad turns white, not black, as a JPEG.
    final corner = out.getPixel(out.width - 1, out.height - 1);
    expect(corner.r, greaterThan(240));
  });

  test('initials fit 200 by 150, and a small image is never scaled up', () {
    final big = _decode(
      dnSignatureDataUrl(_pad(800, 800), DnSignatureKind.initials),
    );
    expect(big.width, lessThanOrEqualTo(200));
    expect(big.height, lessThanOrEqualTo(150));
    final small = _decode(
      dnSignatureDataUrl(_pad(40, 20), DnSignatureKind.initials),
    );
    expect(small.width, 40);
    expect(small.height, 20);
  });

  test('trimming keeps the ink and the padding around it', () {
    final trimmed = dnTrimToInk(
      _pad(1000, 500, x: 400, y: 200, bw: 100, bh: 50),
      padding: 10,
    );
    expect(trimmed.width, 120);
    expect(trimmed.height, 70);
  });

  test('an untouched pad has no ink, and is left as it is', () {
    final empty = _pad(300, 100);
    expect(dnHasInk(empty), isFalse);
    expect(identical(dnTrimToInk(empty), empty), isTrue);
    expect(dnHasInk(_pad(300, 100, x: 5, y: 5, bw: 3, bh: 3)), isTrue);
  });

  test('a stored data URL reads back as bytes; anything else does not', () {
    final url = dnSignatureDataUrl(
      _pad(10, 10, bw: 2, bh: 2),
      DnSignatureKind.signature,
    );
    expect(dnSignatureBytes(url), isNotEmpty);
    expect(dnSignatureBytes(''), isNull);
    expect(dnSignatureBytes('https://example.com/a.png'), isNull);
  });
}
