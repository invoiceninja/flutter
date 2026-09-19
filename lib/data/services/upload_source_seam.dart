/// Platform seam for the filesystem-backed [UploadSource].
///
/// Native (`dart.library.io`) → `FileUploadSource` streaming from disk
/// (byte-identical to the pre-web upload path). Web → a stub whose
/// [fileUploadSource] throws, because web never enqueues a `local_path`
/// (its screens produce a `BytesUploadSource`). Default target is the web
/// stub; `dart.library.io` swaps in the native implementation.
library;

export 'package:admin/data/services/upload_source_seam_web.dart'
    if (dart.library.io) 'package:admin/data/services/upload_source_seam_io.dart';
