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
    bool canAdopt = true,
  }) => SharedIntakeFiles(
    supportDirectory: () async => support,
    referencedPaths: () async => referenced,
    now: now,
    canAdopt: () => canAdopt,
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

  group('adopt', () {
    // A photo the camera or the photo library handed over sits in the
    // plugin's temp folder, which the OS may empty before an offline upload
    // is sent.
    test('moves the picker\'s copy into its own folder, named as asked, and '
        'the result is one of ours', () async {
      final temp = Directory.systemTemp.createTempSync('picker_tmp');
      addTearDown(() => temp.deleteSync(recursive: true));
      final shot = File(p.join(temp.path, 'image_picker_123.jpg'))
        ..writeAsBytesSync([1, 2, 3]);

      final kept = await store().adopt(
        shot.path,
        name: 'IMG_20261024_120000.jpg',
      );

      expect(kept, isNotNull);
      expect(p.basename(kept!), 'IMG_20261024_120000.jpg');
      expect(p.isWithin(root.path, kept), isTrue);
      expect(File(kept).readAsBytesSync(), [1, 2, 3]);
      expect(shot.existsSync(), isFalse, reason: 'moved, not copied');
      expect(await store().owns(kept), isTrue);
      // The upload handler's cleanup then takes it, folder and all.
      await store().deleteUploaded(kept);
      expect(Directory(p.dirname(kept)).existsSync(), isFalse);
    });

    test('two photos with the same name do not collide', () async {
      final temp = Directory.systemTemp.createTempSync('picker_tmp');
      addTearDown(() => temp.deleteSync(recursive: true));
      final a = File(p.join(temp.path, 'a.jpg'))..writeAsStringSync('a');
      final b = File(p.join(temp.path, 'b.jpg'))..writeAsStringSync('b');

      final keptA = await store().adopt(a.path, name: 'receipt.jpg');
      final keptB = await store().adopt(b.path, name: 'receipt.jpg');

      expect(keptA, isNot(keptB));
      expect(File(keptA!).readAsStringSync(), 'a');
      expect(File(keptB!).readAsStringSync(), 'b');
    });

    test('a name cannot climb out of the folder', () async {
      final temp = Directory.systemTemp.createTempSync('picker_tmp');
      addTearDown(() => temp.deleteSync(recursive: true));
      final shot = File(p.join(temp.path, 'x.jpg'))..writeAsStringSync('x');

      final kept = await store().adopt(shot.path, name: '../../escape.jpg');

      expect(p.isWithin(root.path, kept!), isTrue);
    });

    // On macOS, Windows and Linux the photo picker returns the user's own
    // file, not a copy — moving it would take it from them.
    test('off Android and iOS it adopts nothing and leaves the file', () async {
      final mine = File(p.join(support.path, 'holiday.jpg'))
        ..writeAsStringSync('x');

      expect(
        await store(canAdopt: false).adopt(mine.path, name: 'IMG_1.jpg'),
        isNull,
      );
      expect(mine.existsSync(), isTrue);
      expect(root.existsSync(), isFalse);
    });

    test('null when there is nowhere to keep it, or nothing to keep', () async {
      final none = SharedIntakeFiles(
        supportDirectory: () async => throw const FileSystemException('none'),
        canAdopt: () => true,
      );
      expect(await none.adopt('/nope.jpg', name: 'a.jpg'), isNull);
      expect(
        await store().adopt(p.join(support.path, 'missing.jpg'), name: 'a.jpg'),
        isNull,
      );
      expect(
        root.existsSync() ? root.listSync() : const <FileSystemEntity>[],
        isEmpty,
        reason: 'a failed adopt leaves no empty folder behind',
      );
    });
  });
}
