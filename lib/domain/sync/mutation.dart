/// Synthetic `entity_id` used by `MutationKind.reorder` outbox rows.
///
/// Reorder rows aren't keyed to a single entity — they carry a bulk-sort
/// payload (`{status_ids, task_ids}` for tasks, `{status_ids}` for
/// statuses). We park them under this constant so the outbox keeps its
/// non-null `entity_id` invariant; the Outbox screen renders them as
/// `Reorder &lt;entity&gt;` instead of `Sort #_sort` — see
/// `lib/ui/features/sync/views/outbox_screen.dart`.
const String kReorderEntityId = '_sort';

/// Synthetic `entity_id` used by `MutationKind.refreshAccounts` outbox
/// rows. Refresh rows aren't keyed to a single bank integration —
/// `POST /bank_integrations/refresh_accounts` is a tenant-wide refresh.
const String kRefreshAccountsEntityId = '_refresh';

/// Synthetic `entity_id` used by `MutationKind.convertMatched` and
/// `MutationKind.unlinkTransaction` outbox rows. The payload carries the
/// full `ids` array; this constant lets the outbox enforce its
/// non-null `entity_id` invariant without picking one transaction id
/// arbitrarily.
const String kBulkTransactionEntityId = '_bulk';

/// Reserved key inside a `create` / `update` outbox payload. When present
/// it holds a `Map<String,String>` of query params the server interprets as
/// an action performed *by* the save request itself (e.g.
/// `{'mark_sent':'true'}`, `{'paid':'true'}`). The sync dispatcher strips
/// this key out of the JSON body and promotes it to the request's query
/// string — it is never sent in the body. Set by the edit screen's
/// SAVE-PARAM action path (`GenericEditViewModel.setPendingSaveQuery`).
const String kSaveQueryPayloadKey = '__save_query';

/// The kind of mutation queued in the outbox.
///
/// Stored as a plain TEXT column so M2+ can add new server-side actions
/// (`upload`, `action:send_email`, `action:mark_paid`, etc.) without a
/// schema migration. The enum here covers the M1 CRUD set; the helpers
/// translate to/from the stored string.
enum MutationKind {
  create,
  update,
  delete,
  archive,
  restore,
  purge,
  addComment,
  // Clears a Postmark bounce/spam suppression for an invitation `message_id`
  // / email-event `bounce_id`. Fire-and-forget — no entity payload to apply.
  reactivateEmail,
  // Documents sub-system — same outbox pipeline, custom-actions dispatch.
  // `documentDelete` is password-gated server-side; entity repos that
  // expose documents must return true from `requiresPasswordFor` for it.
  documentUpload,
  documentDelete,
  documentVisibility,

  /// Bulk reorder — used by kanban drag-drop on tasks and by drag-handle
  /// reorder on task_statuses. Payload carries `{status_ids, task_ids}` or
  /// equivalent; `entityId` is a synthetic `'_sort'` because the row doesn't
  /// map to a single entity. Routed via `customActions` on the dispatcher.
  reorder,

  /// `PUT /<recurring_entity>/{id}?start=true` — activate a recurring entity
  /// (Draft/Paused → Active). Payload is `{'id': id}`. Routed via
  /// `customActions` on each recurring entity's dispatcher.
  start,

  /// `PUT /<recurring_entity>/{id}?stop=true` — pause an Active recurring
  /// entity. Payload is `{'id': id}`. Routed via `customActions` on each
  /// recurring entity's dispatcher.
  stop,

  /// `POST /<billing_doc>/{id}/mark_sent` — flip Draft → Sent on an invoice/
  /// quote/credit/PO. Server returns the updated entity. Payload is
  /// `{'id': id}`. Routed via `customActions` on each billing-doc dispatcher.
  markSent,

  /// `POST /api/v1/einvoice/peppol/send` `{entity:'invoice', entity_id}` —
  /// transmit the invoice via the configured e-invoice channel
  /// (PEPPOL / Verifactu-AEAT). Server owns the actual transmission;
  /// the dispatcher re-fetches the invoice so `backup`/`status` update.
  /// Routed via `customActions` on the Invoice dispatcher.
  sendEInvoice,

  /// `POST /invoices/{id}/mark_paid` — mark an invoice as fully paid (server
  /// records a synthetic payment for the outstanding balance). Payload is
  /// `{'id': id}`. Invoice-only today; future Credit could reuse.
  markPaid,

  /// `POST /<billing_doc>/{id}/email` — send the entity via email using a
  /// named template. Payload carries `template`, optional `subject`, `body`,
  /// `cc_email`. Generic name (`emailEntity` not `emailInvoice`) so Quote /
  /// Credit / PO share the same kind.
  emailEntity,

  /// `POST /<billing_doc>/{id}/email?send_at=...` — schedule the email for a
  /// future date. Payload carries `template` + `send_at` (ISO date/time).
  scheduleEmail,

  /// `POST /invoices/{id}/clone_to_invoice` — duplicate this billing doc as
  /// a new invoice. Payload is `{'id': id}`. The five clone variants are
  /// destination-specific because the server route ends in the target type.
  cloneToInvoice,

  /// `POST /<billing_doc>/{id}/clone_to_quote`.
  cloneToQuote,

  /// `POST /<billing_doc>/{id}/clone_to_credit`.
  cloneToCredit,

  /// `POST /<billing_doc>/{id}/clone_to_recurring_invoice`.
  cloneToRecurring,

  /// `POST /<billing_doc>/{id}/clone_to_purchase_order`.
  cloneToPurchaseOrder,

  /// `POST /invoices/{id}/auto_bill` — charge the invoice against the
  /// client's stored payment token. Payload is `{'id': id}`.
  autoBill,

  /// `POST /<billing_doc>/{id}/cancel` — cancel a sent invoice/quote/etc.
  /// Server marks it cancelled but keeps the row. Payload is `{'id': id}`.
  /// Generic name (`cancelEntity` not `cancelInvoice`) so Quote/Credit/PO
  /// share the same kind.
  cancelEntity,

  /// `POST /<billing_doc>/bulk` with `action: template` — apply a design or
  /// email template to one or more entities. Payload carries `template_id`
  /// + entity id. Routed via `customActions`.
  runTemplate,

  /// `POST /recurring_invoices/bulk` with `action: update_prices` — recompute
  /// each recurring invoice's line-item prices from the current product
  /// catalog. Payload `{'id': id}`. Recurring-only; routed via `customActions`.
  updatePrices,

  /// `POST /recurring_invoices/bulk` with `action: increase_prices` — bump
  /// line-item prices by a percentage. Payload carries `id` +
  /// `percentage_increase`. Recurring-only; routed via `customActions`.
  increasePrices,

  /// `POST /clients/bulk` with `action: bulk_update` — mass-update a single
  /// whitelisted column (`public_notes` / `industry_id` / `size_id` /
  /// `country_id` / `custom_value1..4`) across the selected clients. Payload
  /// carries `id` + `column` + `new_value`. Client-only; routed via
  /// `customActions`.
  bulkUpdate,

  /// `POST /api/v1/designs/set/default` — retroactively apply a document
  /// design to existing records at company / group / client scope. Payload:
  /// `{design_id, entity, settings_level, client_id? | group_settings_id?}`.
  /// Enqueued one-per-changed-entity by the Invoice Design "Update all
  /// records" toggle. Company scope fires it inline from `CompanySyncDispatcher`;
  /// client/group route it here via `customActions`.
  setDefaultDesign,

  /// `POST /quotes/{id}/approve` — manually mark a quote as approved by
  /// the client (override of the portal-driven flow). Quote-only.
  /// Payload is `{'id': id}`.
  approve,

  /// `POST /quotes/{id}/convert_to_invoice` — spawn an invoice from this
  /// quote. Server returns the new invoice envelope; the dispatcher
  /// returns null so the source row stays untouched (the new entity
  /// lands via a refresh or explicit navigation).
  convertToInvoice,

  /// `POST /quotes/{id}/convert_to_project` — spawn a project from this
  /// quote. Same null-return contract as `convertToInvoice`.
  convertToProject,

  /// `POST /purchase_orders/{id}/accept` — server-side mark-accepted for
  /// purchase orders (vendor-confirmed). PO-only.
  /// Payload is `{'id': id}`.
  acceptOrder,

  /// `POST /purchase_orders/{id}/expense` — convert a received purchase
  /// order into an expense (receipt). PO-only.
  /// Payload is `{'id': id}`.
  convertToExpense,

  /// `POST /purchase_orders/bulk` with `action: add_to_inventory` — record a
  /// PO's line items as received stock and flip Accepted → Received (server
  /// no-ops once `status_id >= RECEIVED`). PO-only. Payload is `{'id': id}`.
  addToInventory,

  /// `POST /recurring_invoices/{id}/send_now` — fire a one-off generation
  /// of the next invoice from this template, regardless of the schedule.
  /// RecurringInvoice-only. Payload is `{'id': id}`.
  sendNow,

  // ── E-Invoice / PEPPOL — Company-only custom actions ────────────────
  // All eight routes off `CompanySyncDispatcher`. The certificate upload
  // is a multipart POST; the rest are JSON. Each carries its own payload
  // shape (documented next to the corresponding method on
  // `CompaniesApi` / `CompanyRepository`).

  /// `POST /api/v1/companies/{id}/upload` with field `e_invoice_certificate`
  /// — multipart upload of a .p12 / .pfx / .pem / etc. certificate. Payload
  /// carries `{local_path}`; the dispatcher reads the file at send-time so
  /// the upload survives an app kill between save and network availability.
  uploadEInvoiceCertificate,

  /// `POST /api/v1/einvoice/peppol/setup` — bind a tenant to PEPPOL.
  /// Payload mirrors React `peppol/Onboarding.tsx`: party name, address,
  /// classification, sender/receiver, tenant_id.
  peppolSetup,

  /// `PUT /api/v1/einvoice/peppol/update` — change PEPPOL preferences
  /// (`acts_as_sender` / `acts_as_receiver`). Auto-fired by the
  /// Preferences card toggles, debounced.
  peppolUpdate,

  /// `POST /api/v1/einvoice/peppol/disconnect` — disconnect this tenant
  /// from PEPPOL.
  peppolDisconnect,

  /// `POST /api/v1/einvoice/peppol/add_additional_legal_identifier` — add
  /// a per-country VAT identifier (multi-country PEPPOL operation).
  /// Payload: `{country, vat_number}`.
  peppolAddTaxIdentifier,

  /// `DELETE /api/v1/einvoice/peppol/remove_additional_legal_identifier`
  /// — remove a per-country VAT identifier. Payload: `{country, vat_number}`.
  peppolRemoveTaxIdentifier,

  /// `POST /api/v1/einvoice/configurations` — save payment-means
  /// configuration (code + conditional IBAN/BIC/card sub-fields).
  eInvoicePaymentMeans,

  /// `POST /api/v1/einvoice/token/update` — regenerate the e-invoicing
  /// token. Surfaced by the Preferences card when the health-check
  /// endpoint reports the current token unhealthy.
  regenerateEInvoiceToken,

  // ── Bank Accounts / Transactions ───────────────────────────────────
  /// `POST /api/v1/bank_integrations/refresh_accounts` — ask the upstream
  /// provider (Yodlee/Nordigen) to refresh balances + the connected
  /// account list. No payload.
  refreshAccounts,

  /// `POST /api/v1/bank_transactions/match` (CREDIT, create payment) —
  /// payload: `{transactions: [{id, invoice_ids: "id1,id2"}]}`.
  matchToPayment,

  /// `POST /api/v1/bank_transactions/match` (CREDIT, link existing
  /// payment) — payload: `{transactions: [{id, payment_id}]}`.
  linkToPayment,

  /// `POST /api/v1/bank_transactions/match` (DEBIT, create expense) —
  /// payload: `{transactions: [{id, vendor_id, ninja_category_id}]}`.
  matchToExpense,

  /// `POST /api/v1/bank_transactions/match` (DEBIT, link existing
  /// expense) — payload: `{transactions: [{id, expense_id}]}`.
  linkToExpense,

  /// `POST /api/v1/bank_transactions/bulk` with `action=convert_matched`
  /// — convert matched rows into expenses/payments server-side.
  convertMatched,

  /// `POST /api/v1/bank_transactions/bulk` with `action=unlink` —
  /// detach a matched/converted row from its linked entities.
  unlinkTransaction,

  // ── User Management — non-CRUD user actions ────────────────────────
  /// `POST /api/v1/users/{id}/invite` — resend the invitation email to a
  /// pending user. Payload is `{'id': id}`. Routed via `customActions`
  /// on the User dispatcher.
  inviteUser,

  /// `DELETE /api/v1/users/{id}/detach_from_company` — remove the user
  /// from this company without deleting their user record (they still
  /// exist and may belong to other companies). Payload is `{'id': id}`.
  /// Routed via `customActions` on the User dispatcher.
  detachFromCompany,

  // ── Payments — non-CRUD payment actions ────────────────────────────
  /// `POST /api/v1/payments/refund?email_receipt=<bool>[&gateway_refund=true]`
  /// — refund a completed payment, optionally back through the gateway.
  /// Payload carries `{id, date, invoices: [{invoice_id, amount, id: ""}],
  /// send_email, gateway_refund}`. Server returns the updated payment.
  /// Routed via `customActions` on the Payment dispatcher.
  refundPayment,

  /// `PUT /api/v1/payments/{id}` with `{invoices: [{_id, amount, invoice_id,
  /// credit_id?, number?}]}` — apply unapplied payment funds to one or more
  /// invoices. Server returns the updated payment. Routed via `customActions`
  /// on the Payment dispatcher.
  applyPayment,

  /// `POST /api/v1/clients/{merge_into_id}/{merge_from_id}/merge` — absorb
  /// `merge_from` into `merge_into` (survivor). No body; password-gated
  /// (412), same as client delete/purge. Routed via `customActions` on the
  /// Client dispatcher; the absorbed client's local row is removed and the
  /// survivor upserted from the response.
  merge,

  /// Client locations are a standalone `/api/v1/locations` resource (POST /
  /// PUT / DELETE) that is *read-embedded* on the client. These three kinds
  /// route via `customActions` on the Client dispatcher; each handler calls
  /// `LocationsApi` then refreshes the parent client so `client.locations[]`
  /// reflects the change.
  locationCreate,
  locationUpdate,
  locationDelete,

  /// Invoice payment schedule. `paymentScheduleCreate` →
  /// `POST /invoices/{id}/payment_schedule` (number-of-payments flow);
  /// `paymentScheduleCreateCustom` → `POST /task_schedulers` (explicit
  /// rows); `paymentScheduleDelete` → `DELETE /invoices/{id}/payment_schedule`.
  /// Routed via `customActions` on the Invoice dispatcher; each handler
  /// re-fetches the invoice with `?show_schedule=true` so `invoice.schedule[]`
  /// reflects the change.
  paymentScheduleCreate,
  paymentScheduleCreateCustom,
  paymentScheduleDelete;

  static MutationKind? tryParse(String raw) => switch (raw) {
    'create' => MutationKind.create,
    'update' => MutationKind.update,
    'delete' => MutationKind.delete,
    'archive' => MutationKind.archive,
    'restore' => MutationKind.restore,
    'purge' => MutationKind.purge,
    'add_comment' => MutationKind.addComment,
    'reactivate_email' => MutationKind.reactivateEmail,
    'document_upload' => MutationKind.documentUpload,
    'document_delete' => MutationKind.documentDelete,
    'document_visibility' => MutationKind.documentVisibility,
    'reorder' => MutationKind.reorder,
    'start' => MutationKind.start,
    'stop' => MutationKind.stop,
    'mark_sent' => MutationKind.markSent,
    'send_e_invoice' => MutationKind.sendEInvoice,
    'mark_paid' => MutationKind.markPaid,
    'email_entity' => MutationKind.emailEntity,
    'schedule_email' => MutationKind.scheduleEmail,
    'clone_to_invoice' => MutationKind.cloneToInvoice,
    'clone_to_quote' => MutationKind.cloneToQuote,
    'clone_to_credit' => MutationKind.cloneToCredit,
    'clone_to_recurring' => MutationKind.cloneToRecurring,
    'clone_to_purchase_order' => MutationKind.cloneToPurchaseOrder,
    'auto_bill' => MutationKind.autoBill,
    'cancel_entity' => MutationKind.cancelEntity,
    'run_template' => MutationKind.runTemplate,
    'update_prices' => MutationKind.updatePrices,
    'increase_prices' => MutationKind.increasePrices,
    'bulk_update' => MutationKind.bulkUpdate,
    'set_default_design' => MutationKind.setDefaultDesign,
    'approve' => MutationKind.approve,
    'convert_to_invoice' => MutationKind.convertToInvoice,
    'convert_to_project' => MutationKind.convertToProject,
    'accept_order' => MutationKind.acceptOrder,
    'convert_to_expense' => MutationKind.convertToExpense,
    'add_to_inventory' => MutationKind.addToInventory,
    'send_now' => MutationKind.sendNow,
    'upload_e_invoice_certificate' => MutationKind.uploadEInvoiceCertificate,
    'peppol_setup' => MutationKind.peppolSetup,
    'peppol_update' => MutationKind.peppolUpdate,
    'peppol_disconnect' => MutationKind.peppolDisconnect,
    'peppol_add_tax_identifier' => MutationKind.peppolAddTaxIdentifier,
    'peppol_remove_tax_identifier' => MutationKind.peppolRemoveTaxIdentifier,
    'e_invoice_payment_means' => MutationKind.eInvoicePaymentMeans,
    'regenerate_e_invoice_token' => MutationKind.regenerateEInvoiceToken,
    'refresh_accounts' => MutationKind.refreshAccounts,
    'match_to_payment' => MutationKind.matchToPayment,
    'link_to_payment' => MutationKind.linkToPayment,
    'match_to_expense' => MutationKind.matchToExpense,
    'link_to_expense' => MutationKind.linkToExpense,
    'convert_matched' => MutationKind.convertMatched,
    'unlink_transaction' => MutationKind.unlinkTransaction,
    'invite_user' => MutationKind.inviteUser,
    'detach_from_company' => MutationKind.detachFromCompany,
    'refund_payment' => MutationKind.refundPayment,
    'apply_payment' => MutationKind.applyPayment,
    'merge' => MutationKind.merge,
    'location_create' => MutationKind.locationCreate,
    'location_update' => MutationKind.locationUpdate,
    'location_delete' => MutationKind.locationDelete,
    'payment_schedule_create' => MutationKind.paymentScheduleCreate,
    'payment_schedule_create_custom' =>
      MutationKind.paymentScheduleCreateCustom,
    'payment_schedule_delete' => MutationKind.paymentScheduleDelete,
    _ => null,
  };

  String get wireName => switch (this) {
    MutationKind.addComment => 'add_comment',
    MutationKind.reactivateEmail => 'reactivate_email',
    MutationKind.documentUpload => 'document_upload',
    MutationKind.documentDelete => 'document_delete',
    MutationKind.documentVisibility => 'document_visibility',
    MutationKind.markSent => 'mark_sent',
    MutationKind.sendEInvoice => 'send_e_invoice',
    MutationKind.markPaid => 'mark_paid',
    MutationKind.emailEntity => 'email_entity',
    MutationKind.scheduleEmail => 'schedule_email',
    MutationKind.cloneToInvoice => 'clone_to_invoice',
    MutationKind.cloneToQuote => 'clone_to_quote',
    MutationKind.cloneToCredit => 'clone_to_credit',
    MutationKind.cloneToRecurring => 'clone_to_recurring',
    MutationKind.cloneToPurchaseOrder => 'clone_to_purchase_order',
    MutationKind.autoBill => 'auto_bill',
    MutationKind.cancelEntity => 'cancel_entity',
    MutationKind.runTemplate => 'run_template',
    MutationKind.updatePrices => 'update_prices',
    MutationKind.increasePrices => 'increase_prices',
    MutationKind.bulkUpdate => 'bulk_update',
    MutationKind.setDefaultDesign => 'set_default_design',
    MutationKind.approve => 'approve',
    MutationKind.convertToInvoice => 'convert_to_invoice',
    MutationKind.convertToProject => 'convert_to_project',
    MutationKind.acceptOrder => 'accept_order',
    MutationKind.convertToExpense => 'convert_to_expense',
    MutationKind.addToInventory => 'add_to_inventory',
    MutationKind.sendNow => 'send_now',
    MutationKind.uploadEInvoiceCertificate => 'upload_e_invoice_certificate',
    MutationKind.peppolSetup => 'peppol_setup',
    MutationKind.peppolUpdate => 'peppol_update',
    MutationKind.peppolDisconnect => 'peppol_disconnect',
    MutationKind.peppolAddTaxIdentifier => 'peppol_add_tax_identifier',
    MutationKind.peppolRemoveTaxIdentifier => 'peppol_remove_tax_identifier',
    MutationKind.eInvoicePaymentMeans => 'e_invoice_payment_means',
    MutationKind.regenerateEInvoiceToken => 'regenerate_e_invoice_token',
    MutationKind.refreshAccounts => 'refresh_accounts',
    MutationKind.matchToPayment => 'match_to_payment',
    MutationKind.linkToPayment => 'link_to_payment',
    MutationKind.matchToExpense => 'match_to_expense',
    MutationKind.linkToExpense => 'link_to_expense',
    MutationKind.convertMatched => 'convert_matched',
    MutationKind.unlinkTransaction => 'unlink_transaction',
    MutationKind.inviteUser => 'invite_user',
    MutationKind.detachFromCompany => 'detach_from_company',
    MutationKind.refundPayment => 'refund_payment',
    MutationKind.applyPayment => 'apply_payment',
    MutationKind.merge => 'merge',
    MutationKind.locationCreate => 'location_create',
    MutationKind.locationUpdate => 'location_update',
    MutationKind.locationDelete => 'location_delete',
    MutationKind.paymentScheduleCreate => 'payment_schedule_create',
    MutationKind.paymentScheduleCreateCustom =>
      'payment_schedule_create_custom',
    MutationKind.paymentScheduleDelete => 'payment_schedule_delete',
    _ => name,
  };

  bool get isCreate => this == MutationKind.create;
  bool get isMutating =>
      this == MutationKind.create || this == MutationKind.update;

  /// What sending this kind a second time can do to the server — the
  /// question every retry of an attempt with an unknown outcome has to
  /// answer (see [DeliverySafety]). The server does not honour
  /// `Idempotency-Key` (BACKEND.md), so the answer comes from what each
  /// endpoint does, not from the header we send.
  ///
  /// A wildcard-free switch on purpose: a new kind does not compile until
  /// someone decides. When unsure, choose [DeliverySafety.nonIdempotent] —
  /// asking the user about a change that did go through costs a tap;
  /// silently doing it twice can cost money or a customer's inbox. For a
  /// payload that can make a single row stricter than its kind, see
  /// [deliverySafetyFor].
  DeliverySafety get deliverySafety => switch (this) {
    MutationKind.create ||
    MutationKind.addComment ||
    MutationKind.documentUpload ||
    MutationKind.emailEntity ||
    MutationKind.scheduleEmail ||
    MutationKind.cloneToInvoice ||
    MutationKind.cloneToQuote ||
    MutationKind.cloneToCredit ||
    MutationKind.cloneToRecurring ||
    MutationKind.cloneToPurchaseOrder ||
    MutationKind.autoBill ||
    MutationKind.increasePrices ||
    MutationKind.convertToProject ||
    MutationKind.sendNow ||
    MutationKind.inviteUser ||
    MutationKind.refundPayment ||
    MutationKind.applyPayment ||
    MutationKind.locationCreate ||
    MutationKind.paymentScheduleCreate ||
    MutationKind.markPaid ||
    MutationKind.sendEInvoice => DeliverySafety.nonIdempotent,
    MutationKind.cancelEntity ||
    MutationKind.peppolSetup ||
    MutationKind.peppolDisconnect ||
    MutationKind.peppolAddTaxIdentifier ||
    MutationKind.peppolRemoveTaxIdentifier ||
    MutationKind.detachFromCompany ||
    MutationKind.merge ||
    MutationKind.paymentScheduleCreateCustom => DeliverySafety.serverGuarded,
    MutationKind.update ||
    MutationKind.delete ||
    MutationKind.archive ||
    MutationKind.restore ||
    MutationKind.purge ||
    MutationKind.reactivateEmail ||
    MutationKind.documentDelete ||
    MutationKind.documentVisibility ||
    MutationKind.reorder ||
    MutationKind.start ||
    MutationKind.stop ||
    MutationKind.markSent ||
    MutationKind.approve ||
    MutationKind.convertToInvoice ||
    MutationKind.convertToExpense ||
    MutationKind.addToInventory ||
    MutationKind.acceptOrder ||
    MutationKind.runTemplate ||
    MutationKind.updatePrices ||
    MutationKind.bulkUpdate ||
    MutationKind.setDefaultDesign ||
    MutationKind.uploadEInvoiceCertificate ||
    MutationKind.peppolUpdate ||
    MutationKind.eInvoicePaymentMeans ||
    MutationKind.regenerateEInvoiceToken ||
    MutationKind.refreshAccounts ||
    MutationKind.matchToPayment ||
    MutationKind.linkToPayment ||
    MutationKind.matchToExpense ||
    MutationKind.linkToExpense ||
    MutationKind.convertMatched ||
    MutationKind.unlinkTransaction ||
    MutationKind.locationUpdate ||
    MutationKind.locationDelete ||
    MutationKind.paymentScheduleDelete => DeliverySafety.idempotent,
  };
}

/// What re-sending a mutation can do when the first attempt's outcome is
/// unknown — a timeout after the request left, a connection dropped
/// mid-response, the app killed while a row was `in_flight`.
///
/// The outbox used to treat all of those as "never sent" and retry,
/// relying on `Idempotency-Key` to make a re-send harmless. The server
/// ignores that header, so a lost response re-created the entity, re-sent
/// the customer's email, re-applied a percentage price increase.
enum DeliverySafety {
  /// A replay leaves the server exactly as one send would: a PUT of the full
  /// record, a state flag, an absolute value, a delete.
  idempotent,

  /// A replay would be a duplicate, but the server refuses it (a 4xx because
  /// the first one already happened) or ignores it — never a double effect.
  /// Safe to re-send; the worst case is a confusing rejection.
  serverGuarded,

  /// A replay does the thing again: a new record, another email, another
  /// charge or refund, a compounding change. Never re-send one whose first
  /// attempt may have landed without asking the user.
  nonIdempotent;

  /// Whether a row of this safety may be re-sent automatically after an
  /// attempt whose outcome is unknown.
  bool get autoResendable => this != DeliverySafety.nonIdempotent;
}

/// Save-query params (`kSaveQueryPayloadKey`) that make a `create` /
/// `update` perform a non-idempotent action as part of the save — a
/// payment, a charge, a send. The others the edit screens use (`mark_sent`,
/// `approve`, `cancel`, `convert`, `start`, `stop`) set a state or are
/// refused on replay.
const Set<String> kNonIdempotentSaveParams = {
  'paid',
  'mark_paid',
  'auto_bill',
  'send_now',
  'send_email',
};

/// Company `update` rows whose `_action` adds rather than replaces
/// (`CompanySyncDispatcher`): another document each time.
const Set<String> kNonIdempotentCompanyActions = {'upload_document'};

/// How the company's document upload names its action in the stored payload:
/// `jsonEncode` of `{'_action': 'upload_document', …}`
/// (`CompanyRepository.uploadDocument`). No field value can forge it —
/// `jsonEncode` escapes the quotes inside a user's own text.
const String kUploadDocumentActionJson = '"_action":"upload_document"';

/// Whether an outbox row only attaches a document to its record: a
/// `document_upload`, or the company's `update` carrying
/// [kUploadDocumentActionJson]. It writes no field of the record, so it can't
/// overwrite a later save — it holds none back
/// (`OutboxDao.hasEarlierActiveRowForEntity`, and the drain's in-pass latch),
/// is no pending edit a refresh must defer to (`OutboxDao.hasActiveRowsFor`,
/// `hasEditRowForEntity`), and owns no dirty flag
/// (`OutboxDao.hasActiveRowsForEntity`). Uploads are the likeliest rows to go
/// `unconfirmed`, and one used to hold every later save of its record until
/// the user dealt with it. The DAO's SQL twin is `OutboxDao._isDocumentUpload`
/// — keep the two in step.
bool isDocumentUploadRow({
  required String mutationKind,
  required String payload,
}) =>
    mutationKind == MutationKind.documentUpload.wireName ||
    (mutationKind == MutationKind.update.wireName &&
        payload.contains(kUploadDocumentActionJson));

/// [MutationKind.deliverySafety], made stricter by what this row's decoded
/// [payload] actually asks for. Only ever escalates: a payload can turn a
/// plain save into a payment, never a create into something harmless.
DeliverySafety deliverySafetyFor(MutationKind kind, Object? payload) {
  final base = kind.deliverySafety;
  if (base == DeliverySafety.nonIdempotent || payload is! Map) return base;
  final query = payload[kSaveQueryPayloadKey];
  if (query is Map &&
      query.keys.any((k) => kNonIdempotentSaveParams.contains(k))) {
    return DeliverySafety.nonIdempotent;
  }
  final action = payload['_action'];
  if (action is String && kNonIdempotentCompanyActions.contains(action)) {
    return DeliverySafety.nonIdempotent;
  }
  return base;
}
