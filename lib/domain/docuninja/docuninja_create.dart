/// Creating a DocuNinja document and opening its field builder, as React
/// does it (`pages/documents/create/Create.tsx`,
/// `common/components/DocumentCreationDropZone.tsx`). docs/docuninja.md.
library;

import 'dart:convert';
import 'dart:typed_data';

/// The file types React's drop zone accepts, by extension. React accepts
/// `image/jpeg` by MIME type, so a `.jpeg` file is accepted there too.
const kDnUploadExtensions = <String>[
  'pdf',
  'doc',
  'docx',
  'odt',
  'xls',
  'xlsx',
  'png',
  'jpg',
  'jpeg',
];

/// React's `getDocumentNameFromFile`: the file name without its extension,
/// dashes and underscores as spaces, each word capitalised. Like React's
/// `\b\w`, only ASCII letters and digits start a word.
String dnDocumentNameFromFile(
  String fileName, {
  String fallback = 'Untitled document',
}) {
  final base = fileName.replaceFirst(RegExp(r'\.[^/.]+$'), '').trim();
  if (base.isEmpty) return fallback;
  final spaced = base
      .replaceAll(RegExp(r'[-_]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (spaced.isEmpty) return fallback;
  return spaced.replaceAllMapped(
    RegExp(r'(^|[^A-Za-z0-9_])([A-Za-z0-9_])'),
    (m) => '${m[1]}${m[2]!.toUpperCase()}',
  );
}

/// The name a password-protected PDF is uploaded under: React appends the
/// password to the file name (`name.pdf|password`), which DocuNinja splits
/// off to open the file.
String dnProtectedFileName(String fileName, String password) =>
    '$fileName|$password';

/// Whether a PDF's bytes look password-protected: an encrypted PDF names an
/// `/Encrypt` dictionary in its trailer. [head] and [tail] are the start and
/// end of the file (the trailer is at the end, or at the start of a
/// linearised file). React asks pdf.js; this is the same answer without a
/// PDF parser.
bool dnLooksPasswordProtected(Uint8List head, Uint8List tail) {
  bool has(Uint8List bytes) => latin1
      .decode(bytes, allowInvalid: true)
      .contains(RegExp(r'/Encrypt\s*\d+\s+\d+\s+R|/Encrypt\s*<<'));
  return has(head) || has(tail);
}

/// The hosted web app, where the field builder runs until it is embedded
/// in the app. It uses the hash router (`/#/…`), like the referral link.
const kDnHostedWebAppUrl = 'https://app.invoicing.co';

/// React's builder for [documentId] in the browser. `?company=` makes a
/// fresh tab open on the right company (React's `resolveCompanyIndex`,
/// read once on load), so a user with several companies lands on the one
/// the document belongs to.
Uri dnBuilderWebUri({required String documentId, required String companyId}) =>
    Uri.parse(
      '$kDnHostedWebAppUrl/#/docuninja/'
      '${Uri.encodeComponent(documentId)}/builder'
      '?company=${Uri.encodeQueryComponent(companyId)}',
    );
