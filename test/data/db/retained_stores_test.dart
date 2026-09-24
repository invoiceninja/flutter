@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:admin/data/db/database_opener_io.dart'
    show deleteRetainedStore, listRetainedStoresIn;

/// The old copies a reset keeps are listed in Device Settings → Data so the
/// user can see and delete them — the only way an `.unrecovered` copy, which
/// nothing prunes, ever leaves the device.
void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('retained_stores'));
  tearDown(() => dir.deleteSync(recursive: true));

  File write(String name, int bytes) =>
      File(p.join(dir.path, name))..writeAsBytesSync(List.filled(bytes, 0));

  test('lists the kept copies newest first, sized with their sidecars, and '
      'nothing else', () async {
    write('invoiceninja.sqlite', 100); // the live store
    write('invoiceninja.sqlite-journal', 10);
    write('invoiceninja.sqlite.salvage', 5);
    write('invoiceninja.sqlite.broken.1000', 200);
    write('invoiceninja.sqlite.broken.1000-journal', 20);
    write('invoiceninja.sqlite.unrecovered.3000', 300);
    write('claude-diagnostics.log', 1);

    final copies = await listRetainedStoresIn(dir);

    expect(
      [for (final c in copies) p.basename(c.path)],
      [
        'invoiceninja.sqlite.unrecovered.3000',
        'invoiceninja.sqlite.broken.1000',
      ],
    );
    expect(copies.first.unrecovered, isTrue);
    expect(copies.first.keptAt, DateTime.fromMillisecondsSinceEpoch(3000));
    expect(copies.last.unrecovered, isFalse);
    expect(copies.last.bytes, 220, reason: 'the journal goes with it');
  });

  test('delete removes a copy with its sidecars', () async {
    final copy = write('invoiceninja.sqlite.unrecovered.3000', 300);
    final journal = write('invoiceninja.sqlite.unrecovered.3000-journal', 30);

    await deleteRetainedStore(copy.path);

    expect(copy.existsSync(), isFalse);
    expect(journal.existsSync(), isFalse);
    expect(await listRetainedStoresIn(dir), isEmpty);
  });

  test('delete refuses anything that is not a kept copy', () async {
    final live = write('invoiceninja.sqlite', 100);
    await expectLater(deleteRetainedStore(live.path), throwsArgumentError);
    expect(live.existsSync(), isTrue);
  });

  test('a missing directory lists nothing', () async {
    expect(
      await listRetainedStoresIn(Directory(p.join(dir.path, 'absent'))),
      isEmpty,
    );
  });
}
