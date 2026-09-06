import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/billing/invitation.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/vendor.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/dialogs/discard_changes_dialog.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/features/billing_shared/billing_doc_type.dart';
import 'package:admin/ui/features/billing_shared/email/billing_doc_email_sheet.dart'
    show BillingEmailTemplate;
import 'package:admin/ui/features/billing_shared/email/email_preview_binding.dart';
import 'package:admin/ui/features/billing_shared/email/labeled_field.dart';
import 'package:admin/ui/features/billing_shared/email/schedule_email_picker.dart';
import 'package:admin/ui/features/billing_shared/pdf/billing_doc_pdf_view.dart';
import 'package:admin/ui/features/billing_shared/sends/billing_doc_sends_tab.dart';
import 'package:admin/ui/features/settings/views/advanced/templates_reminders/preview_controller.dart';
import 'package:admin/ui/features/settings/views/advanced/templates_reminders/widgets/template_preview_panel.dart';
import 'package:admin/utils/formatting.dart';

/// Callback types so the screen stays entity-agnostic — the route screen
/// binds these to the owning repo's `email` / `scheduleEmail` /
/// `reactivateInvitationEmail` / `api.downloadPdf`.
typedef SendEmailCallback =
    Future<void> Function({
      required String template,
      String? subject,
      String? body,
      String? ccEmail,
    });
typedef ScheduleEmailCallback =
    Future<void> Function({
      required String template,
      required String sendAt,
      String? subject,
      String? body,
      String? ccEmail,
    });

/// Full-screen "Send Email" surface, shared by all five billing docs
/// (invoice / quote / credit / purchase order / recurring invoice).
///
/// Desktop (≥1024): two panels — left = the email form (read-only
/// recipients, template, CC, subject, body) with a live preview beneath;
/// right = PDF + History tabs. Mobile (<1024): one `[Email | PDF | History]`
/// tab strip with the form + inline preview together under "Email".
///
/// It is **entity-agnostic**: data + the send/schedule/reactivate/PDF
/// behaviors arrive as plain values + callbacks from
/// [BillingDocEmailRouteScreen]. The live preview reuses [PreviewController]
/// + [TemplatePreviewPanel] (the same engine as Settings → Templates):
/// WebView-rendered HTML on iOS/Android, `SuperReader` markdown on
/// desktop/web — the PDF panel is the rendered-fidelity anchor on desktop.
class BillingDocEmailScreen extends StatefulWidget {
  const BillingDocEmailScreen({
    super.key,
    required this.services,
    required this.companyId,
    required this.type,
    required this.entityId,
    required this.entityNumber,
    required this.invitations,
    required this.clientId,
    required this.vendorId,
    required this.isHosted,
    required this.formatter,
    required this.onSend,
    this.onSchedule,
    required this.onReactivate,
    required this.pdfFetcher,
  });

  final Services services;
  final String companyId;
  final BillingDocType type;
  final String entityId;
  final String entityNumber;
  final List<Invitation> invitations;

  /// Exactly one of [clientId] / [vendorId] is non-empty — names the entity
  /// whose contacts label the recipient line (vendors for purchase orders).
  final String clientId;
  final String vendorId;

  final bool isHosted;
  final Formatter? formatter;

  final SendEmailCallback onSend;

  /// Null when the doc type can't be scheduled (recurring invoices). The
  /// Schedule action is hidden in that case — see [_wideActions] /
  /// [_narrowActions] and [BillingDocType.supportsScheduledSend].
  final ScheduleEmailCallback? onSchedule;
  final Future<int> Function(String messageId) onReactivate;
  final Future<Uint8List> Function({
    String? designId,
    required bool deliveryNote,
  })
  pdfFetcher;

  @override
  State<BillingDocEmailScreen> createState() => _BillingDocEmailScreenState();
}

class _BillingDocEmailScreenState extends State<BillingDocEmailScreen> {
  late String _template;
  late final PreviewController _preview;
  final _subject = TextEditingController();
  final _body = TextEditingController();
  final _cc = TextEditingController();

  StreamSubscription<Map<String, ({String label, String email})>>? _contactsSub;
  Map<String, ({String label, String email})> _contacts = const {};

  /// True once the contacts stream has emitted at least once. Distinguishes
  /// "still loading" (show no hint) from "loaded, but no deliverable email"
  /// (explain why Send is disabled).
  bool _contactsLoaded = false;

  /// True until the next server render lands; then we seed the (still empty)
  /// subject/body controllers from the template defaults. Disarmed the
  /// instant the user types, and re-checked at apply time, so an in-flight
  /// render can never overwrite text the user just entered.
  bool _seedArmed = true;
  bool _editedSubject = false;
  bool _editedBody = false;
  bool _editedCc = false;

  /// Synchronous double-submit guard — set before any await so two taps in
  /// one frame can't both enqueue.
  bool _inFlight = false;

  bool get _dirty => _editedSubject || _editedBody || _editedCc;
  bool get _isTmp => widget.entityId.startsWith('tmp_');

  /// At least one recipient has a real (non-empty) email — an invitation can
  /// point at a contact with a blank address, which is not deliverable.
  bool get _hasDeliverable => widget.invitations.any((inv) {
    final id = inv.clientContactId.isNotEmpty
        ? inv.clientContactId
        : inv.vendorContactId;
    return (_contacts[id]?.email ?? '').isNotEmpty;
  });

  /// Every recipient previously bounced / errored — resending just bounces
  /// again until they're reactivated from the History tab.
  bool get _allBounced =>
      widget.invitations.isNotEmpty &&
      widget.invitations.every((i) => i.hasBounced || i.hasError);

  bool get _canSend => !_inFlight && !_isTmp && _hasDeliverable;

  @override
  void initState() {
    super.initState();
    _preview = PreviewController(api: widget.services.templates);
    _preview.addListener(_onPreviewChanged);
    _template = BillingEmailTemplate.forType(widget.type).first.value;

    // The doc's client/vendor (hence its contacts) may not be in Drift yet
    // when reached from a list — deduped + safe to fire unconditionally.
    if (widget.clientId.isNotEmpty) {
      widget.services.clients.ensureLoaded(
        companyId: widget.companyId,
        id: widget.clientId,
      );
    } else if (widget.vendorId.isNotEmpty) {
      widget.services.vendors.ensureLoaded(
        companyId: widget.companyId,
        id: widget.vendorId,
      );
    }
    _contactsSub = _contactsStream().listen((m) {
      if (mounted) {
        setState(() {
          _contacts = m;
          _contactsLoaded = true;
        });
      }
    });

    _scheduleRender(immediate: true);
  }

  @override
  void dispose() {
    _contactsSub?.cancel();
    _preview.removeListener(_onPreviewChanged);
    _preview.dispose();
    _subject.dispose();
    _body.dispose();
    _cc.dispose();
    super.dispose();
  }

  // ---- preview + seeding -------------------------------------------------

  void _scheduleRender({bool immediate = false}) {
    // Bind the render to the document being emailed — see
    // [emailPreviewBinding] for why, and for the two cases that must stay
    // on the server's generic sample.
    final binding = emailPreviewBinding(
      type: widget.type,
      entityId: widget.entityId,
      hasInvitations: widget.invitations.isNotEmpty,
    );
    _preview.schedule(
      template: _template,
      subject: _subject.text,
      body: _body.text,
      entity: binding.entity,
      entityId: binding.entityId,
      immediate: immediate,
    );
  }

  void _onPreviewChanged() {
    final value = _preview.value;
    // Re-check emptiness HERE (not only when arming) — closes the window
    // where the user types while a render is in flight.
    if (value is TemplatePreviewLoaded &&
        _seedArmed &&
        _subject.text.isEmpty &&
        _body.text.isEmpty) {
      _seedArmed = false;
      _subject.text = value.preview.rawSubject;
      _body.text = value.preview.rawBody;
    }
  }

  void _onTemplateChanged(String value) {
    setState(() {
      _template = value;
      // Preserve the user's text if they've customized it (just re-render the
      // preview against the new template); otherwise reseed from the new
      // template's defaults.
      if (!_editedSubject && !_editedBody) {
        _subject.clear();
        _body.clear();
        _seedArmed = true;
      }
    });
    _scheduleRender(immediate: true);
  }

  void _onSubjectChanged(String _) {
    _seedArmed = false;
    if (!_editedSubject) setState(() => _editedSubject = true);
    _scheduleRender();
  }

  void _onBodyChanged(String _) {
    _seedArmed = false;
    if (!_editedBody) setState(() => _editedBody = true);
    _scheduleRender();
  }

  void _clearSubject() {
    _subject.clear();
    _editedSubject = false;
    // Re-arm so the field reseeds to the template default (only applies if
    // the body is also empty, per the seed guard); the preview re-renders to
    // show the template's default subject either way.
    if (_body.text.isEmpty) _seedArmed = true;
    setState(() {});
    _scheduleRender(immediate: true);
  }

  // ---- contacts ----------------------------------------------------------

  Stream<Map<String, ({String label, String email})>> _contactsStream() {
    if (widget.clientId.isNotEmpty) {
      return widget.services.clients
          .watch(companyId: widget.companyId, id: widget.clientId)
          .map(_fromClient);
    }
    if (widget.vendorId.isNotEmpty) {
      return widget.services.vendors
          .watch(companyId: widget.companyId, id: widget.vendorId)
          .map(_fromVendor);
    }
    return Stream.value(const {});
  }

  static Map<String, ({String label, String email})> _fromClient(
    Client? client,
  ) {
    if (client == null) return const {};
    return {
      for (final c in client.contacts)
        c.id: (label: '${c.firstName} ${c.lastName}'.trim(), email: c.email),
    };
  }

  static Map<String, ({String label, String email})> _fromVendor(
    Vendor? vendor,
  ) {
    if (vendor == null) return const {};
    return {
      for (final c in vendor.contacts)
        c.id: (label: '${c.firstName} ${c.lastName}'.trim(), email: c.email),
    };
  }

  String _recipientText() {
    final parts = <String>[];
    for (final inv in widget.invitations) {
      final id = inv.clientContactId.isNotEmpty
          ? inv.clientContactId
          : inv.vendorContactId;
      final c = _contacts[id];
      final label = (c?.label ?? '').trim();
      final email = (c?.email ?? '').trim();
      if (label.isEmpty && email.isEmpty) continue;
      parts.add(
        label.isEmpty
            ? email
            : email.isEmpty
            ? label
            : '$label • $email',
      );
    }
    return parts.join(', ');
  }

  // ---- send / schedule / close ------------------------------------------

  String? _trimOrNull(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _send() async {
    if (_inFlight) return;
    setState(() => _inFlight = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.onSend(
        template: _template,
        subject: _trimOrNull(_subject),
        body: _trimOrNull(_body),
        ccEmail: _trimOrNull(_cc),
      );
      if (!mounted) return;
      Notify.success(context, context.tr('email_queued'), messenger: messenger);
      _doPop();
    } catch (e) {
      if (!mounted) return;
      Notify.error(
        context,
        context.tr('error'),
        error: e,
        messenger: messenger,
      );
      setState(() => _inFlight = false);
    }
  }

  Future<void> _schedule() async {
    if (_inFlight || widget.onSchedule == null) return;
    // Hold the in-flight guard across the picker so Send can't fire while the
    // schedule dialog is open (Schedule-then-Send double-commit).
    setState(() => _inFlight = true);
    final messenger = ScaffoldMessenger.of(context);
    final picked = await showScheduleEmailPicker(
      context,
      formatter: widget.formatter,
    );
    if (picked == null) {
      if (mounted) setState(() => _inFlight = false);
      return;
    }
    // Keep the LOCAL date: the server truncates sendAt to a date-only next_run
    // (scheduleEmailRecord), so `.toUtc()` shifted an evening pick to the next
    // (or previous) calendar day vs what the picker + confirmation toast show.
    final sendAt = picked.toIso8601String();
    try {
      await widget.onSchedule!(
        template: _template,
        sendAt: sendAt,
        subject: _trimOrNull(_subject),
        body: _trimOrNull(_body),
        ccEmail: _trimOrNull(_cc),
      );
      if (!mounted) return;
      Notify.success(
        context,
        context.tr('email_scheduled'),
        detail: widget.formatter?.date(
          sendAt,
          showTime: true,
          showSeconds: false,
        ),
        messenger: messenger,
      );
      _doPop();
    } catch (e) {
      if (!mounted) return;
      Notify.error(
        context,
        context.tr('error'),
        error: e,
        messenger: messenger,
      );
      setState(() => _inFlight = false);
    }
  }

  Future<void> _handleClose() async {
    if (_inFlight) return;
    if (_dirty && !(await showDiscardChangesDialog(context))) return;
    if (!mounted) return;
    _doPop();
  }

  /// Pop back to the detail screen; fall back to a `go` when the screen was
  /// reached by a direct deep link / restored route (nothing to pop).
  void _doPop() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/${widget.type.pluralLabelKey}/${widget.entityId}');
    }
  }

  // ---- build -------------------------------------------------------------

  String _title(BuildContext context) => widget.entityNumber.isEmpty
      ? context.tr('send_email')
      : '${context.tr('send_email')} · #${widget.entityNumber}';

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty && !_inFlight,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _inFlight) return;
        if (_dirty && !(await showDiscardChangesDialog(context))) return;
        if (!mounted) return;
        _doPop();
      },
      child: LayoutBuilder(
        builder: (context, constraints) =>
            constraints.maxWidth >= Breakpoints.slideOver
            ? _buildWide(context)
            : _buildNarrow(context),
      ),
    );
  }

  PreferredSizeWidget _appBar(
    BuildContext context, {
    required bool wide,
    PreferredSizeWidget? bottom,
  }) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: _handleClose,
        tooltip: context.tr('back'),
      ),
      titleSpacing: 0,
      title: Text(_title(context)),
      actions: wide ? _wideActions(context) : _narrowActions(context),
      bottom: bottom,
    );
  }

  /// Desktop: Schedule (secondary) + Send (primary) side by side. Schedule
  /// is hidden for doc types that can't be scheduled (recurring invoices —
  /// the server's task_scheduler rejects them, so it would silently send now).
  List<Widget> _wideActions(BuildContext context) {
    return [
      if (widget.type.supportsScheduledSend) ...[
        Center(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
            icon: const Icon(Icons.schedule_outlined, size: 18),
            label: Text(context.tr('schedule')),
            onPressed: _canSend ? _schedule : null,
          ),
        ),
        SizedBox(width: InSpacing.md(context)),
      ],
      Center(
        child: FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
          icon: const Icon(Icons.send, size: 18),
          label: Text(context.tr('send')),
          onPressed: _canSend ? _send : null,
        ),
      ),
      SizedBox(width: InSpacing.lg(context)),
    ];
  }

  /// Mobile: a compact Send button + Schedule tucked in an overflow menu so
  /// the title + actions never crowd a narrow AppBar.
  List<Widget> _narrowActions(BuildContext context) {
    return [
      Center(
        child: FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(64, 40)),
          onPressed: _canSend ? _send : null,
          child: Text(context.tr('send')),
        ),
      ),
      if (widget.type.supportsScheduledSend)
        PopupMenuButton<String>(
          // Explicit: the default is `Icons.adaptive.more`, which is
          // `more_horiz` on iOS and macOS. CLAUDE.md § Design system (v2).
          icon: const Icon(Icons.more_vert),
          enabled: _canSend,
          onSelected: (_) => _schedule(),
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              value: 'schedule',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.schedule_outlined, size: 18),
                  SizedBox(width: InSpacing.sm),
                  Text(context.tr('schedule')),
                ],
              ),
            ),
          ],
        ),
    ];
  }

  Widget _buildWide(BuildContext context) {
    final tokens = context.inTheme;
    return Scaffold(
      appBar: _appBar(context, wide: true),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _composePaneWide(context)),
          VerticalDivider(width: 1, thickness: 1, color: tokens.border),
          Expanded(child: _rightTabs(context)),
        ],
      ),
    );
  }

  Widget _buildNarrow(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: _appBar(
          context,
          wide: false,
          bottom: _tabBar(context, [
            context.tr('email'),
            context.tr('preview'),
            context.tr('pdf'),
            context.tr('history'),
          ]),
        ),
        body: TabBarView(
          children: [
            _composeScroll(context),
            _previewTab(context),
            _pdfView(),
            _historyView(),
          ],
        ),
      ),
    );
  }

  TabBar _tabBar(BuildContext context, List<String> labels) {
    final tokens = context.inTheme;
    return TabBar(
      labelColor: tokens.ink,
      unselectedLabelColor: tokens.ink2,
      indicatorColor: tokens.accent,
      dividerColor: tokens.border,
      tabs: [for (final l in labels) Tab(text: l)],
    );
  }

  Widget _rightTabs(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          _tabBar(context, [context.tr('pdf'), context.tr('history')]),
          Expanded(child: TabBarView(children: [_pdfView(), _historyView()])),
        ],
      ),
    );
  }

  Widget _pdfView() => BillingDocPdfView(
    entity: widget.type,
    entityNumber: widget.entityNumber,
    fetcher: widget.pdfFetcher,
  );

  Widget _historyView() => SingleChildScrollView(
    child: BillingDocSendsTab(
      services: widget.services,
      companyId: widget.companyId,
      entityWireName: widget.type.wireName,
      entityId: widget.entityId,
      invitations: widget.invitations,
      isHosted: widget.isHosted,
      onReactivate: widget.onReactivate,
      clientId: widget.clientId,
      vendorId: widget.vendorId,
    ),
  );

  Widget _composePaneWide(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(InSpacing.lg(context)),
            child: _form(context),
          ),
        ),
        Expanded(
          flex: 2,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              InSpacing.lg(context),
              0,
              InSpacing.lg(context),
              InSpacing.lg(context),
            ),
            child: TemplatePreviewPanel(controller: _preview),
          ),
        ),
      ],
    );
  }

  Widget _composeScroll(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(InSpacing.lg(context)),
      child: _form(context),
    );
  }

  /// Standalone preview tab (mobile). Deliberately kept OUT of the compose
  /// scroll: on desktop/web the preview is `SuperReader`, which integrates
  /// with a *vertical* ancestor scrollable and then renders as a sliver —
  /// inside the compose `SingleChildScrollView` that crashes (a sliver in a
  /// box context). A tab body's only scrollable ancestor is the horizontal
  /// `TabBarView`, which super_editor ignores, so the panel renders as a box.
  Widget _previewTab(BuildContext context) => Padding(
    padding: EdgeInsets.all(InSpacing.lg(context)),
    child: TemplatePreviewPanel(controller: _preview),
  );

  Widget _form(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _toLine(context),
        SizedBox(height: InSpacing.md(context)),
        LabeledField(
          label: context.tr('template'),
          child: DropdownButtonFormField<String>(
            initialValue: _template,
            isExpanded: true,
            items: [
              for (final t in BillingEmailTemplate.forType(widget.type))
                DropdownMenuItem(
                  value: t.value,
                  child: Text(context.tr(t.labelKey)),
                ),
            ],
            onChanged: _inFlight
                ? null
                : (v) {
                    if (v != null) _onTemplateChanged(v);
                  },
          ),
        ),
        SizedBox(height: InSpacing.md(context)),
        LabeledField(
          label: context.tr('cc_email'),
          child: TextField(
            controller: _cc,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(hintText: 'name@example.com'),
            onChanged: (_) {
              if (!_editedCc) setState(() => _editedCc = true);
            },
          ),
        ),
        SizedBox(height: InSpacing.md(context)),
        LabeledField(
          label: context.tr('subject'),
          child: TextField(
            controller: _subject,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: context.tr('use_default'),
              suffixIcon: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _subject,
                builder: (context, value, _) => value.text.isEmpty
                    ? const SizedBox.shrink()
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: context.tr('clear'),
                        onPressed: _clearSubject,
                      ),
              ),
            ),
            onChanged: _onSubjectChanged,
          ),
        ),
        SizedBox(height: InSpacing.md(context)),
        LabeledField(
          label: context.tr('body'),
          child: TextField(
            controller: _body,
            minLines: 4,
            maxLines: 8,
            keyboardType: TextInputType.multiline,
            decoration: InputDecoration(hintText: context.tr('use_default')),
            onChanged: _onBodyChanged,
          ),
        ),
        if (_allBounced) ...[
          SizedBox(height: InSpacing.md(context)),
          _bounceWarning(context),
        ],
      ],
    );
  }

  Widget _toLine(BuildContext context) {
    final tokens = context.inTheme;
    final text = _recipientText();
    // Once contacts resolve, explain a disabled Send when the recipient(s)
    // have no email — otherwise the button looks broken.
    final noEmail =
        _contactsLoaded && widget.invitations.isNotEmpty && !_hasDeliverable;
    return LabeledField(
      label: context.tr('to'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            label: '${context.tr('recipients')}: ${text.isEmpty ? '—' : text}',
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                text.isEmpty ? '—' : text,
                style: TextStyle(
                  color: text.isEmpty ? tokens.ink3 : tokens.ink,
                ),
              ),
            ),
          ),
          if (noEmail)
            Text(
              context.tr('no_email_on_file'),
              style: TextStyle(color: tokens.ink3, fontSize: 12),
            ),
        ],
      ),
    );
  }

  Widget _bounceWarning(BuildContext context) {
    final tokens = context.inTheme;
    return Container(
      padding: EdgeInsets.all(InSpacing.md(context)),
      decoration: BoxDecoration(
        color: tokens.overdueSoft,
        borderRadius: BorderRadius.circular(InRadii.r2),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: tokens.overdue),
          SizedBox(width: InSpacing.sm),
          Expanded(
            child: Text(
              context.tr('email_bounced'),
              style: TextStyle(color: tokens.overdue, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
