import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/repositories/docuninja/docuninja_session.dart';
import 'package:admin/domain/docuninja/docuninja_embed.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/dialogs/discard_changes_dialog.dart';
import 'package:admin/ui/core/unsaved_changes/unsaved_changes_scope.dart';
import 'package:admin/ui/core/utils/external_url.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/features/docuninja/view_models/docuninja_builder_view_model.dart';
import 'package:admin/ui/features/docuninja/widgets/docuninja_builder_link.dart';

/// React's field builder for one document (`/docuninja/:id/builder`), in a
/// web view: the hosted web app's own builder page in embed mode
/// (docs/docuninja.md § The field builder runs embedded where a web view
/// can). The app draws the title and Back; the page draws the builder and
/// its Send / Save for later buttons.
class DocuNinjaBuilderScreen extends StatefulWidget {
  const DocuNinjaBuilderScreen({super.key, required this.id});

  final String id;

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
        if (mounted) context.go('/docuninja/${widget.id}');
      },
      openExternal: launchExternalUri,
    );
    web
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'InvoiceNinjaApp',
        onMessageReceived: (m) => vm.handle(m.message),
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri != null && dnEmbedAllowed(uri)) {
              return NavigationDecision.navigate;
            }
            // Anything else (a help page, a payment page) opens in the
            // browser; the web view only ever shows the web app.
            if (uri != null &&
                request.isMainFrame &&
                (uri.scheme == 'https' || uri.scheme == 'http')) {
              launchExternalUri(uri);
            }
            return NavigationDecision.prevent;
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame ?? false) vm.loadFailed();
          },
        ),
      );
    _web = web;
    _vm = vm..start();
    // A fresh page every time: no token or company left over from an
    // earlier visit (React keeps the DocuNinja token in localStorage).
    web.clearLocalStorage().whenComplete(() {
      if (!mounted) return;
      web.loadRequest(
        dnEmbedBuilderUri(documentId: widget.id, companyId: companyId),
      );
    });
  }

  @override
  void dispose() {
    _web?.clearLocalStorage();
    _vm?.dispose();
    super.dispose();
  }

  Future<void> _openInBrowser() async {
    final companyId = _companyId;
    if (companyId == null) return;
    await openDocuNinjaBuilder(
      context,
      documentId: widget.id,
      companyId: companyId,
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
            if (context.mounted) context.go('/docuninja/${widget.id}');
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(context.tr('edit_document')),
              actions: [
                IconButton(
                  icon: const Icon(Icons.open_in_new),
                  tooltip: context.tr('edit'),
                  onPressed: _openInBrowser,
                ),
              ],
            ),
            body: switch (vm.phase) {
              DnBuilderPhase.unavailable => EmptyState(
                icon: Icons.open_in_new,
                title: context.tr('edit_document'),
                action: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(64, 44),
                  ),
                  onPressed: _openInBrowser,
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: Text(context.tr('edit')),
                ),
              ),
              _ => Stack(
                children: [
                  WebViewWidget(controller: web),
                  if (vm.phase == DnBuilderPhase.loading)
                    const Center(child: CircularProgressIndicator()),
                ],
              ),
            },
          ),
        ),
      ),
    );
  }
}
