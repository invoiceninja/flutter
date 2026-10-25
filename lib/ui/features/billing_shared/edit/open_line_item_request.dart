import 'package:flutter/widgets.dart';

import 'package:admin/app/router.dart';
import 'package:admin/ui/features/billing_shared/billing_doc_type.dart';

/// The edit route's `extra` when a line item was tapped on the record screen:
/// open the editor already editing the line at [index] (admin-portal parity —
/// tapping a line used to skip Edit → Items → tap the line).
///
/// A route `extra`, never a query parameter: the URL is persisted for "resume
/// where you left off" and replayed by back / forward, and either would reopen
/// the line's dialog on a screen the user had already moved past.
@immutable
class OpenLineItemRequest {
  const OpenLineItemRequest(this.index);

  /// The line's position in the document's `line_items`, blank lines
  /// included — the order the edit view model's draft holds them in.
  final int index;

  /// [extra] as a request, or null when the route carries something else (an
  /// invoice's "Add to invoice" draft) or nothing.
  static OpenLineItemRequest? of(Object? extra) =>
      extra is OpenLineItemRequest ? extra : null;

  @override
  bool operator ==(Object other) =>
      other is OpenLineItemRequest && other.index == index;

  @override
  int get hashCode => index.hashCode;
}

/// Open [type]'s edit screen for [id] on the line at [index].
///
/// The invoice goes through `InvoiceActions.edit` instead, whose lock check
/// must run first.
void goEditBillingDocLineItem(
  BuildContext context, {
  required BillingDocType type,
  required String id,
  required int index,
}) => goEntityEdit(
  context,
  type.routePath,
  id,
  extra: OpenLineItemRequest(index),
);
