import 'package:admin/data/services/upload_source.dart';

/// Allowlist of file extensions the server accepts as document attachments
/// (mirrors what admin-portal allows). Sent to the picker as a hard filter,
/// and re-checked after pick/drop because some pickers ignore the filter on
/// certain platforms.
const kDocumentAllowedExtensions = <String>[
  'pdf',
  'doc',
  'docx',
  'xls',
  'xlsx',
  'ppt',
  'pptx',
  'txt',
  'csv',
  'rtf',
  'odt',
  'ods',
  'odp',
  'png',
  'jpg',
  'jpeg',
  'gif',
  'webp',
  'heic',
  'svg',
];

/// Hard cap on uploaded file size. The server enforces this too, but
/// rejecting client-side saves a wasted round-trip and gives the user a
/// crisp message.
const int kDocumentMaxBytes = 25 * 1024 * 1024;

/// Convenience MB constant for display in the "too large" toast.
const int kDocumentMaxMb = kDocumentMaxBytes ~/ (1024 * 1024);

enum DocumentUploadIssue { wrongExtension, tooLarge, unreadable }

/// Result of a pre-upload validation check.
class DocumentUploadValidation {
  const DocumentUploadValidation.ok(this.fileName, this.sizeBytes)
    : issue = null;
  const DocumentUploadValidation.failed(this.fileName, this.issue)
    : sizeBytes = 0;

  final String fileName;
  final int sizeBytes;
  final DocumentUploadIssue? issue;

  bool get isOk => issue == null;
}

/// Validate one [UploadSource] against the allowlist + size cap. Used by
/// `EntityDocumentsTab` for both the file-picker and drag-drop paths (and
/// on every platform) so the reject toasts are identical regardless of how
/// the user added the file. Extension comes from [UploadSource.fileName];
/// size from [UploadSource.length] (cheap on both the file and bytes form).
Future<DocumentUploadValidation> validateDocumentUpload(
  UploadSource source,
) async {
  final name = source.fileName;
  final dot = name.lastIndexOf('.');
  final ext = dot >= 0 ? name.substring(dot + 1).toLowerCase() : '';
  if (!kDocumentAllowedExtensions.contains(ext)) {
    return DocumentUploadValidation.failed(
      name,
      DocumentUploadIssue.wrongExtension,
    );
  }
  int size;
  try {
    size = await source.length();
  } catch (_) {
    return DocumentUploadValidation.failed(
      name,
      DocumentUploadIssue.unreadable,
    );
  }
  if (size > kDocumentMaxBytes) {
    return DocumentUploadValidation.failed(name, DocumentUploadIssue.tooLarge);
  }
  return DocumentUploadValidation.ok(name, size);
}

/// One warning to show for a batch's rejects: a localization key and its
/// params. Kept as data rather than a toast so a caller without a
/// `BuildContext` (`SharedFileIntake`) can render the same words.
typedef DocumentRejectNotice = ({String key, Map<String, String>? params});

/// The outcome of validating several files at once — what a picker, a drop,
/// or a share hands over.
class DocumentUploadBatch {
  const DocumentUploadBatch({
    required this.accepted,
    required this.rejected,
    required this.sawWrongType,
    required this.sawTooLarge,
  });

  final List<UploadSource> accepted;
  final List<UploadSource> rejected;

  /// A file of a type the server won't take — or one that couldn't be read,
  /// which reads the same to the user.
  final bool sawWrongType;
  final bool sawTooLarge;

  /// One notice per kind of reject, in a fixed order: the type warning, then
  /// the size one.
  List<DocumentRejectNotice> get rejectNotices => [
    if (sawWrongType) (key: 'dropzone_invalid_file_type', params: null),
    if (sawTooLarge)
      (key: 'upload_too_large_with_size', params: {'size': '$kDocumentMaxMb'}),
  ];
}

/// [validateDocumentUpload] over a batch, sorting the files into accepted and
/// rejected and noting which kinds of reject were seen — the loop every
/// upload surface used to repeat.
Future<DocumentUploadBatch> validateDocumentSources(
  Iterable<UploadSource> sources,
) async {
  final accepted = <UploadSource>[];
  final rejected = <UploadSource>[];
  var sawWrongType = false;
  var sawTooLarge = false;
  for (final source in sources) {
    final result = await validateDocumentUpload(source);
    switch (result.issue) {
      case null:
        accepted.add(source);
        continue;
      case DocumentUploadIssue.wrongExtension:
      case DocumentUploadIssue.unreadable:
        sawWrongType = true;
      case DocumentUploadIssue.tooLarge:
        sawTooLarge = true;
    }
    rejected.add(source);
  }
  return DocumentUploadBatch(
    accepted: accepted,
    rejected: rejected,
    sawWrongType: sawWrongType,
    sawTooLarge: sawTooLarge,
  );
}
