import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/services/receipt_text_recognizer.dart';
import 'package:admin/data/services/upload_source.dart';
import 'package:admin/domain/expenses/receipt_parser.dart';
import 'package:admin/domain/expenses/receipt_scanner.dart';

/// The scanner around the engines: what it reads, how a PDF's pages merge,
/// and that a failure is "couldn't read", never a throw.
void main() {
  final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0, 0, 0, 0, 0, 0]);
  final pdf = Uint8List.fromList('%PDF-1.7 fake'.codeUnits);

  List<OcrFragment> rows(List<String> lines) => [
    for (var i = 0; i < lines.length; i++)
      OcrFragment(lines[i], 0.05, i * 0.05, 0.9, 0.03),
  ];

  ReceiptScanner scanner(
    _FakeRecognizer recognizer, {
    List<Uint8List> pages = const [],
    List<({String id, String name})> vendors = const [],
    Duration timeout = const Duration(seconds: 15),
  }) => ReceiptScanner(
    recognizer: recognizer,
    contextFor: (_) async =>
        const ReceiptParseContext(today: Date(2026, 10, 25)),
    vendorsFor: (_) async => vendors,
    vendorCurrencyFor: (_, id) async => id == 'v1' ? '3' : null,
    rasterizePdf: (_) async => pages,
    timeout: timeout,
  );

  test('a photo is read, and its vendor matched with its currency', () async {
    final recognizer = _FakeRecognizer([
      rows(['BLUE BOTTLE COFFEE', '10/18/2026', 'Total 32.40']),
    ]);
    final read = await scanner(
      recognizer,
      vendors: const [(id: 'v1', name: 'Blue Bottle Coffee')],
    ).scan(BytesUploadSource(jpeg, 'IMG_1.jpg'), 'co');

    expect(read?.scan.total?.value.toString(), '32.4');
    expect(read?.vendorId, 'v1');
    expect(read?.vendorCurrencyId, '3');
    expect(recognizer.calls, 1);
  });

  test("a PDF's first page gives the vendor and date, its last the "
      'total', () async {
    final recognizer = _FakeRecognizer([
      rows(['ACME ONLINE', 'Order date 10/02/2026', 'Item 1  10.00']),
      rows(['Item 9  5.00', 'Grand Total 99.00']),
    ]);
    final read = await scanner(
      recognizer,
      pages: [Uint8List(1), Uint8List(2)],
    ).scan(BytesUploadSource(pdf, 'invoice.pdf'), 'co');

    expect(read?.scan.vendorName, 'Acme Online');
    expect(read?.scan.date?.value, const Date(2026, 10, 2));
    expect(read?.scan.total?.value.toString(), '99');
  });

  test("a guessed total on a PDF's last page never beats a labelled one on "
      'its first', () async {
    final terms = rows([
      'Terms and conditions apply',
      'Ref 12.50',
      'Thank you',
    ]);
    expect(
      parseReceiptText(
        terms,
        const ReceiptParseContext(today: Date(2026, 10, 25)),
      ).total?.confidence,
      ReceiptConfidence.check,
      reason: 'the last page alone guesses one',
    );
    final recognizer = _FakeRecognizer([
      rows(['ACME ONLINE', 'Order date 10/02/2026', 'Total 99.00']),
      terms,
    ]);
    final read = await scanner(
      recognizer,
      pages: [Uint8List(1), Uint8List(2)],
    ).scan(BytesUploadSource(pdf, 'invoice.pdf'), 'co');
    expect(read?.scan.total?.value.toString(), '99');
    expect(read?.scan.total?.confidence, ReceiptConfidence.sure);
  });

  test("a PDF the renderer can't open reads as nothing", () async {
    final read = await ReceiptScanner(
      recognizer: _FakeRecognizer([]),
      contextFor: (_) async =>
          const ReceiptParseContext(today: Date(2026, 10, 25)),
      vendorsFor: (_) async => const [],
      vendorCurrencyFor: (_, _) async => null,
      rasterizePdf: (_) async => throw Exception('encrypted'),
    ).scan(BytesUploadSource(pdf, 'locked.pdf'), 'co');
    expect(read, isNull);
  });

  test("the matched vendor's own name comes back, not the till's", () async {
    final read = await scanner(
      _FakeRecognizer([
        rows(['BLUE BOTTLE COFFEE #12', 'Total 4.50']),
      ]),
      vendors: const [(id: 'v1', name: 'Blue Bottle Coffee')],
    ).scan(BytesUploadSource(jpeg, 'IMG_1.jpg'), 'co');
    expect(read?.vendorId, 'v1');
    expect(read?.vendorName, 'Blue Bottle Coffee');
  });

  test('a HEIC is not readable on Windows, which needs the Store '
      'extensions to decode it', () async {
    final heic = BytesUploadSource(
      Uint8List.fromList([0, 0, 0, 0x18, ...'ftypheic'.codeUnits]),
      'IMG_1.HEIC',
    );
    expect(await ReceiptScanner.isReadable(heic), isTrue);
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      expect(await ReceiptScanner.isReadable(heic), isFalse);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  test('a file that is no image or PDF is not read', () async {
    final recognizer = _FakeRecognizer([]);
    final read = await scanner(recognizer).scan(
      BytesUploadSource(Uint8List.fromList('hello'.codeUnits), 'a.txt'),
      'co',
    );
    expect(read, isNull);
    expect(recognizer.calls, 0);
    expect(
      await ReceiptScanner.isReadable(
        BytesUploadSource(Uint8List.fromList('hello'.codeUnits), 'a.jpg'),
      ),
      isFalse,
      reason: 'by its bytes, not its name',
    );
  });

  test('no text, an engine failure or a timeout reads as nothing', () async {
    expect(
      await scanner(
        _FakeRecognizer([const []]),
      ).scan(BytesUploadSource(jpeg, 'a.jpg'), 'co'),
      isNull,
    );
    expect(
      await scanner(
        _FakeRecognizer([null]),
      ).scan(BytesUploadSource(jpeg, 'a.jpg'), 'co'),
      isNull,
    );
    expect(
      await scanner(
        _FakeRecognizer([], hang: true),
        timeout: const Duration(milliseconds: 10),
      ).scan(BytesUploadSource(jpeg, 'a.jpg'), 'co'),
      isNull,
    );
  });

  test('a device without an engine reads nothing', () async {
    final recognizer = _FakeRecognizer([], supported: false);
    expect(await scanner(recognizer).isSupported(), isFalse);
    expect(
      await scanner(recognizer).scan(BytesUploadSource(jpeg, 'a.jpg'), 'co'),
      isNull,
    );
  });
}

class _FakeRecognizer implements ReceiptTextRecognizer {
  _FakeRecognizer(this.pages, {this.supported = true, this.hang = false});

  final List<List<OcrFragment>?> pages;
  final bool supported;
  final bool hang;
  var calls = 0;

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<List<OcrFragment>?> recognize({String? path, Uint8List? bytes}) {
    if (hang) return Completer<List<OcrFragment>?>().future;
    final page = calls < pages.length ? pages[calls] : null;
    calls++;
    return Future.value(page);
  }
}
