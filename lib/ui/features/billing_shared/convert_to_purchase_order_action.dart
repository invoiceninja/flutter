import 'package:decimal/decimal.dart';
import 'package:flutter/widgets.dart';

import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/features/billing_shared/billing_cross_clone.dart';

/// Opens the purchase order an invoice or quote converts to (React #3370) —
/// see [convertToPurchaseOrder] for what carries over. The design comes from
/// the source client's settings cascade, as on the server. The vendor is
/// still the user's to pick on the create screen.
///
/// Lines whose product carries no cost come across at 0 — a product the PO
/// can't price. Said up front, so a zero-total order isn't a surprise.
Future<void> openConvertedPurchaseOrder(
  BuildContext context,
  Services services, {
  required String companyId,
  required BillingCloneData data,
  String invoiceId = '',
  String quoteId = '',
}) async {
  final settings = await services.settings.resolved(
    companyId: companyId,
    clientId: data.clientId.isEmpty ? null : data.clientId,
  );
  if (!context.mounted) return;
  final designId = settings['purchase_order_design_id'];
  final po = convertToPurchaseOrder(
    data,
    invoiceId: invoiceId,
    quoteId: quoteId,
    designId: designId is String ? designId : '',
  );
  final uncosted = po.lineItems
      .where(
        (l) =>
            l.cost == Decimal.zero &&
            (l.productKey.trim().isNotEmpty || l.notes.trim().isNotEmpty),
      )
      .length;
  if (uncosted > 0) {
    Notify.warning(
      context,
      context.tr('po_lines_without_cost', {'count': '$uncosted'}),
    );
  }
  goEntityCreateFullWidth(context, '/purchase_orders', extra: po);
}
