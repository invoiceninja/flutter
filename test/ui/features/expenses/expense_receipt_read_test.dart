import 'dart:async';
import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/domain/expense.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/repositories/expense_repository.dart';
import 'package:admin/data/services/expenses_api.dart';
import 'package:admin/data/services/upload_source.dart';
import 'package:admin/domain/expenses/receipt_fill.dart';
import 'package:admin/domain/expenses/receipt_parser.dart';
import 'package:admin/domain/expenses/receipt_scanner.dart';
import 'package:admin/ui/features/expenses/view_models/expense_edit_view_model.dart';
import 'package:admin/ui/features/expenses/views/expense_edit_screen.dart';

/// New Expense reading a receipt (`docs/receipt-ocr.md`): when it reads on
/// its own, that a late result never lands on an edit, a cancel, a Discard
/// or a disposed form, and that Undo puts back exactly what it changed.
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
  final notes = BytesUploadSource(
    Uint8List.fromList('just some notes'.codeUnits),
    'notes.txt',
  );

  final read = ReceiptRead(
    scan: ReceiptScan(
      total: ReceiptField(Decimal.parse('14.23'), ReceiptConfidence.sure),
      date: const ReceiptField(Date(2026, 10, 14), ReceiptConfidence.check),
      vendorName: 'Blue Bottle Coffee',
      receiptNumber: '4471',
    ),
    vendorId: 'v1',
  );

  final photo2 = BytesUploadSource(
    Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0, 0, 0, 0, 0, 0, 0, 1]),
    'IMG_2.jpg',
  );

  ExpenseEditViewModel vm(
    _FakeScanner scanner, {
    List<UploadSource> documents = const [],
    bool clone = false,
    Expense? staged,
    Future<ReceiptFillContext> Function()? fillContext,
  }) {
    final v = ExpenseEditViewModel(
      repo: repo,
      companyId: 'co',
      cloneFrom:
          staged ??
          (clone ? emptyExpense().copyWith(amount: Decimal.parse('3')) : null),
      initialDocuments: documents,
      receiptScanner: scanner,
      receiptFillContext:
          fillContext ??
          () async => ReceiptFillContext(receiptNote: (n) => 'Receipt #$n'),
    );
    addTearDown(v.dispose);
    return v;
  }

  test('a pristine form reads the first receipt it is given', () async {
    final scanner = _FakeScanner();
    final form = vm(scanner, documents: [notes, photo]);

    final reading = form.autoReadReceipt(form.documents);
    await pumpEventQueue();
    expect(form.isReadingReceipt, isTrue);
    expect(form.readingReceipt, photo, reason: 'the text file is not one');

    scanner.finish(read);
    await reading;

    expect(form.draft.amount, Decimal.parse('14.23'));
    expect(form.draft.date, const Date(2026, 10, 14));
    expect(form.draft.vendorId, 'v1');
    expect(form.draft.privateNotes, 'Receipt #4471');
    expect(form.draft.number, '');
    expect(form.receiptMarker(ReceiptFillField.amount), ReceiptConfidence.sure);
    expect(form.receiptMarker(ReceiptFillField.date), ReceiptConfidence.check);
    expect(form.lastReceiptRead, isNotNull);
    expect(form.receiptWasRead(photo), isTrue);
    expect(form.isDirty, isTrue);
  });

  test('a clone, or a form the user has typed into, waits for the '
      'button', () async {
    final scanner = _FakeScanner();
    final cloned = vm(scanner, documents: [photo], clone: true);
    await cloned.autoReadReceipt(cloned.documents);
    expect(scanner.started, 0);

    final typed = vm(scanner);
    typed.setPublicNotes('lunch');
    typed.addDocuments([photo]);
    await pumpEventQueue();
    expect(scanner.started, 0);
    expect(typed.canReadReceipt, isTrue);
  });

  test('a value typed while the engine reads is kept', () async {
    final scanner = _FakeScanner();
    final form = vm(scanner, documents: [photo]);
    final reading = form.readReceipt(photo);
    await pumpEventQueue();

    form.setAmount('5');
    scanner.finish(read);
    await reading;

    expect(form.draft.amount, Decimal.parse('5'));
    expect(form.draft.vendorId, 'v1', reason: 'the blank fields still fill');
  });

  test('a field the user is in is not filled under the caret', () async {
    final scanner = _FakeScanner();
    final form = vm(scanner, documents: [photo]);
    form.noteReceiptFieldFocus(ReceiptFillField.date, true);
    final reading = form.readReceipt(photo);
    await pumpEventQueue();
    scanner.finish(read);
    await reading;

    expect(form.draft.date, Date.today());
    expect(form.draft.amount, Decimal.parse('14.23'));
  });

  test('a cancelled read, a Discard or a closed form drops the late '
      'result', () async {
    final scanner = _FakeScanner();

    final cancelled = vm(scanner, documents: [photo]);
    final a = cancelled.readReceipt(photo);
    await pumpEventQueue();
    cancelled.cancelReceiptRead();
    scanner.finish(read);
    await a;
    expect(cancelled.draft.amount, Decimal.zero);
    expect(cancelled.isReadingReceipt, isFalse);

    final discarded = vm(scanner, documents: [photo]);
    final b = discarded.readReceipt(photo);
    await pumpEventQueue();
    discarded.resetToEmpty();
    scanner.finish(read);
    await b;
    expect(discarded.draft.amount, Decimal.zero);
    expect(discarded.isDirty, isFalse);

    final closed = ExpenseEditViewModel(
      repo: repo,
      companyId: 'co',
      initialDocuments: [photo],
      receiptScanner: scanner,
      receiptFillContext: () async => ReceiptFillContext(receiptNote: (n) => n),
    );
    await pumpEventQueue();
    final c = closed.readReceipt(photo);
    await pumpEventQueue();
    closed.dispose();
    scanner.finish(read);
    await c; // no throw, no notify after dispose
  });

  test('Undo puts back what the read changed and keeps what the user '
      'changed since', () async {
    final scanner = _FakeScanner();
    final form = vm(scanner, documents: [photo]);
    final reading = form.readReceipt(photo);
    await pumpEventQueue();
    scanner.finish(read);
    await reading;

    form.setDate(const Date(2026, 10, 1)); // the user corrects the date

    form.undoReceiptRead();

    expect(form.draft.amount, Decimal.zero);
    expect(form.draft.vendorId, '');
    expect(form.draft.privateNotes, '');
    expect(form.draft.date, const Date(2026, 10, 1));
    expect(form.receiptMarker(ReceiptFillField.amount), isNull);
    expect(form.receiptWasRead(photo), isFalse, reason: 'Read comes back');
    expect(form.showsReceiptBanner, isFalse);
  });

  test("a marker goes once the user changes the field — not while they're "
      'still in it', () async {
    final scanner = _FakeScanner();
    final form = vm(scanner, documents: [photo]);
    final reading = form.readReceipt(photo);
    await pumpEventQueue();
    scanner.finish(read);
    await reading;

    form.noteReceiptFieldFocus(ReceiptFillField.amount, true);
    form.setAmount('15');
    expect(form.receiptMarker(ReceiptFillField.amount), isNotNull);
    form.noteReceiptFieldFocus(ReceiptFillField.amount, false);
    expect(form.receiptMarker(ReceiptFillField.amount), isNull);
  });

  test("an unreadable receipt says so, and a vendor the company doesn't "
      'have is offered, never made', () async {
    final scanner = _FakeScanner();
    final form = vm(scanner, documents: [photo]);
    var reading = form.readReceipt(photo);
    await pumpEventQueue();
    scanner.finish(null);
    await reading;
    expect(form.receiptReadFailed, isTrue);
    form.dismissReceiptBanner();

    final other = vm(scanner, documents: [photo]);
    reading = other.readReceipt(photo);
    await pumpEventQueue();
    scanner.finish(
      const ReceiptRead(scan: ReceiptScan(vendorName: 'Corner Deli')),
    );
    await reading;
    expect(other.draft.vendorId, '');
    expect(other.unmatchedReceiptVendor, 'Corner Deli');
    other.setVendorId('picked');
    expect(other.unmatchedReceiptVendor, isNull);
  });

  group('Scan Receipt and a shared file', () {
    // Both stage an empty draft beside the files (`Services.stageExpense`).
    test('their blank staged draft opens a blank form, which reads on its '
        'own and fills the date', () async {
      expect(stagedExpenseDraft(emptyExpense()), isNull);
      final scanner = _FakeScanner();
      final form = vm(
        scanner,
        documents: [photo],
        staged: stagedExpenseDraft(emptyExpense()),
      );
      final reading = form.autoReadReceipt(form.documents);
      await pumpEventQueue();
      expect(scanner.started, 1);
      scanner.finish(read);
      await reading;
      expect(form.draft.date, const Date(2026, 10, 14));
      expect(form.isDirty, isTrue);
    });

    test('a staged draft that says something is kept', () {
      final fromVendor = emptyExpense().copyWith(vendorId: 'v9');
      expect(stagedExpenseDraft(fromVendor), fromVendor);
      final clone = emptyExpense();
      expect(stagedExpenseDraft(clone, isClone: true), clone);
    });
  });

  test('Undo after a second read takes back only that read', () async {
    final scanner = _FakeScanner();
    final form = vm(scanner, documents: [photo, photo2]);
    var reading = form.readReceipt(photo);
    await pumpEventQueue();
    scanner.finish(
      ReceiptRead(
        scan: ReceiptScan(
          total: ReceiptField(Decimal.parse('14.23'), ReceiptConfidence.sure),
        ),
      ),
    );
    await reading;
    reading = form.readReceipt(photo2);
    await pumpEventQueue();
    scanner.finish(
      const ReceiptRead(
        scan: ReceiptScan(vendorName: 'Blue Bottle Coffee'),
        vendorId: 'v1',
      ),
    );
    await reading;
    expect(form.draft.vendorId, 'v1');

    form.undoReceiptRead();
    expect(form.draft.vendorId, '');
    expect(form.draft.amount, Decimal.parse('14.23'));
    expect(form.receiptMarker(ReceiptFillField.amount), ReceiptConfidence.sure);
    expect(form.receiptWasRead(photo), isTrue);
    expect(form.receiptWasRead(photo2), isFalse);
  });

  test('Undo clears each tax slot still as the read left it, and keeps the '
      "mode the user is working in once they've edited one", () async {
    final scanner = _FakeScanner();
    final form = vm(
      scanner,
      documents: [photo],
      fillContext: () async =>
          ReceiptFillContext(enabledTaxTiers: 3, receiptNote: (n) => n),
    );
    final reading = form.readReceipt(photo);
    await pumpEventQueue();
    scanner.finish(
      ReceiptRead(
        scan: ReceiptScan(
          total: ReceiptField(Decimal.parse('118'), ReceiptConfidence.sure),
          taxes: [
            ReceiptTax(name: 'CGST', amount: Decimal.parse('9')),
            ReceiptTax(name: 'SGST', amount: Decimal.parse('9')),
          ],
        ),
      ),
    );
    await reading;
    expect(form.draft.calculateTaxByAmount, isTrue);
    expect(form.draft.usesInclusiveTaxes, isTrue);
    expect(form.draft.taxAmount2, Decimal.parse('9'));

    form.setTaxAmount2('8');
    form.undoReceiptRead();

    expect(form.draft.taxName1, '');
    expect(form.draft.taxAmount1, Decimal.zero);
    expect(form.draft.taxAmount2, Decimal.parse('8'), reason: "the user's");
    expect(form.draft.calculateTaxByAmount, isTrue);
    expect(form.draft.usesInclusiveTaxes, isTrue);
    expect(form.draft.amount, Decimal.zero);
  });

  test('a read that lands after a save started, or after its file was '
      'removed, is dropped', () async {
    final scanner = _FakeScanner();
    final saving = vm(scanner, documents: [photo]);
    var reading = saving.readReceipt(photo);
    await pumpEventQueue();
    await saving.save(); // invalid or not, a save began
    scanner.finish(read);
    await reading;
    expect(saving.draft.vendorId, '');
    expect(saving.isReadingReceipt, isFalse);

    final removed = vm(scanner, documents: [photo]);
    reading = removed.readReceipt(photo);
    await pumpEventQueue();
    removed.removeDocument(photo);
    scanner.finish(read);
    await reading;
    expect(removed.draft.amount, Decimal.zero);
  });

  test('two batches arriving together start one read', () async {
    final scanner = _FakeScanner();
    final form = vm(scanner, documents: [photo, photo2]);
    final a = form.autoReadReceipt([photo]);
    final b = form.autoReadReceipt([photo2]);
    await pumpEventQueue();
    expect(scanner.started, 1);
    scanner.finish(read);
    await Future.wait([a, b]);
  });

  test('company settings that fail to load end the read as failed, not '
      'stuck reading', () async {
    final scanner = _FakeScanner();
    final form = vm(
      scanner,
      documents: [photo],
      fillContext: () async => throw StateError('no company'),
    );
    final reading = form.readReceipt(photo);
    await pumpEventQueue();
    scanner.finish(read);
    await reading;
    expect(form.isReadingReceipt, isFalse);
    expect(form.receiptReadFailed, isTrue);
    expect(form.receiptWasRead(photo), isFalse, reason: 'Read stays');
  });

  test('an engine that turns out to have no language hides Read', () async {
    final scanner = _FakeScanner();
    final form = vm(scanner, documents: [photo]);
    await form.autoReadReceipt(const []);
    expect(form.canReadReceipt, isTrue);
    final reading = form.readReceipt(photo);
    await pumpEventQueue();
    scanner.supported = false;
    scanner.finish(null);
    await reading;
    expect(form.canReadReceipt, isFalse);
  });

  test('a new read replaces the strip, and a failure wins over the last '
      'fill', () async {
    final scanner = _FakeScanner();
    final form = vm(scanner, documents: [photo, photo2]);
    var reading = form.readReceipt(photo);
    await pumpEventQueue();
    scanner.finish(read);
    await reading;
    expect(form.receiptBannerState, ReceiptBannerState.filled);

    reading = form.readReceipt(photo2);
    await pumpEventQueue();
    expect(form.receiptBannerState, ReceiptBannerState.reading);
    scanner.finish(null);
    await reading;
    expect(form.receiptBannerState, ReceiptBannerState.failed);
    expect(
      form.receiptMarker(ReceiptFillField.amount),
      ReceiptConfidence.sure,
      reason: "the first read's fields keep their markers",
    );
  });

  test('a vendor-only read says so, with nothing to undo', () async {
    final scanner = _FakeScanner();
    final form = vm(scanner, documents: [photo]);
    final reading = form.readReceipt(photo);
    await pumpEventQueue();
    scanner.finish(
      const ReceiptRead(scan: ReceiptScan(vendorName: 'Corner Deli')),
    );
    await reading;
    expect(form.receiptBannerState, ReceiptBannerState.vendorOnly);
    expect(form.receiptFilledFields, isEmpty);
  });

  test('an edit form never reads', () async {
    final scanner = _FakeScanner();
    final form = ExpenseEditViewModel(
      repo: repo,
      companyId: 'co',
      existing: emptyExpense().copyWith(id: 'e1'),
      receiptScanner: scanner,
    );
    addTearDown(form.dispose);
    await pumpEventQueue();
    expect(form.canReadReceipt, isFalse);
  });
}

class _FakeExpensesApi implements ExpensesApi {
  @override
  Object? noSuchMethod(Invocation i) => throw UnimplementedError();
}

/// A scanner whose reads finish when the test says.
class _FakeScanner implements ReceiptScanner {
  var started = 0;
  var supported = true;
  Completer<ReceiptRead?>? _pending;

  void finish(ReceiptRead? read) => _pending!.complete(read);

  @override
  Duration get timeout => const Duration(seconds: 15);

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<ReceiptRead?> scan(UploadSource source, String companyId) {
    started++;
    _pending = Completer<ReceiptRead?>();
    return _pending!.future;
  }
}
