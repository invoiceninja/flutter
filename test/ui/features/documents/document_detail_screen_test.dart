// The document record screen, assembled — against a real `Services` graph and
// a real local database, the network offline. The harness is
// `test/_support/record_screen_harness.dart`.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/document_api_model.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/core/detail/standing_card.dart';
import 'package:admin/ui/features/documents/views/document_detail_screen.dart';
import 'package:admin/ui/features/documents/widgets/detail/document_detail_header.dart';
import 'package:admin/ui/features/documents/widgets/detail/document_preview_card.dart';

import '../../../_support/record_screen_harness.dart';

DocumentApi _doc({
  String type = 'pdf',
  bool isPublic = true,
  int width = 0,
  int height = 0,
}) => DocumentApi(
  id: 'd1',
  name: 'Signed contract.$type',
  hash: 'abc123',
  type: type,
  size: 2048,
  width: width,
  height: height,
  isPublic: isPublic,
  createdAt: 1700000000,
  updatedAt: 1710000000,
);

/// The screen over [doc], seeded as the harvest would file it: attached to
/// invoice `i1`, which this device has not cached.
void _screenTest(
  String description,
  DocumentApi doc,
  Future<void> Function(WidgetTester tester, RecordScreen screen) body,
) => recordScreenTest(
  description,
  seed: (services) => services.documents.applyRefreshDelta(
    companyId: 'co1',
    parents: [
      (
        type: EntityType.invoice,
        id: 'i1',
        updatedAt: 1710000000,
        documents: [doc],
        prunable: true,
      ),
    ],
  ),
  screen: () => DocumentDetailScreen(id: doc.id),
  ready: () => find.byType(DocumentDetailHeader),
  body: body,
);

Finder _header(String text) => find.descendant(
  of: find.byType(DocumentDetailHeader),
  matching: find.text(text),
);

void main() {
  _screenTest(
    'a file: its name, what kind it is, what it hangs off, and a preview '
    'that waits to be asked for on a narrow window',
    _doc(),
    (tester, screen) async {
      expect(_header('Signed contract.pdf'), findsOneWidget);
      expect(_header('PDF'), findsOneWidget);
      expect(_header('2 KB'), findsOneWidget);

      // Details. The invoice isn't cached, so "Linked to" names its kind.
      expect(find.text('Linked To'), findsOneWidget);
      expect(find.text('Invoice'), findsOneWidget);
      expect(find.text('File Type'), findsOneWidget);
      // Public, so not private — and not "Private" in the header either.
      expect(find.text('Private'), findsOneWidget);
      expect(find.text('No'), findsOneWidget);
      // An image-only row has nothing to say about a PDF.
      expect(find.text('Dimensions'), findsNothing);

      // 480 px wide: the file is not fetched until asked for.
      expect(find.byType(DocumentPreviewCard), findsOneWidget);
      expect(find.text('Show Preview'), findsOneWidget);

      // No figures and no tabs — a file has neither.
      expect(find.byType(StandingCard), findsNothing);
      expect(find.byType(TabBar), findsNothing);
    },
  );

  _screenTest(
    'a private image shows it in the header and its dimensions in Details',
    _doc(type: 'png', isPublic: false, width: 640, height: 480),
    (tester, screen) async {
      expect(_header('Private'), findsOneWidget);
      expect(find.text('640 × 480'), findsOneWidget);
      expect(find.text('Yes'), findsOneWidget);
    },
  );

  _screenTest(
    'a file the app cannot draw has no preview card',
    _doc(type: 'docx'),
    (tester, screen) async {
      expect(find.byType(DocumentPreviewCard), findsNothing);
    },
  );

  _screenTest(
    'View leads the bar — opening the file is what a file is for',
    _doc(),
    (tester, screen) async {
      expect(find.widgetWithText(FilledButton, 'View'), findsOneWidget);
    },
  );
}
