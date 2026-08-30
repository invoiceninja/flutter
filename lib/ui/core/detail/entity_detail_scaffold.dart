import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/ui/core/detail/detail_scroll_scope.dart';
import 'package:admin/ui/core/detail/generic_detail_view_model.dart';
import 'package:admin/ui/core/list/master_detail_layout.dart';
import 'package:admin/ui/core/utils/text_input_focus.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';

/// Shared chrome for an entity detail screen.
///
/// Owns the Scaffold + AppBar + loading/empty/content states that every
/// entity detail page wants. Concrete screens supply:
///   * a [GenericDetailViewModel] (`ClientDetailViewModel`, …)
///   * [actionsForItem]   — the AppBar title/actions widget per item
///     (typically the entity's actions row)
///   * [emptyTitle] + [emptyIcon] — shown when the watch stream resolves
///     to null (entity deleted, deep-linked to nonexistent id)
///   * [bodyBuilder] — renders the cards/sections for a resolved item
class EntityDetailScaffold<T> extends StatefulWidget {
  const EntityDetailScaffold({
    super.key,
    required this.vm,
    required this.bodyBuilder,
    required this.emptyTitle,
    this.emptySubtitle,
    this.emptyIcon = Icons.search_off_outlined,
    this.emptyAction,
    this.hydrate,
    this.actionsForItem,
    this.embedded = false,
  });

  final GenericDetailViewModel<T> vm;
  final Widget Function(BuildContext context, T item) bodyBuilder;
  final String emptyTitle;
  final String? emptySubtitle;
  final IconData emptyIcon;

  /// Optional escape hatch rendered under the empty state — typically a
  /// `Go to <list>` button. A record can legitimately not resolve (deleted
  /// server-side, outside this user's permissions, a stale shared link), and
  /// without this the screen is a dead end.
  final Widget? emptyAction;

  /// Optional one-shot fetch for a record that isn't in the local cache,
  /// invoked once from `initState` (typically `repo.ensureLoaded`).
  ///
  /// The scaffold shows its resolving spinner for the duration instead of the
  /// empty state. That matters more than it looks: [GenericDetailViewModel]
  /// clears `isResolving` on the FIRST Drift emission, and for an uncached
  /// record that emission is `null` — so without this the screen flashes
  /// "not found" for the length of the network round-trip and then flips to
  /// content. A deep-link recipient hits that path every time, since the whole
  /// point is that they have never browsed to the record.
  final Future<void> Function()? hydrate;

  /// Optional builder for the AppBar's title slot — usually an entity
  /// actions row. Receives the resolved item; not called while resolving
  /// or in the empty state. In embedded mode this widget is rendered as
  /// a thin header strip in place of the AppBar.
  final Widget Function(BuildContext context, T item)? actionsForItem;

  /// When `true`, the scaffold returns only the body — no outer
  /// `Scaffold`, no `AppBar`. Used when this screen is hosted inside
  /// another container (e.g. the `MasterDetailLayout` right pane on
  /// wide desktop) so the parent's chrome isn't duplicated. The actions
  /// row, if any, renders as an inline header strip above the body.
  final bool embedded;

  @override
  State<EntityDetailScaffold<T>> createState() =>
      _EntityDetailScaffoldState<T>();
}

class _EntityDetailScaffoldState<T> extends State<EntityDetailScaffold<T>> {
  // Owns the detail page's scroll. Published via [DetailScrollScope] so an
  // embedded related-entity list can drive its pagination off this scroll
  // (the embedded list shrink-wraps and no longer scrolls itself).
  final ScrollController _outerScroll = ScrollController();

  /// True while [EntityDetailScaffold.hydrate] is in flight.
  bool _hydrating = false;

  @override
  void initState() {
    super.initState();
    final hydrate = widget.hydrate;
    if (hydrate == null) return;
    _hydrating = true;
    // `ensureLoaded` handles its own errors, but `hydrate` is a public
    // parameter — a caller that passes something else must not turn a failed
    // *prefetch* into an unhandled async error (a zone error, a diagnostics
    // entry and a Sentry report from a screen that merely didn't warm up).
    // A cache hit is fast but not synchronous: it still awaits one Drift read.
    hydrate().catchError((_) {}).whenComplete(() {
      if (mounted) setState(() => _hydrating = false);
    });
  }

  @override
  void dispose() {
    _outerScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Auto-detect when mounted inside the master-detail right pane —
    // concrete screens never need to pass `embedded: true`. Matches
    // the same convention `EntityEditScaffold` uses.
    final inPane = MasterDetailPaneScope.isInPane(context);
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.keyE): _EditCurrentIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          // Single-key `e` shortcut: disable while typing so the
          // keystroke falls through and inserts `e` instead of
          // navigating to the edit screen.
          _EditCurrentIntent: GuardedShortcutAction<_EditCurrentIntent>(
            onInvoke: (_) {
              if (widget.vm.item == null) return null;
              // Universal: detail routes follow `/<entity>/:id`, edit is
              // the sibling `/<entity>/:id/edit`. Appending `/edit` to
              // the current URL is correct for every entity that goes
              // through `_entityRoutes` in `lib/app/router.dart`. The
              // scaffold isn't mounted on `/new` or `/edit` paths, so
              // this can't produce `/edit/edit`.
              final state = GoRouterState.of(context);
              context.go('${state.uri.path}/edit');
              return null;
            },
          ),
        },
        child: ListenableBuilder(
          listenable: widget.vm,
          builder: (context, _) {
            final item = widget.vm.item;
            if (widget.embedded || inPane) {
              return _embeddedBody(context, item);
            }
            return Scaffold(
              appBar: AppBar(
                titleSpacing: InSpacing.lg(context),
                title: (item != null && widget.actionsForItem != null)
                    ? widget.actionsForItem!(context, item)
                    : null,
              ),
              body: _stateBody(context, item),
            );
          },
        ),
      ),
    );
  }

  /// Embedded variant: stack a thin actions header above the same body
  /// switcher. No Scaffold / AppBar — the host shell owns the chrome.
  /// When mounted inside the slide-over pane, the pane's X + full-
  /// screen icons published via [MasterDetailPaneScope] are appended
  /// to the right of the row so they share the strip with the
  /// entity's own action buttons.
  Widget _embeddedBody(BuildContext context, T? item) {
    final tokens = context.inTheme;
    final paneActions = MasterDetailPaneScope.paneActionsOf(context);
    // Narrow viewport: the pane publishes a leading back arrow (and no
    // trailing X / full-screen toggle). Render it at the start of the header.
    final paneLeading = MasterDetailPaneScope.paneLeadingOf(context);
    final hasHeaderContent = item != null && widget.actionsForItem != null;
    final showHeader =
        hasHeaderContent || paneActions != null || paneLeading != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader)
          Container(
            padding: EdgeInsetsDirectional.only(
              start: paneLeading != null ? 4 : InSpacing.lg(context),
              end: InSpacing.lg(context),
              top: 8,
              bottom: 8,
            ),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: tokens.border)),
            ),
            child: Row(
              children: [
                if (paneLeading != null) paneLeading,
                if (hasHeaderContent)
                  Expanded(child: widget.actionsForItem!(context, item))
                else
                  const Spacer(),
                if (paneActions != null) paneActions,
              ],
            ),
          ),
        Expanded(child: _stateBody(context, item)),
      ],
    );
  }

  Widget _stateBody(BuildContext context, T? item) {
    if (item == null && (widget.vm.isResolving || _hydrating)) {
      return const Center(child: CircularProgressIndicator());
    }
    if (item == null) {
      return EmptyState(
        icon: widget.emptyIcon,
        title: widget.emptyTitle,
        subtitle: widget.emptySubtitle,
        action: widget.emptyAction,
      );
    }
    // Publish the page scroll so an embedded related-entity list (rendered
    // inside a detail tab) can drive its pagination off this scroll. Wraps
    // both the standalone and master-detail-embedded body paths. The
    // Builder gives `bodyBuilder` a context *below* the scope so its
    // SingleChildScrollView's `DetailScrollScope.maybeOf` resolves.
    return DetailScrollScope(
      controller: _outerScroll,
      child: Builder(
        builder: (context) {
          final body = widget.bodyBuilder(context, item);
          // Desktop/web a11y + keyboard path: make the body's text selectable
          // so keyboard and screen-reader users can select and Cmd/Ctrl+C (the
          // hover copy icon is mouse-only). Skipped on touch, where the value's
          // own tap-to-copy is the path and selection handles would fight it.
          return Env.isMobile ? body : SelectionArea(child: body);
        },
      ),
    );
  }
}

class _EditCurrentIntent extends Intent {
  const _EditCurrentIntent();
}
