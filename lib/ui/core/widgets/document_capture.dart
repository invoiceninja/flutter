import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/services/shared_intake_files.dart';
import 'package:admin/data/services/upload_source.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/utils/file_type.dart';

/// The picker behind [captureDocumentPhoto] / [pickGalleryPhotos]. A widget
/// test swaps in a fake, so no platform channel is needed.
@visibleForTesting
ImagePicker Function() imagePickerFactory = _picker;

ImagePicker _picker() {
  // Android's photo grid instead of the generic file chooser. Off by default
  // in the plugin below Android 16; where a device has no photo picker it
  // falls back to the chooser by itself. (`ModuleDependencies`, which would
  // ask Play to install a backport on older devices, is stripped from the
  // manifest for the F-Droid build — docs/fdroid.md.)
  final platform = ImagePickerPlatform.instance;
  if (platform is ImagePickerAndroid) platform.useAndroidPhotoPicker = true;
  return ImagePicker();
}

/// Long edge and JPEG quality for every photo. A receipt stays legible and the
/// file a fraction of `kDocumentMaxBytes`. On Android the resize is also what
/// makes the plugin re-encode a library photo — a HEIC, which the server's
/// upload rule refuses, comes back as JPEG when the device can decode it; iOS
/// re-encodes anything but JPEG / PNG / GIF to JPEG on its own
/// (`docs/sharing-files-into-the-app.md`).
const double _kMaxEdge = 2560;
const int _kQuality = 85;

/// Takes one photo with the camera, for a document surface on a phone
/// (`FileDropZone.allowPhotos`, the dashboard's Scan Receipt). Empty when the
/// user backs out or the picture can't be used — every failure is toasted
/// here, so a caller only hands the result on.
Future<List<UploadSource>> captureDocumentPhoto(BuildContext context) =>
    _pickPhotos(context, () async {
      final shot = await imagePickerFactory().pickImage(
        source: ImageSource.camera,
        maxWidth: _kMaxEdge,
        maxHeight: _kMaxEdge,
        imageQuality: _kQuality,
      );
      return [?shot];
    });

/// Picks photos from the device's library — on iOS the only way to reach
/// Photos at all, since `file_picker`'s document picker browses Files. One
/// photo unless [multiple].
Future<List<UploadSource>> pickGalleryPhotos(
  BuildContext context, {
  required bool multiple,
}) => _pickPhotos(context, () async {
  final picker = imagePickerFactory();
  if (multiple) {
    return picker.pickMultiImage(
      maxWidth: _kMaxEdge,
      maxHeight: _kMaxEdge,
      imageQuality: _kQuality,
    );
  }
  final one = await picker.pickImage(
    source: ImageSource.gallery,
    maxWidth: _kMaxEdge,
    maxHeight: _kMaxEdge,
    imageQuality: _kQuality,
  );
  return [?one];
});

/// The app's own photo folder, or null — on web, or under a widget test whose
/// `Services` fake throws on any member it doesn't implement (a photo is then
/// kept as bytes, which is the right answer there too). Read it before an
/// await if the widget may be gone by the time it is needed.
SharedIntakeFiles? intakeOf(BuildContext context) {
  try {
    return context.read<Services?>()?.sharedIntakeFiles;
  } catch (_) {
    return null;
  }
}

/// Hands back photos [captureDocumentPhoto] / [pickGalleryPhotos] kept in the
/// app's folder when the surface they were for did not keep them — rejected,
/// refused, or gone before they arrived. A receipt is personal data, and the
/// launch sweep would otherwise leave it on the device for a day. Safe on any
/// source: `SharedIntakeFiles.delete` ignores a path outside its folder and
/// one an outbox upload still names.
Future<void> releaseCapturedPhotos(
  SharedIntakeFiles? intake,
  Iterable<UploadSource> sources,
) async {
  if (intake == null) return;
  final paths = sources.map(SharedIntakeFiles.localPathOf).nonNulls.toList();
  if (paths.isEmpty) return;
  await intake.delete(paths);
}

/// One picker at a time, app-wide. A second tap — the tablet's Scan Receipt
/// button, a Documents tile — before the first picker covers the screen
/// would otherwise make the plugin refuse it (`already_active`) or cancel the
/// first (`multiple_request`), and the user see an error for a camera that
/// is opening fine.
bool _picking = false;

/// Clears the single-flight flag — for a test whose pick never finished.
@visibleForTesting
void debugResetPhotoPicking() => _picking = false;

Future<List<UploadSource>> _pickPhotos(
  BuildContext context,
  Future<List<XFile>> Function() pick,
) async {
  if (_picking) return const [];
  _picking = true;
  try {
    return await _pickAndKeep(context, pick);
  } finally {
    _picking = false;
  }
}

Future<List<UploadSource>> _pickAndKeep(
  BuildContext context,
  Future<List<XFile>> Function() pick,
) async {
  // Read now: the screen may be gone when the picker returns, and the photo
  // must still leave the plugin's temp folder — the caller hands back what
  // it can't use (`releaseCapturedPhotos`).
  final intake = kIsWeb ? null : intakeOf(context);
  final List<XFile> picked;
  try {
    picked = await pick();
  } on PlatformException catch (e) {
    if (context.mounted) _notifyPickFailed(context, e);
    return const [];
  } catch (e) {
    if (context.mounted) {
      Notify.error(context, context.tr('an_error_occurred'), error: e);
    }
    return const [];
  }
  if (picked.isEmpty) return const [];

  final stamp = DateTime.now();
  final out = <UploadSource>[];
  final seen = <String>{};
  var refused = false;
  for (final file in picked) {
    // Android writes every resized library photo to `cache/scaled_<name>`, so
    // two picks that share a name come back as one path holding the second.
    if (file.path.isNotEmpty && !seen.add(file.path)) continue;
    try {
      // The content decides the extension. Android keeps the original name on
      // the JPEG it re-encoded (`IMG_1.heic`), and returns the original
      // untouched when it can't decode it — a HEIC the server would refuse.
      final ext = imageExtensionOf(await _head(file));
      if (ext == null) {
        refused = true;
        continue;
      }
      // Every pick gets the camera's name. The plugins' own are temp names —
      // iOS `image_picker_<GUID>.jpg`, Android `scaled_<name>` — and they
      // would reach the server and the client portal as the document's name.
      final name = _photoFileName(stamp, out.length, ext);
      // The plugin's copy lives in a temp folder the OS may empty before an
      // offline upload is sent; the app's own folder keeps it until then.
      final kept = await intake?.adopt(file.path, name: name);
      out.add(
        kept != null
            ? fileUploadSource(kept)
            // Bytes travel inside the outbox row, so they can't go missing.
            : BytesUploadSource(await file.readAsBytes(), name),
      );
    } catch (_) {
      // Gone or unreadable — the rest of the batch still counts.
      refused = true;
    }
  }
  if (refused && context.mounted) {
    Notify.warning(context, context.tr('dropzone_invalid_file_type'));
  }
  return out;
}

Future<Uint8List> _head(XFile file) async {
  try {
    final chunks = await file.openRead(0, 12).toList();
    return Uint8List.fromList([for (final c in chunks) ...c]);
  } catch (_) {
    // An in-memory file throws for a range past its end, where a file on
    // disk returns what it has.
    try {
      final all = await file.readAsBytes();
      return Uint8List.sublistView(all, 0, all.length < 12 ? all.length : 12);
    } catch (_) {
      return Uint8List(0);
    }
  }
}

/// `IMG_20261024_085700.jpg` — the camera's own convention, and the same in
/// every locale. A second photo in the same batch gets `_2`.
String _photoFileName(DateTime t, int index, String ext) {
  String two(int v) => v.toString().padLeft(2, '0');
  final suffix = index == 0 ? '' : '_${index + 1}';
  return 'IMG_${t.year}${two(t.month)}${two(t.day)}_'
      '${two(t.hour)}${two(t.minute)}${two(t.second)}$suffix.$ext';
}

void _notifyPickFailed(BuildContext context, PlatformException e) {
  switch (e.code) {
    // A second picker raced the first: the first is opening, say nothing.
    case 'already_active' || 'multiple_request':
      return;
    // Android with no camera app. (iOS shows its own "Camera not available."
    // alert and returns nothing, so it never gets here.)
    case 'no_available_camera':
      Notify.warning(context, context.tr('camera_unavailable'));
      return;
  }
  // `camera_access_denied` / `photo_access_denied` on both platforms, and
  // iOS's `…_access_restricted` (Screen Time, a managed device).
  if (e.code.contains('_access_')) {
    Notify.warning(
      context,
      context.tr('camera_access_denied'),
      action: NotifyAction(
        context.tr('settings'),
        () => unawaited(openAppSettingsPage()),
      ),
    );
    return;
  }
  Notify.error(context, context.tr('an_error_occurred'), error: e.message);
}

/// Same name as `MainActivity.APP_SETTINGS_CHANNEL`.
@visibleForTesting
const appSettingsChannel = MethodChannel('invoice_ninja/app_settings');

/// Opens this app's page in the system settings, where a refused camera or
/// photo permission is switched back on: iOS from a URL, Android through
/// `MainActivity` (no URL reaches it). Never throws.
Future<void> openAppSettingsPage() async {
  try {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await launchUrl(Uri.parse('app-settings:'));
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      await appSettingsChannel.invokeMethod<void>('openAppSettings');
    }
  } catch (_) {
    // Nothing better to offer: the toast already said where to go.
  }
}
