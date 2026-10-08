import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/features/settings/view_models/settings_draft_view_model.dart';
import 'package:admin/ui/features/settings/widgets/cascade_draft_resolver.dart';
import 'package:admin/ui/features/settings/widgets/cascade_settings_scaffold.dart';
import 'package:admin/ui/features/settings/widgets/settings_company_scoped_host.dart';
import 'package:admin/ui/features/settings/widgets/settings_page_scaffold.dart';
import 'package:admin/ui/features/settings/widgets/tabbed_settings_shell.dart';

/// Cascade-aware counterpart to [TabbedSettingsShell]. Use this for any
/// settings page that:
///   * binds to `company.settings.*` fields (i.e. needs the cascade override
///     wrapper at group / client scope — see [CascadeSettingsScaffold]), AND
///   * splits its content across tabs (Localization today; Templates &
///     Reminders / Client Portal will be next).
///
/// Picks the right VM for the active [SettingsLevel] via `resolveCascadeDraftVm`
/// (company → caller's factory; group → shared `GroupSettingsDraftViewModel`;
/// client → shared `ClientSettingsDraftViewModel`) and owns the
/// [TabController] + URL ↔ tab-index sync. The tabs themselves are scope-
/// agnostic because they read [SettingsDraftHost] off Provider just like a
/// non-tabbed cascade screen.
///
/// Pair with [tabbedSettingsRoutePair] in `settings_routes.dart` — the
/// shared page key in that helper is what keeps the [TabController] + draft
/// VM alive across the two route variants.
class CascadeTabbedSettingsShell extends StatefulWidget {
  const CascadeTabbedSettingsShell({
    super.key,
    required this.titleKey,
    required this.basePath,
    required this.initialTab,
    required this.companyVmFactory,
    required this.tabs,
    this.extraActions = const <Widget>[],
    this.resolveErrorTabSlug,
    this.banner,
    this.sidePane,
    this.sidePaneFullScreenBuilder,
  }) : assert(
         tabs.length >= 2,
         'CascadeTabbedSettingsShell needs at least two tabs',
       );

  /// Localization key for the AppBar title.
  final String titleKey;

  /// Absolute path of the shell's bare URL (no trailing `/`). Used to
  /// build the per-tab URL when the controller settles on a new index.
  final String basePath;

  /// The `:tab` path-parameter from the route, or null on the bare URL
  /// (resolves to the first tab).
  final String? initialTab;

  /// Build the typed VM for the active company. Used at
  /// [SettingsLevel.company]; at [SettingsLevel.client] the shell substitutes
  /// `ClientSettingsDraftViewModel` automatically. Same shape as
  /// [CascadeSettingsScaffold.companyVmFactory].
  final CompanySettingsVmFactory companyVmFactory;

  /// Tab definitions, in display order. First entry should use an empty
  /// `slug` (the default tab); the rest carry their literal slug.
  final List<TabbedSettingsTab> tabs;

  /// Additional AppBar action widgets rendered to the right of the Save
  /// button.
  final List<Widget> extraActions;

  /// Optional 422 → tab-jump resolver. Same semantics as
  /// [TabbedSettingsShell.resolveErrorTabSlug].
  final String? Function(SettingsDraftHost vm)? resolveErrorTabSlug;

  /// Optional full-width widget rendered below the TabBar and above the
  /// TabBarView body — typically a stripe-style `PlanGateBanner` for
  /// plan-gated surfaces. When null the body fills the whole area as
  /// before.
  final Widget? banner;

  /// Optional persistent pane rendered beside the `TabBarView`. When non-null
  /// the body becomes responsive in three modes:
  ///   * `>= Breakpoints.slideOver` (1024): tabs and pane side-by-side, ~50/50.
  ///   * `>= Breakpoints.wide` (600): an in-place "Show Preview" toggle swaps
  ///     the full-width tab content for the full-width pane.
  ///   * `< Breakpoints.wide`: tab content + an in-body "Preview" button that
  ///     opens the fullscreen route built by [sidePaneFullScreenBuilder].
  /// All three modes key off the body's own `LayoutBuilder` width — never the
  /// window — so a sidebar-narrowed detail pane can't strand the preview. The
  /// active tab's [TabbedSettingsTab.topBarLeading] sits above the tab content
  /// in every one of them.
  /// Null (the default) preserves the original full-width `TabBarView`
  /// behavior — all existing callers are unaffected.
  final Widget? sidePane;

  /// Builds the fullscreen-dialog variant of [sidePane] for phone widths.
  /// Invoked from a context that still has the cascade providers in scope, so
  /// the implementation can `read` the draft host / level there. Required
  /// alongside [sidePane] to enable the phone fallback; ignored when
  /// [sidePane] is null.
  final Widget Function(BuildContext context)? sidePaneFullScreenBuilder;

  @override
  State<CascadeTabbedSettingsShell> createState() =>
      _CascadeTabbedSettingsShellState();
}

class _CascadeTabbedSettingsShellState extends State<CascadeTabbedSettingsShell>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final ValueNotifier<bool> _saveVisible;

  /// Tablet-band ("medium" width) toggle: false → tab content full-width,
  /// true → [CascadeTabbedSettingsShell.sidePane] full-width (settings list
  /// hidden). Only consulted when `sidePane != null`.
  final ValueNotifier<bool> _previewShown = ValueNotifier<bool>(false);

  SettingsDraftHost? _boundVm;
  void Function()? _vmListener;

  @override
  void initState() {
    super.initState();
    final initialIndex = _indexForSlug(widget.initialTab);
    _tabController = TabController(
      length: widget.tabs.length,
      vsync: this,
      initialIndex: initialIndex,
    );
    _tabController.addListener(_onTabControllerChanged);
    _saveVisible = ValueNotifier<bool>(
      widget.tabs[initialIndex].contributesToSave,
    );
  }

  @override
  void dispose() {
    _detachVm();
    _tabController.removeListener(_onTabControllerChanged);
    _tabController.dispose();
    _saveVisible.dispose();
    _previewShown.dispose();
    super.dispose();
  }

  void _onTabControllerChanged() {
    if (_tabController.indexIsChanging) return;
    final tab = widget.tabs[_tabController.index];
    _saveVisible.value = tab.contributesToSave;
    final desiredPath = tab.slug.isEmpty
        ? widget.basePath
        : '${widget.basePath}/${tab.slug}';
    final currentPath = GoRouterState.of(context).uri.path;
    if (currentPath == desiredPath) return;
    context.go(desiredPath);
  }

  void _attachVm(SettingsDraftHost vm) {
    if (identical(_boundVm, vm)) return;
    _detachVm();
    final resolve = widget.resolveErrorTabSlug;
    if (resolve == null) return;
    void listener() {
      if (!mounted) return;
      final slug = resolve(vm);
      if (slug == null) return;
      final index = _indexForSlug(slug);
      if (index == _tabController.index || _tabController.indexIsChanging) {
        return;
      }
      _tabController.animateTo(index);
    }

    vm.addListener(listener);
    _boundVm = vm;
    _vmListener = listener;
  }

  void _detachVm() {
    final vm = _boundVm;
    final listener = _vmListener;
    if (vm != null && listener != null) {
      vm.removeListener(listener);
    }
    _boundVm = null;
    _vmListener = null;
  }

  int _indexForSlug(String? slug) {
    if (slug == null || slug.isEmpty) return 0;
    for (var i = 0; i < widget.tabs.length; i++) {
      if (widget.tabs[i].slug == slug) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final currentTab = GoRouterState.of(context).pathParameters['tab'];
    final urlIndex = _indexForSlug(currentTab);
    if (urlIndex != _tabController.index && !_tabController.indexIsChanging) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (urlIndex != _tabController.index) {
          _tabController.animateTo(urlIndex);
        }
      });
    }

    final services = context.read<Services>();
    final tokens = context.inTheme;
    return SettingsCompanyScopedHost<SettingsDraftHost>(
      // Scope is captured once at mount. Safe only because
      // `tabbedSettingsRoutePair` (settings_routes.dart) wraps the shellBuilder
      // in `_SettingsLevelKeyed`, which remounts the whole subtree on level/
      // targetId flips. Mount this shell outside that helper and the level
      // change won't pick up here.
      create: (companyId) {
        final vm = resolveCascadeDraftVm(
          services,
          companyId,
          () => widget.companyVmFactory(
            repo: services.company,
            companyId: companyId,
          ),
        );
        unawaited(vm.load());
        return vm;
      },
      builder: (context, vm) {
        _attachVm(vm);
        final hasSidePane = widget.sidePane != null;
        return SettingsPageScaffold<SettingsDraftHost>(
          titleKey: widget.titleKey,
          viewModel: vm,
          extraActions: widget.extraActions,
          saveVisible: _saveVisible,
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.center,
            labelColor: tokens.ink,
            unselectedLabelColor: tokens.ink3,
            indicatorColor: tokens.accent,
            indicatorWeight: 2,
            tabs: [
              for (final tab in widget.tabs)
                Tab(text: context.tr(tab.labelKey)),
            ],
          ),
          body: _buildBody(context, hasSidePane),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, bool hasSidePane) {
    final tabBarView = TabBarView(
      controller: _tabController,
      children: [for (final tab in widget.tabs) tab.body],
    );
    final content = hasSidePane
        ? CascadeSidePaneLayout(
            tabBarView: tabBarView,
            sidePane: widget.sidePane!,
            previewShown: _previewShown,
            fullScreenBuilder: widget.sidePaneFullScreenBuilder,
            tabController: _tabController,
            tabs: widget.tabs,
          )
        : tabBarView;
    if (widget.banner == null) return content;
    return Column(
      children: [
        widget.banner!,
        Expanded(child: content),
      ],
    );
  }
}

/// Responsive wrapper, with the body's own `LayoutBuilder` constraints as the
/// **single** source of truth for every mode (so a sidebar-narrowed detail
/// pane never disagrees with the window width):
///   * `>= Breakpoints.slideOver`: tabs + pane side-by-side, ~50/50.
///   * `>= Breakpoints.wide`: in-place toggle swaps the full-width tab content
///     for the full-width pane.
///   * `< Breakpoints.wide`: tab content + a "Preview" button that opens the
///     fullscreen-dialog pane (phone fallback).
///
/// The active tab's [TabbedSettingsTab.topBarLeading] is drawn above the tab
/// content in **all three** modes. The side-by-side one has no preview button
/// and so had no bar, which is how Custom Designs lost its "+ New Design" on
/// exactly the widest layout.
@visibleForTesting
class CascadeSidePaneLayout extends StatelessWidget {
  const CascadeSidePaneLayout({
    super.key,
    required this.tabBarView,
    required this.sidePane,
    required this.previewShown,
    required this.fullScreenBuilder,
    required this.tabController,
    required this.tabs,
  });

  final Widget tabBarView;
  final Widget sidePane;
  final ValueNotifier<bool> previewShown;
  final Widget Function(BuildContext context)? fullScreenBuilder;
  final TabController tabController;
  final List<TabbedSettingsTab> tabs;

  /// The active tab's `topBarLeading`. Call it inside an [AnimatedBuilder] on
  /// [tabController] so the bar refreshes when the user switches tabs.
  Widget? _currentLeading() {
    final i = tabController.index;
    if (i < 0 || i >= tabs.length) return null;
    return tabs[i].topBarLeading;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        if (w >= Breakpoints.slideOver) {
          // The wide branch ignores `previewShown` — no reset here (a
          // post-frame mutation would risk touching a disposed notifier and
          // would discard the user's last toggle on a widen→shrink).
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // No preview button here, but the tab's own action still
                    // needs its slot. Always a child, collapsing to nothing
                    // for a tab without one: the tab view below then keeps
                    // its place in the tree, so a tab switch — which flips
                    // the index as the slide *starts* — can't remount it.
                    AnimatedBuilder(
                      animation: tabController,
                      builder: (context, _) {
                        final leading = _currentLeading();
                        return leading == null
                            ? const SizedBox.shrink()
                            : _TabTopBar(leading: leading);
                      },
                    ),
                    Expanded(child: tabBarView),
                  ],
                ),
              ),
              VerticalDivider(width: 1, color: tokens.border),
              Expanded(child: sidePane),
            ],
          );
        }
        if (w >= Breakpoints.wide) {
          return ValueListenableBuilder<bool>(
            valueListenable: previewShown,
            builder: (context, shown, _) {
              return Column(
                children: [
                  AnimatedBuilder(
                    animation: tabController,
                    builder: (context, _) => _PreviewBarButton(
                      icon: shown
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      label: shown
                          ? context.tr('hide_preview')
                          : context.tr('show_preview'),
                      onPressed: () => previewShown.value = !shown,
                      leading: _currentLeading(),
                    ),
                  ),
                  Expanded(child: shown ? sidePane : tabBarView),
                ],
              );
            },
          );
        }
        // Phone: tab content + a button that opens the fullscreen preview.
        // `context` here is inside `SettingsPageScaffold`'s provider scope, so
        // `fullScreenBuilder` can `read` the cascade host / level.
        final builder = fullScreenBuilder;
        return Column(
          children: [
            if (builder != null)
              AnimatedBuilder(
                animation: tabController,
                builder: (context, _) => _PreviewBarButton(
                  icon: Icons.visibility_outlined,
                  label: context.tr('preview'),
                  onPressed: () =>
                      showCascadeFullScreenPreview(context, builder),
                  leading: _currentLeading(),
                ),
              ),
            Expanded(child: tabBarView),
          ],
        );
      },
    );
  }
}

/// The bar above the tab content: the active tab's own action on the left
/// ([TabbedSettingsTab.topBarLeading] — Custom Designs' "+ New Design") and,
/// where the layout has one, the preview button on the right. Every branch of
/// [CascadeSidePaneLayout] draws it, so a tab's action can't go missing at
/// one width.
class _TabTopBar extends StatelessWidget {
  const _TabTopBar({this.leading, this.trailing});

  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        InSpacing.lg(context),
        InSpacing.md(context),
        InSpacing.lg(context),
        InSpacing.md(context),
      ),
      child: Row(
        children: [
          if (leading != null) leading!,
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// [_TabTopBar] with the preview toggle / open button on the right. Shared by
/// the tablet (toggle) and phone (open-modal) branches of
/// [CascadeSidePaneLayout].
class _PreviewBarButton extends StatelessWidget {
  const _PreviewBarButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.leading,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final previewBtn = OutlinedButton.icon(
      style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
      icon: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onPressed,
    );
    return _TabTopBar(leading: leading, trailing: previewBtn);
  }
}

/// Open the cascade settings full-screen preview pane. Modal sub-flow (not
/// page navigation) — see the routing rule in `docs/architecture.md`
/// § Navigation. The [builder] is invoked inside the pushed route so it
/// stays in the caller's provider scope.
Future<void> showCascadeFullScreenPreview(
  BuildContext context,
  Widget Function(BuildContext context) builder,
) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => builder(context),
    ),
  );
}
