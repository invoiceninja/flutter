import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company_gateway.dart';

/// Resolves a company gateway's display label from the local Drift cache and
/// renders it as a `Text`. Falls back to the raw [gatewayId] while unresolved
/// (or when the gateway carries no label) and to an em-dash when [gatewayId] is
/// empty.
///
/// Company gateways are seeded up front by `CompanyGatewayRepository.applyBundle`
/// from the `/login` / `/refresh` envelope, so there is no lazy per-id hydrate.
/// Resolution mirrors `payment_detail_gateway_card.dart` (prefer `label`).
class CompanyGatewayNameLabel extends StatelessWidget {
  const CompanyGatewayNameLabel({
    super.key,
    required this.gatewayId,
    this.style,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
  });

  final String gatewayId;
  final TextStyle? style;
  final int maxLines;
  final TextOverflow overflow;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    if (gatewayId.isEmpty) {
      return Text(
        '—',
        style:
            style ?? TextStyle(fontSize: 13, height: 1.2, color: tokens.ink3),
        maxLines: maxLines,
        overflow: overflow,
      );
    }
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId;
    if (companyId == null || companyId.isEmpty) {
      return _text(context, gatewayId);
    }
    return StreamBuilder<CompanyGateway?>(
      initialData: services.companyGateways.peek(
        companyId: companyId,
        id: gatewayId,
      ),
      stream: services.companyGateways.watch(
        companyId: companyId,
        id: gatewayId,
      ),
      builder: (context, snapshot) {
        final gateway = snapshot.data;
        final name = gateway == null || gateway.label.isEmpty
            ? gatewayId
            : gateway.label;
        return _text(context, name);
      },
    );
  }

  Widget _text(BuildContext context, String text) => Text(
    text,
    style:
        style ??
        TextStyle(fontSize: 13, height: 1.2, color: context.inTheme.ink),
    maxLines: maxLines,
    overflow: overflow,
  );
}
