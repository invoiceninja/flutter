import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// CI lint: a desktop download is written into the downloads folder, never
/// handed to `printing`'s share (docs/file-downloads.md).
///
/// `Printing.sharePdf` does something different on each desktop, and none of
/// it saves a file the user can find: Windows writes the PDF to `%TEMP%` and
/// `ShellExecute`s it, Linux writes `/tmp/<name>` and `xdg-open`s it, macOS
/// shows a share picker. A beta tester's "Download PDF just launches the PDF"
/// was every Download PDF action calling it. So:
///
///  * `Printing.sharePdf` appears only behind `downloadPdf` (save_bytes.dart),
///    which takes the downloads folder on desktop and the share elsewhere;
///  * every `PdfPreview` gates `allowSharing` on `pdfShareOpensTempCopy()` —
///    the package's built-in Share button calls the same `sharePdf`, inside
///    the package, where the first check cannot see it.
void main() {
  String stripComments(String source) => source
      .split('\n')
      .map((l) {
        final i = l.indexOf('//');
        return i == -1 ? l : l.substring(0, i);
      })
      .join('\n');

  const helper = 'lib/ui/core/utils/save_bytes.dart';

  final sharePdfCalls = <String>[];
  final ungatedPreviews = <String>[];
  var scannedLines = 0;
  var previews = 0;

  for (final file in Directory('lib').listSync(recursive: true)) {
    if (file is! File || !file.path.endsWith('.dart')) continue;
    final source = stripComments(file.readAsStringSync());
    scannedLines += '\n'.allMatches(source).length;

    if (file.path != helper) {
      final lines = source.split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains('Printing.sharePdf')) {
          sharePdfCalls.add('${file.path}:${i + 1}');
        }
      }
    }

    // A `PdfPreview(` constructor call runs to the end of its statement; the
    // gate has to be an argument inside it.
    for (final match in RegExp(r'\bPdfPreview\(').allMatches(source)) {
      previews++;
      final rest = source.substring(match.start);
      final end = rest.indexOf(';');
      final call = end == -1 ? rest : rest.substring(0, end);
      final sharing = RegExp(r'allowSharing:[^,)]*').firstMatch(call);
      if (sharing == null ||
          !sharing.group(0)!.contains('pdfShareOpensTempCopy(')) {
        final line = '\n'.allMatches(source.substring(0, match.start)).length;
        ungatedPreviews.add('${file.path}:${line + 1}');
      }
    }
  }

  test('the scan actually walked lib/', () {
    expect(scannedLines, greaterThan(10000));
    expect(
      previews,
      greaterThanOrEqualTo(6),
      reason:
          'PdfPreview sites — 6 at the time of writing: the billing-doc pane, '
          'the client statement, the document viewer and the three design '
          'previews',
    );
  });

  test('Printing.sharePdf is reached only through downloadPdf', () {
    expect(
      sharePdfCalls,
      isEmpty,
      reason:
          'on Windows / Linux Printing.sharePdf only opens a temp copy. Use '
          'downloadPdf ($helper) for a download:\n'
          '  ${sharePdfCalls.join('\n  ')}',
    );
  });

  test('every PdfPreview hides Share where it opens a temp copy', () {
    expect(
      ungatedPreviews,
      isEmpty,
      reason:
          'pass allowSharing: … !pdfShareOpensTempCopy() (save_download.dart) '
          '— the package Share button calls Printing.sharePdf:\n'
          '  ${ungatedPreviews.join('\n  ')}',
    );
  });
}
