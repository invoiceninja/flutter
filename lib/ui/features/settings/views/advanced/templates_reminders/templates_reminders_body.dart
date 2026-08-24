import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/value/static_template.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/settings/state/settings_level_controller.dart';
import 'package:admin/ui/features/settings/view_models/settings_draft_view_model.dart';
import 'package:admin/ui/features/settings/views/advanced/templates_reminders/preview_controller.dart';
import 'package:admin/ui/features/settings/views/advanced/templates_reminders/template_options.dart';
import 'package:admin/ui/features/settings/views/advanced/templates_reminders/widgets/reminder_rule_section.dart';
import 'package:admin/ui/features/settings/views/advanced/templates_reminders/widgets/template_preview_panel.dart';
import 'package:admin/ui/features/settings/views/advanced/templates_reminders/widgets/template_variables_card.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/settings/widgets/overridable_markdown_field.dart';
import 'package:admin/ui/features/settings/widgets/overridable_text_field.dart';
import 'package:admin/ui/features/settings/widgets/plan_gate_banner.dart';
import 'package:admin/utils/formatting.dart';

/// Localization keys surfaced by the in-app settings search. Spread into
/// `kSettingsSearchCatalog['templates_and_reminders']` in
/// `settings_search_catalog.dart`. The `search_catalog_consistency_test`
/// enforces this list matches every `context.tr(...)` literal used by
/// this screen + its sub-widgets.
const kTemplatesRemindersSearchKeys = <String>[
  'template',
  'subject',
  'body',
  'first_reminder',
  'second_reminder',
  'third_reminder',
  'endless_reminder',
  'quote_reminder1',
  'days',
  'schedule',
  'send_email',
  'frequency',
  'late_fee_amount',
  'late_fee_percent',
  'after_invoice_date',
  'before_due_date',
  'after_due_date',
  'after_quote_date',
  'before_valid_until_date',
  'after_valid_until_date',
  'variables',
  'view_docs',
  'preview',
];

const double _kPreviewBreakpoint = 1100;
const String _kDocsUrl =
    'https://invoiceninja.github.io/en/advanced-settings/#templates_and_reminders';

class TemplatesRemindersBody extends StatefulWidget {
  const TemplatesRemindersBody({super.key});

  @override
  State<TemplatesRemindersBody> createState() => _TemplatesRemindersBodyState();
}

class _TemplatesRemindersBodyState extends State<TemplatesRemindersBody> {
  late final ValueNotifier<String> _selectedTemplate;
  late final PreviewController _preview;
  Formatter? _formatter;
  bool _wasSaving = false;
  // Memoize the last scheduled (template, subject, body) tuple so the
  // post-frame schedule no-ops on rebuilds that don't actually change the
  // preview inputs (theme change, viewport change, save round-trip, etc.).
  // PreviewController.schedule() coalesces correctly via its debounce, but
  // cancelling + restarting the timer on every keystroke + every unrelated
  // rebuild is wasteful — this short-circuit avoids that churn.
  String? _lastScheduledTemplate;
  String? _lastScheduledSubject;
  String? _lastScheduledBody;

  static final _log = Logger('TemplatesRemindersBody');

  @override
  void initState() {
    super.initState();
    _selectedTemplate = ValueNotifier<String>('invoice');
    final services = context.read<Services>();
    _preview = PreviewController(api: services.templates);
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    if (companyId.isNotEmpty) {
      services
          .formatterFor(companyId)
          .then((f) {
            if (mounted) setState(() => _formatter = f);
          })
          .catchError((Object e, StackTrace st) {
            // Late-fee currency field hides when no formatter — log so the
            // diagnostics buffer captures the underlying cause (statics
            // failure, missing company row, etc.).
            _log.warning('Formatter unavailable', e, st);
          });
    }
  }

  @override
  void dispose() {
    _selectedTemplate.dispose();
    _preview.dispose();
    super.dispose();
  }

  /// Force a fresh preview when the save round-trip completes (`isSaving`
  /// transitions true → false with no error). Re-reads the current draft
  /// rather than re-firing the cached last request — the user may have
  /// edited subject/body between the save being initiated and the response
  /// landing, and the preview should reflect what's on screen now.
  void _maybeRefreshAfterSave(SettingsDraftHost host) {
    final saving = host.isSaving;
    final wasSaving = _wasSaving;
    _wasSaving = saving;
    if (wasSaving && !saving && host.submitError == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _schedulePreview(immediate: true);
      });
    }
  }

  void _schedulePreview({required bool immediate}) {
    // Free plans can't change templates, and the hosted server 403s the
    // `/templates` endpoint for them — skip the preview so the panel stays on
    // its idle placeholder instead of flashing repeated "error, retry" states.
    final session = context.read<Services>().auth.session.value;
    if (!(session?.hasProAccess ?? false)) return;
    final host = context.read<SettingsDraftHost>();
    final tplKey = _selectedTemplate.value;
    final option = _findOption(tplKey);
    final subject = _readByKey(host, option.subjectKey) ?? '';
    final body = _readByKey(host, option.templateKey) ?? '';
    if (!immediate &&
        tplKey == _lastScheduledTemplate &&
        subject == _lastScheduledSubject &&
        body == _lastScheduledBody) {
      // Same inputs as last schedule — bail out so we don't churn the
      // debounce timer on unrelated rebuilds.
      return;
    }
    _lastScheduledTemplate = tplKey;
    _lastScheduledSubject = subject;
    _lastScheduledBody = body;
    _preview.schedule(
      template: tplKey,
      subject: subject,
      body: body,
      immediate: immediate,
    );
  }

  String? _readByKey(SettingsDraftHost host, String apiKey) {
    final json = host.settings.toJson();
    final v = json[apiKey];
    return v is String ? v : null;
  }

  TemplateOption _findOption(String key) =>
      kTemplateOptions.firstWhere((o) => o.key == key);

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final host = context.watch<SettingsDraftHost>();
    final scope = context.watch<SettingsLevelController>();
    // Listen for save round-trip completions to refresh the preview.
    _maybeRefreshAfterSave(host);
    final session = services.auth.session.value;
    final isProOrEnterprise = session?.hasProAccess ?? false;
    // Read the active company's module mask off the session, not `host.draft`
    // (which is null at client/group scope → would gate every module-bound
    // template off there). Mirrors online_payments_defaults_body + the settings
    // sidebar (settings_screen.dart). `companyContext` can't be used — its
    // sparse Company omits enabledModules.
    final enabledModules = session?.currentCompany?.enabledModules ?? 0;
    final options = visibleTemplateOptions(enabledModules);
    final templateKey = _selectedTemplate.value;
    final selected = options.any((o) => o.key == templateKey)
        ? _findOption(templateKey)
        : options.first;

    final width = MediaQuery.sizeOf(context).width;
    final showInlinePreview = width >= _kPreviewBreakpoint;

    // Listen to host edits so the preview tracks subject/body changes via
    // the debounced controller. Cheap — `addPostFrameCallback` re-fires on
    // every rebuild but `schedule` coalesces internally.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _schedulePreview(immediate: false);
    });

    final editor = _Editor(
      template: selected,
      isProOrEnterprise: isProOrEnterprise,
      formatter: _formatter,
      currencyId: host.settings.currencyId ?? '',
      isCompanyScope: scope.isCompany,
      staticTemplates: services.statics.templates,
    );

    final auxiliary = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TemplateVariablesCard(templateKey: selected.key),
        // Actionable Preview sits above the "further reading" docs link
        // (invoiceninja/flutter#77).
        if (!showInlinePreview) _ShowPreviewButton(controller: _preview),
        _ViewDocsButton(),
      ],
    );

    final pickerCard = FormSection(
      title: context.tr('template'),
      children: [
        _TemplatePicker(
          options: options,
          selectedKey: selected.key,
          onChanged: (key) {
            setState(() {
              _selectedTemplate.value = key;
            });
            // Kick off a fresh preview for the new template — the
            // KeyedSubtree swap discards the old field state but the new
            // subject/body live on the draft and need to be rendered.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _schedulePreview(immediate: true);
            });
          },
        ),
      ],
    );

    // Plan banner is rendered first inside `body` when not on a paid
    // plan — matches React's `<canChangeEmailTemplate=false>` branch
    // (TemplatesAndReminders.tsx:432).
    Widget body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const PlanGateBanner(style: PlanGateStyle.inset),
        pickerCard,
        // Per-template `ValueKey` forces fresh state for the editor +
        // rule controllers. Mirrors v1 pattern (admin-portal
        // templates_and_reminders.dart:442/462/481/500).
        KeyedSubtree(key: ValueKey('editor_${selected.key}'), child: editor),
        if (selected.isReminder)
          KeyedSubtree(
            key: ValueKey('rule_${selected.key}'),
            child: ReminderRuleSection(
              template: selected,
              // Nullable: the section falls back to a plain number field for
              // the late-fee amount when no formatter loaded, so reminder
              // config is never hidden outright.
              formatter: _formatter,
              currencyId: host.settings.currencyId ?? '',
              // Plan-gate the rule fields like the subject/body editors.
              enabled: isProOrEnterprise,
            ),
          ),
        auxiliary,
        if (!showInlinePreview) SizedBox(height: InSpacing.lg(context)),
      ],
    );

    // Pad the body to keep the markdown editor above the iOS keyboard.
    body = Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: body,
    );

    if (showInlinePreview) {
      // Side-by-side: editor column on the left (max 720 to mirror the
      // form-shell width cap), preview column on the right.
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: InSpacing.lg(context),
          vertical: InSpacing.lg(context),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: SingleChildScrollView(child: body),
              ),
            ),
            SizedBox(width: InSpacing.lg(context)),
            Expanded(
              flex: 4,
              child: SizedBox(
                // Stick to viewport height so the preview stays visible
                // while the editor scrolls underneath. Clamp to non-negative
                // so an extremely short (but ≥1100-wide) window can't hand
                // SizedBox a negative height.
                height: (MediaQuery.sizeOf(context).height - 200).clamp(
                  0.0,
                  double.infinity,
                ),
                child: TemplatePreviewPanel(controller: _preview),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: InSpacing.lg(context),
        vertical: InSpacing.lg(context),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: body,
      ),
    );
  }
}

class _Editor extends StatelessWidget {
  const _Editor({
    required this.template,
    required this.isProOrEnterprise,
    required this.formatter,
    required this.currencyId,
    required this.isCompanyScope,
    required this.staticTemplates,
  });

  final TemplateOption template;
  final bool isProOrEnterprise;
  final Formatter? formatter;
  final String currencyId;
  final bool isCompanyScope;
  final Map<String, StaticTemplate> staticTemplates;

  @override
  Widget build(BuildContext context) {
    // Show the statics-default subject as a placeholder hint at company
    // scope. At group/client scope the override-checkbox machinery in
    // `OverridableField.bind` already surfaces the cascaded parent value,
    // so doubling up with a statics hint would just be noise.
    final defaultSubject = isCompanyScope
        ? (staticTemplates[template.key]?.subject ?? '')
        : '';
    return FormSection(
      title: context.tr(template.labelKey),
      children: [
        OverridableTextField(
          label: context.tr('subject'),
          apiKey: template.subjectKey,
          enabled: isProOrEnterprise,
          hintText: defaultSubject.isEmpty ? null : defaultSubject,
        ),
        // Unlike the subject, the body shows no statics-default placeholder:
        // MarkdownTextField/super_editor exposes no placeholder slot, and the
        // default body is a full template blob that reads poorly as a caption.
        // Harmless — an empty body still renders the server default, and the
        // subject hint already signals that defaults exist.
        OverridableMarkdownField(
          label: context.tr('body'),
          apiKey: template.templateKey,
          enabled: isProOrEnterprise,
          // 150 ms is tight enough to keep the downstream preview debounce
          // (400 ms) under a 600 ms total perceived latency.
          debounce: const Duration(milliseconds: 150),
        ),
      ],
    );
  }
}

class _TemplatePicker extends StatelessWidget {
  const _TemplatePicker({
    required this.options,
    required this.selectedKey,
    required this.onChanged,
  });

  final List<TemplateOption> options;
  final String selectedKey;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: selectedKey,
      isExpanded: true,
      decoration: InputDecoration(labelText: context.tr('template')),
      items: [
        for (final o in options)
          DropdownMenuItem<String>(
            value: o.key,
            child: Text(context.tr(o.labelKey)),
          ),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

class _ViewDocsButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: OutlinedButton.icon(
        onPressed: () => unawaited(launchUrl(Uri.parse(_kDocsUrl))),
        icon: const Icon(Icons.open_in_new, size: 16),
        label: Text(context.tr('view_docs')),
        style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
      ),
    );
  }
}

class _ShowPreviewButton extends StatelessWidget {
  const _ShowPreviewButton({required this.controller});

  final PreviewController controller;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.visibility_outlined, size: 16),
        label: Text(context.tr('preview')),
        style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
        onPressed: () => showTemplatePreviewScreen(context, controller),
      ),
    );
  }
}

/// Full-screen template preview. Modal sub-flow (not page navigation) — see
/// the routing rule in `docs/architecture.md` § Navigation.
Future<void> showTemplatePreviewScreen(
  BuildContext context,
  PreviewController controller,
) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => _PreviewSheet(controller: controller),
    ),
  );
}

class _PreviewSheet extends StatelessWidget {
  const _PreviewSheet({required this.controller});

  final PreviewController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('preview'))),
      body: Padding(
        padding: EdgeInsets.all(InSpacing.lg(context)),
        child: TemplatePreviewPanel(controller: controller),
      ),
    );
  }
}
