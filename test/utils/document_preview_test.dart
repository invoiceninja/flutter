import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:admin/utils/document_preview.dart';

Uint8List _bytes(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  group('previewKindForType', () {
    test('a pdf is a pdf, whatever its case', () {
      expect(previewKindForType('pdf'), DocumentPreviewKind.pdf);
      expect(previewKindForType('PDF'), DocumentPreviewKind.pdf);
    });

    test('the image types every platform decodes are images', () {
      for (final t in ['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp']) {
        expect(previewKindForType(t), DocumentPreviewKind.image, reason: t);
      }
    });

    test('uploadable types nothing in the app can draw are saved instead', () {
      // heic and svg are uploadable images, but `Image.memory` cannot draw an
      // svg anywhere nor a heic on Android or web.
      for (final t in ['heic', 'svg', 'docx', 'xlsx', 'csv', 'txt', '']) {
        expect(previewKindForType(t), DocumentPreviewKind.none, reason: t);
      }
    });
  });

  group('previewKindForBytes', () {
    test('a renderable pdf stays a pdf', () {
      expect(
        previewKindForBytes('pdf', _bytes('%PDF-1.4\nbody\n%%EOF')),
        DocumentPreviewKind.pdf,
      );
    });

    test(
      'a "pdf" that is not one is saved, never handed to the rasterizer',
      () {
        expect(
          previewKindForBytes('pdf', _bytes('<html>oops</html>')),
          DocumentPreviewKind.none,
        );
        // Truncated: the header is there, the %%EOF is not.
        expect(
          previewKindForBytes('pdf', _bytes('%PDF-1.4\nbody')),
          DocumentPreviewKind.none,
        );
      },
    );

    test('an image is left to the decoder to judge', () {
      expect(
        previewKindForBytes('png', _bytes('not really a png')),
        DocumentPreviewKind.image,
      );
    });
  });

  group('documentFileName', () {
    test('keeps a name that already carries its extension', () {
      expect(documentFileName('receipt.pdf', 'pdf'), 'receipt.pdf');
      expect(documentFileName('Receipt.PDF', 'pdf'), 'Receipt.pdf');
    });

    test('adds the extension when the name lacks it', () {
      expect(documentFileName('receipt', 'pdf'), 'receipt.pdf');
    });

    test('sanitizes the base name', () {
      expect(documentFileName('INV/2026:01.pdf', 'pdf'), 'INV-2026-01.pdf');
    });

    test('falls back to "document" when nothing usable is left', () {
      expect(documentFileName('', 'png'), 'document.png');
      expect(documentFileName('///', 'png'), 'document.png');
    });

    test('a long name keeps its extension through the truncation', () {
      final name = '${'a' * 200}.pdf';
      final out = documentFileName(name, 'pdf');
      expect(out, endsWith('.pdf'));
      expect(utf8.encode(out).length, lessThan(name.length));
    });

    test('a type that is not an extension is not written into the name', () {
      expect(documentFileName('scan', 'p/df'), 'scan');
      expect(documentFileName('scan', ''), 'scan');
    });
  });
}
