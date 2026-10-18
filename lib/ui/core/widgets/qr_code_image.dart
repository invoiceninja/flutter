import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';

/// A QR code drawn black on white inside a bordered white card, so it scans
/// whatever the theme — a dark-theme code on a dark card reads as noise to
/// most phone cameras.
///
/// The white quiet zone is the card's 8 px plus `QrImageView`'s own 10 —
/// scanners want about four modules of it, and a code on a dark theme has no
/// white page around it to borrow from.
///
/// An empty [data] (a server hiccup) draws a same-size placeholder, so the
/// layout doesn't jump when it arrives.
class QrCodeImage extends StatelessWidget {
  const QrCodeImage({
    required this.data,
    this.size = 220,
    this.semanticsLabel,
    super.key,
  });

  final String data;
  final double size;

  /// What a screen reader says. Defaults to `qr_code`; `qr_flutter`'s own
  /// default is a hard-coded English 'qr code'.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          border: Border.all(color: context.inTheme.border),
          borderRadius: BorderRadius.circular(InRadii.r2),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.qr_code, size: 64),
      );
    }
    return Container(
      padding: const EdgeInsets.all(InSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(InRadii.r2),
        border: Border.all(color: context.inTheme.border),
      ),
      // Force black-on-white so the code scans regardless of theme.
      child: QrImageView(
        data: data,
        version: QrVersions.auto,
        size: size,
        backgroundColor: Colors.white,
        semanticsLabel: semanticsLabel ?? context.tr('qr_code'),
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: Colors.black,
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Colors.black,
        ),
      ),
    );
  }
}
