import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';

import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/notify.dart';

/// Saves bytes through the platform's save dialog — the signature of what
/// [bytesSaver] returns. Resolves to whether the file was saved; false is a
/// cancel or a failure, and a failure has already been toasted.
typedef BytesSaver =
    Future<bool> Function({required String fileName, required Uint8List bytes});

/// Saves [bytes] as [fileName] and says so. See [bytesSaver].
Future<bool> saveBytesAs(
  BuildContext context, {
  required String fileName,
  required Uint8List bytes,
}) => bytesSaver(context)(fileName: fileName, bytes: bytes);

/// A [BytesSaver] with everything it needs from [context] — the toast host and
/// the strings — resolved now, for a caller that still has the bytes to fetch.
/// The fetch can outlive the element that started it, and `context.tr` on a
/// deactivated element throws.
///
/// The file name must already be safe (`sanitizeFileName`, or
/// `documentFileName` for a document) and carry an extension — the web save
/// throws without one.
///
/// Per platform, `FilePicker.saveFile`:
///  * **web** starts a browser download and always returns null, so null is
///    success there — the browser shows its own download, and a toast on top
///    would only repeat it;
///  * **desktop** returns the chosen path without writing it, null on cancel;
///  * **mobile** writes the file itself, null on cancel.
/// The write below is therefore defensive: only when the path is missing or
/// empty.
BytesSaver bytesSaver(BuildContext context) {
  final toasts = Notify.capture(context);
  final l10n = Localization.of(context);
  String tr(String key, [Map<String, String>? params]) =>
      l10n?.lookup(key, params) ?? key;

  return ({required String fileName, required Uint8List bytes}) async {
    try {
      final path = await FilePicker.saveFile(fileName: fileName, bytes: bytes);
      if (kIsWeb) return true;
      if (path == null) return false;
      final file = File(path);
      if (!await file.exists() || await file.length() == 0) {
        await file.writeAsBytes(bytes);
      }
      toasts?.success(tr('file_saved_in_path', {'path': path}));
      return true;
    } catch (_) {
      toasts?.error(tr('an_error_occurred'));
      return false;
    }
  };
}
