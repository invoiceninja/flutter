import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/repositories/docuninja/docuninja_session.dart';
import 'package:admin/domain/docuninja/docuninja_create.dart';
import 'package:admin/domain/docuninja/docuninja_embed.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/dialogs/discard_changes_dialog.dart';
import 'package:admin/ui/core/unsaved_changes/unsaved_changes_scope.dart';
import 'package:admin/ui/core/utils/external_url.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/features/docuninja/view_models/docuninja_builder_view_model.dart';
import 'package:admin/ui/features/docuninja/widgets/docuninja_builder_link.dart';

/// Clears what the embedded builder's web view stored, at sign-out. A no-op
/// where the builder is never embedded. The web view store is the
/// platform's default one, so this clears every origin in it, which is only
/// the web app (the template preview loads its HTML without an origin).
Future<void> clearDocuNinjaWebStorage() async {
  if (!kDnEmbeddedBuilder || !dnEmbedSupported) return;
  try {
    await WebViewController().clearLocalStorage();
  } on Object {
    // No web view implementation (a test): nothing was stored either.
  }
}

/// React's field builder for one document (`/docuninja/:id/builder`), in a
/// web view: the hosted web app's own builder page in embed mode
/// (docs/docuninja.md § The field builder runs embedded where a web view
/// can). The app draws the title and Back; the page draws the builder and
/// its Send / Save for later buttons.
class DocuNinjaBuilderScreen extends StatefulWidget {
  const DocuNinjaBuilderScreen({
    super.key,
    required this.id,
    this.template = false,
    this.fromTemplate = false,
    this.signInvitationId,
  });

  final String id;

  /// A template's builder (React's `BlueprintBuilder`), not a document's.
  final bool template;

  /// A document just made from a template: React starts its template tour
  /// and maps the template's signers.
  final bool fromTemplate;

  /// The user's own invitation to sign, on React's sign page, instead of a
  /// builder.
  final String? signInvitationId;

  /// Where the screen leaves to: the document, or the templates.
  String get exitRoute => template ? '/docuninja/templates' : '/docuninja/$id';

  @override
  State<DocuNinjaBuilderScreen> createState() => _DocuNinjaBuilderScreenState();
}

class _DocuNinjaBuilderScreenState extends State<DocuNinjaBuilderScreen> {
  WebViewController? _web;
  DocuNinjaBuilderViewModel? _vm;
  String? _companyId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_vm != null) return;
    final services = context.read<Services>();
    final session = context.read<DocuNinjaSession?>();
    _companyId = services.auth.session.value?.currentCompanyId;
    final companyId = _companyId;
    if (companyId == null) return;

    final web = WebViewController();
    final vm = DocuNinjaBuilderViewModel(
      runJavaScript: web.runJavaScript,
      currentUrl: web.currentUrl,
      token: () => services.auth.credentials.value?.token,
      onDocumentChanged: () => session?.markDocumentsChanged(),
      onClose: () {
        if (mounted) context.go(widget.exitRoute);
      },
      openExternal: launchExternalUri,
      // A page of the web app opens here, keeping this page's sign-in (the
      // browser has none).
      openInPlace: web.loadRequest,
    );
    web
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'InvoiceNinjaApp',
        onMessageReceived: (m) {
          if (mounted) unawaited(vm.handle(m.message));
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri != null && dnEmbedAllowed(uri)) {
              return NavigationDecision.navigate;
            }
            // The page's own frames (a file preview, an embedded viewer)
            // load where it put them; they never receive the token, which
            // goes only to the main frame on the web app's origin.
            if (!request.isMainFrame) return NavigationDecision.navigate;
            // Anything else (a help page, a payment page) opens in the
            // browser; the web view only ever shows the web app.
            if (uri != null &&
                request.isMainFrame &&
                (uri.scheme == 'https' || uri.scheme == 'http')) {
              launchExternalUri(uri);
            }
            return NavigationDecision.prevent;
          },
          onPageStarted: (_) => vm.pageStarted(),
          onWebResourceError: (error) {
            if (error.isForMainFrame ?? false) vm.loadFailed();
          },
        ),
      );
    _web = web;
    _vm = vm..start();
    _enableFileInputs(web);
    // A fresh page every time: no token or company left over from an
    // earlier visit (React keeps the DocuNinja token in localStorage).
    web.clearLocalStorage().whenComplete(() {
      if (!mounted) return;
      final sign = widget.signInvitationId;
      web.loadRequest(
        sign != null
            ? dnWebAppSignUri(
                documentId: widget.id,
                invitationId: sign,
                companyId: companyId,
                embed: true,
              )
            : dnEmbedBuilderUri(
                documentId: widget.id,
                companyId: companyId,
                template: widget.template,
                fromTemplate: widget.fromTemplate,
              ),
      );
    });
  }

  /// A file input in the builder (a document's files, an upload). iOS
  /// answers one itself; Android's web view needs the host to pick the
  /// files. macOS's web view plugin has no open-panel support, so a file
  /// input there does nothing (docs/docuninja.md).
  void _enableFileInputs(WebViewController web) {
    final platform = web.platform;
    if (platform is! AndroidWebViewController) return;
    platform.setOnShowFileSelector((params) async {
      final List<PlatformFile> files;
      if (params.mode == FileSelectorMode.openMultiple) {
        files = await FilePicker.pickFiles();
      } else {
        final one = await FilePicker.pickFile();
        files = [?one];
      }
      return [
        for (final f in files)
          if (f.path != null) Uri.file(f.path!).toString(),
      ];
    });
  }

  @override
  void dispose() {
    _web?.clearLocalStorage();
    _vm?.dispose();
    super.dispose();
  }

  /// What "open in the browser" does here: sign, or edit.
  String get _actionKey => widget.signInvitationId != null ? 'sign' : 'edit';

  String get _titleKey => widget.signInvitationId != null
      ? 'sign'
      : widget.template
      ? 'edit_template'
      : 'edit_document';

  Future<void> _openInBrowser() async {
    final companyId = _companyId;
    if (companyId == null) return;
    final sign = widget.signInvitationId;
    if (sign != null) {
      await openDocuNinjaSign(
        context,
        documentId: widget.id,
        invitationId: sign,
        companyId: companyId,
        embedded: false,
      );
      return;
    }
    await openDocuNinjaBuilder(
      context,
      documentId: widget.id,
      companyId: companyId,
      template: widget.template,
      fromTemplate: widget.fromTemplate,
      embedded: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = _vm;
    final web = _web;
    if (vm == null || web == null) return const SizedBox.shrink();
    return UnsavedChangesScope(
      isDirty: () => vm.isDirty,
      source: vm,
      onDiscard: vm.discard,
      child: ListenableBuilder(
        listenable: vm,
        builder: (context, _) => PopScope(
          canPop: !vm.isDirty,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            if (!await showDiscardChangesDialog(context)) return;
            vm.discard();
            if (context.mounted) context.go(widget.exitRoute);
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(context.tr(_titleKey)),
              actions: [
                IconButton(
                  icon: const Icon(Icons.open_in_new),
                  // Already in the editor: the button is the browser.
                  tooltip: context.tr('open_in_browser'),
                  onPressed: _openInBrowser,
                ),
              ],
            ),
            body: switch (vm.phase) {
              DnBuilderPhase.unavailable => EmptyState(
                icon: Icons.open_in_new,
                title: context.tr(_titleKey),
                subtitle: context.tr('docuninja_builder_unavailable'),
                action: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(64, 44),
                  ),
                  onPressed: _openInBrowser,
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: Text(context.tr(_actionKey)),
                ),
              ),
              // The page's own Send / Save sit at its bottom: clear of the
              // system navigation bar and a landscape notch.
              _ => SafeArea(
                top: false,
                child: Stack(
                  children: [
                    WebViewWidget(controller: web),
                    // Covered and inert until the builder is up: before the
                    // handshake the page would be the web app's sign-in.
                    // The opaque listener keeps every tap off the page
                    // under the cover; only the slow notice's own button
                    // takes one.
                    if (vm.phase == DnBuilderPhase.loading)
                      Positioned.fill(
                        child: Listener(
                          behavior: HitTestBehavior.opaque,
                          child: AbsorbPointer(
                            absorbing: !vm.isSlow,
                            child: ColoredBox(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              child: vm.isSlow
                                  // Still waiting, but a document the builder
                                  // cannot open never comes up: say so.
                                  ? EmptyState(
                                      icon: Icons.hourglass_empty,
                                      title: context.tr(_titleKey),
                                      subtitle: context.tr(
                                        'docuninja_builder_unavailable',
                                      ),
                                      action: FilledButton.icon(
                                        style: FilledButton.styleFrom(
                                          minimumSize: const Size(64, 44),
                                        ),
                                        onPressed: _openInBrowser,
                                        icon: const Icon(
                                          Icons.open_in_new,
                                          size: 18,
                                        ),
                                        label: Text(
                                          context.tr('open_in_browser'),
                                        ),
                                      ),
                                    )
                                  : const Center(
                                      child: CircularProgressIndicator(),
                                    ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            },
          ),
        ),
      ),
    );
  }
}
