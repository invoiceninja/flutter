import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company_gateway.dart';
import 'package:admin/data/models/value/gateway.dart';
import 'package:admin/domain/gateway_constants.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/edit/edit_action_filter.dart';
import 'package:admin/ui/core/edit/entity_edit_screen_scaffold.dart';
import 'package:admin/ui/core/list/master_detail_layout.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/features/gateways/view_models/company_gateway_edit_view_model.dart';
import 'package:admin/ui/features/gateways/widgets/company_gateway_actions.dart';
import 'package:admin/ui/features/gateways/widgets/edit/gateway_config_form.dart';
import 'package:admin/ui/features/gateways/widgets/edit/gateway_limits_fees_tab.dart';
import 'package:admin/ui/features/gateways/widgets/edit/gateway_required_fields_tab.dart';
import 'package:admin/ui/features/gateways/widgets/edit/gateway_settings_tab.dart';
import 'package:admin/ui/features/gateways/widgets/edit/gateway_type_picker.dart';
import 'package:admin/ui/features/gateways/widgets/edit/oauth_stub_card.dart';

/// Labels surfaced on the edit screen for the in-app settings search index.
const kCompanyGatewayEditSearchKeys = <String>[
  'credentials',
  'settings',
  'required_fields_label',
  'limits_and_fees',
  'test_mode',
  'token_billing',
  'payment_methods',
];

const _kTabSlugs = <String>[
  '',
  'settings',
  'required_fields',
  'limits_and_fees',
];

/// Edit / create CompanyGateway. The actual VM lifecycle + chrome lives in
/// the shared `EntityEditScreenScaffold` — this screen contributes the
/// per-entity wiring, the per-create picker fork, and the 4-tab body.
///
/// Flow:
///   * Edit existing → scaffold fetches the row → `buildVm(existing:)`
///     constructs the VM correctly (`_original != null`, `isCreate = false`).
///   * Create with `?gateway=<key>` → scaffold buildVm with `existing: null`
///     and the picked key.
///   * Create without `?gateway=` → render the gateway-type picker
///     standalone first (no Save button); on select, swap into the
///     scaffold with the chosen key.
class CompanyGatewayEditScreen extends StatefulWidget {
  const CompanyGatewayEditScreen({
    super.key,
    this.existingId,
    this.initialGatewayKey,
    this.initialTab,
  });

  /// `null` in create mode.
  final String? existingId;

  /// `?gateway=<key>` route query.
  final String? initialGatewayKey;

  /// `:tab` path-param. Resolves to the first tab when null.
  final String? initialTab;

  @override
  State<CompanyGatewayEditScreen> createState() =>
      _CompanyGatewayEditScreenState();
}

class _CompanyGatewayEditScreenState extends State<CompanyGatewayEditScreen> {
  /// Tracks the user's picker selection in the standalone-picker phase of
  /// the create flow. Seeded from `widget.initialGatewayKey` so a deep link
  /// like `/settings/company_gateways/new?gateway=<key>` skips straight to
  /// the tabbed form.
  String? _pickedGatewayKey;

  @override
  void initState() {
    super.initState();
    _pickedGatewayKey = widget.initialGatewayKey;
  }

  /// Picker → tabbed-form transition. Before accepting a brand-new gateway,
  /// warn if one of the same provider already exists (mirrors React's
  /// `DuplicatingGatewayModal`) — except providers that legitimately support
  /// multiple instances (PayPal Platform / PPCP, Stripe Connect).
  Future<void> _onPickGateway(String key) async {
    final services = context.read<Services>();
    final allowsMultiple =
        key == kGatewayPayPalPlatform || key == kGatewayStripeConnect;
    if (!allowsMultiple) {
      final companyId = services.auth.session.value!.currentCompanyId;
      final existing = await services.companyGateways
          .watchPage(companyId: companyId)
          .first;
      if (existing.any((g) => g.gatewayKey == key)) {
        if (!mounted) return;
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(ctx.tr('existing_gateway')),
            content: Text(ctx.tr('confirm_duplicate_gateway')),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(ctx.tr('no')),
              ),
              PrimaryDialogAction(
                label: ctx.tr('yes'),
                onPressed: () => Navigator.of(ctx).pop(true),
              ),
            ],
          ),
        );
        if (proceed != true) return;
      }
    }
    if (!mounted) return;
    setState(() => _pickedGatewayKey = key);
  }

  @override
  Widget build(BuildContext context) {
    // Create flow without a chosen provider yet → render the picker
    // standalone. Bypasses the edit scaffold entirely because the Save
    // button + dirty guard don't apply until the user has picked a
    // provider.
    if (widget.existingId == null &&
        (_pickedGatewayKey == null || _pickedGatewayKey!.isEmpty)) {
      return Scaffold(
        appBar: AppBar(title: Text(context.tr('new_company_gateway'))),
        body: GatewayTypePicker(onSelected: _onPickGateway),
      );
    }

    return EntityEditScreenScaffold<
      CompanyGateway,
      CompanyGatewayEditViewModel
    >(
      existingId: widget.existingId,
      entityTypeName: 'company_gateway',
      fetchExisting: (ctx, services, companyId, id) =>
          services.companyGateways.watch(companyId: companyId, id: id).first,
      buildVm: (ctx, services, companyId, existing) =>
          CompanyGatewayEditViewModel(
            repo: services.companyGateways,
            companyId: companyId,
            existing: existing,
            initialGatewayKey: _pickedGatewayKey,
            sync: services.sync,
            connectivity: services.connectivity,
          ),
      titleWhileLoading: (ctx) => widget.existingId == null
          ? ctx.tr('new_company_gateway')
          : ctx.tr('edit_company_gateway'),
      titleBuilder: (ctx, vm) => vm.isCreate
          ? ctx.tr('new_company_gateway')
          : ctx.tr('edit_company_gateway'),
      bodyBuilder: (ctx, vm) =>
          _GatewayEditBody(vm: vm, initialTab: widget.initialTab),
      resetToEmpty: (vm) => vm.reset(emptyDraft: vm.emptyDraft()),
      entityIdOf: (g) => g.id,
      actionsBuilder: (ctx, vm, onTap, saveButton) =>
          EntityOverflowActionBar<CompanyGatewayAction>(
            leading: saveButton,
            items: filterForEditScreen(
              CompanyGatewayActions.itemsFor(ctx, vm.draft, (a) => onTap(a)),
              isCreate: vm.isCreate,
              isLifecycle: CompanyGatewayActions.isLifecycle,
            ),
          ),
      onAfterSaveAction: (ctx, saved, a) {
        final services = ctx.read<Services>();
        return CompanyGatewayActions.dispatch(
          ctx,
          services,
          services.auth.session.value!.currentCompanyId,
          saved,
          a as CompanyGatewayAction,
        );
      },
      onSaved: (ctx, vm, saved) => goAfterEntitySave(
        ctx,
        isCreate: vm.isCreate,
        basePath: '/settings/company_gateways',
        savedId: saved.id,
      ),
    );
  }
}

/// Tabbed body for the edit screen. Owns the `TabController` and the
/// per-tab routing. Reads gateway statics off Provider on demand (rather
/// than caching) so the tabs see fresh provider metadata if the statics
/// blob refreshes mid-edit.
class _GatewayEditBody extends StatefulWidget {
  const _GatewayEditBody({required this.vm, required this.initialTab});

  final CompanyGatewayEditViewModel vm;
  final String? initialTab;

  @override
  State<_GatewayEditBody> createState() => _GatewayEditBodyState();
}

class _GatewayEditBodyState extends State<_GatewayEditBody>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    final initialIndex = _indexForSlug(widget.initialTab) >= 0
        ? _indexForSlug(widget.initialTab)
        // Default-to-Settings when editing existing; create flow opens on
        // Credentials so the user fills out the gateway-specific fields
        // first.
        : (widget.vm.isCreate ? 0 : 1);
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: initialIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  int _indexForSlug(String? slug) {
    if (slug == null || slug.isEmpty) return 0;
    for (var i = 0; i < _kTabSlugs.length; i++) {
      if (_kTabSlugs[i] == slug) return i;
    }
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.vm,
      builder: (context, _) =>
          _TabbedBody(vm: widget.vm, tabController: _tabController),
    );
  }
}

class _TabbedBody extends StatelessWidget {
  const _TabbedBody({required this.vm, required this.tabController});

  final CompanyGatewayEditViewModel vm;
  final TabController tabController;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final statics = context.read<Services>().statics;
    final gateway = statics.gateway(vm.draft.gatewayKey);
    final errorSlug = vm.errorTabSlug();
    return Column(
      children: [
        TabBar(
          controller: tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.center,
          labelColor: tokens.ink,
          unselectedLabelColor: tokens.ink3,
          indicatorColor: tokens.accent,
          indicatorWeight: 2,
          tabs: [
            _Tab(
              label: context.tr('credentials'),
              error: errorSlug == 'credentials',
            ),
            _Tab(label: context.tr('settings'), error: errorSlug == 'settings'),
            _Tab(
              label: context.tr('required_fields_label'),
              error: errorSlug == 'required_fields',
            ),
            _Tab(
              label: context.tr('limits_and_fees'),
              error: errorSlug == 'limits_and_fees',
            ),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: tabController,
            children: [
              _credentialsTab(context, gateway),
              gateway == null
                  ? _loadingTab(context)
                  : GatewaySettingsTab(vm: vm, gateway: gateway),
              GatewayRequiredFieldsTab(vm: vm),
              GatewayLimitsFeesTab(vm: vm),
            ],
          ),
        ),
      ],
    );
  }

  Widget _credentialsTab(BuildContext context, Gateway? gateway) {
    if (gateway == null) return _loadingTab(context);
    if (vm.draft.isOAuthGateway) {
      return OAuthStubCard(gateway: gateway);
    }
    return GatewayConfigForm(vm: vm, gateway: gateway);
  }

  Widget _loadingTab(BuildContext context) {
    return Center(child: Text(context.tr('loading_ellipsis')));
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.error});
  final String label;
  final bool error;

  @override
  Widget build(BuildContext context) {
    if (!error) return Tab(text: label);
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }
}
