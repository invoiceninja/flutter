/// Whether a billing doc's **E-Invoice** tab is offered at all.
///
/// It never was gated. `invoice_edit_layout.dart`'s own class doc has said
/// since M3 that the tab "surfaces only when company has eInvoice enabled —
/// gated in M4"; the gate was never written, so every invoice / credit /
/// recurring-invoice edit screen has shipped an E-Invoice tab to every
/// company. It is the widest label in the narrow strip (58 px in English,
/// 77 in German) and dead weight for the large majority who never file one —
/// half the reason that strip ran 1.4 screens wide
/// (invoiceninja/flutter#140).
///
/// The predicate mirrors React's, clause for clause
/// (`pages/invoices/common/hooks/useTabs.tsx`):
///
/// ```ts
/// enabled: company?.settings.enable_e_invoice === true ||
///          company?.settings.e_invoice_type === 'PEPPOL',
/// ```
///
/// PEPPOL is called out separately because it is not covered by the switch:
/// `enable_e_invoice` defaults false and `e_invoice_type` defaults to
/// EN16931 (`e_invoice_body.dart`), so a PEPPOL company that never touched
/// the toggle still needs the form.
///
/// [resolvedSettings] is the **async** `SettingsRepository.resolved(companyId:
/// …)` with no client — the company layer, which is the tier React reads.
///
/// Deliberately not its synchronous `resolvedIfReady` sibling, tempting as a
/// frame-1 answer is: that mirror is refreshed only as a side effect of a
/// `resolved()` call, so a company that switches e-invoicing on in Settings
/// would keep the stale answer for the rest of the session — and
/// `peek_is_seed_only_test.dart` fails the build on the attempt. Callers
/// therefore start with the tab **hidden** and reveal it when the cascade
/// answers, two frames in: a tab that arrives is ordinary async UI, where one
/// that vanishes can take a tap with it, and E-Invoice is the last tab in the
/// strip, so on a phone it arrives off-screen anyway.
///
/// An unreadable company row resolves to `{}` and so to false, which is the
/// right answer: a company nothing is known about is not filing e-invoices.
bool eInvoiceTabVisible(Map<String, dynamic> resolvedSettings) =>
    resolvedSettings['enable_e_invoice'] == true ||
    resolvedSettings['e_invoice_type'] == 'PEPPOL';
