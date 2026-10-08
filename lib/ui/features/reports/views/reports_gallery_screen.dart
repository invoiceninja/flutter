import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/app/search_focus_registry.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/report_definition.dart';
import 'package:admin/data/repositories/saved_views_repository.dart';
import 'package:admin/domain/reports/report_registry.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/features/reports/helpers/report_access.dart';
import 'package:admin/ui/features/reports/view_models/reports_view_model.dart';
import 'package:admin/ui/features/shell/widgets/app_drawer.dart';

/// Where a report lives.
String reportRoutePath(String identifier) => '/reports/$identifier';

/// Query parameter naming one of a report's starter views by its position.
const String kReportStarterViewParam = 'starter';

/// Query parameter naming a saved view to open the report in, by id.
///
/// Not `view`: that key already means a layout on Tasks and "full screen" on
/// every list, and `stripTransientQuery` treats it accordingly.
const String kReportSavedViewParam = 'saved';

/// `/reports` — every report the company may open, grouped by what it is
/// for.
///
/// It replaces a flat dropdown of twenty-eight names. A report here is a
/// card that says what it is and offers the questions it answers ("by
/// month", "by client") as one-tap ways in, so the first thing a reader
/// sees on arriving at a report is an answer, not a blank table and a panel
/// of settings.
class ReportsGalleryScreen extends StatefulWidget {
  const ReportsGalleryScreen({super.key});

  @override
  State<ReportsGalleryScreen> createState() => _ReportsGalleryScreenState();
}

class _ReportsGalleryScreenState extends State<ReportsGalleryScreen> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode(debugLabel: 'reports gallery search');
  SearchFocusRegistry? _searchRegistry;
  String _query = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // `/` focuses this box while the gallery is the route on stage. It stays
    // mounted beneath an open report, which has a search of its own — hence
    // the `TickerMode` gate rather than a claim made once in `initState`.
    _searchRegistry ??= context.read<Services>().searchFocus;
    if (TickerMode.valuesOf(context).enabled) {
      _searchRegistry?.current = _searchFocus;
    } else {
      _searchRegistry?.release(_searchFocus);
    }
  }

  @override
  void dispose() {
    _searchRegistry?.release(_searchFocus);
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final globalNav = Breakpoints.isGlobalNavVisible(context);
    final tokens = context.inTheme;
    final company = context
        .watch<Services>()
        .auth
        .session
        .value
        ?.currentCompany;
    final vm = context.watch<ReportsViewModel>();
    final all = reportsInGalleryOrder(availableReports(company));
    final needle = _query.trim().toLowerCase();
    final shown = needle.isEmpty
        ? all
        : [
            for (final d in all)
              if (context.tr(d.labelKey).toLowerCase().contains(needle)) d,
          ];

    final searchField = _SearchField(
      controller: _search,
      focusNode: _searchFocus,
      onChanged: (v) => setState(() => _query = v),
    );

    final Widget body;
    if (shown.isEmpty) {
      body = EmptyState(
        icon: Icons.search_off_outlined,
        title: context.tr('no_matching_reports'),
      );
    } else {
      final recent = needle.isNotEmpty
          ? const <ReportDefinition>[]
          : [
              for (final id in vm.recentReports.take(4))
                ?openableReport(id, company),
            ];
      body = ListView(
        padding: EdgeInsets.all(
          globalNav ? InSpacing.xl : InSpacing.lg(context),
        ),
        children: [
          if (!globalNav) ...[
            searchField,
            const SizedBox(height: InSpacing.xl),
          ],
          if (recent.isNotEmpty) ...[
            _SectionLabel(text: context.tr('recent_reports')),
            const SizedBox(height: InSpacing.sm),
            Wrap(
              spacing: InSpacing.sm,
              runSpacing: InSpacing.sm,
              children: [for (final d in recent) _RecentButton(definition: d)],
            ),
            const SizedBox(height: InSpacing.xl),
          ],
          _SavedViews(
            companyId: vm.companyId ?? '',
            needle: needle,
            canOpen: (id) => openableReport(id, company) != null,
          ),
          for (final category in ReportCategory.values)
            if (shown.any((d) => d.category == category)) ...[
              _SectionLabel(text: context.tr(category.labelKey)),
              const SizedBox(height: InSpacing.sm),
              _CardGrid(
                definitions: [
                  for (final d in shown)
                    if (d.category == category) d,
                ],
              ),
              const SizedBox(height: InSpacing.xl),
            ],
        ],
      );
    }

    return Scaffold(
      backgroundColor: tokens.bg,
      drawer: globalNav ? null : const AppDrawer(),
      appBar: globalNav
          ? null
          : AppBar(
              title: Text(context.tr('reports')),
              leading: const DrawerHamburger(),
            ),
      body: globalNav
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _GalleryHeader(searchField: searchField),
                Expanded(child: body),
              ],
            )
          : body,
    );
  }
}

/// The wide layout's header band — floored to the shared header height so it
/// lines up with the sidebar's company row across the seam.
class _GalleryHeader extends StatelessWidget {
  const _GalleryHeader({required this.searchField});

  final Widget searchField;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Container(
      constraints: const BoxConstraints(minHeight: InSizes.headerBand),
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: InSpacing.xl,
        vertical: InSpacing.md(context),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.tr('reports'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: tokens.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(width: InSpacing.lg(context)),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: searchField,
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const Key('reports-gallery-search'),
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        isDense: true,
        hintText: context.tr('search_reports'),
        prefixIcon: const Icon(Icons.search, size: 18),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: context.tr('clear'),
                icon: const Icon(Icons.close, size: 16),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: context.inTheme.ink2,
          fontWeight: FontWeight.w600,
          fontSize: 11,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

IconData _iconFor(BuildContext context, ReportDefinition definition) =>
    context
        .read<Services>()
        .entityRegistry[definition.icon]
        ?.effectiveOutlinedIcon ??
    Icons.bar_chart_outlined;

/// One of the reports opened lately — a way straight back in.
class _RecentButton extends StatelessWidget {
  const _RecentButton({required this.definition});

  final ReportDefinition definition;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return OutlinedButton.icon(
      onPressed: () => context.go(reportRoutePath(definition.identifier)),
      style: OutlinedButton.styleFrom(
        minimumSize: Size(64, Env.isTouchPrimary ? InSizes.touchTarget : 36),
        foregroundColor: tokens.ink,
        backgroundColor: tokens.surface,
        side: BorderSide(color: tokens.border),
      ),
      icon: Icon(_iconFor(context, definition), size: 16, color: tokens.ink2),
      label: Text(context.tr(definition.labelKey)),
    );
  }
}

/// The company's saved report views, each a way straight into a report
/// already arranged — the reports somebody actually runs, named in their
/// own words. Draws nothing while there are none.
class _SavedViews extends StatefulWidget {
  const _SavedViews({
    required this.companyId,
    required this.needle,
    required this.canOpen,
  });

  final String companyId;

  /// The gallery's search, lower-cased; a view is matched on its name.
  final String needle;

  /// Whether the report a view belongs to is one this company may open.
  final bool Function(String reportIdentifier) canOpen;

  @override
  State<_SavedViews> createState() => _SavedViewsState();
}

class _SavedViewsState extends State<_SavedViews> {
  Stream<List<SavedReportView>>? _views;

  @override
  void initState() {
    super.initState();
    _watch();
  }

  @override
  void didUpdateWidget(_SavedViews oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.companyId != widget.companyId) _watch();
  }

  /// Made here, not in `build` — see `ReportViewsButton`.
  void _watch() {
    _views = widget.companyId.isEmpty
        ? null
        : context.read<Services>().savedViews.watchReportViews(
            widget.companyId,
          );
  }

  @override
  Widget build(BuildContext context) {
    final stream = _views;
    if (stream == null) return const SizedBox.shrink();
    final tokens = context.inTheme;
    return StreamBuilder<List<SavedReportView>>(
      stream: stream,
      builder: (context, snapshot) {
        final views = [
          for (final v in snapshot.data ?? const <SavedReportView>[])
            if (widget.canOpen(v.reportIdentifier) &&
                (widget.needle.isEmpty ||
                    v.name.toLowerCase().contains(widget.needle)))
              v,
        ];
        if (views.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _SectionLabel(text: context.tr('saved_views')),
            const SizedBox(height: InSpacing.sm),
            Wrap(
              spacing: InSpacing.sm,
              runSpacing: InSpacing.sm,
              children: [
                for (final view in views)
                  OutlinedButton.icon(
                    key: Key('report-saved-view-${view.id}'),
                    onPressed: () => context.go(
                      '${reportRoutePath(view.reportIdentifier)}'
                      '?$kReportSavedViewParam=${view.id}',
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: Size(
                        64,
                        Env.isTouchPrimary ? InSizes.touchTarget : 36,
                      ),
                      foregroundColor: tokens.ink,
                      backgroundColor: tokens.surface,
                      side: BorderSide(color: tokens.border),
                    ),
                    icon: Icon(
                      Icons.bookmark_border,
                      size: 16,
                      color: tokens.ink2,
                    ),
                    // The view's name, and the report it is a view of.
                    label: Text(
                      '${view.name}  ·  '
                      '${context.tr(reportDefinitionFor(view.reportIdentifier).labelKey)}',
                    ),
                  ),
              ],
            ),
            const SizedBox(height: InSpacing.xl),
          ],
        );
      },
    );
  }
}

/// Cards in rows that end level: as many columns as fit, every card in a row
/// as tall as the tallest.
class _CardGrid extends StatelessWidget {
  const _CardGrid({required this.definitions});

  final List<ReportDefinition> definitions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1040 ? 3 : (width >= 640 ? 2 : 1);
        final gap = InSpacing.lg(context);
        final rows = <Widget>[];
        for (var i = 0; i < definitions.length; i += columns) {
          final end = (i + columns).clamp(0, definitions.length);
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var j = i; j < i + columns; j++) ...[
                    if (j > i) SizedBox(width: gap),
                    Expanded(
                      child: j < end
                          ? _ReportCard(
                              key: Key(
                                'report-card-${definitions[j].identifier}',
                              ),
                              definition: definitions[j],
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          );
          if (end < definitions.length) rows.add(SizedBox(height: gap));
        }
        return Column(children: rows);
      },
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({super.key, required this.definition});

  final ReportDefinition definition;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(InRadii.r3);
    final name = context.tr(definition.labelKey);
    final path = reportRoutePath(definition.identifier);
    final pad = InSpacing.lg(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: tokens.shadow1,
      ),
      child: Material(
        color: tokens.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: tokens.border),
          borderRadius: radius,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The name is the card's one destination; the views beneath are
            // their own controls and sit outside its ink, so no tap target
            // is nested inside another.
            InkWell(
              onTap: () => context.go(path),
              child: Padding(
                padding: EdgeInsets.fromLTRB(pad, pad, pad, InSpacing.sm),
                child: Row(
                  children: [
                    Icon(
                      _iconFor(context, definition),
                      size: 20,
                      color: tokens.ink2,
                    ),
                    const SizedBox(width: InSpacing.sm),
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: tokens.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 18, color: tokens.ink3),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(pad, 0, pad, pad),
              child: definition.starterViews.isEmpty
                  ? _CardNote(definition: definition)
                  : Wrap(
                      spacing: InSpacing.sm,
                      runSpacing: InSpacing.sm,
                      children: [
                        for (var i = 0; i < definition.starterViews.length; i++)
                          _StarterChip(
                            reportName: name,
                            view: definition.starterViews[i],
                            onTap: () =>
                                context.go('$path?$kReportStarterViewParam=$i'),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What a card says in place of starter views: nothing for a plain list,
/// "Download only" for a report that produces a file and no table.
class _CardNote extends StatelessWidget {
  const _CardNote({required this.definition});

  final ReportDefinition definition;

  @override
  Widget build(BuildContext context) {
    if (definition.showsOnScreen) return const SizedBox.shrink();
    final tokens = context.inTheme;
    return Row(
      children: [
        Icon(Icons.download_outlined, size: 14, color: tokens.ink3),
        const SizedBox(width: 4),
        Text(
          context.tr('report_download_only'),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: tokens.ink2),
        ),
      ],
    );
  }
}

/// "By month" — opens the report already grouped that way.
class _StarterChip extends StatelessWidget {
  const _StarterChip({
    required this.reportName,
    required this.view,
    required this.onTap,
  });

  final String reportName;
  final ReportStarterView view;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final label = context.tr('report_view_by', {
      'dimension': context.tr(view.labelKey),
    });
    return Semantics(
      button: true,
      label: '$reportName, $label',
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          color: tokens.surfaceAlt,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: tokens.border),
            borderRadius: BorderRadius.circular(InRadii.r2),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: Env.isTouchPrimary ? InSizes.touchTarget : 28,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: tokens.ink,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
