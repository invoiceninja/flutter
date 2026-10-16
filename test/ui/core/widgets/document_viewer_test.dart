import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:printing/printing.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/domain/document.dart';
import 'package:admin/data/services/api_client.dart';
import 'package:admin/data/services/api_credentials.dart';
import 'package:admin/data/services/documents_api.dart';
import 'package:admin/data/services/password_cache.dart';
import 'package:admin/ui/core/widgets/document_viewer.dart';
import 'package:admin/ui/core/widgets/error_view.dart';

import '../../../_localization_helper.dart';

const _pdfDoc = Document(
  id: 'd1',
  name: 'receipt.pdf',
  hash: 'h1',
  type: 'pdf',
  url: 'https://example.com/api/v1/documents/d1/download',
);

const _pngDoc = Document(id: 'd2', name: 'photo.png', hash: 'h2', type: 'png');

// A renderable PDF needs the `%PDF-` header and a trailing `%%EOF`.
final _pdf = Uint8List.fromList(utf8.encode('%PDF-1.4 fake\n%%EOF'));

// A 1×1 transparent PNG.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);

Future<void> _pump(
  WidgetTester tester, {
  required Document doc,
  required Future<Uint8List> Function() fetch,
  Size? size,
}) async {
  Widget viewer = DocumentViewer(doc: doc, fetch: fetch);
  if (size != null) {
    viewer = Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(size: size),
        child: DocumentViewer(doc: doc, fetch: fetch),
      ),
    );
  }
  await tester.pumpWidget(
    MaterialApp(
      theme: buildInTheme(InTheme.light),
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: kTestSupportedLocales,
      home: viewer,
    ),
  );
  // Let the fetch resolve. Not pumpAndSettle: `PdfPreview` keeps rasterizing.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('a PDF opens in PdfPreview, titled with the document name', (
    tester,
  ) async {
    await _pump(tester, doc: _pdfDoc, fetch: () async => _pdf);

    expect(find.byType(PdfPreview), findsOneWidget);
    expect(find.text('receipt.pdf'), findsOneWidget);
    // Download is offered once the bytes are in hand.
    expect(find.byTooltip('Download'), findsOneWidget);
  });

  testWidgets('an image opens zoomable', (tester) async {
    await _pump(tester, doc: _pngDoc, fetch: () async => _png);

    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.byType(PdfPreview), findsNothing);
  });

  testWidgets('a "pdf" that is not one offers Download instead of rendering', (
    tester,
  ) async {
    await _pump(
      tester,
      doc: _pdfDoc,
      fetch: () async => Uint8List.fromList(utf8.encode('<html>no</html>')),
    );

    expect(find.byType(PdfPreview), findsNothing);
    expect(find.text('No preview available'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Download'), findsOneWidget);
  });

  testWidgets('a failed fetch shows the error, and Retry fetches again', (
    tester,
  ) async {
    var calls = 0;
    await _pump(
      tester,
      doc: _pdfDoc,
      fetch: () async {
        calls++;
        if (calls == 1) throw Exception('offline');
        return _pdf;
      },
    );

    expect(find.byType(ErrorView), findsOneWidget);
    expect(find.textContaining('offline'), findsOneWidget);
    // Nothing to save while there are no bytes.
    expect(find.byTooltip('Download'), findsNothing);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(calls, 2);
    expect(find.byType(PdfPreview), findsOneWidget);
  });

  testWidgets('an empty body is an error, not a file to save', (tester) async {
    // The server streams before it reads the file, so a file missing from
    // storage arrives as an empty 200.
    await _pump(tester, doc: _pdfDoc, fetch: () async => Uint8List(0));

    expect(find.byType(ErrorView), findsOneWidget);
    expect(find.textContaining('This file is empty'), findsOneWidget);
    expect(find.byTooltip('Download'), findsNothing);
    expect(find.text('No preview available'), findsNothing);
  });

  testWidgets('end to end through DocumentsApi: the token is sent, and the '
      "server's missing content type does not stop the PDF rendering", (
    tester,
  ) async {
    // The beta report: the server answers a request without the token with
    // `{"message":"Invalid token"}`. This one only serves the file to a
    // request carrying it, the way `token_auth` does.
    final api = DocumentsApi(
      ApiClient(
        credentials: ValueNotifier<ApiCredentials?>(
          const ApiCredentials(baseUrl: 'https://test', token: 't'),
        ),
        passwordCache: PasswordCache(),
        onUnauthorized: () async {},
        httpClient: MockClient((req) async {
          if (req.headers['X-API-Token'] != 't') {
            return http.Response('{"message":"Invalid token"}', 403);
          }
          expect(req.url.path, '/api/v1/documents/d1/download');
          // Laravel's `streamDownload` sets no type of its own.
          return http.Response.bytes(
            _pdf,
            200,
            headers: {'content-type': 'text/html; charset=UTF-8'},
          );
        }),
      ),
    );

    await _pump(tester, doc: _pdfDoc, fetch: () => api.download(_pdfDoc.id));

    expect(find.byType(PdfPreview), findsOneWidget);
    expect(find.textContaining('Invalid token'), findsNothing);
  });

  testWidgets('full screen on a phone, a windowed dialog on a wide window', (
    tester,
  ) async {
    await _pump(
      tester,
      doc: _pdfDoc,
      fetch: () async => _pdf,
      size: const Size(390, 844),
    );
    expect(
      find.byWidgetPredicate(
        (w) => w is Dialog && w.insetPadding == EdgeInsets.zero,
      ),
      findsOneWidget,
    );

    await _pump(
      tester,
      doc: _pdfDoc,
      fetch: () async => _pdf,
      size: const Size(1280, 800),
    );
    expect(
      find.byWidgetPredicate(
        (w) => w is Dialog && w.insetPadding != EdgeInsets.zero,
      ),
      findsOneWidget,
    );
  });
}
