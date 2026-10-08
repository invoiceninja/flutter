import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printing/printing.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/domain/design.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/live_design_service.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/preview/wysiwyg_preview_sheet.dart';

import '../../../../../../_localization_helper.dart';

/// Records the most recent `renderDesignPreview` call so tests can assert
/// the arguments. Returns whatever the test sets up via [result] /
/// [throwOnNext].
class _StubLiveDesignService implements LiveDesignService {
  // A renderable PDF needs both the `%PDF-` header and a trailing `%%EOF`
  // marker — `isRenderablePdf` rejects header-only bytes as truncated.
  Uint8List result = Uint8List.fromList(utf8.encode('%PDF-1.4 fake\n%%EOF'));
  Object? throwOnNext;
  String? lastEntityType;
  String? lastEntityId;
  Design? lastDesign;
  int callCount = 0;

  @override
  Future<Uint8List> renderDesignPreview({
    required String entityType,
    required Design design,
    String? entityId,
  }) async {
    callCount++;
    lastEntityType = entityType;
    lastEntityId = entityId;
    lastDesign = design;
    final t = throwOnNext;
    if (t != null) {
      throwOnNext = null;
      throw t;
    }
    return result;
  }

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'Unexpected call on _StubLiveDesignService: ${invocation.memberName}',
  );
}

Design _design({List<String>? entities}) => Design(
  id: 'd1',
  name: 'Custom',
  isCustom: true,
  isActive: true,
  isTemplate: false,
  isFree: true,
  entities: entities ?? const ['invoice', 'quote'],
  template: const DesignTemplate(body: '<x/>'),
  updatedAt: DateTime.utc(2026),
  createdAt: DateTime.utc(2026),
  archivedAt: null,
  isDeleted: false,
);

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: kTestLocalizationsDelegates,
  supportedLocales: kTestSupportedLocales,
  locale: const Locale('en'),
  theme: buildInTheme(InTheme.light),
  home: Scaffold(body: child),
);

void main() {
  testWidgets('renders the PDF returned by renderDesignPreview', (
    tester,
  ) async {
    final service = _StubLiveDesignService();
    await tester.pumpWidget(
      _wrap(
        WysiwygPreviewSheet(
          service: service,
          design: _design(),
          debounce: Duration.zero,
        ),
      ),
    );
    // Allow the initial async render to complete.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(service.callCount, 1);
    expect(service.lastEntityType, 'invoice');
    expect(service.lastDesign?.id, 'd1');
  });

  testWidgets('defaults entity type to design.entities.first', (tester) async {
    final service = _StubLiveDesignService();
    await tester.pumpWidget(
      _wrap(
        WysiwygPreviewSheet(
          service: service,
          design: _design(entities: const ['credit', 'quote']),
          debounce: Duration.zero,
        ),
      ),
    );
    await tester.pump();
    expect(service.lastEntityType, 'credit');
  });

  testWidgets('falls back to "invoice" when the design has no entities', (
    tester,
  ) async {
    final service = _StubLiveDesignService();
    await tester.pumpWidget(
      _wrap(
        WysiwygPreviewSheet(
          service: service,
          design: _design(entities: const []),
          debounce: Duration.zero,
        ),
      ),
    );
    await tester.pump();
    expect(service.lastEntityType, 'invoice');
  });

  testWidgets('422 surfaces the error message in a banner', (tester) async {
    final service = _StubLiveDesignService()
      ..throwOnNext = const ValidationException('Body has invalid Twig', {
        'design.design.body': ['Unexpected end of expression'],
      });
    await tester.pumpWidget(
      _wrap(
        WysiwygPreviewSheet(
          service: service,
          design: _design(),
          debounce: Duration.zero,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Unexpected end of expression'), findsOneWidget);
  });

  testWidgets(
    'changing the design triggers another render after the debounce',
    (tester) async {
      final service = _StubLiveDesignService();
      final design = _design();
      await tester.pumpWidget(
        _wrap(
          WysiwygPreviewSheet(
            service: service,
            design: design,
            debounce: const Duration(milliseconds: 50),
          ),
        ),
      );
      await tester.pump(); // initial immediate render
      expect(service.callCount, 1);

      // Replace the design — should schedule a debounced render.
      await tester.pumpWidget(
        _wrap(
          WysiwygPreviewSheet(
            service: service,
            design: design.copyWith(name: 'Changed'),
            debounce: const Duration(milliseconds: 50),
          ),
        ),
      );
      // Before the debounce fires, no extra call.
      await tester.pump(const Duration(milliseconds: 10));
      expect(service.callCount, 1);
      // After the debounce fires, the second call lands.
      await tester.pump(const Duration(milliseconds: 100));
      expect(service.callCount, 2);
      expect(service.lastDesign?.name, 'Changed');
    },
  );

  testWidgets('cancelling debounce on a new edit drops the queued render', (
    tester,
  ) async {
    // Two updates within one debounce window → only ONE call lands.
    final service = _StubLiveDesignService();
    await tester.pumpWidget(
      _wrap(
        WysiwygPreviewSheet(
          service: service,
          design: _design(),
          debounce: const Duration(milliseconds: 50),
        ),
      ),
    );
    await tester.pump(); // initial immediate
    expect(service.callCount, 1);

    // Two rapid updates.
    await tester.pumpWidget(
      _wrap(
        WysiwygPreviewSheet(
          service: service,
          design: _design().copyWith(name: 'A'),
          debounce: const Duration(milliseconds: 50),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pumpWidget(
      _wrap(
        WysiwygPreviewSheet(
          service: service,
          design: _design().copyWith(name: 'B'),
          debounce: const Duration(milliseconds: 50),
        ),
      ),
    );
    // Let the debounce fire once.
    await tester.pump(const Duration(milliseconds: 100));
    expect(service.callCount, 2, reason: 'second render coalesced into one');
    expect(service.lastDesign?.name, 'B');
  });

  testWidgets('empty PDF bytes are treated as no-preview, never rastered '
      '(guards the printing RangeError)', (tester) async {
    final service = _StubLiveDesignService()..result = Uint8List(0);
    await tester.pumpWidget(
      _wrap(
        WysiwygPreviewSheet(
          service: service,
          design: _design(),
          debounce: Duration.zero,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(service.callCount, 1);
    // An empty body must NOT reach printing's rasterizer, which throws
    // "RangeError (index): ... Valid value range is empty: 0" on a
    // zero-page document (the diagnostics-log error this guards).
    expect(find.byType(PdfPreview), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a non-PDF response body is treated as no-preview, never rastered',
    (tester) async {
      final service = _StubLiveDesignService()
        ..result = Uint8List.fromList(utf8.encode('<html>error</html>'));
      await tester.pumpWidget(
        _wrap(
          WysiwygPreviewSheet(
            service: service,
            design: _design(),
            debounce: Duration.zero,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(PdfPreview), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  group('Phase 8l — free-user PDF preview watermark', () {
    testWidgets('renders the watermark when isPro is false', (tester) async {
      final service = _StubLiveDesignService();
      await tester.pumpWidget(
        _wrap(
          WysiwygPreviewSheet(
            service: service,
            design: _design(),
            debounce: Duration.zero,
            isPro: false,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      // PDF still renders; watermark sits over it inside a Stack.
      expect(find.byType(PdfPreview), findsOneWidget);
      expect(
        find.byKey(const ValueKey('wysiwyg-preview-watermark')),
        findsOneWidget,
      );
    });

    testWidgets('omits the watermark when isPro is true', (tester) async {
      final service = _StubLiveDesignService();
      await tester.pumpWidget(
        _wrap(
          WysiwygPreviewSheet(
            service: service,
            design: _design(),
            debounce: Duration.zero,
            isPro: true,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(PdfPreview), findsOneWidget);
      expect(
        find.byKey(const ValueKey('wysiwyg-preview-watermark')),
        findsNothing,
      );
    });
  });

  group('Phase 18 — entity dropdown lists all supported types', () {
    testWidgets(
      'non-template design surfaces invoice + quote + credit + purchase_order',
      (tester) async {
        final service = _StubLiveDesignService();
        await tester.pumpWidget(
          _wrap(
            WysiwygPreviewSheet(
              // Bound to only `invoice` but the dropdown should still
              // expose every supported entity for preview.
              service: service,
              design: _design(entities: const ['invoice']),
              debounce: Duration.zero,
            ),
          ),
        );
        await tester.pump();

        final dropdown = tester.widget<DropdownButton<String>>(
          find.byType(DropdownButton<String>),
        );
        final values =
            dropdown.items?.map((i) => i.value).toSet() ?? <String?>{};
        expect(
          values,
          containsAll(<String>['invoice', 'quote', 'credit', 'purchase_order']),
        );
      },
    );

    testWidgets(
      'template design carries the broader supported-template-entities list',
      (tester) async {
        final service = _StubLiveDesignService();
        await tester.pumpWidget(
          _wrap(
            WysiwygPreviewSheet(
              service: service,
              design: _design().copyWith(isTemplate: true),
              debounce: Duration.zero,
            ),
          ),
        );
        await tester.pump();

        final dropdown = tester.widget<DropdownButton<String>>(
          find.byType(DropdownButton<String>),
        );
        final values =
            dropdown.items?.map((i) => i.value).toSet() ?? <String?>{};
        // Templates additionally cover payment / client / project /
        // task / expense per DesignEditViewModel.supportedTemplateEntities.
        expect(
          values,
          containsAll(<String>[
            'invoice',
            'payment',
            'client',
            'project',
            'task',
            'expense',
          ]),
        );
      },
    );
  });

  group('Phase 20c — NetworkException → friendly banner', () {
    testWidgets('a NetworkException surfaces as the network_error i18n string, '
        'not the raw exception', (tester) async {
      final service = _StubLiveDesignService()
        ..throwOnNext = const NetworkException(
          'SocketException: Failed host lookup …',
        );
      await tester.pumpWidget(
        _wrap(
          WysiwygPreviewSheet(
            service: service,
            design: _design(),
            debounce: Duration.zero,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      // _ErrorBanner renders the translated message; we don't lock to
      // the full sentence (kept in `_app_pending.json`) but assert
      // (a) the raw exception text doesn't leak and (b) a
      // recognisable hint surfaces.
      expect(find.textContaining('SocketException'), findsNothing);
      expect(find.textContaining('Network error'), findsOneWidget);
    });
  });

  group('the document it is asked to render', () {
    // Not `pumpAndSettle`: the PDF view spins for as long as it rasterizes.
    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('the chosen invoice, while it is an invoice being previewed', (
      tester,
    ) async {
      final service = _StubLiveDesignService();
      await tester.pumpWidget(
        _wrap(
          WysiwygPreviewSheet(
            service: service,
            design: _design(),
            debounce: Duration.zero,
            embedded: true,
            entityId: 'inv42',
            documentPicker: const Text('Invoice 0042'),
          ),
        ),
      );
      await settle(tester);
      expect(service.lastEntityType, 'invoice');
      expect(service.lastEntityId, 'inv42');
      expect(find.text('Invoice 0042'), findsOneWidget);
      expect(find.text('Sample data chosen by the server'), findsNothing);

      // A quote is not that invoice: the server picks, and the header says
      // so instead of offering an invoice picker that would do nothing.
      await tester.tap(find.byType(DropdownButton<String>));
      await settle(tester);
      await tester.tap(find.text('Quote').last);
      await settle(tester);
      expect(service.lastEntityType, 'quote');
      expect(service.lastEntityId, isNull);
      expect(find.text('Invoice 0042'), findsNothing);
      expect(find.text('Sample data chosen by the server'), findsOneWidget);
    });

    testWidgets('a different invoice renders at once', (tester) async {
      final service = _StubLiveDesignService();
      Widget sheet(String? id) => _wrap(
        WysiwygPreviewSheet(
          service: service,
          design: _design(),
          // A long debounce: only an immediate render can pass below.
          debounce: const Duration(seconds: 30),
          embedded: true,
          entityId: id,
        ),
      );
      await tester.pumpWidget(sheet('a'));
      await settle(tester);
      expect(service.lastEntityId, 'a');
      await tester.pumpWidget(sheet('b'));
      await settle(tester);
      expect(service.lastEntityId, 'b');
      expect(service.callCount, 2);
    });

    testWidgets('the type picked is reported, and opens the next preview', (
      tester,
    ) async {
      final service = _StubLiveDesignService();
      String? remembered;
      await tester.pumpWidget(
        _wrap(
          WysiwygPreviewSheet(
            service: service,
            design: _design(),
            debounce: Duration.zero,
            embedded: true,
            onEntityTypeChanged: (t) => remembered = t,
          ),
        ),
      );
      await settle(tester);
      await tester.tap(find.byType(DropdownButton<String>));
      await settle(tester);
      await tester.tap(find.text('Credit').last);
      await settle(tester);
      expect(remembered, 'credit');

      // Leaving and coming back — a new State — starts where it was left.
      await tester.pumpWidget(_wrap(const SizedBox()));
      await tester.pumpWidget(
        _wrap(
          WysiwygPreviewSheet(
            service: service,
            design: _design(),
            debounce: Duration.zero,
            embedded: true,
            initialEntityType: remembered,
          ),
        ),
      );
      await settle(tester);
      expect(service.lastEntityType, 'credit');
    });
  });

  group('in place of the canvas', () {
    testWidgets('no title and no close: the switch above is both', (
      tester,
    ) async {
      final service = _StubLiveDesignService();
      await tester.pumpWidget(
        _wrap(
          WysiwygPreviewSheet(
            service: service,
            design: _design(),
            debounce: Duration.zero,
            embedded: true,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Preview'), findsNothing);
      expect(find.byTooltip('Close'), findsNothing);
    });
  });

  group('when the render fails', () {
    testWidgets('Retry asks again', (tester) async {
      final service = _StubLiveDesignService()
        ..throwOnNext = const NetworkException('offline');
      await tester.pumpWidget(
        _wrap(
          WysiwygPreviewSheet(
            service: service,
            design: _design(),
            debounce: Duration.zero,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(service.callCount, 1);
      expect(find.byType(PdfPreview), findsNothing);

      await tester.tap(find.widgetWithText(TextButton, 'Retry'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(service.callCount, 2);
      expect(find.byType(PdfPreview), findsOneWidget);
    });

    testWidgets('an unexpected failure is a sentence, not a stack frame', (
      tester,
    ) async {
      final service = _StubLiveDesignService()
        ..throwOnNext = StateError('Bad state: _pdfium was null');
      await tester.pumpWidget(
        _wrap(
          WysiwygPreviewSheet(
            service: service,
            design: _design(),
            debounce: Duration.zero,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.textContaining('_pdfium'), findsNothing);
      expect(find.text('An error occurred'), findsOneWidget);
    });
  });
}
