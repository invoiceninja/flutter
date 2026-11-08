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
import 'package:admin/domain/docuninja/docuninja_send_rules.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/copy_entity_link.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/dialogs/confirm_action_dialog.dart';
import 'package:admin/ui/core/list/entity_actions_popup_button.dart';
import 'package:admin/ui/core/utils/save_bytes.dart';
import 'package:admin/ui/core/widgets/app_selection_area.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/core/widgets/error_view.dart';
import 'package:admin/ui/core/widgets/form_save_scope.dart';
import 'package:admin/ui/core/widgets/in_date_field.dart';
import 'package:admin/ui/core/widgets/ltr_value.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/features/docuninja/view_models/docuninja_document_view_model.dart';
import 'package:admin/ui/features/docuninja/widgets/docuninja_builder_link.dart';
import 'package:admin/ui/features/docuninja/widgets/docuninja_documents_list.dart';
import 'package:admin/ui/features/docuninja/widgets/docuninja_inline_error.dart';
import 'package:admin/ui/features/docuninja/widgets/docuninja_status_pill.dart';
import 'package:admin/utils/bidi.dart';
import 'package:admin/utils/file_names.dart';
import 'package:admin/utils/formatting.dart';

/// One DocuNinja document (`/docuninja/:id`), as React's `show/Document.tsx`
/// lays it out: the title with its status, the signers beside the timeline,
/// and the actions in React's order (docs/docuninja.md).
///
/// Edit (the field builder) and Make template arrive with the builder and the
/// templates; until then they are not offered.
class DocuNinjaDocumentScreen extends StatefulWidget {
  const DocuNinjaDocumentScreen({super.key, required this.id});

  final String id;

  @override
  State<DocuNinjaDocumentScreen> createState() =>
      _DocuNinjaDocumentScreenState();
}

enum _Action {
  edit,
  viewPdf,
  send,
  auditLog,
  download,
  clone,
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
    _lifecycle = AppLifecycleListener(onResume: () => _vm?.load());
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
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId;
    if (companyId != null) {
      services.formatterFor(companyId).then((f) {
        if (mounted) setState(() => _formatter = f);
      });
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _vm?.dispose();
    super.dispose();
  }

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
        return Scaffold(
          appBar: AppBar(
            title: Text(
              doc == null ? context.tr('document') : _title(context, doc),
            ),
            actions: [
              if (doc != null)
                EntityActionsPopupButton<_Action>(
                  items: _items(context, vm, doc),
                  splitEditAction: true,
                ),
            ],
          ),
          body: _body(context, vm, doc),
        );
      },
    );
  }

  Widget _body(
    BuildContext context,
    DocuNinjaDocumentViewModel vm,
    DnDocument? doc,
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
    final signers = _Invitations(
      document: doc,
      formatter: _formatter,
      busy: vm.isBusy,
      onResend: (i) => _resend(context, vm, i),
    );
    final timeline = _Timeline(entries: vm.timeline, formatter: _formatter);
    return AppSelectionArea(
      child: RefreshIndicator(
        onRefresh: vm.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(InSpacing.lg(context)),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: tokens.surface,
                    border: Border.all(color: tokens.border),
                    borderRadius: BorderRadius.circular(InRadii.r3),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(InSpacing.lg(context)),
                    child: Column(
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
                            // React shows Deleted / Archived beside the status.
                            // Only when there is one: the Wrap spaces even a
                            // zero-size child.
                            if (doc.isDeleted || doc.isArchived)
                              DocuNinjaLifecyclePill(document: doc),
                            DocuNinjaStatusPill(
                              document: doc,
                              statusOnly: true,
                            ),
                          ],
                        ),
                        // The action worked but the re-read did not (or a
                        // pull to refresh failed): what's shown may be stale.
                        if (vm.error != null && !vm.isLoading)
                          DocuNinjaInlineError(
                            offline: vm.isOffline,
                            onRetry: vm.load,
                          ),
                        if (vm.isBusy || _downloading)
                          const Padding(
                            padding: EdgeInsets.only(top: InSpacing.sm),
                            child: LinearProgressIndicator(minHeight: 2),
                          ),
                        SizedBox(height: InSpacing.lg(context)),
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
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    signers,
                                    SizedBox(height: InSpacing.lg(context)),
                                    timeline,
                                  ],
                                ),
                        ),
                      ],
                    ),
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
      confirm: confirm,
      confirmMessageKey: confirmMessageKey,
      isDestructive: destructive,
      isLifecycle: lifecycle,
      confirmSubject: title,
      onTap: () => _onAction(context, vm, doc, kind),
    );
    return [
      // React's Edit (the field builder): beside the menu, disabled once the
      // document is completed or voided. It opens in the browser for now.
      if (!doc.isDeleted)
        item(
          _Action.edit,
          Icons.edit_outlined,
          'edit',
          primary: true,
          enabled: !completed && doc.status != DnDocumentStatus.voided,
        ),
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
      if (!doc.isDeleted)
        item(
          _Action.clone,
          Icons.copy_outlined,
          'clone',
          confirm: true,
          confirmMessageKey: 'clone_document_description',
        ),
      // The app's Share / Copy Link (every record has one): opens this
      // document in the app, on its company (`buildDocuNinjaDeepLink`).
      EntityActionItem<_Action>(
        kind: _Action.copyLink,
        icon: Icons.link,
        label: context.tr(Env.isTouchPrimary ? 'share_link' : 'copy_link'),
        enabled: true,
        onTap: () => _onAction(context, vm, doc, _Action.copyLink),
      ),
      if (dnCanVoid(doc))
        item(
          _Action.voidIt,
          Icons.block_outlined,
          'void',
          confirm: true,
          destructive: true,
        ),
      if (!doc.isDeleted) item(_Action.options, Icons.tune_outlined, 'options'),
      if (!doc.isArchived && !doc.isDeleted)
        item(
          _Action.archive,
          Icons.archive_outlined,
          'archive',
          confirm: true,
          confirmMessageKey: 'archive_document_description',
          lifecycle: true,
        ),
      if (doc.isArchived || doc.isDeleted)
        item(
          _Action.restore,
          Icons.restore_outlined,
          'restore',
          lifecycle: true,
        ),
      if (!doc.isDeleted)
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
      case _Action.viewPdf:
        context.go('/docuninja/${doc.id}/pdf');
      case _Action.send:
        if (!await _confirmSend(context, doc)) return;
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
          Notify.error(context, context.tr('an_error_occurred_try_again'));
        } else {
          _changed();
          Notify.success(context, context.tr('cloned_document'));
          context.go('/docuninja/$id');
        }
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
        await shareOrCopyLink(context, link);
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
      Notify.error(context, context.tr('an_error_occurred_try_again'));
    }
  }

  /// The signed PDF or the audit log, under the name DocuNinja gives it.
  Future<void> _save(
    BuildContext context,
    Future<DnFileBytes> Function() fetch,
    String fallbackName,
  ) async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      final file = await fetch();
      if (!context.mounted) return;
      final base = (file.filename ?? fallbackName).replaceAll(
        RegExp(r'\.pdf$', caseSensitive: false),
        '',
      );
      await downloadPdf(context, fileName: '${sanitizeFileName(base)}.pdf')(
        file.bytes,
      );
    } on Object {
      if (context.mounted) {
        Notify.error(context, context.tr('an_error_occurred_try_again'));
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  /// React's send dialog (`SendInvitationsModal.tsx`): who will be emailed,
  /// in signing order. Outward-facing, so the primary is not autofocused.
  Future<bool> _confirmSend(BuildContext context, DnDocument doc) async {
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
            for (final i in doc.invitationsInOrder)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  [
                    i.signerName,
                    if (i.signerEmail.isNotEmpty) ltrIsolate(i.signerEmail),
                  ].where((s) => s.isNotEmpty).join(' · '),
                ),
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
    final confirmed = await showConfirmActionDialog(
      context,
      title: context.tr('resend'),
      subject: invitation.signerName.isNotEmpty
          ? invitation.signerName
          : invitation.signerEmail,
    );
    if (!confirmed || !context.mounted) return;
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

/// React's `Invitations.tsx`: each signer, in signing order, with where they
/// are and a resend.
class _Invitations extends StatelessWidget {
  const _Invitations({
    required this.document,
    required this.formatter,
    required this.busy,
    required this.onResend,
  });

  final DnDocument document;
  final Formatter? formatter;
  final bool busy;
  final ValueChanged<DnInvitation> onResend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.inTheme;
    final rows = document.invitationsInOrder;
    final showResend = dnShowsResend(document);
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
          Text(
            context.tr('add_signatories'),
            style: TextStyle(color: tokens.ink3),
          )
        else
          for (final i in rows)
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LtrText(
                          i.signerName.isNotEmpty
                              ? i.signerName
                              : i.signerEmail,
                          // A name may be Arabic or Hebrew; an email is not.
                          keepRtlScript: true,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        if (i.signerName.isNotEmpty && i.signerEmail.isNotEmpty)
                          LtrText(
                            i.signerEmail,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: tokens.ink3, fontSize: 12),
                          ),
                        _StateLine(invitation: i, formatter: formatter),
                      ],
                    ),
                  ),
                  if (showResend)
                    IconButton(
                      icon: const Icon(Icons.forward_to_inbox_outlined),
                      tooltip: context.tr('resend'),
                      onPressed: !busy && dnCanResend(document, i)
                          ? () => onResend(i)
                          : null,
                    ),
                ],
              ),
            ),
      ],
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
    final style = TextStyle(color: context.inTheme.ink2, fontSize: 12);
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

/// React's `TimelineLayout.tsx`: each step, done or still to come.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.entries, required this.formatter});

  final List<DnTimelineEntry> entries;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.inTheme;
    final f = formatter;
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
        for (final e in entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  e.completed
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 18,
                  color: e.completed ? tokens.paid : tokens.ink3,
                ),
                const SizedBox(width: InSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.title,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      if (e.description.isNotEmpty)
                        Text(
                          e.description,
                          style: TextStyle(color: tokens.ink2, fontSize: 12),
                        ),
                      // `YYYY-MM-DD HH:MM:SS` in UTC; the formatter shows it
                      // in local time, in the company's date format.
                      if (e.time.isNotEmpty && f != null)
                        LtrText(
                          f.date(e.time, showTime: true, showSeconds: false),
                          style: TextStyle(color: tokens.ink3, fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
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
        title: Text(context.tr('options')),
        content: FormSaveScope(
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
