import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/domain/document.dart';
import 'package:admin/data/services/upload_source.dart';
import 'package:admin/ui/core/detail/entity_documents_tab.dart';
import 'package:admin/ui/core/widgets/file_drop_zone.dart';

import '../../../_localization_helper.dart';

const _docA = Document(
  id: 'd1',
  name: 'invoice.pdf',
  hash: 'h1',
  type: 'pdf',
  url: 'https://example.com/d1.pdf',
  size: 1024,
  isPublic: true,
  createdAt: 1700000000,
  updatedAt: 1700000000,
);

Future<void> _pump(
  WidgetTester tester, {
  required String entityId,
  required List<Document> documents,
  bool readOnly = false,
  Future<void> Function(List<UploadSource>)? onUpload,
  Future<void> Function(Document)? onDelete,
  Future<void> Function(Document)? onToggleVisibility,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildInTheme(InTheme.light),
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: kTestSupportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 800,
          child: EntityDocumentsTab(
            entityId: entityId,
            documents: documents,
            readOnly: readOnly,
            onUpload: onUpload ?? (_) async {},
            onDelete: onDelete ?? (_) async {},
            onToggleVisibility: onToggleVisibility ?? (_) async {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('EntityDocumentsTab', () {
    testWidgets(
      'tmp_ entity renders only the save-first banner, no dropzone or table',
      (tester) async {
        await _pump(tester, entityId: 'tmp_abc123', documents: const [_docA]);
        expect(
          find.text('Save the record to upload documents'),
          findsOneWidget,
        );
        expect(find.byType(FileDropZone), findsNothing);
        expect(
          find.byWidgetPredicate((w) => w is PopupMenuButton),
          findsNothing,
        );
        // Document row should NOT render even though the list is non-empty —
        // the save-first banner short-circuits the body.
        expect(find.text('invoice.pdf'), findsNothing);
      },
    );

    testWidgets(
      'empty real entity renders the upload affordance + no-records line',
      (tester) async {
        await _pump(tester, entityId: 'real_123', documents: const []);
        // The drop-or-click upload affordance is the shared FileDropZone.
        expect(find.byType(FileDropZone), findsOneWidget);
        expect(find.byIcon(Icons.upload_file_outlined), findsOneWidget);
        // Terse empty-state copy from `no_records_found`.
        expect(find.text('No records found'), findsOneWidget);
      },
    );

    testWidgets(
      'real entity with documents renders each row with name + actions menu',
      (tester) async {
        await _pump(tester, entityId: 'real_123', documents: const [_docA]);
        expect(find.text('invoice.pdf'), findsOneWidget);
        // Actions menu (PopupMenuButton) is present per row when not read-only.
        expect(
          find.byWidgetPredicate((w) => w is PopupMenuButton),
          findsOneWidget,
        );
      },
    );

    testWidgets('readOnly mode hides upload and the mutating row actions, '
        'and keeps View', (tester) async {
      await _pump(
        tester,
        entityId: 'real_123',
        documents: const [_docA],
        readOnly: true,
      );
      // No upload affordance anywhere.
      expect(find.byType(FileDropZone), findsNothing);
      expect(find.byIcon(Icons.upload_file_outlined), findsNothing);
      // The row itself still renders so users can see what's attached.
      expect(find.text('invoice.pdf'), findsOneWidget);

      // And can still open it. Read-only used to drop the whole menu, which
      // left a document that was there to be read with no way to read it.
      await tester.tap(find.byWidgetPredicate((w) => w is PopupMenuButton));
      await tester.pumpAndSettle();
      expect(find.text('View'), findsOneWidget);
      expect(find.text('Delete'), findsNothing);
      expect(find.text('Set Private'), findsNothing);
    });

    testWidgets(
      'tapping Delete fires onDelete immediately (no preceding AlertDialog — '
      'the sync engine fires ConfirmPasswordSheet as the confirmation)',
      (tester) async {
        Document? deleted;
        await _pump(
          tester,
          entityId: 'real_123',
          documents: const [_docA],
          onDelete: (doc) async {
            deleted = doc;
          },
        );
        // Open the actions menu.
        await tester.tap(find.byWidgetPredicate((w) => w is PopupMenuButton));
        await tester.pumpAndSettle();
        // Tap "Delete".
        await tester.tap(find.text('Delete').last);
        await tester.pumpAndSettle();
        expect(deleted?.id, 'd1');
        // No AlertDialog appeared as part of this flow.
        expect(find.byType(AlertDialog), findsNothing);
      },
    );

    testWidgets(
      'private document shows lock icon, menu label flips to "Set public"',
      (tester) async {
        const docPrivate = Document(
          id: 'd2',
          name: 'secret.pdf',
          hash: 'h2',
          type: 'pdf',
          url: 'https://example.com/d2.pdf',
          size: 2048,
          isPublic: false,
          createdAt: 1700000000,
          updatedAt: 1700000000,
        );
        await _pump(
          tester,
          entityId: 'real_123',
          documents: const [docPrivate],
        );
        // Lock icon is shown alongside the filename for private docs.
        expect(find.byIcon(Icons.lock_outline), findsOneWidget);
        // Open the actions menu and confirm the toggle copy.
        await tester.tap(find.byWidgetPredicate((w) => w is PopupMenuButton));
        await tester.pumpAndSettle();
        expect(find.text('Set public'), findsOneWidget);
        expect(find.text('Set private'), findsNothing);
      },
    );
  });
}
