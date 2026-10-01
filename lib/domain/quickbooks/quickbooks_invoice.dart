/// QuickBooks sync state for one invoice, and what the user may do about it
/// (invoiceninja/ui#3284). A leaf: plain maps in, plain values out.
///
/// The server keeps the state on the invoice's read-only `sync` object
/// (`App\DataMapper\InvoiceSync`) and acts on it through
/// `POST /api/v1/quickbooks/action {entity: 'invoice', id, action}`. Only
/// `check_record` answers synchronously; `force_link` / `force_pull` /
/// `force_push` return 204 and run after the response, announcing a changed
/// status on the user's realtime channel (`QuickbooksEntityStatusChanged`).
library;

/// The four actions the endpoint accepts for an invoice, in display order.
enum QuickbooksInvoiceAction {
  checkRecord('check_record'),
  forceLink('force_link'),
  forcePull('force_pull'),
  forcePush('force_push');

  const QuickbooksInvoiceAction(this.wire);
  final String wire;

  static QuickbooksInvoiceAction? fromWire(String wire) {
    for (final a in values) {
      if (a.wire == wire) return a;
    }
    return null;
  }
}

/// `invoice.sync`'s QuickBooks half.
class QuickbooksInvoiceSync {
  const QuickbooksInvoiceSync({
    this.qbId = '',
    this.status = '',
    this.message = '',
  });

  factory QuickbooksInvoiceSync.fromJson(Map<String, dynamic>? json) =>
      QuickbooksInvoiceSync(
        qbId: _str(json?['qb_id']).trim(),
        status: _str(json?['qb_status']).trim(),
        message: _str(json?['qb_status_message']).trim(),
      );

  /// The QuickBooks record id, '' when not linked.
  final String qbId;

  /// `syncable` / `linkable` / `data_mismatch` / `amount_mismatch` /
  /// `synced`, or '' before the server has looked.
  final String status;
  final String message;

  bool get isLinked => qbId.isNotEmpty;
}

/// Whether the company has a QuickBooks connection at all — React's
/// `hasQuickbooksConnection`: `company.quickbooks` is present and non-empty.
bool quickbooksConnected(Map<String, dynamic>? quickbooks) =>
    quickbooks != null && quickbooks.isNotEmpty;

String _invoiceDirection(Map<String, dynamic>? quickbooks) {
  final settings = quickbooks?['settings'];
  final invoice = settings is Map ? settings['invoice'] : null;
  final direction = invoice is Map ? invoice['direction'] : null;
  return direction is String ? direction : '';
}

bool quickbooksInvoicePushEnabled(Map<String, dynamic>? quickbooks) {
  final d = _invoiceDirection(quickbooks);
  return d == 'push' || d == 'bidirectional';
}

bool quickbooksInvoicePullEnabled(Map<String, dynamic>? quickbooks) {
  final d = _invoiceDirection(quickbooks);
  return d == 'pull' || d == 'bidirectional';
}

/// The actions to offer for an invoice in [sync] — React's
/// `getQuickbooksInvoiceActions`, rule for rule:
///  * `check_record` always (when connected);
///  * not linked: `force_link` when the server found a `linkable` match;
///  * linked: `force_pull` when invoices pull from QuickBooks;
///  * `force_push` when a push failed (a status message on a `syncable` /
///    `synced` record) and invoices push to QuickBooks.
List<QuickbooksInvoiceAction> quickbooksInvoiceActions(
  QuickbooksInvoiceSync sync,
  Map<String, dynamic>? quickbooks,
) {
  if (!quickbooksConnected(quickbooks)) return const [];
  final canForcePush =
      (sync.status == 'syncable' || sync.status == 'synced') &&
      sync.message.isNotEmpty &&
      quickbooksInvoicePushEnabled(quickbooks);
  return [
    QuickbooksInvoiceAction.checkRecord,
    if (!sync.isLinked && sync.status == 'linkable')
      QuickbooksInvoiceAction.forceLink,
    if (sync.isLinked && quickbooksInvoicePullEnabled(quickbooks))
      QuickbooksInvoiceAction.forcePull,
    if (canForcePush) QuickbooksInvoiceAction.forcePush,
  ];
}

/// One side-by-side comparison in a check result.
class QuickbooksComparison {
  const QuickbooksComparison({
    required this.matches,
    required this.invoiceNinja,
    required this.quickbooks,
  });

  factory QuickbooksComparison.fromJson(Object? json) {
    final m = json is Map ? json : const <String, Object?>{};
    return QuickbooksComparison(
      matches: m['matches'] == true,
      invoiceNinja: _str(m['invoice_ninja']),
      quickbooks: _str(m['quickbooks']),
    );
  }

  final bool matches;

  /// Raw values as the server sent them — a number for totals, which the
  /// caller formats.
  final String invoiceNinja;
  final String quickbooks;
}

/// `meta.quickbooks_check` from a `check_record` call
/// (`CheckInvoice::buildCheckContext`).
class QuickbooksInvoiceCheck {
  const QuickbooksInvoiceCheck({
    required this.outcome,
    required this.linked,
    required this.message,
    this.quickbooksId = '',
    this.quickbooksStatus = '',
    this.number,
    this.total,
    this.recommendedActions = const [],
  });

  factory QuickbooksInvoiceCheck.fromJson(Map<String, dynamic> json) {
    final qb = json['quickbooks'];
    final cmp = json['comparison'];
    final recommended = json['recommended_actions'];
    return QuickbooksInvoiceCheck(
      outcome: _str(json['outcome']),
      linked: json['linked'] == true,
      message: _str(json['message']).trim(),
      quickbooksId: qb is Map ? _str(qb['id']) : '',
      quickbooksStatus: qb is Map ? _str(qb['status']) : '',
      number: cmp is Map && cmp['number'] != null
          ? QuickbooksComparison.fromJson(cmp['number'])
          : null,
      total: cmp is Map && cmp['total'] != null
          ? QuickbooksComparison.fromJson(cmp['total'])
          : null,
      recommendedActions: [
        if (recommended is List)
          for (final a in recommended)
            if (a is String && a.isNotEmpty) a,
      ],
    );
  }

  /// `syncable` / `linkable` / `synced` / `data_mismatch` / `not_found` /
  /// `voided`.
  final String outcome;
  final bool linked;
  final String message;

  /// The matching QuickBooks record, '' when none was found.
  final String quickbooksId;
  final String quickbooksStatus;
  final QuickbooksComparison? number;
  final QuickbooksComparison? total;

  /// Wire names: an action ([QuickbooksInvoiceAction.fromWire]) or advice
  /// (`change_invoice_number`, `verify_quickbooks_invoice`).
  final List<String> recommendedActions;
}

String _str(Object? v) => v == null ? '' : '$v';
