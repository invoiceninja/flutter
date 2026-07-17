import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/payment.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/custom_fields_detail_card.dart';
import 'package:admin/ui/core/detail/entity_detail_scaffold.dart';
import 'package:admin/ui/core/detail/entity_detail_tabs.dart';
import 'package:admin/ui/core/detail/build_standard_documents_tab.dart';
import 'package:admin/ui/core/widgets/centered_form_column.dart';
import 'package:admin/ui/core/widgets/formatter_host_mixin.dart';
import 'package:admin/ui/features/billing_shared/activity/billing_doc_activity_tab.dart';
import 'package:admin/ui/features/payments/view_models/payment_detail_view_model.dart';
import 'package:admin/ui/features/payments/widgets/detail/payment_detail_actions_row.dart';
import 'package:admin/ui/features/payments/widgets/detail/payment_detail_gateway_card.dart';
import 'package:admin/ui/features/payments/widgets/detail/payment_detail_header.dart';
import 'package:admin/ui/features/payments/widgets/detail/payment_detail_kpi_strip.dart';
import 'package:admin/ui/features/payments/widgets/detail/payment_unapplied_band.dart';
import 'package:admin/ui/features/payments/widgets/payment_actions.dart';

class PaymentDetailScreen extends StatefulWidget {
  const PaymentDetailScreen({required this.id, super.key});
  final String id;

  @override
  State<PaymentDetailScreen> createState() => _PaymentDetailScreenState();
}

class _PaymentDetailScreenState extends State<PaymentDetailScreen>
    with FormatterHostMixin {
  late final PaymentDetailViewModel _vm;
  late final Services _services;
  late final String _companyId;

  @override
  void initState() {
    super.initState();
    _services = context.read<Services>();
    _companyId = _services.auth.session.value!.currentCompanyId;
    _vm = PaymentDetailViewModel.bound(
      _services.payments.watch(companyId: _companyId, id: widget.id),
    );
    // Hydrate on a cache miss (dashboard tap) so the detail resolves
    // instead of showing "not found".
    _services.payments.ensureLoaded(companyId: _companyId, id: widget.id);
    loadFormatter(_services, _companyId);
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return EntityDetailScaffold<Payment>(
      vm: _vm,
      emptyIcon: Icons.payments_outlined,
      emptyTitle: context.tr('payment_not_found'),
      actionsForItem: (context, p) => PaymentDetailActionsRow(
        payment: p,
        onAction: (a) =>
            PaymentActions.dispatch(context, _services, _companyId, p, a),
      ),
      bodyBuilder: (context, p) {
        return SingleChildScrollView(
          padding: EdgeInsets.all(InSpacing.lg(context)),
          // Whole body capped/centered (820) — not just an overview grid like
          // client/vendor detail. Payment detail has no long browsable
          // related-entity lists, so centering the tabs too reads cleanly.
          child: CenteredFormColumn(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PaymentDetailHeader(payment: p, formatter: formatter),
                const SizedBox(height: InSpacing.xl),
                EntityDetailTabs(
                  tabs: [
                    EntityDetailTab(
                      label: context.tr('overview'),
                      icon: Icons.dashboard_outlined,
                      bodyBuilder: (_) => Padding(
                        padding: EdgeInsets.all(InSpacing.lg(context)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            PaymentDetailKpiStrip(
                              payment: p,
                              formatter: formatter,
                            ),
                            PaymentUnappliedBand(
                              payment: p,
                              formatter: formatter,
                            ),
                            if (p.companyGatewayId.isNotEmpty) ...[
                              SizedBox(height: InSpacing.md(context)),
                              PaymentDetailGatewayCard(
                                companyId: _companyId,
                                companyGatewayId: p.companyGatewayId,
                              ),
                            ],
                            if (p.customValue1.isNotEmpty ||
                                p.customValue2.isNotEmpty ||
                                p.customValue3.isNotEmpty ||
                                p.customValue4.isNotEmpty) ...[
                              SizedBox(height: InSpacing.md(context)),
                              CustomFieldsDetailCard(
                                companyId: _companyId,
                                prefix: 'payment',
                                values: [
                                  p.customValue1,
                                  p.customValue2,
                                  p.customValue3,
                                  p.customValue4,
                                ],
                                formatter: formatter,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    buildStandardDocumentsTab(
                      context: context,
                      companyId: _companyId,
                      entityId: p.id,
                      documents: p.documents,
                      repo: _services.payments,
                      formatter: formatter,
                    ),
                    EntityDetailTab(
                      label: context.tr('activity'),
                      icon: Icons.history_outlined,
                      bodyBuilder: (_) => BillingDocActivityTab(
                        entityWireName: 'payment',
                        entityId: p.id,
                        companyId: _companyId,
                        activitiesApi: _services.activities,
                        outboxDao: _services.db.outboxDao,
                        formatter: formatter,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
