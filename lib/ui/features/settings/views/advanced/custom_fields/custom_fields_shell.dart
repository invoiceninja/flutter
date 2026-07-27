import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/enabled_modules.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/settings/view_models/custom_fields_view_model.dart';
import 'package:admin/ui/features/settings/views/advanced/custom_fields/clients_screen.dart';
import 'package:admin/ui/features/settings/views/advanced/custom_fields/company_screen.dart';
import 'package:admin/ui/features/settings/views/advanced/custom_fields/expenses_screen.dart';
import 'package:admin/ui/features/settings/views/advanced/custom_fields/invoices_screen.dart';
import 'package:admin/ui/features/settings/views/advanced/custom_fields/payments_screen.dart';
import 'package:admin/ui/features/settings/views/advanced/custom_fields/products_screen.dart';
import 'package:admin/ui/features/settings/views/advanced/custom_fields/projects_screen.dart';
import 'package:admin/ui/features/settings/views/advanced/custom_fields/tasks_screen.dart';
import 'package:admin/ui/features/settings/views/advanced/custom_fields/users_screen.dart';
import 'package:admin/ui/features/settings/views/advanced/custom_fields/vendors_screen.dart';
import 'package:admin/ui/features/settings/widgets/plan_gate_banner.dart';
import 'package:admin/ui/features/settings/widgets/settings_company_scoped_host.dart';
import 'package:admin/ui/features/settings/widgets/settings_page_scaffold.dart';
import 'package:admin/ui/features/settings/widgets/settings_screen_scaffold.dart';

/// Per-tab definition: URL slug, label key, module gate, and the body widget.
/// `enabledBy == null` means the tab is always visible (Company, Clients,
/// Products, Users); the rest are gated by `company.enabledModules`.
class _CustomFieldsTab {
  const _CustomFieldsTab({
    required this.slug,
    required this.labelKey,
    required this.body,
    this.enabledBy,
  });

  final String slug;
  final String labelKey;
  final Widget body;
  final EnabledModule? enabledBy;
}

/// Full tab catalog in display order. Mirrors React's
/// `pages/settings/custom-fields/CustomFields.tsx` and old Flutter v1's
/// `lib/ui/settings/custom_fields.dart`. The `company` tab uses the empty
/// slug — it's the default landing page at `/settings/custom_fields`.
///
/// No Quotes / Credits tabs by design: quotes, credits, recurring invoices and
/// purchase orders all reuse the **invoice** custom fields (their edit screens
/// read `invoice1..4`), so a separate `quote1..4` / `credit1..4` definition
/// would be dead config. React comments these tabs out; old Flutter aliases
/// `quote*`/`credit*` → `invoice*`.
const _allTabs = <_CustomFieldsTab>[
  _CustomFieldsTab(
    slug: '',
    labelKey: 'company',
    body: CustomFieldsCompanyScreen(),
  ),
  _CustomFieldsTab(
    slug: 'clients',
    labelKey: 'clients',
    body: CustomFieldsClientsScreen(),
  ),
  _CustomFieldsTab(
    slug: 'products',
    labelKey: 'products',
    body: CustomFieldsProductsScreen(),
  ),
  _CustomFieldsTab(
    slug: 'invoices',
    labelKey: 'invoices',
    body: CustomFieldsInvoicesScreen(),
    enabledBy: EnabledModule.invoices,
  ),
  _CustomFieldsTab(
    slug: 'payments',
    labelKey: 'payments',
    body: CustomFieldsPaymentsScreen(),
    // Payments piggyback on the Invoices module — there's no separate
    // payments bit. Matches old Flutter's gating.
    enabledBy: EnabledModule.invoices,
  ),
  _CustomFieldsTab(
    slug: 'projects',
    labelKey: 'projects',
    body: CustomFieldsProjectsScreen(),
    enabledBy: EnabledModule.projects,
  ),
  _CustomFieldsTab(
    slug: 'tasks',
    labelKey: 'tasks',
    body: CustomFieldsTasksScreen(),
    enabledBy: EnabledModule.tasks,
  ),
  _CustomFieldsTab(
    slug: 'vendors',
    labelKey: 'vendors',
    body: CustomFieldsVendorsScreen(),
    enabledBy: EnabledModule.vendors,
  ),
  _CustomFieldsTab(
    slug: 'expenses',
    labelKey: 'expenses',
    body: CustomFieldsExpensesScreen(),
    enabledBy: EnabledModule.expenses,
  ),
  _CustomFieldsTab(
    slug: 'users',
    labelKey: 'users',
    body: CustomFieldsUsersScreen(),
  ),
];

/// Prefix → slug map used by 422 field-error → tab routing. When the server
/// rejects a save with field errors on `custom_fields.<prefix><n>` we jump
/// to the tab that hosts that prefix.
const _prefixToSlug = <String, String>{
  'company': '',
  'client': 'clients',
  'contact': 'clients',
  'location': 'clients',
  'product': 'products',
  'invoice': 'invoices',
  'surcharge': 'invoices',
  'custom_surcharge_taxes': 'invoices',
  'payment': 'payments',
  'project': 'projects',
  'task': 'tasks',
  'vendor': 'vendors',
  'vendor_contact': 'vendors',
  'expense': 'expenses',
  'user': 'users',
};

/// `/settings/custom_fields/[:tab]` shell. Mirrors [TabbedSettingsShell] but
/// computes the visible tab list at runtime from the active company's
/// `enabled_modules` — the generic shell takes a fixed list.
///
/// Pairs with `tabbedSettingsRoutePair(path: 'custom_fields', …)` in
/// `settings_routes.dart` — the shared page key keeps this widget's
/// `TabController` + draft VM alive when the URL flips between the bare
/// path and a `/:tab` segment.
class CustomFieldsShell extends StatefulWidget {
  const CustomFieldsShell({super.key, this.initialTab});

  /// `:tab` path parameter from the route, or null on the bare URL.
  final String? initialTab;

  @override
  State<CustomFieldsShell> createState() => _CustomFieldsShellState();
}

class _CustomFieldsShellState extends State<CustomFieldsShell> {
  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    return SettingsCompanyScopedHost<CustomFieldsViewModel>(
      create: (companyId) {
        final vm = CustomFieldsViewModel(
          repo: services.company,
          companyId: companyId,
        );
        unawaited(vm.load());
        return vm;
      },
      builder: (context, vm) {
        return ListenableBuilder(
          listenable: vm,
          builder: (context, _) {
            // Pre-load: avoid building a TabController against a tab count we
            // don't know yet. Use the plain screen scaffold (no TabBar) so
            // the title still shows.
            if (!vm.isLoaded || vm.draft == null) {
              return SettingsScreenScaffold(
                titleKey: 'custom_fields',
                body: const Center(child: CircularProgressIndicator()),
              );
            }
            final visible = _visibleTabs(vm.draft!.enabledModules);
            // Remount the inner shell whenever the visible-tab signature
            // changes (modules toggled, company switched). The ValueKey
            // tears down + rebuilds the TabController without a manual
            // length check.
            return KeyedSubtree(
              key: ValueKey(
                'cf:${vm.draft!.id}:'
                '${visible.map((t) => t.slug).join(',')}',
              ),
              child: _LoadedShell(
                vm: vm,
                visible: visible,
                initialTab: widget.initialTab,
              ),
            );
          },
        );
      },
    );
  }

  List<_CustomFieldsTab> _visibleTabs(int enabledModules) {
    return [
      for (final tab in _allTabs)
        if (tab.enabledBy == null ||
            isModuleEnabled(enabledModules, tab.enabledBy!))
          tab,
    ];
  }
}

/// Inner shell. By construction `vm.draft != null` here; we only mount this
/// widget once the visible-tab set is known.
class _LoadedShell extends StatefulWidget {
  const _LoadedShell({
    required this.vm,
    required this.visible,
    required this.initialTab,
  });

  final CustomFieldsViewModel vm;
  final List<_CustomFieldsTab> visible;
  final String? initialTab;

  @override
  State<_LoadedShell> createState() => _LoadedShellState();
}

class _LoadedShellState extends State<_LoadedShell>
    with SingleTickerProviderStateMixin {
  late final TabController _controller;
  VoidCallback? _vmListener;

  int _indexForSlug(String? slug) {
    final s = slug ?? '';
    for (var i = 0; i < widget.visible.length; i++) {
      if (widget.visible[i].slug == s) return i;
    }
    // Slug points at a hidden tab (module disabled) or unknown — fall back
    // to the first visible tab. Deep links to /settings/custom_fields/tasks
    // resolve here when Tasks is off.
    return 0;
  }

  @override
  void initState() {
    super.initState();
    _controller = TabController(
      length: widget.visible.length,
      vsync: this,
      initialIndex: _indexForSlug(widget.initialTab),
    );
    _controller.addListener(_onTabSettled);
    _bindVm();
  }

  @override
  void didUpdateWidget(covariant _LoadedShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The host swaps the ViewModel in place on a company switch
    // (`SettingsCompanyScopedHost` — no key in that chain, so this State is
    // reused). Without re-binding, the listener stays attached to the old,
    // disposed VM and `dispose` removes it from the wrong instance, so the
    // 422 → jump-to-offending-tab behaviour silently stops working.
    if (!identical(oldWidget.vm, widget.vm)) {
      if (_vmListener != null) oldWidget.vm.removeListener(_vmListener!);
      _vmListener = null;
      _bindVm();
    }
  }

  @override
  void dispose() {
    if (_vmListener != null) widget.vm.removeListener(_vmListener!);
    _controller.removeListener(_onTabSettled);
    _controller.dispose();
    super.dispose();
  }

  /// Push the controller's settled index into the URL so deep links + back
  /// button reflect the active tab. Skipped while `indexIsChanging` because
  /// the animation hasn't settled yet — we only want one navigation per
  /// user interaction.
  void _onTabSettled() {
    if (_controller.indexIsChanging) return;
    final tab = widget.visible[_controller.index];
    final desiredPath = tab.slug.isEmpty
        ? '/settings/custom_fields'
        : '/settings/custom_fields/${tab.slug}';
    final currentPath = GoRouterState.of(context).uri.path;
    if (currentPath == desiredPath) return;
    context.go(desiredPath);
  }

  /// Subscribe the shell to the VM so a 422 → field error animates the
  /// TabBar to the offending tab.
  void _bindVm() {
    void listener() {
      if (!mounted) return;
      final slug = _slugForFieldErrors(widget.vm.fieldErrors);
      if (slug == null) return;
      final index = _indexForSlug(slug);
      if (index == _controller.index || _controller.indexIsChanging) return;
      _controller.animateTo(index);
    }

    widget.vm.addListener(listener);
    _vmListener = listener;
  }

  /// Map the first field-error key to its tab slug. Keys arrive in the form
  /// `custom_fields.<prefix><n>` (e.g. `custom_fields.invoice2`) or
  /// `custom_surcharge_taxes<n>`. Returns null when no key matches a known
  /// prefix — the standard 422 banner still surfaces.
  String? _slugForFieldErrors(Map<String, List<String>> errors) {
    for (final key in errors.keys) {
      final normalized = key.startsWith('custom_fields.')
          ? key.substring('custom_fields.'.length)
          : key;
      // Strip trailing digits to recover the prefix.
      final prefix = normalized.replaceFirst(RegExp(r'\d+$'), '');
      final slug = _prefixToSlug[prefix];
      if (slug != null) return slug;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Keep the controller in sync if the URL changed externally (back button,
    // settings search). The `!= _controller.index` guard prevents the
    // controller listener (which pushes URL updates) from looping back into
    // another `animateTo`.
    final currentTab = GoRouterState.of(context).pathParameters['tab'];
    final urlIndex = _indexForSlug(currentTab);
    if (urlIndex != _controller.index && !_controller.indexIsChanging) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (urlIndex != _controller.index) {
          _controller.animateTo(urlIndex);
        }
      });
    }

    final tokens = context.inTheme;
    final session = context.read<Services>().auth.session.value;
    // Editing requires a paid plan AND an admin/owner role — matches React's
    // `useShouldDisableCustomFields` (`(pro||enterprise) && isAdmin`). The
    // per-company role is read from `currentCompany`, like `system_logs`.
    // The PlanGateBanner stays plan-only, so a non-admin Pro user sees
    // read-only fields without a misleading upgrade CTA.
    final me = session?.currentCompany;
    final isAdminOrOwner = (me?.isAdmin ?? false) || (me?.isOwner ?? false);
    final canEdit = (session?.hasProAccess ?? false) && isAdminOrOwner;

    final tabBar = TabBar(
      controller: _controller,
      isScrollable: true,
      tabAlignment: TabAlignment.center,
      labelColor: tokens.ink,
      unselectedLabelColor: tokens.ink3,
      indicatorColor: tokens.accent,
      indicatorWeight: 2,
      tabs: [
        for (final tab in widget.visible) Tab(text: context.tr(tab.labelKey)),
      ],
    );

    Widget body = TabBarView(
      controller: _controller,
      // Each tab body is a Builder so we can wrap it in a default `enabled`
      // gate via InheritedWidget without churning every entity screen.
      children: [
        for (final tab in widget.visible)
          _CustomFieldsAccessScope(
            companyId: widget.vm.draft!.id,
            enabled: canEdit,
            child: tab.body,
          ),
      ],
    );

    body = Column(
      children: [
        const PlanGateBanner(style: PlanGateStyle.stripe),
        Expanded(child: body),
      ],
    );

    return SettingsPageScaffold<CustomFieldsViewModel>(
      titleKey: 'custom_fields',
      viewModel: widget.vm,
      bottom: tabBar,
      body: body,
    );
  }
}

/// Inherited scope that carries the `enabled` flag (Pro-plan gate) and the
/// `companyId` (used by per-row `ValueKey` to reset `TextEditingController`s
/// on company switch) down to every [CustomFieldRow].
class _CustomFieldsAccessScope extends InheritedWidget {
  const _CustomFieldsAccessScope({
    required this.companyId,
    required this.enabled,
    required super.child,
  });

  final String companyId;
  final bool enabled;

  static _CustomFieldsAccessScope of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_CustomFieldsAccessScope>();
    assert(scope != null, 'CustomFieldsAccessScope is required');
    return scope!;
  }

  @override
  bool updateShouldNotify(_CustomFieldsAccessScope old) =>
      enabled != old.enabled || companyId != old.companyId;
}

/// Public accessor for the entity screens — they read this to seed each row
/// with `enabled` + the per-company `ValueKey`.
({String companyId, bool enabled}) customFieldsAccess(BuildContext context) {
  final scope = _CustomFieldsAccessScope.of(context);
  return (companyId: scope.companyId, enabled: scope.enabled);
}
