import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:admin/ui/core/utils/save_download.dart';

/// A desktop download is written straight into the downloads folder — never
/// handed to `Printing.sharePdf`, which on Windows and Linux only opens a temp
/// copy (docs/file-downloads.md). Plain `test()` against real temp folders:
/// file IO inside `testWidgets`' fake-async zone can hang.
void main() {
  final bytes = Uint8List.fromList([1, 2, 3]);
  final realLookup = downloadsFolderLookup;
  late Directory downloads;
  late Directory chosen;

  setUp(() {
    downloads = Directory(
      Directory.systemTemp
          .createTempSync('downloads_')
          .resolveSymbolicLinksSync(),
    );
    chosen = Directory(
      Directory.systemTemp.createTempSync('chosen_').resolveSymbolicLinksSync(),
    );
    downloadsFolderLookup = () async => downloads.path;
  });
  tearDown(() {
    downloadsFolderLookup = realLookup;
    debugDefaultTargetPlatformOverride = null;
    downloads.deleteSync(recursive: true);
    chosen.deleteSync(recursive: true);
  });

  Future<SavedDownload?> save({
    String chosenPath = '',
    String name = 'a.pdf',
  }) => saveToDownloadsFolder(chosen: chosenPath, fileName: name, bytes: bytes);

  test('the default goes to the OS downloads folder', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    final saved = await save();
    expect(saved!.isDefaultFolder, isTrue);
    expect(saved.file.path, p.join(downloads.path, 'a.pdf'));
    expect(saved.file.readAsBytesSync(), bytes);
  });

  for (final platform in [TargetPlatform.windows, TargetPlatform.linux]) {
    test('$platform writes to the chosen folder', () async {
      debugDefaultTargetPlatformOverride = platform;
      final saved = await save(chosenPath: chosen.path);
      expect(saved!.isDefaultFolder, isFalse);
      expect(saved.folder, chosen.path);
      expect(File(p.join(chosen.path, 'a.pdf')).existsSync(), isTrue);
    });
  }

  test('macOS ignores a chosen folder: it would not survive a relaunch in the '
      'sandbox', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final saved = await save(chosenPath: chosen.path);
    expect(saved!.isDefaultFolder, isTrue);
    expect(saved.folder, downloads.path);
  });

  test(
    'a name already taken gets (1), then (2) — never an overwrite',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      File(p.join(downloads.path, 'invoice_1.pdf')).writeAsBytesSync([9]);
      final first = await save(name: 'invoice_1.pdf');
      final second = await save(name: 'invoice_1.pdf');
      expect(first!.fileName, 'invoice_1 (1).pdf');
      expect(second!.fileName, 'invoice_1 (2).pdf');
      expect(File(p.join(downloads.path, 'invoice_1.pdf')).readAsBytesSync(), [
        9,
      ]);
    },
  );

  test(
    'a chosen folder that is gone throws, so the caller can say so',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      final gone = p.join(chosen.path, 'deleted');
      await expectLater(
        save(chosenPath: gone),
        throwsA(
          isA<DownloadsFolderMissing>().having((e) => e.path, 'path', gone),
        ),
      );
    },
  );

  test(
    'no usable default folder is null — the caller opens the dialog',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      downloadsFolderLookup = () async => null;
      expect(await save(), isNull);
    },
  );

  test('a failed write is null and leaves nothing behind', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    // A name the OS can't create in the folder: a path into a missing
    // sub-folder fails on create without the candidate existing.
    expect(await save(name: p.join('missing', 'a.pdf')), isNull);
    expect(downloads.listSync(), isEmpty);
  });

  group('platform predicates', () {
    test('only Windows and Linux open a temp copy on Share / may choose a '
        'folder', () {
      for (final platform in TargetPlatform.values) {
        debugDefaultTargetPlatformOverride = platform;
        final expected =
            platform == TargetPlatform.windows ||
            platform == TargetPlatform.linux;
        expect(pdfShareOpensTempCopy(), expected, reason: '$platform');
        expect(downloadsFolderEditable(), expected, reason: '$platform');
      }
    });
  });
}
