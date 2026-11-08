import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:admin/domain/docuninja/docuninja_create.dart';
import 'package:admin/domain/docuninja/docuninja_embed.dart';
import 'package:admin/ui/core/utils/external_url.dart';

/// Whether this platform can embed the builder: `webview_flutter` runs on
/// iOS, Android and macOS. Windows, Linux and the web open it in the
/// browser.
bool get dnEmbedSupported {
  if (kIsWeb) return false;
  return switch (defaultTargetPlatform) {
    TargetPlatform.iOS ||
    TargetPlatform.android ||
    TargetPlatform.macOS => true,
    _ => false,
  };
}

/// Opens React's field builder for [documentId] on [companyId]: embedded in
/// the app where a web view can and the embed is on ([kDnEmbeddedBuilder]),
/// else in the browser (`dnBuilderWebUri`). docs/docuninja.md § The field
/// builder opens in the browser for now. [embedded] false always takes the
/// browser (the embedded screen's own "open in browser"). Shows the
/// standard toast when the browser does not open.
Future<bool> openDocuNinjaBuilder(
  BuildContext context, {
  required String documentId,
  required String companyId,
  bool embedded = true,
}) async {
  if (embedded && kDnEmbeddedBuilder && dnEmbedSupported) {
    context.go('/docuninja/$documentId/builder');
    return true;
  }
  return openExternalUrl(
    context,
    dnBuilderWebUri(documentId: documentId, companyId: companyId).toString(),
  );
}
