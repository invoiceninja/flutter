import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/settings/widgets/plan_gate_banner.dart';
import 'package:admin/ui/features/settings/widgets/settings_form_shell.dart';
import 'package:admin/ui/features/settings/widgets/settings_screen_scaffold.dart';

/// Search keys for QuickBooks. Colocated with the screen so the search
/// catalog stays in sync via spread.
const kAccountManagementQuickbooksSearchKeys = <String>[
  'quickbooks',
  'connect',
  'disconnect',
  'company_name',
  'realm_id',
  'import',
  'quickbooks_sync_settings',
  'income_account',
];

/// Settings → Account Management → Integrations → QuickBooks.
///
/// Connect/disconnect + import + ten-entity sync directions + income-account
/// mapping + read-only QB reference tables. The connected-state
/// `quickbooks.settings.*` payload can't be live-verified (the demo account
/// has no QB integration), so the contract source of truth is React's
/// `react/src/common/interfaces/quickbooks.ts`; every `settings.*` sub-key
/// is read defensively (treated as nullable / absent).
class QuickbooksScreen extends StatefulWidget {
  const QuickbooksScreen({super.key});

  @override
  State<QuickbooksScreen> createState() => _QuickbooksScreenState();
}

class _QuickbooksScreenState extends State<QuickbooksScreen> {
  bool _connecting = false;
  bool _disconnecting = false;
  bool _refreshing = false;
  bool _reconnecting = false;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final session = services.auth.session.value;
    final companyId = session?.currentCompanyId;
    // Mirrors React `usePaidOrSelfhost`: QuickBooks is available on
    // self-hosted (any plan) or hosted + a paid (Pro/Enterprise, trial-
    // aware) plan. Gated hosted users see the upgrade banner instead.
    final allowed =
        session != null && (session.isSelfHosted || session.hasProAccess);
    return SettingsScreenScaffold(
      titleKey: 'quickbooks',
      body: companyId == null || companyId.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : !allowed
          ? const SingleChildScrollView(
              child: PlanGateBanner(style: PlanGateStyle.inset),
            )
          : StreamBuilder<Company?>(
              stream: services.company.watchCompany(companyId),
              builder: (context, snapshot) {
                final company = snapshot.data;
                if (company == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                final quickbooks = company.quickbooks;
                if (quickbooks == null || quickbooks.isEmpty) {
                  return _NotConnected(
                    busy: _connecting,
                    refreshing: _refreshing,
                    onConnect: _onConnect,
                    onRefresh: _onRefresh,
                  );
                }
                return _Connected(
                  company: company,
                  busy: _disconnecting,
                  reconnecting: _reconnecting,
                  onDisconnect: _onDisconnect,
                  onReconnect: _onReconnect,
                );
              },
            ),
    );
  }

  Future<void> _onConnect() async {
    final services = context.read<Services>();
    final messenger = ScaffoldMessenger.maybeOf(context);
    final errorMsg = context.tr('error_refresh_page');
    setState(() => _connecting = true);
    try {
      final uri = await services.quickbooks.buildAuthorizeUrl();
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (mounted) {
        Notify.error(
          context,
          context.tr('failed_to_open_url'),
          messenger: messenger,
        );
      }
    } catch (e) {
      if (!mounted) return;
      Notify.error(context, errorMsg, error: e, messenger: messenger);
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  /// Re-authorize an expired connection. Mirrors React
  /// `useQuickbooksReconnect`: fetch the reconnect URL, then launch it the
  /// same way as the initial connect (the hosted page redirects back).
  Future<void> _onReconnect() async {
    final services = context.read<Services>();
    final messenger = ScaffoldMessenger.maybeOf(context);
    final errorMsg = context.tr('error_refresh_page');
    setState(() => _reconnecting = true);
    try {
      final uri = await services.quickbooks.reconnectUrl();
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (mounted) {
        Notify.error(
          context,
          context.tr('failed_to_open_url'),
          messenger: messenger,
        );
      }
    } catch (e) {
      if (!mounted) return;
      Notify.error(context, errorMsg, error: e, messenger: messenger);
    } finally {
      if (mounted) setState(() => _reconnecting = false);
    }
  }

  /// Pulled in via `R1` from the post-implementation review: `launchUrl`
  /// returns immediately after handing off to the OS browser, so we have
  /// no signal for "user completed OAuth in the external page". The
  /// connect screen surfaces an explicit "Refresh status" button that
  /// pulls a fresh `/refresh` — when the server now reports
  /// `company.quickbooks`, the `StreamBuilder<Company?>` upstairs swaps
  /// the body to the Connected card.
  Future<void> _onRefresh() async {
    final services = context.read<Services>();
    final messenger = ScaffoldMessenger.maybeOf(context);
    final errorMsg = context.tr('error_refresh_page');
    setState(() => _refreshing = true);
    try {
      // "Refresh status" after an external OAuth round-trip — force a full
      // snapshot so the QuickBooks connection state is authoritative.
      await services.auth.refresh(fullSync: true);
    } catch (e) {
      if (!mounted) return;
      Notify.error(context, errorMsg, error: e, messenger: messenger);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _onDisconnect() async {
    final services = context.read<Services>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('disconnect')),
        content: Text(ctx.tr('are_you_sure')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.tr('cancel')),
          ),
          PrimaryDialogAction(
            label: ctx.tr('continue'),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final successMsg = context.tr('disconnected');
    final errorMsg = context.tr('error_refresh_page');
    setState(() => _disconnecting = true);
    try {
      await services.quickbooks.disconnect();
      if (!mounted) return;
      Notify.success(context, successMsg, messenger: messenger);
    } catch (e) {
      if (!mounted) return;
      Notify.error(context, errorMsg, error: e, messenger: messenger);
    } finally {
      if (mounted) setState(() => _disconnecting = false);
    }
  }
}

class _NotConnected extends StatelessWidget {
  const _NotConnected({
    required this.busy,
    required this.refreshing,
    required this.onConnect,
    required this.onRefresh,
  });

  final bool busy;
  final bool refreshing;
  final VoidCallback onConnect;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.account_balance_outlined,
      title: context.tr('quickbooks'),
      subtitle: context.tr('quickbooks_connect_description'),
      action: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(160, 44)),
            icon: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.open_in_new, size: 18),
            label: Text(context.tr('connect')),
            onPressed: busy || refreshing ? null : onConnect,
          ),
          const SizedBox(height: 8),
          // OAuth completes in an external browser; `launchUrl` has no
          // "return to app" signal we can listen for. Once the user lands
          // back here they can tap this to pull a fresh `/refresh` and
          // flip the UI to the connected card.
          TextButton.icon(
            icon: refreshing
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh, size: 18),
            label: Text(context.tr('refresh_data')),
            onPressed: busy || refreshing ? null : onRefresh,
          ),
        ],
      ),
    );
  }
}

/// QuickBooks-connected surface. Mirrors React `QuickBooksDetails` +
/// `QuickBooksImportTab` + `QuickBooksSyncTab`, kept as sections on the one
/// screen (the rebuild routes QB as a single leaf — see `settings_routes`).
class _Connected extends StatefulWidget {
  const _Connected({
    required this.company,
    required this.busy,
    required this.reconnecting,
    required this.onDisconnect,
    required this.onReconnect,
  });

  final Company company;
  final bool busy;
  final bool reconnecting;
  final VoidCallback onDisconnect;
  final VoidCallback onReconnect;

  @override
  State<_Connected> createState() => _ConnectedState();
}

/// React surfaces ten editable sync directions, grouped here so the screen
/// doesn't read as a flat wall of ten controls. Group keys are pending
/// localization keys; the entity keys reuse existing entity strings
/// (`sales` is the lone app-pending addition).
const _kQbSyncGroups = <String, List<String>>{
  'qb_group_contacts_catalog': ['client', 'vendor', 'product'],
  'qb_group_sales_documents': ['invoice', 'quote', 'sales', 'payment'],
  'qb_group_purchasing_expenses': [
    'purchase_order',
    'expense',
    'expense_category',
  ],
};
const _kQbSyncEntities = <String>[
  'client',
  'vendor',
  'product',
  'invoice',
  'quote',
  'sales',
  'payment',
  'purchase_order',
  'expense',
  'expense_category',
];
const _kQbDirections = <String>['none', 'push', 'pull', 'bidirectional'];

/// One entry from `quickbooks.settings.income_account_map`, plus the
/// synthetic "QuickBooks default" sentinel (empty id) so the picker is
/// clearable (mirrors React's `withBlank`).
class _QbAccount {
  const _QbAccount({required this.id, required this.name});
  final String id;
  final String name;
}

class _ConnectedState extends State<_Connected> {
  // Import toggles (one-shot).
  bool _impClients = false;
  bool _impProducts = false;
  bool _impInvoices = false;
  bool _importing = false;

  // Sync settings draft.
  final Map<String, String> _dir = {};
  String? _incomeAccountId;
  bool _automaticTaxes = false;
  final _taxable = TextEditingController();
  final _exempt = TextEditingController();
  bool _settingsDirty = false;
  bool _saving = false;

  // Which sync-entity rows are expanded (collapsed = one-line summary).
  final Set<String> _expandedSync = <String>{};
  // Read-only QB reference tables collapsed by default (can be long).
  bool _refExpanded = false;
  // Set after a successful import trigger so the card shows an honest
  // "running in the background" terminal state instead of a vanishing toast.
  bool _importStarted = false;

  Map<String, dynamic> get _qb =>
      (widget.company.quickbooks ?? const <String, dynamic>{});
  Map<String, dynamic> get _settings {
    final s = _qb['settings'];
    return s is Map ? Map<String, dynamic>.from(s) : <String, dynamic>{};
  }

  @override
  void initState() {
    super.initState();
    _seedFromCompany();
  }

  @override
  void didUpdateWidget(_Connected old) {
    super.didUpdateWidget(old);
    // Re-seed from a fresh server snapshot only when the user has no
    // unsaved edits, so a stream tick can't clobber in-progress changes.
    if (!_settingsDirty) _seedFromCompany();
  }

  void _seedFromCompany() {
    final s = _settings;
    _dir.clear();
    for (final e in _kQbSyncEntities) {
      final entry = s[e];
      final d = entry is Map ? entry['direction'] : null;
      _dir[e] = (d is String && _kQbDirections.contains(d)) ? d : 'none';
    }
    final acct = s['qb_income_account_id'];
    _incomeAccountId = (acct is String && acct.isNotEmpty) ? acct : null;
    _automaticTaxes = s['automatic_taxes'] == true;
    // Only reassign when the server value actually differs — a blind
    // `controller.text =` on every Drift tick resets the cursor/selection
    // to offset 0 mid-edit (before the user's first keystroke flips
    // `_settingsDirty`).
    _seedController(_taxable, (s['default_taxable_code'] as String?) ?? '');
    _seedController(_exempt, (s['default_exempt_code'] as String?) ?? '');
  }

  static void _seedController(TextEditingController c, String value) {
    if (c.text != value) c.text = value;
  }

  /// Parsed (defensive) read-only `income_account_map`. Empty until an
  /// import populates it server-side.
  List<_QbAccount> get _incomeAccounts {
    final raw = _settings['income_account_map'];
    if (raw is! List) return const [];
    return [
      for (final e in raw)
        if (e is Map)
          _QbAccount(
            id: (e['id'] ?? '').toString(),
            name: (e['fully_qualified_name'] ?? e['name'] ?? '').toString(),
          ),
    ];
  }

  /// Parsed (defensive) read-only `tax_rate_map`.
  List<({String name, String rate})> get _taxRates {
    final raw = _settings['tax_rate_map'];
    if (raw is! List) return const [];
    return [
      for (final e in raw)
        if (e is Map)
          (
            name: (e['name'] ?? '').toString(),
            rate: (e['rate'] ?? '').toString(),
          ),
    ];
  }

  @override
  void dispose() {
    _taxable.dispose();
    _exempt.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    final services = context.read<Services>();
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() => _importing = true);
    try {
      await services.quickbooks.triggerImport(
        client: _impClients,
        product: _impProducts,
        invoice: _impInvoices,
      );
      if (!mounted) return;
      Notify.success(context, context.tr('sync_started'), messenger: messenger);
      setState(() {
        _impClients = false;
        _impProducts = false;
        _impInvoices = false;
        _importStarted = true;
      });
    } catch (e) {
      if (!mounted) return;
      Notify.error(
        context,
        context.tr('error_refresh_page'),
        error: e,
        messenger: messenger,
      );
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _saveSettings() async {
    final services = context.read<Services>();
    final messenger = ScaffoldMessenger.maybeOf(context);
    // Deep-copy the whole `quickbooks` blob (JSON-safe) so OAuth tokens /
    // realm / server-populated maps are preserved; only mutate the
    // user-editable settings keys (React persists via the normal company
    // update — same path here, through the outbox + Drift).
    final merged = jsonDecode(jsonEncode(_qb)) as Map<String, dynamic>;
    final settings = (merged['settings'] is Map)
        ? Map<String, dynamic>.from(merged['settings'] as Map)
        : <String, dynamic>{};
    for (final e in _kQbSyncEntities) {
      final existing = settings[e];
      final m = existing is Map
          ? Map<String, dynamic>.from(existing)
          : <String, dynamic>{};
      m['direction'] = _dir[e] ?? 'none';
      settings[e] = m;
    }
    if (_incomeAccountId == null || _incomeAccountId!.isEmpty) {
      settings.remove('qb_income_account_id');
    } else {
      settings['qb_income_account_id'] = _incomeAccountId;
    }
    settings['automatic_taxes'] = _automaticTaxes;
    settings['default_taxable_code'] = _taxable.text.trim();
    settings['default_exempt_code'] = _exempt.text.trim();
    merged['settings'] = settings;

    setState(() => _saving = true);
    try {
      await services.company.updateCompany(
        draft: widget.company.copyWith(quickbooks: merged),
      );
      if (!mounted) return;
      Notify.success(context, context.tr('saved'), messenger: messenger);
      setState(() => _settingsDirty = false);
    } catch (e) {
      if (!mounted) return;
      Notify.error(
        context,
        context.tr('error_refresh_page'),
        error: e,
        messenger: messenger,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// One sync entity: a collapsed one-line summary (name + current
  /// direction) that expands to a 4-choice radio. Keeps ten entities
  /// scannable instead of a wall of forty radio targets.
  Widget _syncEntityTile(BuildContext context, String e) {
    final tokens = context.inTheme;
    final dir = _dir[e] ?? 'none';
    final expanded = _expandedSync.contains(e);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() {
            if (expanded) {
              _expandedSync.remove(e);
            } else {
              _expandedSync.add(e);
            }
          }),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: InSpacing.sm),
            child: Row(
              children: [
                Expanded(child: Text(context.tr(e))),
                Text(
                  context.tr(dir),
                  style: TextStyle(color: tokens.ink3, fontSize: 13),
                ),
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: tokens.ink3,
                ),
              ],
            ),
          ),
        ),
        if (expanded)
          Padding(
            padding: EdgeInsets.only(bottom: InSpacing.sm),
            child: RadioGroup<String>(
              groupValue: dir,
              onChanged: _saving
                  ? (_) {}
                  : (v) => setState(() {
                      _dir[e] = v ?? 'none';
                      _settingsDirty = true;
                    }),
              child: Column(
                children: [
                  for (final d in _kQbDirections)
                    RadioListTile<String>(
                      value: d,
                      title: Text(context.tr(d)),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final companyName = (_qb['companyName'] as String?) ?? '';
    final realmId = (_qb['realmID'] as String?) ?? '';
    final requiresReconnect = _qb['requires_reconnect'] == true;
    final anyImport = _impClients || _impProducts || _impInvoices;
    return SettingsFormShell(
      sections: [
        FormSection(
          title: context.tr('quickbooks'),
          spacing: 0,
          children: [
            if (requiresReconnect) ...[
              Padding(
                padding: EdgeInsets.only(bottom: InSpacing.md(context)),
                child: Text(
                  context.tr('quickbooks_requires_reauth'),
                  style: TextStyle(color: tokens.overdue),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(160, 44),
                  ),
                  icon: widget.reconnecting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.open_in_new, size: 18),
                  label: Text(context.tr('reconnect')),
                  onPressed: widget.reconnecting ? null : widget.onReconnect,
                ),
              ),
              SizedBox(height: InSpacing.md(context)),
            ],
            _InfoRow(label: context.tr('company_name'), value: companyName),
            Divider(color: tokens.border, height: 1),
            _InfoRow(label: context.tr('realm_id'), value: realmId),
          ],
        ),
        FormSection(
          title: context.tr('import'),
          children: _importStarted
              ? [
                  Container(
                    padding: EdgeInsets.all(InSpacing.md(context)),
                    decoration: BoxDecoration(
                      border: Border.all(color: tokens.border),
                      borderRadius: BorderRadius.circular(InRadii.r2),
                      color: tokens.surface,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.schedule, size: 18, color: tokens.ink3),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            context.tr('quickbooks_import_started'),
                            style: TextStyle(color: tokens.ink2, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: InSpacing.sm),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      icon: const Icon(Icons.refresh, size: 18),
                      label: Text(context.tr('import')),
                      onPressed: () => setState(() => _importStarted = false),
                    ),
                  ),
                ]
              : [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: _impClients,
                    onChanged: _importing
                        ? null
                        : (v) => setState(() => _impClients = v),
                    title: Text(context.tr('clients')),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: _impProducts,
                    onChanged: _importing
                        ? null
                        : (v) => setState(() => _impProducts = v),
                    title: Text(context.tr('products')),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: _impInvoices,
                    onChanged: _importing
                        ? null
                        : (v) => setState(() => _impInvoices = v),
                    title: Text(context.tr('invoices')),
                  ),
                  SizedBox(height: InSpacing.sm),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(160, 44),
                      ),
                      icon: _importing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download, size: 18),
                      label: Text(context.tr('import')),
                      onPressed: (_importing || !anyImport) ? null : _import,
                    ),
                  ),
                ],
        ),
        FormSection(
          title: context.tr('quickbooks_sync_settings'),
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: InSpacing.md(context)),
              child: Text(
                context.tr('quickbooks_sync_direction_help'),
                style: TextStyle(color: tokens.ink3, fontSize: 12),
              ),
            ),
            for (final group in _kQbSyncGroups.entries) ...[
              Padding(
                padding: EdgeInsets.only(top: InSpacing.sm, bottom: 4),
                child: Text(
                  context.tr(group.key).toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: tokens.ink3,
                  ),
                ),
              ),
              for (final e in group.value) _syncEntityTile(context, e),
            ],
            SizedBox(height: InSpacing.md(context)),
            if (_incomeAccounts.isEmpty)
              SearchableDropdownField<_QbAccount>(
                label: context.tr('income_account'),
                items: const [],
                initialValue: null,
                displayString: (a) => a.name,
                idOf: (a) => a.id,
                onChanged: (_) {},
                emptyHintKey: 'quickbooks_run_import_to_load_accounts',
              )
            else
              Builder(
                builder: (context) {
                  final items = <_QbAccount>[
                    _QbAccount(id: '', name: context.tr('default')),
                    ..._incomeAccounts,
                  ];
                  _QbAccount selected = items.first;
                  for (final a in items) {
                    if (a.id == (_incomeAccountId ?? '')) {
                      selected = a;
                      break;
                    }
                  }
                  return SearchableDropdownField<_QbAccount>(
                    label: context.tr('income_account'),
                    items: items,
                    initialValue: selected,
                    displayString: (a) => a.name,
                    idOf: (a) => a.id,
                    onChanged: _saving
                        ? (_) {}
                        : (a) => setState(() {
                            _incomeAccountId = (a == null || a.id.isEmpty)
                                ? null
                                : a.id;
                            _settingsDirty = true;
                          }),
                  );
                },
              ),
            SizedBox(height: InSpacing.md(context)),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: _automaticTaxes,
              onChanged: _saving
                  ? null
                  : (v) => setState(() {
                      _automaticTaxes = v;
                      _settingsDirty = true;
                    }),
              title: Text(context.tr('automatic_taxes')),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _taxable,
              onChanged: (_) => setState(() => _settingsDirty = true),
              decoration: InputDecoration(
                labelText: context.tr('default_taxable_code'),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _exempt,
              onChanged: (_) => setState(() => _settingsDirty = true),
              decoration: InputDecoration(
                labelText: context.tr('default_exempt_code'),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            SizedBox(height: InSpacing.md(context)),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(160, 44)),
                onPressed: (_saving || !_settingsDirty) ? null : _saveSettings,
                child: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(context.tr('save')),
              ),
            ),
          ],
        ),
        if (_incomeAccounts.isNotEmpty || _taxRates.isNotEmpty)
          FormSection(
            title: context.tr('quickbooks_read_only_data'),
            spacing: 0,
            children: [
              InkWell(
                onTap: () => setState(() => _refExpanded = !_refExpanded),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: InSpacing.sm),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${context.tr('income_account')} '
                          '(${_incomeAccounts.length})  ·  '
                          '${context.tr('tax_rates')} '
                          '(${_taxRates.length})',
                          style: TextStyle(color: tokens.ink3, fontSize: 13),
                        ),
                      ),
                      Icon(
                        _refExpanded ? Icons.expand_less : Icons.expand_more,
                        size: 18,
                        color: tokens.ink3,
                      ),
                    ],
                  ),
                ),
              ),
              if (_refExpanded) ...[
                if (_incomeAccounts.isNotEmpty) ...[
                  Divider(color: tokens.border, height: 1),
                  for (final a in _incomeAccounts)
                    _InfoRow(
                      label: a.name.isEmpty ? a.id : a.name,
                      value: a.id,
                    ),
                ],
                if (_taxRates.isNotEmpty) ...[
                  Divider(color: tokens.border, height: 1),
                  for (final r in _taxRates)
                    _InfoRow(
                      label: r.name.isEmpty ? '—' : r.name,
                      value: '${r.rate}%',
                    ),
                ],
              ],
            ],
          ),
        FormSection(
          title: context.tr('disconnect'),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                icon: Icon(Icons.link_off, color: tokens.overdue),
                label: Text(
                  context.tr('disconnect'),
                  style: TextStyle(color: tokens.overdue),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(160, 44),
                  side: BorderSide(color: tokens.overdue),
                ),
                onPressed: widget.busy ? null : widget.onDisconnect,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.inTheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: theme.textTheme.bodyMedium),
      subtitle: Text(
        value.isEmpty ? '—' : value,
        style: theme.textTheme.bodyMedium?.copyWith(color: tokens.ink),
      ),
    );
  }
}
