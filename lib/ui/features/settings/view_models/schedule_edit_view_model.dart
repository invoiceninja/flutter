import 'package:decimal/decimal.dart';

import 'package:admin/data/models/domain/report_schedule_seed.dart';
import 'package:admin/data/models/domain/schedule.dart';
import 'package:admin/data/models/domain/schedule_constants.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/schedule_repository.dart';
import 'package:admin/domain/reports/report_schedule.dart';
import 'package:admin/ui/core/edit/generic_edit_view_model.dart';

/// Drives the `/settings/schedules/new` + `/:id` edit screen. The draft's
/// `parameters` map carries the template-specific config; the per-template
/// setter helpers narrow the stringy map to typed call sites for the
/// edit screen.
class ScheduleEditViewModel extends GenericEditViewModel<Schedule> {
  ScheduleEditViewModel({
    required this.repo,
    required this.companyId,
    Schedule? existing,
    super.sync,
    super.connectivity,
  }) : super(
         initialDraft: existing ?? Schedule.empty(),
         original: existing,
         companyId: companyId,
       );

  final ScheduleRepository repo;
  final String companyId;

  /// The picked invoice's total, captured from the create-mode invoice picker
  /// so [canSave] can enforce the server's amount-mode rule (installment
  /// amounts must sum to the invoice total). Null when unknown (edit mode locks
  /// the invoice behind a read-only field, or the invoice isn't loaded yet) →
  /// the amount-sum gate is skipped so Save isn't over-blocked.
  Decimal? _paymentScheduleInvoiceAmount;

  Decimal? get paymentScheduleInvoiceAmount => _paymentScheduleInvoiceAmount;

  void setPaymentScheduleInvoiceAmount(Decimal? v) {
    if (_paymentScheduleInvoiceAmount == v) return;
    _paymentScheduleInvoiceAmount = v;
    notifyListeners();
  }

  @override
  bool draftIsNonEmpty() {
    final d = draft;
    return d.template.isNotEmpty || d.name.isNotEmpty;
  }

  @override
  Future<SaveResult<Schedule>> performSave() async {
    if (isCreate) {
      final result = await repo.create(
        companyId: companyId,
        draft: draft,
        existingTempId: recoveryTempId,
      );
      rememberCreateTempId(result.entity.id);
      return result;
    }
    return repo.save(companyId: companyId, schedule: draft);
  }

  void resetToEmpty() => reset(emptyDraft: Schedule.empty());

  /// Seed a fresh create as an `email_report` schedule pre-filled from the
  /// reports screen's "Schedule" launcher (see `reportEmailSchedule`).
  void applyReportSeed(ReportScheduleSeed seed) =>
      updateDraft(reportEmailSchedule(seed));

  // ----- common setters -----

  void setName(String v) => updateDraft(draft.copyWith(name: v));

  void setTemplate(String v) {
    // Switching template wipes parameters to the right defaults so the
    // form doesn't accidentally send fields from the old template.
    updateDraft(draft.withTemplate(v));
  }

  void setNextRun(Date? v) => updateDraft(draft.copyWith(nextRun: v));

  void setFrequencyId(String v) => updateDraft(draft.copyWith(frequencyId: v));

  void setRemainingCycles(int v) =>
      updateDraft(draft.copyWith(remainingCycles: v));

  void setIsPaused(bool v) => updateDraft(draft.copyWith(isPaused: v));

  // ----- parameter mutators (generic) -----

  void _patchParameters(Map<String, dynamic> patch) {
    final next = Map<String, dynamic>.from(draft.parameters)..addAll(patch);
    updateDraft(draft.copyWith(parameters: next));
  }

  // ----- email_statement / invoice_outstanding_tasks parameters -----

  void setStatementStatus(String v) => _patchParameters({'status': v});

  void setStatementDateRange(String v) => _patchParameters({'date_range': v});

  void setShowAgingTable(bool v) => _patchParameters({'show_aging_table': v});

  void setShowPaymentsTable(bool v) =>
      _patchParameters({'show_payments_table': v});

  void setShowCreditsTable(bool v) =>
      _patchParameters({'show_credits_table': v});

  void setOnlyClientsWithInvoices(bool v) =>
      _patchParameters({'only_clients_with_invoices': v});

  void setStatementClients(List<String> ids) =>
      _patchParameters({'clients': ids});

  void setOutstandingTasksAutoSend(bool v) =>
      _patchParameters({'auto_send': v});

  void setOutstandingTasksIncludeProjectTasks(bool v) =>
      _patchParameters({'include_project_tasks': v});

  // ----- email_record parameters -----

  void setRecordEntityType(String v) {
    // No-op on re-select. The DropdownButtonFormField fires onChanged even
    // when the same item is chosen, and clearing entity_id below would wipe
    // the user's chosen record.
    if (v == draft.recordEntityType) return;
    // Switching entity type clears the entity id (it's only valid for one
    // type) and resets the email template to the entity's first option.
    final templates = kEmailRecordTemplatesPerEntity[v];
    final defaultTemplate = (templates == null || templates.isEmpty)
        ? ''
        : templates.first;
    _patchParameters({
      'entity': v,
      'entity_id': '',
      'template': defaultTemplate,
    });
  }

  void setRecordEntityId(String v) => _patchParameters({'entity_id': v});

  void setRecordEmailTemplate(String v) => _patchParameters({'template': v});

  // ----- email_report parameters -----

  void setReportName(String v) {
    // No-op when the report didn't actually change. SearchableDropdownField
    // fires onChanged on every option tap (including re-selecting the current
    // report), and the reset below would otherwise wipe the params the user
    // just configured.
    if (v == draft.reportName) return;
    // Switching report type resets the parameters to the email_report
    // defaults (then sets the new name), so the previous report's fields
    // don't leak onto the wire. `toApiJson` serializes `parameters`
    // verbatim, and the server reads e.g. `template_id` for *every* report
    // (a stale one silently turns a CSV report into a templated PDF) and
    // validates a stale `clients` id (a since-deleted client 422s on a
    // field the form no longer shows). A stale `custom` date_range would
    // also re-trigger the start/end requirement. Mirrors React
    // (`useHandleChange` resets on report change) and the `withTemplate`
    // reset pattern.
    final reset = draft.withTemplate(kScheduleTemplateEmailReport);
    final next = Map<String, dynamic>.from(reset.parameters)
      ..['report_name'] = v;
    updateDraft(reset.copyWith(parameters: next));
  }

  void setReportDateRange(String v) => _patchParameters({'date_range': v});

  void setReportStartDate(String v) => _patchParameters({'start_date': v});

  void setReportEndDate(String v) => _patchParameters({'end_date': v});

  void setReportStatus(String v) => _patchParameters({'status': v});

  void setReportSendEmail(bool v) => _patchParameters({'send_email': v});

  void setReportDocumentEmailAttachment(bool v) =>
      _patchParameters({'document_email_attachment': v});

  void setReportPdfEmailAttachment(bool v) =>
      _patchParameters({'pdf_email_attachment': v});

  void setReportIsExpenseBilled(bool v) =>
      _patchParameters({'is_expense_billed': v});

  void setReportIsIncomeBilled(bool v) =>
      _patchParameters({'is_income_billed': v});

  void setReportIncludeTax(bool v) => _patchParameters({'include_tax': v});

  void setReportIncludeDeleted(bool v) =>
      _patchParameters({'include_deleted': v});

  void setReportProductKey(String v) => _patchParameters({'product_key': v});

  void setReportClientId(String v) => _patchParameters({'client_id': v});

  void setReportClients(List<String> ids) => _patchParameters({'clients': ids});

  void setReportVendorsCsv(List<String> ids) =>
      _patchParameters({'vendors': ids.join(',')});

  void setReportProjectsCsv(List<String> ids) =>
      _patchParameters({'projects': ids.join(',')});

  void setReportCategoriesCsv(List<String> ids) =>
      _patchParameters({'categories': ids.join(',')});

  void setReportTemplateId(String v) => _patchParameters({'template_id': v});

  void setReportGroupBy(String v) => _patchParameters({'group_by': v});

  // ----- payment_schedule parameters -----

  void setPaymentScheduleInvoiceId(String v) =>
      _patchParameters({'invoice_id': v});

  void setPaymentScheduleAutoBill(bool v) => _patchParameters({'auto_bill': v});

  void setPaymentScheduleRows(List<ScheduleParamsRow> rows) {
    _patchParameters({
      'schedule': rows.map((r) => r.toJson()).toList(growable: false),
    });
  }

  // ----- validation -----

  /// Save-gate for the screen. Encodes the template-specific required
  /// fields without surfacing red borders on the form — the user sees a
  /// disabled Save button until the required slots are populated.
  bool get canSave {
    if (isSaving) return false;
    if (!isDirty) return false;
    final d = draft;
    if (d.template.isEmpty) return false;

    switch (d.template) {
      case kScheduleTemplateEmailStatement:
      case kScheduleTemplateInvoiceOutstandingTasks:
        return d.nextRun != null && d.frequencyId.isNotEmpty;
      case kScheduleTemplateEmailReport:
        if (d.nextRun == null || d.frequencyId.isEmpty) return false;
        // A custom date range makes start/end required on the server
        // (`StoreSchedulerRequest`: start_date/end_date are
        // `required_if:parameters.date_range,custom`, end after_or_equal
        // start). Gate Save so the form can't 422 on hidden-until-custom
        // fields.
        if (d.reportDateRange == 'custom') {
          if (d.reportStartDate.isEmpty || d.reportEndDate.isEmpty) {
            return false;
          }
          final start = Date.tryParse(d.reportStartDate);
          final end = Date.tryParse(d.reportEndDate);
          if (start != null && end != null && end.compareTo(start) < 0) {
            return false;
          }
        }
        return true;
      case kScheduleTemplateEmailRecord:
        return d.nextRun != null &&
            d.recordEntityId.isNotEmpty &&
            d.recordEmailTemplate.isNotEmpty;
      case kScheduleTemplatePaymentSchedule:
        final rows = d.paymentScheduleRows;
        if (d.paymentScheduleInvoiceId.isEmpty) return false;
        if (rows.isEmpty) return false;
        // Dates strictly ascending (matches React AddScheduleModal).
        for (var i = 1; i < rows.length; i++) {
          if (rows[i].date.compareTo(rows[i - 1].date) <= 0) return false;
        }
        // Every row must allocate a positive amount/percent.
        if (rows.any((r) => r.amount <= Decimal.zero)) return false;
        // The server (StoreSchedulerRequest::validatePaymentScheduleTotal)
        // rejects a split that doesn't total exactly — percent mode must sum to
        // 100, amount mode must sum to the invoice total — else the user gets a
        // success toast then a dead 422'd outbox row. Gate Save on both.
        final total = rows.fold<Decimal>(
          Decimal.zero,
          (sum, r) => sum + r.amount,
        );
        if (!rows.first.isAmount) {
          if (total != Decimal.fromInt(100)) return false;
        } else if (_paymentScheduleInvoiceAmount != null) {
          // Amount mode: gate only when we know the invoice total (captured
          // from the create-mode invoice picker). On edit the invoice is locked
          // behind a read-only field, so the amount is unknown → leave Save
          // enabled rather than over-block. Decimal `==` is scale-insensitive,
          // matching the server's BcMath::equal (100.0 == 100.00).
          if (total != _paymentScheduleInvoiceAmount) return false;
        }
        return true;
      default:
        return false;
    }
  }
}
