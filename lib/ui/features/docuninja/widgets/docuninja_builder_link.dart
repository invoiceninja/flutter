import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:admin/domain/docuninja/docuninja_create.dart';
import 'package:admin/domain/docuninja/docuninja_embed.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/utils/external_url.dart';
import 'package:admin/ui/core/widgets/notify.dart';

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

/// After an await (an upload, a clone, a new template): the [message]
/// toast, then the builder. On the web the browser tab can't be opened
/// from here: `window.open` outside the tap's user activation is blocked,
/// silently (url_launcher opens with `noopener`, so it can't tell). There
/// the toast carries an Edit button instead, whose tap is a fresh
/// activation. docs/docuninja.md § On the web a builder opened after an
/// await is a toast button.
void notifyAndOpenDocuNinjaBuilder(
  BuildContext context, {
  required String message,
  required String documentId,
  required String companyId,
  bool template = false,
  bool fromTemplate = false,
}) {
  // The root navigator's context outlives the caller's page, which a
  // `go` to the new document may already have replaced by the time the
  // toast's button is tapped (Use Template does).
  final host = Navigator.of(context, rootNavigator: true).context;
  void open() {
    if (!host.mounted) return;
    openDocuNinjaBuilder(
      host,
      documentId: documentId,
      companyId: companyId,
      template: template,
      fromTemplate: fromTemplate,
    );
  }

  if (kIsWeb && !(kDnEmbeddedBuilder && dnEmbedSupported)) {
    Notify.success(
      context,
      message,
      action: NotifyAction(context.tr('edit'), open),
    );
    return;
  }
  Notify.success(context, message);
  open();
}

/// Opens React's sign page for the user's own invitation: embedded where
/// the builder is, else in the browser (`dnWebAppSignUri`).
Future<bool> openDocuNinjaSign(
  BuildContext context, {
  required String documentId,
  required String invitationId,
  required String companyId,
  bool embedded = true,
}) async {
  if (embedded && kDnEmbeddedBuilder && dnEmbedSupported) {
    context.go('/docuninja/$documentId/sign/$invitationId');
    return true;
  }
  return openExternalUrl(
    context,
    dnWebAppSignUri(
      documentId: documentId,
      invitationId: invitationId,
      companyId: companyId,
    ).toString(),
  );
}
