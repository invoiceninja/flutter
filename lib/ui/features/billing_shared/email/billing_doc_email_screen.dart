import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/billing/invitation.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/vendor.dart';
import 'package:admin/data/models/value/parsing.dart';
import 'package:admin/domain/email_template_variables.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/dialogs/confirm_action_dialog.dart';
import 'package:admin/ui/core/dialogs/discard_changes_dialog.dart';
import 'package:admin/ui/core/widgets/field_action_button.dart';
import 'package:admin/ui/core/widgets/markdown_text_field.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/template_variables/template_default_badge.dart';
import 'package:admin/ui/core/widgets/template_variables/template_variable_field_shell.dart';
import 'package:admin/ui/core/widgets/template_variables/template_variable_text_controller.dart';
import 'package:admin/ui/features/billing_shared/billing_doc_type.dart';
import 'package:admin/ui/features/billing_shared/email/billing_doc_email_sheet.dart'
    show BillingEmailTemplate;
import 'package:admin/ui/features/billing_shared/email/email_preview_binding.dart';
import 'package:admin/ui/features/billing_shared/email/labeled_field.dart';
import 'package:admin/ui/features/billing_shared/email/schedule_email_picker.dart';
import 'package:admin/ui/features/billing_shared/email/template_variable_values_controller.dart';
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
/// recipients, template, CC, subject, body) at full height; right =
/// `[Preview | PDF | History]` tabs. Mobile (<1024): one
/// `[Email | Preview | PDF | History]` tab strip. The preview is a tab on both
/// so the body editor gets the whole compose column: stacked under the form it
/// left ~446 px for ~532 px of fields, while rendering the very same default
/// body the editor above it was already showing.
///
/// It is **entity-agnostic**: data + the send/schedule/reactivate/PDF
/// behaviors arrive as plain values + callbacks from
/// [BillingDocEmailRouteScreen]. The live preview reuses [PreviewController]
/// + [TemplatePreviewPanel] (the same engine as Settings → Templates):
/// WebView-rendered HTML on iOS/Android, `HtmlWidget` on desktop/web — the PDF
/// panel is the rendered-fidelity anchor on desktop.
class BillingDocEmailScreen extends StatefulWidget {
  const BillingDocEmailScreen({
    super.key,
    required this.services,
    required this.companyId,
    required this.type,
    required this.entityId,
    required this.entityNumber,
    required this.invitations,
    required this.isDirty,
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

  /// Forwarded to the History pane's [BillingDocSendsTab] — see its `isDirty`
  /// doc. Nothing on this screen reads it.
  final bool isDirty;

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

  /// Which `$variables` this document's emails can use
  /// (invoiceninja/flutter#139).
  late final TemplateVariableScope _scope = templateVariableScopeForEntity(
    widget.type.wireName,
  );
  late final TemplateVariableTextController _subject =
      TemplateVariableTextController(scope: _scope);
  final _cc = TextEditingController();
  final _subjectFocus = FocusNode();
  final _subjectShell = GlobalKey<TemplateVariableFieldShellState>();

  /// The body, as the editor emits it: **HTML**, and `''` while the template's
  /// own default is what will be sent.
  String _bodyValue = '';

  /// Forces an immediate serialize + emit, bypassing the editor's debounce.
  /// Every synchronous read of [_bodyValue] goes behind this.
  final _bodyFlush = MarkdownFieldController();

  /// Bumped to make the editor reseed — "Reset".
  int _bodySeed = 0;

  /// The user touched the body but the debounce hasn't fired yet. `canPop` is
  /// read during build and cannot await a flush, so the editor reports the
  /// first change synchronously through `onEditing` and this carries it until
  /// [_bodyValue] catches up.
  bool _touchedBody = false;

  /// The server's own subject / body for the selected template, rendered muted
  /// under a "Default" badge until the user edits. **Only ever assigned while
  /// our own value is empty**: `raw_subject` / `raw_body` echo the *request*
  /// back (`TemplateEngine.php` assigns them after `setTemplates()`), so once
  /// the user types they are the user's text, not the template — and a default
  /// poisoned with it makes Reset restore what it just reset away.
  String _defaultSubject = '';
  String _defaultBody = '';

  /// What the chips show — the document's own values. Only when the preview is
  /// bound to it; unbound, the server answers with another record's
  /// (invoiceninja/flutter#31).
  TemplateVariableValuesController? _values;
  bool _previewBound = false;

  /// The last server-rendered subject, for the narrow layout's "Preview:"
  /// line.
  String? _renderedSubject;

  StreamSubscription<Map<String, ({String label, String email})>>? _contactsSub;
  Map<String, ({String label, String email})> _contacts = const {};

  /// True once the contacts stream has emitted at least once. Distinguishes
  /// "still loading" (show no hint) from "loaded, but no deliverable email"
  /// (explain why Send is disabled).
  bool _contactsLoaded = false;

  bool _editedCc = false;
  final _ccFocus = FocusNode();

  /// Set on blur, not per keystroke — an address is malformed right up until
  /// the moment it isn't, so validating as you type flags every prefix.
  bool _ccInvalid = false;

  /// Both fields show the server's template until the user changes it, so
  /// "edited" is **derived from the value**, never latched. The editor emits
  /// `''` for a document edited back to the default, and the shell leaves its
  /// adopted copy in the controller after a blur — a sticky flag would leave
  /// Reset on screen, the form dirty, and the schedule warning firing for an
  /// edit that no longer exists.
  bool get _editedBody => _bodyValue.isNotEmpty || _touchedBody;

  bool get _editedSubject {
    final text = _subject.text.trim();
    return text.isNotEmpty && text != _defaultSubject.trim();
  }

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

  bool get _canSend => !_inFlight && !_isTmp && _hasDeliverable && !_ccInvalid;

  /// Whether the CC field holds something the server would silently drop.
  ///
  /// A list, not an address: the server splits `cc_email` on comma **and**
  /// space, so `"a@x.com, b@y.com"` is two addresses and validating it as one
  /// string would disable Send on a perfectly good entry.
  bool get _ccHasTypo =>
      splitAddressList(_cc.text).any((a) => !isLikelyEmailAddress(a));

  /// A CC typo is otherwise invisible: the field posts whatever it holds, the
  /// server drops what it can't parse without telling anyone, and the screen
  /// pops saying "Email queued".
  ///
  /// Blur is early feedback, not the gate — on touch an `AppBar` button takes
  /// no focus, so tapping Send never blurs this field and this never runs.
  /// [_validateCc] is the gate.
  void _onCcFocus() {
    if (_ccFocus.hasFocus) return;
    _validateCc();
  }

  /// Returns false when the field is unusable, having shown the error.
  bool _validateCc() {
    final invalid = _ccHasTypo;
    if (invalid != _ccInvalid) setState(() => _ccInvalid = invalid);
    return !invalid;
  }

  @override
  void initState() {
    super.initState();
    _preview = PreviewController(api: widget.services.templates);
    _preview.addListener(_onPreviewChanged);
    _ccFocus.addListener(_onCcFocus);
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

    final binding = emailPreviewBinding(
      type: widget.type,
      entityId: widget.entityId,
      hasInvitations: widget.invitations.isNotEmpty,
    );
    _previewBound = binding.entityId.isNotEmpty;
    if (_previewBound) {
      _values = TemplateVariableValuesController(
        api: widget.services.templates,
        entity: binding.entity,
        entityId: binding.entityId,
        scope: _scope,
        template: () => _template,
      )..start(const []);
    }

    _scheduleRender(immediate: true);
  }

  @override
  void dispose() {
    _contactsSub?.cancel();
    _preview.removeListener(_onPreviewChanged);
    _preview.dispose();
    _values?.dispose();
    _subjectFocus.dispose();
    _subject.dispose();
    _ccFocus.removeListener(_onCcFocus);
    _ccFocus.dispose();
    _cc.dispose();
    super.dispose();
  }

  // ---- preview + seeding -------------------------------------------------

  void _scheduleRender({bool immediate = false}) {
    // A flush from `_send` / `_schedule` / `_handleClose` re-enters here
    // through `onChanged`; the screen is on its way out, so the render would
    // land on nobody.
    if (_inFlight) return;
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
      // The same shape the send will use, so the preview isn't a rehearsal of
      // something else. Already HTML: that is what the editor emits.
      body: _bodyValue,
      entity: binding.entity,
      entityId: binding.entityId,
      immediate: immediate,
    );
  }

  void _onPreviewChanged() {
    final value = _preview.value;
    if (value is! TemplatePreviewLoaded) return;
    // Adopt the render's templates as the fields' defaults — but only from a
    // render that actually ASKED for the template. `rawSubject` / `rawBody`
    // are the request echoed back, so a response to a request that carried
    // the user's own text carries it straight back, and `PreviewController`
    // only invalidates its token inside `_fire()` — a non-immediate
    // `schedule()` merely restarts the debounce, so such a response can still
    // land after the user has cleared the field. Without the request check
    // that made their own deleted draft the muted "Default".
    //
    // The template check is the other half: a response for the template we
    // have since switched away from is never this one's default.
    final req = value.request;
    final forThisTemplate = req.template == _template;
    if (forThisTemplate && req.subjectWasEmpty && _subject.text.isEmpty) {
      if (value.preview.rawSubject != _defaultSubject) {
        setState(() => _defaultSubject = value.preview.rawSubject);
        _values?.noteText(_defaultSubject);
      }
    }
    if (forThisTemplate && req.bodyWasEmpty && _bodyValue.isEmpty) {
      if (value.preview.rawBody != _defaultBody) {
        setState(() => _defaultBody = value.preview.rawBody);
        // Probe the default's own tokens here: an untouched default never
        // fires `onChanged` (the editor emits nothing until the document
        // differs from it), so `_onBodyChanged` would never see them.
        _values?.noteText(_defaultBody);
      }
    }
    // Read by the "Preview:" line, whose builder listens to `_preview` after
    // this listener (registered first, in `initState`) has run.
    _renderedSubject = value.preview.subject;
  }

  void _onTemplateChanged(String value) {
    // Read BEFORE the cache they are derived from is cleared: once
    // `_defaultSubject` is `''`, `_editedSubject` degrades to "the field has
    // any text at all", which is true of the copy the shell adopts merely
    // because the user tapped in.
    final keepSubject = _editedSubject;
    setState(() {
      _template = value;
      // The cached defaults belong to the template we are leaving, so they go
      // **unconditionally** — an edited field is exactly the case where they
      // can never be refreshed (every adopt path requires our own value to be
      // empty), and a stale one there is not cosmetic: `_editedSubject`
      // compares against it, so typing the old template's wording back would
      // read as "unedited" and send `null`, i.e. the NEW template's subject,
      // while the user watches their own on screen.
      //
      // Clearing rather than keeping is the point for the unedited case too:
      // leaving the *first* reminder's body under a "Default" badge while the
      // third renders is a plausible-looking lie, where a blank box for one
      // render cycle is merely empty.
      _defaultSubject = '';
      _defaultBody = '';
      // Keep what the user wrote; otherwise start clean for the new template.
      if (!keepSubject) _subject.clear();
    });
    _scheduleRender(immediate: true);
  }

  void _onSubjectChanged(String _) {
    // `_editedSubject` is derived, so this only has to rebuild.
    setState(() {});
    _values?.noteText(_subject.text);
    _scheduleRender();
  }

  void _onBodyChanged(String html) {
    // The editor schedules its final emit on a microtask from `dispose`, so
    // this can arrive after the screen is gone.
    if (!mounted) return;
    setState(() {
      _bodyValue = html;
      _touchedBody = false;
    });
    _values?.noteText(html);
    _scheduleRender();
  }

  /// Put the template's own subject back.
  void _resetSubject() {
    _subject.clear();
    setState(() {});
    _scheduleRender(immediate: true);
  }

  /// Back to the template's own body. Bumping the seed is what makes the
  /// editor reseed — it owns its document, not our string.
  void _resetBody() {
    setState(() {
      _bodyValue = '';
      _touchedBody = false;
      _bodySeed++;
    });
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

  /// The subject as it goes on the wire — **null when it is the template's
  /// own**, so the server resolves it against the *client's* language at send
  /// time rather than receiving a snapshot fixed in ours. The shell leaves the
  /// copy it adopted on tap sitting in the controller, so tapping in and back
  /// out would otherwise post that copy as a deliberate override.
  String? _subjectOrNull() {
    final text = _subject.text.trim();
    if (text.isEmpty || text == _defaultSubject.trim()) return null;
    return text;
  }

  /// The body as it goes on the wire: HTML, already, because that is what the
  /// editor emits — and null while the document is still the template's own,
  /// for the same reason [_subjectOrNull] returns null there.
  ///
  /// Flushes first: the editor emits on a debounce, so a body typed in the
  /// last fraction of a second is otherwise dropped silently.
  String? _bodyOrNull() {
    final html = _bodyFlush.flush() ?? _bodyValue;
    return html.isEmpty ? null : html;
  }

  Future<void> _send() async {
    if (_inFlight) return;
    // Before anything else: the CC gate (blur never fires on touch), then
    // settle the editor's debounce so what we send is what is on screen.
    if (!_validateCc()) return;
    final body = _bodyOrNull();
    setState(() => _inFlight = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.onSend(
        template: _template,
        subject: _subjectOrNull(),
        body: body,
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
    if (!_validateCc()) return;
    // Flush BEFORE the edited check, not merely before the send: the warning
    // below is the only thing standing between a just-typed body and the
    // server discarding it, and `_editedBody` is debounced.
    final body = _bodyOrNull();
    // The server's scheduler sends the saved template and ignores a subject
    // or body override (`EmailRecord.php`; see BACKEND.md) — say so, rather
    // than drop the user's edits silently.
    if (_editedSubject || _editedBody) {
      final proceed = await showConfirmActionDialog(
        context,
        title: context.tr('schedule'),
        message: context.tr('scheduled_email_ignores_edits'),
      );
      if (!proceed || !mounted) return;
    }
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
        subject: _subjectOrNull(),
        body: body,
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
    // Settle the editor's debounce so `_dirty` sees a body typed a moment ago
    // — the ✕ is an `IconButton`, which takes no focus, so nothing blurred the
    // editor on the way here.
    _bodyFlush.flush();
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
    // The controller sits ABOVE the `Row` because `_rightTabs` no longer owns
    // one, and because the compose pane on the left reads it too — the
    // rendered-subject line under the Subject field jumps to the Preview tab.
    //
    // Keyed, so `LayoutBuilder` cannot reuse this element across the
    // breakpoint: a 4→3 remap would carry the index over, landing a resize
    // from narrow "Preview" (1) on wide "PDF" (1).
    return DefaultTabController(
      key: const ValueKey('email-tabs-wide'),
      length: 3,
      child: Scaffold(
        appBar: _appBar(context, wide: true),
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _composeScroll(context, wide: true)),
            VerticalDivider(width: 1, thickness: 1, color: tokens.border),
            Expanded(child: _rightTabs(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildNarrow(BuildContext context) {
    return DefaultTabController(
      key: const ValueKey('email-tabs-narrow'),
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
            _composeScroll(context, wide: false),
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

  /// Preview leads: the user is composing an email, and the PDF is its
  /// attachment. It also puts the preview where it has a full pane instead of
  /// a ~300 px strip under the form, and makes wide and narrow the same shape.
  Widget _rightTabs(BuildContext context) {
    return Column(
      children: [
        _tabBar(context, [
          context.tr('preview'),
          context.tr('pdf'),
          context.tr('history'),
        ]),
        Expanded(
          child: TabBarView(
            children: [_previewTab(context), _pdfView(), _historyView()],
          ),
        ),
      ],
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
      isDirty: widget.isDirty,
      isHosted: widget.isHosted,
      onReactivate: widget.onReactivate,
      clientId: widget.clientId,
      vendorId: widget.vendorId,
    ),
  );

  Widget _composeScroll(BuildContext context, {required bool wide}) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        InSpacing.lg(context),
        InSpacing.lg(context),
        InSpacing.lg(context),
        // The body is `SuperEditor`, not an `EditableText`, so Flutter's
        // scroll-the-caret-into-view never runs for it and the editor's own
        // `CustomScrollView` is the inner scrollable, not this one. Without
        // the inset the keyboard simply covers the field. Templates &
        // Reminders needed the identical padding for the identical reason.
        InSpacing.lg(context) + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: _form(context, wide: wide),
    );
  }

  /// Standalone preview tab. Deliberately kept OUT of the compose scroll:
  /// `TemplatePreviewPanel` is a `WebViewWidget` on mobile-native and an
  /// `HtmlWidget` elsewhere, and its frame falls back to a hard 600 px when
  /// its height is unbounded — inside the compose `SingleChildScrollView`
  /// that is a 600 px block with a nested scroll inside it.
  Widget _previewTab(BuildContext context) => Padding(
    padding: EdgeInsets.all(InSpacing.lg(context)),
    child: TemplatePreviewPanel(controller: _preview),
  );

  Widget _form(BuildContext context, {required bool wide}) {
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
            focusNode: _ccFocus,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              hintText: 'name@example.com',
              errorText: _ccInvalid ? context.tr('email_is_invalid') : null,
            ),
            onChanged: (_) {
              setState(() {
                _editedCc = true;
                // Clear the complaint as soon as they start fixing it; the
                // blur decides again.
                _ccInvalid = false;
              });
            },
          ),
        ),
        SizedBox(height: InSpacing.md(context)),
        // Variables render as chips carrying this document's values, so
        // "$company.name" reads as the company's name rather than as code
        // someone has to replace by hand (invoiceninja/flutter#139). Both
        // fields show the server's own template, muted, until the user edits:
        // it is what will actually be sent, and posting a snapshot of it back
        // would freeze the per-client language the server resolves at send.
        LabeledField(
          label: context.tr('subject'),
          // `!_editedSubject`, not `text.isEmpty`: the shell adopts a copy of
          // the default into the controller the moment the user taps in, so
          // an emptiness test drops the badge off a field that is still
          // showing the default — muted grey text with nothing to explain it,
          // which is the reading the badge exists to overturn.
          badge: !_editedSubject && _defaultSubject.isNotEmpty
              ? TemplateDefaultBadge(label: context.tr('default'))
              : null,
          trailing: Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _labelAction(
                context,
                icon: Icons.add,
                label: context.tr('insert_variable'),
                onPressed: _inFlight
                    ? null
                    : () => _subjectShell.currentState?.insertVariable(),
              ),
              if (_editedSubject)
                _labelAction(
                  context,
                  key: const Key('reset_subject'),
                  icon: Icons.restart_alt,
                  label: context.tr('reset'),
                  onPressed: _resetSubject,
                ),
            ],
          ),
          child: TemplateVariableFieldShell(
            key: _subjectShell,
            controller: _subject,
            focusNode: _subjectFocus,
            values: _values,
            defaultText: _defaultSubject,
            // The body below captions the pair; two copies of the same two
            // wrapped lines is noise on a 360 px phone.
            showDefaultCaption: false,
            showInsertButton: false,
            decoration: const InputDecoration(),
            onEdited: _onSubjectChanged,
            fieldBuilder: (context, decoration, onTapOutside) => TextField(
              controller: _subject,
              focusNode: _subjectFocus,
              textInputAction: TextInputAction.done,
              decoration: decoration,
              onTapOutside: onTapOutside,
              onChanged: _onSubjectChanged,
            ),
          ),
        ),
        _renderedSubjectLine(context, wide: wide),
        SizedBox(height: InSpacing.md(context)),
        // No `LabeledField`: the editor draws its own label row (label +
        // "Default" badge + Insert variable + `labelTrailing`), and two label
        // rows would be worse than one.
        MarkdownTextField(
          label: context.tr('body'),
          initialValue: _bodyValue,
          // `_defaultBody` is in the key because it arrives from a preview
          // render, i.e. always after the first build.
          externalValueKey: Object.hash(_bodySeed, _template, _defaultBody),
          defaultValue: _defaultBody.isEmpty ? null : _defaultBody,
          // The shared string says an edit "saves a custom copy", which is
          // true in Templates & Reminders and false here — nothing is saved,
          // the edit applies to this one email. Read before typing, the wrong
          // one reads as "editing this rewrites my template for every send".
          defaultCaption: context.tr('default_template_caption_send'),
          templateVariables: _scope,
          values: _values,
          controller: _bodyFlush,
          onChanged: _onBodyChanged,
          // Both edges. The false one is what stops an edit that round-trips
          // — typing a character and deleting it, or clearing the default and
          // letting it come back — from leaving the form dirty for ever.
          onEditing: (editing) {
            if (_touchedBody != editing) setState(() => _touchedBody = editing);
          },
          // Deliberately no `enabled:` gate on `_inFlight`: it swaps the live
          // editor for a reader mid-send, which drops focus (flushing, and
          // possibly reseeding, underneath the send) and takes the field's own
          // "Insert variable" button out of the label row. `_canSend` already
          // blocks both buttons.
          height: 120,
          // Explicit, because the default is half the *window* — not half this
          // pane — which on a phone is a 450 px scroller nested in the compose
          // scroll, where the inner one wins the gesture arena.
          maxHeight: 240,
          // Matches Templates & Reminders: tight enough to keep this plus the
          // preview's own 400 ms under a 600 ms perceived latency.
          debounce: const Duration(milliseconds: 150),
          labelTrailing: _editedBody
              ? _labelAction(
                  context,
                  key: const Key('reset_body'),
                  icon: Icons.restart_alt,
                  label: context.tr('reset'),
                  onPressed: _resetBody,
                )
              : null,
        ),
        if (_allBounced) ...[
          SizedBox(height: InSpacing.md(context)),
          _bounceWarning(context),
        ],
      ],
    );
  }

  /// A compact label-row action ("Insert variable", "Reset").
  Widget _labelAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    Key? key,
  }) => FieldActionButton(
    key: key,
    icon: icon,
    label: label,
    onPressed: onPressed,
  );

  /// Narrow layout only: the subject as recipients will read it. On a phone
  /// the rendered preview is a tab away from the fields, so this is where the
  /// user sees what `$company.name` becomes before sending. Dimmed while a
  /// new render is in flight; hidden when unbound, since an unbound render
  /// shows another record's values (#31). Tapping it opens the Preview tab.
  Widget _renderedSubjectLine(BuildContext context, {required bool wide}) {
    // The Preview tab's index, which is not the same on both: the wide strip
    // is [Preview, PDF, History], the narrow one [Email, Preview, PDF,
    // History].
    final previewTab = wide ? 0 : 1;
    return ValueListenableBuilder<TemplatePreviewState>(
      valueListenable: _preview,
      builder: (context, state, _) {
        final text = _renderedSubject?.trim() ?? '';
        if (!_previewBound ||
            text.isEmpty ||
            state is TemplatePreviewError ||
            state is TemplatePreviewIdle) {
          return const SizedBox.shrink();
        }
        final tokens = context.inTheme;
        final style = Theme.of(context).textTheme.bodySmall;
        final prefix = '${context.tr('preview')}: ';
        return Semantics(
          button: true,
          label: '$prefix$text',
          excludeSemantics: true,
          onTap: () =>
              DefaultTabController.maybeOf(context)?.animateTo(previewTab),
          child: InkWell(
            onTap: () =>
                DefaultTabController.maybeOf(context)?.animateTo(previewTab),
            borderRadius: BorderRadius.circular(InRadii.r1),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: AnimatedOpacity(
                opacity: state is TemplatePreviewLoading ? 0.5 : 1,
                duration: const Duration(milliseconds: 150),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: prefix,
                        style: style?.copyWith(color: tokens.ink2),
                      ),
                      TextSpan(
                        text: text,
                        style: style?.copyWith(
                          color: tokens.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        );
      },
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
