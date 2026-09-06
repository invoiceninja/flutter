import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/design.dart';
import 'package:admin/data/static/built_in_designs_catalog.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/copyable_value.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/import_design_json_dialog.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/design_edit_screen.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/templates.dart';
import 'package:admin/ui/features/settings/views/settings_shell.dart'
    show hideSettingsListSidebar;
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/wysiwyg_design_screen.dart';
import 'package:admin/ui/features/settings/widgets/plan_gate_banner.dart';

/// Custom Designs tab body — second tab on the Invoice Design shell
/// (`/settings/invoice_design/custom_designs`).
///
/// Lists Built-in / Custom buckets. Tapping a custom row opens
/// [DesignEditScreen] for full create / edit / delete (the entity stack,
/// outbox wiring, and password gate live in [DesignRepository]); built-in
/// and template rows open the read-only [_DesignDetailScreen] since their
/// HTML isn't user-editable.
///
/// Self-contained — reads `Services` off Provider, doesn't bind to the
/// cascade VM. The tab is registered with `contributesToSave: false` so the
/// shell's Save button hides while it's active.
class CustomDesignsBody extends StatelessWidget {
  const CustomDesignsBody({super.key});

  @override
  Widget build(BuildContext context) => const _BodyImpl();
}

/// Top-bar action injected into the cascade shell's preview-toggle row
/// for the Custom Designs tab (see `TabbedSettingsTab.topBarLeading`).
/// Lives outside `CustomDesignsBody` so the shell can render it alongside
/// "Show Preview" instead of stacking it below.
class CustomDesignsNewDesignButton extends StatelessWidget {
  const CustomDesignsNewDesignButton({super.key});

  @override
  Widget build(BuildContext context) {
    // Custom designs are a Pro feature (parity with React / admin-portal).
    // For a free user the button becomes the upgrade CTA instead of opening
    // the create chooser — this gates all three create paths (visual / HTML /
    // import) at their single entry point.
    final isPro =
        context.read<Services>().auth.session.value?.hasProAccess ?? false;
    return FilledButton.icon(
      style: FilledButton.styleFrom(minimumSize: const Size(64, 40)),
      onPressed: isPro
          ? () => _showNewDesignChooser(context)
          : () => unawaited(openUpgradeFlow(context)),
      icon: const Icon(Icons.add, size: 18),
      label: Text(context.tr('new_design')),
    );
  }
}

class _BodyImpl extends StatelessWidget {
  const _BodyImpl();

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId;
    return StreamBuilder<List<Design>>(
      stream: companyId == null
          ? const Stream.empty()
          : services.designs.watchAll(companyId: companyId),
      builder: (context, snapshot) {
        final bundled = snapshot.data ?? const <Design>[];
        return _DesignsListView(bundled: bundled);
      },
    );
  }
}

/// Open the full design create/edit screen. Modal sub-flow (not page
/// navigation) — see the routing rule in `docs/architecture.md` § Navigation.
///
/// Phase 12: while the editor is open, flip [hideSettingsListSidebar] so
/// the wide-mode shell hides its 280 px sidebar column and the live
/// preview gets the reclaimed space. The flag auto-resets when the push
/// future completes (back / save / discard / system-back all funnel here).
Future<void> showDesignEditScreen(
  BuildContext context, {
  String? existingId,
  Design? seedFrom,
  String? importJson,
  bool startInHtml = false,
}) async {
  hideSettingsListSidebar.value = true;
  try {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DesignEditScreen(
          existingId: existingId,
          seedFrom: seedFrom,
          importJson: importJson,
          startInHtml: startInHtml,
        ),
      ),
    );
  } finally {
    hideSettingsListSidebar.value = false;
  }
}

/// Open the read-only design detail screen (template rows, which are not
/// editable entities). Modal sub-flow — see `docs/architecture.md`.
Future<void> showDesignDetailScreen(BuildContext context, Design design) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => _DesignDetailScreen(design: design),
    ),
  );
}

/// Entry chooser. Three options (Phase 11): the visual builder
/// pre-seeded with the standard starter so users land on a populated
/// canvas; the tabbed Twig editor open to the HTML tab (the
/// "Edit HTML" path absorbs the old "Duplicate a built-in" + "Edit
/// the HTML" entries since they routed to the same screen); and a
/// paste-JSON importer.
Future<void> _showNewDesignChooser(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(ctx.tr('new_design')),
      children: [
        ListTile(
          leading: const Icon(Icons.dashboard_customize_outlined),
          title: Text(ctx.tr('visual_designer')),
          subtitle: Text(ctx.tr('drag_and_drop_to_add')),
          onTap: () {
            Navigator.of(ctx).pop();
            // Phase 11: pre-seed with the `standard` starter so users
            // land on a populated canvas instead of an empty grid.
            final starters = buildStarterTemplates();
            final standard = starters.firstWhere(
              (s) => s.id == 'standard',
              orElse: () => starters.first,
            );
            showWysiwygDesignScreen(
              context,
              seedFrom: _seedFromStarter(standard),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.code),
          title: Text(ctx.tr('edit_the_html')),
          subtitle: Text(ctx.tr('edit_the_html_hint')),
          onTap: () {
            Navigator.of(ctx).pop();
            // Land on the Settings tab so the user sets name / start-from
            // / template first; HTML editing is one tab over.
            showDesignEditScreen(context);
          },
        ),
        ListTile(
          leading: const Icon(Icons.file_upload_outlined),
          title: Text(ctx.tr('import_design')),
          subtitle: Text(ctx.tr('import_design_hint')),
          onTap: () async {
            Navigator.of(ctx).pop();
            await _promptImportJson(context);
          },
        ),
      ],
    ),
  );
}

/// Synthesize an unsaved `Design` that wraps a starter template's
/// blocks. Used by the Visual Designer entry (pre-seeded with
/// `standard`) and any future template-gallery flow.
Design _seedFromStarter(DesignTemplateStarter starter) => Design(
  id: '',
  name: '',
  isCustom: true,
  isActive: true,
  isTemplate: false,
  isFree: false,
  entities: const ['invoice'],
  template: DesignTemplate(blocks: starter.blocks),
  updatedAt: DateTime.utc(2000),
  createdAt: DateTime.utc(2000),
  archivedAt: null,
  isDeleted: false,
);

/// Open the WYSIWYG visual designer (sibling to [showDesignEditScreen]).
/// Modal sub-flow — see `docs/architecture.md` § Navigation.
///
/// Phase 12: same sidebar-hide treatment as [showDesignEditScreen].
Future<void> showWysiwygDesignScreen(
  BuildContext context, {
  String? existingId,
  Design? seedFrom,
}) async {
  hideSettingsListSidebar.value = true;
  try {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            WysiwygDesignScreen(existingId: existingId, seedFrom: seedFrom),
      ),
    );
  } finally {
    hideSettingsListSidebar.value = false;
  }
}

Future<void> _promptImportJson(BuildContext context) async {
  final json = await showImportDesignJsonDialog(context);
  if (json == null || json.trim().isEmpty || !context.mounted) return;
  unawaited(showDesignEditScreen(context, importJson: json));
}

Future<void> _exportDesign(BuildContext context, Design design) {
  const encoder = JsonEncoder.withIndent('  ');
  // Name the design rather than the JSON blob it serializes to.
  return copyToClipboard(
    context,
    encoder.convert(design.toApiJson()),
    label: design.name,
  );
}

class _DesignsListView extends StatelessWidget {
  const _DesignsListView({required this.bundled});

  final List<Design> bundled;

  @override
  Widget build(BuildContext context) {
    final rows = mergeDesignRows(bundled);
    final builtIn = rows.where((r) => !r.isCustom).toList();
    final custom = rows.where((r) => r.isCustom).toList();
    // Custom designs are Pro-gated; free users get read-only access (parity
    // with React's `hideEditableOptions`). The banner auto-hides for Pro/trial.
    final canEdit =
        context.read<Services>().auth.session.value?.hasProAccess ?? false;

    return ListView(
      padding: EdgeInsets.symmetric(
        horizontal: InSpacing.lg(context),
        vertical: InSpacing.md(context),
      ),
      // "+ New design" used to live here; it's been hoisted into the
      // shell's preview-toggle bar via `TabbedSettingsTab.topBarLeading`
      // (see `CustomDesignsNewDesignButton` + `invoice_design_shell.dart`)
      // so it sits on the same horizontal line as "Show preview"
      // instead of stacking below it.
      children: [
        const PlanGateBanner(style: PlanGateStyle.inset),
        if (custom.isNotEmpty) ...[
          for (final r in custom) _DesignTile(row: r, canEdit: canEdit),
          SizedBox(height: InSpacing.lg(context)),
        ],
        _SectionHeader(label: context.tr('built_in')),
        for (final r in builtIn) _DesignTile(row: r, canEdit: canEdit),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: InSpacing.sm),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(color: context.inTheme.ink2),
      ),
    );
  }
}

class _DesignTile extends StatelessWidget {
  const _DesignTile({required this.row, required this.canEdit});

  final _Row row;

  /// False for free users — custom designs are Pro-gated. When false the row
  /// opens read-only and the "Edit a copy" action is hidden (parity with
  /// React's `hideEditableOptions`).
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    // "Edit a copy" seeds a NEW custom design, so it's Pro-only; hide it for
    // free users. Export is read-only (clipboard) and stays available to all.
    final showCopy = row.design != null && canEdit;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        title: Text(row.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: row.entities.isEmpty
            ? null
            : Text(
                row.entities.join(' · '),
                style: TextStyle(color: context.inTheme.ink3),
              ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (row.isTemplate)
              _Pill(label: context.tr('template'), tone: _PillTone.neutral),
            if (!row.isCustom && !row.isFree)
              _Pill(label: context.tr('pro_plan'), tone: _PillTone.accent),
            if (row.design != null)
              PopupMenuButton<String>(
                // Explicit: the default is `Icons.adaptive.more`, which is
                // `more_horiz` on iOS and macOS. CLAUDE.md § Design system (v2).
                icon: const Icon(Icons.more_vert),
                tooltip: '',
                itemBuilder: (ctx) => [
                  if (showCopy)
                    PopupMenuItem(
                      value: 'copy',
                      child: Text(ctx.tr('edit_a_copy')),
                    ),
                  PopupMenuItem(
                    value: 'export',
                    child: Text(ctx.tr('export_design')),
                  ),
                ],
                onSelected: (v) {
                  if (v == 'copy') {
                    showDesignEditScreen(context, seedFrom: row.design);
                  } else if (v == 'export') {
                    unawaited(_exportDesign(context, row.design!));
                  }
                },
              )
            else
              const SizedBox(width: 8),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: _onTap(context),
      ),
    );
  }

  /// Pro users edit custom designs in place; free users get the upgrade prompt
  /// (the read-only detail is blank for block-based WYSIWYG designs, and custom
  /// designs are the gated feature) — mirrors the "+ New design" button.
  /// Built-in designs open read-only detail for everyone; static catalog rows
  /// with no loaded template (`design == null`) aren't tappable.
  VoidCallback? _onTap(BuildContext context) {
    if (row.isCustom) {
      return canEdit
          ? () => showDesignEditScreen(context, existingId: row.id)
          : () => unawaited(openUpgradeFlow(context));
    }
    if (row.design == null) return null;
    return () => showDesignDetailScreen(context, row.design!);
  }
}

class _DesignDetailScreen extends StatelessWidget {
  const _DesignDetailScreen({required this.design});

  final Design design;

  @override
  Widget build(BuildContext context) {
    // "Edit a copy" seeds a new custom design — Pro only.
    final canEdit =
        context.read<Services>().auth.session.value?.hasProAccess ?? false;
    final sections = <(String, String)>[
      ('body', design.template.body),
      ('header', design.template.header),
      ('footer', design.template.footer),
      ('includes', design.template.includes),
      ('product', design.template.product),
      ('task', design.template.task),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(design.name),
        actions: [
          if (canEdit)
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                showDesignEditScreen(context, seedFrom: design);
              },
              icon: const Icon(Icons.copy_all_outlined, size: 18),
              label: Text(context.tr('edit_a_copy')),
            ),
          IconButton(
            tooltip: context.tr('export_design'),
            icon: const Icon(Icons.file_download_outlined),
            onPressed: () => unawaited(_exportDesign(context, design)),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(InSpacing.lg(context)),
        children: [
          if (design.entities.isNotEmpty)
            _MetaRow(
              label: context.tr('entities'),
              value: design.entities.join(', '),
            ),
          _MetaRow(
            label: context.tr('type'),
            value: design.isCustom
                ? context.tr('custom')
                : context.tr('built_in'),
          ),
          if (design.isTemplate)
            _MetaRow(label: context.tr('template'), value: context.tr('yes')),
          SizedBox(height: InSpacing.lg(context)),
          for (final s in sections)
            if (s.$2.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  title: Text(context.tr(s.$1)),
                  childrenPadding: const EdgeInsets.all(12),
                  children: [
                    SelectableText(
                      s.$2,
                      style: const TextStyle(
                        fontFamily: kMonoFontFamily,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(color: context.inTheme.ink3)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

enum _PillTone { neutral, accent }

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.tone});

  final String label;
  final _PillTone tone;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final bg = tone == _PillTone.accent ? tokens.accentSoft : tokens.surfaceAlt;
    final fg = tone == _PillTone.accent ? tokens.accent : tokens.ink2;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      margin: const EdgeInsets.only(left: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(InRadii.r2),
      ),
      child: Text(label, style: TextStyle(color: fg, fontSize: 11)),
    );
  }
}

/// Lightweight projection used for the merged built-in + bundled list. Holds
/// a [Design] reference when the row came from the bundle (so the detail
/// screen has the full template HTML) and is null for the pure-static
/// built-in catalog entries (no template HTML on hand until the bundle lands).
/// Merge the server-bundled designs with the static built-in catalog
/// into a single sorted row list.
///
/// **Phase 14 dedupe rule:** when `bundled` carries any non-custom row
/// the server is authoritative — drop [kBuiltInDesigns] entirely so
/// installs whose server-side IDs diverge from the static catalog
/// don't show each built-in twice (the old by-id merge let
/// non-matching ids through). The catalog only contributes to
/// first-paint / offline scenarios where no built-in has arrived yet.
@visibleForTesting
List<DesignListRow> mergeDesignRows(List<Design> bundled) {
  // Composite key — different shape per bucket:
  //   * Built-ins (`isCustom: false`) dedupe by NAME, case-insensitive
  //     trimmed. Server-side IDs diverge from the static catalog on many
  //     installs, AND the server itself can return the same built-in at
  //     two ids (e.g. an original + a copy). Both should collapse to one
  //     row.
  //   * Custom designs dedupe by id only. Two custom designs with the
  //     same name are legitimate (user named both "Invoice v2"); they
  //     must not silently merge.
  final byKey = <String, _Row>{};
  String keyFor(_Row r) =>
      r.isCustom ? 'c:${r.id}' : 'b:${r.name.toLowerCase().trim()}';

  final hasBundledBuiltIns = bundled.any((d) => !d.isCustom);
  if (!hasBundledBuiltIns) {
    for (final d in kBuiltInDesigns) {
      final row = _Row.builtIn(d.id, d.name, d.isFree);
      byKey[keyFor(row)] = row;
    }
  }
  for (final d in bundled) {
    final row = _Row.fromDomain(d);
    byKey[keyFor(row)] = row; // server wins on built-in name collision
  }
  return byKey.values.toList()..sort((a, b) => a.name.compareTo(b.name));
}

/// Public alias for [_Row] so [mergeDesignRows]' return type is
/// reachable from tests. The `_Row` shape stays internal to the body.
typedef DesignListRow = _Row;

class _Row {
  const _Row({
    required this.id,
    required this.name,
    required this.entities,
    required this.isCustom,
    required this.isTemplate,
    required this.isFree,
    required this.design,
  });

  factory _Row.builtIn(String id, String name, bool isFree) => _Row(
    id: id,
    name: name,
    entities: const <String>[],
    isCustom: false,
    isTemplate: false,
    isFree: isFree,
    design: null,
  );

  factory _Row.fromDomain(Design d) => _Row(
    id: d.id,
    name: d.name,
    entities: d.entities,
    isCustom: d.isCustom,
    isTemplate: d.isTemplate,
    isFree: d.isFree,
    design: d,
  );

  final String id;
  final String name;
  final List<String> entities;
  final bool isCustom;
  final bool isTemplate;
  final bool isFree;
  final Design? design;
}
