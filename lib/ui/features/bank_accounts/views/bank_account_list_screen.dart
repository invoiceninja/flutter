import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/router.dart' show selectedIdFromRoute;
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/bank_account.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/master_detail_layout.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/unsynced_pill.dart';
import 'package:admin/ui/features/settings/widgets/plan_gate_banner.dart';
import 'package:admin/ui/features/settings/widgets/settings_entity_list_scaffold.dart';
import 'package:admin/utils/formatting.dart';

/// Search keys for the in-app settings sidebar search.
const kBankAccountsListSearchKeys = <String>[
  'bank_accounts',
  'bank_account',
  'new_bank_account',
  'auto_sync',
  'sync_from',
  'transaction_rules',
  'connect_accounts',
  'reconnect',
];

/// `/settings/bank_accounts` — list every bank integration. Tap a row to
/// open it; tap "+ New bank account" to create a manual account. The app-bar
/// actions (Connect Accounts / Refresh / Rules) live in [_BankAccountsActions],
/// a single overflow menu, each item plan/host-gated to mirror React.
class BankAccountListScreen extends StatelessWidget {
  const BankAccountListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    final repo = services.bankAccounts;

    // The Formatter is built async (statics + company settings). Resolve
    // once at the screen level and pass down — rows render unformatted
    // balances while the future is pending, then re-render with the
    // proper currency/locale once it resolves.
    return FutureBuilder<Formatter>(
      future: services.formatterFor(companyId),
      builder: (context, snapshot) {
        final formatter = snapshot.data;
        return SettingsEntityListScaffold<BankAccount>(
          titleKey: 'bank_accounts',
          sectionTitleKey: 'bank_accounts',
          newRoute: '/settings/bank_accounts/new',
          newLabelKey: 'new_bank_account',
          emptyIcon: Icons.account_balance_outlined,
          emptyTitleKey: 'no_bank_accounts',
          emptyHintKey: 'no_bank_accounts_hint',
          supportsArchive: true,
          // Bank-feed connect (Yodlee/Nordigen) is enterprise-only (React
          // `BankAccountsPlanAlert`). The banner auto-hides for enterprise
          // accounts; manual bank accounts stay available on any plan.
          banner: const PlanGateBanner(
            style: PlanGateStyle.stripe,
            level: PlanGateLevel.enterprise,
          ),
          extraAppBarActions: const [_BankAccountsActions()],
          refreshAll: () async {
            if (companyId.isEmpty) return;
            await repo.refreshAll(companyId: companyId);
          },
          stream: ({required includeArchived}) => includeArchived
              ? repo.watchAllIncludingArchived(companyId: companyId)
              : repo.watchAll(companyId: companyId),
          isArchivedOf: (a) => a.archivedAt != null,
          isDeletedOf: (a) => a.isDeleted,
          rowBuilder: (a) => _BankAccountRow(
            key: ValueKey(a.id),
            account: a,
            formatter: formatter,
          ),
          archivedRowBuilder: (a) => _BankAccountRow.archived(
            key: ValueKey(a.id),
            account: a,
            formatter: formatter,
          ),
        );
      },
    );
  }
}

class _BankAccountRow extends StatelessWidget {
  const _BankAccountRow({
    required this.account,
    required this.formatter,
    super.key,
  }) : _isArchived = false;

  const _BankAccountRow.archived({
    required this.account,
    required this.formatter,
    super.key,
  }) : _isArchived = true;

  final BankAccount account;
  final Formatter? formatter;
  final bool _isArchived;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final displayName = account.name.trim().isEmpty
        ? context.tr('untitled')
        : account.name;
    final balanceLabel = _formatBalance(formatter, account);
    final isUrlSelected = selectedIdFromRoute(context) == account.id;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: Icon(
            account.needsReconnect
                ? Icons.link_off
                : Icons.account_balance_outlined,
            color: account.needsReconnect ? tokens.overdue : tokens.ink2,
          ),
          title: Text(displayName),
          subtitle: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (account.type.isNotEmpty)
                Text(
                  account.type,
                  style: TextStyle(color: tokens.ink2, fontSize: 12),
                ),
              if (account.provider.isNotEmpty ||
                  account.integrationType.isNotEmpty)
                Text(
                  '· ${_providerLabel(context, account)}',
                  style: TextStyle(color: tokens.ink2, fontSize: 12),
                ),
              if (account.needsReconnect)
                _ChipPill(
                  text: context.tr('reconnect'),
                  background: tokens.overdueSoft,
                  foreground: tokens.overdue,
                ),
            ],
          ),
          trailing: _isArchived
              ? _ChipPill(
                  text: context.tr('archived'),
                  background: tokens.draftSoft,
                  foreground: tokens.draft,
                )
              : account.isDirty
              ? const UnsyncedPill()
              : Text(
                  balanceLabel,
                  style: TextStyle(
                    color: tokens.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
          onTap: isUrlSelected
              ? () => MasterDetailNavScope.requestClose(
                  context,
                  basePath: '/settings/bank_accounts',
                )
              : () => context.go('/settings/bank_accounts/${account.id}'),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

/// Format the balance through the company's Formatter when one is
/// available. Bank accounts store currency as an ISO code (`USD`) but
/// `Formatter.money` keys on the numeric currency id — resolve via
/// `formatter.currencies` (small map, cheap scan). When the formatter
/// isn't ready yet, fall back to a plain `<CODE> <amount>` rendering so
/// the row still displays sensibly during the brief load.
String _formatBalance(Formatter? formatter, BankAccount account) {
  if (formatter != null) {
    String? resolvedId;
    if (account.currency.isNotEmpty) {
      final upper = account.currency.toUpperCase();
      for (final entry in formatter.currencies.entries) {
        if (entry.value.code.toUpperCase() == upper) {
          resolvedId = entry.key;
          break;
        }
      }
    }
    final formatted = formatter.money(account.balance, currencyId: resolvedId);
    if (formatted.isNotEmpty) return formatted;
  }
  final prefix = account.currency.isEmpty ? '' : '${account.currency} ';
  return '$prefix${account.balance}';
}

/// Build the aggregator's hosted connect URL from a `one_time_token` hash.
/// Mirrors admin-portal: `cleanApiUrl(credentials.url)` (strip `/api/v1` +
/// trailing slash) is the base for **both** Yodlee and Nordigen, so
/// regional / staging / self-hosted servers connect to their own host
/// instead of a hardcoded `invoicing.co` (which broke non-prod hosts).
/// For hosted production the cleaned base already *is* `invoicing.co`, so
/// behaviour there is unchanged. Pure + unit-tested.
String connectBankUrl(String context, String hash, String baseUrl) {
  final base = baseUrl
      .trim()
      .replaceFirst(RegExp(r'/api/v1'), '')
      .replaceFirst(RegExp(r'/+$'), '');
  if (context == 'yodlee') {
    return '$base/yodlee/onboard/$hash';
  }
  return '$base/nordigen/connect/$hash';
}

/// App-bar actions for the bank-accounts list: **Connect Accounts** (Yodlee /
/// Nordigen hosted OAuth), **Refresh** (upstream `refresh_accounts`), and
/// **Rules** (Transaction Rules). Gating mirrors React's BankAccounts index:
/// Refresh = hosted + enterprise; Rules = pro/enterprise/self-hosted
/// (≈ `hasProAccess`); Connect is always present but enterprise-gated (and
/// self-hosted always has enterprise access).
///
/// Rendered as a single overflow (`⋮`) menu. The list sits in a
/// sidebar-narrowed settings pane whose width an AppBar action can't measure
/// (no `LayoutBuilder` constraints; `MediaQuery` reports the whole window), so
/// a width-driven inline layout would crowd the title at medium widths — one
/// icon sidesteps that entirely.
class _BankAccountsActions extends StatelessWidget {
  const _BankAccountsActions();

  /// Mint a one-time token and open the aggregator's hosted connect page.
  /// The aggregator + server own the OAuth/credential exchange; the app just
  /// opens the URL, then Refresh / pull-to-refresh pulls the linked accounts.
  Future<void> _connect(BuildContext context, String ctx) async {
    final services = context.read<Services>();
    final baseUrl = services.auth.session.value?.baseUrl ?? '';
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final hash = await services.bankAccounts.api.oneTimeToken(context: ctx);
      final url = connectBankUrl(ctx, hash, baseUrl);
      final ok = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!context.mounted) return;
      if (ok) {
        Notify.success(
          context,
          context.tr('complete_in_browser'),
          messenger: messenger,
        );
      } else {
        Notify.error(
          context,
          context.tr('an_error_occurred'),
          messenger: messenger,
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      Notify.error(
        context,
        context.tr('an_error_occurred'),
        error: e,
        messenger: messenger,
      );
    }
  }

  /// Self-hosted connects via Nordigen directly (React parity — no provider
  /// modal); hosted enterprise picks a provider first.
  Future<void> _onConnect(BuildContext context) async {
    final s = context.read<Services>().auth.session.value;
    if (s?.isSelfHosted ?? false) {
      await _connect(context, 'nordigen');
      return;
    }
    final ctx = await showDialog<String>(
      context: context,
      builder: (d) => SimpleDialog(
        title: Text(d.tr('connect_accounts')),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(d).pop('yodlee'),
            // i18n-exempt: brand name
            child: const Text('Yodlee'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(d).pop('nordigen'),
            // i18n-exempt: brand name
            child: const Text('Nordigen (GoCardless)'),
          ),
        ],
      ),
    );
    if (ctx == null || !context.mounted) return;
    await _connect(context, ctx);
  }

  /// Ask the server to poll the upstream provider for fresh balances /
  /// transactions. Routed through the outbox (queued + retried), so we toast a
  /// transient "Processing" rather than awaiting React's synchronous message.
  Future<void> _onRefresh(BuildContext context) async {
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    if (companyId.isEmpty) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    await services.bankAccounts.refreshAccounts(companyId: companyId);
    if (!context.mounted) return;
    Notify.info(context, context.tr('processing'), messenger: messenger);
  }

  void _onRules(BuildContext context) =>
      context.go('/settings/bank_accounts/transaction_rules');

  @override
  Widget build(BuildContext context) {
    final session = context.read<Services>().auth.session.value;
    final enterprise = session?.hasEnterpriseAccess ?? false;
    final isHosted = session?.isHosted ?? false;
    final pro = session?.hasProAccess ?? false;

    final showRefresh = isHosted && enterprise;
    final showRules = pro;

    // A single overflow menu holds every available action. The settings list
    // renders inside a sidebar-narrowed pane (not full window width), and an
    // AppBar action gets no usable LayoutBuilder width — so there's no reliable
    // signal for an inline layout. One `⋮` icon never overflows at any pane
    // width, and is more compact than the old inline "Connect" button.
    // Handlers run on the outer `context` (stable, mounted in the AppBar), not
    // the transient `menuContext`, so showDialog / messenger / go stay valid
    // after the menu pops.
    return PopupMenuButton<void>(
      icon: const Icon(Icons.more_vert),
      itemBuilder: (menuContext) => [
        PopupMenuItem<void>(
          enabled: enterprise,
          onTap: () => _onConnect(context),
          child: _ActionMenuRow(
            icon: Icons.add_link,
            label: context.tr('connect_accounts'),
          ),
        ),
        if (showRefresh)
          PopupMenuItem<void>(
            onTap: () => _onRefresh(context),
            child: _ActionMenuRow(
              icon: Icons.refresh,
              label: context.tr('refresh'),
            ),
          ),
        if (showRules)
          PopupMenuItem<void>(
            onTap: () => _onRules(context),
            child: _ActionMenuRow(
              icon: Icons.rule_outlined,
              label: context.tr('rules'),
            ),
          ),
      ],
    );
  }
}

/// Icon + label row for a [_BankAccountsActions] overflow-menu item.
class _ActionMenuRow extends StatelessWidget {
  const _ActionMenuRow({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(icon, size: 20), const SizedBox(width: 12), Text(label)],
    );
  }
}

/// Prefer the server-provided friendly provider name when present;
/// otherwise translate the wire `integration_type` (YODLEE / NORDIGEN /
/// manual) so the row never displays the raw uppercase enum.
String _providerLabel(BuildContext context, BankAccount account) {
  if (account.provider.isNotEmpty) {
    // Server sometimes returns the wire enum (`YODLEE`) and sometimes a
    // friendlier label — translate when it matches a known wire value,
    // otherwise pass through.
    final key = labelKeyForProvider(account.provider);
    if (key.startsWith('provider_name_') || key == 'manual') {
      return context.tr(key);
    }
    return account.provider;
  }
  return context.tr(labelKeyForProvider(account.integrationType));
}

class _ChipPill extends StatelessWidget {
  const _ChipPill({
    required this.text,
    required this.background,
    required this.foreground,
  });

  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(InRadii.r1),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),
    );
  }
}
