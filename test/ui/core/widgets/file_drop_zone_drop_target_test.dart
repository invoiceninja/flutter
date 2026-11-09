import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/services/upload_source.dart';
import 'package:admin/ui/core/widgets/file_drop_zone.dart';

/// `desktop_drop` hands a drop to every `DropTarget` whose bounds contain the
/// point. A zone the user cannot see — on a branch kept mounted offstage, or
/// under a dialog — must not take a file dropped on another one: DocuNinja's
/// zone creates a document from it at once.
void main() {
  Future<void> send(WidgetTester tester, String method, Object args) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'desktop_drop',
      const StandardMethodCodec().encodeMethodCall(MethodCall(method, args)),
      (_) {},
    );
    await tester.pump();
  }

  Future<void> dropAt(WidgetTester tester, Offset at) async {
    await send(tester, 'entered', [at.dx, at.dy]);
    await send(tester, 'updated', [at.dx, at.dy]);
    await send(tester, 'performOperation', ['/tmp/contract.pdf']);
    await tester.pump();
  }

  Widget zone(List<String> into, String name) => FileDropZone(
    allowedExtensions: const ['pdf'],
    onFiles: (List<UploadSource> files) async => into.add(name),
  );

  Widget app(Widget home) => MaterialApp(
    theme: ThemeData.light().copyWith(extensions: [InTheme.light]),
    home: Scaffold(body: home),
  );

  testWidgets('an offstage zone under the pointer does not take the drop', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final got = <String>[];
    await tester.pumpWidget(
      app(
        Stack(
          children: [
            // A branch the user left: laid out, offstage, tickers off.
            Offstage(
              child: TickerMode(enabled: false, child: zone(got, 'hidden')),
            ),
            zone(got, 'shown'),
          ],
        ),
      ),
    );
    final at = tester.getCenter(find.byType(FileDropZone).last);
    await dropAt(tester, at);
    expect(got, ['shown']);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('a zone under a dialog does not take a drop on the dialog', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final got = <String>[];
    await tester.pumpWidget(app(Center(child: zone(got, 'page'))));
    final context = tester.element(find.byType(FileDropZone));
    unawaited(
      showDialog<void>(
        context: context,
        builder: (_) =>
            Dialog(child: SizedBox(width: 400, child: zone(got, 'dialog'))),
      ),
    );
    await tester.pumpAndSettle();
    final at = tester.getCenter(find.byType(FileDropZone).last);
    await dropAt(tester, at);
    expect(got, ['dialog']);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}
