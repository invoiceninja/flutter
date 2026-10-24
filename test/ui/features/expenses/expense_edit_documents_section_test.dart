import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/expense_repository.dart';
import 'package:admin/data/repositories/sync_repository.dart';
import 'package:admin/data/services/connectivity_watcher.dart';
import 'package:admin/data/services/expenses_api.dart';
import 'package:admin/data/services/upload_source.dart';
import 'package:admin/domain/entity_registry.dart';
import 'package:admin/ui/core/widgets/file_drop_zone.dart';
import 'package:admin/ui/features/expenses/view_models/expense_edit_view_model.dart';
import 'package:admin/ui/features/expenses/widgets/edit/expense_edit_documents_section.dart';

import '../../../_localization_helper.dart';

/// New Expense's Documents card (invoiceninja/flutter#173): where a receipt
/// shared into the app shows up, and where files are attached before the
/// expense exists.

class _FakeExpensesApi implements ExpensesApi {
  @override
  Object? noSuchMethod(Invocation i) => throw UnimplementedError();
}

/// Holds a save on screen until [release] — a save in flight.
class _HeldSync extends SyncRepository {
  _HeldSync(AppDatabase db) : super(db: db, registry: EntityRegistry(const {}));

  final _gate = Completer<void>();
  void release() => _gate.complete();

  @override
  Future<SyncRowResult> awaitRow({
    required int rowId,
    required String companyId,
    Duration timeout = const Duration(seconds: 30),
    Duration pollInterval = const Duration(milliseconds: 200),
    bool callerWillDisplayFailure = true,
  }) async {
    await _gate.future;
    return const SyncRowResult(outcome: SyncRowOutcome.success);
  }
}

const _owner = AuthCompany(
  id: 'co',
  name: 'Co',
  displayName: 'Co',
  permissions: '',
  isAdmin: true,
  isOwner: true,
);

AuthSession _session({required bool hosted}) => AuthSession(
  baseUrl: 'https://example.test',
  isHosted: hosted,
  accountId: 'acc',
  companies: const [_owner],
  currentCompanyId: 'co',
);

void main() {
  late AppDatabase db;
  late ExpenseRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ExpenseRepository(db: db, api: _FakeExpensesApi());
  });
  tearDown(() async => db.close());

  Future<void> pump(WidgetTester tester, ExpenseEditViewModel vm) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ListenableBuilder(
              listenable: vm,
              builder: (_, _) => ExpenseEditDocumentsSection(vm: vm),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('lists the attached files, each removable', (tester) async {
    final vm = ExpenseEditViewModel(
      repo: repo,
      companyId: 'co',
      initialDocuments: [
        BytesUploadSource(Uint8List(2048), 'receipt.pdf'),
        BytesUploadSource(Uint8List(10), 'photo.jpg'),
      ],
    );
    addTearDown(vm.dispose);
    await pump(tester, vm);

    expect(find.byType(FileDropZone), findsOneWidget);
    expect(find.text('receipt.pdf'), findsOneWidget);
    expect(find.text('photo.jpg'), findsOneWidget);
    expect(find.text('These files upload when you save.'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove').first);
    await tester.pump();

    expect(vm.documents.map((s) => s.fileName), ['photo.jpg']);
    expect(find.text('receipt.pdf'), findsNothing);
  });

  // Someone who just took a photo of a receipt sees it was the right shot.
  testWidgets('a photo shows a thumbnail, any other file its type icon', (
    tester,
  ) async {
    final vm = ExpenseEditViewModel(
      repo: repo,
      companyId: 'co',
      initialDocuments: [
        BytesUploadSource(Uint8List.fromList(_onePixelPng), 'IMG_1.png'),
        BytesUploadSource(Uint8List(10), 'receipt.pdf'),
      ],
    );
    addTearDown(vm.dispose);
    await pump(tester, vm);

    final thumb = find.byWidgetPredicate(
      (w) =>
          w is Image &&
          w.image is ResizeImage &&
          (w.image as ResizeImage).imageProvider is MemoryImage,
    );
    expect(thumb, findsOneWidget);
    expect(tester.getSize(thumb), const Size(32, 32));
    expect(find.byIcon(Icons.description_outlined), findsOneWidget);
  });

  // A photo taken on the phone is a file in the app's own folder by the time
  // it reaches the card — the thumbnail must read it from there.
  testWidgets('a photo on disk is drawn from its file', (tester) async {
    final vm = ExpenseEditViewModel(
      repo: repo,
      companyId: 'co',
      initialDocuments: [
        fileUploadSource('/support/shared_intake/u1/IMG_20261024_120000.jpg'),
      ],
    );
    addTearDown(vm.dispose);
    await pump(tester, vm);

    final image = tester.widget<Image>(find.byType(Image));
    final provider = (image.image as ResizeImage).imageProvider;
    expect(provider, isA<FileImage>());
    expect(
      (provider as FileImage).file.path,
      '/support/shared_intake/u1/IMG_20261024_120000.jpg',
    );
  });

  testWidgets('on a phone the card offers Camera / Photos / Files', (
    tester,
  ) async {
    final vm = ExpenseEditViewModel(repo: repo, companyId: 'co');
    addTearDown(vm.dispose);
    await pump(tester, vm);
    for (final label in ['Camera', 'Photos', 'Files']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(
      tester.widget<FileDropZone>(find.byType(FileDropZone)).allowPhotos,
      isTrue,
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('no files: just the drop zone, no hint', (tester) async {
    final vm = ExpenseEditViewModel(repo: repo, companyId: 'co');
    addTearDown(vm.dispose);
    await pump(tester, vm);
    expect(find.byType(FileDropZone), findsOneWidget);
    expect(find.text('These files upload when you save.'), findsNothing);
  });

  testWidgets('locked while a save is in flight — a file added or removed '
      'then would not match what that attempt queued', (tester) async {
    final sync = _HeldSync(db);
    final vm = ExpenseEditViewModel(
      repo: repo,
      companyId: 'co',
      initialDocuments: [BytesUploadSource(Uint8List(10), 'receipt.pdf')],
      sync: sync,
      connectivity: ConnectivityWatcher.fixed(online: true),
    )..setVendorId('v1');
    addTearDown(vm.dispose);
    await pump(tester, vm);

    final saving = vm.save(); // parked on the held sync
    await tester.pump();

    expect(vm.isSaving, isTrue);
    expect(
      tester.widget<FileDropZone>(find.byType(FileDropZone)).enabled,
      isFalse,
    );
    final remove = tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip('Remove'),
        matching: find.byType(IconButton),
      ),
    );
    expect(remove.onPressed, isNull);

    sync.release();
    await tester.pump();
    expect(await saving, isNotNull);
  });

  group('showsExpenseDocumentsCard', () {
    test('a new expense where attachments are allowed', () {
      expect(
        showsExpenseDocumentsCard(
          isCreate: true,
          session: _session(hosted: false),
        ),
        isTrue,
      );
      expect(showsExpenseDocumentsCard(isCreate: true, session: null), isTrue);
    });

    test('never on an existing expense — its documents are on the detail '
        'screen', () {
      expect(
        showsExpenseDocumentsCard(
          isCreate: false,
          session: _session(hosted: false),
        ),
        isFalse,
      );
    });

    test('a hosted plan without attachments gets no card — no upsell on '
        'every new expense', () {
      expect(
        showsExpenseDocumentsCard(
          isCreate: true,
          session: _session(hosted: true),
        ),
        isFalse,
      );
    });
  });
}

/// A 1×1 PNG.
const _onePixelPng = <int>[
  137,
  80,
  78,
  71,
  13,
  10,
  26,
  10,
  0,
  0,
  0,
  13,
  73,
  72,
  68,
  82,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  1,
  8,
  6,
  0,
  0,
  0,
  31,
  21,
  196,
  137,
  0,
  0,
  0,
  13,
  73,
  68,
  65,
  84,
  120,
  218,
  99,
  100,
  248,
  207,
  80,
  15,
  0,
  3,
  134,
  1,
  128,
  90,
  52,
  125,
  107,
  0,
  0,
  0,
  0,
  73,
  69,
  78,
  68,
  174,
  66,
  96,
  130,
];
