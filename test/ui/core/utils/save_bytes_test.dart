import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import 'package:admin/app/downloads_folder_controller.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';
import 'package:admin/ui/core/utils/save_bytes.dart';
import 'package:admin/ui/core/utils/save_download.dart';
import 'package:admin/ui/core/widgets/toast_controller.dart';

import '../../../_localization_helper.dart';

/// file_picker 13's `saveFile` resolves a `Uri`, and on Android that can be a
/// `content:` document with no path — which a `File(...)` would throw on, and
/// which would read as a failed save even though the file was written.
void main() {
  final bytes = Uint8List.fromList([1, 2, 3]);
  final realSave = platformFileSave;
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('save_bytes_'));
  tearDown(() {
    platformFileSave = realSave;
    dir.deleteSync(recursive: true);
  });

  void platformReturns(Uri? uri) =>
      platformFileSave = ({required fileName, required bytes}) async => uri;

  test('a cancel is null', () async {
    platformReturns(null);
    expect(await saveBytesFile(fileName: 'a.csv', bytes: bytes), isNull);
  });

  test(
    'a file Uri the platform wrote is reported by path, untouched',
    () async {
      final file = File(p.join(dir.path, 'a.csv'))..writeAsBytesSync([9]);
      platformReturns(Uri.file(file.path));
      final saved = await saveBytesFile(fileName: 'a.csv', bytes: bytes);
      expect(saved?.path, file.path);
      expect(file.readAsBytesSync(), [9]);
    },
  );

  test('a file Uri that came back missing is written defensively', () async {
    final file = File(p.join(dir.path, 'b.csv'));
    platformReturns(Uri.file(file.path));
    final saved = await saveBytesFile(fileName: 'b.csv', bytes: bytes);
    expect(saved?.path, file.path);
    expect(file.readAsBytesSync(), bytes);
  });

  test('a content Uri is a save with no path — never a File', () async {
    platformReturns(Uri.parse('content://com.android.providers/document/42'));
    final saved = await saveBytesFile(fileName: 'c.csv', bytes: bytes);
    expect(saved, isNotNull);
    expect(saved!.path, isNull);
    expect(saved.isBrowserDownload, isFalse);
  });

  test(
    'on the web a null result is the browser download, not a cancel',
    () async {
      platformReturns(null);
      final saved = await saveBytesFile(
        fileName: 'd.csv',
        bytes: bytes,
        isWeb: true,
      );
      expect(saved?.isBrowserDownload, isTrue);
    },
  );

  group('bytesSaver on desktop', desktopDownloads);
}

/// A desktop Download writes into the downloads folder and says where; the
/// save dialog is only the fallback (docs/file-downloads.md).
void desktopDownloads() {
  final bytes = Uint8List.fromList([1, 2, 3]);
  final realSave = platformFileSave;
  final realLookup = downloadsFolderLookup;
  final realShare = pdfShare;
  late Directory downloads;
  late ToastController toasts;
  late List<String> dialogSaves;
  late List<String> shares;

  setUp(() {
    downloads = Directory(
      Directory.systemTemp
          .createTempSync('bytes_saver_')
          .resolveSymbolicLinksSync(),
    );
    downloadsFolderLookup = () async => downloads.path;
    toasts = ToastController();
    dialogSaves = [];
    shares = [];
    platformFileSave = ({required fileName, required bytes}) async {
      dialogSaves.add(fileName);
      return null;
    };
    pdfShare = ({required bytes, required filename}) async {
      shares.add(filename);
      return true;
    };
  });
  tearDown(() {
    platformFileSave = realSave;
    downloadsFolderLookup = realLookup;
    pdfShare = realShare;
    toasts.dispose();
    downloads.deleteSync(recursive: true);
  });

  Future<BuildContext> pumpContext(
    WidgetTester tester, {
    String chosen = '',
  }) async {
    final prefs = DevicePrefsStore(null);
    final folder = DownloadsFolderController(prefs: prefs);
    await folder.set(chosen);
    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<ToastController>.value(value: toasts),
            ChangeNotifierProvider<DownloadsFolderController>.value(
              value: folder,
            ),
          ],
          child: Builder(
            builder: (context) {
              captured = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    return captured;
  }

  testWidgets('writes into the downloads folder and names the file it wrote', (
    tester,
  ) async {
    final context = await pumpContext(tester);
    final save = bytesSaver(context);
    File(p.join(downloads.path, 'invoice_7.pdf')).writeAsBytesSync([9]);
    await tester.runAsync(() => save(fileName: 'invoice_7.pdf', bytes: bytes));

    expect(dialogSaves, isEmpty);
    expect(
      File(p.join(downloads.path, 'invoice_7 (1).pdf')).readAsBytesSync(),
      bytes,
    );
    final toast = toasts.toasts.single;
    expect(toast.message, 'The file has been saved in the downloads folder');
    expect(toast.detail, 'invoice_7 (1).pdf');
    expect(toast.action?.label, 'Open');
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets(
    'a chosen folder that is gone says so, then opens the save dialog',
    (tester) async {
      final gone = p.join(downloads.path, 'deleted');
      final context = await pumpContext(tester, chosen: gone);
      final save = bytesSaver(context);
      await tester.runAsync(() => save(fileName: 'a.pdf', bytes: bytes));

      expect(dialogSaves, ['a.pdf']);
      expect(
        toasts.toasts.first.message,
        'The downloads folder does not exist $gone',
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets(
    'off desktop a Download is the save dialog, and a PDF the share sheet',
    (tester) async {
      final context = await pumpContext(tester);
      final save = bytesSaver(context);
      await tester.runAsync(() => save(fileName: 'a.csv', bytes: bytes));
      await tester.runAsync(
        () => downloadPdf(context, fileName: 'b.pdf')(bytes),
      );

      expect(dialogSaves, ['a.csv']);
      expect(shares, ['b.pdf']);
      expect(downloads.listSync(), isEmpty);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('on desktop a PDF Download never reaches the share', (
    tester,
  ) async {
    final context = await pumpContext(tester);
    await tester.runAsync(() => downloadPdf(context, fileName: 'b.pdf')(bytes));

    expect(shares, isEmpty);
    expect(File(p.join(downloads.path, 'b.pdf')).existsSync(), isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}
