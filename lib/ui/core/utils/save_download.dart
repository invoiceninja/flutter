import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, visibleForTesting;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:admin/app/env.dart';

// A desktop download is written straight into the downloads folder, as the old
// app did — never handed to `Printing.sharePdf`, which on Windows and Linux
// writes a temp copy and opens it, and on macOS only offers to share it
// (docs/file-downloads.md). `bytesSaver` (save_bytes.dart) is the caller; this
// file is the IO, with no widgets, so it is tested with plain `test()`.

/// Windows or Linux, natively. Never web: there `defaultTargetPlatform`
/// reports the browser's OS, and a browser download is not this problem.
bool _nativeWindowsOrLinux() =>
    Env.isDesktop &&
    (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux);

/// Whether the user may choose the downloads folder. Not on macOS: a folder
/// picked in the sandboxed build loses its access on the next launch, so
/// there it is always Downloads (the `files.downloads.read-write`
/// entitlement).
bool downloadsFolderEditable() => _nativeWindowsOrLinux();

/// Whether `printing`'s Share opens a temp copy instead of sharing — every
/// `PdfPreview` passes `allowSharing: … && !pdfShareOpensTempCopy()`
/// (`test/lint/desktop_downloads_test.dart`). macOS keeps Share: there it is a
/// real share picker.
bool pdfShareOpensTempCopy() => _nativeWindowsOrLinux();

/// The OS Downloads folder as the user knows it, or null when there is no
/// usable one — the caller then opens the save dialog.
typedef DownloadsFolderLookup = Future<String?> Function();

Future<String?> _osDownloadsFolder() async {
  try {
    final dir = await getDownloadsDirectory();
    if (dir == null) return null;
    var path = dir.path;
    // The sandboxed build is handed its container's `Data/Downloads`, a link
    // to the real `~/Downloads`. Writes go through either way; resolving it
    // only keeps a Containers path out of the toast and the settings card.
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      path = await Directory(path).resolveSymbolicLinks();
    }
    if (defaultTargetPlatform == TargetPlatform.linux &&
        !_isLinuxDownloadsFolder(path)) {
      return null;
    }
    if (!await Directory(path).exists()) return null;
    return path;
  } catch (_) {
    return null;
  }
}

/// `xdg-user-dir DOWNLOAD` prints `$HOME` when the user has no downloads
/// folder configured, and under the snap's strict confinement `HOME` is the
/// snap's own data folder — neither is somewhere to say "saved in the
/// downloads folder" about.
bool _isLinuxDownloadsFolder(String path) {
  if (path.isEmpty) return false;
  final env = Platform.environment;
  final normalized = p.normalize(path);
  final home = env['HOME'];
  if (home != null && home.isNotEmpty && normalized == p.normalize(home)) {
    return false;
  }
  for (final key in const ['SNAP_USER_DATA', 'SNAP_USER_COMMON']) {
    final root = env[key];
    if (root == null || root.isEmpty) continue;
    final r = p.normalize(root);
    if (normalized == r || p.isWithin(r, normalized)) return false;
  }
  return true;
}

/// Replaced by tests; production asks `path_provider`.
@visibleForTesting
DownloadsFolderLookup downloadsFolderLookup = _osDownloadsFolder;

/// The OS Downloads folder, symlinks resolved, or null when there is no
/// usable one. Also what the Device Settings card shows by default.
Future<String?> defaultDownloadsFolder() => downloadsFolderLookup();

/// Thrown when the folder the user chose in Device Settings is gone.
class DownloadsFolderMissing implements Exception {
  const DownloadsFolderMissing(this.path);
  final String path;

  @override
  String toString() => 'DownloadsFolderMissing($path)';
}

/// A file [saveToDownloadsFolder] wrote.
class SavedDownload {
  const SavedDownload({required this.file, required this.isDefaultFolder});

  final File file;

  /// Written to the OS Downloads folder, not one the user chose.
  final bool isDefaultFolder;

  String get folder => file.parent.path;
  String get fileName => p.basename(file.path);
}

/// Writes [bytes] as [fileName] into the downloads folder: [chosen] where the
/// user may choose one (Windows / Linux) and did, else the OS Downloads
/// folder. A name already taken gets ` (1)`, ` (2)`… — never an overwrite.
///
/// Null means "use the save dialog instead": there is no usable downloads
/// folder, or the write failed. Throws [DownloadsFolderMissing] when [chosen]
/// no longer exists, so the caller can say so before the dialog.
///
/// [fileName] must already be safe (`sanitizeFileName` / `documentFileName`).
Future<SavedDownload?> saveToDownloadsFolder({
  required String chosen,
  required String fileName,
  required Uint8List bytes,
}) async {
  final useChosen = chosen.isNotEmpty && downloadsFolderEditable();
  final String folder;
  if (useChosen) {
    if (!await Directory(chosen).exists()) {
      throw DownloadsFolderMissing(chosen);
    }
    folder = chosen;
  } else {
    final found = await defaultDownloadsFolder();
    if (found == null) return null;
    folder = found;
  }

  final stem = p.basenameWithoutExtension(fileName);
  final ext = p.extension(fileName);
  for (var n = 0; n < 1000; n++) {
    final name = n == 0 ? fileName : '$stem ($n)$ext';
    final file = File(p.join(folder, name));
    try {
      await file.create(exclusive: true);
    } on FileSystemException {
      if (file.existsSync()) continue; // Taken — try the next number.
      return null;
    }
    try {
      await file.writeAsBytes(bytes, flush: true);
    } on FileSystemException {
      try {
        await file.delete();
      } catch (_) {
        // Leaving an empty file behind is the lesser problem.
      }
      return null;
    }
    return SavedDownload(file: file, isDefaultFolder: !useChosen);
  }
  return null;
}
