import 'package:admin/data/prefs/device_pref.dart';
import 'package:admin/data/prefs/device_pref_keys.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';

/// Owns the folder a desktop download is written to
/// (`DevicePrefKeys.downloadsFolder`, device-local).
///
/// Empty — the default — is the OS Downloads folder. Only Windows and Linux
/// let the user change it: a folder picked in the sandboxed macOS build loses
/// its access on the next launch (docs/file-downloads.md).
///
/// Read through its root provider as
/// `context.read<DownloadsFolderController?>()`, so a test without the
/// provider simply gets the default.
class DownloadsFolderController extends DevicePref<String> {
  DownloadsFolderController({required DevicePrefsStore prefs})
    : super(prefs, DevicePrefKeys.downloadsFolder, fallback: '');
}
