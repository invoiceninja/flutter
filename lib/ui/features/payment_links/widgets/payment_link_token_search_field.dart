import 'package:flutter/material.dart';

import 'package:admin/ui/core/list/search/token_search_field.dart';
import 'package:admin/ui/features/payment_links/view_models/payment_link_list_view_model.dart';
import 'package:admin/ui/features/payment_links/widgets/payment_link_filter_keys.dart';

/// Thin wrapper that wires [TokenSearchField] for the Payment Links list.
class PaymentLinkTokenSearchField extends StatelessWidget {
  const PaymentLinkTokenSearchField({
    required this.vm,
    required this.wide,
    super.key,
  });

  final PaymentLinkListViewModel vm;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return TokenSearchField(
      vm: vm,
      filterKeys: buildPaymentLinkFilterKeys(),
      wide: wide,
      // Matches the other entity search fields. The Transifex
      // `search_payment_links` is "Search :count Payment Links" and this hint
      // substitutes nothing.
      hintKey: 'search_payment_links_or_filter_hint',
    );
  }
}
