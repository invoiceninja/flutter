import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/domain/document.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/services/shared_intake_files.dart';
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
  Services? services,
}) async {
  final app = MaterialApp(
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
  );
  await tester.pumpWidget(
    services == null
        ? app
        : Provider<Services>.value(value: services, child: app),
  );
  await tester.pump();
}

void main() {
  group('EntityDocumentsTab', () {
    // A photo taken on this tab sits in the app's own folder until its upload
    // is sent; one the tab rejects never reaches the outbox, so it goes back
    // at once instead of waiting a day for the launch sweep.
    testWidgets('a rejected photo from the app\'s folder is handed back', (
      tester,
    ) async {
      final support = Directory.systemTemp.createTempSync('tab_release');
      addTearDown(() => support.deleteSync(recursive: true));
      final intake = SharedIntakeFiles(
        supportDirectory: () async => support,
        referencedPaths: () async => const {},
      );
      final rejected = File(
        p.join(support.path, SharedIntakeFiles.kFolderName, 'u1', 'scan.tiff'),
      )..createSync(recursive: true);
      final uploaded = <UploadSource>[];
      await _pump(
        tester,
        entityId: 'real_123',
        documents: const [],
        services: _IntakeServices(intake),
        onUpload: (s) async => uploaded.addAll(s),
      );

      final zone = tester.widget<FileDropZone>(find.byType(FileDropZone));
      unawaited(zone.onFiles([fileUploadSource(rejected.path)]));
      for (var i = 0; i < 100 && rejected.existsSync(); i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }

      expect(rejected.existsSync(), isFalse);
      expect(uploaded, isEmpty);
    });

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
      // A desktop: the drop-or-click box.
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );

    // The old app's camera button (DocumentGrid), on every Documents tab.
    testWidgets(
      'on a phone the upload affordance is Camera / Photos / Files',
      (tester) async {
        await _pump(tester, entityId: 'real_123', documents: const []);
        expect(find.text('Camera'), findsOneWidget);
        expect(find.text('Photos'), findsOneWidget);
        expect(find.text('Files'), findsOneWidget);
        expect(find.byIcon(Icons.upload_file_outlined), findsNothing);
      },
      variant: const TargetPlatformVariant({
        TargetPlatform.iOS,
        TargetPlatform.android,
      }),
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

    testWidgets('the row menu offers View and Download ahead of the mutating '
        'actions', (tester) async {
      await _pump(tester, entityId: 'real_123', documents: const [_docA]);
      await tester.tap(find.byWidgetPredicate((w) => w is PopupMenuButton));
      await tester.pumpAndSettle();
      final labels = tester
          .widgetList<ListTile>(find.byType(ListTile))
          .map((t) => (t.title! as Text).data)
          .toList();
      expect(labels, ['View', 'Download', 'Set private', 'Delete']);
    });

    testWidgets('readOnly mode hides upload and the mutating row actions, '
        'and keeps View and Download', (tester) async {
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
      expect(find.text('Download'), findsOneWidget);
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

/// Just enough `Services` for `intakeOf`, and for the tab's plan check (no
/// session: not gated).
class _IntakeServices implements Services {
  _IntakeServices(this.sharedIntakeFiles);

  @override
  final SharedIntakeFiles sharedIntakeFiles;

  @override
  final AuthRepository auth = _NoSession();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _NoSession implements AuthRepository {
  @override
  final ValueListenable<AuthSession?> session = ValueNotifier(null);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}
