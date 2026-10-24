import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/repositories/expense_repository.dart';
import 'package:admin/data/services/expenses_api.dart';
import 'package:admin/data/services/upload_source.dart';
import 'package:admin/domain/expenses/receipt_fill.dart';
import 'package:admin/domain/expenses/receipt_parser.dart';
import 'package:admin/domain/expenses/receipt_scanner.dart';
import 'package:admin/ui/features/expenses/view_models/expense_edit_view_model.dart';
import 'package:admin/ui/features/expenses/widgets/edit/expense_edit_documents_section.dart';
import 'package:admin/ui/features/expenses/widgets/edit/receipt_read_banner.dart';
import 'package:admin/utils/formatting.dart';

import '../../../_localization_helper.dart';

/// What New Expense shows while and after reading a receipt: the strip
/// above the form, and the Read receipt button on a file's row.
void main() {
  late AppDatabase db;
  late ExpenseRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ExpenseRepository(db: db, api: _FakeExpensesApi());
  });
  tearDown(() async => db.close());

  final photo = BytesUploadSource(
    Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0, 0, 0, 0, 0, 0, 0, 0]),
    'IMG_1.jpg',
  );
  final photo2 = BytesUploadSource(
    Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0, 0, 0, 0, 0, 0, 0, 1]),
    'IMG_2.jpg',
  );
  final text = BytesUploadSource(
    Uint8List.fromList('plain text file'.codeUnits),
    'notes.txt',
  );

  ExpenseEditViewModel form(_FakeScanner? scanner, {List<UploadSource>? docs}) {
    final vm = ExpenseEditViewModel(
      repo: repo,
      companyId: 'co',
      initialDocuments: docs ?? [photo],
      receiptScanner: scanner,
      receiptFillContext: () async =>
          ReceiptFillContext(receiptNote: (n) => 'Receipt #$n'),
    );
    addTearDown(vm.dispose);
    return vm;
  }

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      Provider<Services>.value(
        value: _FakeServices(),
        child: MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('reading, then what it filled, then Undo', (tester) async {
    final scanner = _FakeScanner();
    final vm = form(scanner);
    await pump(tester, ReceiptReadBanner(vm: vm));
    expect(find.text('Reading receipt…'), findsNothing);

    unawaited(vm.readReceipt(photo));
    await tester.pump();
    await tester.pump();
    expect(find.text('Reading receipt…'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    scanner.finish(
      ReceiptRead(
        scan: ReceiptScan(
          total: ReceiptField(Decimal.parse('14.23'), ReceiptConfidence.sure),
          date: const ReceiptField(Date(2026, 10, 14), ReceiptConfidence.sure),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Filled from receipt'), findsOneWidget);
    expect(find.textContaining('14.23'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pump();
    expect(find.text('Filled from receipt'), findsNothing);
    expect(vm.draft.amount, Decimal.zero);
  });

  testWidgets('a read that found nothing says so', (tester) async {
    final scanner = _FakeScanner();
    final vm = form(scanner);
    await pump(tester, ReceiptReadBanner(vm: vm));
    unawaited(vm.readReceipt(photo));
    await tester.pump();
    scanner.finish(null);
    await tester.pump();
    await tester.pump();
    expect(find.text("Couldn't read this receipt"), findsOneWidget);
    await tester.tap(find.text('Hide'));
    await tester.pump();
    expect(find.text("Couldn't read this receipt"), findsNothing);
  });

  group('on a phone', () {
    Future<List<String>> announced(WidgetTester tester) async {
      final out = <String>[];
      tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler(
        SystemChannels.accessibility,
        (message) async {
          final data = (message as Map)['data'] as Map;
          if (data['message'] case final String m) out.add(m);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockDecodedMessageHandler(SystemChannels.accessibility, null),
      );
      return out;
    }

    testWidgets('the strip shows with the keyboard down', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final scanner = _FakeScanner();
      final vm = form(scanner);
      await pump(tester, ReceiptReadBanner(vm: vm));
      unawaited(vm.readReceipt(photo));
      await tester.pump();
      await tester.pump();
      expect(find.text('Reading receipt…'), findsOneWidget);
      scanner.finish(null);
      await tester.pump();
    });

    testWidgets('with the keyboard up the strip hides, and a screen reader '
        'still hears the read finish', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.reset);
      final spoken = await announced(tester);
      final scanner = _FakeScanner();
      final vm = form(scanner);
      await pump(tester, ReceiptReadBanner(vm: vm));
      unawaited(vm.readReceipt(photo));
      await tester.pump();
      await tester.pump();
      expect(vm.isReadingReceipt, isTrue, reason: 'reading, just not shown');
      expect(find.text('Reading receipt…'), findsNothing);

      scanner.finish(
        ReceiptRead(
          scan: ReceiptScan(
            total: ReceiptField(Decimal.parse('14.23'), ReceiptConfidence.sure),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(find.text('Filled from receipt'), findsNothing);
      expect(spoken, contains('Reading receipt…'));
      expect(
        spoken.where((m) => m.startsWith('Filled from receipt')),
        hasLength(1),
        reason: 'once, however often the strip rebuilds',
      );
    });
  });

  testWidgets('the values are what the read filled, not what the user typed '
      'since', (tester) async {
    final scanner = _FakeScanner();
    final vm = form(scanner);
    await pump(tester, ReceiptReadBanner(vm: vm));
    unawaited(vm.readReceipt(photo));
    await tester.pump();
    scanner.finish(
      ReceiptRead(
        scan: ReceiptScan(
          total: ReceiptField(Decimal.parse('14.23'), ReceiptConfidence.sure),
          vendorName: 'WHOLEFDS MKT #10234',
        ),
        vendorId: 'v1',
        vendorName: 'Whole Foods Market',
      ),
    );
    await tester.pump();
    await tester.pump();
    vm.setAmount('99');
    await tester.pump();
    expect(find.textContaining('14.23'), findsOneWidget);
    expect(find.textContaining('99'), findsNothing);
    expect(find.text('Whole Foods Market'), findsOneWidget);
    expect(find.textContaining('WHOLEFDS'), findsNothing);
  });

  testWidgets('a vendor-only read names it, and has no Undo', (tester) async {
    final scanner = _FakeScanner();
    final vm = form(scanner);
    await pump(tester, ReceiptReadBanner(vm: vm));
    unawaited(vm.readReceipt(photo));
    await tester.pump();
    scanner.finish(
      const ReceiptRead(scan: ReceiptScan(vendorName: 'Corner Deli')),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('On receipt: Corner Deli'), findsOneWidget);
    expect(find.text('Undo'), findsNothing);
    expect(find.text('Hide'), findsOneWidget);
  });

  testWidgets('a failed second read replaces the first one\'s strip', (
    tester,
  ) async {
    final scanner = _FakeScanner();
    final vm = form(scanner);
    await pump(tester, ReceiptReadBanner(vm: vm));
    unawaited(vm.readReceipt(photo));
    await tester.pump();
    scanner.finish(
      ReceiptRead(
        scan: ReceiptScan(
          total: ReceiptField(Decimal.parse('14.23'), ReceiptConfidence.sure),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    vm.addDocuments([photo2]);
    unawaited(vm.readReceipt(photo2));
    await tester.pump();
    scanner.finish(null);
    await tester.pump();
    await tester.pump();
    expect(find.text("Couldn't read this receipt"), findsOneWidget);
    expect(find.text('Filled from receipt'), findsNothing);
  });

  group('the row button', () {
    testWidgets('a photo offers Read receipt; a text file does not', (
      tester,
    ) async {
      final scanner = _FakeScanner();
      final vm = form(scanner, docs: [photo, text]);
      await tester.runAsync(() => vm.autoReadReceipt(const []));
      await pump(
        tester,
        ListenableBuilder(
          listenable: vm,
          builder: (_, _) => ExpenseEditDocumentsSection(vm: vm),
        ),
      );
      await tester.pump();
      expect(find.text('Read receipt'), findsOneWidget);

      await tester.tap(find.text('Read receipt'));
      await tester.pump();
      expect(scanner.started, 1);
      expect(find.text('Read receipt'), findsNothing, reason: 'reading now');
      scanner.finish(null);
      await tester.pump();
    });

    testWidgets('no scanner — the F-Droid build, Linux, web — no button', (
      tester,
    ) async {
      final vm = form(null);
      await pump(
        tester,
        ListenableBuilder(
          listenable: vm,
          builder: (_, _) => ExpenseEditDocumentsSection(vm: vm),
        ),
      );
      expect(find.text('Read receipt'), findsNothing);
    });
  });
}

class _FakeExpensesApi implements ExpensesApi {
  @override
  Object? noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _FakeServices implements Services {
  @override
  Formatter? formatterIfReady(String companyId) => null;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _FakeScanner implements ReceiptScanner {
  var started = 0;
  Completer<ReceiptRead?>? _pending;

  void finish(ReceiptRead? read) {
    final p = _pending;
    if (p != null && !p.isCompleted) p.complete(read);
  }

  @override
  Duration get timeout => const Duration(seconds: 15);

  @override
  Future<bool> isSupported() async => true;

  @override
  Future<ReceiptRead?> scan(UploadSource source, String companyId) {
    started++;
    _pending = Completer<ReceiptRead?>();
    return _pending!.future;
  }
}
