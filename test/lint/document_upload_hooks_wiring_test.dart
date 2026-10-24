import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every document upload — an entity's, and the company's — hands its file to
/// the `SharedIntakeFiles` hooks: `resolveSource` before it is sent, and
/// `onUploaded` after.
///
/// Structural, because a dropped line compiles, runs and uploads fine. What
/// it breaks is invisible: a photo taken on a phone's Documents tab, or a
/// receipt shared into the app, is the app's own copy in `shared_intake/`
/// (`docs/sharing-files-into-the-app.md`). Without `onUploaded` that copy —
/// personal data — stays on the device until a later launch's sweep; without
/// `resolveSource` an upload queued offline dead-letters once an iOS update
/// moves the data container. The hooks were wired for expenses only while
/// shares were the folder's only tenant, and nothing noticed when the camera
/// made every record's Documents tab one.
void main() {
  String codeOf(String path) => File(path)
      .readAsStringSync()
      .split('\n')
      .map((l) {
        final i = l.indexOf('//');
        return i < 0 ? l : l.substring(0, i);
      })
      .join('\n');

  test('every documentMutationHandlers call passes both intake hooks', () {
    final src = codeOf('lib/app/services_entity_wiring.dart');
    final calls = RegExp(r'documentMutationHandlers<\w+>\(').allMatches(src);
    expect(calls, isNotEmpty);
    for (final call in calls) {
      // The call's own argument list: up to its closing `)`.
      var depth = 0;
      var end = call.end - 1;
      for (var i = call.end - 1; i < src.length; i++) {
        if (src[i] == '(') depth++;
        if (src[i] == ')' && --depth == 0) {
          end = i;
          break;
        }
      }
      final args = src.substring(call.start, end);
      final name = call.group(0);
      expect(
        args,
        contains('onUploaded: reg.ctx.onDocumentUploaded'),
        reason: '$name has no onUploaded hook',
      );
      expect(
        args,
        contains('resolveSource: reg.ctx.resolveDocumentSource'),
        reason: '$name has no resolveSource hook',
      );
    }
  });

  test('the company dispatcher passes both intake hooks', () {
    final src = codeOf('lib/app/services.dart');
    final at = src.indexOf('CompanySyncDispatcher(');
    expect(at, isNonNegative);
    final args = src.substring(at, src.indexOf('),', at));
    expect(args, contains('onDocumentUploaded: onDocumentUploaded'));
    expect(args, contains('resolveDocumentSource: sharedIntakeFiles.resolve'));
  });
}
