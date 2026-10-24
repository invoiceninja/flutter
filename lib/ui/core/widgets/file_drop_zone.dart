import 'dart:async';
import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/data/services/upload_source.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/document_capture.dart';
import 'package:admin/ui/core/widgets/icon_label_tile.dart';

/// Whether the running platform supports OS file drag-and-drop. Web and mobile
/// fall back to click-to-select only (the box stays tappable, just no drop).
bool get fileDropSupported {
  if (kIsWeb) return false;
  final p = defaultTargetPlatform;
  return p == TargetPlatform.macOS ||
      p == TargetPlatform.linux ||
      p == TargetPlatform.windows;
}

/// Builds an [UploadSource] from raw parts: a native filesystem [path] wins on
/// non-web; otherwise in-memory [bytes]. Returns null when neither is usable
/// (e.g. a web pick that never loaded bytes). Pure + platform-branching, so the
/// drop / pick adapters below and the unit tests share one code path.
UploadSource? uploadSourceFromParts({
  String? path,
  Uint8List? bytes,
  required String name,
}) {
  if (!kIsWeb && path != null && path.isNotEmpty) return fileUploadSource(path);
  if (bytes != null) return BytesUploadSource(bytes, name);
  return null;
}

/// Converts the picked [PlatformFile]s (the click-to-select path) into upload
/// sources, dropping any entry that has neither a path nor bytes. A native pick
/// with a `file:` Uri carries a real path (streamed, never copied); a web pick,
/// or one whose Uri is not a file (`PlatformFile.path` is null for an Android
/// `content:` document), is read on demand — `readAsBytes()` fetches it,
/// replacing the removed `withData` eager-load.
Future<List<UploadSource>> uploadSourcesFromPicked(
  List<PlatformFile> files,
) async {
  final out = <UploadSource>[];
  for (final f in files) {
    final bytes = kIsWeb || f.path == null ? await f.readAsBytes() : null;
    final src = uploadSourceFromParts(path: f.path, bytes: bytes, name: f.name);
    if (src != null) out.add(src);
  }
  return out;
}

/// Converts an OS drag-drop ([DropDoneDetails]) into upload sources. On native
/// each file has a real path; on web `XFile.path` is a blob URL, so we read the
/// bytes the drop handed us instead.
Future<List<UploadSource>> uploadSourcesFromDrop(
  DropDoneDetails details,
) async {
  final out = <UploadSource>[];
  for (final xf in details.files) {
    out.add(
      !kIsWeb && xf.path.isNotEmpty
          ? fileUploadSource(xf.path)
          : BytesUploadSource(await xf.readAsBytes(), xf.name),
    );
  }
  return out;
}

/// The single "drop a file here or click to select" affordance used at every
/// upload site (logo, documents, certificate, import, designer image, …). On
/// desktop it accepts OS drag-and-drop; on every platform a click opens the
/// file picker. The host supplies [allowedExtensions] + an [onFiles] callback
/// that does the site-specific validation / upload; this widget owns only the
/// picker invocation, the drag-over visuals, and the file → [UploadSource]
/// conversion, so every upload site looks and behaves identically.
///
/// A documents surface sets [allowPhotos]: on a phone or tablet the box then
/// becomes three tiles — Camera, Photos, Files — since there is nothing to
/// drop there and the document picker behind "click" can't reach Photos on
/// iOS. Each tile ends in the same [onFiles].
class FileDropZone extends StatefulWidget {
  const FileDropZone({
    super.key,
    required this.allowedExtensions,
    required this.onFiles,
    this.allowMultiple = false,
    this.preview,
    this.enabled = true,
    this.idleLabelKey,
    this.allowPhotos = false,
  });

  /// Extension allowlist (no leading dot) passed to the picker and — on web —
  /// the only client-side filter. Sites still re-validate in [onFiles].
  final List<String> allowedExtensions;

  /// Receives the picked / dropped files as [UploadSource]s. Does the
  /// site-specific validation + upload (and its own success/error toasts).
  final Future<void> Function(List<UploadSource> sources) onFiles;

  final bool allowMultiple;

  /// Rendered inside the box in place of the default upload icon (e.g. the
  /// current company logo). Drop + click stay active over it.
  final Widget? preview;

  /// When false the box is dimmed and ignores taps + drops.
  final bool enabled;

  /// Localization key for the idle hint; defaults to `dropzone_default_message`
  /// ("Drop files or click to upload").
  final String? idleLabelKey;

  /// Offer Camera and Photos beside Files on a native phone or tablet
  /// ([Env.isMobile]); ignored everywhere else. For the document surfaces —
  /// a logo, a certificate or an import file has no business being a photo.
  final bool allowPhotos;

  @override
  State<FileDropZone> createState() => _FileDropZoneState();
}

class _FileDropZoneState extends State<FileDropZone> {
  bool _dragOver = false;

  /// A picker is open. A second tap would stack another one over it.
  bool _picking = false;

  /// Which tile's work is under way (`_photoTiles`), for its spinner: the
  /// picker, then the photo's processing and [FileDropZone.onFiles] — a big
  /// photo from iCloud or a re-encode can take seconds after the picker
  /// closes.
  _Source? _active;

  Future<void> _run(
    Future<List<UploadSource>> Function() pick, {
    _Source? source,
  }) async {
    if (_picking) return;
    // Read now: once the zone is gone there is no context to read it from.
    final intake = intakeOf(context);
    setState(() {
      _picking = true;
      _active = source;
    });
    try {
      final sources = await pick();
      if (sources.isEmpty) return;
      if (!mounted) {
        // Left the screen with the camera open: nothing will take the photo.
        await releaseCapturedPhotos(intake, sources);
        return;
      }
      await widget.onFiles(sources);
    } finally {
      if (mounted) {
        setState(() {
          _picking = false;
          _active = null;
        });
      }
    }
  }

  Future<void> _pick() => _run(_pickFiles, source: _Source.files);

  Future<List<UploadSource>> _pickFiles() async {
    // `pickFile` is the single-select entry point; `pickFiles` implies multiple.
    // Bytes are pulled on demand in uploadSourcesFromPicked (no eager withData).
    final List<PlatformFile> files;
    if (widget.allowMultiple) {
      // An empty list is a cancel.
      files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: widget.allowedExtensions,
      );
    } else {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: widget.allowedExtensions,
      );
      if (picked == null) return const [];
      files = [picked];
    }
    return uploadSourcesFromPicked(files);
  }

  Future<void> _onDrop(DropDoneDetails details) async {
    setState(() => _dragOver = false);
    final sources = await uploadSourcesFromDrop(details);
    if (sources.isEmpty) return;
    await widget.onFiles(sources);
  }

  /// Camera / Photos / Files, side by side — the touch replacement for the
  /// box, in the create sheet's tile style. Capped in width: on a tablet's
  /// wide pane three stretched tiles read as a banner, not as buttons.
  Widget _photoTiles(BuildContext context) {
    final live = widget.enabled && !_picking;
    Widget tile(_Source source, IconData icon, String labelKey) =>
        IconLabelTile(
          icon: icon,
          label: context.tr(labelKey),
          busy: _active == source,
          onTap: live ? () => _start(source) : null,
        );
    final tiles = [
      tile(_Source.camera, Icons.photo_camera_outlined, 'photo_source_camera'),
      tile(_Source.photos, Icons.photo_library_outlined, 'photo_source_photos'),
      tile(
        _Source.files,
        Icons.insert_drive_file_outlined,
        'photo_source_files',
      ),
    ];
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _kPhotoTilesMaxWidth),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                if (i > 0) const SizedBox(width: InSpacing.sm),
                Expanded(child: tiles[i]),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _start(_Source source) => unawaited(switch (source) {
    _Source.camera => _run(() => captureDocumentPhoto(context), source: source),
    _Source.photos => _run(
      () => pickGalleryPhotos(context, multiple: widget.allowMultiple),
      source: source,
    ),
    _Source.files => _pick(),
  });

  @override
  Widget build(BuildContext context) {
    if (widget.allowPhotos && Env.isMobile) return _photoTiles(context);
    final tokens = context.inTheme;
    final over = _dragOver && widget.enabled;
    final idleLabel = context.tr(
      widget.idleLabelKey ?? 'dropzone_default_message',
    );
    final activeLabel = context.tr(
      widget.allowMultiple ? 'drop_files_here' : 'drop_file_here',
    );

    final box = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: InSpacing.lg(context),
        vertical: InSpacing.xl,
      ),
      decoration: BoxDecoration(
        color: over ? tokens.accentSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(InRadii.r2),
        border: Border.all(
          color: over ? tokens.accent : tokens.border,
          width: over ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          widget.preview ??
              Icon(Icons.upload_file_outlined, size: 32, color: tokens.ink3),
          const SizedBox(height: InSpacing.sm),
          Text(
            over ? activeLabel : idleLabel,
            textAlign: TextAlign.center,
            style: TextStyle(color: tokens.ink2, fontSize: 13),
          ),
        ],
      ),
    );

    final tappable = Opacity(
      opacity: widget.enabled ? 1 : 0.5,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(InRadii.r2),
        child: InkWell(
          onTap: widget.enabled ? _pick : null,
          borderRadius: BorderRadius.circular(InRadii.r2),
          child: box,
        ),
      ),
    );

    if (!fileDropSupported || !widget.enabled) return tappable;
    return DropTarget(
      onDragEntered: (_) => setState(() => _dragOver = true),
      onDragExited: (_) => setState(() => _dragOver = false),
      onDragDone: _onDrop,
      child: tappable,
    );
  }
}

/// The three tiles of `_photoTiles`.
enum _Source { camera, photos, files }

/// Three tiles of ~150 px — wide enough for every locale's label on two
/// lines, narrow enough to read as buttons on a tablet.
const double _kPhotoTilesMaxWidth = 480;
