import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every file name the app hands to a platform — `printing`'s share sheet or
/// `FilePicker.saveFile` — must go through `sanitizeFileName`, because an illegal
/// character there is **silent**.
///
/// `printing`'s four native share implementations each concatenate the name onto
/// a temp directory and swallow the write failure — macOS/iOS
/// `catch { print(…); return }`, Android `catch (IOException e) {
/// e.printStackTrace(); }`, Windows an unchecked `ofstream` followed by a
/// `ShellExecute` on a path that was never written. So the user gets no share
/// sheet, no file, no error: a Share/Download button that does nothing.
///
/// Two producers make this reachable with no unusual data at all:
///
///  * a **document number**, whose pattern is a company setting, so
///    `INV/2026/0001` is an ordinary European numbering scheme;
///  * a **saved-version timestamp** on the History tab, rendered through the
///    company's `date_format_id` — `/`-separated on four of the fourteen formats
///    including the server's own default (`dd/MMM/yyyy`), and `:`-separated on
///    all of them.
///
/// Scanned rather than exercised because the widget tests deliberately keep
/// `PdfPreview` from instantiating (it needs the engine rasterizer), so nothing
/// that runs can see the property. A source scan is what the repo uses for the
/// same reason elsewhere — see `focus_owner_wiring_test.dart`.
///
/// **Extension-agnostic on purpose.** The first version of this test gated on
/// `.pdf'`, and the identical bug sat seventeen lines below the fix it was
/// guarding: the e-purchase-order export builds the same name with `.xml` and
/// hands it to `FilePicker.saveFile`. A rule about file names cannot be keyed on
/// one extension.
void main() {
  /// `//` tails stripped, so a comment that merely *names* the helper cannot
  /// satisfy the scan — the same precaution `device_prefs_wiring_test.dart`
  /// takes, and one the first version of this file was missing.
  String stripComments(String source) => source
      .split('\n')
      .map((l) {
        final i = l.indexOf('//');
        return i == -1 ? l : l.substring(0, i);
      })
      .join('\n');

  /// The opt-out, same shape as `field_input_types_test`'s
  /// `// lint: allow-input-type`. For a name whose interpolations cannot carry an
  /// illegal character — an epoch stamp, an enum name — where sanitising would be
  /// pure noise. It must carry a reason.
  const optOut = 'lint: allow-raw-file-name';

  /// A string literal ending in one of the extensions the app writes.
  ///
  /// Matched as a *suffix* plus a separate "does this statement interpolate
  /// anything" test, rather than as one whole-literal pattern: a sanitised name
  /// is `'\${sanitizeFileName('invoice_\${…}')}.pdf'`, whose nested single quotes
  /// no `[^']*` can cross. The first attempt at this test used the whole-literal
  /// form and silently matched 3 of the 14 sites — the floor below is what caught
  /// that, which is the whole reason it is there.
  final extEnding = RegExp(r"\.(pdf|xml|csv|json|zip|png)'");

  final offenders = <String>[];
  var scanned = 0;
  var interpolated = 0;

  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    if (entity.path.endsWith('.g.dart') ||
        entity.path.endsWith('.freezed.dart')) {
      continue;
    }
    final raw = entity.readAsStringSync();
    if (!extEnding.hasMatch(stripComments(raw))) continue;
    scanned++;
    // Statement-wise, so a name built across several lines is judged as one
    // expression. Split on the RAW source so the opt-out comment travels with
    // its statement; the name literal and the helper are looked for in the
    // comment-stripped form of the same chunk.
    for (final statement in raw.split(';')) {
      final body = stripComments(statement);
      // A constant name (`'design_preview.pdf'`) needs nothing.
      if (!extEnding.hasMatch(body) || !body.contains(r'${')) continue;
      // A bundled asset path is not a file this app writes.
      if (body.contains("'assets/")) continue;
      interpolated++;
      if (body.contains('sanitizeFileName')) continue;
      if (statement.contains(optOut)) continue;
      offenders.add('${entity.path}: ${body.trim().split('\n').last.trim()}');
    }
  }

  test('the scan actually reached the file-name sites', () {
    // Without this the test passes vacuously the day the directory moves or the
    // literal shape changes.
    expect(scanned, greaterThanOrEqualTo(25), reason: 'files naming a file');
    expect(
      interpolated,
      greaterThanOrEqualTo(14),
      reason:
          'interpolated file names — 14 at the time of writing: the shared '
          'billing-doc pane, the client statement, the download action for each '
          'of invoice / quote / credit / purchase order / recurring invoice, the '
          'bulk-list action for each of invoice / quote / credit / purchase '
          'order, and the e-purchase-order .xml export. Names whose '
          'interpolations cannot carry an illegal character opt out with '
          '`$optOut` and are counted here too',
    );
  });

  test('every interpolated file name is sanitized', () {
    expect(
      offenders,
      isEmpty,
      reason:
          'these build a file name from a document number or a formatted date '
          'without sanitizeFileName, so Share / Download / Save silently does '
          'nothing for any company whose numbering or date format contains one '
          r'of / \ : * ? " < > | :'
          '\n${offenders.join('\n')}',
    );
  });
}
