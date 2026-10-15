import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/data/models/domain/payment.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';
import 'package:admin/ui/features/payments/view_models/payment_edit_view_model.dart';
import 'package:admin/ui/features/payments/widgets/edit/payment_allocations_section.dart';
import 'package:admin/utils/formatting.dart';

/// Start a new payment from an invoice instead of a client (React's "client
/// *or* invoice"): picking one fills the client and allocates the invoice's
/// open amount. Lists the unpaid invoices — every client's until one is
/// chosen, then that client's — newest first.
///
/// It shows and controls the payment's single invoice, so it is drawn only
/// while there is at most one: past that the allocations section below is
/// where invoices are added and removed, and a picker showing one of several
/// would be a lie about the rest.
class PaymentInvoicePicker extends StatefulWidget {
  const PaymentInvoicePicker({
    super.key,
    required this.vm,
    required this.formatter,
  });
  final PaymentEditViewModel vm;
  final Formatter? formatter;

  @override
  State<PaymentInvoicePicker> createState() => PaymentInvoicePickerState();
}

class PaymentInvoicePickerState extends State<PaymentInvoicePicker> {
  late final Services _services;
  late final Stream<List<Invoice>> _invoices;
  late final Stream<List<Client>> _clients;

  /// The client whose unpaid invoices were last fetched; `''` is everyone's.
  String? _fetchedFor;

  PaymentEditViewModel get vm => widget.vm;

  @override
  void initState() {
    super.initState();
    _services = context.read<Services>();
    _invoices = _services.invoices.watchRecent(
      companyId: vm.companyId,
      limit: 1000,
      badgeModeId: 'unpaid',
    );
    // The same query the Client picker runs, which drift shares — here only to
    // name each invoice's client.
    _clients = _services.clients.watchPage(
      companyId: vm.companyId,
      loadedPages: 100,
    );
    _fetch();
  }

  @override
  void didUpdateWidget(PaymentInvoicePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    _fetch();
  }

  /// A list page doesn't bring every unpaid invoice, so ask the server for
  /// the first page of them — everyone's, or the chosen client's. Best
  /// effort: offline, the cached ones are what there is.
  void _fetch() {
    final clientId = vm.draft.clientId;
    if (clientId == _fetchedFor) return;
    _fetchedFor = clientId;
    if (clientId.isEmpty) {
      _services.invoices
          .ensurePageLoaded(
            companyId: vm.companyId,
            page: 1,
            extraFilters: const {
              'client_status': {'unpaid'},
            },
          )
          .ignore();
    } else {
      _services.invoices
          .ensureUnpaidForClientLoaded(
            companyId: vm.companyId,
            clientId: clientId,
          )
          .ignore();
    }
  }

  String _label(BuildContext context, Invoice invoice, Client? client) {
    final f = widget.formatter;
    final amount = invoice.balanceOrAmount;
    final name = client?.displayName ?? '';
    return [
      invoice.number.isEmpty ? context.tr('pending') : '#${invoice.number}',
      if (name.isNotEmpty) name,
      f?.money(amount, clientCurrencyId: client?.currencyId) ??
          amount.toString(),
    ].join('  ·  ');
  }

  void _onPicked(Invoice? invoice, Client? client) {
    if (invoice == null) {
      vm.clearInvoiceAllocations();
      return;
    }
    final target = AllocationTarget(
      id: invoice.id,
      number: invoice.number,
      balance: invoice.balanceOrAmount,
      partial: invoice.partial,
    );
    vm.startFromInvoice(
      clientId: invoice.clientId,
      clientCurrencyId: client?.currencyId ?? '',
      allocation: Paymentable(
        invoiceId: invoice.id,
        amount: computeAutoFillAmount(
          kind: AllocationKind.invoice,
          target: target,
          paymentAmount: vm.autoFillCap,
          allocatedExcludingThisRow: Decimal.zero,
        ),
        refunded: Decimal.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Client>>(
      stream: _clients,
      builder: (context, clientSnap) {
        final clientsById = {
          for (final c in clientSnap.data ?? const <Client>[]) c.id: c,
        };
        return StreamBuilder<List<Invoice>>(
          stream: _invoices,
          builder: (context, snap) {
            final clientId = vm.draft.clientId;
            final items = [
              for (final i in snap.data ?? const <Invoice>[])
                if (!i.id.startsWith('tmp_') &&
                    i.balanceOrAmount > Decimal.zero &&
                    (clientId.isEmpty || i.clientId == clientId))
                  i,
            ];
            final allocated = [
              for (final p in vm.draft.paymentables)
                if (p.invoiceId.isNotEmpty) p.invoiceId,
            ];
            Invoice? selected;
            if (allocated.length == 1) {
              for (final i in items) {
                if (i.id == allocated.single) {
                  selected = i;
                  break;
                }
              }
            }
            return SearchableDropdownField<Invoice>(
              label: context.tr('invoice'),
              items: items,
              initialValue: selected,
              emptyHintKey: 'no_open_invoices',
              displayString: (i) => _label(context, i, clientsById[i.clientId]),
              idOf: (i) => i.id,
              onChanged: (i) =>
                  _onPicked(i, i == null ? null : clientsById[i.clientId]),
            );
          },
        );
      },
    );
  }
}
