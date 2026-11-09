import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/docuninja/dn_models.dart';
import 'package:admin/data/repositories/docuninja/docuninja_session.dart';
import 'package:admin/data/services/docuninja/docuninja_api.dart';
import 'package:admin/data/services/docuninja/docuninja_client.dart';
import 'package:admin/domain/docuninja/docuninja_access.dart';
import 'package:admin/domain/docuninja/docuninja_settings_tabs.dart';
import 'package:admin/domain/docuninja/docuninja_permissions.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/dialogs/confirm_action_dialog.dart';
import 'package:admin/ui/core/unsaved_changes/unsaved_changes_scope.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/core/widgets/error_view.dart';
import 'package:admin/ui/core/widgets/form_save_scope.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/property_panel/property_inputs.dart';
import 'package:admin/ui/core/widgets/copyable_value.dart';
import 'package:admin/ui/core/widgets/ltr_value.dart';
import 'package:admin/ui/features/docuninja/widgets/docuninja_states.dart';
import 'package:admin/ui/features/docuninja/widgets/docuninja_table.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';

final _log = Logger('DocuNinjaSettingsScreen');

/// DocuNinja's own settings (`/docuninja/settings/<tab>`, React's
/// `CompanyDetails.tsx`), for a DocuNinja admin: email settings, email
/// templates, notifications, widget defaults and reminder schedules, a
/// sub-route each, with Save in the AppBar acting on the tab showing.
/// docs/docuninja.md § Settings.
class DocuNinjaSettingsScreen extends StatefulWidget {
  const DocuNinjaSettingsScreen({
    super.key,
    this.tab = kDocuNinjaSettingsDefaultTab,
  });

  /// The tab the route names (a [kDocuNinjaSettingsTabs] slug).
  final String tab;

  @override
  State<DocuNinjaSettingsScreen> createState() =>
      _DocuNinjaSettingsScreenState();
}

int _tabIndex(String tab) {
  final i = kDocuNinjaSettingsTabs.indexOf(tab);
  return i >= 0
      ? i
      : kDocuNinjaSettingsTabs.indexOf(kDocuNinjaSettingsDefaultTab);
}

/// What a tab offers the AppBar's Save: nothing until it publishes (the
/// reminder schedules never do: they save as they change), then its save
/// and whether one is running. A tab publishes from `setState`, so the
/// AppBar follows it.
class _TabSave extends ChangeNotifier {
  bool visible = false;
  bool saving = false;
  VoidCallback? onSave;

  /// A company tab's Save: off while another company tab saves (one save
  /// at a time lays its edits over the company the last one left).
  bool companyLock = false;
  bool _disposed = false;

  void publish({
    required VoidCallback? onSave,
    required bool saving,
    bool companyLock = false,
  }) {
    if (visible &&
        this.onSave == onSave &&
        this.saving == saving &&
        this.companyLock == companyLock) {
      return;
    }
    visible = true;
    this.onSave = onSave;
    this.saving = saving;
    this.companyLock = companyLock;
    // A tab first publishes while it builds: tell the AppBar after the
    // frame, never during it.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) notifyListeners();
      });
    } else {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class _DocuNinjaSettingsScreenState extends State<DocuNinjaSettingsScreen>
    with SingleTickerProviderStateMixin {
  DocuNinjaSession? _session;
  late final TabController _tabs = TabController(
    length: kDocuNinjaSettingsTabs.length,
    vsync: this,
    initialIndex: _tabIndex(widget.tab),
  );
  final _saves = [for (final _ in kDocuNinjaSettingsTabs) _TabSave()];
  late final Listenable _saveState = Listenable.merge([
    _tabs,
    _companySaveLock,
    ..._saves,
  ]);

  @override
  void initState() {
    super.initState();
    _tabs.addListener(_onTabChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = context.read<DocuNinjaSession?>();
    if (identical(session, _session)) return;
    _session = session;
    session?.load();
  }

  @override
  void didUpdateWidget(DocuNinjaSettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The route changed under the screen (Back, a deep link, a restore).
    final index = _tabIndex(widget.tab);
    if (index != _tabs.index && !_tabs.indexIsChanging) {
      _tabs.animateTo(index);
    }
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    for (final s in _saves) {
      s.dispose();
    }
    super.dispose();
  }

  /// A tab picked (or swiped to) is its sub-route, as React's are.
  void _onTabChanged() {
    if (_tabs.indexIsChanging) return;
    final tab = kDocuNinjaSettingsTabs[_tabs.index];
    if (tab == widget.tab) return;
    GoRouter.maybeOf(context)?.go(docuNinjaSettingsTabPath(tab));
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    if (session == null) return const SizedBox.shrink();
    return ValueListenableBuilder<DocuNinjaState>(
      valueListenable: session,
      builder: (context, state, _) {
        final login = state.login;
        final company = state.company;
        final admin = login != null && dnIsAdmin(login.companyUser);
        final Widget body;
        if (state.access == DocuNinjaAccess.loading ||
            state.access == DocuNinjaAccess.unavailable) {
          body = const Center(child: CircularProgressIndicator());
        } else if (!state.isReady || company == null) {
          body = DocuNinjaGoHomeState(access: state.access);
        } else if (!admin) {
          body = EmptyState(
            icon: Icons.lock_outline,
            title: context.tr('unauthorized_action'),
          );
        } else {
          final api = context.read<DocuNinjaApi>();
          _TabSave save(String tab) =>
              _saves[kDocuNinjaSettingsTabs.indexOf(tab)];
          // Keyed by company: a company switch starts every tab afresh.
          body = KeyedSubtree(
            key: ValueKey(company.id),
            child: TabBarView(
              controller: _tabs,
              children: [
                for (final tab in kDocuNinjaSettingsTabs)
                  switch (tab) {
                    'email_templates' => _EmailTemplatesTab(
                      api: api,
                      save: save(tab),
                    ),
                    'reminder_schedules' => _ReminderSchedulesTab(api: api),
                    _ => _CompanySettingsTab(
                      kind: switch (tab) {
                        'notifications' => _CompanyTab.notifications,
                        'widget_defaults' => _CompanyTab.widgets,
                        _ => _CompanyTab.email,
                      },
                      company: company,
                      api: api,
                      session: session,
                      save: save(tab),
                    ),
                  },
              ],
            ),
          );
        }
        final tabbed = state.isReady && company != null && admin;
        return Scaffold(
          appBar: AppBar(
            title: Text(context.tr('settings')),
            // React's Save is in the page header, as the app's settings
            // pages put theirs in the AppBar; it saves the tab showing.
            actions: [
              if (tabbed)
                ListenableBuilder(
                  listenable: _saveState,
                  builder: (context, _) {
                    final save = _saves[_tabs.index];
                    if (!save.visible) return const SizedBox.shrink();
                    final locked = save.companyLock && _companySaveLock.value;
                    return DnAppBarSaveButton(
                      saving: save.saving,
                      onPressed: locked ? null : save.onSave,
                    );
                  },
                ),
              const SizedBox(width: InSpacing.sm),
            ],
            bottom: tabbed
                ? TabBar(
                    controller: _tabs,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    tabs: [
                      for (final t in kDocuNinjaSettingsTabs)
                        Tab(text: context.tr(t)),
                    ],
                  )
                : null,
          ),
          body: body,
        );
      },
    );
  }
}

/// A settings tab's centred, capped column.
class _TabBody extends StatelessWidget {
  const _TabBody({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ListView(
    padding: EdgeInsets.all(InSpacing.lg(context)),
    children: [
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    ],
  );
}

enum _CompanyTab { email, notifications, widgets }

/// Held while one of the company tabs saves (one screen at a time shows
/// them).
final _companySaveLock = ValueNotifier<bool>(false);

/// Two settings values the same to the user: a flag DocuNinja holds as 1
/// is the `true` a switch writes, and a missing one is off.
bool _sameSetting(Object? a, Object? b) {
  bool? flag(Object? v) => switch (v) {
    true || 1 => true,
    false || 0 || null => false,
    _ => null,
  };
  final fa = flag(a);
  final fb = flag(b);
  if (fa != null && fb != null) return fa == fb;
  return '${a ?? ''}' == '${b ?? ''}';
}

/// React's three company pages (email settings, notifications, widget
/// defaults): each edits `company.settings` and puts the whole company
/// back. The company is the one paired with this Invoice Ninja company
/// (React reads the first company, which is wrong on a multi-company
/// account). Saving re-runs the handshake, as React refetches its login.
class _CompanySettingsTab extends StatefulWidget {
  const _CompanySettingsTab({
    required this.kind,
    required this.company,
    required this.api,
    required this.session,
    required this.save,
  });

  final _CompanyTab kind;
  final DnCompany company;
  final DocuNinjaApi api;
  final DocuNinjaSession session;

  /// The AppBar's Save, while this tab shows.
  final _TabSave save;

  @override
  State<_CompanySettingsTab> createState() => _CompanySettingsTabState();
}

class _CompanySettingsTabState extends State<_CompanySettingsTab>
    with AutomaticKeepAliveClientMixin {
  /// What the user changed on this tab, and only that: a save lays it over
  /// the company's current settings (which another tab's save may have
  /// changed since this one opened), so one tab never writes back another's
  /// stale values, nor a default the server never held.
  final Map<String, dynamic> _edits = {};

  /// What the controls show: the company's settings, under this tab's
  /// edits, with React's display defaults for a key the company lacks.
  Map<String, dynamic> get _settings => {
    'widget_border_style': 'hidden',
    'widget_border_color': '#FF5733',
    ...widget.company.settings,
    ..._edits,
  };

  /// The company's settings as saved, with the same display defaults.
  Map<String, dynamic> get _saved => {
    'widget_border_style': 'hidden',
    'widget_border_color': '#FF5733',
    ...widget.company.settings,
  };

  String _savedText(String key) => '${_saved[key] ?? ''}'.trim();

  /// Bumped on every change, so the unsaved-changes guard re-asks.
  final _revision = ValueNotifier<int>(0);
  late final Listenable _changes = Listenable.merge([
    _revision,
    _fromName,
    _replyTo,
  ]);

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _revision.value++;
    _publishSave();
  }

  void _publishSave() =>
      widget.save.publish(onSave: _save, saving: _saving, companyLock: true);

  @override
  void initState() {
    super.initState();
    _publishSave();
  }

  /// Something on this tab differs from the company as saved.
  bool get _isDirty {
    final saved = _saved;
    if (_edits.entries.any((e) => !_sameSetting(saved[e.key], e.value))) {
      return true;
    }
    if (widget.kind != _CompanyTab.email) return false;
    return _fromName.text.trim() != _savedText('email_from_name') ||
        _replyTo.text.trim() != _savedText('reply_to_email');
  }

  /// Back to the company as saved (the user chose Discard).
  void _discard() => setState(() {
    _edits.clear();
    _fieldErrors = const {};
    _fromName.text = _savedText('email_from_name');
    _replyTo.text = _savedText('reply_to_email');
  });

  void _set(String key, Object? value) => setState(() => _edits[key] = value);
  late final _fromName = TextEditingController(
    text: '${_settings['email_from_name'] ?? ''}',
  );
  late final _replyTo = TextEditingController(
    text: '${_settings['reply_to_email'] ?? ''}',
  );
  bool _saving = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _fromName.dispose();
    _replyTo.dispose();
    _revision.dispose();
    super.dispose();
  }

  /// The server's per-field messages, by settings key.
  Map<String, String> _fieldErrors = const {};

  static Map<String, String> _settingsErrors(Map<String, List<String>> e) => {
    for (final entry in e.entries)
      if (entry.value.isNotEmpty)
        entry.key.replaceFirst('settings.', ''): entry.value.first,
  };

  bool _flag(String key) => _settings[key] == true || _settings[key] == 1;

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    if (widget.kind == _CompanyTab.email) {
      // React sends an empty value as null.
      final name = _fromName.text.trim();
      final reply = _replyTo.text.trim();
      _edits['email_from_name'] = name.isEmpty ? null : name;
      _edits['reply_to_email'] = reply.isEmpty ? null : reply;
    }
    // One company save at a time across the tabs: each lays its edits over
    // the company as the last save left it.
    if (_companySaveLock.value) {
      setState(() => _saving = false);
      return;
    }
    _companySaveLock.value = true;
    _fieldErrors = const {};
    try {
      // The company as DocuNinja holds it now, not as this session first
      // read it: another admin may have changed it since, and the save puts
      // the whole company back (React refetches its login on focus).
      final epoch = widget.session.epoch;
      await widget.session.load(force: true);
      // A company switch (or sign-out) while the handshake was out: the
      // token now is another company's, so nothing of this one is sent.
      if (!mounted || widget.session.epoch != epoch) return;
      final company = widget.session.value.company;
      if (company == null || company.id != widget.company.id) {
        // DocuNinja no longer pairs this company: the screen is about to
        // say so; the edits are not sent anywhere.
        Notify.error(context, context.tr('an_error_occurred_try_again'));
        return;
      }
      final next = {...company.settings, ..._edits};
      await widget.api.updateCompanySettings(company, next);
      // Saved: the session holds the company as saved, so the other tabs
      // build their next save on it.
      widget.session.replaceCompany(company.withSettings(next));
      _edits.clear();
      if (!mounted) return;
      Notify.success(context, context.tr('updated_company'));
    } on DocuNinjaException catch (e) {
      // A refused field's own message shows beside it; the toast stays
      // the app's (server text is never toasted raw).
      if (mounted) {
        setState(() => _fieldErrors = _settingsErrors(e.fieldErrors));
        Notify.error(context, context.tr('an_error_occurred_try_again'));
      }
    } on Object catch (e, st) {
      _log.warning('Saving DocuNinja company settings failed', e, st);
      if (mounted) {
        Notify.error(context, context.tr('an_error_occurred_try_again'));
      }
    } finally {
      _companySaveLock.value = false;
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _toggle(String key, String label, String help) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    value: _flag(key),
    title: Text(context.tr(label)),
    subtitle: Text(context.tr(help)),
    onChanged: _saving ? null : (v) => _set(key, v),
  );

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return UnsavedChangesScope(
      isDirty: () => _isDirty,
      source: _changes,
      onDiscard: _discard,
      child: _tab(context),
    );
  }

  Widget _tab(BuildContext context) {
    switch (widget.kind) {
      case _CompanyTab.email:
        return FormSaveScope(
          onSubmit: _save,
          enabled: !_saving,
          child: _TabBody(
            children: [
              FormSection(
                title: context.tr('email_settings'),
                children: [
                  TextField(
                    controller: _fromName,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: context.tr('from_name'),
                      errorText: _fieldErrors['email_from_name'],
                    ),
                    onSubmitted: (_) => _save(),
                  ),
                  TextField(
                    controller: _replyTo,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: context.tr('reply_to_email'),
                      errorText: _fieldErrors['reply_to_email'],
                    ),
                    onSubmitted: (_) => _save(),
                  ),
                ],
              ),
            ],
          ),
        );
      case _CompanyTab.notifications:
        return _TabBody(
          children: [
            FormSection(
              title: context.tr('notifications'),
              children: [
                _toggle(
                  'ninja_quote_notification',
                  'quote_signed_notification',
                  'email_client_when_quote_signed_description',
                ),
                _toggle(
                  'ninja_invoice_notification',
                  'invoice_signed_notification',
                  'email_client_when_invoice_signed_description',
                ),
                _toggle(
                  'ninja_credit_notification',
                  'credit_signed_notification',
                  'email_client_when_credit_signed_description',
                ),
                _toggle(
                  'ninja_purchase_order_notification',
                  'purchase_order_signed_notification',
                  'email_vendor_when_purchase_order_signed_description',
                ),
                _toggle(
                  'email_client_when_completed',
                  'custom_document_completed',
                  'email_client_when_custom_document_completed',
                ),
                _toggle(
                  'attach_audit_log_to_completed_email',
                  'attach_audit_log_to_completed_email',
                  'attach_audit_log_to_completed_email_help',
                ),
              ],
            ),
          ],
        );
      case _CompanyTab.widgets:
        final style = '${_settings['widget_border_style'] ?? 'hidden'}';
        return _TabBody(
          children: [
            FormSection(
              title: context.tr('widget_defaults'),
              children: [
                _toggle('widget_show_label', 'show_label', 'show_label_help'),
                // Three choices: a radio group (CLAUDE.md § Forms).
                Text(context.tr('widget_border_style')),
                RadioGroup<String>(
                  groupValue:
                      const ['hidden', 'dotted', 'solid'].contains(style)
                      ? style
                      : 'hidden',
                  onChanged: (v) {
                    if (!_saving && v != null) _set('widget_border_style', v);
                  },
                  child: Column(
                    children: [
                      for (final b in const ['hidden', 'dotted', 'solid'])
                        RadioListTile<String>(
                          contentPadding: EdgeInsets.zero,
                          value: b,
                          title: Text(context.tr(b)),
                        ),
                    ],
                  ),
                ),
                Text(
                  context.tr('widget_border_style_help'),
                  style: TextStyle(color: context.inTheme.ink3, fontSize: 12),
                ),
                IgnorePointer(
                  ignoring: _saving,
                  child: ColorInput(
                    labelKey: 'widget_border_color',
                    value: '${_settings['widget_border_color'] ?? ''}',
                    defaultValue: '#FF5733',
                    onChanged: (v) =>
                        _set('widget_border_color', v.isEmpty ? '#FF5733' : v),
                  ),
                ),
                Text(
                  context.tr('widget_border_color_help'),
                  style: TextStyle(color: context.inTheme.ink3, fontSize: 12),
                ),
              ],
            ),
          ],
        );
    }
  }
}

/// React's email templates page: one tab per template, a subject and a
/// plain-text body each, saved all at once.
class _EmailTemplatesTab extends StatefulWidget {
  const _EmailTemplatesTab({required this.api, required this.save});

  final DocuNinjaApi api;

  /// The AppBar's Save, while this tab shows.
  final _TabSave save;

  @override
  State<_EmailTemplatesTab> createState() => _EmailTemplatesTabState();
}

class _EmailTemplatesTabState extends State<_EmailTemplatesTab>
    with AutomaticKeepAliveClientMixin {
  List<DnEmailTemplate>? _templates;
  final _subjects = <String, TextEditingController>{};
  final _bodies = <String, TextEditingController>{};
  int _selected = 0;
  bool _failed = false;
  bool _saving = false;

  /// Bumped on every change, so the unsaved-changes guard re-asks; merged
  /// with the text fields once they exist.
  final _revision = ValueNotifier<int>(0);
  late Listenable _changes = _revision;

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _revision.value++;
    _publishSave();
  }

  /// Save once the templates are read.
  void _publishSave() => widget.save.publish(
    onSave: (_templates?.isEmpty ?? true) || _failed ? null : _save,
    saving: _saving,
  );

  /// A subject or body differs from the templates as last read or saved.
  bool get _isDirty =>
      _templates?.any(
        (t) =>
            _subjects[t.id]?.text != t.subject || _bodies[t.id]?.text != t.body,
      ) ??
      false;

  /// Back to the templates as saved (the user chose Discard).
  void _discard() => setState(() {
    for (final t in _templates ?? const <DnEmailTemplate>[]) {
      _subjects[t.id]?.text = t.subject;
      _bodies[t.id]?.text = t.body;
    }
  });

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _publishSave();
    _load();
  }

  @override
  void dispose() {
    for (final c in [..._subjects.values, ..._bodies.values]) {
      c.dispose();
    }
    _revision.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final templates = await widget.api.emailTemplates();
      if (!mounted) return;
      for (final t in templates) {
        _subjects[t.id]?.dispose();
        _bodies[t.id]?.dispose();
        _subjects[t.id] = TextEditingController(text: t.subject);
        _bodies[t.id] = TextEditingController(text: t.body);
      }
      setState(() {
        _templates = templates;
        _changes = Listenable.merge([
          _revision,
          ..._subjects.values,
          ..._bodies.values,
        ]);
      });
    } on Object catch (e, st) {
      _log.warning('Reading DocuNinja email templates failed', e, st);
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _save() async {
    final templates = _templates;
    if (templates == null || _saving) return;
    setState(() => _saving = true);
    try {
      final next = [
        for (final t in templates)
          t.copyWith(subject: _subjects[t.id]!.text, body: _bodies[t.id]!.text),
      ];
      await widget.api.saveEmailTemplates(next);
      if (!mounted) return;
      // Saved: what is on screen is now what the server holds.
      setState(() => _templates = next);
      Notify.success(context, context.tr('template_updated'));
    } on Object catch (e, st) {
      _log.warning('Saving DocuNinja email templates failed', e, st);
      if (mounted) {
        Notify.error(context, context.tr('an_error_occurred_try_again'));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return UnsavedChangesScope(
      isDirty: () => _isDirty,
      source: _changes,
      onDiscard: _discard,
      child: _tab(context),
    );
  }

  Widget _tab(BuildContext context) {
    final templates = _templates;
    if (_failed) {
      return ErrorView(
        message: context.tr('an_error_occurred_try_again'),
        onRetry: _load,
      );
    }
    if (templates == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (templates.isEmpty) {
      return EmptyState(
        icon: Icons.mail_outline,
        title: context.tr('no_templates_found'),
      );
    }
    final current = templates[_selected.clamp(0, templates.length - 1)];
    return _TabBody(
      children: [
        FormSection(
          title: context.tr('email_templates'),
          children: [
            DropdownButtonFormField<int>(
              initialValue: _selected.clamp(0, templates.length - 1),
              decoration: InputDecoration(labelText: context.tr('template')),
              items: [
                for (var i = 0; i < templates.length; i++)
                  DropdownMenuItem(value: i, child: Text(templates[i].name)),
              ],
              onChanged: (i) => setState(() => _selected = i ?? 0),
            ),
            TextField(
              key: ValueKey('subject:${current.id}'),
              controller: _subjects[current.id],
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(labelText: context.tr('subject')),
              onSubmitted: (_) => _save(),
            ),
            TextField(
              key: ValueKey('body:${current.id}'),
              controller: _bodies[current.id],
              minLines: 6,
              maxLines: 16,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: context.tr('body'),
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
        SizedBox(height: InSpacing.lg(context)),
        // React's variables card: the Twig tokens the server fills in.
        FormSection(
          title: context.tr('variables'),
          children: [
            for (final (group, tokens) in _kVariables)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr(group),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: InSpacing.sm,
                    runSpacing: InSpacing.sm,
                    children: [
                      for (final t in tokens) _VariableChip(token: '{{ $t }}'),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

/// React's variable (`Variable.tsx`): a chip that copies its token on a
/// tap, and says so.
class _VariableChip extends StatelessWidget {
  const _VariableChip({required this.token});

  final String token;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final radius = BorderRadius.circular(InRadii.r1);
    return Tooltip(
      message: context.tr('copy'),
      waitDuration: const Duration(milliseconds: 400),
      child: Material(
        color: tokens.surfaceAlt,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: tokens.border),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: () => copyToClipboard(context, token),
          child: Semantics(
            button: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LtrText(
                    token,
                    style: TextStyle(
                      color: tokens.ink2,
                      fontSize: 12,
                      fontFamily: kMonoFontFamily,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.content_copy, size: 12, color: tokens.ink3),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// React's `docu_*` variables (`customize/common/variables.ts`).
const _kVariables = <(String, List<String>)>[
  (
    'company',
    [
      'company.name',
      'company.address1',
      'company.address2',
      'company.city',
      'company.state',
      'company.postal_code',
    ],
  ),
  ('document', ['document.description', 'document.link']),
  (
    'sender',
    [
      'sender.first_name',
      'sender.last_name',
      'sender.phone_number',
      'sender.email',
      'sender.name',
    ],
  ),
  (
    'user',
    [
      'user.first_name',
      'user.last_name',
      'user.phone_number',
      'user.email',
      'user.name',
    ],
  ),
  (
    'contact',
    [
      'contact.first_name',
      'contact.last_name',
      'contact.phone',
      'contact.email',
      'contact.name',
    ],
  ),
];

/// React's reminder schedules: a toggle per schedule that saves at once,
/// edit and delete, and an add.
class _ReminderSchedulesTab extends StatefulWidget {
  const _ReminderSchedulesTab({required this.api});

  final DocuNinjaApi api;

  @override
  State<_ReminderSchedulesTab> createState() => _ReminderSchedulesTabState();
}

class _ReminderSchedulesTabState extends State<_ReminderSchedulesTab>
    with AutomaticKeepAliveClientMixin {
  List<DnReminderSchedule>? _schedules;
  bool _failed = false;
  bool _busy = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final schedules = await widget.api.reminderSchedules();
      if (mounted) setState(() => _schedules = schedules);
    } on Object catch (e, st) {
      _log.warning('Reading DocuNinja reminder schedules failed', e, st);
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _run(Future<void> Function() action, String successKey) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      Notify.success(context, context.tr(successKey));
      await _load();
    } on Object catch (e, st) {
      _log.warning('DocuNinja reminder schedule action failed', e, st);
      if (mounted) {
        Notify.error(context, context.tr('an_error_occurred_try_again'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit([DnReminderSchedule? schedule]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _ReminderScheduleDialog(api: widget.api, schedule: schedule),
    );
    if (saved != true || !mounted) return;
    Notify.success(
      context,
      context.tr(
        schedule == null
            ? 'created_reminder_schedule'
            : 'updated_reminder_schedule',
      ),
    );
    await _load();
  }

  Future<void> _delete(DnReminderSchedule s) async {
    final ok = await showConfirmActionDialog(
      context,
      title: context.tr('delete'),
      subject: s.name,
      destructive: true,
    );
    if (!ok || !mounted) return;
    await _run(
      () => widget.api.deleteReminderSchedule(s.id),
      'deleted_reminder_schedule',
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final schedules = _schedules;
    if (_failed) {
      return ErrorView(
        message: context.tr('an_error_occurred_try_again'),
        onRetry: _load,
      );
    }
    if (schedules == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final tokens = context.inTheme;
    return _TabBody(
      children: [
        FormSection(
          title: context.tr('reminder_schedules'),
          // An icon: the header has no room for the label at a large text
          // size on a phone.
          trailing: IconButton(
            icon: const Icon(Icons.add),
            tooltip: context.tr('add_reminder_schedule'),
            onPressed: _busy ? null : () => _edit(),
          ),
          children: [
            if (schedules.isEmpty)
              Text(
                context.tr('no_reminder_schedules_found'),
                style: TextStyle(color: tokens.ink3),
              )
            else
              for (final s in schedules)
                Row(
                  children: [
                    // Named for a screen reader: the switch saves at once.
                    Semantics(
                      label: s.name,
                      child: Switch(
                        value: s.enabled,
                        onChanged: _busy
                            ? null
                            : (v) => _run(
                                () => widget.api.setReminderScheduleEnabled(
                                  s.id,
                                  v,
                                ),
                                'updated_reminder_schedule',
                              ),
                      ),
                    ),
                    const SizedBox(width: InSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.name,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            '${s.numDays} ${context.tr('days')} '
                            '${context.tr(s.direction)}',
                            style: TextStyle(color: tokens.ink3, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: context.tr('edit'),
                      onPressed: _busy ? null : () => _edit(s),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: context.tr('delete'),
                      onPressed: _busy ? null : () => _delete(s),
                    ),
                  ],
                ),
          ],
        ),
      ],
    );
  }
}

/// React's reminder schedule modal. New schedules start at one day after
/// the event, enabled; React has no control for the direction, so an edit
/// keeps it.
class _ReminderScheduleDialog extends StatefulWidget {
  const _ReminderScheduleDialog({required this.api, this.schedule});

  final DocuNinjaApi api;
  final DnReminderSchedule? schedule;

  @override
  State<_ReminderScheduleDialog> createState() =>
      _ReminderScheduleDialogState();
}

class _ReminderScheduleDialogState extends State<_ReminderScheduleDialog> {
  late final _name = TextEditingController(text: widget.schedule?.name);
  late final _subject = TextEditingController(text: widget.schedule?.subject);
  late final _body = TextEditingController(text: widget.schedule?.body);
  late final _days = TextEditingController(
    text: '${widget.schedule?.numDays ?? 1}',
  );
  late bool _enabled = widget.schedule?.enabled ?? true;
  bool _saving = false;
  Map<String, List<String>> _errors = const {};

  @override
  void dispose() {
    for (final c in [_name, _subject, _body, _days]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _error(String field) => _errors[field]?.first;

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _errors = const {};
    });
    final schedule = DnReminderSchedule(
      id: widget.schedule?.id ?? '',
      name: _name.text.trim(),
      subject: _subject.text.trim(),
      body: _body.text,
      numDays: int.tryParse(_days.text.trim()) ?? 0,
      direction: widget.schedule?.direction ?? 'after_event',
      enabled: _enabled,
      isDeleted: false,
    );
    try {
      await widget.api.saveReminderSchedule(schedule, id: widget.schedule?.id);
      if (mounted) Navigator.of(context).pop(true);
    } on DocuNinjaException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errors = e.fieldErrors;
      });
      if (e.fieldErrors.isEmpty) {
        Notify.error(context, context.tr('an_error_occurred_try_again'));
      }
    } on Object catch (e, st) {
      _log.warning('Saving the DocuNinja reminder schedule failed', e, st);
      if (!mounted) return;
      setState(() => _saving = false);
      Notify.error(context, context.tr('an_error_occurred_try_again'));
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      scrollable: true,
      title: Text(
        context.tr(
          widget.schedule == null
              ? 'add_reminder_schedule'
              : 'edit_reminder_schedule',
        ),
      ),
      content: SizedBox(
        width: 520,
        child: FormSaveScope(
          onSubmit: _save,
          enabled: !_saving,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: context.tr('name'),
                  errorText: _error('name'),
                ),
                onSubmitted: (_) => _save(),
              ),
              TextField(
                controller: _subject,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: context.tr('subject'),
                  errorText: _error('subject'),
                ),
                onSubmitted: (_) => _save(),
              ),
              TextField(
                controller: _body,
                minLines: 4,
                maxLines: 10,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: context.tr('body'),
                  alignLabelWithHint: true,
                  errorText: _error('body'),
                ),
              ),
              TextField(
                controller: _days,
                keyboardType: TextInputType.number,
                // Whole days only: anything else would save as 0.
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: context.tr('num_days'),
                  errorText: _error('num_days'),
                ),
                onSubmitted: (_) => _save(),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _enabled,
                title: Text(context.tr('enabled')),
                onChanged: _saving ? null : (v) => setState(() => _enabled = v),
              ),
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
          label: context.tr(widget.schedule == null ? 'add' : 'save'),
          autofocus: false,
          busy: _saving,
          onPressed: _save,
        ),
      ],
    ),
  );
}
