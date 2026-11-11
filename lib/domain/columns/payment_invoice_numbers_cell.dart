import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/router.dart';
import 'package:admin/data/models/domain/payment.dart';
import 'package:admin/domain/columns/column_cells.dart';
import 'package:admin/ui/core/widgets/invoice_name_label.dart';
import 'package:admin/ui/core/widgets/link_text.dart';
import 'package:admin/ui/core/widgets/ltr_value.dart';

/// The ids of the invoices [payment] is applied to, in allocation order.
List<String> paymentInvoiceIds(Payment payment) => <String>{
  for (final p in payment.paymentables)
    if (p.invoiceId.isNotEmpty) p.invoiceId,
}.toList();

/// The number of invoice [invoiceId] as the payment itself carries it, or
/// null. Every list page is fetched with `include=invoices`
/// (`PaymentRepository.ensurePageLoaded`), so the number is normally already
/// on the row.
String? paymentInvoiceNumber(Payment payment, String invoiceId) {
  for (final ref in payment.invoices) {
    if (ref.id == invoiceId) return ref.number.isEmpty ? null : ref.number;
  }
  return null;
}

/// The Payments list's Invoice Number cell: the number of the invoice the
/// payment is applied to, linked. A payment spread over several invoices
/// names the first and counts the rest (`INV-0012 +2`) — a list cell is one
/// line, and three numbers sharing it would each be cut short.
///
/// The number is read off the payment. Only an invoice the payment carries no
/// reference for — a payment entered offline and not yet synced — goes
/// through [InvoiceNameLabel], which reads the local cache and fetches the
/// invoice when it is missing: a page of fifty rows each asking the server
/// for its invoice is fifty requests, which is why that is the fallback and
/// not the cell.
///
/// Lives beside the registry, not under `ui/features/`: a linked name is
/// right only in a labelled wide-table column, and
/// `no_list_tile_name_link_test` holds every feature widget to that.
class PaymentInvoiceNumbersCell extends StatelessWidget {
  const PaymentInvoiceNumbersCell({super.key, required this.payment});

  final Payment payment;

  @override
  Widget build(BuildContext context) {
    final ids = paymentInvoiceIds(payment);
    if (ids.isEmpty) return cellEmpty();
    final number = paymentInvoiceNumber(payment, ids.first);
    final first = number == null
        ? InvoiceNameLabel(invoiceId: ids.first, link: true)
        : linkOrText(
            context: context,
            link: true,
            label: number,
            onTap: () => goEntityFullDetail(context, '/invoices', ids.first),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
    if (ids.length == 1) return first;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: first),
        const SizedBox(width: 6),
        LtrText(
          '+${ids.length - 1}',
          style: TextStyle(fontSize: 13, color: context.inTheme.ink3),
        ),
      ],
    );
  }
}
