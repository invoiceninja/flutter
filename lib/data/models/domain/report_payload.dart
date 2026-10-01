import 'package:admin/data/models/value/date.dart';

/// Date-range presets accepted by the server's report endpoints. Wire tokens
/// are verified against the server's own `BaseExport::date_range` switch
/// (`invoiceninja/app/Export/CSV/BaseExport.php`): it accepts `all`, `last7`,
/// `last30`, `this_month`, `last_month`, `this_quarter`, `last_quarter`,
/// `last365_days`, `this_year`, `last_year`, `custom`. NOTE the 365-day window
/// is `last365_days` (NOT `last365`), and there is **no** `last90` case — an
/// unrecognized token silently widens to all-time, so we only expose tokens the
/// server actually honors. The dashboard keeps its own `DashboardDatePreset`.
enum ReportDatePreset {
  allTime,
  last7,
  last30,
  last365,
  thisMonth,
  lastMonth,
  thisQuarter,
  lastQuarter,
  thisYear,
  lastYear,
  custom;

  String get wire {
    switch (this) {
      case ReportDatePreset.allTime:
        return 'all';
      case ReportDatePreset.last7:
        return 'last7';
      case ReportDatePreset.last30:
        return 'last30';
      case ReportDatePreset.last365:
        return 'last365_days';
      case ReportDatePreset.thisMonth:
        return 'this_month';
      case ReportDatePreset.lastMonth:
        return 'last_month';
      case ReportDatePreset.thisQuarter:
        return 'this_quarter';
      case ReportDatePreset.lastQuarter:
        return 'last_quarter';
      case ReportDatePreset.thisYear:
        return 'this_year';
      case ReportDatePreset.lastYear:
        return 'last_year';
      case ReportDatePreset.custom:
        return 'custom';
    }
  }
}

/// Wire-shape DTO posted to the report endpoints. Field names are wire
/// names so [toJson] can be a direct dump.
///
/// Verified against `react/src/pages/reports/common/useReports.ts:11-46`
/// and `Reports.tsx:266-283`:
/// - Multi-select fields (`clients`, `vendors`, `categories`, `projects`,
///   `status`) are **comma-joined CSV strings**, not arrays.
/// - `report_keys` is a JSON array, populated at submit time from the user's
///   visible-column selection (not stored on the payload).
/// - Empty / null fields are **dropped** from the wire payload — except
///   for the `product_sales` quirk where an empty `client_id` is sent as
///   literal `null` (Reports.tsx:270) so the server treats it as "all
///   clients" rather than "filter by empty string".
class ReportPayload {
  const ReportPayload({
    this.datePreset = ReportDatePreset.allTime,
    this.startDate,
    this.endDate,
    this.dateKey,
    this.clientId,
    this.clients,
    this.vendors,
    this.categories,
    this.projects,
    this.tags,
    this.status,
    this.activityTypeId,
    this.productKey,
    this.templateId,
    this.documentEmailAttachment = false,
    this.pdfEmailAttachment = false,
    this.includeDeleted = false,
    this.includeTax = false,
    this.isExpenseBilled = false,
    this.isIncomeBilled = false,
    this.sendEmail = false,
  });

  final ReportDatePreset datePreset;
  final Date? startDate;
  final Date? endDate;

  /// Which date column the date range filters by (`created_at`,
  /// `invoice_date`, `due_date`, …). Per-report default lives on
  /// [ReportDefinition.defaultFilterValues].
  final String? dateKey;

  // Single-id filter (product_sales has a special "all clients" semantics).
  final String? clientId;

  // CSV-joined id filters — multi-select pickers join on submit.
  final String? clients;
  final String? vendors;
  final String? categories;
  final String? projects;

  /// CSV of tag ids → `tag_ids` (every tag-bearing report).
  final String? tags;
  final String? status;

  final String? activityTypeId;
  final String? productKey;
  final String? templateId;

  final bool documentEmailAttachment;
  final bool pdfEmailAttachment;
  final bool includeDeleted;
  final bool includeTax;
  final bool isExpenseBilled;
  final bool isIncomeBilled;

  /// True only when serializing for the email-export flow. The wire endpoint
  /// is the same as a normal export POST; `send_email: true` short-circuits
  /// the hash/poll cycle (server enqueues + emails asynchronously, response
  /// is a plain 200 with no hash to follow). [ReportsApi.sendEmail] sets
  /// this; nothing else should.
  final bool sendEmail;

  ReportPayload copyWith({
    ReportDatePreset? datePreset,
    Date? Function()? startDate,
    Date? Function()? endDate,
    String? Function()? dateKey,
    String? Function()? clientId,
    String? Function()? clients,
    String? Function()? vendors,
    String? Function()? categories,
    String? Function()? projects,
    String? Function()? tags,
    String? Function()? status,
    String? Function()? activityTypeId,
    String? Function()? productKey,
    String? Function()? templateId,
    bool? documentEmailAttachment,
    bool? pdfEmailAttachment,
    bool? includeDeleted,
    bool? includeTax,
    bool? isExpenseBilled,
    bool? isIncomeBilled,
    bool? sendEmail,
  }) {
    return ReportPayload(
      datePreset: datePreset ?? this.datePreset,
      startDate: startDate == null ? this.startDate : startDate(),
      endDate: endDate == null ? this.endDate : endDate(),
      dateKey: dateKey == null ? this.dateKey : dateKey(),
      clientId: clientId == null ? this.clientId : clientId(),
      clients: clients == null ? this.clients : clients(),
      vendors: vendors == null ? this.vendors : vendors(),
      categories: categories == null ? this.categories : categories(),
      projects: projects == null ? this.projects : projects(),
      tags: tags == null ? this.tags : tags(),
      status: status == null ? this.status : status(),
      activityTypeId: activityTypeId == null
          ? this.activityTypeId
          : activityTypeId(),
      productKey: productKey == null ? this.productKey : productKey(),
      templateId: templateId == null ? this.templateId : templateId(),
      documentEmailAttachment:
          documentEmailAttachment ?? this.documentEmailAttachment,
      pdfEmailAttachment: pdfEmailAttachment ?? this.pdfEmailAttachment,
      includeDeleted: includeDeleted ?? this.includeDeleted,
      includeTax: includeTax ?? this.includeTax,
      isExpenseBilled: isExpenseBilled ?? this.isExpenseBilled,
      isIncomeBilled: isIncomeBilled ?? this.isIncomeBilled,
      sendEmail: sendEmail ?? this.sendEmail,
    );
  }

  /// Build the JSON map sent on the wire.
  ///
  /// - `report_keys` is supplied separately (derived from visible columns at
  ///   submit time, not stored on the payload).
  /// - `group_by` is supplied separately on the export flow only — preview
  ///   does its grouping locally, so we never send it on preview.
  /// - The `product_sales` `client_id` quirk: pass [reportIdentifier] so the
  ///   serializer knows when to coerce an empty `clientId` to literal `null`
  ///   instead of dropping it.
  Map<String, dynamic> toJson({
    required String reportIdentifier,
    List<String> reportKeys = const [],
    String? groupBy,
  }) {
    final out = <String, dynamic>{
      'date_range': datePreset.wire,
      if (startDate != null) 'start_date': startDate!.toIso(),
      if (endDate != null) 'end_date': endDate!.toIso(),
      if (dateKey != null && dateKey!.isNotEmpty) 'date_key': dateKey,
      if (clients != null && clients!.isNotEmpty) 'clients': clients,
      if (vendors != null && vendors!.isNotEmpty) 'vendors': vendors,
      if (categories != null && categories!.isNotEmpty)
        'categories': categories,
      if (projects != null && projects!.isNotEmpty) 'projects': projects,
      if (tags != null && tags!.isNotEmpty) 'tag_ids': tags,
      if (status != null && status!.isNotEmpty) 'status': status,
      if (activityTypeId != null && activityTypeId!.isNotEmpty)
        'activity_type_id': activityTypeId,
      if (productKey != null && productKey!.isNotEmpty)
        'product_key': productKey,
      if (templateId != null && templateId!.isNotEmpty)
        'template_id': templateId,
      if (documentEmailAttachment) 'document_email_attachment': true,
      if (pdfEmailAttachment) 'pdf_email_attachment': true,
      if (includeDeleted) 'include_deleted': true,
      if (includeTax) 'include_tax': true,
      if (isExpenseBilled) 'is_expense_billed': true,
      if (isIncomeBilled) 'is_income_billed': true,
      if (sendEmail) 'send_email': true,
      if (reportKeys.isNotEmpty) 'report_keys': reportKeys,
      if (groupBy != null && groupBy.isNotEmpty) 'group_by': groupBy,
    };

    // product_sales: an empty client_id must be serialized as literal `null`
    // (not omitted) so the server treats it as "all clients" rather than
    // "filter by empty string". Other reports drop empty client_id entirely.
    if (reportIdentifier == 'product_sales') {
      out['client_id'] = (clientId == null || clientId!.isEmpty)
          ? null
          : clientId;
    } else if (clientId != null && clientId!.isNotEmpty) {
      out['client_id'] = clientId;
    }

    return out;
  }

  @override
  bool operator ==(Object other) {
    if (other is! ReportPayload) return false;
    return datePreset == other.datePreset &&
        startDate == other.startDate &&
        endDate == other.endDate &&
        dateKey == other.dateKey &&
        clientId == other.clientId &&
        clients == other.clients &&
        vendors == other.vendors &&
        categories == other.categories &&
        projects == other.projects &&
        tags == other.tags &&
        status == other.status &&
        activityTypeId == other.activityTypeId &&
        productKey == other.productKey &&
        templateId == other.templateId &&
        documentEmailAttachment == other.documentEmailAttachment &&
        pdfEmailAttachment == other.pdfEmailAttachment &&
        includeDeleted == other.includeDeleted &&
        includeTax == other.includeTax &&
        isExpenseBilled == other.isExpenseBilled &&
        isIncomeBilled == other.isIncomeBilled &&
        sendEmail == other.sendEmail;
  }

  @override
  int get hashCode => Object.hashAll([
    datePreset,
    startDate,
    endDate,
    dateKey,
    clientId,
    clients,
    vendors,
    categories,
    projects,
    tags,
    status,
    activityTypeId,
    productKey,
    templateId,
    documentEmailAttachment,
    pdfEmailAttachment,
    includeDeleted,
    includeTax,
    isExpenseBilled,
    isIncomeBilled,
    sendEmail,
  ]);
}
