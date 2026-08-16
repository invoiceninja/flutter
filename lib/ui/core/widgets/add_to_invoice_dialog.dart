import 'package:flutter/material.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/domain/billing/invoice_lock.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';
import 'package:admin/utils/formatting.dart';

/// Pick an existing editable invoice for the active [clientId] so a task /
/// expense / project's line items can be appended to it. Returns the chosen
/// [Invoice] (the caller appends the line items and routes to its edit screen,
/// where the normal outbox update applies) or null on cancel.
///
/// Mirrors `showMergeClientDialog` — a `SearchableDropdownField` inside an
/// `AlertDialog`. Offline-first, but not offline-*only*: it kicks off one
/// client-scoped page fetch on open, because the underlying stream is pure
/// Drift (`InvoiceRepository.watchForClient`) and a user who has never browsed
/// this client's invoices would otherwise be told "no records found".
Future<Invoice?> showAddToInvoiceDialog(
  BuildContext context, {
  required Services services,
  required String companyId,
  required String clientId,
  required Formatter formatter,
}) {
  return showDialog<Invoice?>(
    context: context,
    builder: (ctx) => _AddToInvoiceDialog(
      services: services,
      companyId: companyId,
      clientId: clientId,
      formatter: formatter,
    ),
  );
}

class _AddToInvoiceDialog extends StatefulWidget {
  const _AddToInvoiceDialog({
    required this.services,
    required this.companyId,
    required this.clientId,
    required this.formatter,
  });

  final Services services;
  final String companyId;
  final String clientId;
  final Formatter formatter;

  @override
  State<_AddToInvoiceDialog> createState() => _AddToInvoiceDialogState();
}

class _AddToInvoiceDialogState extends State<_AddToInvoiceDialog> {
  Invoice? _selected;

  /// Hoisted, never rebuilt in `build`. `StreamBuilder` compares streams by
  /// identity, so a fresh `watchForClient(...)` per build resubscribes to the
  /// Drift query on every `setState` — and this widget has three sources of
  /// those (the lock cascade, the prefetch finishing, each selection). Every
  /// resubscribe re-enters `waiting` with null data, which empties `items`,
  /// and an empty list makes `SearchableDropdownField` unmount its
  /// `RawAutocomplete` entirely (`searchable_dropdown_field.dart`) — the open
  /// options list and whatever the user had typed vanish mid-interaction.
  /// The app-wide stable-stream rule; see CLAUDE.md.
  late final Stream<List<Invoice>> _invoices = widget.services.invoices
      .watchForClient(companyId: widget.companyId, clientId: widget.clientId);

  /// Null until the settings cascade resolves. Held as the two resolved inputs
  /// rather than per-invoice `resolveInvoiceLockReason` calls: the dialog is
  /// scoped to a single client, so the cascade is identical for every row and
  /// one read covers the list.
  String? _lockInvoicesSetting;
  bool _veriFactuActive = false;
  bool _settingsLoaded = false;

  /// Purely cosmetic: the list renders from Drift immediately and the fetch
  /// only widens it, so this drives a spinner, never a gate.
  bool _fetching = true;

  @override
  void initState() {
    super.initState();
    _loadLockSettings();
    _prefetchInvoices();
  }

  Future<void> _loadLockSettings() async {
    try {
      final resolved = await widget.services.settings.resolved(
        companyId: widget.companyId,
        clientId: widget.clientId.isEmpty ? null : widget.clientId,
      );
      if (!mounted) return;
      setState(() {
        _lockInvoicesSetting = resolved['lock_invoices'] as String?;
        _veriFactuActive = resolved['e_invoice_type'] == 'VERIFACTU';
        _settingsLoaded = true;
      });
    } catch (_) {
      // Can't resolve the cascade → fall back to the server's own `isLocked`
      // flag (still honoured by `invoiceLockReason`). Better than hiding
      // everything or offering everything.
      if (mounted) setState(() => _settingsLoaded = true);
    }
  }

  Future<void> _prefetchInvoices() async {
    try {
      await widget.services.invoices.ensurePageLoaded(
        companyId: widget.companyId,
        page: 1,
        states: const {EntityState.active},
        extraFilters: {
          'client_id': {widget.clientId},
        },
        // Client-scoped fetch: never touch the browsable list's shared cursor.
        ignoreCursor: true,
      );
    } catch (_) {
      // Offline / server hiccup — the Drift rows we already have still show.
    }
    if (mounted) setState(() => _fetching = false);
  }

  /// Invoices that can still take a new line. Excludes paid / cancelled
  /// (appending silently reopens a settled balance — matches legacy
  /// admin-portal) and **locked** ones: `InvoiceRepository.save` re-checks the
  /// lock and the edit screen bounces the user straight back out, so offering
  /// a sent invoice under `lock_invoices = when_sent` would let them watch the
  /// lines land and then lose the work at Save.
  List<Invoice> _selectable(List<Invoice> all) {
    final rows =
        all
            .where(
              (i) =>
                  !i.isDeleted &&
                  i.archivedAt == null &&
                  !i.isPaid &&
                  !i.isCancelled &&
                  (!_settingsLoaded ||
                      invoiceLockReason(
                            invoice: i,
                            lockInvoicesSetting: _lockInvoicesSetting,
                            veriFactuActive: _veriFactuActive,
                          ) ==
                          InvoiceLockReason.none),
            )
            .toList()
          ..sort((a, b) => b.number.compareTo(a.number));
    // Rows render before the lock cascade resolves, so a pick made in that
    // window can stop being selectable a moment later. Leaving `_selected`
    // pointing at it would keep the primary enabled on an invoice that
    // `InvoiceRepository.save` will refuse — the exact "watch the lines land,
    // then lose them at Save" flow the lock filter exists to prevent — and
    // hand `SearchableDropdownField` an `initialValue` absent from `items`.
    final picked = _selected;
    if (picked != null && !rows.any((i) => i.id == picked.id)) {
      // Deferred: this runs inside a `StreamBuilder` build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _selected?.id != picked.id) return;
        setState(() => _selected = null);
      });
    }
    return rows;
  }

  /// `#0042 · Mar 2, 2026 · $1,250.00` — number alone is thin when a client
  /// has a dozen open invoices.
  String _label(BuildContext context, Invoice invoice) {
    final number = invoice.number.isEmpty
        ? context.tr('pending')
        : invoice.number;
    final date = invoice.date == null
        ? ''
        : widget.formatter.date(invoice.date!.toIso());
    return [
      number,
      if (date.isNotEmpty) date,
      widget.formatter.money(invoice.balanceOrAmount),
    ].join('  ·  ');
  }

  @override
  Widget build(BuildContext context) {
    // `action_add_to_invoice` ("Add To Invoice"), never `add_to_invoice` —
    // the latter is "Add to invoice :invoice" and this surface fires *before*
    // an invoice is picked, so the token has nothing to fill it. Mirrors
    // admin-portal (`EntityAction.toString()`) and React's expense action.
    final label = context.tr('action_add_to_invoice');
    return AlertDialog(
      title: Text(label),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: StreamBuilder<List<Invoice>>(
          stream: _invoices,
          builder: (context, snapshot) {
            final invoices = _selectable(snapshot.data ?? const <Invoice>[]);
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SearchableDropdownField<Invoice>(
                  label: context.tr('invoice'),
                  items: invoices,
                  initialValue: _selected,
                  emptyHintKey: 'no_records_found',
                  displayString: (i) => _label(context, i),
                  idOf: (i) => i.id,
                  onChanged: (i) => setState(() => _selected = i),
                ),
                if (_fetching) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(minHeight: 2),
                ],
              ],
            );
          },
        ),
      ),
      actions: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr('cancel')),
        ),
        PrimaryDialogAction(
          label: label,
          enabled: _selected != null,
          // Dropdown picker: Enter selects an option (SearchableDropdownField
          // never fires the primary), so no Enter hint.
          autofocus: false,
          showEnterHint: false,
          onPressed: () => Navigator.of(context).pop(_selected),
        ),
      ],
    );
  }
}
