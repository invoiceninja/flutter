import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printing/printing.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/ui/features/billing_shared/billing_doc_type.dart';
import 'package:admin/ui/features/billing_shared/pdf/billing_doc_pdf_view.dart';

import '../../../_localization_helper.dart';

void main() {
  // The fetcher always fails so the widget lands on the ErrorView path and
  // never instantiates `PdfPreview` (which needs the engine rasterizer).
  // We only assert the fetch-scheduling behaviour, so the bytes are
  // irrelevant.
  late int calls;
  Future<Uint8List> fetcher({String? designId, required bool deliveryNote}) {
    calls++;
    return Future<Uint8List>.error(StateError('no server in test'));
  }

  setUp(() => calls = 0);

  Future<void> pump(WidgetTester tester, {Object? revision}) {
    return tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Scaffold(
          body: BillingDocPdfView(
            entity: BillingDocType.invoice,
            entityNumber: 'INV-1',
            fetcher: fetcher,
            revision: revision,
            autoRefreshDebounce: const Duration(milliseconds: 100),
          ),
        ),
      ),
    );
  }

  testWidgets('fetches once on mount', (tester) async {
    await pump(tester, revision: 1);
    await tester.pumpAndSettle();
    expect(calls, 1);
  });

  testWidgets('a revision change re-fetches after the debounce', (
    tester,
  ) async {
    await pump(tester, revision: 1);
    await tester.pumpAndSettle();
    expect(calls, 1);

    await pump(tester, revision: 2);
    // Not yet — still inside the debounce window.
    await tester.pump(const Duration(milliseconds: 50));
    expect(calls, 1);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(calls, 2);
  });

  testWidgets('rapid revision changes coalesce into one re-fetch', (
    tester,
  ) async {
    await pump(tester, revision: 1);
    await tester.pumpAndSettle();
    expect(calls, 1);

    await pump(tester, revision: 2);
    await tester.pump(const Duration(milliseconds: 30));
    await pump(tester, revision: 3);
    await tester.pump(const Duration(milliseconds: 30));
    await pump(tester, revision: 4);

    await tester.pump(const Duration(milliseconds: 120));
    await tester.pumpAndSettle();
    expect(calls, 2);
  });

  testWidgets('null revision never auto-refreshes on rebuild', (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();
    expect(calls, 1);

    await pump(tester);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(calls, 1);
  });

  testWidgets('a Maximize button sits in the toolbar only when asked for', (
    tester,
  ) async {
    // Real bytes this time: the toolbar belongs to `PdfPreview`, which only
    // mounts once a renderable PDF has arrived. Its page raster never lands
    // in a widget test, so a bounded pump, not `pumpAndSettle`.
    final pdf = Uint8List.fromList('%PDF-1.4\n%%EOF\n'.codeUnits);
    var opened = 0;
    Future<void> mount({VoidCallback? onOpenFullSize}) => tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Scaffold(
          body: BillingDocPdfView(
            entity: BillingDocType.quote,
            entityNumber: 'Q-1',
            fetcher: ({String? designId, required bool deliveryNote}) async =>
                pdf,
            onOpenFullSize: onOpenFullSize,
          ),
        ),
      ),
    );

    await mount();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(PdfPreview), findsOneWidget);
    expect(find.byTooltip('Maximize'), findsNothing);

    await mount(onOpenFullSize: () => opened++);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byTooltip('Maximize'));
    expect(opened, 1);
  });
}
