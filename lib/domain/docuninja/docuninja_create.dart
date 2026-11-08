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

/// The hosted web app, where the field builder runs (in the browser, or
/// embedded in a web view: `docuninja_embed.dart`). It uses the hash router
/// (`/#/…`), like the referral link. `--dart-define=DOCUNINJA_WEB_APP_URL=…`
/// points it at a local build of the React app for testing.
const kDnHostedWebAppUrl = String.fromEnvironment(
  'DOCUNINJA_WEB_APP_URL',
  defaultValue: 'https://app.invoicing.co',
);

/// React's builder in the hosted web app, as a path and query under its
/// hash router: a document's (`docuninja/<id>/builder`, with
/// `from_template=true` for one just made from a template, which starts
/// React's template tour) or a template's (`docuninja/templates/<id>/edit`).
/// `?company=` makes a fresh tab open on the right company (React's
/// `resolveCompanyIndex`, read once on load).
Uri dnWebAppBuilderUri({
  required String id,
  required String companyId,
  bool template = false,
  bool fromTemplate = false,
  bool embed = false,
}) {
  final path = template
      ? 'docuninja/templates/${Uri.encodeComponent(id)}/edit'
      : 'docuninja/${Uri.encodeComponent(id)}/builder';
  final query = [
    'company=${Uri.encodeQueryComponent(companyId)}',
    if (fromTemplate && !template) 'from_template=true',
    if (embed) 'embed=1',
  ].join('&');
  return Uri.parse('$kDnHostedWebAppUrl/#/$path?$query');
}

/// React's builder for [documentId] in the browser ([dnWebAppBuilderUri]).
Uri dnBuilderWebUri({
  required String documentId,
  required String companyId,
  bool template = false,
  bool fromTemplate = false,
}) => dnWebAppBuilderUri(
  id: documentId,
  companyId: companyId,
  template: template,
  fromTemplate: fromTemplate,
);
