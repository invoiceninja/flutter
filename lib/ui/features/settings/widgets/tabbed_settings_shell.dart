import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/settings/view_models/settings_draft_view_model.dart';
import 'package:admin/ui/features/settings/widgets/settings_company_scoped_host.dart';
import 'package:admin/ui/features/settings/widgets/settings_page_scaffold.dart';

/// One entry in a [TabbedSettingsShell]'s tab list.
class TabbedSettingsTab {
  const TabbedSettingsTab({
    required this.slug,
    required this.labelKey,
    required this.body,
    this.contributesToSave = true,
    this.topBarLeading,
  });

  /// URL suffix without leading slash. The default tab uses an empty
  /// string — it resolves to the shell's bare base path (no `:tab`
  /// segment). The remaining tabs use their literal slug.
  final String slug;

  /// Localization key for the TabBar label (passed through `context.tr`).
  final String labelKey;

  /// Tab body. Construct fresh per build — see the non-const-children note
  /// on [TabbedSettingsShell]'s `TabBarView` for why.
  final Widget body;

  /// When `false`, the shell hides the AppBar Save button while this tab is
  /// active. Use for tabs whose body doesn't bind to the shell's VM (e.g.
  /// self-contained flows like Two Factor, or device-local controllers like
  /// Theme + Language) — a Save button there would read as a no-op.
  final bool contributesToSave;

  /// Optional widget that the cascade shell renders at the **top-left** of
  /// the tab content while this tab is active, at every width — beside the
  /// preview button where the layout has one, on its own where the preview
  /// sits alongside. Lets a tab inject its primary action (e.g. Custom
  /// Designs' "New design") so it shares a line with the Show Preview toggle
  /// instead of duplicating a vertical stack inside the body.
  final Widget? topBarLeading;
}

/// Generic tabbed shell for company-only settings pages whose contents are
/// split across tabs (Company Details today; Client Portal / Templates &
/// Reminders next). Owns:
///
/// * the [TabController] (length matches [tabs], vsync = this) and its
///   disposal,
/// * the bi-directional URL ↔ tab-index sync (`_onTabControllerChanged`
///   pushes the settled index into the route via `context.go`; the build
///   method animates the controller when the URL changes externally — e.g.
///   the back button, a deep link, or the settings-search jump),
/// * the compose pattern `SettingsCompanyScopedHost<V>` →
///   `SettingsPageScaffold<V>` with `bottom: TabBar(...)` and
///   `body: TabBarView(...)`.
///
/// The caller supplies just `titleKey`, `basePath`, the optional `initialTab`
/// from the route, a `companyVmFactory`, and the `tabs` list. The shell calls
/// `vm.load()` itself, matching the precedent in the cascade scaffold.
///
/// Pair with [tabbedSettingsRoutePair] (in `settings_routes.dart`) to
/// register the matching bare-URL + `/:tab(<a>|<b>|...)` route entries — the
/// shared page key in that helper is what keeps the [TabController] + draft
/// VM alive across the two paths.
class TabbedSettingsShell<V extends SettingsDraftHost> extends StatefulWidget {
  const TabbedSettingsShell({
    super.key,
    required this.titleKey,
    required this.basePath,
    required this.initialTab,
    required this.companyVmFactory,
    required this.tabs,
    this.extraActions = const <Widget>[],
    this.resolveErrorTabSlug,
    this.banner,
  }) : assert(tabs.length >= 2, 'TabbedSettingsShell needs at least two tabs');

  /// Localization key for the AppBar title.
  final String titleKey;

  /// Absolute path of the shell's bare URL (no trailing `/`). Used to
  /// build the per-tab URL when the controller settles on a new index.
  final String basePath;

  /// The `:tab` path-parameter from the route, or null on the bare URL
  /// (resolves to the first tab).
  final String? initialTab;

  /// Build the typed VM for the active company. Same shape as the
  /// `create` callback on [SettingsCompanyScopedHost]; the shell calls
  /// `vm.load()` itself, so the factory should *not* invoke load.
  final V Function(String companyId) companyVmFactory;

  /// Tab definitions, in display order. The first entry's `slug` should
  /// be empty (the default tab); the rest carry their literal slug.
  final List<TabbedSettingsTab> tabs;

  /// Additional AppBar action widgets rendered to the right of the Save
  /// button (passthrough to [SettingsPageScaffold]).
  final List<Widget> extraActions;

  /// Optional 422 → tab-jump resolver. The shell listens to the VM and, on
  /// every notify, calls this with the VM to ask which tab a freshly-arrived
  /// field error lives on. Return the matching tab's slug to animate there
  /// (no-op if it's already active or the slug is unknown). Pass `null` (the
  /// default) to disable the jump — the standard 422 banner still surfaces;
  /// the user just has to switch tabs themselves.
  final String? Function(V vm)? resolveErrorTabSlug;

  /// Optional full-width widget rendered below the TabBar and above the
  /// TabBarView body — typically a stripe-style `PlanGateBanner` for
  /// plan-gated surfaces. When null the body fills the whole area as
  /// before.
  final Widget? banner;

  @override
  State<TabbedSettingsShell<V>> createState() => _TabbedSettingsShellState<V>();
}

class _TabbedSettingsShellState<V extends SettingsDraftHost>
    extends State<TabbedSettingsShell<V>>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  /// Mirrors the active tab's [TabbedSettingsTab.contributesToSave] flag.
  /// Wired into [SettingsPageScaffold.saveVisible] so the AppBar Save button
  /// hides on tabs that don't bind to the VM (Two Factor, Preferences).
  late final ValueNotifier<bool> _saveVisible;

  /// VM the [TabbedSettingsShell.resolveErrorTabSlug] callback is currently
  /// subscribed against. Re-bound whenever the host swaps the VM on company
  /// switch.
  V? _boundVm;
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
    super.dispose();
  }

  /// Push the controller's settled index into the URL so deep links + back
  /// button reflect the active tab. Skipped while `indexIsChanging` because
  /// the animation hasn't settled yet — we only want one navigation per
  /// user interaction.
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

  /// Subscribe the shell to the active VM so a 422 lands → jump to the
  /// offending tab. Idempotent — repeat calls with the same VM are no-ops.
  void _attachVm(V vm) {
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
    // Keep the controller in sync if the URL changed externally (back
    // button, deep link, settings search). The `!= _tabController.index`
    // guard prevents the controller listener (which pushes URL updates)
    // from looping back into another `animateTo`.
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

    final tokens = context.inTheme;
    return SettingsCompanyScopedHost<V>(
      create: (companyId) {
        final vm = widget.companyVmFactory(companyId);
        unawaited(vm.load());
        return vm;
      },
      builder: (context, vm) {
        _attachVm(vm);
        return SettingsPageScaffold<V>(
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
          // Children are intentionally non-const: when external state
          // changes (e.g. statics finish loading, scope flips) and the shell
          // rebuilds, fresh widget instances let `Element.updateChild`
          // walk into the subtree instead of short-circuiting on identity.
          body: widget.banner == null
              ? TabBarView(
                  controller: _tabController,
                  children: [for (final tab in widget.tabs) tab.body],
                )
              : Column(
                  children: [
                    widget.banner!,
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [for (final tab in widget.tabs) tab.body],
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
