import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:admin/data/services/shared_intake_files.dart';
import 'package:admin/data/services/upload_source.dart';

/// The copies of files shared into the app (invoiceninja/flutter#173). The
/// failure that matters most is deleting something that isn't ours — a file
/// the user picked from their own storage — or a copy an outbox upload still
/// needs; the next is a receipt left on disk forever.
void main() {
  late Directory support;
  late Directory root;

  setUp(() {
    support = Directory.systemTemp.createTempSync('intake_support');
    root = Directory(p.join(support.path, SharedIntakeFiles.kFolderName));
  });

  tearDown(() {
    if (support.existsSync()) support.deleteSync(recursive: true);
  });

  SharedIntakeFiles store({
    DateTime Function()? now,
    Set<String> referenced = const {},
  }) => SharedIntakeFiles(
    supportDirectory: () async => support,
    referencedPaths: () async => referenced,
    now: now,
  );

  /// A share: `shared_intake/<folder>/<name>`.
  File share(String folder, String name) =>
      File(p.join(root.path, folder, name))
        ..createSync(recursive: true)
        ..writeAsStringSync('x');

  test('delete removes a copy and the share folder it leaves empty', () async {
    final a = share('s1', 'a.pdf');
    final b = share('s1', 'b.pdf');

    await store().delete([a.path]);
    expect(a.existsSync(), isFalse);
    expect(Directory(p.join(root.path, 's1')).existsSync(), isTrue);

    await store().delete([b.path]);
    expect(Directory(p.join(root.path, 's1')).existsSync(), isFalse);
    expect(root.existsSync(), isTrue, reason: 'the root itself stays');
  });

  test('delete never touches a path outside the root — a file the user '
      'picked is theirs', () async {
    final mine = File(p.join(support.path, 'picked.pdf'))
      ..writeAsStringSync('x');
    final sneaky = p.join(root.path, '..', 'picked.pdf');

    await store().delete([mine.path, sneaky]);

    expect(mine.existsSync(), isTrue);
  });

  test(
    'sweep keeps referenced and recent shares, deletes old orphans',
    () async {
      final referenced = share('kept', 'a.pdf');
      share('orphan', 'b.pdf');

      // Recent: nothing goes, referenced or not.
      await store().sweep({referenced.path});
      expect(Directory(p.join(root.path, 'orphan')).existsSync(), isTrue);

      // Past the sweep age: only the unreferenced share goes.
      final later = DateTime.now().add(
        SharedIntakeFiles.kSweepAge + const Duration(hours: 1),
      );
      await store(now: () => later).sweep({referenced.path});
      expect(referenced.existsSync(), isTrue);
      expect(Directory(p.join(root.path, 'orphan')).existsSync(), isFalse);
    },
  );

  test('purgeAll removes every share except the ones still held', () async {
    final held = share('held', 'a.pdf');
    share('gone', 'b.pdf');

    await store().purgeAll(except: {held.path});
    expect(held.existsSync(), isTrue);
    expect(Directory(p.join(root.path, 'gone')).existsSync(), isFalse);

    await store().purgeAll();
    expect(root.existsSync(), isFalse);
  });

  test('every method is a no-op when there is nothing on disk', () async {
    final s = store();
    await s.sweep(const {});
    await s.purgeAll();
    await s.delete([p.join(root.path, 'x', 'y.pdf')]);
    expect(root.existsSync(), isFalse);
  });

  test('localPathOf: a file source has a path, bytes do not', () {
    expect(
      SharedIntakeFiles.localPathOf(fileUploadSource('/x/a.pdf')),
      '/x/a.pdf',
    );
    expect(
      SharedIntakeFiles.localPathOf(BytesUploadSource(Uint8List(1), 'a.pdf')),
      isNull,
    );
  });

  test('owns only copies inside the folder', () async {
    final copy = share('s1', 'a.pdf');
    expect(await store().owns(copy.path), isTrue);
    expect(await store().owns(p.join(support.path, 'db.sqlite')), isFalse);
    expect(await store().owns(p.join(root.path, '..', 'db.sqlite')), isFalse);
  });

  test('delete never takes a copy an outbox row still names — even when the '
      'row spells its absolute path differently', () async {
    final copy = share('s1', 'a.pdf');
    // An iOS container that moved, or `/private/var` vs `/var`: only the
    // `<uuid>/<name>` part is ours to match on.
    final moved = '/var/mobile/old-container/shared_intake/s1/a.pdf';

    await store(referenced: {moved}).delete([copy.path]);
    expect(copy.existsSync(), isTrue);

    await store().delete([copy.path]);
    expect(copy.existsSync(), isFalse);
  });

  test(
    'deleteUploaded takes the copy whose upload just went, row or not',
    () async {
      final copy = share('s1', 'a.pdf');
      await store(referenced: {copy.path}).deleteUploaded(copy.path);
      expect(copy.existsSync(), isFalse);
    },
  );

  test(
    'the sweep keeps a share its row names by another absolute prefix',
    () async {
      share('kept', 'a.pdf');
      final later = DateTime.now().add(
        SharedIntakeFiles.kSweepAge + const Duration(hours: 1),
      );
      await store(
        now: () => later,
      ).sweep({'/elsewhere/shared_intake/kept/a.pdf'});
      expect(Directory(p.join(root.path, 'kept')).existsSync(), isTrue);
    },
  );

  group('resolve', () {
    test('re-finds a copy whose queued path moved — an iOS update moving the '
        'data container', () async {
      final copy = share('s1', 'receipt.jpg');
      // The row was queued under the old container's absolute path.
      final queued = fileUploadSource(
        '/var/mobile/Containers/Data/Application/OLD-UUID/Library/'
        'Application Support/shared_intake/s1/receipt.jpg',
      );

      final resolved = await store().resolve(queued);
      expect(SharedIntakeFiles.localPathOf(resolved), copy.path);
      expect(await resolved.exists(), isTrue);
    });

    test('leaves a source alone when it still exists, when it is not one of '
        'ours, or when the copy is gone too', () async {
      final copy = share('s1', 'a.pdf');
      final here = fileUploadSource(copy.path);
      expect(identical(await store().resolve(here), here), isTrue);

      final picked = fileUploadSource('/gone/Downloads/a.pdf');
      expect(identical(await store().resolve(picked), picked), isTrue);

      final missing = fileUploadSource('/old/shared_intake/s9/none.pdf');
      expect(identical(await store().resolve(missing), missing), isTrue);

      final bytes = BytesUploadSource(Uint8List(1), 'b.pdf');
      expect(identical(await store().resolve(bytes), bytes), isTrue);
    });
  });

  test('intakeKey is the part inside the folder', () {
    expect(
      SharedIntakeFiles.intakeKey('/a/b/shared_intake/u1/r.pdf'),
      'u1/r.pdf',
    );
    expect(SharedIntakeFiles.intakeKey('/a/b/other/r.pdf'), isNull);
    expect(SharedIntakeFiles.intakeKey('/a/shared_intake'), isNull);
  });
}
