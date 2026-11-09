import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:admin/app/env.dart';
import 'package:admin/domain/docuninja/docuninja_create.dart';
import 'package:admin/domain/docuninja/docuninja_embed.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/utils/external_url.dart';
import 'package:admin/ui/core/widgets/notify.dart';

/// Whether this platform can embed the builder: `webview_flutter` on iOS,
/// Android and macOS, WebView2 on Windows (docs/windows-web-view.md). Linux
/// and the web open it in the browser.
bool get dnEmbedSupported {
  if (kIsWeb) return false;
  return switch (defaultTargetPlatform) {
    TargetPlatform.iOS ||
    TargetPlatform.android ||
    TargetPlatform.macOS ||
    TargetPlatform.windows => true,
    _ => false,
  };
}

/// Whether the field builder opens outside the app here: the embed is off
/// ([kDnEmbeddedBuilder]) or this platform has no web view for it
/// ([dnEmbedSupported]), so [openDocuNinjaBuilder] takes the browser.
bool dnBuilderOpensExternally() => !(kDnEmbeddedBuilder && dnEmbedSupported);

/// Whether a create on this device should NOT launch the builder at once: a
/// phone whose builder would open in the browser. Leaving the app straight
/// after an upload strands the user in a browser tab, so the document
/// screen offers the builder instead (a "Place signature fields" card).
/// docs/docuninja.md.
bool dnDeferBuilderOnPhone() => Env.isMobile && dnBuilderOpensExternally();

/// Every Edit that opens the builder says where it goes: `open_in_new` and
/// "Edit in browser" while the builder opens externally, so no tap leaves
/// the app without warning (docs/docuninja.md § On a phone).
IconData dnBuilderEditIcon() =>
    dnBuilderOpensExternally() ? Icons.open_in_new : Icons.edit_outlined;

String dnBuilderEditLabelKey() =>
    dnBuilderOpensExternally() ? 'edit_in_browser' : 'edit';

/// Sign, the same way: React's sign page opens in the browser unless the
/// builder is embedded.
String dnSignLabelKey() =>
    dnBuilderOpensExternally() ? 'sign_in_browser' : 'sign';

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

  // The web can't open a tab here (above), and a phone must not be thrown
  // out to the browser by a save: in both the builder is the toast's
  // button, the user's own choice to leave (docs/docuninja.md § On a phone).
  if ((kIsWeb || Env.isMobile) && dnBuilderOpensExternally()) {
    Notify.success(
      context,
      message,
      action: NotifyAction(
        context.tr(Env.isMobile ? 'edit_in_browser' : 'edit'),
        open,
      ),
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
