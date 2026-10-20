import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/ui/features/settings/views/advanced/client_portal/widgets/portal_url_display.dart';

import '../../../../../../_localization_helper.dart';

const _url = 'https://billing.example.com/client/login';

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    theme: buildInTheme(InTheme.light),
    localizationsDelegates: kTestLocalizationsDelegates,
    supportedLocales: kTestSupportedLocales,
    home: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  testWidgets('no QR button unless asked for', (tester) async {
    await _pump(tester, const PortalUrlDisplay(label: 'Login URL', url: _url));
    expect(find.byIcon(Icons.qr_code), findsNothing);
  });

  testWidgets('the QR button opens the code of the URL', (tester) async {
    await _pump(
      tester,
      const PortalUrlDisplay(label: 'Login URL', url: _url, showQrCode: true),
    );
    await tester.tap(find.byIcon(Icons.qr_code));
    await tester.pumpAndSettle();

    expect(find.byType(PortalUrlQrDialog), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('Download'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(PortalUrlQrDialog), findsNothing);
  });

  testWidgets('the downloaded PNG is opaque white around the code', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final bytes = await portalQrPng(_url, size: 200);
      final codec = await ui.instantiateImageCodec(bytes);
      final image = (await codec.getNextFrame()).image;
      // 200 px of code plus a 20 px quiet zone on each side.
      expect(image.width, 240);
      expect(image.height, 240);
      final rgba = (await image.toByteData())!;
      // The top-left pixel sits in the quiet zone: white, not transparent.
      expect(rgba.getUint32(0), 0xFFFFFFFF);
      image.dispose();
    });
  });
}
