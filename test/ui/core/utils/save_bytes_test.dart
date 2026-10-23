import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:admin/ui/core/utils/save_bytes.dart';

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
}
