import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'package:admin/data/services/upload_source_seam.dart';
// Re-export the platform seam's factory so callers only import this file.
export 'package:admin/data/services/upload_source_seam.dart'
    show fileUploadSource;

/// A platform-neutral handle to an about-to-be-uploaded file.
///
/// Native screens have a filesystem path; web screens (`file_picker`, a
/// browser drop) only have in-memory bytes. Both the upload transport
/// (`ApiClient.uploadMultipartChunked`, the entity/company `*Api.upload*`
/// methods) and the offline outbox speak [UploadSource] so neither has to
/// branch on platform.
///
/// Two concrete forms:
/// - [BytesUploadSource] — pure Dart, all platforms (the web channel).
/// - `FileUploadSource` — native-only, behind the `dart.library.io` seam
///   (`upload_source_seam.dart`). It streams from disk via `File.openRead`
///   and builds multipart via `MultipartFile.fromPath`, i.e. **byte-identical
///   to the pre-web upload path**. Constructed through [fileUploadSource].
///
/// The outbox serialization is the cross-platform contract: native rows carry
/// `{'local_path': …}` exactly as before (no schema migration — old parked
/// rows still decode); web rows carry `{'upload_bytes_b64': …}`.
abstract class UploadSource {
  String get fileName;

  /// Total byte length. Cheap on both forms (file `stat` / in-memory length).
  Future<int> length();

  /// Reads `[start, end)`. The chunked uploader calls this per 2 MB slice;
  /// the file form streams so a large company-import zip never sits fully in
  /// memory.
  Future<Uint8List> readRange(int start, int end);

  /// Builds a single `multipart/form-data` part for the simple (non-chunked)
  /// logo / document / certificate uploads. File form → `fromPath`
  /// (streaming, byte-identical native); bytes form → `fromBytes`.
  Future<http.MultipartFile> toMultipartFile(String field);

  /// Whether the underlying data is still available. The sync dispatchers
  /// drop an upload row rather than 5xx-loop if the file vanished between
  /// enqueue and drain. Bytes are held in the payload, so always `true`.
  Future<bool> exists();

  /// Serializes into an outbox mutation payload. Merge into the existing
  /// payload map; [fromPayload] is the inverse.
  Map<String, dynamic> toPayload();

  /// Reconstructs from an outbox payload. `local_path` → native file source;
  /// `upload_bytes_b64` → bytes source. Backwards-compatible with rows
  /// enqueued before the web seam (those only have `local_path`).
  static UploadSource fromPayload(Map<String, dynamic> payload) {
    final localPath = payload['local_path'];
    if (localPath is String && localPath.isNotEmpty) {
      return fileUploadSource(localPath);
    }
    final b64 = payload['upload_bytes_b64'];
    if (b64 is String) {
      return BytesUploadSource(
        base64Decode(b64),
        payload['file_name'] as String? ?? 'upload',
      );
    }
    throw ArgumentError(
      'UploadSource payload missing local_path / upload_bytes_b64',
    );
  }
}

/// In-memory upload source — the web channel, but also usable anywhere.
class BytesUploadSource implements UploadSource {
  BytesUploadSource(this.bytes, this.fileName);

  final Uint8List bytes;

  @override
  final String fileName;

  @override
  Future<int> length() async => bytes.length;

  @override
  Future<Uint8List> readRange(int start, int end) async =>
      Uint8List.sublistView(bytes, start, end);

  @override
  Future<http.MultipartFile> toMultipartFile(String field) async =>
      http.MultipartFile.fromBytes(field, bytes, filename: fileName);

  @override
  Future<bool> exists() async => true;

  @override
  Map<String, dynamic> toPayload() => {
    'upload_bytes_b64': base64Encode(bytes),
    'file_name': fileName,
  };
}
