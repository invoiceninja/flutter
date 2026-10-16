import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// CI lint: nothing in the UI or domain layers reads a document's `url`.
///
/// The server's `DocumentTransformer.url` is `/api/v1/documents/{id}/download`,
/// an API route behind `token_auth`. Both document lists used to hand it to the
/// browser, which sends no `X-API-TOKEN`, so every document anyone tried to view
/// opened as `{"message":"Invalid token"}` (a beta report on an expense's PDF).
/// The bytes come through `DocumentsApi.download` now, and View / Download are
/// `lib/ui/core/detail/document_open_actions.dart` — see `docs/document-urls.md`.
///
/// No type information here, so the rule is keyed on what a regression would
/// look like: a `.url` read in a file that imports the `Document` model, or a
/// `.url` read off a `documents` list anywhere. Only the data layer (the model
/// itself and the repositories that round-trip it into Drift) may touch it.
void main() {
  test('lib/ui and lib/domain never read a Document url', () {
    final urlRead = RegExp(r'\.url\b');
    final offListRead = RegExp(r'\bdocuments\b[^;]*\.url\b');

    final offenders = <String>[];
    var importers = 0;

    for (final root in ['lib/ui', 'lib/domain']) {
      for (final file in Directory(root).listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        final source = file.readAsStringSync();
        final importsDocument = source.contains(
          'data/models/domain/document.dart',
        );
        if (importsDocument) importers++;
        final lines = source.split('\n');
        for (var i = 0; i < lines.length; i++) {
          final code = lines[i].trimLeft();
          // Prose that names the trap is the point of documenting it.
          if (code.startsWith('//') || code.startsWith('*')) continue;
          final hit = importsDocument
              ? urlRead.hasMatch(code)
              : offListRead.hasMatch(code);
          if (hit) offenders.add('${file.path}:${i + 1}: $code');
        }
      }
    }

    // 5 at the time of writing: the Documents tab and its builder, the shared
    // actions, the viewer, and rectify_invoice.
    expect(
      importers,
      greaterThanOrEqualTo(4),
      reason:
          'Only $importers files import the Document model — the scan is '
          'probably broken, so an empty offender list means nothing.',
    );
    expect(
      offenders,
      isEmpty,
      reason:
          "A document's url is a token-gated API route; a browser opening it "
          'gets {"message":"Invalid token"}. Use viewDocument / '
          'downloadDocument (document_open_actions.dart), which fetch through '
          'DocumentsApi.download. Found at:\n  ${offenders.join('\n  ')}',
    );
  });
}
