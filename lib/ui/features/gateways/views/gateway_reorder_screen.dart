import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company_gateway.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/core/widgets/status_pill.dart';
import 'package:admin/ui/features/gateways/gateway_order_writer.dart';
import 'package:admin/ui/features/settings/state/settings_level_controller.dart';
import 'package:admin/ui/features/settings/widgets/settings_scope_banner.dart';

/// Read-only, inline-reorder gateway list shown at non-company scopes.
/// Company scope continues to use `CompanyGatewayListScreen`'s CRUD list.
///
/// What this screen owns:
///   * the scope banner (delegated to `SettingsScopeBanner`),
///   * a `ReorderableListView` with drag handles,
///   * debounced save through `writeGatewayOrder(...)`,
///   * the inheritance hint until the user makes their first explicit drop,
///   * a "Reset to default" AppBar action that clears the scope's override.
///
/// Reads are sourced from `services.companyGateways.watchPage(...)` with
/// `states: {EntityState.active}` so archived / deleted rows don't appear
/// in the reorder set.
class GatewayReorderScreen extends StatefulWidget {
  const GatewayReorderScreen({super.key});

  @override
  State<GatewayReorderScreen> createState() => _GatewayReorderScreenState();
}

class _GatewayReorderScreenState extends State<GatewayReorderScreen> {
  static const _kDebounce = Duration(milliseconds: 250);

  late final Services _services;
  late final SettingsLevelController _scope;
  late final String _companyId;

  /// Source-of-truth gateway rows from the repo. The reordered display
  /// list is materialized from this + `_resolution.csv` on each rebuild.
  List<CompanyGateway> _gateways = const [];

  /// The current scope's resolved order + override state, refreshed
  /// whenever the underlying entity emits.
  GatewayOrderResolution _resolution = const GatewayOrderResolution(
    csv: '',
    isOverriding: false,
  );

  /// User-driven local override of the displayed order between the last
  /// committed save and the next one. Cleared on save / reset.
  List<String>? _pendingOrder;

  /// Hides the inheritance hint after the user's first explicit drop.
  /// Re-enabled on reset.
  bool _hintDismissed = false;

  StreamSubscription<List<CompanyGateway>>? _gatewaysSub;
  Timer? _saveDebounce;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _services = context.read<Services>();
    _scope = context.read<SettingsLevelController>();
    _companyId = _services.auth.session.value!.currentCompanyId;
    _subscribeGateways();
    _resolveOrder();
  }

  void _subscribeGateways() {
    _gatewaysSub = _services.companyGateways
        .watchPage(
          companyId: _companyId,
          loadedPages: 1,
          states: const {EntityState.active},
        )
        .listen((rows) {
          if (!mounted) return;
          setState(() => _gateways = rows);
        });
  }

  Future<void> _resolveOrder() async {
    final next = await resolveGatewayOrder(_services, _scope);
    if (!mounted) return;
    setState(() => _resolution = next);
  }

  @override
  void dispose() {
    _gatewaysSub?.cancel();
    _saveDebounce?.cancel();
    super.dispose();
  }

  /// Build the displayed gateway sequence. Priority:
  ///   1. User's in-flight `_pendingOrder` from the latest drop, if any.
  ///   2. The resolved scope-or-inherited CSV from `_resolution`.
  ///   3. Whatever Drift returned (already sorted by the list VM's default).
  List<CompanyGateway> get _orderedGateways {
    if (_gateways.isEmpty) return const [];
    final csvSource = _pendingOrder?.join(',') ?? _resolution.csv;
    if (csvSource.isEmpty) return _gateways;
    final byId = {for (final g in _gateways) g.id: g};
    final ordered = csvSource.split(',').where((s) => s.isNotEmpty).toList();
    final out = <CompanyGateway>[
      for (final id in ordered)
        if (byId.containsKey(id)) byId.remove(id)!,
      ...byId.values, // rows the CSV doesn't mention land at the bottom.
    ];
    return out;
  }

  void _onReorder(int oldIndex, int newIndex) {
    final ordered = _orderedGateways;
    if (ordered.isEmpty) return;
    final next = List<CompanyGateway>.from(ordered);
    final moved = next.removeAt(oldIndex);
    next.insert(newIndex, moved);
    setState(() {
      _pendingOrder = next.map((g) => g.id).toList();
      _hintDismissed = true;
    });
    _scheduleSave();
  }

  void _scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(_kDebounce, _commit);
  }

  Future<void> _commit() async {
    final pending = _pendingOrder;
    if (pending == null) return;
    setState(() => _saving = true);
    try {
      await writeGatewayOrder(_services, _scope, pending.join(','));
      // Resolve again — the just-written value should now appear as the
      // active override, flipping `isOverriding` to true.
      await _resolveOrder();
      if (!mounted) return;
      Notify.success(context, context.tr('order_saved'));
    } catch (e) {
      if (mounted) Notify.error(context, e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          // Only clear the pending order if a NEWER drag didn't replace it
          // while the save was in flight — else that later reorder is silently
          // dropped and never saved.
          if (identical(_pendingOrder, pending)) _pendingOrder = null;
        });
      }
    }
  }

  Future<void> _onReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('reset_gateway_order')),
        content: Text(ctx.tr('reset_gateway_order_confirm')),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(64, 40)),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.tr('cancel')),
          ),
          PrimaryDialogAction(
            label: ctx.tr('reset'),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _saving = true);
    try {
      await clearGatewayOrderOverride(_services, _scope);
      await _resolveOrder();
      if (!mounted) return;
      setState(() {
        _pendingOrder = null;
        _hintDismissed = false;
      });
      Notify.success(context, context.tr('order_saved'));
    } catch (e) {
      if (mounted) Notify.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ordered = _orderedGateways;
    final showHint =
        !_hintDismissed && !_resolution.isOverriding && _pendingOrder == null;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('gateway_display_order')),
        actions: [
          IconButton(
            tooltip: context.tr('gateway_order_what_is_this'),
            icon: const Icon(Icons.help_outline),
            // Reveal the explanatory hint banner (was a dead no-op onPressed).
            onPressed: () => setState(() => _hintDismissed = false),
          ),
          if (_resolution.isOverriding)
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size(64, 40)),
              onPressed: _saving ? null : _onReset,
              child: Text(context.tr('reset_gateway_order')),
            ),
          if (_saving)
            Padding(
              padding: EdgeInsets.only(right: InSpacing.md(context)),
              child: const Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          const SettingsScopeBanner(),
          if (showHint) _InheritanceHint(resolution: _resolution),
          Expanded(
            child: ordered.isEmpty
                ? const _EmptyState()
                : ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: InSpacing.sm),
                    buildDefaultDragHandles: false,
                    itemCount: ordered.length,
                    onReorderItem: _onReorder,
                    itemBuilder: (context, i) {
                      final g = ordered[i];
                      return _ReorderRow(
                        key: ValueKey(g.id),
                        gateway: g,
                        index: i,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _InheritanceHint extends StatelessWidget {
  const _InheritanceHint({required this.resolution});
  final GatewayOrderResolution resolution;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final namedSource = resolution.inheritedSourceLabel;
    final text = namedSource != null && namedSource.isNotEmpty
        ? context.tr('gateway_order_inherits_from_group_named', {
            'name': namedSource,
          })
        : context.tr('gateway_order_inherits_from_company');
    return Container(
      width: double.infinity,
      color: tokens.surfaceAlt,
      padding: EdgeInsets.symmetric(
        horizontal: InSpacing.lg(context),
        vertical: InSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: tokens.ink3),
          const SizedBox(width: InSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: tokens.ink2, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReorderRow extends StatelessWidget {
  const _ReorderRow({super.key, required this.gateway, required this.index});

  final CompanyGateway gateway;
  final int index;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final services = context.read<Services>();
    final providerName = services.statics.gateway(gateway.gatewayKey)?.name;
    final display = gateway.resolveDisplayName(gatewayName: providerName);
    return Container(
      decoration: BoxDecoration(
        border: BorderDirectional(bottom: BorderSide(color: tokens.border)),
      ),
      child: ListTile(
        leading: const Icon(Icons.account_balance_wallet_outlined, size: 22),
        title: Text(
          display,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: providerName != null && providerName != display
            ? Text(providerName, maxLines: 1, overflow: TextOverflow.ellipsis)
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (gateway.testMode) ...[
              StatusPill(
                label: context.tr('test'),
                fgColor: tokens.sent,
                bgColor: tokens.sentSoft,
              ),
              const SizedBox(width: InSpacing.sm),
            ],
            ReorderableDragStartListener(
              index: index,
              child: Icon(Icons.drag_handle, color: tokens.ink3),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.account_balance_wallet_outlined,
      title: context.tr('no_company_gateways_yet'),
      subtitle: context.tr('no_gateways_for_reorder_subtitle'),
    );
  }
}
