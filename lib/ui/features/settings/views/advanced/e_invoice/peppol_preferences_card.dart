import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/api/tax_config_api_model.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/core/widgets/status_pill.dart';
import 'package:admin/ui/features/settings/view_models/settings_draft_view_model.dart';
import 'package:admin/ui/features/settings/views/advanced/e_invoice/peppol_buy_credits_links.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/settings/widgets/overridable_switch_field.dart';
import 'package:admin/ui/features/settings/widgets/overridable_text_field.dart';

/// Settings → E-Invoice — PEPPOL Preferences card. Rendered when the
/// active company has a non-zero `legalEntityId` (i.e. setup has
/// completed and the tenant is bound to the PEPPOL network).
///
/// Toggles for `acts_as_sender` / `acts_as_receiver` auto-fire a
/// debounced `peppolUpdate` outbox row — matches admin-portal and React
/// auto-submission semantics. Disconnect is a confirm-then-fire flow.
/// Credits quota and token health-check are live GETs issued on mount;
/// network failures are swallowed.
class PeppolPreferencesCard extends StatefulWidget {
  const PeppolPreferencesCard({super.key});

  @override
  State<PeppolPreferencesCard> createState() => _PeppolPreferencesCardState();
}

class _PeppolPreferencesCardState extends State<PeppolPreferencesCard> {
  Timer? _debounce;
  int? _quota;
  bool _quotaLoading = true;
  bool? _healthy;

  @override
  void initState() {
    super.initState();
    // Defer the inherited-widget lookups (Services / repo) until after
    // the first frame — `context.read` works in `initState` today but
    // the canonical pattern is to wait for the element tree to settle.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadQuotaAndHealth();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadQuotaAndHealth() async {
    final repo = context.read<Services>().company;
    // Both endpoints are best-effort — the repo wrappers already swallow
    // network errors and return null, so the futures here never reject.
    unawaited(
      repo.fetchEInvoiceQuota().then((value) {
        if (!mounted) return;
        setState(() {
          _quotaLoading = false;
          _quota = value;
        });
      }),
    );
    unawaited(
      repo.fetchEInvoiceHealthCheck().then((value) {
        if (!mounted) return;
        setState(() => _healthy = value);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final host = context.watch<SettingsDraftHost>();
    final company = host.draft;
    if (company == null) return const SizedBox.shrink();
    final taxData = company.taxData ?? const TaxConfigApi();
    final tokens = context.inTheme;

    return FormSection(
      title: 'PEPPOL',
      children: [
        // Wrap (not Row) so the status pill + legal-entity id + action
        // buttons reflow to multiple lines on narrow widths instead of
        // overflowing. `runSpacing` separates rows when wrapping.
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: InSpacing.md(context),
          runSpacing: InSpacing.sm,
          children: [
            StatusPill(
              label: context.tr('connected'),
              fgColor: tokens.paid,
              bgColor: tokens.paidSoft,
            ),
            Text(
              '#${company.legalEntityId}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (_healthy == false)
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(64, 40),
                ),
                onPressed: _onRegenerateToken,
                child: Text(context.tr('regenerate_token')),
              ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(64, 40),
                foregroundColor: tokens.overdue,
              ),
              onPressed: () => _confirmDisconnect(context),
              child: Text(context.tr('disconnect')),
            ),
          ],
        ),
        SwitchListTile(
          title: Text(context.tr('act_as_sender')),
          contentPadding: EdgeInsets.zero,
          value: taxData.actsAsSender,
          onChanged: (v) => _updateTaxData(
            host,
            (t) => t.copyWith(actsAsSender: v),
            debounce: true,
          ),
        ),
        SwitchListTile(
          title: Text(context.tr('act_as_receiver')),
          contentPadding: EdgeInsets.zero,
          value: taxData.actsAsReceiver,
          onChanged: (v) => _updateTaxData(
            host,
            (t) => t.copyWith(actsAsReceiver: v),
            debounce: true,
          ),
        ),
        // Inbound-forwarding addresses + the skip-automatic-email toggle.
        // These are PEPPOL-specific settings; React surfaces them on the
        // Preferences card once a legal entity is bound (not in the
        // non-PEPPOL enable block). Cascade fields — they ride the page
        // Save button via their `apiKey`, unlike the auto-firing toggles above.
        OverridableTextField(
          label: context.tr('e_invoice_forward_email'),
          apiKey: 'e_invoice_forward_email',
          helperText: context.tr('e_invoice_forward_email_help'),
          keyboardType: TextInputType.emailAddress,
        ),
        OverridableTextField(
          label: context.tr('e_expense_forward_email'),
          apiKey: 'e_expense_forward_email',
          helperText: context.tr('e_expense_forward_email_help'),
          keyboardType: TextInputType.emailAddress,
        ),
        OverridableSwitchField(
          label: context.tr('skip_automatic_email_with_peppol'),
          apiKey: 'skip_automatic_email_with_peppol',
          subtitle: context.tr('skip_automatic_email_with_peppol_help'),
        ),
        if (!_quotaLoading)
          Row(
            children: [
              Text(
                context.tr('credits'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              SizedBox(width: InSpacing.md(context)),
              Text(
                _quota?.toString() ?? '—',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        // Top up PEPPOL credits — hosted-only, self-gates to nothing otherwise.
        const PeppolBuyCreditsLinks(),
      ],
    );
  }

  void _updateTaxData(
    SettingsDraftHost host,
    TaxConfigApi Function(TaxConfigApi) edit, {
    required bool debounce,
  }) {
    final base = host.draft?.taxData ?? const TaxConfigApi();
    final next = edit(base);
    host.updateCompany((c) => c.copyWith(taxData: next));

    if (!debounce) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _fireUpdate(next);
    });
  }

  Future<void> _fireUpdate(TaxConfigApi taxData) async {
    final services = context.read<Services>();
    final host = context.read<SettingsDraftHost>();
    final companyId = host.draft?.id;
    if (companyId == null) return;
    try {
      await services.company.enqueuePeppolUpdate(
        companyId: companyId,
        payload: {
          'acts_as_sender': taxData.actsAsSender,
          'acts_as_receiver': taxData.actsAsReceiver,
        },
      );
    } catch (e) {
      if (!mounted) return;
      Notify.error(context, context.tr('could_not_save'), error: e);
    }
  }

  Future<void> _onRegenerateToken() async {
    final services = context.read<Services>();
    final host = context.read<SettingsDraftHost>();
    final companyId = host.draft?.id;
    if (companyId == null) return;
    try {
      await services.company.enqueueRegenerateEInvoiceToken(
        companyId: companyId,
      );
      if (!mounted) return;
      Notify.success(context, context.tr('token_regenerated'));
    } catch (e) {
      if (!mounted) return;
      Notify.error(context, context.tr('token_regeneration_failed'), error: e);
    }
  }

  Future<void> _confirmDisconnect(BuildContext context) async {
    final host = context.read<SettingsDraftHost>();
    final services = context.read<Services>();
    final company = host.draft;
    if (company == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('peppol_disconnect')),
        content: Text(context.tr('peppol_disconnect_long')),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.tr('cancel')),
          ),
          PrimaryDialogAction(
            variant: DialogActionVariant.destructive,
            label: context.tr('disconnect'),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!context.mounted) return;

    try {
      // Match React's `account?.e_invoicing_token` semantics — when the
      // session has no token (account never onboarded PEPPOL) omit the
      // field entirely so the server's nullable check behaves the same
      // way as it does for the JS client.
      final eInvoicingToken =
          services.auth.session.value?.eInvoicingToken ?? '';
      await services.company.enqueuePeppolDisconnect(
        companyId: company.id,
        payload: {
          'company_key': company.companyKey,
          'legal_entity_id': company.legalEntityId,
          'tax_data': company.taxData?.toJson() ?? const <String, dynamic>{},
          if (eInvoicingToken.isNotEmpty) 'e_invoicing_token': eInvoicingToken,
        },
      );
      if (!context.mounted) return;
      Notify.success(context, context.tr('disconnected'));
    } catch (e) {
      if (!context.mounted) return;
      Notify.error(context, context.tr('could_not_save'), error: e);
    }
  }
}
