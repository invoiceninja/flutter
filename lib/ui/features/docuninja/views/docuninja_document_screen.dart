import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/entity_links.dart';
import 'package:admin/app/env.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/docuninja/dn_models.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/repositories/docuninja/docuninja_session.dart';
import 'package:admin/data/services/docuninja/docuninja_api.dart';
import 'package:admin/data/services/docuninja/docuninja_client.dart';
import 'package:admin/domain/docuninja/docuninja_access.dart';
import 'package:admin/domain/docuninja/docuninja_create.dart';
import 'package:admin/domain/docuninja/docuninja_permissions.dart';
import 'package:admin/domain/docuninja/docuninja_send_rules.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/copy_entity_link.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/detail/entity_quick_actions.dart';
import 'package:admin/ui/core/detail/record_timestamps.dart';
import 'package:admin/ui/core/dialogs/confirm_action_dialog.dart';
import 'package:admin/ui/core/list/entity_actions_popup_button.dart';
import 'package:admin/ui/core/list/entity_list_constants.dart';
import 'package:admin/ui/core/widgets/app_selection_area.dart';
import 'package:admin/ui/core/widgets/copyable_value.dart';
import 'package:admin/ui/core/widgets/dashed_border.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/core/widgets/error_view.dart';
import 'package:admin/ui/core/widgets/form_save_scope.dart';
import 'package:admin/ui/core/widgets/in_date_field.dart';
import 'package:admin/ui/core/widgets/ltr_value.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/core/widgets/status_pill.dart';
import 'package:admin/ui/features/docuninja/view_models/docuninja_document_view_model.dart';
import 'package:admin/ui/features/docuninja/widgets/docuninja_builder_link.dart';
import 'package:admin/ui/features/docuninja/widgets/docuninja_documents_list.dart';
import 'package:admin/ui/features/docuninja/widgets/docuninja_download.dart';
import 'package:admin/ui/features/docuninja/widgets/docuninja_return_refresh.dart';
import 'package:admin/ui/features/docuninja/widgets/docuninja_inline_error.dart';
import 'package:admin/ui/features/docuninja/widgets/docuninja_states.dart';
import 'package:admin/ui/features/docuninja/widgets/docuninja_status_pill.dart';
import 'package:admin/utils/bidi.dart';
import 'package:admin/utils/formatting.dart';

/// One DocuNinja document (`/docuninja/:id`), as React's `show/Document.tsx`
/// lays it out: the title with its status, the signers beside the timeline,
/// and the actions in React's order (docs/docuninja.md).
///
/// Edit opens the field builder (embedded where it can be, else in the
/// browser), and Clone to Template the template builder.
class DocuNinjaDocumentScreen extends StatefulWidget {
  const DocuNinjaDocumentScreen({super.key, required this.id});

  final String id;

  @override
  State<DocuNinjaDocumentScreen> createState() =>
      _DocuNinjaDocumentScreenState();
}

enum _Action {
  edit,
  sign,
  viewPdf,
  send,
  auditLog,
  download,
  clone,
  makeTemplate,
  copyLink,
  voidIt,
  options,
  archive,
  restore,
  delete,
}

class _DocuNinjaDocumentScreenState extends State<DocuNinjaDocumentScreen> {
  DocuNinjaDocumentViewModel? _vm;
  Formatter? _formatter;
  bool _downloading = false;

  /// The builder runs in the browser for now: re-read the document when the
  /// user comes back to the app, so fields placed there show up here.
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = dnRefreshOnReturn(() => _vm?.load());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_vm != null) return;
    final api = context.read<DocuNinjaApi?>();
    if (api != null) {
      // The client runs the handshake first when it has no token yet (a
      // document opened on a cold start, before the list screen loaded it).
      _vm = DocuNinjaDocumentViewModel(api: api, id: widget.id)..load();
    }
    // DocuNinja's live updates (a signature landed): re-read, as React's
    // detail page refetches on `DocumentWasSigned`.
    _remote = context.read<DocuNinjaSession?>()?.remoteChanged
      ?..addListener(_onRemote);
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId;
    if (companyId != null) {
      services.formatterFor(companyId).then((f) {
        if (mounted) setState(() => _formatter = f);
      });
    }
  }

  ValueNotifier<int>? _remote;

  void _onRemote() => _vm?.load();

  @override
  void dispose() {
    _remote?.removeListener(_onRemote);
    _lifecycle.dispose();
    _vm?.dispose();
    super.dispose();
  }

  /// The signed-in DocuNinja user's own invitation, still to sign.
  DnInvitation? _ownInvitation(DnDocument doc) => dnOwnInvitation(
    doc,
    context.read<DocuNinjaSession?>()?.value.login?.user.id ?? '',
  );

  /// Tells the list it came from to re-read DocuNinja.
  void _changed() => context.read<DocuNinjaSession?>()?.markDocumentsChanged();

  bool _sendable(DnDocument doc) {
    final me = context.read<Services>().auth.session.value?.currentCompany;
    return dnIsSendable(
      document: doc,
      isAdminOrOwner: (me?.isAdmin ?? false) || (me?.isOwner ?? false),
      requiresApproval: me?.can('requires_approval') ?? false,
      canEdit: me?.can('edit_documents') ?? false,
      canCreate: me?.can('create_documents') ?? false,
      // React compares DocuNinja's `user_id` with the Invoice Ninja user id,
      // which never match (docs/docuninja.md).
      isDocumentOwner: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = _vm;
    if (vm == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        final doc = vm.document;
        final items = doc == null ? null : _items(context, vm, doc);
        return Scaffold(
          appBar: AppBar(
            // On a phone the body's heading already shows the (often long)
            // name: the bar says what the page is instead of repeating it.
            title: Text(
              doc == null || isPhoneRecordLayout(context)
                  ? context.tr('document')
                  : _title(context, doc),
            ),
            actions: [if (items != null) ..._appBarActions(context, items)],
          ),
          body: _body(context, vm, doc, items),
        );
      },
    );
  }

  /// Edit beside the `⋮`. Where the builder opens in the browser it says so
  /// (`open_in_new`, "Edit in browser"): the shared split button always
  /// draws the circled pencil, which read as an in-app editor and then left
  /// the app without a word.
  List<Widget> _appBarActions(
    BuildContext context,
    List<EntityActionItem<_Action>> items,
  ) {
    if (!dnBuilderOpensExternally()) {
      return [
        EntityActionsPopupButton<_Action>(items: items, splitEditAction: true),
      ];
    }
    final edit = findActionItem(items, _Action.edit);
    // `EntityActionsPopupButton`'s own sizing, so the pair matches it.
    final side = actionButtonSize();
    return [
      if (edit != null) ...[
        IconButton(
          icon: Icon(edit.icon),
          tooltip: edit.label,
          style: IconButton.styleFrom(
            fixedSize: Size(side, side),
            minimumSize: Size.zero,
            maximumSize: Size.infinite,
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onPressed: edit.enabled ? guardedOnTap(context, edit) : null,
        ),
        const SizedBox(width: kColActionsClusterGap),
      ],
      EntityActionsPopupButton<_Action>(
        items: [
          for (final i in items)
            if (i.kind != _Action.edit) i,
        ],
      ),
    ];
  }

  /// A phone's tiles for what a user most often does here, in this order;
  /// each one is the `⋮` menu's own item (docs/detail-screen-layout.md § A
  /// quick-action tile is a second render of an existing action).
  List<EntityQuickAction<_Action>> _quickActions(
    BuildContext context,
    List<EntityActionItem<_Action>> items,
    DnDocument doc,
  ) {
    EntityQuickAction<_Action>? tile(
      _Action kind, {
      String? shortKey,
      bool applies = true,
    }) {
      final item = findActionItem(items, kind);
      if (item == null) return null;
      return EntityQuickAction<_Action>(
        item: item,
        shortLabel: shortKey == null ? item.label : context.tr(shortKey),
        applies: applies,
      );
    }

    return [
      ?tile(_Action.send, shortKey: 'send'),
      ?tile(_Action.sign, shortKey: dnSignLabelKey()),
      ?tile(_Action.viewPdf, shortKey: 'view_pdf'),
      ?tile(_Action.copyLink),
      ?tile(_Action.download, shortKey: 'download'),
      // Disabled once completed or voided: a tile that cannot run yields
      // its slot; the `⋮` still shows it greyed.
      // Labelled as the action is ("Edit in browser" while it leaves the
      // app), and yielded while the Place signature fields card already
      // offers the same step — four ways to one browser was three too many.
      ?tile(
        _Action.edit,
        shortKey: dnBuilderEditLabelKey(),
        applies:
            !dnIsCompleted(doc) &&
            doc.status != DnDocumentStatus.voided &&
            !(dnDeferBuilderOnPhone() && dnNeedsFields(doc)),
      ),
    ];
  }

  /// "Created … · Updated …", muted under the title; null until the
  /// company's date format has loaded.
  String? _datesLine(BuildContext context, DnDocument doc) {
    final created = dnLocalDate(_formatter, doc.createdAt);
    final updated = dnLocalDate(_formatter, doc.updatedAt);
    final parts = [
      if (created.isNotEmpty) context.tr('created_short', {'date': created}),
      if (updated.isNotEmpty && updated != created)
        context.tr('updated_short', {'date': updated}),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  Widget _body(
    BuildContext context,
    DocuNinjaDocumentViewModel vm,
    DnDocument? doc,
    List<EntityActionItem<_Action>>? items,
  ) {
    if (doc == null) {
      if (vm.isLoading) {
        return const Center(child: CircularProgressIndicator());
      }
      if (vm.isOffline) {
        return EmptyState(
          icon: Icons.cloud_off_outlined,
          title: context.tr('offline'),
          action: TextButton(
            onPressed: vm.load,
            child: Text(context.tr('retry')),
          ),
        );
      }
      if (vm.isNoAccess) {
        return DocuNinjaGoHomeState(
          access:
              context.read<DocuNinjaSession?>()?.value.access ??
              DocuNinjaAccess.failed,
        );
      }
      if (vm.isForbidden) {
        return EmptyState(
          icon: Icons.lock_outline,
          title: context.tr('unauthorized_action'),
        );
      }
      if (vm.isMissing) {
        return EmptyState(
          icon: Icons.draw_outlined,
          title: context.tr('document_not_found'),
        );
      }
      return ErrorView(
        message: context.tr('an_error_occurred_try_again'),
        onRetry: vm.load,
      );
    }
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    final actions = items ?? const <EntityActionItem<_Action>>[];
    final phone = isPhoneRecordLayout(context);
    final edit = findActionItem(actions, _Action.edit);
    final dates = _datesLine(context, doc);
    final signers = _Invitations(
      document: doc,
      formatter: _formatter,
      busy: vm.isBusy,
      onResend: (i) => _resend(context, vm, i),
      // The builder, so it needs what Edit needs.
      onAddSignatories:
          doc.isDeleted ||
              dnIsCompleted(doc) ||
              doc.status == DnDocumentStatus.voided ||
              !(context.read<DocuNinjaSession?>()?.value.can(
                    'documents',
                    DnAction.edit,
                  ) ??
                  true)
          ? null
          : () => _onAction(context, vm, doc, _Action.edit),
    );
    final timeline = _Timeline(entries: vm.timeline, formatter: _formatter);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: InSpacing.sm,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Semantics(
              header: true,
              headingLevel: 1,
              child: Text(
                _title(context, doc),
                style: theme.textTheme.titleLarge,
              ),
            ),
            // React shows Deleted / Archived beside the status. Only when
            // there is one: the Wrap spaces even a zero-size child.
            if (doc.isDeleted || doc.isArchived)
              DocuNinjaLifecyclePill(document: doc),
            DocuNinjaStatusPill(document: doc, statusOnly: true),
          ],
        ),
        if (dates != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              dates,
              // ink2: at 12 px ink3 is under the 4.5:1 floor.
              style: TextStyle(color: tokens.ink2, fontSize: 12),
            ),
          ),
        // The action worked but the re-read did not (or a pull to refresh
        // failed): what's shown may be stale.
        if (vm.error != null && !vm.isLoading)
          DocuNinjaInlineError(offline: vm.isOffline, onRetry: vm.load),
        if (vm.isBusy || _downloading)
          const Padding(
            padding: EdgeInsets.only(top: InSpacing.sm),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        SizedBox(height: InSpacing.lg(context)),
        // A phone's main actions as tiles, from the menu's own items; the
        // strip owns its trailing gap and draws nothing when none applies.
        if (phone)
          EntityQuickActions<_Action>(
            priority: _quickActions(context, actions, doc),
          ),
        // Where the builder would leave the app, a document still waiting
        // for its fields says how to go on rather than launching a browser
        // after the upload (the list lands here instead).
        if (edit != null && dnDeferBuilderOnPhone() && dnNeedsFields(doc)) ...[
          _PlaceFieldsCard(
            onOpen: edit.enabled ? guardedOnTap(context, edit) : null,
          ),
          SizedBox(height: InSpacing.lg(context)),
        ],
        LayoutBuilder(
          builder: (context, c) => c.maxWidth >= 760
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: signers),
                    SizedBox(width: InSpacing.lg(context)),
                    Expanded(flex: 3, child: timeline),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    signers,
                    SizedBox(height: InSpacing.lg(context)),
                    timeline,
                  ],
                ),
        ),
      ],
    );
    final pad = InSpacing.lg(context);
    return AppSelectionArea(
      child: RefreshIndicator(
        onRefresh: vm.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          // A ListView given a padding no longer adds the home indicator's
          // inset itself. Read here, it is zero wherever something above
          // has already taken it (a SafeArea strips it), so never doubled.
          padding: EdgeInsets.symmetric(horizontal: pad).copyWith(
            top: pad,
            bottom: pad + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                // On a phone the page is flush: a card inside the page's own
                // inset cost every line ~25 px a side.
                child: phone
                    ? content
                    : DecoratedBox(
                        decoration: BoxDecoration(
                          color: tokens.surface,
                          border: Border.all(color: tokens.border),
                          borderRadius: BorderRadius.circular(InRadii.r3),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(pad),
                          child: content,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// React's actions (`useActions.tsx` and the detail page), in its order,
  /// offered where they apply.
  List<EntityActionItem<_Action>> _items(
    BuildContext context,
    DocuNinjaDocumentViewModel vm,
    DnDocument doc,
  ) {
    final idle = !vm.isBusy && !_downloading;
    final completed = dnIsCompleted(doc);
    final title = _title(context, doc);
    // DocuNinja's own role (React offers every action and lets DocuNinja
    // refuse it with an error): what this user may not do is not offered.
    // Send keeps React's Invoice Ninja permission check (`_sendable`).
    // With no session to ask (none provided), DocuNinja decides, as React
    // always lets it.
    final session = context.read<DocuNinjaSession?>()?.value;
    bool can(String model, DnAction action) =>
        session?.can(model, action) ?? true;
    final canEdit = can('documents', DnAction.edit);
    EntityActionItem<_Action> item(
      _Action kind,
      IconData icon,
      String key, {
      bool confirm = false,
      String? confirmMessageKey,
      bool destructive = false,
      bool lifecycle = false,
      bool primary = false,
      bool enabled = true,
    }) => EntityActionItem<_Action>(
      kind: kind,
      icon: icon,
      label: context.tr(key),
      enabled: idle && enabled,
      isPrimary: primary,
      isEdit: kind == _Action.edit,
      confirm: confirm,
      confirmMessageKey: confirmMessageKey,
      isDestructive: destructive,
      isLifecycle: lifecycle,
      confirmSubject: title,
      onTap: () => _onAction(context, vm, doc, kind),
    );
    return [
      // React's Edit (the field builder): beside the menu, disabled once the
      // document is completed or voided. Where it opens in the browser it
      // says so, so leaving the app is no surprise.
      if (!doc.isDeleted && canEdit)
        item(
          _Action.edit,
          dnBuilderEditIcon(),
          dnBuilderEditLabelKey(),
          primary: true,
          enabled: !completed && doc.status != DnDocumentStatus.voided,
        ),
      // React's Sign (its builder's): the user's own invitation, on React's
      // sign page (docs/docuninja.md § Signing your own invitation).
      if (_ownInvitation(doc) != null)
        item(_Action.sign, Icons.draw_outlined, dnSignLabelKey()),
      // React's `shouldShowPdf`: completed, not deleted, and with a file.
      if (completed && !doc.isDeleted && doc.files.isNotEmpty)
        item(_Action.viewPdf, Icons.picture_as_pdf_outlined, 'view_pdf'),
      if (_sendable(doc) && doc.invitations.isNotEmpty)
        item(_Action.send, Icons.send_outlined, 'send'),
      if (completed)
        item(_Action.auditLog, Icons.fact_check_outlined, 'audit_log'),
      if (completed)
        item(_Action.download, Icons.download_outlined, 'download'),
      // Unlike the app's other Clones (an unsaved edit screen), this creates
      // the copy on DocuNinja at once, so it confirms as React's does.
      if (!doc.isDeleted && can('documents', DnAction.create))
        item(
          _Action.clone,
          Icons.copy_outlined,
          'clone',
          confirm: true,
          confirmMessageKey: 'clone_document_description',
        ),
      // React's Clone to Template: a template from this document, opened in
      // the template builder. It creates the template at once, so it asks.
      if (!doc.isDeleted && can('blueprints', DnAction.create))
        item(
          _Action.makeTemplate,
          Icons.copy_all_outlined,
          'clone_to_template',
          confirm: true,
        ),
      // The app's Share / Copy Internal Link (every record has one): opens this
      // document in the app, on its company (`buildDocuNinjaDeepLink`).
      EntityActionItem<_Action>(
        kind: _Action.copyLink,
        icon: Icons.link,
        label: context.tr(
          Env.isTouchPrimary ? 'share_internal_link' : 'copy_internal_link',
        ),
        enabled: true,
        onTap: () => _onAction(context, vm, doc, _Action.copyLink),
      ),
      if (dnCanVoid(doc) && canEdit)
        item(
          _Action.voidIt,
          Icons.block_outlined,
          'void',
          confirm: true,
          destructive: true,
        ),
      if (!doc.isDeleted && canEdit)
        item(_Action.options, Icons.tune_outlined, 'options'),
      if (!doc.isArchived && !doc.isDeleted && canEdit)
        item(
          _Action.archive,
          Icons.archive_outlined,
          'archive',
          confirm: true,
          confirmMessageKey: 'archive_document_description',
          lifecycle: true,
        ),
      if ((doc.isArchived || doc.isDeleted) && canEdit)
        item(
          _Action.restore,
          Icons.restore_outlined,
          'restore',
          lifecycle: true,
        ),
      if (!doc.isDeleted && can('documents', DnAction.delete))
        item(
          _Action.delete,
          Icons.delete_outline,
          'delete',
          confirm: true,
          destructive: true,
          lifecycle: true,
        ),
    ];
  }

  Future<void> _onAction(
    BuildContext context,
    DocuNinjaDocumentViewModel vm,
    DnDocument doc,
    _Action action,
  ) async {
    final title = _title(context, doc);
    switch (action) {
      case _Action.edit:
        final companyId = context
            .read<Services>()
            .auth
            .session
            .value
            ?.currentCompanyId;
        if (companyId == null) return;
        await openDocuNinjaBuilder(
          context,
          documentId: doc.id,
          companyId: companyId,
        );
      case _Action.sign:
        final invitation = _ownInvitation(doc);
        final companyId = context
            .read<Services>()
            .auth
            .session
            .value
            ?.currentCompanyId;
        if (invitation == null || companyId == null) return;
        await openDocuNinjaSign(
          context,
          documentId: doc.id,
          invitationId: invitation.id,
          companyId: companyId,
        );
      case _Action.viewPdf:
        context.go('/docuninja/${doc.id}/pdf');
      case _Action.send:
        if (!await _confirmSend(context, doc.invitations)) return;
        final ok = await vm.send();
        if (!context.mounted) return;
        _report(context, ok, 'document_queued_for_sending');
      case _Action.auditLog:
        await _save(context, vm.auditLog, '${title}_audit_log');
      case _Action.download:
        await _save(context, vm.download, title);
      case _Action.clone:
        final id = await vm.clone();
        if (!context.mounted) return;
        if (id == null) {
          // A copy may exist all the same (a timed-out clone): the list
          // re-reads.
          _changed();
          Notify.error(context, context.tr('an_error_occurred_try_again'));
        } else {
          _changed();
          Notify.success(context, context.tr('cloned_document'));
          context.go('/docuninja/$id');
        }
      case _Action.makeTemplate:
        final companyId = context
            .read<Services>()
            .auth
            .session
            .value
            ?.currentCompanyId;
        final templateId = await vm.makeTemplate();
        if (!context.mounted) return;
        if (templateId == null || companyId == null) {
          _changed();
          Notify.error(context, context.tr('an_error_occurred_try_again'));
          return;
        }
        notifyAndOpenDocuNinjaBuilder(
          context,
          message: context.tr('template_created'),
          documentId: templateId,
          companyId: companyId,
          template: true,
        );
      case _Action.copyLink:
        final session = context.read<Services>().auth.session.value;
        final link = buildDocuNinjaDeepLink(
          documentId: doc.id,
          companyId: session?.currentCompanyId ?? '',
          baseUrl: session?.baseUrl,
        );
        if (link == null) {
          Notify.error(context, context.tr('an_error_occurred'));
          return;
        }
        await shareOrCopyLink(
          context,
          link,
          label: context.tr('internal_link'),
        );
      case _Action.voidIt:
        final ok = await vm.voidDocument();
        if (!context.mounted) return;
        _report(context, ok, 'voided_document');
      case _Action.options:
        await _options(context, vm, doc);
      case _Action.archive:
        final ok = await vm.archive();
        if (!context.mounted) return;
        _report(context, ok, 'document_archived');
      case _Action.restore:
        final ok = await vm.restore();
        if (!context.mounted) return;
        _report(context, ok, 'document_restored');
      case _Action.delete:
        // Like React, the page stays, now showing the document deleted.
        final ok = await vm.delete();
        if (!context.mounted) return;
        _report(context, ok, 'deleted_document');
    }
  }

  void _report(BuildContext context, bool ok, String successKey) {
    if (ok) {
      _changed();
      Notify.success(context, context.tr(successKey));
    } else {
      // It may have landed all the same (a timed-out void): the list
      // re-reads, as this page already has.
      _changed();
      Notify.error(context, context.tr('an_error_occurred_try_again'));
    }
  }

  /// The signed PDF or the audit log, under the name DocuNinja gives it
  /// (`dnSaveFile`); one at a time.
  Future<void> _save(
    BuildContext context,
    Future<DnFileBytes> Function() fetch,
    String fallbackName,
  ) async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      await dnSaveFile(context, fetch: fetch, fallbackName: fallbackName);
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  /// React's send dialogs (`SendInvitationsModal.tsx` for the document,
  /// `Invitations.tsx` for one signer): who will be emailed, one line each in
  /// React's `- Name (email)` form, in the order DocuNinja lists them.
  /// Outward-facing, so the primary is not autofocused.
  Future<bool> _confirmSend(
    BuildContext context,
    List<DnInvitation> invitations,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        // One line per signer: long lists scroll instead of overflowing.
        scrollable: true,
        title: Text(context.tr('send_confirmation')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr('send_emails_to_following')),
            const SizedBox(height: InSpacing.sm),
            for (final i in invitations)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                // A dialog is outside the page's selection area, so the
                // email can be an isolate inside the line.
                child: Text('- ${_recipient(i)}'),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('cancel')),
          ),
          PrimaryDialogAction(
            label: context.tr('send'),
            autofocus: false,
            showEnterHint: false,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _resend(
    BuildContext context,
    DocuNinjaDocumentViewModel vm,
    DnInvitation invitation,
  ) async {
    // React's per-signer Send Email: the same question, naming that one
    // recipient.
    if (!await _confirmSend(context, [invitation])) return;
    if (!context.mounted) return;
    final ok = await vm.send(only: invitation);
    if (!context.mounted) return;
    _report(context, ok, 'document_queued_for_sending');
  }

  /// React's Options modal (`DocumentSettingsModal.tsx`): the description,
  /// and the expiry until the document is sent. It saves itself and stays
  /// open on a refusal, so the user's edit is never lost.
  Future<void> _options(
    BuildContext context,
    DocuNinjaDocumentViewModel vm,
    DnDocument doc,
  ) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) =>
          _OptionsDialog(document: doc, formatter: _formatter, vm: vm),
    );
    if (saved != true || !context.mounted) return;
    _changed();
    Notify.success(context, context.tr('updated_settings'));
  }
}

String _title(BuildContext context, DnDocument doc) =>
    doc.description.isEmpty ? context.tr('untitled_document') : doc.description;

/// Whether [doc] still waits for its fields to be placed: a draft with no
/// signers yet, or with signers but no field on any page. Past draft (sent,
/// in approval, finished) the builder is not the next step; a draft that has
/// both is ready to send, which its Send tile offers.
@visibleForTesting
bool dnNeedsFields(DnDocument doc) =>
    !doc.isDeleted &&
    doc.status == DnDocumentStatus.draft &&
    (doc.invitations.isEmpty || doc.files.every((f) => f.rectangles.isEmpty));

/// "Place signature fields": the way on from a new document where the
/// builder opens in the browser (a phone or tablet), instead of leaving the
/// app straight after the upload. Runs the same Edit action.
class _PlaceFieldsCard extends StatelessWidget {
  const _PlaceFieldsCard({required this.onOpen});

  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border.all(color: tokens.border),
        borderRadius: BorderRadius.circular(InRadii.r3),
      ),
      child: Padding(
        padding: EdgeInsets.all(InSpacing.lg(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              headingLevel: 2,
              child: Text(
                context.tr('docuninja_place_fields'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.tr('docuninja_place_fields_help'),
              style: TextStyle(color: tokens.ink2, fontSize: 13),
            ),
            SizedBox(height: InSpacing.md(context)),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
              onPressed: onOpen,
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(context.tr('open_in_browser')),
            ),
          ],
        ),
      ),
    );
  }
}

/// One recipient as React's send dialogs write it (`getRecipient`):
/// `Name (email)`, or the email alone when there is no name. The email is
/// isolated left-to-right; only for text outside the selectable page.
String _recipient(DnInvitation i) {
  final name = i.signerName;
  final email = i.signerEmail.isEmpty ? '' : ltrIsolate(i.signerEmail);
  if (name.isEmpty) return email;
  return email.isEmpty ? name : '$name ($email)';
}

/// React's `Invitations.tsx`: a card per signer, in the order DocuNinja
/// lists them, with a status, where they are, React's Copy Link and Send
/// Email; with none, React's dashed box into the builder.
class _Invitations extends StatelessWidget {
  const _Invitations({
    required this.document,
    required this.formatter,
    required this.busy,
    required this.onResend,
    this.onAddSignatories,
  });

  final DnDocument document;
  final Formatter? formatter;
  final bool busy;
  final ValueChanged<DnInvitation> onResend;

  /// React's empty box is a way into the builder; null where the builder
  /// cannot open (a completed, voided or deleted document).
  final VoidCallback? onAddSignatories;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = document.invitations;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          headingLevel: 2,
          child: Text(
            context.tr('signatories'),
            style: theme.textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: InSpacing.sm),
        if (rows.isEmpty)
          _AddSignatoriesBox(onTap: onAddSignatories)
        else
          for (var n = 0; n < rows.length; n++) ...[
            if (n > 0) const SizedBox(height: 16),
            _SignerCard(
              document: document,
              invitation: rows[n],
              formatter: formatter,
              busy: busy,
              onResend: onResend,
            ),
          ],
      ],
    );
  }
}

/// React's empty signers box: a dashed box with a plus, the whole of it a
/// way into the builder. Dimmed, and not a button, where the builder cannot
/// open.
class _AddSignatoriesBox extends StatelessWidget {
  const _AddSignatoriesBox({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final enabled = onTap != null;
    final ink = enabled ? tokens.ink2 : tokens.ink4;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(InRadii.r1),
    );
    return DashedBorder(
      color: tokens.borderStrong,
      radius: InRadii.r1,
      child: Material(
        color: tokens.surface,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          child: Semantics(
            button: enabled,
            enabled: enabled,
            child: SizedBox(
              height: 160,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 32, color: ink),
                    const SizedBox(height: 16),
                    Text(
                      context.tr('add_signatories'),
                      style: TextStyle(color: ink),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One signer as React's card shows them: the name and status, who they are
/// on whose side, where they are, then Copy Link and Send Email until the
/// document is finished.
class _SignerCard extends StatelessWidget {
  const _SignerCard({
    required this.document,
    required this.invitation,
    required this.formatter,
    required this.busy,
    required this.onResend,
  });

  final DnDocument document;
  final DnInvitation invitation;
  final Formatter? formatter;
  final bool busy;
  final ValueChanged<DnInvitation> onResend;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final i = invitation;
    final showResend = dnShowsResend(document);
    final label = context.tr(
      i.clientContactId.isNotEmpty ? 'client_contact' : 'user',
    );
    final line = TextStyle(color: tokens.ink2, fontSize: 13);
    // React's per-signer Copy Link: the web app's sign page for this signer
    // (behind its sign-in), for a signer linked to a contact or user, until
    // the document is finished. It copies on every platform: the link is
    // for the team, and a share sheet beside a client's name invites
    // sending it to a client who would meet a sign-in wall.
    final copyLink =
        showResend && (i.clientContactId.isNotEmpty || i.userId.isNotEmpty);
    final name = i.signerName.isNotEmpty
        ? i.signerName
        : i.signerEmail.isNotEmpty
        ? i.signerEmail
        : label;
    // With a signing order only the next unsigned signer can be emailed;
    // the others say why rather than show a button that does nothing.
    final waiting = !dnCanResend(document, i) && i.signedDate == null;
    // The dashes in `borderStrong` all but vanish on a dark surface.
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SizedBox(
          width: double.infinity,
          child: DashedBorder(
            color: dark ? tokens.ink4 : tokens.borderStrong,
            radius: InRadii.r1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: dark ? tokens.surfaceAlt : tokens.surface,
                borderRadius: BorderRadius.circular(InRadii.r1),
              ),
              child: Padding(
                // A phone's page is flush, and this inset is the card's own.
                padding: EdgeInsets.all(
                  isPhoneRecordLayout(context) ? InSpacing.md(context) : 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: LtrText(
                            name,
                            // A name may be Arabic or Hebrew; an email is not.
                            keepRtlScript: true,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: tokens.ink,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: InSpacing.sm),
                        // React's per-signer badge.
                        _SignerPill(invitation: i),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // React's "Client contact:" / "User:", as a caption: who
                    // on whose side is asked to sign. On its own line, so
                    // the email below keeps the card's whole width.
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: tokens.ink2, fontSize: 12),
                    ),
                    // Two lines, not an ellipsis: a cut email is a guess.
                    // Not twice when it is already the card's title.
                    if (i.signerEmail.isNotEmpty && i.signerEmail != name)
                      LtrText(
                        i.signerEmail,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: line,
                      ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 16,
                          color: tokens.ink3,
                        ),
                        const SizedBox(width: InSpacing.sm),
                        Expanded(
                          child: _StateLine(
                            invitation: i,
                            formatter: formatter,
                          ),
                        ),
                      ],
                    ),
                    if (showResend) ...[
                      const SizedBox(height: 12),
                      // A Wrap, so a large text scale puts Send Email on
                      // its own line instead of overflowing the card.
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        runSpacing: 4,
                        children: [
                          if (copyLink)
                            TextButton(
                              onPressed: () => copyToClipboard(
                                context,
                                dnWebAppSignLink(
                                  documentId: document.id,
                                  invitationId: i.id,
                                ).toString(),
                                label: context.tr('link'),
                              ),
                              child: Text(context.tr('copy_link')),
                            ),
                          if (waiting)
                            _WaitingNote(style: line)
                          // A signer who has signed has nothing to be sent:
                          // no greyed button that can never be pressed.
                          else if (i.signedDate == null ||
                              dnCanResend(document, i))
                            TextButton.icon(
                              onPressed: !busy && dnCanResend(document, i)
                                  ? () => onResend(i)
                                  : null,
                              icon: const Icon(Icons.send, size: 17),
                              label: Text(context.tr('send_email')),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Why a signer has no Send Email yet: someone earlier in the signing order
/// has still to sign.
class _WaitingNote extends StatelessWidget {
  const _WaitingNote({required this.style});

  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Level with the Copy Link button's label beside it.
      padding: const EdgeInsets.symmetric(vertical: InSpacing.sm),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hourglass_empty, size: 16, color: context.inTheme.ink3),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              context.tr('docuninja_waiting_for_earlier_signer'),
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}

/// React's badge for one signer: signed green, viewed yellow, sent blue,
/// pending neutral.
class _SignerPill extends StatelessWidget {
  const _SignerPill({required this.invitation});

  final DnInvitation invitation;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final (String key, Color fg, Color bg) = switch (invitation.state) {
      DnInvitationState.signed => ('signed', tokens.paid, tokens.paidSoft),
      DnInvitationState.viewed => (
        'viewed',
        tokens.warning,
        tokens.warningSoft,
      ),
      DnInvitationState.sent => ('sent', tokens.partial, tokens.partialSoft),
      DnInvitationState.pending => ('pending', tokens.ink3, tokens.draftSoft),
    };
    return StatusPill(
      label: context.tr(key),
      fgColor: fg,
      bgColor: bg,
      textStyle: TextStyle(fontSize: 12, color: tokens.ink),
    );
  }
}

/// React's status line under a signer: signed / viewed / sent with the
/// date, or created with the date while it waits. The date is its own
/// left-to-right run, not a direction mark inside the string, so a copy from
/// the selectable page carries no invisible characters.
class _StateLine extends StatelessWidget {
  const _StateLine({required this.invitation, required this.formatter});

  final DnInvitation invitation;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final i = invitation;
    final (key, at) = switch (i.state) {
      DnInvitationState.signed => ('signed', i.signedDate),
      DnInvitationState.viewed => ('viewed', i.viewedDate),
      DnInvitationState.sent => ('sent', i.sentDate),
      DnInvitationState.pending => ('created', '${i.raw['created_at'] ?? ''}'),
    };
    final on = dnLocalDate(formatter, at);
    final style = TextStyle(color: context.inTheme.ink2, fontSize: 13);
    if (on.isEmpty) return Text(context.tr(key), style: style);
    return Wrap(
      spacing: 4,
      children: [
        Text('${context.tr(key)}:', style: style),
        LtrText(on, style: style),
      ],
    );
  }
}

/// React's `TimelineLayout.tsx` / `Timeline.tsx`: a stepper, each step a dot
/// on a rail joined to the next (solid once the next step is done, dashed
/// until then), its title with a done / waiting badge, then what happened
/// and when.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.entries, required this.formatter});

  final List<DnTimelineEntry> entries;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          headingLevel: 2,
          child: Text(
            context.tr('timeline'),
            style: theme.textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: InSpacing.sm),
        for (var n = 0; n < entries.length; n++)
          _TimelineStep(
            entry: entries[n],
            formatter: formatter,
            // React's `nextItemCompleted`; no connector after the last step.
            next: n + 1 < entries.length
                ? (entries[n + 1].completed ? _Rail.solid : _Rail.dashed)
                : _Rail.none,
          ),
      ],
    );
  }
}

enum _Rail { none, solid, dashed }

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.entry,
    required this.formatter,
    required this.next,
  });

  final DnTimelineEntry entry;
  final Formatter? formatter;
  final _Rail next;

  /// The rail column's width, and the dot's centre from the step's top (the
  /// middle of the title's first line).
  static const double _railWidth = 24;
  static const double _dotY = 11;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final e = entry;
    final f = formatter;
    final done = e.completed;
    return CustomPaint(
      painter: _TimelineRailPainter(
        dot: done ? tokens.accent : tokens.ink3,
        halo: tokens.surface,
        line: tokens.borderStrong,
        rail: next,
        railWidth: _railWidth,
        dotY: _dotY,
        textDirection: Directionality.of(context),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: _railWidth + InSpacing.sm,
          bottom: next == _Rail.none ? 0 : 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: e.title,
                    style: TextStyle(
                      color: tokens.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const WidgetSpan(child: SizedBox(width: InSpacing.sm)),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Container(
                      width: 20,
                      height: 20,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: tokens.border, width: 2),
                      ),
                      child: Icon(
                        done ? Icons.check : Icons.access_time,
                        // The step's state, which the badge alone shows.
                        semanticLabel: context.tr(
                          done ? 'completed' : 'pending',
                        ),
                        size: 12,
                        color: done ? tokens.paid : tokens.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (e.description.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                e.description,
                style: TextStyle(color: tokens.ink2, fontSize: 13),
              ),
            ],
            // `YYYY-MM-DD HH:MM:SS` in UTC; the formatter shows it in local
            // time, in the company's date format.
            if (e.time.isNotEmpty && f != null)
              LtrText(
                f.date(e.time, showTime: true, showSeconds: false),
                style: TextStyle(color: tokens.ink3, fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }
}

/// A timeline step's rail: the connector down to the next step's dot, then
/// the dot over it, ringed in the card's colour. The connector runs past the
/// step's own bottom into the next step, whose dot paints over its end.
class _TimelineRailPainter extends CustomPainter {
  const _TimelineRailPainter({
    required this.dot,
    required this.halo,
    required this.line,
    required this.rail,
    required this.railWidth,
    required this.dotY,
    required this.textDirection,
  });

  final Color dot;
  final Color halo;
  final Color line;
  final _Rail rail;
  final double railWidth;
  final double dotY;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    // The rail column sits at the start edge.
    final x = textDirection == TextDirection.rtl
        ? size.width - railWidth / 2
        : railWidth / 2;
    final from = Offset(x, dotY);
    final to = Offset(x, size.height + dotY);
    final stroke = Paint()
      ..color = line
      ..strokeWidth = 2;
    switch (rail) {
      case _Rail.none:
        break;
      case _Rail.solid:
        canvas.drawLine(from, to, stroke);
      case _Rail.dashed:
        const dash = 4.0;
        const gap = 3.0;
        for (var y = from.dy; y < to.dy; y += dash + gap) {
          canvas.drawLine(
            Offset(x, y),
            Offset(x, (y + dash).clamp(y, to.dy)),
            stroke,
          );
        }
    }
    canvas
      ..drawCircle(from, 8, Paint()..color = halo)
      ..drawCircle(from, 5, Paint()..color = dot);
  }

  @override
  bool shouldRepaint(_TimelineRailPainter old) =>
      old.dot != dot ||
      old.halo != halo ||
      old.line != line ||
      old.rail != rail ||
      old.railWidth != railWidth ||
      old.dotY != dotY ||
      old.textDirection != textDirection;
}

class _OptionsDialog extends StatefulWidget {
  const _OptionsDialog({
    required this.document,
    required this.formatter,
    required this.vm,
  });

  final DnDocument document;
  final Formatter? formatter;
  final DocuNinjaDocumentViewModel vm;

  @override
  State<_OptionsDialog> createState() => _OptionsDialogState();
}

class _OptionsDialogState extends State<_OptionsDialog> {
  late final _description = TextEditingController(
    text: widget.document.description,
  );

  /// The expiry's calendar day as DocuNinja stores it (the time part is not
  /// the user's), so an untouched field is never sent shifted a day.
  late final DateTime? _stored = _day(widget.document.expiresAt);
  late DateTime? _expires = _stored;
  bool _saving = false;
  String? _descriptionError;
  String? _expiryError;

  static DateTime? _day(String? iso) {
    final d = Date.tryParse(
      iso != null && iso.length >= 10 ? iso.substring(0, 10) : null,
    );
    return d == null ? null : DateTime(d.year, d.month, d.day);
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    // A date typed into the expiry field is taken on blur, and on a phone
    // tapping Save does not blur it: commit it first, or Save drops it
    // (`EntityEditScaffold._runSave` does the same).
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(Duration.zero);
    if (!mounted || _saving) return;
    final expiryChanged =
        dnCanSetExpiry(widget.document) && _expires != _stored;
    setState(() {
      _saving = true;
      _descriptionError = null;
      _expiryError = null;
    });
    final expires = _expires;
    final error = await widget.vm.saveSettings(
      description: _description.text.trim(),
      setExpiry: expiryChanged,
      expiresAt: expires == null
          ? null
          : Date(expires.year, expires.month, expires.day).toIso(),
    );
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _saving = false;
      if (error is DocuNinjaException) {
        _descriptionError = error.fieldErrors['description']?.first;
        _expiryError = error.fieldErrors['expires_at']?.first;
      }
    });
    if (_descriptionError == null && _expiryError == null) {
      Notify.error(context, context.tr('an_error_occurred_try_again'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final canExpire = dnCanSetExpiry(widget.document);
    // Not dismissed mid-save (barrier, Escape, Android back): the answer
    // would land with no dialog to show it, and a refusal's field errors
    // and the user's edit would be lost.
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        // Scrolls in a short landscape window with the keyboard up.
        scrollable: true,
        title: Text(context.tr('options')),
        content: SizedBox(
          width: 480,
          child: FormSaveScope(
            onSubmit: _save,
            enabled: !_saving,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _description,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: context.tr('description'),
                    errorText: _descriptionError,
                  ),
                  onSubmitted: (_) => _save(),
                ),
                if (canExpire) ...[
                  const SizedBox(height: InSpacing.sm),
                  InDateField(
                    value: _expires,
                    formatter: widget.formatter,
                    labelText: context.tr('expiry_date'),
                    clearable: true,
                    errorText: _expiryError,
                    onChanged: (d) => setState(() => _expires = d),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(false),
            child: Text(context.tr('cancel')),
          ),
          PrimaryDialogAction(
            label: context.tr('save'),
            // The description field holds the focus.
            autofocus: false,
            busy: _saving,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}
