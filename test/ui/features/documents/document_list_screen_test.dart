// The Documents list, mounted against a real `Services` graph and a real
// local database (network offline): the rows come from Drift, as in the app.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/document_api_model.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/features/documents/views/document_list_screen.dart';
import 'package:admin/ui/features/documents/widgets/document_list_tile.dart';

import '../shell/_shell_test_helpers.dart';

DocumentApi _doc(String id, String name, {bool isPublic = true}) => DocumentApi(
  id: id,
  name: name,
  hash: 'h$id',
  type: 'pdf',
  size: 2048,
  isPublic: isPublic,
  createdAt: 1700000000,
  updatedAt: 1710000000,
);

void main() {
  Future<void> pumpList(WidgetTester tester, Size window) async {
    tester.view.physicalSize = window;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fixture = await buildFixture(
      companies: const [FakeCompany(id: 'co1', name: 'Acme')],
    );
    addTearDown(fixture.dispose);
    await fixture.services.documents.applyRefreshDelta(
      companyId: 'co1',
      parents: [
        (
          type: EntityType.quote,
          id: 'q1',
          updatedAt: 1710000000,
          documents: [
            _doc('d1', 'Signed contract.pdf'),
            _doc('d2', 'Internal notes.pdf', isPublic: false),
          ],
          prunable: true,
        ),
      ],
    );

    await tester.pumpWidget(
      wrapWithShell(fixture.services, const DocumentListScreen()),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Tear the subtree down inside the test so the Drift watches' close timers
  /// fire before the binding's end-of-test timer check.
  Future<void> disposeTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('wide: the files, what each hangs off, and no New button', (
    tester,
  ) async {
    await pumpList(tester, const Size(1400, 900));

    expect(find.byType(DocumentListTile), findsNWidgets(2));
    expect(find.text('Signed contract.pdf'), findsOneWidget);
    // Column headers are drawn in capitals.
    expect(find.text('LINKED TO'), findsOneWidget);
    // The quote isn't cached, so the cell names its kind.
    expect(find.text('Quote'), findsNWidgets(2));
    // A file is uploaded on its record: nothing here creates one.
    expect(find.byIcon(Icons.add), findsNothing);
    await disposeTree(tester);
  });

  testWidgets('narrow: no FAB, and a private file says so under its name', (
    tester,
  ) async {
    await pumpList(tester, const Size(400, 800));

    expect(find.byType(DocumentListTile), findsNWidgets(2));
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.textContaining('Private'), findsOneWidget);
    await disposeTree(tester);
  });
}
