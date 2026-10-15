import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/version.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/domain/clients/vat_check.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/clients/view_models/client_edit_view_model.dart';
import 'package:admin/ui/features/settings/views/advanced/e_invoice/e_invoice_constants.dart';

/// "Check VAT" and "Check PEPPOL delivery" under the client's tax flags
/// (React #3415). Both ask the server about the client as it is *saved*, so
/// each is disabled — with a line saying why — while the fields it reads have
/// unsaved changes, or the client has never reached the server.
///
/// - **Check VAT** — an EU client only (`kVatCheckCountryIds`). Queues a VIES
///   lookup and polls for the verdict (`ClientRepository.checkVat`, which
///   re-fetches the row once the server has written it); a definite answer
///   also flips the form's "Valid VAT number" switch, so a save keeps it.
/// - **Check PEPPOL delivery** — hosted, with the company on PEPPOL and bound
///   to a legal entity: whether an e-invoice could reach this client.
///
/// Both need a 5.13.45 server (`ServerFeatures.clientVerificationChecks`), and
/// both are direct requests rather than outbox rows: the user waits for the
/// answer, so there is nothing to queue.
class ClientVerificationChecks extends StatefulWidget {
  const ClientVerificationChecks({super.key, required this.vm});

  final ClientEditViewModel vm;

  @override
  State<ClientVerificationChecks> createState() =>
      _ClientVerificationChecksState();
}

class _ClientVerificationChecksState extends State<ClientVerificationChecks> {
  // Subscribed once: the form rebuilds this on every keystroke, and a fresh
  // stream each time would hand the builder a null company for a frame —
  // unmounting the PEPPOL row and dropping its answer.
  late final Stream<Company?> _company = context
      .read<Services>()
      .company
      .watchCompany(widget.vm.companyId);

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final services = context.read<Services>();
    final isHosted = services.auth.session.value?.isHosted ?? false;
    if (!ServerFeatures.supports(
      services.serverVersion.value,
      ServerFeatures.clientVerificationChecks,
      isHosted: isHosted,
    )) {
      return const SizedBox.shrink();
    }
    return StreamBuilder<Company?>(
      stream: _company,
      builder: (context, snap) {
        final company = snap.data;
        final draft = vm.draft;
        final original = vm.original;
        // Saved here but still in the outbox: the server holds the old
        // values, so a check would answer for those.
        final unsynced =
            draft.id.startsWith('tmp_') || (original?.isDirty ?? false);
        final vat = kVatCheckCountryIds.contains(draft.countryId);
        final peppol =
            isHosted &&
            company != null &&
            company.legalEntityId > 0 &&
            company.settings.eInvoiceType == kEInvoiceTypePEPPOL;
        if (!vat && !peppol) return const SizedBox.shrink();
        bool changed(String Function(Client c) field) =>
            original == null || field(draft) != field(original);
        String? blocked(bool unsaved, String saveFirstKey) => unsynced
            ? context.tr('sync_first_generic')
            : unsaved
            ? context.tr(saveFirstKey)
            : null;
        return Padding(
          padding: EdgeInsets.only(top: InSpacing.md(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (vat)
                _VatCheck(
                  vm: vm,
                  // What the server's lookup reads (`TaxService::validateVat`).
                  blockedMessage: blocked(
                    changed((c) => c.vatNumber) ||
                        changed((c) => c.countryId) ||
                        changed((c) => c.shippingCountryId),
                    'save_client_before_vat_check',
                  ),
                ),
              if (vat && peppol) SizedBox(height: InSpacing.sm),
              if (peppol)
                _PeppolCheck(
                  vm: vm,
                  // What the routing lookup reads (React's reset list).
                  blockedMessage: blocked(
                    changed((c) => c.vatNumber) ||
                        changed((c) => c.idNumber) ||
                        changed((c) => c.routingId) ||
                        changed((c) => c.countryId) ||
                        changed((c) => c.classification),
                    'save_client_before_discovery',
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _VatCheck extends StatefulWidget {
  const _VatCheck({required this.vm, required this.blockedMessage});

  final ClientEditViewModel vm;

  /// Why the check can't run yet (unsaved or unsynced changes), or null.
  final String? blockedMessage;

  @override
  State<_VatCheck> createState() => _VatCheckState();
}

class _VatCheckState extends State<_VatCheck> {
  bool _busy = false;
  VatCheckResult? _result;

  /// Bumped when the answer in flight no longer applies — the fields changed
  /// or the widget went away — so a late verdict is dropped.
  int _run = 0;

  @override
  void didUpdateWidget(covariant _VatCheck old) {
    super.didUpdateWidget(old);
    if (widget.blockedMessage != null && old.blockedMessage == null) _reset();
  }

  @override
  void dispose() {
    _run++;
    super.dispose();
  }

  void _reset() {
    _run++;
    _busy = false;
    _result = null;
  }

  Future<void> _check() async {
    final run = ++_run;
    final vm = widget.vm;
    final clients = context.read<Services>().clients;
    setState(() {
      _busy = true;
      _result = null;
    });
    final result = await clients.checkVat(
      companyId: vm.companyId,
      id: vm.draft.id,
      cancelled: () => run != _run,
    );
    if (!mounted || run != _run || result == null) return;
    setState(() {
      _busy = false;
      _result = result;
    });
    if (result == VatCheckResult.valid || result == VatCheckResult.invalid) {
      widget.vm.setHasValidVatNumber(result == VatCheckResult.valid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final (String? message, Color? color) = widget.blockedMessage != null
        ? (widget.blockedMessage, null)
        : _busy
        ? (context.tr('vat_validation_pending'), null)
        : switch (_result) {
            null => (null, null),
            VatCheckResult.valid => (
              context.tr('vat_validation_valid'),
              tokens.paid,
            ),
            VatCheckResult.invalid => (
              context.tr('vat_validation_invalid'),
              tokens.overdue,
            ),
            VatCheckResult.unavailable => (
              context.tr('vat_validation_unavailable'),
              tokens.warning,
            ),
            VatCheckResult.timeout => (
              context.tr('vat_validation_timeout'),
              tokens.warning,
            ),
            VatCheckResult.error => (
              context.tr('vat_validation_failed'),
              tokens.overdue,
            ),
          };
    return _CheckRow(
      label: context.tr('check_vat'),
      onPressed: widget.blockedMessage != null || _busy ? null : _check,
      busy: _busy,
      message: message,
      color: color,
    );
  }
}

class _PeppolCheck extends StatefulWidget {
  const _PeppolCheck({required this.vm, required this.blockedMessage});

  final ClientEditViewModel vm;

  /// Why the check can't run yet (unsaved or unsynced changes), or null.
  final String? blockedMessage;

  @override
  State<_PeppolCheck> createState() => _PeppolCheckState();
}

class _PeppolCheckState extends State<_PeppolCheck> {
  bool _busy = false;

  /// True = found, false = not on the network, null = not asked / failed
  /// (see [_failed]).
  bool? _found;
  bool _failed = false;
  int _run = 0;

  @override
  void didUpdateWidget(covariant _PeppolCheck old) {
    super.didUpdateWidget(old);
    if (widget.blockedMessage != null && old.blockedMessage == null) {
      _run++;
      _busy = false;
      _found = null;
      _failed = false;
    }
  }

  @override
  void dispose() {
    _run++;
    super.dispose();
  }

  Future<void> _check() async {
    final run = ++_run;
    final clients = context.read<Services>().clients;
    setState(() {
      _busy = true;
      _found = null;
      _failed = false;
    });
    bool? found;
    try {
      found = await clients.peppolDiscovery(widget.vm.draft.id);
    } catch (_) {
      found = null;
    }
    if (!mounted || run != _run) return;
    setState(() {
      _busy = false;
      _found = found;
      _failed = found == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final (String? message, Color? color) = widget.blockedMessage != null
        ? (widget.blockedMessage, null)
        : _failed
        ? (context.tr('peppol_discovery_failed'), tokens.overdue)
        : switch (_found) {
            null => (null, null),
            true => (
              context.tr('client_discoverable_on_peppol_network'),
              tokens.paid,
            ),
            false => (
              context.tr('client_not_found_on_peppol_network'),
              tokens.warning,
            ),
          };
    return _CheckRow(
      label: context.tr('check_peppol_delivery'),
      onPressed: widget.blockedMessage != null || _busy ? null : _check,
      busy: _busy,
      message: message,
      color: color,
    );
  }
}

/// A check's button with its outcome beside it — wrapping under it when the
/// card is narrow.
class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.label,
    required this.onPressed,
    required this.busy,
    required this.message,
    required this.color,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final String? message;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: InSpacing.md(context),
      runSpacing: InSpacing.xs,
      children: [
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
          onPressed: onPressed,
          icon: busy
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.verified_outlined, size: 18),
          label: Text(label),
        ),
        if (message != null)
          Semantics(
            liveRegion: true,
            child: Text(
              message!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: color ?? tokens.ink3),
            ),
          ),
      ],
    );
  }
}
