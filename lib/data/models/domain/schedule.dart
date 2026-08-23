import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:admin/data/models/api/schedule_api_model.dart';
import 'package:admin/data/models/domain/schedule_constants.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/models/value/parsing.dart';

part 'schedule.freezed.dart';

/// Clean domain model for a task scheduler row. Powers the list/edit
/// screens under Settings → Advanced → Schedules.
///
/// `parameters` stays as a free `Map<String, dynamic>`. Typed views per
/// template are exposed through the `parametersAs*` extension getters.
@freezed
abstract class Schedule with _$Schedule {
  const factory Schedule({
    required String id,
    required String name,
    required String template,
    required String frequencyId,
    required Date? nextRun,
    required bool isPaused,
    required int remainingCycles,
    required Map<String, dynamic> parameters,
    required DateTime updatedAt,
    required DateTime createdAt,
    required DateTime? archivedAt,
    required bool isDeleted,
    @Default(false) bool isDirty,
  }) = _Schedule;

  factory Schedule.fromApi(ScheduleApi a) => Schedule(
    id: a.id,
    name: a.name,
    template: a.template,
    frequencyId: a.frequencyId,
    nextRun: Date.tryParse(a.nextRun),
    isPaused: a.isPaused,
    remainingCycles: a.remainingCycles,
    parameters: Map<String, dynamic>.from(a.parameters),
    updatedAt: epochSecondsToUtc(a.updatedAt),
    createdAt: epochSecondsToUtc(a.createdAt),
    archivedAt: epochSecondsToUtcOrNull(a.archivedAt),
    isDeleted: a.isDeleted,
  );

  /// Create an empty draft for a brand-new schedule. Caller picks the
  /// template via the card-picker landing step; the form then seeds
  /// template-specific parameter defaults via [Schedule.withTemplate].
  factory Schedule.empty() => Schedule(
    id: '',
    name: '',
    template: '',
    frequencyId: '5', // monthly — the legacy admin-portal default
    nextRun: Date.today(),
    isPaused: false,
    remainingCycles: kScheduleRemainingCyclesEndless,
    parameters: const <String, dynamic>{},
    updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    archivedAt: null,
    isDeleted: false,
  );
}

extension SchedulePayload on Schedule {
  /// Serialize to the wire shape. The Drift `payload` column round-trips
  /// through this when the row is read back by the repository's `_fromRow`.
  ///
  /// `frequency_id` / `remaining_cycles` are emitted only for the templates
  /// that use them (React `TemplateProperties` in `useFormatSchedulePayload`):
  /// the server force-sets `frequency_id=0` for email_record and
  /// `remaining_cycles=count(schedule)` for payment_schedule, so sending
  /// stale values is at best ignored and at worst (frequency on a one-shot
  /// email_record) wrong. Omitted keys read back as the DTO defaults.
  Map<String, dynamic> toApiJson({bool preserveTempId = false}) {
    return <String, dynamic>{
      if (preserveTempId || !id.startsWith('tmp_')) 'id': id,
      'name': name,
      'template': template,
      if (supportsFrequency) 'frequency_id': frequencyId,
      'next_run': nextRun?.toIso() ?? '',
      'is_paused': isPaused,
      if (supportsRemainingCycles) 'remaining_cycles': remainingCycles,
      'parameters': _wireParameters(parameters),
    };
  }
}

extension ScheduleTemplateHelpers on Schedule {
  /// Switch the schedule to a new template and seed sensible parameter
  /// defaults. Mirrors React `useHandleChange.tsx`'s reset behavior on
  /// template change. Frequency, next-run, and cycle settings stay put.
  Schedule withTemplate(String newTemplate) {
    return copyWith(
      template: newTemplate,
      parameters: _defaultParametersFor(newTemplate),
    );
  }

  /// Whether this template has a recurring frequency.
  bool get supportsFrequency =>
      template != kScheduleTemplateEmailRecord &&
      template != kScheduleTemplatePaymentSchedule;

  /// Whether this template uses the `next_run` field. Payment schedules
  /// drive their dates from the inline rows instead.
  bool get supportsNextRun => template != kScheduleTemplatePaymentSchedule;

  /// Whether this template carries a `remaining_cycles` count. Only the two
  /// recurring email templates do (React `TemplateProperties`):
  /// invoice_outstanding_tasks sends a frequency but no cycle count, and
  /// email_record / payment_schedule have neither.
  bool get supportsRemainingCycles =>
      template == kScheduleTemplateEmailStatement ||
      template == kScheduleTemplateEmailReport;

  /// Return a copy whose `next_run` is no earlier than [floor]. The server
  /// enforces `next_run >= today` on every template (`StoreSchedulerRequest`),
  /// so the repository clamps on save — this also covers payment_schedule,
  /// whose `next_run` field is hidden, and editing a schedule whose stored
  /// `next_run` already lapsed. A null `next_run` is left untouched.
  Schedule withNextRunNotBefore(Date floor) {
    final current = nextRun;
    if (current == null || current.compareTo(floor) >= 0) return this;
    return copyWith(nextRun: floor);
  }
}

extension EmailStatementParametersAccess on Schedule {
  String get statementDateRange =>
      (parameters['date_range'] as String?) ?? 'last7_days';

  String get statementStatus =>
      (parameters['status'] as String?) ?? kStatementStatusAll;

  bool get statementShowAgingTable =>
      (parameters['show_aging_table'] as bool?) ?? false;

  bool get statementShowPaymentsTable =>
      (parameters['show_payments_table'] as bool?) ?? false;

  bool get statementShowCreditsTable =>
      (parameters['show_credits_table'] as bool?) ?? false;

  bool get statementOnlyClientsWithInvoices =>
      (parameters['only_clients_with_invoices'] as bool?) ?? false;

  /// Empty list means "all clients" — the wire's null/empty signal.
  List<String> get statementClients => _stringList(parameters['clients']);
}

extension EmailRecordParametersAccess on Schedule {
  String get recordEntityType => (parameters['entity'] as String?) ?? 'invoice';

  String get recordEntityId => (parameters['entity_id'] as String?) ?? '';

  /// Email template name (e.g. `reminder1`, `custom2`). NOT the report
  /// design id — that's `templateId` on email_report.
  String get recordEmailTemplate => (parameters['template'] as String?) ?? '';
}

extension EmailReportParametersAccess on Schedule {
  String get reportName => (parameters['report_name'] as String?) ?? 'activity';

  String get reportDateRange =>
      (parameters['date_range'] as String?) ?? 'last7_days';

  String get reportStartDate => (parameters['start_date'] as String?) ?? '';

  String get reportEndDate => (parameters['end_date'] as String?) ?? '';

  String get reportStatus => (parameters['status'] as String?) ?? '';

  bool get reportSendEmail => (parameters['send_email'] as bool?) ?? true;

  bool get reportDocumentEmailAttachment =>
      (parameters['document_email_attachment'] as bool?) ?? false;

  bool get reportPdfEmailAttachment =>
      (parameters['pdf_email_attachment'] as bool?) ?? false;

  bool get reportIsExpenseBilled =>
      (parameters['is_expense_billed'] as bool?) ?? false;

  bool get reportIsIncomeBilled =>
      (parameters['is_income_billed'] as bool?) ?? false;

  bool get reportIncludeTax => (parameters['include_tax'] as bool?) ?? false;

  bool get reportIncludeDeleted =>
      (parameters['include_deleted'] as bool?) ?? false;

  String get reportProductKey => (parameters['product_key'] as String?) ?? '';

  /// Singular client (the `client` report uses this).
  String get reportClientId => (parameters['client_id'] as String?) ?? '';

  /// Multi-client list (most other reports use this). Plural.
  List<String> get reportClients => _stringList(parameters['clients']);

  /// Vendors / projects / categories live on the wire as CSV strings
  /// (per React). The domain accessor exposes them as lists.
  List<String> get reportVendors => _csvOrList(parameters['vendors']);

  List<String> get reportProjects => _csvOrList(parameters['projects']);

  List<String> get reportCategories => _csvOrList(parameters['categories']);

  /// Report-design template id (NOT the email template — that's
  /// `recordEmailTemplate` on email_record).
  String get reportTemplateId => (parameters['template_id'] as String?) ?? '';

  String get reportGroupBy => (parameters['group_by'] as String?) ?? '';

  List<String> get reportKeys => _stringList(parameters['report_keys']);
}

extension InvoiceOutstandingTasksParametersAccess on Schedule {
  String get outstandingTasksDateRange =>
      (parameters['date_range'] as String?) ?? 'last7_days';

  bool get outstandingTasksAutoSend =>
      (parameters['auto_send'] as bool?) ?? false;

  bool get outstandingTasksIncludeProjectTasks =>
      (parameters['include_project_tasks'] as bool?) ?? false;

  List<String> get outstandingTasksClients =>
      _stringList(parameters['clients']);
}

extension PaymentScheduleParametersAccess on Schedule {
  String get paymentScheduleInvoiceId =>
      (parameters['invoice_id'] as String?) ?? '';

  bool get paymentScheduleAutoBill =>
      (parameters['auto_bill'] as bool?) ?? false;

  /// The split-payment rows. Empty when the schedule hasn't been
  /// populated yet — the form requires at least one row before save.
  List<ScheduleParamsRow> get paymentScheduleRows {
    final raw = parameters['schedule'];
    if (raw is! List) return const <ScheduleParamsRow>[];
    final result = <ScheduleParamsRow>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final map = Map<String, dynamic>.from(entry);
      final id = (map['id'] as num?)?.toInt() ?? 0;
      final date = Date.tryParse(map['date'] as String?);
      if (date == null) continue;
      final amountRaw = map['amount'];
      final amount = amountRaw is num
          ? numToDecimal(amountRaw)
          : Decimal.tryParse((amountRaw as String?) ?? '0') ?? Decimal.zero;
      final isAmount = (map['is_amount'] as bool?) ?? true;
      result.add(
        ScheduleParamsRow(
          id: id,
          date: date,
          amount: amount,
          isAmount: isAmount,
        ),
      );
    }
    return List.unmodifiable(result);
  }
}

/// Typed view of a single payment-schedule row (`parameters.schedule[N]`).
///
/// `id` is a client-side 1-based index assigned on add (mirrors React's
/// `AddScheduleModal.tsx:148`). `amount` is a `Decimal`, never a `double`
/// — CLAUDE.md § Strict rules. `isAmount` is set on row 0 only and
/// inherited by subsequent rows (React `AddScheduleModal.tsx:260`).
class ScheduleParamsRow {
  const ScheduleParamsRow({
    required this.id,
    required this.date,
    required this.amount,
    required this.isAmount,
  });

  final int id;
  final Date date;
  final Decimal amount;
  final bool isAmount;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'date': date.toIso(),
    'amount': amount.toString(),
    'is_amount': isAmount,
  };

  ScheduleParamsRow copyWith({
    int? id,
    Date? date,
    Decimal? amount,
    bool? isAmount,
  }) => ScheduleParamsRow(
    id: id ?? this.id,
    date: date ?? this.date,
    amount: amount ?? this.amount,
    isAmount: isAmount ?? this.isAmount,
  );
}

// ---------- private helpers ----------

/// Parameter keys the server validates with Laravel's `date:Y-m-d` rule.
const _kDateParameterKeys = <String>{'start_date', 'end_date'};

/// [parameters] with any blank date key dropped.
///
/// An empty string is **not** skipped the way a `nullable` rule would skip
/// it. `StoreSchedulerRequest` declares
/// `'parameters.start_date' => ['bail', 'date:Y-m-d', 'required_if:parameters.date_range,custom']`,
/// and posting `email_report` with `start_date: ''` / `end_date: ''` is
/// rejected live with **422** *"The parameters.start date is not a valid
/// date."* — verified against demo.invoiceninja.com; omitting both keys
/// succeeds. Since `_defaultParametersFor` seeds both as `''` and the form
/// only renders them when `date_range == 'custom'`, every non-custom
/// `email_report` create 422'd: the row landed in Drift, the outbox POST was
/// rejected, and the list showed a schedule that was never saved
/// (invoiceninja/flutter#43).
///
/// Scoped deliberately to these two keys: they are the only date params in
/// the API surface declared without `sometimes`/`nullable`. Every other date
/// this app sends as `''` (invoice/quote/credit `due_date`, `partial_due_date`,
/// expense `payment_date`, …) is `'bail|sometimes|nullable|date'` server-side,
/// where Laravel skips a blank — so there is nothing to sweep elsewhere.
///
/// Dropping beats defaulting — inventing a date the user never picked would
/// silently narrow the report's range. `canSave` separately blocks the
/// `custom` case until both dates are filled, so a blank here always means
/// "this template has no date range", never "the user hasn't typed it yet".
Map<String, dynamic> _wireParameters(Map<String, dynamic> parameters) {
  final out = <String, dynamic>{};
  for (final entry in parameters.entries) {
    final isBlankDate =
        _kDateParameterKeys.contains(entry.key) &&
        entry.value is String &&
        (entry.value as String).isEmpty;
    if (!isBlankDate) out[entry.key] = entry.value;
  }
  return out;
}

Map<String, dynamic> _defaultParametersFor(String template) {
  switch (template) {
    case kScheduleTemplateEmailStatement:
      return <String, dynamic>{
        'date_range': 'last7_days',
        'status': kStatementStatusAll,
        'show_aging_table': false,
        'show_payments_table': false,
        'show_credits_table': false,
        'only_clients_with_invoices': false,
        'clients': const <String>[],
      };
    case kScheduleTemplateEmailRecord:
      return <String, dynamic>{
        'entity': 'invoice',
        'entity_id': '',
        // The initial-email template for the default `invoice` entity. Must
        // be a server-accepted value (see kEmailRecordTemplatesPerEntity) —
        // `'initial'` is rejected by `StoreSchedulerRequest`.
        'template': 'invoice',
      };
    case kScheduleTemplateEmailReport:
      return <String, dynamic>{
        'report_name': 'activity',
        'date_range': 'last7_days',
        'start_date': '',
        'end_date': '',
        'send_email': true,
        'document_email_attachment': false,
        'pdf_email_attachment': false,
        'is_expense_billed': false,
        'is_income_billed': false,
        'include_tax': false,
        'include_deleted': false,
        'product_key': '',
        'client_id': '',
        'clients': const <String>[],
        'vendors': '',
        'projects': '',
        'categories': '',
        'template_id': '',
        'group_by': '',
        'status': '',
        'report_keys': const <String>[],
      };
    case kScheduleTemplateInvoiceOutstandingTasks:
      return <String, dynamic>{
        'date_range': 'last7_days',
        'auto_send': false,
        'include_project_tasks': false,
        'clients': const <String>[],
      };
    case kScheduleTemplatePaymentSchedule:
      return <String, dynamic>{
        'invoice_id': '',
        'auto_bill': false,
        'schedule': const <Map<String, dynamic>>[],
      };
    default:
      return <String, dynamic>{};
  }
}

List<String> _stringList(Object? raw) {
  if (raw is List) {
    return raw.whereType<String>().toList(growable: false);
  }
  return const <String>[];
}

/// React's `vendors`, `projects`, `categories` come over the wire as CSV
/// strings. The admin-portal models them as lists. We accept both shapes
/// and emit list semantics from the domain.
List<String> _csvOrList(Object? raw) {
  if (raw is List) return raw.whereType<String>().toList(growable: false);
  if (raw is String) {
    final s = raw.trim();
    if (s.isEmpty) return const <String>[];
    return s
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }
  return const <String>[];
}
