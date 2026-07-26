import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/services/upload_source.dart';
import 'package:admin/utils/document_upload_validation.dart';

/// First coverage for `validateDocumentUpload` — the last untested file in
/// `lib/utils/`. It is the single gate in front of both document-upload entry
/// points (`EntityDocumentsTab` and Company Details → Documents), for both the
/// file-picker and drag-drop paths, so a hole here means either a rejected
/// valid file or a wasted round-trip on one the server will refuse.
///
/// Extension matching is case-insensitive and takes the substring after the
/// LAST dot; the size cap is exclusive at the boundary (`> kDocumentMaxBytes`).
///
/// [_source] reports a name and a size without allocating a buffer —
/// `validateDocumentUpload` only reads `fileName` and `length()`, never the
/// bytes, so the size-cap cases would otherwise allocate 25 MB of real heap
/// each to assert an integer comparison. Set [readable] false to make
/// `length()` throw, which is the `unreadable` branch (a native local_path
/// that vanished between pick and validate). One test still uses the real
/// `BytesUploadSource` so the fake can't drift from the interface.
UploadSource _source(String fileName, {int size = 10, bool readable = true}) =>
    _FakeSource(fileName, size: size, readable: readable);

class _FakeSource implements UploadSource {
  _FakeSource(this.fileName, {required this.size, required this.readable});

  @override
  final String fileName;
  final int size;
  final bool readable;

  @override
  Future<int> length() async => readable ? size : throw const _SourceGone();

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Stands in for the platform error a vanished local file raises.
class _SourceGone implements Exception {
  const _SourceGone();
}

void main() {
  group('accepts allowlisted extensions', () {
    test('a plain pdf', () async {
      final result = await validateDocumentUpload(_source('invoice.pdf'));

      expect(result.isOk, isTrue);
      expect(result.issue, isNull);
      expect(result.fileName, 'invoice.pdf');
      expect(result.sizeBytes, 10);
    });

    test('extension matching is case-insensitive', () async {
      expect((await validateDocumentUpload(_source('SCAN.PDF'))).isOk, isTrue);
      expect((await validateDocumentUpload(_source('a.JpEg'))).isOk, isTrue);
    });

    test('only the final extension counts', () async {
      expect(
        (await validateDocumentUpload(_source('report.exe.pdf'))).isOk,
        isTrue,
      );
    });

    test('every entry in the allowlist is reachable by the parser', () async {
      // Not a tautology despite `contains` being the production check: the
      // parser lowercases and strips the dot before matching, so a malformed
      // allowlist entry ('PDF', '.pdf', 'tar.gz') could never match any real
      // filename. This is the only thing that would catch that.
      for (final ext in kDocumentAllowedExtensions) {
        expect(
          (await validateDocumentUpload(_source('file.$ext'))).isOk,
          isTrue,
          reason: '"$ext" is on the allowlist but no filename can match it',
        );
      }
    });

    test('a real BytesUploadSource round-trips (not just the fake)', () async {
      final result = await validateDocumentUpload(
        BytesUploadSource(Uint8List(7), 'real.pdf'),
      );

      expect(result.isOk, isTrue);
      expect(result.sizeBytes, 7);
    });

    test('a leading-dot filename is accepted on its suffix', () async {
      // '.pdf' → lastIndexOf('.') is 0, so ext is 'pdf' and it passes. Pinned
      // because it is non-obvious, not because it is desirable.
      expect((await validateDocumentUpload(_source('.pdf'))).isOk, isTrue);
    });
  });

  group('rejects with wrongExtension', () {
    test('an extension that is not on the allowlist', () async {
      final result = await validateDocumentUpload(_source('malware.exe'));

      expect(result.isOk, isFalse);
      expect(result.issue, DocumentUploadIssue.wrongExtension);
      expect(result.fileName, 'malware.exe');
      expect(result.sizeBytes, 0);
    });

    test('a file with no extension at all', () async {
      expect(
        (await validateDocumentUpload(_source('README'))).issue,
        DocumentUploadIssue.wrongExtension,
      );
    });

    test('a trailing dot with nothing after it', () async {
      expect(
        (await validateDocumentUpload(_source('weird.'))).issue,
        DocumentUploadIssue.wrongExtension,
      );
    });

    test('a dotfile with no allowlisted suffix is rejected', () async {
      expect(
        (await validateDocumentUpload(_source('.gitignore'))).issue,
        DocumentUploadIssue.wrongExtension,
      );
    });
  });

  group('size cap', () {
    test('a file exactly at the cap is accepted', () async {
      final result = await validateDocumentUpload(
        _source('big.pdf', size: kDocumentMaxBytes),
      );

      expect(result.isOk, isTrue);
      expect(result.sizeBytes, kDocumentMaxBytes);
    });

    test('one byte over the cap is rejected', () async {
      final result = await validateDocumentUpload(
        _source('toobig.pdf', size: kDocumentMaxBytes + 1),
      );

      expect(result.issue, DocumentUploadIssue.tooLarge);
      expect(result.fileName, 'toobig.pdf');
    });

    test('an empty file is accepted', () async {
      expect(
        (await validateDocumentUpload(_source('empty.txt', size: 0))).isOk,
        isTrue,
      );
    });

    test('the cap is 25 MB', () {
      // Deliberately one assertion. `kDocumentMaxMb` is *derived* from
      // `kDocumentMaxBytes` (`~/ (1024 * 1024)`), so also asserting it would
      // be asserting the same constant twice — it can never disagree, and a
      // test that cannot fail is worse than no test. Pin the product decision.
      expect(kDocumentMaxBytes, 25 * 1024 * 1024);
    });
  });

  group('unreadable source', () {
    test('a length() failure reports unreadable, not a throw', () async {
      final result = await validateDocumentUpload(
        _source('gone.pdf', readable: false),
      );

      expect(result.isOk, isFalse);
      expect(result.issue, DocumentUploadIssue.unreadable);
      expect(result.fileName, 'gone.pdf');
    });

    test('the extension check runs first — a bad extension never reads the '
        'file', () async {
      // Guards the ordering: a vanished file with a rejected extension must
      // report the extension problem, which is the actionable message. If the
      // size check ran first this would surface `unreadable` instead.
      final result = await validateDocumentUpload(
        _source('gone.exe', readable: false),
      );

      expect(result.issue, DocumentUploadIssue.wrongExtension);
    });
  });
}
