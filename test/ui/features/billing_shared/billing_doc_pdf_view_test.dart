import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printing/printing.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/ui/core/widgets/error_view.dart';
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

  Future<void> pump(
    WidgetTester tester, {
    Object? revision,
    Object? contentRevision,
  }) {
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
            contentRevision: contentRevision,
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

  testWidgets('a revision change re-fetches at once', (tester) async {
    await pump(tester, revision: 1);
    await tester.pumpAndSettle();
    expect(calls, 1);

    // A different document: no debounce to wait out.
    await pump(tester, revision: 2);
    await tester.pump(const Duration(milliseconds: 1));
    expect(calls, 2);
  });

  testWidgets('a content change re-fetches after the debounce', (tester) async {
    await pump(tester, contentRevision: 1);
    await tester.pumpAndSettle();
    expect(calls, 1);

    await pump(tester, contentRevision: 2);
    // Not yet — still inside the debounce window.
    await tester.pump(const Duration(milliseconds: 50));
    expect(calls, 1);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(calls, 2);
  });

  testWidgets('rapid content changes coalesce into one re-fetch', (
    tester,
  ) async {
    await pump(tester, contentRevision: 1);
    await tester.pumpAndSettle();
    expect(calls, 1);

    await pump(tester, contentRevision: 2);
    await tester.pump(const Duration(milliseconds: 30));
    await pump(tester, contentRevision: 3);
    await tester.pump(const Duration(milliseconds: 30));
    await pump(tester, contentRevision: 4);

    await tester.pump(const Duration(milliseconds: 120));
    await tester.pumpAndSettle();
    expect(calls, 2);
  });

  testWidgets('equal content does not re-fetch', (tester) async {
    // Records compare by value, as the freezed rows callers pass do: a
    // stream re-emitting an unchanged row hands over an equal, non-identical
    // object.
    await pump(tester, contentRevision: ('INV-1', 100));
    await tester.pumpAndSettle();
    await pump(tester, contentRevision: ('INV-1', 100));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(calls, 1);
  });

  testWidgets('null revisions never auto-refresh on rebuild', (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();
    expect(calls, 1);

    await pump(tester);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(calls, 1);
  });

  group('with a rendered PDF', () {
    // Real bytes: `PdfPreview` only mounts once a renderable PDF has
    // arrived. Its page raster never lands in a widget test, so bounded
    // pumps, not `pumpAndSettle`.
    final pdfA = Uint8List.fromList('%PDF-1.4\n%A\n%%EOF\n'.codeUnits);
    final pdfB = Uint8List.fromList('%PDF-1.4\n%B\n%%EOF\n'.codeUnits);
    late Future<Uint8List> Function() next;

    Future<void> mount(
      WidgetTester tester, {
      Object? revision,
      Object? contentRevision,
      bool hasUnsyncedChanges = false,
      bool initialDeliveryNote = false,
    }) => tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Scaffold(
          body: BillingDocPdfView(
            entity: BillingDocType.invoice,
            entityNumber: 'INV-1',
            fetcher: ({String? designId, required bool deliveryNote}) => next(),
            revision: revision,
            contentRevision: contentRevision,
            hasUnsyncedChanges: hasUnsyncedChanges,
            initialDeliveryNote: initialDeliveryNote,
            autoRefreshDebounce: const Duration(milliseconds: 50),
          ),
        ),
      ),
    );

    Future<Uint8List> fails() => Future<Uint8List>.error(StateError('offline'));

    final notice = find.text(
      "This preview doesn't include your latest changes",
    );

    testWidgets(
      'a failed content refresh keeps the PDF, marked stale, and Retry '
      'clears it',
      (tester) async {
        next = () async => pdfA;
        await mount(tester, contentRevision: 1);
        await tester.pump(const Duration(milliseconds: 10));
        expect(find.byType(PdfPreview), findsOneWidget);
        expect(
          tester.widget<PdfPreview>(find.byType(PdfPreview)).allowPrinting,
          isTrue,
        );

        next = fails;
        await mount(tester, contentRevision: 2);
        await tester.pump(const Duration(milliseconds: 60));
        await tester.pump();

        expect(find.byType(PdfPreview), findsOneWidget);
        expect(find.byType(ErrorView), findsNothing);
        expect(notice, findsOneWidget);
        final stale = tester.widget<PdfPreview>(find.byType(PdfPreview));
        expect(stale.allowPrinting, isFalse);
        expect(stale.allowSharing, isFalse);

        next = () async => pdfB;
        await tester.tap(find.text('Retry'));
        await tester.pump();
        await tester.pump();
        expect(notice, findsNothing);
        expect(
          tester.widget<PdfPreview>(find.byType(PdfPreview)).allowPrinting,
          isTrue,
        );
      },
    );

    testWidgets('a failed switch to a different document still drops the PDF', (
      tester,
    ) async {
      // A version with no stored file must not leave the live document on
      // screen under that version's title.
      next = () async => pdfA;
      await mount(tester, revision: 'live');
      await tester.pump(const Duration(milliseconds: 10));
      expect(find.byType(PdfPreview), findsOneWidget);

      next = fails;
      await mount(tester, revision: 'activity-7');
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(find.byType(PdfPreview), findsNothing);
      expect(find.byType(ErrorView), findsOneWidget);
    });

    testWidgets(
      'a content change during a switch to another document does not keep '
      'the previous one on screen',
      (tester) async {
        // Picking the live document from a version: the frozen render is
        // still on screen behind the scrim when a sync re-emits the record.
        next = () async => pdfA;
        await mount(tester, revision: 'activity-7');
        await tester.pump(const Duration(milliseconds: 10));

        final pending = Completer<Uint8List>();
        next = () => pending.future;
        await mount(tester, contentRevision: 1);
        await tester.pump(const Duration(milliseconds: 1));

        next = fails;
        await mount(tester, contentRevision: 2);
        await tester.pump(const Duration(milliseconds: 60));
        await tester.pump();

        // Not a quiet refresh over the version's PDF: the failure is the
        // live document's, and nothing of the version is left showing.
        expect(find.byType(PdfPreview), findsNothing);
        expect(find.byType(ErrorView), findsOneWidget);
        expect(notice, findsNothing);
      },
    );

    testWidgets('PdfPreview gets a new build callback only with new bytes', (
      tester,
    ) async {
      // `PdfPreview` re-rasters on every new callback and drops one that
      // lands mid-raster, so a callback rebuilt on each frame could leave
      // the old page on screen after the new bytes arrived.
      next = () async => pdfA;
      await mount(tester, contentRevision: 1);
      await tester.pump(const Duration(milliseconds: 10));
      final first = tester.widget<PdfPreview>(find.byType(PdfPreview)).build;

      final pending = Completer<Uint8List>();
      next = () => pending.future;
      await mount(tester, contentRevision: 2);
      await tester.pump(const Duration(milliseconds: 60));
      // Refreshing, with the progress bar showing: still the same callback.
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(
        tester.widget<PdfPreview>(find.byType(PdfPreview)).build,
        same(first),
      );

      pending.complete(pdfB);
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsNothing);
      final second = tester.widget<PdfPreview>(find.byType(PdfPreview)).build;
      expect(second, isNot(same(first)));
    });

    testWidgets(
      'the delivery note of a document with unsynced edits is marked stale, '
      'with no retry',
      (tester) async {
        next = () async => pdfA;
        await mount(
          tester,
          contentRevision: 1,
          hasUnsyncedChanges: true,
          initialDeliveryNote: true,
        );
        await tester.pump(const Duration(milliseconds: 10));
        expect(notice, findsOneWidget);
        expect(find.text('Retry'), findsNothing);
        expect(
          tester.widget<PdfPreview>(find.byType(PdfPreview)).allowPrinting,
          isFalse,
        );

        // The invoice itself renders the local edit.
        await tester.tap(find.byType(Switch));
        await tester.pump();
        await tester.pump();
        expect(notice, findsNothing);
      },
    );
  });

  testWidgets('a Maximize button sits in the toolbar only when asked for', (
    tester,
  ) async {
    // Real bytes this time: the toolbar belongs to `PdfPreview`, which only
    // mounts once a renderable PDF has arrived. Its page raster never lands
    // in a widget test, so a bounded pump, not `pumpAndSettle`.
    final pdf = Uint8List.fromList('%PDF-1.4\n%%EOF\n'.codeUnits);
    final opened = <bool>[];
    Future<void> mount({ValueChanged<bool>? onOpenFullSize}) =>
        tester.pumpWidget(
          MaterialApp(
            theme: buildInTheme(InTheme.light),
            localizationsDelegates: kTestLocalizationsDelegates,
            supportedLocales: kTestSupportedLocales,
            home: Scaffold(
              body: BillingDocPdfView(
                entity: BillingDocType.invoice,
                entityNumber: 'INV-1',
                fetcher:
                    ({String? designId, required bool deliveryNote}) async =>
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

    await mount(onOpenFullSize: opened.add);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byTooltip('Maximize'));
    expect(opened, [false]);

    // The full-size screen opens on the document the pane shows.
    await tester.tap(find.byType(Switch));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byTooltip('Maximize'));
    expect(opened, [false, true]);
  });
}
