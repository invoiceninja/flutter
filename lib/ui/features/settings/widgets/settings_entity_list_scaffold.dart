import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/core/widgets/watch_builder.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/settings/widgets/settings_form_shell.dart';
import 'package:admin/ui/features/settings/widgets/settings_screen_scaffold.dart';

/// Shared chrome for the list view of a bundled settings-CRUD entity
/// (payment_terms, task_statuses, group_settings, …). Owns the
/// `StreamBuilder`, empty state, `FormSection` container, "+ New" tile,
/// optional Show Archived toggle, and optional drag-to-reorder.
///
/// [stream] always yields active **and** archived rows; the scaffold splits
/// them locally and the toggle only chooses what to draw.
///
/// Per-screen callers supply just the row layout and the stream/refresh
/// hooks bound to their repo — list screens drop from ~120–260 lines to
/// ~30–60.
///
/// Reorder semantics: when [onReorder] is non-null, active rows render
/// inside a `ReorderableListView` and the scaffold owns the optimistic
/// snapshot so the drag drop lands instantly. The snapshot clears as
/// soon as the stream re-emits with the persisted order.
class SettingsEntityListScaffold<T> extends StatefulWidget {
  const SettingsEntityListScaffold({
    super.key,
    required this.titleKey,
    required this.sectionTitleKey,
    required this.newRoute,
    required this.newLabelKey,
    required this.emptyIcon,
    required this.emptyTitleKey,
    required this.emptyHintKey,
    required this.refreshAll,
    required this.stream,
    required this.streamKey,
    required this.isArchivedOf,
    required this.isDeletedOf,
    this.rowBuilder,
    this.reorderableRowBuilder,
    this.archivedRowBuilder,
    this.supportsArchive = false,
    this.onReorder,
    this.extraAppBarActions = const <Widget>[],
    this.starters,
    this.banner,
    this.canCreate = true,
  }) : assert(
         rowBuilder != null || reorderableRowBuilder != null,
         'Pass at least one of rowBuilder or reorderableRowBuilder',
       ),
       assert(
         onReorder == null || reorderableRowBuilder != null,
         'reorderableRowBuilder is required when onReorder is non-null',
       ),
       assert(
         !supportsArchive || rowBuilder != null || archivedRowBuilder != null,
         'When supportsArchive is true, pass either rowBuilder or '
         'archivedRowBuilder (or both) to render archived rows',
       );

  /// AppBar title and section header keys.
  final String titleKey;
  final String sectionTitleKey;

  /// `/settings/<slug>/new` for the "+ New" tile + empty-state CTA.
  final String newRoute;
  final String newLabelKey;

  /// Empty-state copy when both active and archived sections are empty.
  final IconData emptyIcon;
  final String emptyTitleKey;
  final String emptyHintKey;

  /// Fire-and-forget background refresh from the server. Called once on
  /// `initState`.
  final Future<void> Function() refreshAll;

  /// Repo watch. **Must include archived rows** — the scaffold splits them
  /// out locally via [isArchivedOf] and needs to know whether any exist
  /// before it can decide to render the Show Archived toggle at all
  /// (invoiceninja/flutter#63). Callers wire as
  /// `() => services.[repo].watchAllIncludingArchived(companyId: ...)`.
  final Stream<List<T>> Function() stream;

  /// Everything [stream]'s closure depends on, so [WatchBuilder] knows when to
  /// re-subscribe. Required, and supplied by the caller rather than derived
  /// here, because [stream] is opaque to this widget: a key computed from our
  /// own view of the active company could disagree with the company the thunk
  /// actually closed over. Usually `companyId`; `tags_screen` passes
  /// `(companyId, entityType)` because its query is scoped by both.
  final Object? streamKey;

  /// Predicates used to split the stream into active vs archived sections.
  final bool Function(T) isArchivedOf;
  final bool Function(T) isDeletedOf;

  /// Row layout for the active section in static (non-reorderable) mode.
  /// Required unless [reorderableRowBuilder] is supplied. Set a stable
  /// `ValueKey(entity.id)` on each row to keep tap targets stable across
  /// stream emissions.
  final Widget Function(T item)? rowBuilder;

  /// Row layout when `onReorder` is non-null. Receives the row's index in
  /// the active list so the caller can wire a `ReorderableDragStartListener`.
  /// Required when [onReorder] is set; ignored otherwise.
  final Widget Function(T item, int index)? reorderableRowBuilder;

  /// Row layout for the archived section. Defaults to [rowBuilder] when
  /// omitted — but most callers want a separate variant that drops the
  /// trailing chevron / drag handle in favor of an "Archived" pill.
  final Widget Function(T item)? archivedRowBuilder;

  /// When true, the body can render a second FormSection for archived rows
  /// and the AppBar carries a Show Archived / Show Active toggle — but only
  /// once an archived row actually exists, so a brand-new company isn't
  /// offered a filter over nothing (invoiceninja/flutter#63).
  final bool supportsArchive;

  /// Optional reorder hook. When non-null, the active section becomes a
  /// `ReorderableListView` whose drag drop fires this callback with the
  /// reordered list. The scaffold owns the optimistic snapshot so the UI
  /// repaints instantly. Archived rows are never reorderable
  /// (`status_order` is moot until restored).
  final Future<void> Function(List<T> reordered)? onReorder;

  /// Extra AppBar actions rendered before the optional Show Archived
  /// toggle. Used by Bank Accounts to surface its Connect / Refresh / Rules
  /// actions (plan-gated, with a mobile overflow menu) alongside the standard
  /// "+ New bank account" path. Empty by default.
  final List<Widget> extraAppBarActions;

  /// Optional starter cards rendered inside the empty state, between the
  /// hint text and the standard "+ New" CTA. Lets a screen offer prefab
  /// shortcuts (e.g. Schedules' "Email monthly statements") so the user's
  /// first action isn't a blank form. Null hides the row entirely; an
  /// empty list is treated the same as null.
  final List<SettingsListStarter>? starters;

  /// Optional full-width widget rendered above the list body (between the
  /// AppBar and the first FormSection). Used by plan-gated screens to
  /// render a `PlanGateBanner`.
  final Widget? banner;

  /// When false, the "+ New" CTAs in both the populated list and the
  /// empty-state are disabled (visible but non-tappable). Used by
  /// plan-gated screens so a free-plan user still sees existing rows but
  /// can't create new ones.
  final bool canCreate;

  @override
  State<SettingsEntityListScaffold<T>> createState() =>
      _SettingsEntityListScaffoldState<T>();
}

class _SettingsEntityListScaffoldState<T>
    extends State<SettingsEntityListScaffold<T>> {
  bool _showArchived = false;

  /// Optimistic local order. Stays around just long enough for the next
  /// stream emission to repaint with the persisted order. Only used when
  /// `widget.onReorder` is non-null.
  List<T>? _optimistic;

  @override
  void initState() {
    super.initState();
    widget.refreshAll();
  }

  Future<void> _handleReorder(
    List<T> rendered,
    int oldIndex,
    int newIndex,
  ) async {
    // onReorderItem already maps newIndex to the post-removal destination.
    final adjusted = newIndex;
    final next = List<T>.from(rendered);
    final moved = next.removeAt(oldIndex);
    next.insert(adjusted, moved);
    setState(() => _optimistic = next);
    try {
      await widget.onReorder!(next);
    } finally {
      // Drop the optimistic snapshot — the next stream emission will paint
      // the persisted state. If reorder threw, the snapshot was wrong
      // anyway; the stream will repaint from Drift.
      if (mounted) setState(() => _optimistic = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    // `_showArchived` is a pure *display* toggle: the stream is always the
    // archived-inclusive one. The AppBar has to know whether an archived row
    // exists before it can decide whether the toggle is worth rendering, and
    // an active-only stream can't answer that — so a company with nothing at
    // all still got a "Show archived" button that revealed nothing
    // (invoiceninja/flutter#63). Reading the superset costs nothing here:
    // every caller is a bundled settings entity with a handful of rows, and
    // the split below was already local.
    return WatchBuilder<List<T>>(
      cacheKey: widget.streamKey,
      create: widget.stream,
      builder: (context, snapshot) {
        final loading =
            snapshot.connectionState == ConnectionState.waiting &&
            snapshot.data == null;
        final fromDrift = snapshot.data ?? <T>[];
        // Optimistic snapshot only applies to the active section — the
        // user can't drag-reorder archived rows.
        final activeSource = _optimistic ?? fromDrift;
        final active = activeSource
            .where((t) => !widget.isArchivedOf(t) && !widget.isDeletedOf(t))
            .toList(growable: false);
        final archived = fromDrift
            .where((t) => widget.isArchivedOf(t) && !widget.isDeletedOf(t))
            .toList(growable: false);

        // Nothing to toggle between until an archived row exists. The
        // `_showArchived` half keeps the control mounted while it is on, so
        // restoring the last archived row can't strand the user in a mode
        // they have no button to leave.
        final showArchiveToggle =
            widget.supportsArchive && (archived.isNotEmpty || _showArchived);

        return SettingsScreenScaffold(
          titleKey: widget.titleKey,
          actions: [
            ...widget.extraAppBarActions,
            if (showArchiveToggle)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: TextButton.icon(
                  icon: Icon(
                    _showArchived
                        ? Icons.visibility_off_outlined
                        : Icons.archive_outlined,
                    size: 18,
                  ),
                  label: Text(
                    context.tr(_showArchived ? 'show_active' : 'show_archived'),
                  ),
                  onPressed: () =>
                      setState(() => _showArchived = !_showArchived),
                ),
              ),
          ],
          body: loading
              ? const Center(child: CircularProgressIndicator())
              : _buildBody(context, active: active, archived: archived),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context, {
    required List<T> active,
    required List<T> archived,
  }) {
    final canCreate = widget.canCreate;
    VoidCallback? newAction() =>
        canCreate ? () => context.go(widget.newRoute) : null;

    // Emptiness is judged on what is *visible*, not what exists: with the
    // toggle off, a company whose only rows are archived still gets the
    // empty state (and, now, a Show archived button to go find them).
    if (active.isEmpty && (!_showArchived || archived.isEmpty)) {
      final starters = widget.starters;
      final Widget emptyBody;
      if (starters != null && starters.isNotEmpty) {
        emptyBody = SettingsFormShell(
          sections: [
            FormSection(
              title: context.tr(widget.sectionTitleKey),
              children: [
                EmptyState(
                  icon: widget.emptyIcon,
                  title: context.tr(widget.emptyTitleKey),
                  subtitle: context.tr(widget.emptyHintKey),
                  action: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(64, 44),
                    ),
                    icon: const Icon(Icons.add),
                    label: Text(context.tr(widget.newLabelKey)),
                    onPressed: newAction(),
                  ),
                ),
                const SizedBox(height: 16),
                _StarterCards(starters: starters),
              ],
            ),
          ],
        );
      } else {
        emptyBody = EmptyState(
          icon: widget.emptyIcon,
          title: context.tr(widget.emptyTitleKey),
          subtitle: context.tr(widget.emptyHintKey),
          action: FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
            icon: const Icon(Icons.add),
            label: Text(context.tr(widget.newLabelKey)),
            onPressed: newAction(),
          ),
        );
      }
      return _withBanner(widget.banner, emptyBody);
    }

    // `onReorder == null` implies `rowBuilder != null` (constructor
    // assert). When reorder is on, `reorderableRowBuilder!` is the
    // active section's builder and the static `rowBuilder` is
    // unused — `archivedRowBuilder` (or a fallback) covers archived.
    final activeSection = widget.onReorder == null
        ? _StaticRows<T>(items: active, rowBuilder: widget.rowBuilder!)
        : _ReorderableRows<T>(
            items: active,
            rowBuilder: widget.reorderableRowBuilder!,
            onReorder: (o, n) => _handleReorder(active, o, n),
          );

    return _withBanner(
      widget.banner,
      SettingsFormShell(
        sections: [
          FormSection(
            title: context.tr(widget.sectionTitleKey),
            spacing: 0,
            children: [
              if (active.isNotEmpty) activeSection,
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.add),
                title: Text(context.tr(widget.newLabelKey)),
                enabled: canCreate,
                onTap: canCreate ? () => context.go(widget.newRoute) : null,
              ),
            ],
          ),
          if (_showArchived && archived.isNotEmpty)
            FormSection(
              title: context.tr('archived'),
              spacing: 0,
              children: [
                for (final item in archived)
                  (widget.archivedRowBuilder ?? widget.rowBuilder!)(item),
              ],
            ),
        ],
      ),
    );
  }
}

/// Wraps [body] in a Column with [banner] above when non-null; otherwise
/// returns [body] verbatim so the scaffold remains visually identical for
/// non-gated screens.
Widget _withBanner(Widget? banner, Widget body) {
  if (banner == null) return body;
  return Column(
    children: [
      banner,
      Expanded(child: body),
    ],
  );
}

/// A single starter card shown in the empty state. Each card describes a
/// pre-configured starting point — tapping it deep-links into the create
/// form with the relevant defaults pre-applied (typically by appending
/// query params the edit screen reads on init).
class SettingsListStarter {
  const SettingsListStarter({
    required this.icon,
    required this.titleKey,
    required this.subtitleKey,
    required this.route,
  });

  /// Leading icon rendered inside the card.
  final IconData icon;

  /// Localization key for the card's title.
  final String titleKey;

  /// Localization key for the card's one-line description.
  final String subtitleKey;

  /// `go_router` route to push when the card is tapped. Typically the
  /// screen's `/new` path with starter-specific query params attached.
  final String route;
}

class _StarterCards extends StatelessWidget {
  const _StarterCards({required this.starters});

  final List<SettingsListStarter> starters;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 560;
        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < starters.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: _StarterCard(starter: starters[i])),
              ],
            ],
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < starters.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _StarterCard(starter: starters[i]),
            ],
          ],
        );
      },
    );
  }
}

class _StarterCard extends StatelessWidget {
  const _StarterCard({required this.starter});

  final SettingsListStarter starter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go(starter.route),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(starter.icon, size: 22, color: theme.colorScheme.primary),
              const SizedBox(height: 10),
              Text(
                context.tr(starter.titleKey),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.tr(starter.subtitleKey),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Static rows + divider between each. Used when reorder is off.
class _StaticRows<T> extends StatelessWidget {
  const _StaticRows({required this.items, required this.rowBuilder});

  final List<T> items;
  final Widget Function(T item) rowBuilder;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [for (final item in items) rowBuilder(item)],
    );
  }
}

/// Active rows wrapped in a `ReorderableListView` shrink-wrapped inside the
/// `FormSection`. Per-item key is the row widget's own key — callers must
/// set a stable `ValueKey(entity.id)` on each row.
class _ReorderableRows<T> extends StatelessWidget {
  const _ReorderableRows({
    required this.items,
    required this.rowBuilder,
    required this.onReorder,
  });

  final List<T> items;
  final Widget Function(T item, int index) rowBuilder;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: items.length,
      onReorderItem: onReorder,
      itemBuilder: (context, i) => rowBuilder(items[i], i),
    );
  }
}
