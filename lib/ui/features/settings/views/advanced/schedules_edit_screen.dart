import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/credit.dart';
import 'package:admin/data/models/domain/design.dart';
import 'package:admin/data/models/domain/enabled_modules.dart';
import 'package:admin/data/models/domain/expense_category.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/data/models/domain/product.dart';
import 'package:admin/data/models/domain/project.dart';
import 'package:admin/data/models/domain/purchase_order.dart';
import 'package:admin/data/models/domain/quote.dart';
import 'package:admin/data/models/domain/report_schedule_seed.dart';
import 'package:admin/data/models/domain/schedule.dart';
import 'package:admin/data/models/domain/schedule_constants.dart';
import 'package:admin/data/models/domain/vendor.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/domain/reports/report_filter_options.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/widgets/in_date_field.dart';
import 'package:admin/ui/core/widgets/multi_entity_picker.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';
import 'package:admin/ui/features/settings/view_models/schedule_edit_view_model.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/settings/widgets/settings_entity_edit_scaffold.dart';
import 'package:admin/ui/features/settings/widgets/settings_text_field.dart';
import 'package:admin/utils/formatting.dart';

/// `/settings/schedules/new` and `/settings/schedules/:id`.
///
/// Edit-or-create form for a single Schedule. The form is template-driven:
/// on create the user picks a template card; the body then reveals a
/// "Common" section (next_run / frequency / cycles / pause) plus a
/// per-template parameter section.
class SchedulesEditScreen extends StatelessWidget {
  const SchedulesEditScreen({
    this.existingId,
    this.starter,
    this.seed,
    super.key,
  });

  final String? existingId;

  /// `?starter=...` from the empty-state starter cards. Pre-fills the
  /// template + parameters when set on a fresh create.
  final String? starter;

  /// Passed via `context.go(..., extra:)` from the reports screen's
  /// "Schedule" launcher — pre-fills a fresh create as an `email_report`
  /// schedule with the current report's filters/columns. Same typed-`extra`
  /// prefill precedent as `PaymentLinkEditScreen.cloneFrom`.
  final ReportScheduleSeed? seed;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    final repo = services.schedules;

    return SettingsEntityEditScaffold<Schedule, ScheduleEditViewModel>(
      existingId: existingId,
      backRoute: '/settings/schedules',
      createTitleKey: 'new_schedule',
      editTitleKey: 'edit_schedule',
      wireName: 'schedule',
      watchById: (id) => repo.watch(companyId: companyId, id: id),
      refreshAll: () => repo.refreshAll(companyId: companyId),
      onArchive: (id) => repo.archive(companyId: companyId, id: id),
      onRestore: (id) => repo.restore(companyId: companyId, id: id),
      onDelete: (id) => repo.delete(companyId: companyId, id: id),
      vmFactory: ({existing}) {
        final vm = ScheduleEditViewModel(
          repo: repo,
          companyId: companyId,
          existing: existing,
          sync: services.sync,
          connectivity: services.connectivity,
        );
        // Prefill on fresh creates. A report seed (from the reports
        // "Schedule" launcher) wins over a starter card; they never
        // co-occur in practice. `updateDraft` mirrors how `_applyStarter`
        // mutates the VM post-construction.
        if (existing == null) {
          if (seed != null) {
            vm.applyReportSeed(seed!);
          } else if (starter != null) {
            _applyStarter(vm, starter!);
          }
        }
        return vm;
      },
      isArchivedOf: (s) => s.archivedAt != null,
      isDeletedOf: (s) => s.isDeleted,
      canSave: (vm) => vm.canSave,
      bodyBuilder: (context, vm) {
        // Card-picker landing step on a fresh create — only shown when no
        // template is selected yet.
        if (vm.isCreate && vm.draft.template.isEmpty) {
          return [_TemplatePickerLanding(vm: vm)];
        }
        return [
          _CommonFieldsSection(vm: vm),
          _TemplateParametersSection(vm: vm),
        ];
      },
    );
  }
}

void _applyStarter(ScheduleEditViewModel vm, String starter) {
  switch (starter) {
    case 'monthly_statement':
      vm.setTemplate(kScheduleTemplateEmailStatement);
      vm.setFrequencyId('5'); // monthly
      vm.setStatementStatus(kStatementStatusAll);
      vm.setShowAgingTable(true);
      break;
    case 'quarterly_pnl':
      vm.setTemplate(kScheduleTemplateEmailReport);
      vm.setFrequencyId('7'); // three months
      vm.setReportName('profitloss');
      vm.setReportSendEmail(true);
      break;
    case 'weekly_reminders':
      vm.setTemplate(kScheduleTemplateInvoiceOutstandingTasks);
      vm.setFrequencyId('2'); // weekly
      vm.setOutstandingTasksAutoSend(true);
      break;
  }
}

// ============== Card-picker landing step ===============

class _TemplatePickerLanding extends StatelessWidget {
  const _TemplatePickerLanding({required this.vm});

  final ScheduleEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    return FormSection(
      title: context.tr('pick_a_template'),
      children: [
        Text(
          context.tr('pick_a_template_hint'),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= Breakpoints.wide;
            final cols = wide ? 2 : 1;
            final gap = InSpacing.md(context);
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final t in kScheduleTemplates)
                  SizedBox(
                    width: (constraints.maxWidth - gap * (cols - 1)) / cols,
                    child: _TemplateCard(
                      templateKey: t,
                      onTap: () => vm.setTemplate(t),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.templateKey, required this.onTap});

  final String templateKey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(InRadii.r3),
      child: InkWell(
        borderRadius: BorderRadius.circular(InRadii.r3),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_iconFor(templateKey), color: theme.colorScheme.primary),
              const SizedBox(height: 10),
              Text(
                context.tr(templateKey),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.tr('${templateKey}_hint'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(String t) {
    switch (t) {
      case kScheduleTemplateEmailStatement:
        return Icons.receipt_long_outlined;
      case kScheduleTemplateEmailRecord:
        return Icons.mail_outline;
      case kScheduleTemplateEmailReport:
        return Icons.assessment_outlined;
      case kScheduleTemplateInvoiceOutstandingTasks:
        return Icons.timer_outlined;
      case kScheduleTemplatePaymentSchedule:
        return Icons.payments_outlined;
      default:
        return Icons.schedule_outlined;
    }
  }
}

// ============== Common fields (every template) ===============

class _CommonFieldsSection extends StatelessWidget {
  const _CommonFieldsSection({required this.vm});

  final ScheduleEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    final formatter = services.formatterIfReady(companyId);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return FormSection(
      title: context.tr('details'),
      children: [
        // payment_schedule + invoice_outstanding_tasks have their name set
        // server-side (StoreSchedulerRequest::prepareForValidation), so an
        // editable name field there would be silently overwritten — hide it.
        if (!_serverAutoNamesSchedule(vm.draft.template))
          SettingsTextField(
            initialValue: vm.draft.name,
            labelKey: 'name',
            onChanged: vm.setName,
            errorText: vm.fieldErrorFor('name'),
            externalSyncKey: vm.original?.id,
          ),
        _TemplateDisplayField(vm: vm),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(context.tr('pause_schedule')),
          subtitle: Text(
            context.tr('pause_schedule_hint'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          value: vm.draft.isPaused,
          onChanged: vm.setIsPaused,
        ),
        if (vm.draft.supportsNextRun)
          InDateField(
            value: vm.draft.nextRun?.toDateTime(),
            labelText: context.tr('next_run'),
            formatter: formatter,
            // The server rejects a past next_run (after_or_equal:today).
            firstDate: today,
            onChanged: (dt) {
              vm.setNextRun(
                dt == null ? null : Date(dt.year, dt.month, dt.day),
              );
            },
          ),
        if (vm.draft.supportsFrequency)
          DropdownButtonFormField<String>(
            initialValue: vm.draft.frequencyId.isEmpty
                ? null
                : vm.draft.frequencyId,
            decoration: InputDecoration(labelText: context.tr('frequency')),
            items: [
              for (final entry in kScheduleFrequencies.entries)
                DropdownMenuItem<String>(
                  value: entry.key,
                  child: Text(context.tr(entry.value)),
                ),
            ],
            onChanged: (v) => vm.setFrequencyId(v ?? ''),
          ),
        if (vm.draft.supportsRemainingCycles)
          DropdownButtonFormField<int>(
            initialValue: vm.draft.remainingCycles,
            decoration: InputDecoration(
              labelText: context.tr('remaining_cycles'),
            ),
            items: [
              DropdownMenuItem<int>(
                value: kScheduleRemainingCyclesEndless,
                child: Text(context.tr('endless')),
              ),
              for (var i = 0; i <= kScheduleRemainingCyclesMax; i++)
                DropdownMenuItem<int>(value: i, child: Text(i.toString())),
            ],
            onChanged: (v) =>
                vm.setRemainingCycles(v ?? kScheduleRemainingCyclesEndless),
          ),
      ],
    );
  }
}

/// Whether the server overwrites the schedule `name` for this template
/// (`StoreSchedulerRequest::prepareForValidation`). For those, the name
/// field is hidden so the user isn't editing a value that gets discarded.
bool _serverAutoNamesSchedule(String template) =>
    template == kScheduleTemplatePaymentSchedule ||
    template == kScheduleTemplateInvoiceOutstandingTasks;

/// Read-only chip showing the chosen template. Disabled because changing
/// it post-create would orphan all the parameter fields the user just
/// filled in.
class _TemplateDisplayField extends StatelessWidget {
  const _TemplateDisplayField({required this.vm});

  final ScheduleEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    if (vm.isCreate) {
      // Show the template name as a read-only label; switching back to
      // the picker is a one-button affordance.
      return InputDecorator(
        decoration: InputDecoration(labelText: context.tr('template')),
        child: Row(
          children: [
            Expanded(child: Text(context.tr(vm.draft.template))),
            TextButton(
              onPressed: () => _onChange(context),
              child: Text(context.tr('change')),
            ),
          ],
        ),
      );
    }
    // On edit: template is locked. Matches React (Edit.tsx disables it).
    return InputDecorator(
      decoration: InputDecoration(labelText: context.tr('template')),
      child: Text(context.tr(vm.draft.template)),
    );
  }

  Future<void> _onChange(BuildContext context) async {
    // Compare current parameters against the freshly-seeded defaults for
    // the same template. If they match, the user hasn't typed anything
    // template-specific — just swap. Otherwise prompt before discarding.
    final fresh = Schedule.empty().withTemplate(vm.draft.template).parameters;
    final current = vm.draft.parameters;
    final pristine =
        jsonEncode(_sortedMap(current)) == jsonEncode(_sortedMap(fresh));
    if (pristine) {
      vm.setTemplate('');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.tr('discard_changes_question')),
        content: Text(dialogContext.tr('discard_changes_warning')),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.tr('keep_editing')),
          ),
          PrimaryDialogAction(
            label: dialogContext.tr('discard'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      vm.setTemplate('');
    }
  }

  /// Stable-ordered map for `jsonEncode`-based deep equality.
  Map<String, dynamic> _sortedMap(Map<String, dynamic> input) {
    final keys = input.keys.toList()..sort();
    return {for (final k in keys) k: input[k]};
  }
}

// ============== Per-template parameter section ===============

class _TemplateParametersSection extends StatelessWidget {
  const _TemplateParametersSection({required this.vm});

  final ScheduleEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    switch (vm.draft.template) {
      case kScheduleTemplateEmailStatement:
        return _EmailStatementSection(vm: vm);
      case kScheduleTemplateEmailRecord:
        return _EmailRecordSection(vm: vm);
      case kScheduleTemplateEmailReport:
        return _EmailReportSection(vm: vm);
      case kScheduleTemplateInvoiceOutstandingTasks:
        return _InvoiceOutstandingTasksSection(vm: vm);
      case kScheduleTemplatePaymentSchedule:
        return _PaymentScheduleSection(vm: vm);
      default:
        return const SizedBox.shrink();
    }
  }
}

// ============== email_statement ===============

class _EmailStatementSection extends StatelessWidget {
  const _EmailStatementSection({required this.vm});

  final ScheduleEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    return FormSection(
      title: context.tr('email_statement'),
      children: [
        _dateRangeDropdown(
          context,
          value: vm.draft.statementDateRange,
          onChanged: vm.setStatementDateRange,
          options: kStatementDateRangeOptions,
        ),
        DropdownButtonFormField<String>(
          initialValue: vm.draft.statementStatus,
          decoration: InputDecoration(labelText: context.tr('status')),
          items: [
            for (final s in kStatementStatuses)
              DropdownMenuItem<String>(value: s, child: Text(context.tr(s))),
          ],
          onChanged: (v) => vm.setStatementStatus(v ?? kStatementStatusAll),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(context.tr('show_aging_table')),
          value: vm.draft.statementShowAgingTable,
          onChanged: vm.setShowAgingTable,
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(context.tr('show_payments_table')),
          value: vm.draft.statementShowPaymentsTable,
          onChanged: vm.setShowPaymentsTable,
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(context.tr('show_credits_table')),
          value: vm.draft.statementShowCreditsTable,
          onChanged: vm.setShowCreditsTable,
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(context.tr('only_clients_with_invoices')),
          value: vm.draft.statementOnlyClientsWithInvoices,
          onChanged: vm.setOnlyClientsWithInvoices,
        ),
        _ClientsField(
          ids: vm.draft.statementClients,
          onChanged: vm.setStatementClients,
        ),
      ],
    );
  }
}

// ============== email_record ===============

class _EmailRecordSection extends StatelessWidget {
  const _EmailRecordSection({required this.vm});

  final ScheduleEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    final templates =
        kEmailRecordTemplatesPerEntity[vm.draft.recordEntityType] ??
        const <String>[];
    final modules =
        context
            .read<Services>()
            .auth
            .session
            .value
            ?.currentCompany
            ?.enabledModules ??
        0;
    return FormSection(
      title: context.tr('email_record'),
      children: [
        DropdownButtonFormField<String>(
          initialValue: vm.draft.recordEntityType,
          decoration: InputDecoration(labelText: context.tr('type')),
          items: [
            // Keep the currently-selected type even if its module is off so
            // editing an existing schedule that targets it isn't broken.
            for (final t in kEmailRecordEntityTypes)
              if (t == vm.draft.recordEntityType ||
                  isWireModuleEnabledForCompany(t, modules))
                DropdownMenuItem<String>(value: t, child: Text(context.tr(t))),
          ],
          onChanged: (v) {
            if (v != null) vm.setRecordEntityType(v);
          },
        ),
        _RecordEntityField(vm: vm),
        DropdownButtonFormField<String>(
          initialValue: templates.contains(vm.draft.recordEmailTemplate)
              ? vm.draft.recordEmailTemplate
              : (templates.isNotEmpty ? templates.first : null),
          decoration: InputDecoration(labelText: context.tr('template')),
          items: [
            for (final t in templates)
              DropdownMenuItem<String>(value: t, child: Text(context.tr(t))),
          ],
          onChanged: (v) {
            if (v != null) vm.setRecordEmailTemplate(v);
          },
        ),
      ],
    );
  }
}

// ============== email_report ===============

class _EmailReportSection extends StatefulWidget {
  const _EmailReportSection({required this.vm});

  final ScheduleEditViewModel vm;

  @override
  State<_EmailReportSection> createState() => _EmailReportSectionState();
}

class _EmailReportSectionState extends State<_EmailReportSection> {
  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final reportName = vm.draft.reportName;
    final fields =
        kEmailReportFieldsByReport[reportName] ?? kDefaultEmailReportFields;
    final options = _reportOptions(context);

    return FormSection(
      title: context.tr('email_report'),
      children: [
        SearchableDropdownField<_ReportOption>(
          label: context.tr('report'),
          items: options,
          initialValue: options.firstWhere(
            (o) => o.id == reportName,
            orElse: () => options.first,
          ),
          displayString: (o) => o.display,
          idOf: (o) => o.id,
          onChanged: (o) {
            if (o != null) vm.setReportName(o.id);
          },
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final f in fields) ...[
                const SizedBox(height: 12),
                _buildReportField(context, vm, f),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReportField(
    BuildContext context,
    ScheduleEditViewModel vm,
    EmailReportField field,
  ) {
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    switch (field) {
      case EmailReportField.sendEmail:
        // React renders this disabled — a scheduled report always emails.
        return SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(context.tr('send_email')),
          value: vm.draft.reportSendEmail,
          onChanged: null,
        );
      case EmailReportField.dateRange:
        return _dateRangeDropdown(
          context,
          value: vm.draft.reportDateRange,
          onChanged: vm.setReportDateRange,
          options: kReportDateRangeOptions,
        );
      case EmailReportField.startDate:
        if (vm.draft.reportDateRange != 'custom') {
          return const SizedBox.shrink();
        }
        return InDateField(
          value: Date.tryParse(vm.draft.reportStartDate)?.toDateTime(),
          labelText: context.tr('start_date'),
          formatter: services.formatterIfReady(companyId),
          clearable: true,
          onChanged: (dt) => vm.setReportStartDate(
            dt == null ? '' : Date(dt.year, dt.month, dt.day).toIso(),
          ),
        );
      case EmailReportField.endDate:
        if (vm.draft.reportDateRange != 'custom') {
          return const SizedBox.shrink();
        }
        return InDateField(
          value: Date.tryParse(vm.draft.reportEndDate)?.toDateTime(),
          labelText: context.tr('end_date'),
          formatter: services.formatterIfReady(companyId),
          clearable: true,
          onChanged: (dt) => vm.setReportEndDate(
            dt == null ? '' : Date(dt.year, dt.month, dt.day).toIso(),
          ),
        );
      case EmailReportField.status:
        return _ReportStatusField(
          reportName: vm.draft.reportName,
          value: vm.draft.reportStatus,
          onChanged: vm.setReportStatus,
        );
      case EmailReportField.documentEmailAttachment:
        return SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(context.tr('document_email_attachment')),
          value: vm.draft.reportDocumentEmailAttachment,
          onChanged: vm.setReportDocumentEmailAttachment,
        );
      case EmailReportField.pdfEmailAttachment:
        return SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(context.tr('attach_pdf')),
          value: vm.draft.reportPdfEmailAttachment,
          onChanged: vm.setReportPdfEmailAttachment,
        );
      case EmailReportField.isExpenseBilled:
        return SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(context.tr('expense_paid_report')),
          value: vm.draft.reportIsExpenseBilled,
          onChanged: vm.setReportIsExpenseBilled,
        );
      case EmailReportField.isIncomeBilled:
        return SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(context.tr('cash_vs_accrual')),
          value: vm.draft.reportIsIncomeBilled,
          onChanged: vm.setReportIsIncomeBilled,
        );
      case EmailReportField.includeTax:
        return SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(context.tr('include_tax')),
          value: vm.draft.reportIncludeTax,
          onChanged: vm.setReportIncludeTax,
        );
      case EmailReportField.includeDeleted:
        return SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(context.tr('include_deleted')),
          value: vm.draft.reportIncludeDeleted,
          onChanged: vm.setReportIncludeDeleted,
        );
      case EmailReportField.productKey:
        return _RepoSinglePicker<Product>(
          labelKey: 'product',
          streamFactory: () => services.products.watchPage(
            companyId: companyId,
            loadedPages: 100,
          ),
          selectedId: vm.draft.reportProductKey,
          idOf: (p) => p.productKey,
          displayString: (p) => p.productKey.isEmpty ? p.id : p.productKey,
          onChanged: vm.setReportProductKey,
        );
      case EmailReportField.clientIdSingular:
        return _RepoSinglePicker<Client>(
          labelKey: 'client',
          streamFactory: () => services.clients.watchPage(
            companyId: companyId,
            loadedPages: 100,
          ),
          selectedId: vm.draft.reportClientId,
          idOf: (c) => c.id,
          displayString: _clientLabel,
          onChanged: vm.setReportClientId,
        );
      case EmailReportField.clients:
        return _ClientsField(
          ids: vm.draft.reportClients,
          onChanged: vm.setReportClients,
        );
      case EmailReportField.vendors:
        return _RepoMultiPicker<Vendor>(
          labelKey: 'vendors',
          streamFactory: () => services.vendors.watchPage(
            companyId: companyId,
            loadedPages: 100,
          ),
          selectedIds: vm.draft.reportVendors,
          idOf: (v) => v.id,
          displayString: (v) => v.name.isEmpty ? v.id : v.name,
          onChanged: vm.setReportVendorsCsv,
        );
      case EmailReportField.projects:
        return _RepoMultiPicker<Project>(
          labelKey: 'projects',
          streamFactory: () => services.projects.watchPage(
            companyId: companyId,
            loadedPages: 100,
          ),
          selectedIds: vm.draft.reportProjects,
          idOf: (p) => p.id,
          displayString: (p) => p.name.isEmpty ? p.id : p.name,
          onChanged: vm.setReportProjectsCsv,
        );
      case EmailReportField.categories:
        return _RepoMultiPicker<ExpenseCategory>(
          labelKey: 'categories',
          streamFactory: () => services.expenseCategories.watchPage(
            companyId: companyId,
            loadedPages: 100,
          ),
          selectedIds: vm.draft.reportCategories,
          idOf: (c) => c.id,
          displayString: (c) => c.name.isEmpty ? c.id : c.name,
          onChanged: vm.setReportCategoriesCsv,
        );
      case EmailReportField.templateId:
        return _RepoSinglePicker<Design>(
          labelKey: 'design',
          // Server requires a real template Design (is_template=true).
          streamFactory: () => services.designs
              .watchAll(companyId: companyId)
              .map((list) => list.where((d) => d.isTemplate).toList()),
          selectedId: vm.draft.reportTemplateId,
          idOf: (d) => d.id,
          displayString: (d) => d.name,
          onChanged: vm.setReportTemplateId,
        );
      case EmailReportField.groupBy:
      case EmailReportField.reportKeys:
        // group_by needs React's per-report column-map options (deferred);
        // report_keys has no UI in either client. Neither is currently
        // listed in any report's field set, so these never render.
        return const SizedBox.shrink();
    }
  }

  List<_ReportOption> _reportOptions(BuildContext context) {
    return [
      for (final r in kEmailReportReportNames)
        _ReportOption(
          id: r,
          display: '${context.tr(emailReportCategoryOf(r))} · ${context.tr(r)}',
        ),
    ];
  }
}

class _ReportOption {
  const _ReportOption({required this.id, required this.display});

  final String id;
  final String display;
}

// ============== invoice_outstanding_tasks ===============

class _InvoiceOutstandingTasksSection extends StatelessWidget {
  const _InvoiceOutstandingTasksSection({required this.vm});

  final ScheduleEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    return FormSection(
      title: context.tr('invoice_outstanding_tasks'),
      children: [
        _dateRangeDropdown(
          context,
          value: vm.draft.outstandingTasksDateRange,
          onChanged: (v) => vm._patchOutstandingDateRange(v),
          options: kStatementDateRangeOptions,
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(context.tr('auto_send')),
          subtitle: Text(
            context.tr('auto_send_help'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          value: vm.draft.outstandingTasksAutoSend,
          onChanged: vm.setOutstandingTasksAutoSend,
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(context.tr('include_project_tasks')),
          subtitle: Text(
            context.tr('include_project_tasks_help'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          value: vm.draft.outstandingTasksIncludeProjectTasks,
          onChanged: vm.setOutstandingTasksIncludeProjectTasks,
        ),
        _ClientsField(
          ids: vm.draft.outstandingTasksClients,
          onChanged: (ids) => vm._patchOutstandingClients(ids),
        ),
      ],
    );
  }
}

extension on ScheduleEditViewModel {
  // The outstanding-tasks template reuses the statement setters because
  // both write the same parameter keys (`date_range`, `clients`).
  void _patchOutstandingDateRange(String v) => setStatementDateRange(v);
  void _patchOutstandingClients(List<String> ids) => setStatementClients(ids);
}

// ============== payment_schedule ===============

class _PaymentScheduleSection extends StatefulWidget {
  const _PaymentScheduleSection({required this.vm});

  final ScheduleEditViewModel vm;

  @override
  State<_PaymentScheduleSection> createState() =>
      _PaymentScheduleSectionState();
}

class _PaymentScheduleSectionState extends State<_PaymentScheduleSection> {
  /// Mode preference for the next-added row when no rows exist yet. Once
  /// a row is in place, the displayed mode is read from `rows.first` and
  /// this field is unused — the toggle is locked until the user clears
  /// the rows back out.
  bool _pendingMode = true;

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    final rows = vm.draft.paymentScheduleRows;
    final isAmountMode = rows.isEmpty ? _pendingMode : rows.first.isAmount;
    final today = Date.today();

    return FormSection(
      title: context.tr('payment_schedule'),
      children: [
        // Lock invoice id on edit — matches React PaymentSchedule.tsx:389.
        // On create, a searchable invoice picker (the id is validated
        // server-side by InvoiceWithNoExistingSchedule, so a typed id 422s).
        if (vm.isCreate)
          _RepoSinglePicker<Invoice>(
            labelKey: 'invoice',
            streamFactory: () => services.invoices.watchPage(
              companyId: companyId,
              loadedPages: 100,
            ),
            selectedId: vm.draft.paymentScheduleInvoiceId,
            idOf: (i) => i.id,
            displayString: (i) => i.number.isEmpty ? i.id : i.number,
            onChanged: vm.setPaymentScheduleInvoiceId,
            errorText: vm.fieldErrorFor('invoice_id'),
          )
        else
          _InvoiceReadonlyField(invoiceId: vm.draft.paymentScheduleInvoiceId),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(context.tr('auto_bill')),
          subtitle: Text(
            context.tr('auto_bill_help'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          value: vm.draft.paymentScheduleAutoBill,
          onChanged: vm.setPaymentScheduleAutoBill,
        ),
        const SizedBox(height: 8),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(context.tr('amount_mode')),
          subtitle: Text(
            isAmountMode ? context.tr('amount') : context.tr('percent'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          value: isAmountMode,
          // Mode applies to row 0; subsequent rows inherit. Lock the
          // toggle once any row exists — flipping mode after rows are
          // populated would re-interpret each row's numeric amount
          // (e.g. "200.00 USD" becomes "200%" — way over 100%). Mirrors
          // React's AddScheduleModal.tsx:260 (mode toggle only on row 0).
          // To change mode, the user clears the rows back out and the
          // toggle re-enables.
          onChanged: rows.isEmpty
              ? (v) => setState(() => _pendingMode = v)
              : null,
        ),
        const SizedBox(height: 8),
        if (rows.isEmpty)
          Text(
            context.tr('no_payment_schedule_rows_hint'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < rows.length; i++)
                _PaymentScheduleRowTile(
                  key: ValueKey(rows[i].id),
                  index: i,
                  row: rows[i],
                  isAmountMode: isAmountMode,
                  isPast: rows[i].date.compareTo(today) < 0,
                  // Existing schedules: rows are immutable server-side on update.
                  readOnly: !vm.isCreate,
                  onChanged: (updated) {
                    final next = List<ScheduleParamsRow>.from(rows);
                    next[i] = updated;
                    vm.setPaymentScheduleRows(next);
                  },
                  onRemove: () {
                    final next = List<ScheduleParamsRow>.from(rows)
                      ..removeAt(i);
                    vm.setPaymentScheduleRows(next);
                  },
                ),
            ],
          ),
        if (rows.isNotEmpty) ...[
          const SizedBox(height: 8),
          _PaymentRemainingHint(
            invoiceId: vm.draft.paymentScheduleInvoiceId,
            rows: rows,
            isAmountMode: isAmountMode,
          ),
        ],
        const SizedBox(height: 8),
        // Add-row only on CREATE — the server ignores schedule row changes on
        // update (see readOnly above), so an Add here would silently do nothing.
        if (vm.isCreate)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
            icon: const Icon(Icons.add),
            label: Text(context.tr('add_row')),
            onPressed: () {
              final nextId = (rows.isEmpty ? 0 : rows.last.id) + 1;
              // Default new-row date: row 0 today, otherwise one day after
              // the last row's date so the strict-ordering rule is satisfied
              // out of the box.
              // Date.addDays is UTC date-space — a local-midnight + Duration on a
              // fall-back DST day stays on the same calendar day, seeding a
              // duplicate date that the strict-ordering save-gate then rejects
              // (L3).
              final base = rows.isEmpty ? today : rows.last.date.addDays(1);
              final next = List<ScheduleParamsRow>.from(rows)
                ..add(
                  ScheduleParamsRow(
                    id: nextId,
                    date: base,
                    amount: Decimal.zero,
                    isAmount: isAmountMode,
                  ),
                );
              vm.setPaymentScheduleRows(next);
            },
          ),
      ],
    );
  }
}

class _PaymentScheduleRowTile extends StatefulWidget {
  const _PaymentScheduleRowTile({
    required this.index,
    required this.row,
    required this.isAmountMode,
    required this.isPast,
    required this.onChanged,
    required this.onRemove,
    this.readOnly = false,
    super.key,
  });

  final int index;
  final ScheduleParamsRow row;
  final bool isAmountMode;
  final bool isPast;

  /// When true (editing an EXISTING schedule) the row is uneditable — the
  /// server's UpdateSchedulerRequest discards any `parameters.schedule` change
  /// for a payment_schedule template, so editing would silently do nothing.
  final bool readOnly;
  final ValueChanged<ScheduleParamsRow> onChanged;
  final VoidCallback onRemove;

  @override
  State<_PaymentScheduleRowTile> createState() =>
      _PaymentScheduleRowTileState();
}

class _PaymentScheduleRowTileState extends State<_PaymentScheduleRowTile> {
  late final TextEditingController _amountController;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: _displayAmount(widget.row));
  }

  @override
  void didUpdateWidget(covariant _PaymentScheduleRowTile old) {
    super.didUpdateWidget(old);
    // Re-seed when the row's amount or mode changes externally (e.g. the
    // section clears amounts on mode flip in a future fix). Skip when the
    // text already matches what the user is typing.
    final next = _displayAmount(widget.row);
    if (next != _amountController.text &&
        (widget.row.amount != old.row.amount ||
            widget.row.isAmount != old.row.isAmount)) {
      _amountController.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      );
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  static String _displayAmount(ScheduleParamsRow row) =>
      row.amount == Decimal.zero ? '' : row.amount.toString();

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    // Fold readOnly into the same lock isPast already uses (disabled inputs +
    // no remove + dimmed) so editing an existing schedule's rows is inert.
    final isPast = widget.isPast || widget.readOnly;
    return Opacity(
      opacity: isPast ? 0.6 : 1.0,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: InDateField(
                value: row.date.toDateTime(),
                labelText: context.tr('date'),
                enabled: !isPast,
                onChanged: (d) {
                  if (d == null) return;
                  widget.onChanged(
                    row.copyWith(date: Date(d.year, d.month, d.day)),
                  );
                },
              ),
            ),
            SizedBox(width: InSpacing.md(context)),
            Expanded(
              flex: 2,
              child: TextField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: widget.isAmountMode
                      ? context.tr('amount')
                      : context.tr('percent'),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,-]')),
                ],
                enabled: !isPast,
                onChanged: (v) {
                  final services = context.read<Services>();
                  final companyId =
                      services.auth.session.value?.currentCompanyId ?? '';
                  final useComma =
                      services
                          .formatterIfReady(companyId)
                          ?.settings
                          .useCommaAsDecimalPlace ??
                      false;
                  final parsed =
                      parseDecimal(v, useCommaAsDecimalPlace: useComma) ??
                      Decimal.zero;
                  widget.onChanged(row.copyWith(amount: parsed));
                },
              ),
            ),
            const SizedBox(width: InSpacing.xs),
            IconButton(
              onPressed: isPast ? null : widget.onRemove,
              icon: const Icon(Icons.remove_circle_outline),
              tooltip: context.tr('remove'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============== shared helpers ===============

Widget _dateRangeDropdown(
  BuildContext context, {
  required String value,
  required ValueChanged<String> onChanged,
  required List<String> options,
}) {
  return DropdownButtonFormField<String>(
    initialValue: options.contains(value) ? value : null,
    decoration: InputDecoration(labelText: context.tr('date_range')),
    items: [
      for (final o in options)
        DropdownMenuItem<String>(value: o, child: Text(context.tr(o))),
    ],
    onChanged: (v) {
      if (v != null) onChanged(v);
    },
  );
}

String _clientLabel(Client c) => c.displayName.isEmpty ? c.name : c.displayName;

/// Single-entity reference picker backed by a watched repo list. Resolves
/// the current id against the loaded page and shows the entity's
/// name/number instead of the raw hashed id; the server validates the id on
/// save. Loads one page + filters client-side — same trade-off as the
/// payment-edit invoice picker.
///
/// The watch is memoized (resolved once) — the VM-backed edit scaffold
/// rebuilds this whole subtree on every field edit, and an inline stream
/// would cancel + resubscribe (flicker to "loading" + re-query) per
/// keystroke. Mirrors `payment_edit_layout.dart`'s `_resolveStream`.
class _RepoSinglePicker<T extends Object> extends StatefulWidget {
  const _RepoSinglePicker({
    required this.labelKey,
    required this.streamFactory,
    required this.selectedId,
    required this.idOf,
    required this.displayString,
    required this.onChanged,
    this.errorText,
  });

  final String labelKey;
  final Stream<List<T>> Function() streamFactory;
  final String selectedId;
  final String Function(T) idOf;
  final String Function(T) displayString;
  final ValueChanged<String> onChanged;
  final String? errorText;

  @override
  State<_RepoSinglePicker<T>> createState() => _RepoSinglePickerState<T>();
}

class _RepoSinglePickerState<T extends Object>
    extends State<_RepoSinglePicker<T>> {
  Stream<List<T>>? _stream;

  @override
  Widget build(BuildContext context) {
    final stream = _stream ??= widget.streamFactory();
    return StreamBuilder<List<T>>(
      stream: stream,
      builder: (context, snapshot) {
        final items = snapshot.data ?? const [];
        T? selected;
        for (final it in items) {
          if (widget.idOf(it) == widget.selectedId) {
            selected = it;
            break;
          }
        }
        return SearchableDropdownField<T>(
          label: context.tr(widget.labelKey),
          items: items,
          initialValue: selected,
          displayString: widget.displayString,
          idOf: widget.idOf,
          onChanged: (it) =>
              widget.onChanged(it == null ? '' : widget.idOf(it)),
          errorText: widget.errorText,
        );
      },
    );
  }
}

/// Multi-entity reference picker backed by a watched repo list. Memoizes the
/// watch for the same reason as [_RepoSinglePicker].
class _RepoMultiPicker<T extends Object> extends StatefulWidget {
  const _RepoMultiPicker({
    required this.labelKey,
    required this.streamFactory,
    required this.selectedIds,
    required this.idOf,
    required this.displayString,
    required this.onChanged,
  });

  final String labelKey;
  final Stream<List<T>> Function() streamFactory;
  final List<String> selectedIds;
  final String Function(T) idOf;
  final String Function(T) displayString;
  final ValueChanged<List<String>> onChanged;

  @override
  State<_RepoMultiPicker<T>> createState() => _RepoMultiPickerState<T>();
}

class _RepoMultiPickerState<T extends Object>
    extends State<_RepoMultiPicker<T>> {
  Stream<List<T>>? _stream;

  @override
  Widget build(BuildContext context) {
    final stream = _stream ??= widget.streamFactory();
    return StreamBuilder<List<T>>(
      stream: stream,
      builder: (context, snapshot) {
        final items = snapshot.data ?? const [];
        return MultiEntityPicker<T>(
          labelKey: widget.labelKey,
          selectedIds: widget.selectedIds,
          items: items,
          idOf: widget.idOf,
          displayString: widget.displayString,
          onChanged: widget.onChanged,
        );
      },
    );
  }
}

/// Multi-client picker — statement / outstanding-tasks / report `clients`
/// filters. Empty selection = "all clients".
class _ClientsField extends StatelessWidget {
  const _ClientsField({required this.ids, required this.onChanged});

  final List<String> ids;
  final ValueChanged<List<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    return _RepoMultiPicker<Client>(
      labelKey: 'clients',
      streamFactory: () =>
          services.clients.watchPage(companyId: companyId, loadedPages: 100),
      selectedIds: ids,
      idOf: (c) => c.id,
      displayString: _clientLabel,
      onChanged: onChanged,
    );
  }
}

/// email_record entity picker — the repo + display switch on the chosen
/// entity type (invoice / quote / credit / purchase_order).
class _RecordEntityField extends StatelessWidget {
  const _RecordEntityField({required this.vm});

  final ScheduleEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    final selectedId = vm.draft.recordEntityId;
    final error = vm.fieldErrorFor('entity_id');
    switch (vm.draft.recordEntityType) {
      case 'quote':
        return _RepoSinglePicker<Quote>(
          labelKey: 'quote',
          streamFactory: () =>
              services.quotes.watchPage(companyId: companyId, loadedPages: 100),
          selectedId: selectedId,
          idOf: (q) => q.id,
          displayString: (q) => q.number.isEmpty ? q.id : q.number,
          onChanged: vm.setRecordEntityId,
          errorText: error,
        );
      case 'credit':
        return _RepoSinglePicker<Credit>(
          labelKey: 'credit',
          streamFactory: () => services.credits.watchPage(
            companyId: companyId,
            loadedPages: 100,
          ),
          selectedId: selectedId,
          idOf: (c) => c.id,
          displayString: (c) => c.number.isEmpty ? c.id : c.number,
          onChanged: vm.setRecordEntityId,
          errorText: error,
        );
      case 'purchase_order':
        return _RepoSinglePicker<PurchaseOrder>(
          labelKey: 'purchase_order',
          streamFactory: () => services.purchaseOrders.watchPage(
            companyId: companyId,
            loadedPages: 100,
          ),
          selectedId: selectedId,
          idOf: (p) => p.id,
          displayString: (p) => p.number.isEmpty ? p.id : p.number,
          onChanged: vm.setRecordEntityId,
          errorText: error,
        );
      case 'invoice':
      default:
        return _RepoSinglePicker<Invoice>(
          labelKey: 'invoice',
          streamFactory: () => services.invoices.watchPage(
            companyId: companyId,
            loadedPages: 100,
          ),
          selectedId: selectedId,
          idOf: (i) => i.id,
          displayString: (i) => i.number.isEmpty ? i.id : i.number,
          onChanged: vm.setRecordEntityId,
          errorText: error,
        );
    }
  }
}

/// Read-only invoice label (payment_schedule on edit — the invoice can't be
/// changed). Resolves the id to the invoice number once loaded. The watch is
/// memoized so the surrounding rebuild-on-every-edit subtree doesn't churn it.
class _InvoiceReadonlyField extends StatefulWidget {
  const _InvoiceReadonlyField({required this.invoiceId});

  final String invoiceId;

  @override
  State<_InvoiceReadonlyField> createState() => _InvoiceReadonlyFieldState();
}

class _InvoiceReadonlyFieldState extends State<_InvoiceReadonlyField> {
  Stream<List<Invoice>>? _stream;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    final theme = Theme.of(context);
    final stream = _stream ??= services.invoices.watchPage(
      companyId: companyId,
      loadedPages: 100,
    );
    return StreamBuilder<List<Invoice>>(
      stream: stream,
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <Invoice>[];
        var label = widget.invoiceId;
        for (final i in items) {
          if (i.id == widget.invoiceId && i.number.isNotEmpty) {
            label = i.number;
            break;
          }
        }
        return InputDecorator(
          decoration: InputDecoration(
            labelText: context.tr('invoice'),
            enabled: false,
          ),
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        );
      },
    );
  }
}

/// Report `status` filter — a report-aware multiselect of chips when the
/// report has a known status set ([reportStatusOptions]), a free-text field
/// otherwise. Emits the CSV the server expects.
class _ReportStatusField extends StatelessWidget {
  const _ReportStatusField({
    required this.reportName,
    required this.value,
    required this.onChanged,
  });

  final String reportName;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = reportStatusOptions(reportName);
    if (options == null) {
      return SettingsTextField(
        initialValue: value,
        labelKey: 'status',
        onChanged: onChanged,
        externalSyncKey: reportName,
      );
    }
    final theme = Theme.of(context);
    final tokens = context.inTheme;
    final selected = value
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('status'),
          style: theme.textTheme.labelMedium?.copyWith(color: tokens.ink3),
        ),
        SizedBox(height: InSpacing.sm),
        Wrap(
          spacing: InSpacing.sm,
          runSpacing: InSpacing.sm,
          children: [
            for (final o in options)
              FilterChip(
                label: Text(context.tr(o.labelKey)),
                selected: selected.contains(o.id),
                onSelected: (isOn) {
                  final next = {...selected};
                  if (isOn) {
                    next.add(o.id);
                  } else {
                    next.remove(o.id);
                  }
                  // Keep the canonical option order in the emitted CSV.
                  onChanged(
                    options
                        .where((x) => next.contains(x.id))
                        .map((x) => x.id)
                        .join(','),
                  );
                },
              ),
          ],
        ),
      ],
    );
  }
}

/// Non-blocking "remaining" hint for the payment schedule. Percent mode:
/// 100 − Σ%. Amount mode: invoice total − Σ amount (when the invoice is
/// loaded). The server doesn't enforce the sum, so this is guidance only.
class _PaymentRemainingHint extends StatefulWidget {
  const _PaymentRemainingHint({
    required this.invoiceId,
    required this.rows,
    required this.isAmountMode,
  });

  final String invoiceId;
  final List<ScheduleParamsRow> rows;
  final bool isAmountMode;

  @override
  State<_PaymentRemainingHint> createState() => _PaymentRemainingHintState();
}

class _PaymentRemainingHintState extends State<_PaymentRemainingHint> {
  Stream<List<Invoice>>? _stream;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.inTheme;
    final allocated = widget.rows.fold<Decimal>(
      Decimal.zero,
      (sum, r) => sum + r.amount,
    );

    Widget hint(String text, {bool over = false}) => Text(
      text,
      style: theme.textTheme.bodySmall?.copyWith(
        color: over ? theme.colorScheme.error : tokens.ink3,
      ),
    );

    if (!widget.isAmountMode) {
      final remaining = Decimal.fromInt(100) - allocated;
      return hint(
        '$remaining% ${context.tr('remaining')}',
        over: remaining < Decimal.zero,
      );
    }

    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    final stream = _stream ??= services.invoices.watchPage(
      companyId: companyId,
      loadedPages: 100,
    );
    return StreamBuilder<List<Invoice>>(
      stream: stream,
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <Invoice>[];
        Invoice? invoice;
        for (final i in items) {
          if (i.id == widget.invoiceId) {
            invoice = i;
            break;
          }
        }
        if (invoice == null) return const SizedBox.shrink();
        final remaining = invoice.amount - allocated;
        return hint(
          '$remaining ${context.tr('remaining')}',
          over: remaining < Decimal.zero,
        );
      },
    );
  }
}
