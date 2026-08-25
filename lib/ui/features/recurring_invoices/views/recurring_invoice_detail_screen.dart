import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/ui/core/widgets/entity_tags_view.dart';
import 'package:admin/ui/core/widgets/client_name_label.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/recurring_invoice.dart';
import 'package:admin/data/models/domain/recurring_schedule_date.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/core/widgets/error_view.dart';
import 'package:admin/utils/formatting.dart';
import 'package:admin/domain/recurring_frequency.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/detail/custom_fields_detail_card.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/detail/entity_detail_scaffold.dart';
import 'package:admin/ui/core/detail/entity_detail_tabs.dart';
import 'package:admin/ui/core/detail/recent_visit_recorder.dart';
import 'package:admin/domain/date_placeholders.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/core/detail/entity_documents_tab.dart';
import 'package:admin/ui/core/widgets/formatter_host_mixin.dart';
import 'package:admin/ui/features/billing_shared/activity/billing_doc_activity_tab.dart';
import 'package:admin/ui/features/billing_shared/sends/billing_doc_sends_tab.dart';
import 'package:admin/ui/features/billing_shared/billing_doc_type.dart';
import 'package:admin/ui/features/billing_shared/pdf/billing_doc_pdf_view.dart';
import 'package:admin/ui/features/recurring_invoices/view_models/recurring_invoice_detail_view_model.dart';
import 'package:admin/ui/features/recurring_invoices/widgets/recurring_invoice_actions.dart';
import 'package:admin/ui/features/recurring_invoices/widgets/recurring_invoice_status_pill.dart';

class RecurringInvoiceDetailScreen extends StatefulWidget {
  const RecurringInvoiceDetailScreen({required this.id, super.key});
  final String id;

  @override
  State<RecurringInvoiceDetailScreen> createState() =>
      _RecurringInvoiceDetailScreenState();
}

class _RecurringInvoiceDetailScreenState
    extends State<RecurringInvoiceDetailScreen>
    with FormatterHostMixin {
  late final RecurringInvoiceDetailViewModel _vm;
  late final Services _services;
  late final String _companyId;

  @override
  void initState() {
    super.initState();
    _services = context.read<Services>();
    _companyId = _services.auth.session.value!.currentCompanyId;
    _vm = RecurringInvoiceDetailViewModel.bound(
      _services.recurringInvoices.watch(companyId: _companyId, id: widget.id),
    );
    // Hydrate on a cache miss (dashboard tap) so the detail resolves
    // instead of showing "not found".
    _services.recurringInvoices.ensureLoaded(
      companyId: _companyId,
      id: widget.id,
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
    return EntityDetailScaffold<RecurringInvoice>(
      vm: _vm,
      emptyIcon: Icons.event_repeat_outlined,
      emptyTitle: context.tr('recurring_invoice_not_found'),
      actionsForItem: (context, ri) =>
          EntityDetailActionsRow<RecurringInvoiceAction>(
            items: RecurringInvoiceActions.itemsFor(
              context,
              ri,
              (a) => RecurringInvoiceActions.dispatch(
                context,
                _services,
                _companyId,
                ri,
                a,
              ),
            ),
          ),
      bodyBuilder: (context, ri) => _Body(
        recurringInvoice: ri,
        services: _services,
        companyId: _companyId,
        formatter: formatter,
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.recurringInvoice,
    required this.services,
    required this.companyId,
    required this.formatter,
  });

  final RecurringInvoice recurringInvoice;
  final Services services;
  final String companyId;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide =
            Breakpoints.isWide(constraints) && constraints.maxWidth >= 900;
        final main = SingleChildScrollView(
          padding: EdgeInsets.all(InSpacing.lg(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RecentVisitRecorder(
                type: EntityType.recurringInvoice,
                id: recurringInvoice.id,
                label: recurringInvoice.number.isEmpty
                    ? context.tr('recurring_invoice')
                    : '#${recurringInvoice.number}',
                child: _Header(
                  recurringInvoice: recurringInvoice,
                  services: services,
                  companyId: companyId,
                  formatter: formatter,
                ),
              ),
              SizedBox(height: InSpacing.lg(context)),
              EntityDetailTabs(
                tabs: [
                  EntityDetailTab(
                    label: context.tr('overview'),
                    icon: Icons.dashboard_outlined,
                    bodyBuilder: (_) => Padding(
                      padding: EdgeInsets.all(InSpacing.lg(context)),
                      child: _Overview(
                        recurringInvoice: recurringInvoice,
                        companyId: companyId,
                        formatter: formatter,
                      ),
                    ),
                  ),
                  EntityDetailTab(
                    label: context.tr('schedule'),
                    icon: Icons.calendar_month_outlined,
                    bodyBuilder: (_) => _ScheduleTab(
                      recurringInvoiceId: recurringInvoice.id,
                      services: services,
                      formatter: formatter,
                    ),
                  ),
                  EntityDetailTab(
                    label: recurringInvoice.documents.isEmpty
                        ? context.tr('documents')
                        : context.tr('documents_with_count', {
                            'count': '${recurringInvoice.documents.length}',
                          }),
                    icon: Icons.description_outlined,
                    bodyBuilder: (_) => EntityDocumentsTab(
                      entityId: recurringInvoice.id,
                      documents: recurringInvoice.documents,
                      onUpload: (sources) async {
                        for (final s in sources) {
                          await services.recurringInvoices.uploadDocument(
                            companyId: companyId,
                            entityId: recurringInvoice.id,
                            source: s,
                          );
                        }
                      },
                      onDelete: (doc) async {
                        await services.recurringInvoices.deleteDocument(
                          companyId: companyId,
                          entityId: recurringInvoice.id,
                          documentId: doc.id,
                        );
                      },
                      onToggleVisibility: (doc) async {
                        await services.recurringInvoices.setDocumentVisibility(
                          companyId: companyId,
                          entityId: recurringInvoice.id,
                          documentId: doc.id,
                          isPublic: !doc.isPublic,
                        );
                      },
                    ),
                  ),
                  EntityDetailTab(
                    label: context.tr('activity'),
                    icon: Icons.history_outlined,
                    bodyBuilder: (_) => BillingDocActivityTab(
                      entityWireName: 'recurring_invoice',
                      entityId: recurringInvoice.id,
                      companyId: companyId,
                      activitiesApi: services.activities,
                      outboxDao: services.db.outboxDao,
                    ),
                  ),
                  EntityDetailTab(
                    label: context.tr('email_history'),
                    icon: Icons.outgoing_mail,
                    bodyBuilder: (_) => BillingDocSendsTab(
                      services: services,
                      companyId: companyId,
                      entityWireName: 'recurring_invoice',
                      entityId: recurringInvoice.id,
                      invitations: recurringInvoice.invitations,
                      clientId: recurringInvoice.clientId,
                      isHosted: services.auth.session.value?.isHosted ?? false,
                      onReactivate: (messageId) =>
                          services.recurringInvoices.reactivateInvitationEmail(
                            companyId: companyId,
                            id: recurringInvoice.id,
                            messageId: messageId,
                          ),
                    ),
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
            Expanded(
              flex: 6,
              child: _PdfPane(recurringInvoice: recurringInvoice),
            ),
          ],
        );
      },
    );
  }
}

/// Read-only "Schedule" tab: the server-computed upcoming send + due dates
/// (`GET ?show_dates=true`). Fetched on demand — not part of the synced
/// entity — and rendered through the company [Formatter] so dates honor the
/// configured format. Mirrors React's Schedule tab.
class _ScheduleTab extends StatefulWidget {
  const _ScheduleTab({
    required this.recurringInvoiceId,
    required this.services,
    required this.formatter,
  });

  final String recurringInvoiceId;
  final Services services;
  final Formatter? formatter;

  @override
  State<_ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<_ScheduleTab> {
  late Future<List<RecurringScheduleDate>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<RecurringScheduleDate>> _load() => widget
      .services
      .recurringInvoices
      .api
      .fetchSchedule(id: widget.recurringInvoiceId);

  // Never render a raw ISO string — fall back to a placeholder until the
  // formatter is ready (see the Formatter rule in CLAUDE.md).
  String _fmt(Date? d) =>
      d == null ? '—' : (widget.formatter?.date(d.toIso()) ?? '—');

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return FutureBuilder<List<RecurringScheduleDate>>(
      future: _future,
      builder: (context, snap) {
        Widget pad(Widget child) => Padding(
          padding: EdgeInsets.all(InSpacing.lg(context)),
          child: child,
        );

        if (snap.connectionState == ConnectionState.waiting) {
          return pad(const Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError) {
          return pad(
            ErrorView(
              message: context.tr('an_error_occurred'),
              onRetry: () => setState(() => _future = _load()),
            ),
          );
        }
        final rows = snap.data ?? const <RecurringScheduleDate>[];
        if (rows.isEmpty) {
          return pad(
            EmptyState(
              icon: Icons.calendar_month_outlined,
              title: context.tr('no_records_found'),
            ),
          );
        }

        TextStyle headStyle() => TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: tokens.ink3,
        );
        Widget cell(String text, {bool head = false}) => Expanded(
          child: Text(
            text,
            style: head ? headStyle() : TextStyle(color: tokens.ink),
          ),
        );
        Widget row(Widget a, Widget b) => Padding(
          padding: EdgeInsets.symmetric(
            horizontal: InSpacing.lg(context),
            vertical: InSpacing.md(context),
          ),
          child: Row(
            children: [
              a,
              SizedBox(width: InSpacing.md(context)),
              b,
            ],
          ),
        );

        return pad(
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: tokens.border),
              borderRadius: BorderRadius.circular(InRadii.r3),
              color: tokens.surface,
            ),
            child: Column(
              children: [
                row(
                  cell(context.tr('send_date'), head: true),
                  cell(context.tr('due_date'), head: true),
                ),
                for (final r in rows) ...[
                  Divider(height: 1, color: tokens.border),
                  row(cell(_fmt(r.sendDate)), cell(_fmt(r.dueDate))),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.recurringInvoice,
    required this.services,
    required this.companyId,
    required this.formatter,
  });
  final RecurringInvoice recurringInvoice;
  final Services services;
  final String companyId;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
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
          Row(
            children: [
              Text(
                recurringInvoice.number.isEmpty
                    ? '—'
                    : '#${recurringInvoice.number}',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: tokens.ink,
                ),
              ),
              const SizedBox(width: 12),
              RecurringInvoiceStatusPill(
                statusId: recurringInvoice.calculatedStatusId,
                hasBounce: recurringInvoice.hasBouncedInvitation,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClientNameLabel(
            clientId: recurringInvoice.clientId,
            link: true,
            style: TextStyle(color: tokens.ink3),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              StreamBuilder<Client?>(
                stream: services.clients.watch(
                  companyId: companyId,
                  id: recurringInvoice.clientId,
                ),
                builder: (context, clientSnap) => _LabelValue(
                  label: context.tr('amount'),
                  mono: true,
                  value:
                      formatter?.money(
                        recurringInvoice.amount,
                        clientCurrencyId: clientSnap.data?.currencyId,
                      ) ??
                      // Never show a raw Decimal — placeholder until the
                      // company formatter has loaded.
                      '—',
                ),
              ),
              if (recurringInvoice.frequencyId.isNotEmpty)
                _LabelValue(
                  label: context.tr('frequency'),
                  value: _frequencyLabel(context, recurringInvoice.frequencyId),
                ),
              if (recurringInvoice.nextSendDate != null)
                _LabelValue(
                  label: context.tr('next_send_date'),
                  value:
                      formatter?.date(recurringInvoice.nextSendDate!.toIso()) ??
                      // Never show a raw ISO date — placeholder until ready.
                      '—',
                ),
              _LabelValue(
                label: context.tr('remaining_cycles'),
                value: recurringInvoice.remainingCycles < 0
                    ? context.tr('endless')
                    : '${recurringInvoice.remainingCycles}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({
    required this.recurringInvoice,
    required this.companyId,
    this.formatter,
  });
  final RecurringInvoice recurringInvoice;
  final String companyId;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final hasCustomFields =
        recurringInvoice.customValue1.isNotEmpty ||
        recurringInvoice.customValue2.isNotEmpty ||
        recurringInvoice.customValue3.isNotEmpty ||
        recurringInvoice.customValue4.isNotEmpty;
    final hasNotes = recurringInvoice.publicNotes.isNotEmpty;
    final hasTerms = recurringInvoice.terms.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (recurringInvoice.tagIds.isNotEmpty) ...[
          Text(
            context.tr('tags'),
            style: TextStyle(
              fontSize: 12,
              color: tokens.ink3,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          EntityTagsView(
            entityType: 'recurring_invoice',
            tagIds: recurringInvoice.tagIds,
          ),
          if (hasNotes || hasTerms || hasCustomFields)
            SizedBox(height: InSpacing.md(context)),
        ],
        if (hasNotes) ...[
          Text(
            context.tr('public_notes'),
            style: TextStyle(
              fontSize: 12,
              color: tokens.ink3,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          // A recurring template keeps its raw keywords forever — the server
          // re-expands them per generated invoice, anchored to `next_send_date`
          // (`RecurringInvoiceToInvoiceFactory.php:148-169`). Rendering today's
          // dates here previews what the next run will say
          // (invoiceninja/flutter#93).
          Text(
            expandDatePlaceholders(
              recurringInvoice.publicNotes,
              formatter: formatter,
            ),
            style: TextStyle(color: tokens.ink),
          ),
        ],
        if (hasTerms) ...[
          if (hasNotes) SizedBox(height: InSpacing.md(context)),
          Text(
            context.tr('terms'),
            style: TextStyle(
              fontSize: 12,
              color: tokens.ink3,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            expandDatePlaceholders(
              recurringInvoice.terms,
              formatter: formatter,
            ),
            style: TextStyle(color: tokens.ink),
          ),
        ],
        // Reuses the `invoice` custom-field config slots (no separate
        // recurring-invoice keys exist server-side).
        if (hasCustomFields) ...[
          if (hasNotes || hasTerms) SizedBox(height: InSpacing.md(context)),
          CustomFieldsDetailCard(
            companyId: companyId,
            prefix: 'invoice',
            values: [
              recurringInvoice.customValue1,
              recurringInvoice.customValue2,
              recurringInvoice.customValue3,
              recurringInvoice.customValue4,
            ],
            formatter: formatter,
          ),
        ],
      ],
    );
  }
}

class _PdfPane extends StatelessWidget {
  const _PdfPane({required this.recurringInvoice});
  final RecurringInvoice recurringInvoice;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    return BillingDocPdfView(
      entity: BillingDocType.recurringInvoice,
      entityNumber: recurringInvoice.number,
      fetcher: ({String? designId, required bool deliveryNote}) =>
          services.recurringInvoices.api.downloadPdf(
            entityJson: recurringInvoice.toApiJson(),
            designId:
                designId ??
                (recurringInvoice.designId.isEmpty
                    ? null
                    : recurringInvoice.designId),
          ),
    );
  }
}

/// Localized recurring-frequency label, falling back to the raw id for
/// an unknown code. Mirrors `recurring_expense_detail_kpi_strip`.
String _frequencyLabel(BuildContext context, String id) {
  final key = kRecurringFrequencyLabelKey[id];
  return key == null ? id : context.tr(key);
}

class _LabelValue extends StatelessWidget {
  const _LabelValue({
    required this.label,
    required this.value,
    this.mono = false,
  });
  final String label;
  final String value;

  /// Render the value in the mono money typeface. The amount field sets this;
  /// frequency / next-send-date / remaining-cycles keep the sans UI font.
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: tokens.ink3)),
        const SizedBox(height: 2),
        Text(
          value,
          style: mono
              ? moneyTextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: tokens.ink,
                )
              : TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: tokens.ink,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
        ),
      ],
    );
  }
}
