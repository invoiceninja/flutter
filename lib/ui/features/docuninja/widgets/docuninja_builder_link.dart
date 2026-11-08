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

/// The app's route for the embedded builder of a document, or of a
/// template when [template].
String dnBuilderRoute(
  String id, {
  bool template = false,
  bool fromTemplate = false,
}) => template
    ? '/docuninja/templates/$id/builder'
    : '/docuninja/$id/builder${fromTemplate ? '?from_template=true' : ''}';

/// Opens React's field builder for a document, or a template when
/// [template] ([fromTemplate]: a document just made from one), on
/// [companyId]: embedded in the app where a web view can and the embed is
/// on ([kDnEmbeddedBuilder]), else in the browser (`dnBuilderWebUri`).
/// docs/docuninja.md § The field builder opens in the browser for now.
/// [embedded] false always takes the browser (the embedded screen's own
/// "open in browser"). Shows the standard toast when the browser does not
/// open.
Future<bool> openDocuNinjaBuilder(
  BuildContext context, {
  required String documentId,
  required String companyId,
  bool template = false,
  bool fromTemplate = false,
  bool embedded = true,
}) async {
  if (embedded && kDnEmbeddedBuilder && dnEmbedSupported) {
    context.go(
      dnBuilderRoute(
        documentId,
        template: template,
        fromTemplate: fromTemplate,
      ),
    );
    return true;
  }
  return openExternalUrl(
    context,
    dnBuilderWebUri(
      documentId: documentId,
      companyId: companyId,
      template: template,
      fromTemplate: fromTemplate,
    ).toString(),
  );
}
