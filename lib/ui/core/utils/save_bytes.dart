import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/widgets.dart';

import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/notify.dart';

/// Saves bytes through the platform's save dialog — the signature of what
/// [bytesSaver] returns. Resolves to whether the file was saved; false is a
/// cancel or a failure, and a failure has already been toasted.
typedef BytesSaver =
    Future<bool> Function({required String fileName, required Uint8List bytes});

/// Where [saveBytesFile] put the bytes. A cancel is a null [SavedFile], not one
/// of these.
class SavedFile {
  const SavedFile.atPath(String this.path) : isBrowserDownload = false;
  const SavedFile.elsewhere() : path = null, isBrowserDownload = false;
  const SavedFile.browserDownload() : path = null, isBrowserDownload = true;

  /// The filesystem path, when there is one to show the user. Null for a
  /// browser download and for an Android `content://` document.
  final String? path;

  /// The browser shows its own download, so a toast on top only repeats it.
  final bool isBrowserDownload;
}

/// The platform save, as `FilePicker.saveFile` exposes it.
typedef PlatformFileSave =
    Future<Uri?> Function({required String fileName, required Uint8List bytes});

Future<Uri?> _filePickerSave({
  required String fileName,
  required Uint8List bytes,
}) => FilePicker.saveFile(fileName: fileName, bytes: bytes);

/// Replaced by tests; production always goes through `FilePicker.saveFile`.
@visibleForTesting
PlatformFileSave platformFileSave = _filePickerSave;

/// Saves [bytes] as [fileName] through the platform's save dialog. Null on a
/// cancel; throws on a failure.
///
/// The file name must already be safe (`sanitizeFileName`, or
/// `documentFileName` for a document) and carry an extension — the web save
/// throws without one.
///
/// Per platform, `FilePicker.saveFile` (file_picker 13):
///  * **web** starts a browser download and resolves null — which here is
///    success, not a cancel;
///  * **desktop and iOS** write the file themselves and resolve a `file:` Uri;
///  * **Android** writes through the system picker and may resolve a
///    `content:` Uri, which has no path and must never reach [File].
/// The write below is defensive, and only where there is a real path that came
/// back missing or empty.
Future<SavedFile?> saveBytesFile({
  required String fileName,
  required Uint8List bytes,
  @visibleForTesting bool isWeb = kIsWeb,
}) async {
  final uri = await platformFileSave(fileName: fileName, bytes: bytes);
  if (isWeb) return const SavedFile.browserDownload();
  if (uri == null) return null;
  if (uri.scheme != 'file') return const SavedFile.elsewhere();
  final path = uri.toFilePath();
  final file = File(path);
  if (!await file.exists() || await file.length() == 0) {
    await file.writeAsBytes(bytes);
  }
  return SavedFile.atPath(path);
}

/// Saves [bytes] as [fileName] and says so. See [bytesSaver].
Future<bool> saveBytesAs(
  BuildContext context, {
  required String fileName,
  required Uint8List bytes,
}) => bytesSaver(context)(fileName: fileName, bytes: bytes);

/// A [BytesSaver] with everything it needs from [context] — the toast host and
/// the strings — resolved now, for a caller that still has the bytes to fetch.
/// The fetch can outlive the element that started it, and `context.tr` on a
/// deactivated element throws. See [saveBytesFile] for the platform rules.
BytesSaver bytesSaver(BuildContext context) {
  final toasts = Notify.capture(context);
  final l10n = Localization.of(context);
  String tr(String key, [Map<String, String>? params]) =>
      l10n?.lookup(key, params) ?? key;

  return ({required String fileName, required Uint8List bytes}) async {
    try {
      final saved = await saveBytesFile(fileName: fileName, bytes: bytes);
      if (saved == null) return false;
      if (saved.isBrowserDownload) return true;
      final path = saved.path;
      toasts?.success(
        path == null ? tr('saved') : tr('file_saved_in_path', {'path': path}),
      );
      return true;
    } catch (_) {
      toasts?.error(tr('an_error_occurred'));
      return false;
    }
  };
}
