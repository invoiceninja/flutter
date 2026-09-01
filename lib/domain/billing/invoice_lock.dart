// Invoice-lock policy. Mirrors admin-portal `app_actions.dart` `editEntity()`
// (the `EntityType.invoice` branch): the `lock_invoices` company setting
// blocks *editing* an invoice once it is sent / paid / past end-of-month.
//
// v2 stores the server-computed `Invoice.isLocked` flag but never enforced it
// — the editor opened anyway and the doomed mutation entered the outbox. This
// computes the lock locally (so it's correct offline, where the server flag is
// stale) and is ORed with the server flag (server wins if it says locked).
//
// Scope is invoices only — Quote / Credit / PurchaseOrder / RecurringInvoice
// have no lock setting and no `isLocked` field, matching both reference apps.
//
// Status transitions (markSent / markPaid / autoBill / cancel) are *not*
// edits and are intentionally not gated here — the VeriFactu nuance from
// `invoice_actions.dart` (only `markPaid` is blocked, because the synthetic
// payment it records is itself an edit) is preserved at the call sites.

import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/repositories/settings_repository.dart';

/// Why an invoice is locked — drives the reason-specific dialog/banner copy.
enum InvoiceLockReason {
  /// Not locked.
  none,

  /// The server returned `is_locked: true` (e.g. VeriFactu compliance). Uses
  /// the generic `invoice_locked` message.
  server,

  /// `lock_invoices = when_paid` and the invoice is paid / partially paid.
  paid,

  /// `lock_invoices = when_sent` and the invoice has been sent.
  sent,

  /// `lock_invoices = end_of_month` and the invoice's month has passed.
  endOfMonth,
}

/// The localization key for [reason]. All keys ship in the English bundle
/// (`invoice_locked` lives in `_app_pending.json`, the other three in
/// `en.json`); none are new — see CLAUDE.md § Localization.
String invoiceLockMessageKey(InvoiceLockReason reason) {
  switch (reason) {
    case InvoiceLockReason.paid:
      return 'paid_invoices_are_locked';
    case InvoiceLockReason.sent:
      return 'sent_invoices_are_locked';
    case InvoiceLockReason.endOfMonth:
      return 'invoices_locked_end_of_month';
    case InvoiceLockReason.server:
    case InvoiceLockReason.none:
      return 'invoice_locked';
  }
}

/// Pure lock policy. No DB access — unit-testable in isolation.
///
/// [lockInvoicesSetting] is the resolved cascade value (one of `off` /
/// `when_sent` / `when_paid` / `end_of_month`, or null). [veriFactuActive]
/// forces `when_sent` when the resolved setting is null/`off` (the server and
/// the settings UI do the same — VeriFactu always locks sent invoices).
/// [today] is injectable for deterministic tests.
InvoiceLockReason invoiceLockReason({
  required Invoice invoice,
  required String? lockInvoicesSetting,
  required bool veriFactuActive,
  Date? today,
}) {
  // Server flag wins outright (it already factored in compliance rules).
  if (invoice.isLocked) return InvoiceLockReason.server;

  var setting = lockInvoicesSetting;
  if ((setting == null || setting.isEmpty || setting == 'off') &&
      veriFactuActive) {
    setting = 'when_sent';
  }

  switch (setting) {
    case 'when_sent':
      return invoice.isSent ? InvoiceLockReason.sent : InvoiceLockReason.none;
    case 'when_paid':
      return (invoice.isPaid || invoice.isPartial)
          ? InvoiceLockReason.paid
          : InvoiceLockReason.none;
    case 'end_of_month':
      final date = invoice.date;
      if (date == null) return InvoiceLockReason.none;
      final now = today ?? Date.today();
      final pastMonth = date.year != now.year || date.month != now.month;
      return pastMonth ? InvoiceLockReason.endOfMonth : InvoiceLockReason.none;
    case 'off':
    default:
      return InvoiceLockReason.none;
  }
}

/// Convenience boolean over [invoiceLockReason].
bool isInvoiceLockedBy({
  required Invoice invoice,
  required String? lockInvoicesSetting,
  required bool veriFactuActive,
  Date? today,
}) =>
    invoiceLockReason(
      invoice: invoice,
      lockInvoicesSetting: lockInvoicesSetting,
      veriFactuActive: veriFactuActive,
      today: today,
    ) !=
    InvoiceLockReason.none;

/// Resolves the settings cascade for [invoice]'s client and applies the pure
/// policy. `SettingsRepository.resolved` always hits Drift, so this is the
/// authoritative path — every gate that ACTS on the lock uses it.
/// [peekInvoiceLockReason] is the seed-only sibling for first-frame rendering.
Future<InvoiceLockReason> resolveInvoiceLockReason({
  required SettingsRepository settings,
  required String companyId,
  required Invoice invoice,
}) async {
  final resolved = await settings.resolved(
    companyId: companyId,
    clientId: _cascadeClientId(invoice),
  );
  return _reasonFrom(invoice, resolved);
}

/// Synchronous first-frame approximation of [resolveInvoiceLockReason].
///
/// Null when the cascade has never been resolved for this company this session
/// — the caller then starts where it always did, at [InvoiceLockReason.none].
///
/// A **seed**, never a source of truth: the caller MUST still run
/// [resolveInvoiceLockReason] and let its answer win. Exists because the
/// master-detail pane re-keys its subtree per `:id`, so the banner is mounted
/// fresh on every row click and two awaited Drift reads later is far too late
/// to decide whether ~44 px of chrome exists.
///
/// Typed as a reason rather than handing back the settings map on purpose: it
/// keeps `SettingsRepository.resolvedIfReady` from drifting into use as a
/// general synchronous settings source.
InvoiceLockReason? peekInvoiceLockReason({
  required SettingsRepository settings,
  required String companyId,
  required Invoice invoice,
}) {
  final resolved = settings.resolvedIfReady(
    companyId: companyId,
    clientId: _cascadeClientId(invoice),
  );
  if (resolved == null) return null;
  return _reasonFrom(invoice, resolved);
}

String? _cascadeClientId(Invoice invoice) =>
    invoice.clientId.isEmpty ? null : invoice.clientId;

/// The two keys the lock policy reads, in one place so the sync and async
/// paths cannot pick up different ones.
InvoiceLockReason _reasonFrom(Invoice invoice, Map<String, dynamic> resolved) =>
    invoiceLockReason(
      invoice: invoice,
      lockInvoicesSetting: resolved['lock_invoices'] as String?,
      veriFactuActive: resolved['e_invoice_type'] == 'VERIFACTU',
    );

/// Resolves the cascade and returns whether [invoice] is locked.
Future<bool> resolveInvoiceLocked({
  required SettingsRepository settings,
  required String companyId,
  required Invoice invoice,
}) async =>
    (await resolveInvoiceLockReason(
      settings: settings,
      companyId: companyId,
      invoice: invoice,
    )) !=
    InvoiceLockReason.none;

/// Thrown by [InvoiceRepository.save] when a plain field edit is attempted on
/// a locked invoice. A backstop — the UI hard-blocks at the edit-entry point
/// before this is reached; this guarantees no locked mutation can enter the
/// outbox via any future call site.
class InvoiceLockedException implements Exception {
  const InvoiceLockedException([this.reason = InvoiceLockReason.none]);

  final InvoiceLockReason reason;

  /// Localization key for a user-facing message.
  String get messageKey => invoiceLockMessageKey(reason);

  @override
  String toString() => 'InvoiceLockedException(${reason.name})';
}
