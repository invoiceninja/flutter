import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:re_editor/re_editor.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/design.dart';
import 'package:admin/data/services/live_design_service.dart';
import 'package:admin/data/static/design_template_completions.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/dialogs/discard_changes_dialog.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/features/settings/view_models/design_edit_view_model.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/widgets/design_code_field.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/widgets/design_live_preview_pane.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/settings/widgets/plan_gate_banner.dart';
import 'package:admin/ui/features/settings/widgets/settings_entity_edit_scaffold.dart';
import 'package:admin/ui/features/settings/widgets/settings_text_field.dart';

/// Wide-window breakpoint: at or above this the editor and the live preview
/// sit side-by-side; below it the editor is full-width and the preview is a
/// "Preview" button → full-screen modal. Matches General Settings.
const double _kSplitBreakpoint = 1024;

const String _kTemplateDocsUrl =
    'https://invoiceninja.github.io/docs/advanced-topics/templates';

/// One editable template section. Ordered to match the editor tabs.
enum _Section {
  settings,
  body,
  header,
  footer,
  product,
  task,
  includes,
  variables,
}

const _htmlSections = <_Section>[
  _Section.body,
  _Section.header,
  _Section.footer,
  _Section.product,
  _Section.task,
  _Section.includes,
];

extension on _Section {
  String get key => switch (this) {
    _Section.settings => 'settings',
    _Section.body => 'body',
    _Section.header => 'header',
    _Section.footer => 'footer',
    _Section.product => 'product',
    _Section.task => 'task',
    _Section.includes => 'includes',
    _Section.variables => 'variables',
  };

  /// One-line help shown above the editor so authors know what each section
  /// is for (the rarely-needed ones are flagged "advanced").
  String? get helpKey => switch (this) {
    _Section.body => 'design_help_body',
    _Section.header => 'design_help_header',
    _Section.footer => 'design_help_footer',
    _Section.product => 'design_help_product',
    _Section.task => 'design_help_task',
    _Section.includes => 'design_help_includes',
    _ => null,
  };
}

/// Create / edit a custom [Design]. Reached from the Custom Designs tab.
/// Lifecycle / AppBar / Save / overflow are owned by
/// [SettingsEntityEditScaffold]; the body is the two-pane editor workspace.
///
/// [seedFrom] pre-fills a brand-new design from another design (the
/// "Duplicate a built-in" / "Edit a copy" flow). [startInHtml] opens
/// straight on the Body editor instead of the code-free Settings tab.
class DesignEditScreen extends StatelessWidget {
  const DesignEditScreen({
    this.existingId,
    this.seedFrom,
    this.importJson,
    this.startInHtml = false,
    super.key,
  });

  final String? existingId;
  final Design? seedFrom;

  /// Raw exported-design JSON to seed a brand-new design from (Import flow).
  final String? importJson;
  final bool startInHtml;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    final repo = services.designs;
    // Custom designs are Pro-gated (parity with React / admin-portal). Entry is
    // blocked upstream in the Custom Designs tab; this gates Save as a backstop.
    final isPro = services.auth.session.value?.hasProAccess ?? false;

    return SettingsEntityEditScaffold<Design, DesignEditViewModel>(
      existingId: existingId,
      backRoute: '/settings/invoice_design/custom_designs',
      createTitleKey: 'new_design',
      editTitleKey: 'edit_design',
      wireName: 'design',
      watchById: (id) => repo.watch(companyId: companyId, id: id),
      refreshAll: () => repo.refreshAll(companyId: companyId),
      onArchive: (id) => repo.archive(companyId: companyId, id: id),
      onRestore: (id) => repo.restore(companyId: companyId, id: id),
      onDelete: (id) => repo.delete(companyId: companyId, id: id),
      vmFactory: ({existing}) => DesignEditViewModel(
        repo: repo,
        companyId: companyId,
        existing: existing,
        sync: services.sync,
        connectivity: services.connectivity,
      ),
      isArchivedOf: (d) => d.archivedAt != null,
      isDeletedOf: (d) => d.isDeleted,
      // A nameless design renders as its UUID in the picker dropdowns.
      canSave: (vm) =>
          isPro &&
          !vm.isSaving &&
          vm.isDirty &&
          vm.draft.name.trim().isNotEmpty,
      // Pushed as a bare MaterialPageRoute (no settings-shell guard), so opt
      // into the scaffold's own confirm-on-pop.
      guardUnsavedChanges: true,
      onDiscard: (vm) => vm.resetToEmpty(),
      customBodyBuilder: (context, vm) => Column(
        children: [
          // Backstop banner — explains the disabled Save if a free user ever
          // reaches this editor (auto-hides for Pro/trial).
          const PlanGateBanner(style: PlanGateStyle.inset),
          Expanded(
            child: _DesignWorkspace(
              vm: vm,
              companyId: companyId,
              seedFrom: seedFrom,
              importJson: importJson,
              startInHtml: startInHtml,
            ),
          ),
        ],
      ),
    );
  }
}

class _DesignWorkspace extends StatefulWidget {
  const _DesignWorkspace({
    required this.vm,
    required this.companyId,
    required this.seedFrom,
    required this.importJson,
    required this.startInHtml,
  });

  final DesignEditViewModel vm;
  final String companyId;
  final Design? seedFrom;
  final String? importJson;
  final bool startInHtml;

  @override
  State<_DesignWorkspace> createState() => _DesignWorkspaceState();
}

class _DesignWorkspaceState extends State<_DesignWorkspace> {
  late _Section _section = widget.startInHtml
      ? _Section.body
      : _Section.settings;

  /// The HTML section the user last had open — variable inserts target it
  /// even while the Variables tab is showing.
  _Section _lastHtmlSection = _Section.body;

  /// Live code controllers, keyed by section, for tap-to-insert variables.
  final Map<_Section, CodeLineEditingController> _controllers = {};

  /// section → first validation message from the latest 422 render.
  Map<String, String> _sectionErrors = const {};

  late final LiveDesignService _service = LiveDesignService(
    context.read<Services>().apiClient,
  );

  @override
  void initState() {
    super.initState();
    final seed = widget.seedFrom;
    final importJson = widget.importJson;
    if (seed != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.vm.loadFrom(seed);
      });
    } else if (importJson != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // Surface a parse failure instead of silently opening a blank editor —
        // the import dialog passes the raw text through without validating.
        final error = widget.vm.importFromJson(importJson);
        if (error != null) {
          Notify.error(context, context.tr(error));
        }
      });
    }
  }

  void _select(_Section s) {
    setState(() {
      _section = s;
      if (_htmlSections.contains(s)) _lastHtmlSection = s;
    });
  }

  void _insertVariable(String v) {
    final c = _controllers[_lastHtmlSection];
    if (c == null) return;
    // Template-mode Twig chips (`{{ … }}`) only render inside a
    // `<ninja>...</ninja>` block. Outside one, auto-wrap so the variable
    // works — otherwise the chip would silently insert literal HTML.
    final isTwig = v.startsWith('{{') || v.startsWith('{%');
    if (widget.vm.draft.isTemplate && isTwig && !isCaretInNinja(c)) {
      c.replaceSelection('<ninja>$v</ninja>');
    } else {
      c.replaceSelection(v);
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    return StreamBuilder<Company?>(
      stream: services.company.watchCompany(widget.companyId),
      builder: (context, snap) {
        final company = snap.data;
        final editor = _EditorColumn(
          vm: widget.vm,
          section: _section,
          sectionErrors: _sectionErrors,
          controllers: _controllers,
          company: company,
          onSelect: _select,
          onInsertVariable: _insertVariable,
        );
        final pane = DesignLivePreviewPane(
          service: _service,
          vm: widget.vm,
          enabledModulesBitmask: company?.enabledModules ?? 0,
          embedded: true,
          onSectionErrors: (e) {
            if (mounted) setState(() => _sectionErrors = e);
          },
        );
        return LayoutBuilder(
          builder: (context, c) {
            if (c.maxWidth < _kSplitBreakpoint) {
              return Column(
                children: [
                  Padding(
                    padding: EdgeInsets.all(InSpacing.md(context)),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(64, 40),
                        ),
                        onPressed: () => _openPreviewModal(
                          context,
                          services,
                          company?.enabledModules ?? 0,
                        ),
                        icon: const Icon(Icons.visibility_outlined, size: 18),
                        label: Text(context.tr('preview')),
                      ),
                    ),
                  ),
                  Expanded(child: editor),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 3, child: editor),
                const VerticalDivider(width: 1),
                Expanded(flex: 2, child: pane),
              ],
            );
          },
        );
      },
    );
  }

  void _openPreviewModal(
    BuildContext context,
    Services services,
    int enabledModules,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog.fullscreen(
          child: Scaffold(
            appBar: AppBar(
              title: Text(context.tr('preview')),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
            ),
            body: DesignLivePreviewPane(
              service: _service,
              vm: widget.vm,
              enabledModulesBitmask: enabledModules,
              onSectionErrors: (e) {
                if (mounted) setState(() => _sectionErrors = e);
              },
            ),
          ),
        );
      },
    );
  }
}

/// Left column: section selector + the active pane.
class _EditorColumn extends StatelessWidget {
  const _EditorColumn({
    required this.vm,
    required this.section,
    required this.sectionErrors,
    required this.controllers,
    required this.company,
    required this.onSelect,
    required this.onInsertVariable,
  });

  final DesignEditViewModel vm;
  final _Section section;
  final Map<String, String> sectionErrors;
  final Map<_Section, CodeLineEditingController> controllers;
  final Company? company;
  final ValueChanged<_Section> onSelect;
  final ValueChanged<String> onInsertVariable;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTabs(
          current: section,
          sectionErrors: sectionErrors,
          onSelect: onSelect,
        ),
        const Divider(height: 1),
        Expanded(
          child: Padding(
            padding: EdgeInsets.all(InSpacing.lg(context)),
            // IndexedStack keeps every code editor mounted so switching
            // tabs preserves cursor/scroll and variable-insert can target
            // a section that isn't currently visible.
            child: IndexedStack(
              index: _Section.values.indexOf(section),
              sizing: StackFit.expand,
              children: [for (final s in _Section.values) _paneFor(context, s)],
            ),
          ),
        ),
      ],
    );
  }

  Widget _paneFor(BuildContext context, _Section s) {
    if (s == _Section.settings) {
      return _SettingsPane(vm: vm, company: company);
    }
    if (s == _Section.variables) {
      return _VariablesPane(
        onInsert: onInsertVariable,
        isTemplate: vm.draft.isTemplate,
        entities: vm.draft.entities,
      );
    }
    return _HtmlPane(
      vm: vm,
      section: s,
      controllers: controllers,
      error: sectionErrors[s.key],
    );
  }
}

class _SectionTabs extends StatelessWidget {
  const _SectionTabs({
    required this.current,
    required this.sectionErrors,
    required this.onSelect,
  });

  final _Section current;
  final Map<String, String> sectionErrors;
  final ValueChanged<_Section> onSelect;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(
        horizontal: InSpacing.md(context),
        vertical: InSpacing.sm,
      ),
      child: Row(
        children: [
          for (final s in _Section.values)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(context.tr(s.key)),
                    if (sectionErrors.containsKey(s.key)) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.error_outline,
                        size: 14,
                        color: tokens.overdue,
                      ),
                    ],
                  ],
                ),
                selected: current == s,
                showCheckmark: false,
                onSelected: (_) => onSelect(s),
              ),
            ),
        ],
      ),
    );
  }
}

/// Code-free tab: name, start-from, template toggle, entities (templates
/// only), used-for badge.
class _SettingsPane extends StatelessWidget {
  const _SettingsPane({required this.vm, required this.company});

  final DesignEditViewModel vm;
  final Company? company;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        FormSection(
          title: context.tr('settings'),
          children: [
            SettingsTextField(
              initialValue: vm.draft.name,
              labelKey: 'name',
              onChanged: vm.setName,
              errorText: vm.fieldErrorFor('name'),
              externalSyncKey: vm.original?.id,
            ),
            _TemplateToggle(vm: vm),
            _StartFromField(vm: vm),
            // Entities picker is only meaningful for templates (which
            // can target multiple entity types). Non-template designs
            // default to a single entity and don't need the chooser.
            if (vm.draft.isTemplate) _EntitiesField(vm: vm),
            SizedBox(height: InSpacing.md(context)),
            _UsedForBadge(vm: vm, company: company),
          ],
        ),
      ],
    );
  }
}

/// `is_template` toggle. Templates use Twig (`{{ }}` / `{% %}`) inside
/// `<ninja></ninja>` blocks for bespoke documents (statements,
/// multi-invoice reports). Designs use flat `$tokens`. Flipping ON over
/// an empty body seeds the minimal Twig scaffold.
class _TemplateToggle extends StatelessWidget {
  const _TemplateToggle({required this.vm});

  final DesignEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Padding(
      padding: EdgeInsets.only(top: InSpacing.md(context)),
      child: CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        controlAffinity: ListTileControlAffinity.leading,
        value: vm.draft.isTemplate,
        onChanged: (v) => vm.setIsTemplate(v ?? false),
        title: Text(context.tr('template')),
        subtitle: Text(
          context.tr('template_help'),
          style: TextStyle(color: tokens.ink3, fontSize: 12),
        ),
        secondary: IconButton(
          tooltip: context.tr('view_docs'),
          icon: const Icon(Icons.help_outline, size: 18),
          onPressed: () => unawaited(launchUrl(Uri.parse(_kTemplateDocsUrl))),
        ),
      ),
    );
  }
}

/// Grouped Built-in / Custom / Blank picker. Selecting one replaces the
/// whole template (after a confirm if the draft already has content).
class _StartFromField extends StatelessWidget {
  const _StartFromField({required this.vm});

  final DesignEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    return StreamBuilder<List<Design>>(
      stream: services.designs.watchAll(companyId: companyId),
      builder: (context, snapshot) {
        final all = snapshot.data ?? const <Design>[];
        // Only designs that actually carry template HTML can seed.
        final seedable =
            all
                .where((d) => d.id != vm.draft.id && d.template.body.isNotEmpty)
                .toList()
              ..sort((a, b) => a.name.compareTo(b.name));
        final builtIn = seedable.where((d) => !d.isCustom).toList();
        final custom = seedable.where((d) => d.isCustom).toList();
        return Padding(
          padding: EdgeInsets.only(top: InSpacing.md(context)),
          child: DropdownButtonFormField<String>(
            initialValue: null,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: context.tr('start_from'),
              border: const OutlineInputBorder(),
            ),
            items: [
              DropdownMenuItem(
                value: '__blank__',
                child: Text(context.tr('blank')),
              ),
              if (builtIn.isNotEmpty)
                DropdownMenuItem(
                  enabled: false,
                  child: Text(
                    context.tr('built_in'),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              for (final d in builtIn)
                DropdownMenuItem(value: d.id, child: Text(d.name)),
              if (custom.isNotEmpty)
                DropdownMenuItem(
                  enabled: false,
                  child: Text(
                    context.tr('custom_designs'),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              for (final d in custom)
                DropdownMenuItem(value: d.id, child: Text(d.name)),
            ],
            onChanged: (id) async {
              if (id == null) return;
              if (vm.templateIsNonEmpty) {
                final ok = await showDiscardChangesDialog(context);
                if (!ok || !context.mounted) return;
              }
              if (id == '__blank__') {
                vm.loadBlankScaffold();
                return;
              }
              final src = seedable.firstWhere((d) => d.id == id);
              vm.loadFrom(src);
            },
          ),
        );
      },
    );
  }
}

class _EntitiesField extends StatelessWidget {
  const _EntitiesField({required this.vm});

  final DesignEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: InSpacing.md(context)),
        Text(
          context.tr('entities'),
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: 4),
        for (final e
            in vm.draft.isTemplate
                ? DesignEditViewModel.supportedTemplateEntities
                : DesignEditViewModel.supportedEntities)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            value: vm.draft.entities.contains(e),
            onChanged: (v) => vm.toggleEntity(e, v ?? false),
            title: Text(context.tr(e)),
          ),
      ],
    );
  }
}

/// "Used for: Invoices · Quotes" — warns the author that edits to a design
/// already wired up in General Settings hit issued documents.
class _UsedForBadge extends StatelessWidget {
  const _UsedForBadge({required this.vm, required this.company});

  final DesignEditViewModel vm;
  final Company? company;

  @override
  Widget build(BuildContext context) {
    final c = company;
    final id = vm.original?.id;
    if (c == null || id == null) return const SizedBox.shrink();
    final s = c.settings;
    final uses = <String>[
      if (s.invoiceDesignId == id) context.tr('invoice'),
      if (s.quoteDesignId == id) context.tr('quote'),
      if (s.creditDesignId == id) context.tr('credit'),
      if (s.purchaseOrderDesignId == id) context.tr('purchase_order'),
    ];
    final tokens = context.inTheme;
    if (uses.isEmpty) {
      return Text(
        context.tr('design_not_in_use'),
        style: TextStyle(color: tokens.ink3, fontSize: 12),
      );
    }
    return Container(
      padding: EdgeInsets.all(InSpacing.sm),
      decoration: BoxDecoration(
        color: tokens.overdueSoft,
        borderRadius: BorderRadius.circular(InRadii.r2),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 16, color: tokens.overdue),
          SizedBox(width: InSpacing.sm),
          Expanded(
            child: Text(
              '${context.tr('used_for')}: ${uses.join(' · ')}',
              style: TextStyle(color: tokens.overdue, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// One HTML section: help line + syntax editor (+ inline 422 message).
class _HtmlPane extends StatelessWidget {
  const _HtmlPane({
    required this.vm,
    required this.section,
    required this.controllers,
    required this.error,
  });

  final DesignEditViewModel vm;
  final _Section section;
  final Map<_Section, CodeLineEditingController> controllers;
  final String? error;

  String get _initial => switch (section) {
    _Section.body => vm.draft.template.body,
    _Section.header => vm.draft.template.header,
    _Section.footer => vm.draft.template.footer,
    _Section.product => vm.draft.template.product,
    _Section.task => vm.draft.template.task,
    _Section.includes => vm.draft.template.includes,
    _ => '',
  };

  void _onChanged(String v) {
    switch (section) {
      case _Section.body:
        vm.setBody(v);
      case _Section.header:
        vm.setHeader(v);
      case _Section.footer:
        vm.setFooter(v);
      case _Section.product:
        vm.setProduct(v);
      case _Section.task:
        vm.setTask(v);
      case _Section.includes:
        vm.setIncludes(v);
      case _:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final help = section.helpKey;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (help != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              context.tr(help),
              style: TextStyle(color: tokens.ink3, fontSize: 12),
            ),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              error!,
              style: TextStyle(color: tokens.overdue, fontSize: 12),
            ),
          ),
        Expanded(
          child: DesignCodeField(
            initial: _initial,
            seedRevision: vm.seedRevision,
            isTemplate: vm.draft.isTemplate,
            onChanged: _onChanged,
            insertController: (c) => controllers[section] = c,
            // Only the body section ever gets a fresh <ninja> scaffold,
            // so it's the only section that should consume the flag.
            caretToNinjaOnSeed:
                section == _Section.body && vm.consumeSeedCaretToNinja(),
          ),
        ),
      ],
    );
  }
}

/// Grouped, tap-to-insert variable reference. Catalog depends on
/// [isTemplate]: design-mode shows `$tokens`, template-mode shows the
/// Twig `{{ … }}` set. The inline editor autocomplete carries the full
/// catalog; this pane is the browseable subset.
///
/// In template mode, groups whose required entity isn't in [entities]
/// render dimmed via [isGroupEnabledForEntities]. Chips stay tappable
/// — the gray-out is informational. Design mode never gates because
/// its lone entity-named group (`$invoice.*`) actually holds generic
/// document tokens that apply to quotes / credits / POs too.
class _VariablesPane extends StatefulWidget {
  const _VariablesPane({
    required this.onInsert,
    required this.isTemplate,
    required this.entities,
  });

  final ValueChanged<String> onInsert;
  final bool isTemplate;
  final List<String> entities;

  @override
  State<_VariablesPane> createState() => _VariablesPaneState();
}

class _VariablesPaneState extends State<_VariablesPane> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final q = _query.trim().toLowerCase();
    final groups = widget.isTemplate
        ? kTwigVariableGroups
        : kDesignVariableGroups;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          decoration: InputDecoration(
            isDense: true,
            prefixIcon: const Icon(Icons.search, size: 18),
            hintText: context.tr('search'),
            border: const OutlineInputBorder(),
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
        SizedBox(height: InSpacing.sm),
        Text(
          context.tr(
            widget.isTemplate ? 'variables_hint_template' : 'variables_hint',
          ),
          style: TextStyle(color: tokens.ink3, fontSize: 12),
        ),
        SizedBox(height: InSpacing.sm),
        Expanded(
          child: ListView(
            children: [for (final g in groups) ..._group(context, g, q)],
          ),
        ),
      ],
    );
  }

  List<Widget> _group(BuildContext context, DesignVariableGroup g, String q) {
    final vars = q.isEmpty
        ? g.variables
        : g.variables.where((v) => v.toLowerCase().contains(q)).toList();
    if (vars.isEmpty) return const [];
    // Design mode never gates; template mode dims groups whose required
    // entity isn't in the draft's `entities`. Chip taps still work — the
    // gray-out is just a heads-up that the variable may not render in
    // this template's context.
    final enabled =
        !widget.isTemplate ||
        isGroupEnabledForEntities(g.titleKey, widget.entities);
    final opacity = enabled ? 1.0 : 0.45;
    return [
      Opacity(
        opacity: opacity,
        child: Padding(
          padding: EdgeInsets.only(
            top: InSpacing.md(context),
            bottom: InSpacing.sm,
          ),
          child: Text(
            context.tr(g.titleKey),
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
      ),
      Opacity(
        opacity: opacity,
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [for (final v in vars) _buildChip(v)],
        ),
      ),
    ];
  }

  /// Builds one side-pane chip. Long HTML-comment snippets (currently
  /// just the statement-template marker) get a shorter preview label
  /// plus a tooltip carrying the full insertion text and a placement
  /// hint — the raw 51-char marker would wrap ugly in a chip and the
  /// user wouldn't know it must live near the top of `<head>`.
  Widget _buildChip(String v) {
    if (v.startsWith('<!--')) {
      return Tooltip(
        message:
            'Inserts: $v\n'
            'Place near the top of <head> in a statement template.',
        child: ActionChip(
          label: const Text(
            '<!-- Statement marker -->',
            style: TextStyle(fontFamily: kMonoFontFamily, fontSize: 12),
          ),
          onPressed: () => widget.onInsert(v),
        ),
      );
    }
    return ActionChip(
      label: Text(
        v,
        style: const TextStyle(fontFamily: kMonoFontFamily, fontSize: 12),
      ),
      onPressed: () => widget.onInsert(v),
    );
  }
}
