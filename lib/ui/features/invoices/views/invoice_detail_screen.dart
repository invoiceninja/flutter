import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/router.dart';
import 'package:admin/ui/core/detail/entity_list_empty_action.dart';
import 'package:admin/ui/core/widgets/client_name_label.dart';
import 'package:admin/ui/core/widgets/link_text.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/db/app_database.dart' show OutboxRow;
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/domain/sync/mutation.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/detail/custom_fields_detail_card.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/detail/entity_detail_scaffold.dart';
import 'package:admin/ui/core/detail/entity_detail_tabs.dart';
import 'package:admin/ui/core/detail/recent_visit_recorder.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/core/detail/build_standard_documents_tab.dart';
import 'package:admin/ui/core/widgets/formatter_host_mixin.dart';
import 'package:admin/ui/core/widgets/formatter_scope.dart';
import 'package:admin/ui/core/widgets/party_call_button.dart';
import 'package:admin/ui/core/widgets/watch_builder.dart';
import 'package:admin/ui/core/detail/activity_note_actions.dart';
import 'package:admin/ui/features/billing_shared/activity/billing_doc_activity_tab.dart';
import 'package:admin/ui/features/billing_shared/sends/billing_doc_sends_tab.dart';
import 'package:admin/ui/features/billing_shared/billing_doc_type.dart';
import 'package:admin/ui/features/billing_shared/pdf/billing_doc_pdf_view.dart';
import 'package:admin/ui/features/invoices/view_models/invoice_detail_view_model.dart';
import 'package:admin/ui/features/invoices/widgets/detail/invoice_lock_banner.dart';
import 'package:admin/ui/features/invoices/widgets/detail/invoice_reminders_summary.dart';
import 'package:admin/ui/features/invoices/widgets/detail/invoice_unapplied_payments_section.dart';
import 'package:admin/ui/features/invoices/widgets/detail/invoice_payment_schedule_tab.dart';
import 'package:admin/ui/features/invoices/widgets/invoice_actions.dart';
import 'package:admin/ui/features/invoices/widgets/invoice_status_pill.dart';
import 'package:admin/ui/features/invoices/widgets/rectify_invoice.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/domain/billing/totals_calculator.dart';
import 'package:admin/ui/features/billing_shared/billing_doc_kpi_strip.dart';
import 'package:admin/ui/features/billing_shared/billing_doc_overview.dart';
import 'package:admin/ui/features/invoices/widgets/detail/invoice_applied_payments_section.dart';

/// Read-only Invoice detail screen.
///
/// **M1** shipped the header (number + balance + status pill + actions row).
/// **M2** adds the Documents tab, a wide-mode PDF preview pane, and wires
/// the action set (send email, mark sent/paid, autoBill, view/download/print PDF).
/// **M3** adds line items + invitations + payment history. **M4** adds
/// Verifactu + unapplied payments + reminders.
class InvoiceDetailScreen extends StatefulWidget {
  const InvoiceDetailScreen({required this.id, super.key});
  final String id;

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen>
    with FormatterHostMixin {
  late final InvoiceDetailViewModel _vm;
  late final Services _services;
  late final String _companyId;

  @override
  void initState() {
    super.initState();
    _services = context.read<Services>();
    _companyId = _services.auth.session.value!.currentCompanyId;
    _vm = InvoiceDetailViewModel.bound(
      _services.invoices.watch(companyId: _companyId, id: widget.id),
    );
    loadFormatter(_services, _companyId);
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return EntityDetailScaffold<Invoice>(
      id: widget.id,
      vm: _vm,
      hydrate: () =>
          _services.invoices.ensureLoaded(companyId: _companyId, id: widget.id),
      emptyAction: entityListEmptyAction(context, EntityType.invoice),
      emptyIcon: Icons.receipt_long_outlined,
      emptyTitle: context.tr('invoice_not_found'),
      actionsForItem: (context, invoice) => _InvoiceActionsRow(
        invoice: invoice,
        services: _services,
        companyId: _companyId,
      ),
      bodyBuilder: (context, invoice) {
        final body = _Body(
          invoice: invoice,
          services: _services,
          companyId: _companyId,
        );
        // Always mounted, even while `formatter` is still null: branching
        // here would change the tree shape and remount the whole body when
        // the formatter lands.
        return FormatterScope(formatter: formatter, child: body);
      },
    );
  }
}

/// Invoice actions row. The Verifactu "rectify" action's visibility depends
/// on the invoice's client country + the company's `e_invoice_type` — async
/// inputs not available to the synchronous `itemsFor`. We pre-gate on the
/// cheap invoice-only subset ([rectifyPreGate]) and only subscribe the
/// client/company streams when that passes (the rare Verifactu case).
class _InvoiceActionsRow extends StatefulWidget {
  const _InvoiceActionsRow({
    required this.invoice,
    required this.services,
    required this.companyId,
  });

  final Invoice invoice;
  final Services services;
  final String companyId;

  @override
  State<_InvoiceActionsRow> createState() => _InvoiceActionsRowState();
}

class _InvoiceActionsRowState extends State<_InvoiceActionsRow> {
  /// Stable subscription — created once here, never inside `build()`. A fresh
  /// stream per build makes `StreamBuilder` retain its prior value across
  /// rebuild-induced re-subscribes; a fail-fast `sendEInvoice` failure and its
  /// shell modal are a rebuild burst that could otherwise drop the
  /// dead-excluded emission and leave the "Send E-Invoice" action
  /// stuck-suppressed. Mirrors the Sends-tab fix. `invoice.id` is stable for
  /// this screen, so capturing it once is safe.
  late final Stream<List<OutboxRow>> _sendEInvoicePending;

  @override
  void initState() {
    super.initState();
    _sendEInvoicePending = widget.services.db.outboxDao.watchPendingForEntity(
      companyId: widget.companyId,
      entityType: 'invoice',
      entityId: widget.invoice.id,
      kind: MutationKind.sendEInvoice,
    );
    _ensureClient();
  }

  @override
  void didUpdateWidget(_InvoiceActionsRow old) {
    super.didUpdateWidget(old);
    if (old.invoice.clientId != widget.invoice.clientId) _ensureClient();
  }

  /// The rectify gate needs the invoice's client in Drift (paginated lists
  /// prefetch only page 1). Mirror `ClientNameLabel._ensure`: deduped /
  /// negative-cached / safe to fire unconditionally. Only when the cheap
  /// pre-gate passes, so non-Verifactu invoice opens don't fetch the client.
  void _ensureClient() {
    final inv = widget.invoice;
    if (!rectifyPreGate(inv) || inv.clientId.isEmpty) return;
    widget.services.clients.ensureLoaded(
      companyId: widget.companyId,
      id: inv.clientId,
    );
  }

  Widget _row(
    BuildContext context,
    bool rectifyEligible,
    String? eInvoiceType,
    bool sendEInvoicePending,
  ) => EntityDetailActionsRow<InvoiceAction>(
    items: InvoiceActions.itemsFor(
      context,
      widget.invoice,
      (a) => InvoiceActions.dispatch(
        context,
        widget.services,
        widget.companyId,
        widget.invoice,
        a,
      ),
      rectifyEligible: rectifyEligible,
      eInvoiceType: eInvoiceType,
      sendEInvoicePending: sendEInvoicePending,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final inv = widget.invoice;
    // Pending `sendEInvoice` outbox row for this invoice → suppress the
    // Send action so the user can't double-enqueue a compliance
    // transmission (React uses a send cooldown). Reuses the same
    // per-entity/kind pending seam as the Activity tab.
    return StreamBuilder<List<OutboxRow>>(
      stream: _sendEInvoicePending,
      builder: (context, pendingSnap) {
        final sendPending = (pendingSnap.data ?? const []).isNotEmpty;
        // Always resolve the company's e-invoice type (cheap local Drift
        // watch) — the send/validate gate needs it for any e-invoiced
        // invoice, not just Verifactu. The client watch (for rectify) is
        // still only added when the cheap rectify pre-gate passes.
        return WatchBuilder<Company?>(
          cacheKey: widget.companyId,
          create: () => widget.services.company.watchCompany(widget.companyId),
          builder: (context, companySnap) {
            final eInvoiceType = companySnap.data?.settings.eInvoiceType;
            if (!rectifyPreGate(inv)) {
              return _row(context, false, eInvoiceType, sendPending);
            }
            return WatchBuilder<Client?>(
              cacheKey: (widget.companyId, inv.clientId),
              initialData: widget.services.clients.peek(
                companyId: widget.companyId,
                id: inv.clientId,
              ),
              create: () => widget.services.clients.watch(
                companyId: widget.companyId,
                id: inv.clientId,
              ),
              builder: (context, clientSnap) {
                final eligible = isRectifyEligible(
                  invoice: inv,
                  clientCountryId: clientSnap.data?.countryId,
                  eInvoiceType: eInvoiceType,
                );
                return _row(context, eligible, eInvoiceType, sendPending);
              },
            );
          },
        );
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.invoice,
    required this.services,
    required this.companyId,
  });

  final Invoice invoice;
  final Services services;
  final String companyId;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Two-pane on wide: left = info + tabs, right = sticky PDF preview.
        // Single-column on narrow with a "View PDF" affordance routing to
        // `/invoices/:id/pdf`.
        final wide =
            Breakpoints.isWide(constraints) && constraints.maxWidth >= 900;
        final main = SingleChildScrollView(
          padding: EdgeInsets.all(InSpacing.lg(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RecentVisitRecorder(
                type: EntityType.invoice,
                id: invoice.id,
                label: invoice.number.isEmpty
                    ? context.tr('invoice')
                    : '#${invoice.number}',
                child: _Header(invoice: invoice, companyId: companyId),
              ),
              SizedBox(height: InSpacing.lg(context)),
              EntityDetailTabs(
                tabs: [
                  EntityDetailTab(
                    label: context.tr('overview'),
                    icon: Icons.dashboard_outlined,
                    bodyBuilder: (_) => Padding(
                      padding: EdgeInsets.all(InSpacing.lg(context)),
                      child: _Overview(invoice: invoice),
                    ),
                  ),
                  buildStandardDocumentsTab(
                    context: context,
                    companyId: companyId,
                    entityId: invoice.id,
                    documents: invoice.documents,
                    repo: services.invoices,
                  ),
                  EntityDetailTab(
                    label: context.tr('activity'),
                    icon: Icons.history_outlined,
                    bodyBuilder: (_) => BillingDocActivityTab(
                      entityWireName: 'invoice',
                      entityId: invoice.id,
                      companyId: companyId,
                      activitiesApi: services.activities,
                      outboxDao: services.db.outboxDao,
                      onAddComment: () => promptAddCommentFor(
                        context,
                        entityId: invoice.id,
                        submit: (text) => services.invoices.addComment(
                          companyId: companyId,
                          invoiceId: invoice.id,
                          text: text,
                        ),
                      ),
                      onLogCall: () => promptLogCallFor(
                        context,
                        companyId: companyId,
                        entityId: invoice.id,
                        subject: invoice.number.isEmpty
                            ? ''
                            : '#${invoice.number}',
                        submit: (text) => services.invoices.addComment(
                          companyId: companyId,
                          invoiceId: invoice.id,
                          text: text,
                        ),
                      ),
                    ),
                  ),
                  EntityDetailTab(
                    label: context.tr('email_history'),
                    icon: Icons.outgoing_mail,
                    bodyBuilder: (_) => BillingDocSendsTab(
                      services: services,
                      companyId: companyId,
                      entityWireName: 'invoice',
                      entityId: invoice.id,
                      invitations: invoice.invitations,
                      clientId: invoice.clientId,
                      isHosted: services.auth.session.value?.isHosted ?? false,
                      onReactivate: (messageId) =>
                          services.invoices.reactivateInvitationEmail(
                            companyId: companyId,
                            id: invoice.id,
                            messageId: messageId,
                          ),
                    ),
                  ),
                  EntityDetailTab(
                    label: context.tr('unapplied_payments'),
                    icon: Icons.account_balance_wallet_outlined,
                    bodyBuilder: (_) => InvoiceUnappliedPaymentsSection(
                      invoice: invoice,
                      services: services,
                      companyId: companyId,
                    ),
                  ),
                  if (invoiceSupportsPaymentSchedule(
                    invoice,
                    canViewOrEdit:
                        (services.auth.session.value?.currentCompany?.can(
                              'edit_invoice',
                            ) ??
                            false) ||
                        (services.auth.session.value?.currentCompany?.can(
                              'view_invoice',
                            ) ??
                            false),
                  ))
                    EntityDetailTab(
                      label: context.tr('payment_schedule'),
                      icon: Icons.event_repeat_outlined,
                      bodyBuilder: (_) =>
                          InvoicePaymentScheduleTab(invoice: invoice),
                    ),
                ],
              ),
            ],
          ),
        );
        if (!wide) return main;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 5, child: main),
            VerticalDivider(width: 1, color: context.inTheme.border),
            Expanded(flex: 6, child: _PdfPane(invoice: invoice)),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.invoice, required this.companyId});
  final Invoice invoice;
  final String companyId;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final formatter = FormatterScope.maybeOf(context);
    final services = context.read<Services>();
    final effectiveDue = invoice.partialDueDate ?? invoice.dueDate;
    return Container(
      padding: EdgeInsets.all(InSpacing.lg(context)),
      decoration: BoxDecoration(
        border: Border.all(color: tokens.border),
        borderRadius: BorderRadius.circular(InRadii.r3),
        color: tokens.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Unconditional on purpose: it collapses to `SizedBox.shrink()`
          // itself, so the tree shape doesn't change when the reason resolves.
          InvoiceLockBanner(invoice: invoice, companyId: companyId),
          Row(
            children: [
              Flexible(
                child: Text(
                  invoice.number.isEmpty ? '—' : '#${invoice.number}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: tokens.ink,
                  ),
                ),
              ),
              SizedBox(width: InSpacing.md(context)),
              InvoiceStatusPill(
                statusId: invoice.calculatedStatusId,
                hasBounce: invoice.hasBouncedInvitation,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Flexible(
                child: ClientNameLabel(
                  clientId: invoice.clientId,
                  link: true,
                  style: TextStyle(color: tokens.ink3),
                ),
              ),
              PartyCallButton(
                clientId: invoice.clientId,
                // Filed against the *document*, not the party: the
                // server stamps `client_id` on it anyway, so it still
                // reaches the client's feed — and this way the note
                // also says which document the call was about.
                logTarget: (
                  type: EntityType.invoice,
                  id: invoice.id,
                  subject: invoice.number.isEmpty ? '' : '#${invoice.number}',
                ),
              ),
            ],
          ),
          // Link to the recurring invoice that generated this invoice.
          if (invoice.recurringId.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.autorenew, size: 14, color: tokens.ink3),
                const SizedBox(width: 4),
                LinkText(
                  label: context.tr('recurring_invoice'),
                  style: TextStyle(
                    color: tokens.ink3,
                    fontWeight: FontWeight.w500,
                  ),
                  onTap: () => goEntityFullDetail(
                    context,
                    '/recurring_invoices',
                    invoice.recurringId,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          BillingDatesCaption(
            formatter: formatter,
            issuedLabel: context.tr('date'),
            issued: invoice.date,
            secondaryLabel: context.tr('due_date'),
            secondary: effectiveDue,
            overduePrefix: context.tr('overdue'),
            overdueDays: invoice.isPastDue && effectiveDue != null
                ? Date.today().differenceInDays(effectiveDue)
                : null,
          ),
          const SizedBox(height: 16),
          WatchBuilder<Client?>(
            cacheKey: (companyId, invoice.clientId),
            initialData: services.clients.peek(
              companyId: companyId,
              id: invoice.clientId,
            ),
            create: () => services.clients.watch(
              companyId: companyId,
              id: invoice.clientId,
            ),
            builder: (context, clientSnap) => BillingDocKpiStrip(
              formatter: formatter,
              currencyId: clientSnap.data?.currencyId,
              metrics: [
                BillingMetric(
                  label: context.tr('amount'),
                  amount: invoice.amount,
                ),
                BillingMetric(
                  label: context.tr('balance'),
                  amount: invoice.balance,
                  highlightWhenPositive: invoice.isPastDue,
                ),
                BillingMetric(
                  label: context.tr('paid_to_date'),
                  amount: invoice.paidToDate,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.invoice});
  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final formatter = FormatterScope.maybeOf(context);
    final services = context.read<Services>();
    final companyId = services.auth.currentCompanyId ?? '';
    return WatchBuilder<Client?>(
      cacheKey: (companyId, invoice.clientId),
      initialData: services.clients.peek(
        companyId: companyId,
        id: invoice.clientId,
      ),
      create: () =>
          services.clients.watch(companyId: companyId, id: invoice.clientId),
      builder: (context, clientSnap) {
        final currencyId = clientSnap.data?.currencyId;
        final precision =
            formatter?.precisionFor(clientCurrencyId: currencyId) ?? 2;
        return BillingDocOverview(
          totalsInput: _invoiceTotalsInput(invoice),
          surchargeAmounts: [
            invoice.customSurcharge1,
            invoice.customSurcharge2,
            invoice.customSurcharge3,
            invoice.customSurcharge4,
          ],
          precision: precision,
          paidToDate: invoice.paidToDate,
          balance: invoice.balance,
          publicNotes: invoice.publicNotes,
          terms: invoice.terms,
          formatter: formatter,
          currencyId: currencyId,
          entityType: 'invoice',
          tagIds: invoice.tagIds,
          trailing: [
            if (invoice.customValue1.isNotEmpty ||
                invoice.customValue2.isNotEmpty ||
                invoice.customValue3.isNotEmpty ||
                invoice.customValue4.isNotEmpty)
              CustomFieldsDetailCard(
                companyId: companyId,
                prefix: 'invoice',
                values: [
                  invoice.customValue1,
                  invoice.customValue2,
                  invoice.customValue3,
                  invoice.customValue4,
                ],
                formatter: formatter,
              ),
            InvoiceAppliedPaymentsSection(
              invoice: invoice,
              services: services,
              companyId: companyId,
              formatter: formatter,
              currencyId: currencyId,
            ),
            InvoiceRemindersSummary(invoice: invoice),
          ],
        );
      },
    );
  }
}

BillingTotalsInput _invoiceTotalsInput(Invoice d) => BillingTotalsInput(
  lineItems: d.lineItems,
  discount: d.discount,
  isAmountDiscount: d.isAmountDiscount,
  usesInclusiveTaxes: d.usesInclusiveTaxes,
  taxName1: d.taxName1,
  taxRate1: d.taxRate1,
  taxName2: d.taxName2,
  taxRate2: d.taxRate2,
  taxName3: d.taxName3,
  taxRate3: d.taxRate3,
  customSurcharge1: d.customSurcharge1,
  customSurcharge2: d.customSurcharge2,
  customSurcharge3: d.customSurcharge3,
  customSurcharge4: d.customSurcharge4,
  customTaxes1: d.customTaxes1,
  customTaxes2: d.customTaxes2,
  customTaxes3: d.customTaxes3,
  customTaxes4: d.customTaxes4,
);

class _PdfPane extends StatelessWidget {
  const _PdfPane({required this.invoice});
  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    return BillingDocPdfView(
      entity: BillingDocType.invoice,
      entityNumber: invoice.number,
      fetcher: ({String? designId, required bool deliveryNote}) =>
          services.invoices.api.downloadPdf(
            entityJson: invoice.toApiJson(),
            designId:
                designId ??
                (invoice.designId.isEmpty ? null : invoice.designId),
            deliveryNote: deliveryNote,
          ),
    );
  }
}
