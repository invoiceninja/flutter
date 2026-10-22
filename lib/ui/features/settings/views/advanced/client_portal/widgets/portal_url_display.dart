import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/utils/external_url.dart';
import 'package:admin/ui/core/utils/save_bytes.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/core/widgets/qr_code_image.dart';
import 'package:admin/utils/file_names.dart';

/// Below this pane width the action buttons move under the URL.
const double _kStackedBelow = 480;

/// Read-only computed URL row. Used by the Client Portal Settings tab to
/// surface the Login URL and by the Registration tab for the Registration
/// URL. Renders the URL as selectable text with trailing icon buttons:
/// copy-to-clipboard, open-in-new-tab, and (opt-in) a QR code.
///
/// The URL is computed by the caller — this widget is purely presentation.
class PortalUrlDisplay extends StatelessWidget {
  const PortalUrlDisplay({
    super.key,
    required this.label,
    required this.url,
    this.showQrCode = false,
    this.qrCodeAfterSync = false,
  });

  /// Localized label shown above the URL (e.g. `t('login_url')`).
  final String label;

  /// Fully-formed URL — caller decides hosted-subdomain vs hosted-domain
  /// vs self-hosted shape.
  final String url;

  /// Adds a button that shows the URL as a scannable, downloadable QR code —
  /// what a user prints on a business card or a flyer.
  final bool showQrCode;

  /// Says, under the URL, that its QR code appears once the changes are
  /// saved and synced. Set instead of [showQrCode] while the URL is a preview
  /// of the draft — see [ConfirmedPortalUrlDisplay].
  final bool qrCodeAfterSync;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(color: tokens.ink2),
        ),
        SizedBox(height: InSpacing.xs),
        // Three buttons beside a long URL leave a phone a column a few
        // characters wide, so a narrow pane puts them under it instead.
        LayoutBuilder(
          builder: (context, constraints) {
            final link = Row(
              children: [
                Icon(Icons.link, color: tokens.ink2),
                SizedBox(width: InSpacing.md(context)),
                Expanded(
                  child: SelectableText(
                    url,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: tokens.ink,
                    ),
                  ),
                ),
              ],
            );
            final actions = [
              IconButton(
                icon: const Icon(Icons.content_copy),
                tooltip: context.tr('copy'),
                onPressed: () => _copy(context),
              ),
              IconButton(
                icon: const Icon(Icons.open_in_new),
                tooltip: context.tr('open'),
                onPressed: () => _open(context),
              ),
              if (showQrCode)
                IconButton(
                  icon: const Icon(Icons.qr_code),
                  tooltip: context.tr('qr_code'),
                  onPressed: () => _showQrCode(context),
                ),
            ];
            if (constraints.maxWidth < _kStackedBelow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  link,
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: actions,
                  ),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: link),
                ...actions,
              ],
            );
          },
        ),
        if (qrCodeAfterSync)
          Text(
            context.tr('portal_qr_code_after_sync'),
            style: theme.textTheme.bodySmall?.copyWith(color: tokens.ink2),
          ),
      ],
    );
  }

  Future<void> _copy(BuildContext context) async {
    final copiedText = context
        .tr('copied_to_clipboard')
        .replaceAll(':value', url);
    await Clipboard.setData(ClipboardData(text: url));
    if (!context.mounted) return;
    Notify.success(context, copiedText);
  }

  Future<void> _open(BuildContext context) async {
    await openExternalUrl(context, url);
  }

  Future<void> _showQrCode(BuildContext context) => showDialog<void>(
    context: context,
    builder: (_) => PortalUrlQrDialog(label: label, url: url),
  );
}

/// The QR code of a portal URL, with the URL under it and a Download that
/// saves it as a PNG.
class PortalUrlQrDialog extends StatelessWidget {
  const PortalUrlQrDialog({super.key, required this.label, required this.url});

  static const double _qrSize = 220;

  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(label),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // AlertDialog measures its content's intrinsic size, and
          // QrImageView lays out through a LayoutBuilder, which can't report
          // one. A tight box answers for it: the code plus QrCodeImage's 8 px
          // padding and 1 px border on each side.
          SizedBox.square(
            dimension: _qrSize + 2 * (InSpacing.sm + 1),
            child: QrCodeImage(data: url, size: _qrSize),
          ),
          SizedBox(height: InSpacing.md(context)),
          SelectableText(
            url,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: context.inTheme.ink2,
            ),
          ),
        ],
      ),
      actions: [
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
          icon: const Icon(Icons.download),
          label: Text(context.tr('download')),
          onPressed: () => _download(context),
        ),
        PrimaryDialogAction(
          label: context.tr('close'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Future<void> _download(BuildContext context) async {
    final save = bytesSaver(context);
    final bytes = await portalQrPng(url);
    await save(
      fileName: '${sanitizeFileName('$label QR', fallback: 'qr_code')}.png',
      bytes: bytes,
    );
  }
}

/// [url] as a print-ready PNG: black modules on an opaque white square with
/// a four-module quiet zone. `QrPainter.toImageData` alone paints on
/// transparency with no margin, which most scanners refuse once it sits on a
/// dark or busy background.
Future<Uint8List> portalQrPng(String url, {double size = 1024}) async {
  final painter = QrPainter(
    data: url,
    version: QrVersions.auto,
    gapless: true,
    eyeStyle: const QrEyeStyle(
      eyeShape: QrEyeShape.square,
      color: Colors.black,
    ),
    dataModuleStyle: const QrDataModuleStyle(
      dataModuleShape: QrDataModuleShape.square,
      color: Colors.black,
    ),
  );
  final quiet = size / 10;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)
    ..drawRect(
      Rect.fromLTWH(0, 0, size + quiet * 2, size + quiet * 2),
      Paint()..color = Colors.white,
    )
    ..translate(quiet, quiet);
  painter.paint(canvas, Size.square(size));
  final side = (size + quiet * 2).round();
  final image = await recorder.endRecording().toImage(side, side);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

/// Says the portal is switched off, above the URLs that would otherwise look
/// live: the server still lets a client log in, then shows every page as
/// "disabled by the administrator".
class PortalDisabledNotice extends StatelessWidget {
  const PortalDisabledNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Container(
      padding: EdgeInsets.all(InSpacing.md(context)),
      decoration: BoxDecoration(
        color: tokens.warningSoft,
        borderRadius: BorderRadius.circular(InRadii.r2),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: tokens.warning),
          SizedBox(width: InSpacing.md(context)),
          Expanded(
            child: Text(
              context.tr('client_portal_disabled_links'),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: tokens.ink),
            ),
          ),
        ],
      ),
    );
  }
}
