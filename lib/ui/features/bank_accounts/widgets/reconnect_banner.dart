import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/bank_account.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/features/bank_accounts/widgets/bank_connect.dart';

/// The connect-flow context + (Nordigen-only) institution id derived from
/// a stale account's integration type.
typedef ReconnectArgs = ({String ctx, String? institutionId});

/// Map a [BankAccount]'s integration type to the hosted-connect context
/// and, for Nordigen only, its known institution id (so the user isn't
/// re-prompted to pick a bank — mirrors React `handleConnectNordigen`).
///
/// Uses the canonical `kBankIntegration*` constants and **throws**
/// [ArgumentError] for an unrecognized type, so the caller surfaces an
/// error rather than letting `connectBankUrl`'s else-branch silently route
/// an unknown provider to Nordigen. Pure + top-level so the derivation is
/// unit-testable without widget scaffolding (the `buildPeppolSetupPayload`
/// pattern).
ReconnectArgs bankReconnectArgs(BankAccount a) {
  switch (a.integrationType) {
    case kBankIntegrationYodlee:
      return (ctx: 'yodlee', institutionId: null);
    case kBankIntegrationNordigen:
      return (ctx: 'nordigen', institutionId: a.nordigenInstitutionId);
    default:
      throw ArgumentError('Unsupported bank integration: ${a.integrationType}');
  }
}

/// Inline warning rendered when the bank integration's upstream provider
/// has dropped the connection (`disabledUpstream == true` + an
/// integration type set). Reconnect re-triggers the existing hosted
/// connect flow (`one_time_token` → aggregator URL → external browser) —
/// there is no separate reconnect endpoint; React does the same. For
/// Nordigen the stale link's institution id is passed so the user isn't
/// re-prompted to pick a bank.
///
/// The aggregator + server own the OAuth/credential exchange; the app just
/// opens the URL, then the existing pull-to-refresh / `refresh_accounts`
/// pulls the relinked account. Mirrors the Peppol-CorpPass precedent: a
/// one-shot external-auth redirect, launched directly (not an outbox
/// mutation — you can't relink a bank offline).
///
/// Shared by `BankAccountEditScreen` and `BankAccountDetailScreen`.
class ReconnectBanner extends StatefulWidget {
  const ReconnectBanner({super.key, required this.account});

  final BankAccount account;

  @override
  State<ReconnectBanner> createState() => _ReconnectBannerState();
}

class _ReconnectBannerState extends State<ReconnectBanner> {
  bool _busy = false;

  Future<void> _reconnect() async {
    if (_busy) return;
    final account = widget.account;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final ReconnectArgs args;
    try {
      args = bankReconnectArgs(account);
    } catch (_) {
      Notify.error(
        context,
        context.tr('an_error_occurred'),
        messenger: messenger,
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await startBankConnect(
        context,
        provider: args.ctx,
        institutionId: args.institutionId,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.account.needsReconnect) return const SizedBox.shrink();
    final tokens = context.inTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.overdueSoft,
        borderRadius: BorderRadius.circular(InRadii.r2),
        border: Border.all(color: tokens.overdue.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.link_off, color: tokens.overdue, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.tr('reconnect_bank_account_help'),
              style: TextStyle(color: tokens.ink, fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _reconnect,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh, size: 16),
            label: Text(context.tr('reconnect')),
            style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
          ),
        ],
      ),
    );
  }
}
