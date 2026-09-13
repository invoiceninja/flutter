import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/features/billing_shared/billing_doc_type.dart';
import 'package:admin/ui/features/billing_shared/pdf/billing_doc_draft_preview.dart';
import 'package:admin/ui/features/billing_shared/pdf/billing_doc_pdf_screen.dart';

import '../../../../_localization_helper.dart';

/// The affordance that replaced the `PDF` tab in the narrow billing-doc edit
/// strip (invoiceninja/flutter#140).
Future<void> _pump(
  WidgetTester tester, {
  required bool enabled,
  BillingDocPdfFetcher? fetcher,
}) {
  return tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: kTestLocalizationsDelegates,
      home: Scaffold(
        appBar: AppBar(
          title: BillingDocPreviewButton(
            entity: BillingDocType.invoice,
            entityNumber: '0060',
            enabled: enabled,
            // Never completes: the point is that the route opened, and a
            // resolved future would drag the `printing` rasterizer in.
            fetcher:
                fetcher ??
                ({String? designId, required bool deliveryNote}) =>
                    Completer<Uint8List>().future,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('it opens a full-screen preview of the draft', (tester) async {
    await _pump(tester, enabled: true);
    expect(find.byType(BillingDocPdfScreen), findsNothing);

    await tester.tap(find.byIcon(Icons.picture_as_pdf_outlined));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(BillingDocPdfScreen), findsOneWidget);
  });

  testWidgets('a doc with no party yet is disabled, not hidden', (
    tester,
  ) async {
    // Hiding it would make the header jump the moment a client is picked, and
    // "disabled" is what the tab's own `please_select_a_client` body said in
    // more words.
    await _pump(tester, enabled: false);
    final button = tester.widget<IconButton>(find.byType(IconButton));
    expect(button.onPressed, isNull);
    expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);
  });

  testWidgets('the draft preview never offers the delivery note by default', (
    tester,
  ) async {
    // The delivery-note PDF is a dedicated GET route needing a real (saved)
    // id, so a `tmp_` draft must not advertise it.
    await _pump(tester, enabled: true);
    await tester.tap(find.byIcon(Icons.picture_as_pdf_outlined));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final screen = tester.widget<BillingDocPdfScreen>(
      find.byType(BillingDocPdfScreen),
    );
    expect(screen.deliveryNoteAvailable, isFalse);
  });

  group('in the narrow edit header', () {
    /// The shape `EntityEditScaffold` builds below `Breakpoints.wide`: the
    /// title flexes, the cluster does not. `EntityOverflowActionBar` takes
    /// its `compactBar()` branch here, which is also what keeps the preview
    /// button out of `OverflowView` — a `Tooltip` measured inside that
    /// layout callback is what `entity_edit_scaffold.dart` forbids on the
    /// Save button.
    Future<void> pumpHeader(
      WidgetTester tester, {
      double width = 411.4,
      double textScale = 1,
      String title = 'Edit · #0060',
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: kTestLocalizationsDelegates,
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 800),
              textScaler: TextScaler.linear(textScale),
            ),
            child: Center(
              child: SizedBox(
                width: width,
                child: Scaffold(
                  appBar: AppBar(
                    titleSpacing: 16,
                    title: ActionBarLayoutScope(
                      wide: false,
                      child: Builder(
                        builder: (context) => Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 12),
                            EntityOverflowActionBar<String>(
                              leading: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  BillingDocPreviewButton(
                                    entity: BillingDocType.invoice,
                                    entityNumber: '0060',
                                    enabled: true,
                                    fetcher:
                                        ({
                                          String? designId,
                                          required bool deliveryNote,
                                        }) => Completer<Uint8List>().future,
                                  ),
                                  SizedBox(width: InSpacing.md(context)),
                                  FilledButton(
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size(64, 44),
                                    ),
                                    onPressed: () {},
                                    child: const Text('Save'),
                                  ),
                                ],
                              ),
                              items: const [
                                EntityActionItem<String>(
                                  kind: 'archive',
                                  icon: Icons.archive_outlined,
                                  label: 'Archive',
                                  enabled: true,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('Preview · Save · ⋮ all fit a 411 px phone', (tester) async {
      await pumpHeader(tester);
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    testWidgets('the title yields, the cluster does not', (tester) async {
      // A long German title at 1.4x is what would push a fixed-width control
      // off the edge; the title is the `Expanded` and ellipsises instead.
      await pumpHeader(
        tester,
        width: 360,
        textScale: 1.4,
        title: 'Wiederkehrende Rechnung bearbeiten · #0060',
      );
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    testWidgets('it sits before Save, not after it', (tester) async {
      // Secondary, primary, overflow. Reversing it puts a destructive-ish
      // affordance between the primary action and the menu.
      await pumpHeader(tester);
      expect(
        tester.getCenter(find.byIcon(Icons.picture_as_pdf_outlined)).dx,
        lessThan(tester.getCenter(find.text('Save')).dx),
      );
      expect(
        tester.getCenter(find.text('Save')).dx,
        lessThan(tester.getCenter(find.byIcon(Icons.more_vert)).dx),
      );
    });
  });
}
