import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

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
import 'package:admin/ui/features/docuninja/widgets/docuninja_embed_surface.dart';

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
  DnEmbedSurface? _web;
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

    // The view model and the surface need each other: the surface's events
    // go to the view model, and the view model drives the surface.
    late final DnEmbedSurface web;
    final vm = DocuNinjaBuilderViewModel(
      runJavaScript: (script) => web.runJavaScript(script),
      currentUrl: () => web.currentUrl(),
      token: () => services.auth.credentials.value?.token,
      onDocumentChanged: () => session?.markDocumentsChanged(),
      onClose: () {
        if (mounted) context.go(_exitRoute);
      },
      openExternal: launchExternalUri,
      // A page of the web app opens here, keeping this page's sign-in (the
      // browser has none).
      openInPlace: (uri) => web.load(uri),
    );
    web = DnEmbedSurface(
      DnEmbedEvents(
        onMessage: (raw) {
          if (mounted) unawaited(vm.handle(raw));
        },
        onPageStarted: vm.pageStarted,
        onLoadFailed: vm.loadFailed,
        openExternal: launchExternalUri,
      ),
    );
    _web = web;
    _vm = vm..start();
    final sign = widget.signInvitationId;
    unawaited(
      web.open(
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
      ),
    );
  }

  @override
  void dispose() {
    _web?.dispose();
    _vm?.dispose();
    super.dispose();
  }

  /// Where leaving goes. A template's builder that React's Use Template
  /// moved on to a new document's builder leaves to that document, not to
  /// the templates.
  String get _exitRoute {
    final loaded = _vm?.loadedDocumentId;
    if (widget.template && loaded != null && loaded != widget.id) {
      return '/docuninja/$loaded';
    }
    return widget.exitRoute;
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
            if (context.mounted) context.go(_exitRoute);
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
                    web.build(context),
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
