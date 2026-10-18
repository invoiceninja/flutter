import 'package:admin/data/models/domain/report_preview.dart';
import 'package:admin/data/models/value/date.dart';

/// What a report built on the device is asked for: the window its rows fall
/// in, and the filters the report's settings panel offers — the same ones
/// the server would have been sent, applied on the device instead.
class ReportQuery {
  const ReportQuery({
    required this.companyId,
    required this.now,
    required this.label,
    this.start,
    this.end,
    this.status = '',
    this.clientIds = const {},
    this.projectIds = const {},
    this.tagIds = const {},
    this.includeDeleted = false,
  });

  final String companyId;

  /// The first and last day of the range, both inclusive; null for "All
  /// time". Resolved from the request's own payload, never from the one on
  /// screen — see `ReportsViewModel._localQuery`.
  final Date? start;
  final Date? end;

  /// The report's Status filter as the server spells it — a comma-joined
  /// list, empty for none.
  final String status;
  final Set<String> clientIds;
  final Set<String> projectIds;
  final Set<String> tagIds;
  final bool includeDeleted;

  /// The moment the rows are as of: a running timer counts up to it, and a
  /// block booked after it is not time worked.
  final DateTime now;

  /// A column's header, from its localization key. The view model holds no
  /// `BuildContext`; the host hands it the lookup.
  final String Function(String key) label;

  bool get isAllTime => start == null || end == null;
}

/// A report whose rows are built on the device from records the app holds,
/// rather than asked of the server — see `ReportDefinition.isLocal`.
///
/// Two calls, because the screen wants both: the rows the device already
/// holds, at once and with no connection, and then the same rows after the
/// server has been asked for anything the device is missing.
abstract interface class LocalReportSource {
  /// The rows from what the device holds now. Never touches the network.
  Future<ReportPreview> fromDevice(ReportQuery query);

  /// Fetch what [query] needs into the device's store, then [fromDevice].
  ///
  /// Throws a `ReportError` — `cancelled` when [isCancelled] turns true or
  /// the company is switched mid-fetch.
  Future<ReportPreview> refresh(
    ReportQuery query, {
    bool Function()? isCancelled,
  });
}
