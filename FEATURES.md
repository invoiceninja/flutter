# Feature parity tracker

Working tracker comparing every user-facing feature across the three Invoice Ninja admin clients:

- **React** — the web client at `/Users/hillel/Code/react`
- **Flutter v1** — the legacy Redux-based admin app at `/Users/hillel/Code/admin-portal`
- **Flutter v2** — this rebuild (`/Users/hillel/Code/admin`)

## Legend

| Symbol | Meaning |
|---|---|
| ✅ | Implemented end-to-end |
| 🟡 | Partial — UI scaffolded but missing functionality, gated by another module, or known-incomplete |
| ❌ | Not implemented (no screen, no model, no route) |
| — | N/A (feature doesn't apply to this app — e.g. biometric lock on the web, cookie banner on desktop) |

The **Live E2E** column tracks *true* automated coverage by the live
`integration_test/` suite that runs the real app against
`demo.invoiceninja.com` (see `integration_test/demo/` + `support/demo_harness.dart`):

- ✅ — covered end-to-end by a passing live test (real UI → network → assertion).
- 🟡 — partially exercised (e.g. the list/screen mounts and renders without error, but rows/behaviour aren't asserted).
- blank — not yet covered by a live test (the default; most rows).
- — — N/A (no meaningful live assertion possible for this row).

Only flip a cell here when a test genuinely asserts the behaviour; blank is the honest default.

The **AI review** column tracks whether a feature's Flutter v2 implementation
has had a deep AI review of code correctness:

- ✅ — code reviewed in depth and confirmed correct.
- blank — not yet reviewed (the default; most rows).

Only flip a cell to ✅ when a genuine deep correctness review was done; blank is
the honest default.

## Categories

1. [Authentication & session](#authentication--session)
2. [Dashboard](#dashboard)
3. [Clients](#clients)
4. [Invoices](#invoices)
5. [Quotes](#quotes)
6. [Credits](#credits)
7. [Recurring invoices](#recurring-invoices)
8. [Payments](#payments)
9. [Projects](#projects)
10. [Tasks](#tasks)
11. [Vendors](#vendors)
12. [Purchase orders](#purchase-orders)
13. [Expenses](#expenses)
14. [Recurring expenses](#recurring-expenses)
15. [Bank transactions](#bank-transactions)
16. [Products](#products)
17. [Documents (DocuNinja)](#documents-docuninja)
18. [Reports](#reports)
19. [Settings — Basic](#settings--basic)
20. [Settings — Advanced](#settings--advanced)
21. [Payment gateways](#payment-gateways)
22. [Sync & offline](#sync--offline)
23. [Cross-cutting](#cross-cutting)
24. [Platform / mobile specific](#platform--mobile-specific)

---

## Authentication & session

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Email / password login | ✅ | ✅ | ✅ | ✅ | ✅ |
| Signup / account creation | ✅ | ❌ | ✅ | ✅ | |
| OAuth — Google | ✅ | ❌ | ✅ | ✅ | |
| OAuth — Microsoft / Azure | ✅ | ❌ | ❌ |  | |
| OAuth — Apple (Sign in with Apple) | ✅ | ✅ | ✅ | ✅ | |
| Two-factor authentication (TOTP / Google Authenticator) | ✅ | ✅ | ✅ | ✅ | |
| Login precheck (hide OTP / API-secret fields unless the server needs them) | ❌ | ❌ | ✅ | | |
| Two-factor SMS verification | ✅ | ✅ | ✅ | ✅ | |
| Password reset / recovery email | ✅ | ✅ | ✅ | ✅ | |
| Biometric lock (Touch ID / Face ID / fingerprint) | — | ✅ | ✅ | ✅ | |
| Demo-account access | ✅ | ✅ | ✅ | ✅ | ✅ |
| Logout | ✅ | ✅ | ✅ | ✅ | ✅ |
| Idle session timeout | ✅ | ✅ | ✅ | ✅ | |
| Single-flight 401 → logout coordination | ✅ | ✅ | ✅ | ✅ | |
| Minimum-client-version gate | ✅ | ✅ | ✅ | ✅ | |
| Multi-company switching within session | ✅ | ✅ | ✅ | ✅ | |
| Password confirmation modal for destructive actions | ✅ | ✅ | ✅ | ✅ | |
| Password cache TTL (5 min) for chained destructive ops | ✅ | ✅ | ✅ | ✅ | |
| GDPR data export / account closure flow | ✅ | ❌ | ✅ | ✅ | |

---

## Dashboard

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Dashboard overview screen | ✅ | ✅ | ✅ | ✅ | ✅ |
| KPI strip (revenue / invoices / quotes / payments) | ✅ | ✅ | ✅ | ✅ | ✅ |
| Delta chip (period-over-period change) | ✅ | ✅ | ✅ | ✅ | |
| Sparkline charts on KPIs | ✅ | ✅ | ✅ | ✅ | |
| Recent payments card | ✅ | ✅ | ✅ | ✅ | |
| Upcoming invoices card | ✅ | ✅ | ✅ | ✅ | |
| Upcoming quotes card | ✅ | ✅ | ✅ | ✅ | |
| Upcoming recurring invoices card | ✅ | ✅ | ✅ | ✅ | |
| Expired quotes card | ✅ | ✅ | ✅ | ✅ | |
| Past-due invoices card | ✅ | ✅ | ✅ | ✅ | |
| Needs-attention auto-detected items | ✅ | ✅ | ✅ | ✅ | |
| Activity feed (recent entity changes) | ✅ | ✅ | ✅ | ✅ | |
| Dashboard date range filter | ✅ | ✅ | ✅ | ✅ | |
| Chart Day/Week/Month grouping | ✅ | ✅ | ✅ | ✅ | |
| Configurable dashboard cards (Dashboard Fields) | ✅ | ✅ | ✅ | ✅ | |
| Reorder + show/hide dashboard list panels (device-local) | — | — | ✅ | ✅ | |
| Dashboard prefs synced server-side (cross-device) | ✅ | ✅ | ❌ | ✅ | — |
| Panel → filtered list deep-links (View All / KPI cards carry matching filters) | — | — | ✅ | ✅ | |
| Freshness label (last data update) | ❌ | ✅ | ✅ | ✅ | |
| Responsive single-column mobile layout | — | ✅ | ✅ | ✅ | |

---

## Clients

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Client — list | ✅ | ✅ | ✅ | ✅ | ✅ |
| Client — detail | ✅ | ✅ | ✅ | ✅ | ✅ |
| Client — edit | ✅ | ✅ | ✅ | ✅ | ✅ |
| Client — create | ✅ | ✅ | ✅ | ✅ | ✅ |
| Client — clone | ✅ | ❌ | ✅ | ✅ | |
| Client — merge two clients | ✅ | ❌ | ✅ | ✅ | |
| Client — statement PDF | ✅ | ✅ | ✅ | ✅ | |
| Client — comments / internal notes | ✅ | ✅ | ✅ | ✅ | |
| Client — documents / attachments | ✅ | ✅ | ✅ | ✅ | |
| Client — activity / audit feed | ✅ | ✅ | ✅ | ✅ | |
| Client — ledger tab (running balance, filter chips, tap-through) | ✅ | ✅ | ✅ | ✅ | |
| Client — email history | ✅ | ✅ | ✅ | | |
| Client — contact unsubscribed/bounce indicator | ✅ | ❌ | ✅ | | |
| Client — email bounce reactivate | ✅ | ❌ | ✅ | | |
| Client — custom fields | ✅ | ✅ | ✅ | ✅ | |
| Client — group assignment | ✅ | ✅ | ✅ | ✅ | |
| Client — multiple contacts | ✅ | ✅ | ✅ | ✅ | |
| Client — import contact from device address book (iOS) | ❌ | ✅ | ✅ | | |
| Client/Vendor — contact CC-only | ✅ | ✅ | ✅ | — | — |
| Client — multiple shipping / billing locations | ✅ | ✅ | ✅ | ✅ | |
| Client — shipping address on the record (billing + shipping, Copy Billing) | ✅ | ✅ | ✅ | ✅ | |
| Client — settings editor (currency / language / classification / size / industry / tax flags) | ✅ | ✅ | ✅ | ✅ | |
| Client — saved payment methods (gateway tokens) card | ✅ | ✅ | ✅ | ✅ | |
| Client — payment terms override | ✅ | ✅ | ✅ | ✅ | |
| Client — currency override (cascade) | ✅ | ✅ | ✅ | ✅ | |
| Client — portal-access toggle / portal password | ✅ | ✅ | ✅ | ✅ | |
| Client — open client portal (primary contact, silent auto-login) | ✅ | ✅ | ✅ | | |
| Client — archive | ✅ | ✅ | ✅ | ✅ | |
| Client — restore | ✅ | ✅ | ✅ | ✅ | |
| Client — delete | ✅ | ✅ | ✅ | ✅ | |
| Client — purge (hard delete, admin only) | ✅ | ✅ | ✅ | ✅ | |
| Client — bulk archive / restore / delete | ✅ | ✅ | ✅ | ✅ | |
| Client — bulk update (mass-edit fields) | ✅ | ✅ | ✅ |  | |
| Client — import (CSV / JSON) | ✅ | 🟡 | ✅ | ✅ | |
| Client — cross-entity "New invoice / recurring / quote / credit / payment / task / expense" | ✅ | ✅ | ✅ | ✅ | |
| Client — view client invoices / quotes / payments / credits / recurring / projects / tasks / expenses | ✅ | ✅ | ✅ | ✅ | |
| Client — tags (attach via picker, list `tag_ids` filter + column, detail chips) | ✅ | — | ✅ | | |
| Client — create inline from the billing-doc Client picker, auto-selected on the document (invoice / quote / credit / recurring) | ✅ | ✅ | ✅ | | |

---

## Invoices

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Invoice — list | ✅ | ✅ | ✅ | ✅ | 🟡 |
| Invoice — detail | ✅ | ✅ | ✅ | ✅ | ✅ |
| Invoice — edit (line items, dates, totals) | ✅ | ✅ | ✅ | ✅ | |
| Billing-doc edit — items-section FAB → tabbed multi-select picker (Products / Tasks / Expenses; tasks+expenses client-scoped to uninvoiced; exclude already-attached; Select All per tab; projectId carry-over) — invoice / quote / credit / recurring / PO | ✅ | ✅ | ✅ | ✅ | |
| Billing-doc edit — picker Tasks tab grouped by project with per-project select-all | ❌ | ❌ | ✅ | | |
| Billing-doc edit — document-level tax rates (1–3) + custom surcharges (1–4) + inclusive-taxes toggle, gated on company `enabled_tax_rates` / surcharge custom-fields — invoice / quote / credit / recurring / PO | ✅ | ✅ | ✅ | | |
| Invoice — create | ✅ | ✅ | ✅ | ✅ | |
| Edit/create screen action bar (Save & mark sent/paid/cancel/auto-bill via save query-param; email/clone/etc. after-save) — all entities | ✅ | ✅ | ✅ | | |
| Invoice — clone to new invoice | ✅ | ✅ | ✅ | ✅ | |
| Invoice — clone to quote | ✅ | ✅ | ✅ | ✅ | |
| Invoice — clone to credit | ✅ | ❌ | ✅ | ✅ | |
| Invoice — clone to recurring invoice | ✅ | ✅ | ✅ | ✅ | |
| Invoice — clone to purchase order | ✅ | ❌ | ✅ | ✅ | |
| Invoice — mark sent | ✅ | ✅ | ✅ | ✅ | |
| Invoice — mark paid | ✅ | ✅ | ✅ | ✅ | |
| Invoice — mark partial payment | ✅ | ✅ | ✅ | ✅ | |
| Invoice — refund / credit application | ✅ | ✅ | ✅ | ✅ | |
| Invoice — cancel | ✅ | ✅ | ✅ | ✅ | |
| Invoice — rectify (reversal / correction) | ✅ | ❌ | ✅ | ✅ | |
| Invoice — email to client | ✅ | ✅ | ✅ | ✅ | |
| Invoice — schedule email (delayed send) | ✅ | ❌ | ✅ | ✅ | |
| Invoice — change template / design | ✅ | ✅ | ✅ | ✅ | |
| Invoice — auto-bill with gateway | ✅ | ✅ | ✅ | ✅ | |
| Invoice — view / download PDF | ✅ | ✅ | ✅ | ✅ | |
| Invoice — print | ✅ | ✅ | ✅ | ✅ | |
| Invoice — audit trail / history | ✅ | ✅ | ✅ | ✅ | |
| Invoice — email history | ✅ | ✅ | ✅ | | |
| Invoice — email bounce indicator + reactivate | ✅ | ✅ | ✅ | | |
| Invoice — list bounce status badge | 🟡 | ✅ | ✅ | | |
| Invoice — activities | ✅ | ✅ | ✅ | ✅ | |
| Invoice — payment schedule view | ✅ | ✅ | ✅ | ✅ | |
| Invoice — unapplied payments view | ✅ | ✅ | ✅ | ✅ | |
| Invoice — documents / attachments | ✅ | ✅ | ✅ | ✅ | |
| Invoice — e-invoice (UBL / Factur-X) | ✅ | ❌ | ✅ | ✅ | |
| Invoice — Peppol delivery | ✅ | ❌ | ✅ | ✅ | |
| Invoice — Verifactu (Spain) compliance | ✅ | ❌ | ✅ | ✅ | |
| Invoice — archive / restore / delete | ✅ | ✅ | ✅ | ✅ | |
| Invoice — bulk actions | ✅ | ✅ | ✅ | ✅ | |
| Invoice — import (CSV) | ✅ | 🟡 | ✅ | ✅ | |
| Invoice — custom fields | ✅ | ✅ | ✅ | ✅ | |
| Invoice — tags (attach via picker, list `tag_ids` filter + column, detail chips) | ✅ | — | ✅ | | |

---

## Quotes

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Quote — list | ✅ | ✅ | ✅ | ✅ | 🟡 |
| Quote — detail | ✅ | ✅ | ✅ | ✅ | ✅ |
| Quote — edit | ✅ | ✅ | ✅ | ✅ | |
| Quote — create | ✅ | ✅ | ✅ | ✅ | |
| Quote — clone to quote | ✅ | ✅ | ✅ | ✅ | |
| Quote — clone to invoice | ✅ | ✅ | ✅ | ✅ | |
| Quote — convert / approve to invoice | ✅ | ✅ | ✅ | ✅ | |
| Quote — mark sent | ✅ | ✅ | ✅ | ✅ | |
| Quote — email to client | ✅ | ✅ | ✅ | ✅ | |
| Quote — schedule email | ✅ | ❌ | ✅ | ✅ | |
| Quote — change template / design | ✅ | ✅ | ✅ | ✅ | |
| Quote — view / download PDF | ✅ | ✅ | ✅ | ✅ | |
| Quote — activities | ✅ | ✅ | ✅ | ✅ | |
| Quote — email history | ✅ | ✅ | ✅ | | |
| Quote — email bounce indicator + reactivate | ✅ | ✅ | ✅ | | |
| Quote — list bounce status badge | 🟡 | ✅ | ✅ | | |
| Quote — documents / attachments | ✅ | ✅ | ✅ | ✅ | |
| Quote — archive / restore / delete | ✅ | ✅ | ✅ | ✅ | |
| Quote — bulk actions | ✅ | ✅ | ✅ | ✅ | |
| Quote — import (CSV) | ✅ | 🟡 | ✅ | ✅ | |
| Quote — custom fields | ✅ | ✅ | ✅ | ✅ | |
| Quote — tags (attach via picker, list `tag_ids` filter + column, detail chips) | ✅ | — | ✅ | | |

---

## Credits

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Credit — list | ✅ | ✅ | ✅ | ✅ | 🟡 |
| Credit — detail | ✅ | ✅ | ✅ | ✅ | 🟡 |
| Credit — edit | ✅ | ✅ | ✅ | ✅ | |
| Credit — create | ✅ | ✅ | ✅ | ✅ | |
| Credit — clone to credit | ✅ | ✅ | ✅ | ✅ | |
| Credit — clone to invoice | ✅ | ❌ | ✅ | ✅ | |
| Credit — apply to invoice | ✅ | ✅ | ✅ | ✅ | |
| Credit — mark paid (negative credits) | ✅ | ✅ | ✅ | ✅ | |
| Credit — partial deposit / partial due date | ✅ | ✅ | ✅ | ✅ | |
| Credit — email to client | ✅ | ✅ | ✅ | ✅ | |
| Credit — email history | ✅ | ✅ | ✅ | | |
| Credit — email bounce indicator + reactivate | ✅ | ✅ | ✅ | | |
| Credit — list bounce status badge | 🟡 | ✅ | ✅ | | |
| Credit — change template / design | ✅ | ✅ | ✅ | ✅ | |
| Credit — view / download PDF | ✅ | ✅ | ✅ | ✅ | |
| Credit — activities | ✅ | ✅ | ✅ | ✅ | |
| Credit — e-invoice / Peppol | ✅ | ❌ | ✅ | ✅ | |
| Credit — documents / attachments | ✅ | ✅ | ✅ | ✅ | |
| Credit — archive / restore / delete | ✅ | ✅ | ✅ | ✅ | |
| Credit — bulk actions | ✅ | ✅ | ✅ | ✅ | |
| Credit — custom fields | ✅ | ✅ | ✅ | ✅ | |
| Credit — tags (attach via picker, list `tag_ids` filter + column, detail chips) | ✅ | — | ✅ | | |

---

## Recurring invoices

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Recurring invoice — list | ✅ | ✅ | ✅ | ✅ | 🟡 |
| Recurring invoice — detail | ✅ | ✅ | ✅ | ✅ | 🟡 |
| Recurring invoice — edit | ✅ | ✅ | ✅ | ✅ | |
| Recurring invoice — create | ✅ | ✅ | ✅ | ✅ | |
| Recurring invoice — clone | ✅ | ✅ | ✅ | ✅ | |
| Recurring invoice — start / activate | ✅ | ✅ | ✅ | ✅ | |
| Recurring invoice — stop / pause | ✅ | ✅ | ✅ | ✅ | |
| Recurring invoice — send now | ✅ | ✅ | ✅ | ✅ | |
| Recurring invoice — bulk update / increase prices | ✅ | ✅ | ✅ | ✅ | |
| Recurring invoice — filter by status | ✅ | ✅ | ✅ | ✅ | |
| Recurring invoice — change template / design | ✅ | ✅ | ✅ | ✅ | |
| Recurring invoice — view next-occurrence schedule | ✅ | ✅ | ✅ | ✅ | |
| Recurring invoice — view / download PDF | ✅ | ✅ | ✅ | ✅ | |
| Recurring invoice — activities | ✅ | ✅ | ✅ | ✅ | |
| Recurring invoice — email history | ✅ | ✅ | ✅ | | |
| Recurring invoice — email bounce indicator + reactivate | ✅ | ✅ | ✅ | | |
| Recurring invoice — documents / attachments | ✅ | ✅ | ✅ | ✅ | |
| Recurring invoice — e-invoice | ✅ | ❌ | ✅ | ✅ | |
| Recurring invoice — archive / restore / delete | ✅ | ✅ | ✅ | ✅ | |
| Recurring invoice — bulk actions | ✅ | ✅ | ✅ | ✅ | |
| Recurring invoice — import | ✅ | 🟡 | ✅ | ✅ | |
| Recurring invoice — custom fields | ✅ | ✅ | ✅ | ✅ | |
| Recurring invoice — tags (attach via picker, list `tag_ids` filter + column, detail chips) | ✅ | — | ✅ | | |

---

## Payments

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Payment — list | ✅ | ✅ | ✅ | ✅ | 🟡 |
| Payment — detail | ✅ | ✅ | ✅ | ✅ | ✅ |
| Payment — edit | ✅ | ✅ | ✅ | ✅ | |
| Payment — record manual payment | ✅ | ✅ | ✅ | ✅ | |
| Payment — apply to specific invoice | ✅ | ✅ | ✅ | ✅ | |
| Payment — refund (partial / full) | ✅ | ✅ | ✅ | ✅ | |
| Payment — email receipt | ✅ | ✅ | ✅ | ✅ | |
| Payment — view payment method / gateway used | ✅ | ✅ | ✅ | ✅ | |
| Payment — activities / audit trail | ✅ | ✅ | ✅ | ✅ | |
| Payment — documents / attachments | ✅ | ✅ | ✅ | ✅ | |
| Payment — archive / restore / delete | ✅ | ✅ | ✅ | ✅ | |
| Payment — bulk actions | ✅ | ✅ | ✅ | ✅ | |
| Payment — import (CSV) | ✅ | 🟡 | ✅ | ✅ | |
| Payment — custom fields | ✅ | ✅ | ✅ | ✅ | |
| Payment — tags (attach via picker, list `tag_ids` filter + column, detail chips) | ✅ | — | ✅ | | |

---

## Projects

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Project — list | ✅ | ✅ | ✅ | ✅ | 🟡 |
| Project — detail | ✅ | ✅ | ✅ | ✅ | ✅ |
| Project — edit | ✅ | ✅ | ✅ | ✅ | |
| Project — create | ✅ | ✅ | ✅ | ✅ | 🟡 |
| Project — clone | ✅ | ✅ | ✅ | ✅ | |
| Project — "New task" shortcut (prefills project) | ✅ | ✅ | ✅ | ✅ | |
| Project — view project tasks | ✅ | ✅ | ✅ | ✅ | |
| Project — invoice project (bill all tasks) | ✅ | ✅ | ✅ | ✅ | |
| Project — add project's tasks to an existing invoice (single + bulk) | ❌ | ❌ | ✅ | | |
| Project — run template | ✅ | ✅ | ✅ | ✅ | |
| Project — time summary | ✅ | ✅ | ✅ | ✅ | |
| Project — budget / hours-worked tracking | ✅ | ✅ | ✅ | ✅ | |
| Project — budgeted amount (money budget) | ❌ | ❌ | ✅ | | |
| Project — analytics tab (server burn-up + budget/invoice/profit/health) | ❌ | ❌ | 🟡 | | |
| Project — documents / attachments | ✅ | ✅ | ✅ | ✅ | |
| Project — activities | ✅ | ✅ | ✅ | ✅ | |
| Project — custom fields | ✅ | ✅ | ✅ | ✅ | |
| Project — tags (attach via picker, list `tag_ids` filter + column, local sort) | ✅ | — | ✅ | | |
| Project — archive / restore / delete / purge | ✅ | ✅ | ✅ | ✅ | |
| Project — bulk actions | ✅ | ✅ | ✅ | ✅ | |

---

## Tasks

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Task — list | ✅ | ✅ | ✅ | ✅ | 🟡 |
| Task — kanban board view | ✅ | ✅ | ✅ | ✅ | |
| Task — daily view | ✅ | ❌ | ✅ |  | |
| Task — weekly view | ✅ | ❌ | ✅ |  | |
| Task — calendar view | ✅ | ❌ | ✅ |  | |
| Task — connect Google/Microsoft calendar + convert event to task | ✅ | ❌ | 🟡 |  | |
| Task — detail | ✅ | ✅ | ✅ | ✅ | ✅ |
| Task — edit | ✅ | ✅ | ✅ | ✅ | |
| Task — create | ✅ | ✅ | ✅ | ✅ | 🟡 |
| Task — clone | ✅ | ✅ | ✅ | ✅ | |
| Task — timer start | ✅ | ✅ | ✅ | ✅ | |
| Task — timer stop | ✅ | ✅ | ✅ | ✅ | |
| Task — timer resume from time log | ✅ | ✅ | ✅ | ✅ | |
| Task — time-log entries (edit each row) | ✅ | ✅ | ✅ | ✅ | |
| Task — kanban drag-to-reorder within status | ✅ | ✅ | ✅ | ✅ | |
| Task — kanban filter by project / client / assignee | ✅ | ✅ | ✅ | ✅ | |
| Task — invoice from task | ✅ | ✅ | ✅ | ✅ | |
| Task — add to existing invoice | ✅ | ✅ | ✅ | | |
| Task — bulk invoice / add to invoice from a multi-select (multi-client rejected, multi-project grouped) | ✅ | ✅ | ✅ | | |
| Task — generated line items carry the project header + time-log details per Task Settings (`invoice_task_project` / `_project_header` / `_datelog` / `_timelog` / `_hours` / `_item_description`) | 🟡 | ✅ | ✅ | | |
| Task — list `client:` filter | ✅ | ✅ | ✅ | | |
| Task — status colors | ✅ | ✅ | ✅ | ✅ | |
| Task — colour-coded built-in statuses (Backlog / Ready to do / In progress / Done) | ❌ | ❌ | ✅ | | |
| Task — assignee | ✅ | ✅ | ✅ | ✅ | |
| Task — link to project (with project rate) | ✅ | ✅ | ✅ | ✅ | |
| Task — link to client | ✅ | ✅ | ✅ | ✅ | |
| Task — documents / attachments | ✅ | ✅ | ✅ | ✅ | |
| Task — activities | ✅ | ✅ | ✅ | ✅ | |
| Task — custom fields | ✅ | ✅ | ✅ | ✅ | |
| Task — tags (attach via picker, list `tag_ids` filter + column, local sort) | ✅ | — | ✅ | | |
| Task — archive / restore / delete / purge | ✅ | ✅ | ✅ | ✅ | |
| Task — bulk actions | ✅ | ✅ | ✅ | ✅ | |
| Task — import (CSV) | ✅ | 🟡 | ✅ | ✅ | |

---

## Vendors

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Vendor — list | ✅ | ✅ | ✅ | ✅ | 🟡 |
| Vendor — detail | ✅ | ✅ | ✅ | ✅ | ✅ |
| Vendor — edit | ✅ | ✅ | ✅ | ✅ | ✅ |
| Vendor — create | ✅ | ✅ | ✅ | ✅ | ✅ |
| Vendor — clone | ✅ | ❌ | ✅ | ✅ | |
| Vendor — ledger tab (expenses + POs spend roll-up) | — | — | ✅ | ✅ | |
| Vendor — comments / internal notes | ✅ | ✅ | ✅ | ✅ | |
| Vendor — documents / attachments | ✅ | ✅ | ✅ | ✅ | |
| Vendor — activities | ✅ | ✅ | ✅ | ✅ | |
| Vendor — "New expense / purchase order / recurring expense" shortcuts (prefill vendor) | ✅ | ✅ | ✅ | ✅ | |
| Vendor — merge into another vendor | ✅ | ✅ | ✅ | ✅ | |
| Vendor — portal link (open primary contact portal) | ✅ | ✅ | ✅ | ✅ | |
| Vendor — currency / language / classification / tax-exempt / routing id | ✅ | ✅ | ✅ | ✅ | |
| Vendor — custom fields | ✅ | ✅ | ✅ | ✅ | |
| Vendor — view vendor expenses / POs / recurring expenses | ✅ | ✅ | ✅ | ✅ | |
| Vendor — archive / restore / delete / purge | ✅ | ✅ | ✅ | ✅ | |
| Vendor — bulk actions | ✅ | ✅ | ✅ | ✅ | |
| Vendor — import (CSV) | ✅ | 🟡 | ✅ | ✅ | |
| Vendor — tags (attach via picker, list `tag_ids` filter + column, detail chips) | ✅ | — | ✅ | | |

---

## Purchase orders

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Purchase order — list | ✅ | ✅ | ✅ | ✅ | 🟡 |
| Purchase order — detail | ✅ | ✅ | ✅ | ✅ | 🟡 |
| Purchase order — edit | ✅ | ✅ | ✅ | ✅ | |
| Purchase order — create | ✅ | ✅ | ✅ | ✅ | |
| Purchase order — clone | ✅ | ✅ | ✅ | ✅ | |
| Purchase order — convert to expense | ✅ | ✅ | ✅ | ✅ | |
| Purchase order — view linked expense | ✅ | ✅ | ✅ | ✅ | |
| Purchase order — add to inventory (→ received) | ✅ | ✅ | ✅ | ✅ | |
| Purchase order — email to vendor | ✅ | ✅ | ✅ | ✅ | |
| Purchase order — schedule email | ✅ | ❌ | ✅ | ✅ | |
| Purchase order — mark sent | ✅ | ✅ | ✅ | ✅ | |
| Purchase order — accept (vendor-portal only; no admin action) | ✅ | ❌ | — | ✅ | |
| Purchase order — vendor portal link | ✅ | ✅ | ✅ | ✅ | |
| Purchase order — download e-purchase-order (e-invoice) | ✅ | ❌ | ✅ | | |
| Purchase order — change template / design | ✅ | ✅ | ✅ | ✅ | |
| Purchase order — view / download PDF | ✅ | ✅ | ✅ | ✅ | |
| Purchase order — activities | ✅ | ✅ | ✅ | ✅ | |
| Purchase order — email history | ✅ | ✅ | ✅ | | |
| Purchase order — email bounce indicator + reactivate | ✅ | ✅ | ✅ | | |
| Purchase order — list bounce status badge | 🟡 | ✅ | ✅ | | |
| Purchase order — documents / attachments | ✅ | ✅ | ✅ | ✅ | |
| Purchase order — archive / restore / delete | ✅ | ✅ | ✅ | ✅ | |
| Purchase order — bulk actions | ✅ | ✅ | ✅ | ✅ | |
| Purchase order — import | ✅ | 🟡 | ✅ | ✅ | |
| Purchase order — custom fields | ✅ | ✅ | ✅ | ✅ | |
| Purchase order — tags (attach via picker, list `tag_ids` filter + column, detail chips) | ✅ | — | ✅ | | |

---

## Expenses

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Expense — list | ✅ | ✅ | ✅ | ✅ | 🟡 |
| Expense — detail | ✅ | ✅ | ✅ | ✅ | ✅ |
| Expense — edit | ✅ | ✅ | ✅ | ✅ | |
| Expense — create | ✅ | ✅ | ✅ | ✅ | |
| Expense — clone | ✅ | ✅ | ✅ | ✅ | |
| Expense — clone to recurring expense | ✅ | ✅ | ✅ | ✅ | |
| Expense — categorize | ✅ | ✅ | ✅ | ✅ | |
| Expense — link to vendor | ✅ | ✅ | ✅ | ✅ | |
| Expense — link to project / client | ✅ | ✅ | ✅ | ✅ | |
| Expense — convert / add to invoice | ✅ | ✅ | ✅ | ✅ | |
| Expense — run template | ✅ | ✅ | ✅ | ✅ | |
| Expense — documents / receipts attachment | ✅ | ✅ | ✅ | ✅ | |
| Expense — comments | ✅ | ✅ | ✅ | ✅ | |
| Expense — activities | ✅ | ✅ | ✅ | ✅ | |
| Expense — custom fields | ✅ | ✅ | ✅ | ✅ | |
| Expense — archive / restore / delete / purge | ✅ | ✅ | ✅ | ✅ | |
| Expense — bulk actions | ✅ | ✅ | ✅ | ✅ | |
| Expense — import (CSV) | ✅ | 🟡 | ✅ | ✅ | |
| Expense — tags (attach via picker, list `tag_ids` filter + column, detail chips) | ✅ | — | ✅ | | |

---

## Recurring expenses

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Recurring expense — list | ✅ | ✅ | ✅ | ✅ | 🟡 |
| Recurring expense — detail | ✅ | ✅ | ✅ | ✅ | 🟡 |
| Recurring expense — edit | ✅ | ✅ | ✅ | ✅ | |
| Recurring expense — create | ✅ | ✅ | ✅ | ✅ | |
| Recurring expense — clone | ✅ | ✅ | ✅ | ✅ | |
| Recurring expense — clone to single expense | ✅ | ✅ | ✅ | ✅ | |
| Recurring expense — start / activate | ✅ | ✅ | ✅ | ✅ | |
| Recurring expense — stop / pause | ✅ | ✅ | ✅ | ✅ | |
| Recurring expense — frequency configuration | ✅ | ✅ | ✅ | ✅ | |
| Recurring expense — comments | ✅ | ✅ | ✅ | ✅ | |
| Recurring expense — documents | ✅ | ✅ | ✅ | ✅ | |
| Recurring expense — activities | ✅ | ✅ | ✅ | ✅ | |
| Recurring expense — custom fields | ✅ | ✅ | ✅ | ✅ | |
| Recurring expense — archive / restore / delete / purge | ✅ | ✅ | ✅ | ✅ | |
| Recurring expense — bulk actions | ✅ | ✅ | ✅ | ✅ | |
| Recurring expense — tags (attach via picker, list `tag_ids` filter + column, detail chips) | ✅ | — | ✅ | | |

---

## Bank transactions

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Bank transaction — list | ✅ | ✅ | ✅ | ✅ | 🟡 |
| Bank transaction — create | ✅ | ✅ | ✅ | ✅ | |
| Bank transaction — edit / categorize | ✅ | ✅ | ✅ | ✅ | |
| Bank transaction — import (CSV) | ✅ | ✅ | ✅ | ✅ | |
| Bank transaction — import (OFX / QIF / QFX) | ✅ | ✅ | ❌ |  | |
| Bank transaction — match to invoice (Create Payment) | ✅ | ✅ | ✅ | ✅ | |
| Bank transaction — link existing payment | ✅ | ✅ | ✅ | ✅ | |
| Bank transaction — match to expense | ✅ | ✅ | ✅ | ✅ | |
| Bank transaction — link existing expense | ✅ | ✅ | ✅ | ✅ | |
| Bank transaction — transaction rules (auto-match) | ✅ | ✅ | ✅ | ✅ | |
| Bank transaction — bulk archive / restore / delete | ✅ | ✅ | ✅ | ✅ | |
| Bank transaction — bulk convert / unlink | ✅ | ✅ | ✅ | ✅ | |
| Bank account — read-only detail with embedded transactions | ✅ | ✅ | ✅ | ✅ | |
| Bank transaction — tags (attach via picker, list `tag_ids` filter + column, detail chips) | ✅ | — | ✅ | | |

---

## Products

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Product — list | ✅ | ✅ | ✅ | ✅ | 🟡 |
| Product — detail | ✅ | ✅ | ✅ | ✅ | ✅ |
| Product — edit | ✅ | ✅ | ✅ | ✅ | |
| Product — create | ✅ | ✅ | ✅ | ✅ | ✅ |
| Product — clone | ✅ | ✅ | ✅ | ✅ | |
| Product — new invoice / quote / purchase order (prefills product) | ✅ | ✅ | ✅ | | |
| Product — set tax category | ✅ | ✅ | ✅ | | |
| Product — documents / attachments | ✅ | ✅ | ✅ | ✅ | |
| Product — tax category | ✅ | ✅ | ✅ | ✅ | |
| Product — stock / inventory tracking | ✅ | 🟡 | ✅ | ✅ | |
| Product — stock shown when selecting products (invoice line items) | ✅ | ✅ | ✅ | | |
| Product — low-stock / out-of-stock list filter + row highlight | — | — | ✅ | | |
| Product — stock value (qty × price) column + detail row | — | — | ✅ | | |
| Product — custom fields | ✅ | ✅ | ✅ | ✅ | |
| Product — activities | ✅ | ✅ | ✅ | ✅ | |
| Product — archive / restore / delete / purge | ✅ | ✅ | ✅ | ✅ | |
| Product — bulk actions | ✅ | ✅ | ✅ | ✅ | |
| Product — import (CSV) | ✅ | 🟡 | ✅ | ✅ | |
| Product — tags (attach via picker, list `tag_ids` filter + column, detail chips) | ✅ | — | ✅ | | |

---

## Documents (DocuNinja)

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| DocuNinja — document list | ✅ | ❌ | ❌ |  | |
| DocuNinja — create document | ✅ | ❌ | ❌ |  | |
| DocuNinja — create blueprint / template | ✅ | ❌ | ❌ |  | |
| DocuNinja — drag-and-drop document builder | ✅ | ❌ | ❌ |  | |
| DocuNinja — signature field mapping | ✅ | ❌ | ❌ |  | |
| DocuNinja — sign document | ✅ | ❌ | ❌ |  | |
| DocuNinja — PDF preview / render | ✅ | ❌ | ❌ |  | |
| DocuNinja — user management for docs | ✅ | ❌ | ❌ |  | |
| DocuNinja — document email templates | ✅ | ❌ | ❌ |  | |
| DocuNinja — delete document | ✅ | ❌ | ❌ |  | |

---

## Reports

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Report — activity | ✅ | ✅ | ✅ | ✅ | |
| Report — client | ✅ | ✅ | ✅ | ✅ | ✅ |
| Report — contact | ✅ | ✅ | ✅ | ✅ | |
| Report — credit | ✅ | ✅ | ✅ | ✅ | |
| Report — document | ✅ | 🟡 | ✅ | ✅ | |
| Report — expense | ✅ | ✅ | ✅ | ✅ | |
| Report — invoice | ✅ | ✅ | ✅ | ✅ | |
| Report — invoice item | ✅ | ✅ | ✅ | ✅ | |
| Report — quote | ✅ | ✅ | ✅ | ✅ | |
| Report — quote item | ✅ | ✅ | ✅ | ✅ | |
| Report — recurring invoice | ✅ | ✅ | ✅ | ✅ | |
| Report — recurring invoice item | ✅ | 🟡 | ✅ | ✅ | |
| Report — payment | ✅ | ✅ | ✅ | ✅ | |
| Report — product | ✅ | ✅ | ✅ | ✅ | |
| Report — product sales | ✅ | ✅ | ✅ | ✅ | |
| Report — product inventory valuation total (stock value) | — | — | ✅ | | |
| Report — task | ✅ | ✅ | ✅ | ✅ | |
| Report — tag filter (task + project reports → `tag_ids`) | ✅ | — | ✅ | | |
| Report — vendor | ✅ | ✅ | ✅ | ✅ | |
| Report — purchase order | ✅ | ✅ | ✅ | ✅ | |
| Report — purchase order item | ✅ | 🟡 | ✅ | ✅ | |
| Report — profit / loss | ✅ | ✅ | ✅ | ✅ | |
| Report — client balance | ✅ | ✅ | ✅ | ✅ | |
| Report — client sales | ✅ | ✅ | ✅ | ✅ | |
| Report — aged receivable (detailed) | ✅ | ✅ | ✅ | ✅ | |
| Report — aged receivable (summary) | ✅ | ✅ | ✅ | ✅ | |
| Report — user sales | ✅ | 🟡 | ✅ | ✅ | |
| Report — tax summary | ✅ | ✅ | ✅ | ✅ | |
| Report — tax period | ✅ | ❌ | ✅ | ✅ | |
| Report — project | ✅ | ✅ | ✅ | ✅ | |
| Report — custom column selection | ✅ | ✅ | ✅ | ✅ | |
| Report — date range filters (preset + custom) | ✅ | ✅ | ✅ | ✅ | |
| Report — export to PDF / CSV | ✅ | ✅ | ✅ | ✅ | |
| Report — email-scheduled delivery | ✅ | 🟡 | ✅ | ✅ | |
| Report — grouping by dimension | ✅ | ✅ | ✅ | ✅ | |
| Report — multi-entity filtering | ✅ | ✅ | ✅ | ✅ | |
| Report — typed status filter (multi-select) | ✅ | ✅ | ✅ | — | |
| Report — currency-aware grand totals | — | ✅ | ✅ | — | |
| Report — column reorder | ✅ | ❌ | ✅ | — | |
| Report — per-column table filters (type-aware) | ❌ | ✅ | ✅ | — | |
| Report — chart (bar + time-series) | ❌ | ✅ | ✅ | — | |

---

## Settings — Basic

Field-level breakdown of every option under each settings panel. Source of truth for v2: `lib/ui/features/settings/settings_search_catalog.dart` and the per-screen `kFooSearchKeys` constants colocated next to each screen. Multi-tab panels are split per-tab.

### Company Details

#### Company Details — Details tab

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Name | ✅ | ✅ | ✅ | ✅ | |
| ID Number | ✅ | ✅ | ✅ | ✅ | |
| VAT Number | ✅ | ✅ | ✅ | ✅ | |
| QR IBAN (Swiss only) | ✅ | ✅ | ✅ | ✅ | |
| BESR ID (Swiss only) | ✅ | ✅ | ✅ | ✅ | |
| Website | ✅ | ✅ | ✅ | ✅ | |
| Email | ✅ | ✅ | ✅ | ✅ | |
| Phone | ✅ | ✅ | ✅ | ✅ | |
| Classification (dropdown) | ✅ | ✅ | ✅ | ✅ | |
| Size (dropdown) | ✅ | ✅ | ✅ | ✅ | |
| Industry (dropdown) | ✅ | ✅ | ✅ | ✅ | |

#### Company Details — Address tab

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Address 1 | ✅ | ✅ | ✅ | ✅ | |
| Address 2 | ✅ | ✅ | ✅ | ✅ | |
| City | ✅ | ✅ | ✅ | ✅ | |
| State / Province | ✅ | ✅ | ✅ | ✅ | |
| Postal Code | ✅ | ✅ | ✅ | ✅ | |
| Country | ✅ | ✅ | ✅ | ✅ | |

#### Company Details — Logo tab

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Logo upload | ✅ | ✅ | ✅ | ✅ | |
| Logo crop / size | ✅ | ✅ | ✅ | ✅ | |

#### Company Details — Defaults tab

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Invoice Terms (markdown) | ✅ | ✅ | ✅ | ✅ | |
| Invoice Footer (markdown) | ✅ | ✅ | ✅ | ✅ | |
| Quote Terms (markdown) | ✅ | ✅ | ✅ | ✅ | |
| Quote Footer (markdown) | ✅ | ✅ | ✅ | ✅ | |
| Credit Terms (markdown) | ✅ | ✅ | ✅ | ✅ | |
| Credit Footer (markdown) | ✅ | ✅ | ✅ | ✅ | |
| Purchase Order Terms (markdown) | ✅ | ✅ | ✅ | ✅ | |
| Purchase Order Footer (markdown) | ✅ | ✅ | ✅ | ✅ | |

#### Company Details — Documents tab

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Document upload | ✅ | ✅ | ✅ | ✅ | |
| Document list / preview | ✅ | ✅ | ✅ | ✅ | |
| Document download | ✅ | ✅ | ✅ | ✅ | |
| Document delete | ✅ | ✅ | ✅ | ✅ | |
| Documents public by default (company setting) | ❌ | ✅ | ✅ | | |

#### Company Details — Custom Fields tab

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Custom Field 1 (label + type) | ✅ | ✅ | ✅ | ✅ | |
| Custom Field 2 (label + type) | ✅ | ✅ | ✅ | ✅ | |
| Custom Field 3 (label + type) | ✅ | ✅ | ✅ | ✅ | |
| Custom Field 4 (label + type) | ✅ | ✅ | ✅ | ✅ | |

### User Details

#### User Details — Details tab

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| First Name | ✅ | ✅ | ✅ | ✅ | |
| Last Name | ✅ | ✅ | ✅ | ✅ | |
| Email | ✅ | ✅ | ✅ | ✅ | |
| Phone | ✅ | ✅ | ✅ | ✅ | |
| Document Language | ✅ | ✅ | ✅ | ✅ | |
| Signature (image / text) | ✅ | ✅ | ✅ | ✅ | |
| Sign Out (action) | ✅ | ✅ | ✅ | ✅ | |

#### User Details — Password tab

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Current Password | ✅ | ✅ | ✅ | ✅ | |
| New Password | ✅ | ✅ | ✅ | ✅ | |
| Confirm Password | ✅ | ✅ | ✅ | ✅ | |

#### User Details — Connect tab

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Connect Google (OAuth) | ✅ | ✅ | ✅ | ✅ | |
| Connect Microsoft (OAuth) | ✅ | ✅ | ❌ | ✅ | |
| Connect Gmail (OAuth) | ✅ | ✅ | ❌ | ✅ | |
| Connect Email (OAuth) | ✅ | ✅ | ❌ | ✅ | |
| Disconnect | ✅ | ✅ | ✅ | ✅ | |

> v2 Connect tab supports **Google connect** (in-app) + **all disconnects** (OAuth + mailer) only. Connecting Microsoft OAuth and the email mailer (Gmail/Outlook send-on-behalf) are intentionally not implemented — no native MSAL and no in-app OAuth callback handler. Accepted pre-launch limitation.

#### User Details — Two-Factor tab

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Enable Two-Factor Authentication | ✅ | ✅ | ✅ | ✅ | |
| Two-factor setup / verification | ✅ | ✅ | ✅ | ✅ | |

#### User Details — Notifications tab

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| All Events (master toggle) | ✅ | ✅ | ✅ | ✅ | |
| All Notifications (master toggle) | ✅ | ✅ | ✅ | ✅ | |
| User Logged In | ✅ | ✅ | ✅ | ✅ | |
| Task Assigned | ✅ | ✅ | ✅ | ✅ | |
| Disable Recurring Payment Notification | ✅ | ✅ | ✅ | ✅ | |
| E-Invoice Received | ✅ | ✅ | ✅ | ✅ | |
| Invoice Created | ✅ | ✅ | ✅ | ✅ | |
| Invoice Sent | ✅ | ✅ | ✅ | ✅ | |
| Invoice Viewed | ✅ | ✅ | ✅ | ✅ | |
| Invoice Late | ✅ | ✅ | ✅ | ✅ | |
| Payment Success | ✅ | ✅ | ✅ | ✅ | |
| Payment Failure | ✅ | ✅ | ✅ | ✅ | |
| Payment Manual | ✅ | ✅ | ✅ | ✅ | |
| Quote Created | ✅ | ✅ | ✅ | ✅ | |
| Quote Sent | ✅ | ✅ | ✅ | ✅ | |
| Quote Viewed | ✅ | ✅ | ✅ | ✅ | |
| Quote Approved | ✅ | ✅ | ✅ | ✅ | |
| Quote Expired | ✅ | ✅ | ✅ | ✅ | |
| Quote Rejected | ✅ | ✅ | ✅ | ✅ | |
| Credit Created | ✅ | ✅ | ✅ | ✅ | |
| Credit Sent | ✅ | ✅ | ✅ | ✅ | |
| Credit Viewed | ✅ | ✅ | ✅ | ✅ | |
| Purchase Order Created | ✅ | ✅ | ✅ | ✅ | |
| Purchase Order Sent | ✅ | ✅ | ✅ | ✅ | |
| Purchase Order Viewed | ✅ | ✅ | ✅ | ✅ | |
| Purchase Order Accepted | ✅ | ✅ | ✅ | ✅ | |
| Inventory Threshold | ✅ | ✅ | ✅ | ✅ | |

#### User Details — Preferences tab

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Theme (light / dark / system) | ✅ | ✅ | ✅ | ✅ | |
| Customizable presets (per light/dark colour overrides) | — | — | ✅ | ✅ | |
| App Language | ✅ | ✅ | ✅ | ✅ | |
| Accent Color | ✅ | ✅ | ✅ | ✅ | |

### Localization

#### Localization — Settings tab

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Currency | ✅ | ✅ | ✅ | ✅ | |
| Currency Format (symbol / position / decimals) | ✅ | ✅ | ✅ | ✅ | |
| Language | ✅ | ✅ | ✅ | ✅ | |
| Timezone | ✅ | ✅ | ✅ | ✅ | |
| Date Format | ✅ | ✅ | ✅ | ✅ | |
| Military / 24-hour time | ✅ | ✅ | ✅ | ✅ | |
| Rappen Rounding (Swiss) | ✅ | ✅ | ✅ | ✅ | |
| Decimal Comma | ✅ | ✅ | ✅ | ✅ | |
| First Month of the Year (fiscal start) | ✅ | ✅ | ✅ | ✅ | v2 now drives dashboard This/Last Year + report year grouping onto the fiscal year (was a stored-but-inert field); quarters stay calendar-aligned, matching React/v1 |
| First Day of the Week (week start) | ❌ | 🟡 | ✅ | ✅ | v1 dropdown is commented out + the value is unused; React has no such setting. v2 adds the control and honors it in dashboard chart weeks, report week grouping, and the date-range calendar grid |

#### Localization — Custom Labels tab

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Predefined label overrides (~40 keys: address, amount, balance, country, credit, date, description, discount, due date, email, hours, ID number, invoice, item, line total, paid to date, partial due, phone, PO number, product, quantity, quote, rate, statement, subtotal, surcharge, tax, terms, total, unit cost, valid until, VAT number, website, etc.) | ✅ | ✅ | ✅ | ✅ | |
| Free-form custom labels | ✅ | ✅ | ✅ | ✅ | |
| Country-specific label aliases | ✅ | ✅ | ✅ | ✅ | |

### Online Payments

#### Online Payments — General tab

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Auto Bill Standard Invoices | ✅ | ✅ | ✅ | ✅ | |
| Auto Bill Recurring Invoices | ✅ | ✅ | ✅ | ✅ | |
| Auto Bill On (dropdown) | ✅ | ✅ | ✅ | ✅ | |
| Use Available Payments | ✅ | ✅ | ✅ | ✅ | |
| Use Available Credits | ✅ | ✅ | ✅ | ✅ | |
| Configure Gateways (link) | ✅ | ✅ | ✅ | ✅ | |
| Admin Initiated Payments | ✅ | ✅ | ✅ | ✅ | |
| Client Initiated Payments | ✅ | ✅ | ✅ | ✅ | |
| Minimum Payment Amount | ✅ | ✅ | ✅ | ✅ | |
| Allow Over Payment | ✅ | ✅ | ✅ | ✅ | |
| Allow Under Payment | ✅ | ✅ | ✅ | ✅ | |
| Minimum Under Payment Amount | ✅ | ✅ | ✅ | ✅ | |
| Convert Currency | ✅ | ✅ | ✅ | ✅ | |
| One Page Checkout | ✅ | ✅ | ✅ | ✅ | |
| Unlock Invoice Documents After Payment | ✅ | ✅ | ✅ | ✅ | |

#### Online Payments — Defaults tab

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Default Payment Type | ✅ | ✅ | ✅ | ✅ | |
| Default Expense Payment Type | ✅ | ✅ | ✅ | ✅ | |
| Invoice Payment Terms | ✅ | ✅ | ✅ | ✅ | |
| Quote Valid Until | ✅ | ✅ | ✅ | ✅ | |
| Configure Payment Terms (link) | ✅ | ✅ | ✅ | ✅ | |

#### Online Payments — Emails tab

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Online Payment Email | ✅ | ✅ | ✅ | ✅ | |
| Manual Payment Email | ✅ | ✅ | ✅ | ✅ | |
| Mark Paid Payment Email | ✅ | ✅ | ✅ | ✅ | |
| Send Emails To (all contacts / primary) | ✅ | ✅ | ✅ | ✅ | |

### Tax Settings

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Invoice Tax Rates (0 / 1 / 2 / 3) | ✅ | ✅ | ✅ | ✅ | |
| Invoice Item Tax Rates (0 / 1 / 2 / 3) | ✅ | ✅ | ✅ | ✅ | |
| Expense Tax Rates (0 / 1 / 2 / 3) | ✅ | ✅ | ✅ | ✅ | |
| Inclusive Taxes toggle | ✅ | ✅ | ✅ | ✅ | |
| Tax Name (per rate) | ✅ | ✅ | ✅ | ✅ | |
| Tax Rate percentage (per rate) | ✅ | ✅ | ✅ | ✅ | |
| Calculate Taxes (auto / manual) | ✅ | ✅ | ✅ | ✅ | |
| Seller Subregion (EU VAT) | ✅ | ✅ | ✅ | ✅ | |
| Reduced Rate (per region, when Calculate Taxes on) | ✅ | ✅ | ✅ | ✅ | |
| Tax rate CRUD (manage rate list) | ✅ | ✅ | ✅ | ✅ | 🟡 |

### Product Settings

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Track Inventory | ✅ | ✅ | ✅ | ✅ | |
| Stock Notifications | ✅ | ✅ | ✅ | ✅ | |
| Notification Threshold (when Stock Notifications on) | ✅ | ✅ | ✅ | ✅ | |
| Show Product Discount | ✅ | ✅ | ✅ | ✅ | |
| Show Product Cost | ✅ | ✅ | ✅ | ✅ | |
| Show Product Quantity | ✅ | ✅ | ✅ | ✅ | |
| Default Quantity | ✅ | ✅ | ✅ | ✅ | |
| Show Product Description | ✅ | ✅ | ✅ | ✅ | |
| Fill Products | ✅ | ✅ | ✅ | ✅ | |
| Update Products | ✅ | ✅ | ✅ | ✅ | |
| Convert Products | ✅ | ✅ | ✅ | ✅ | |
| Convert To (currency, when Convert Products on) | ✅ | ✅ | ✅ | ✅ | |

### Task Settings

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Default Task Rate | ✅ | ✅ | ✅ | ✅ | |
| Auto Start Tasks | ✅ | ✅ | ✅ | ✅ | |
| Show Task End Date | ✅ | ✅ | ✅ | ✅ | |
| Show Task Item Description | ✅ | ✅ | ✅ | ✅ | |
| Show Task Billable | ✅ | ✅ | ✅ | ✅ | |
| Round Tasks | ✅ | ✅ | ✅ | ✅ | |
| Rounding Direction (up / down, when Round Tasks on) | ✅ | ✅ | ✅ | ✅ | |
| Task Round To Nearest (preset seconds / custom) | ✅ | ✅ | ✅ | ✅ | |
| Round To Seconds (when "Custom" selected) | ✅ | ✅ | ✅ | ✅ | |
| Configure Statuses (link) | ✅ | ✅ | ✅ | ✅ | |
| Manage Tags (Settings → Tags; list / create / edit / recolor / archive, entity-type picker over all 14 tag-bearing types, admin-gated) | ✅ | — | ✅ | | |
| Show Tasks Table | ✅ | ✅ | ✅ | ✅ | |
| Invoice Task Datelog | ✅ | ✅ | ✅ | ✅ | |
| Invoice Task Timelog | ✅ | ✅ | ✅ | ✅ | |
| Invoice Task Hours | ✅ | ✅ | ✅ | ✅ | |
| Invoice Task Item Description | ✅ | ✅ | ✅ | ✅ | |
| Invoice Task Project | ✅ | ✅ | ✅ | ✅ | |
| Project Location | ✅ | ✅ | ✅ | ✅ | |
| Lock Invoiced Tasks | ✅ | ✅ | ✅ | ✅ | |
| Add Documents to Invoice | ✅ | ✅ | ✅ | ✅ | |
| Show Tasks in Client Portal | ✅ | ✅ | ✅ | ✅ | |
| Tasks Shown in Portal | ✅ | ✅ | ✅ | ✅ | |

### Expense Settings

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Should Be Invoiced (default invoiceable) | ✅ | ✅ | ✅ | ✅ | |
| Mark Paid (default) | ✅ | ✅ | ✅ | ✅ | |
| Default Expense Payment Type | ✅ | ✅ | ✅ | ✅ | |
| Convert Currency | ✅ | ✅ | ✅ | ✅ | |
| Add Documents to Invoice | ✅ | ✅ | ✅ | ✅ | |
| Notify Vendor When Paid | ✅ | ✅ | ✅ | ✅ | |
| Expense Mailbox Active | ✅ | ✅ | ✅ | ✅ | |
| Expense Mailbox (email address) | ✅ | ✅ | ✅ | ✅ | |
| Inbound Mailbox — Allow Company Users | ✅ | ✅ | ✅ | ✅ | |
| Inbound Mailbox — Allow Vendors | ✅ | ✅ | ✅ | ✅ | |
| Inbound Mailbox — Allow Clients | ✅ | ✅ | ✅ | ✅ | |
| Inbound Mailbox — Whitelist | ✅ | ✅ | ✅ | ✅ | |
| Inbound Mailbox — Blacklist | ✅ | ✅ | ✅ | ✅ | |
| Inbound Mailbox — Allow Unknown | ✅ | ✅ | ✅ | ✅ | |
| Enter Taxes | ✅ | ✅ | ✅ | ✅ | |
| Inclusive Taxes | ✅ | ✅ | ✅ | ✅ | |
| Configure Categories (link) | ✅ | ✅ | ✅ | ✅ | |

### Workflow Settings

#### Workflow Settings — Invoices tab

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Auto Email Invoice | ✅ | ✅ | ✅ | ✅ | |
| Stop on Unpaid | ✅ | ✅ | ✅ | ✅ | |
| Auto Archive Paid Invoices | ✅ | ✅ | ✅ | ✅ | |
| Auto Archive Cancelled Invoices | ✅ | ✅ | ✅ | ✅ | |
| Lock Invoices (off / when sent / when paid / end of month) | ✅ | ✅ | ✅ | ✅ | Enforced: client-side cascade computation hard-blocks edit entry (action menu + deep-link guard) + repo/outbox backstop; reason-specific dialog/banner |
| Global Tag Inheritance | — | — | ✅ |  | Company-level toggle (`settings.global_tag_inheritance`), company scope only — server reads it via `Company::getSetting()`, no client/group cascade. Server applies the tag cascade on entity create (`BaseRepository`); client only persists the flag. App now surfaces tags on all 14 tag-bearing entities, so the inherited tags are visible across the board |

#### Workflow Settings — Quotes tab

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Auto Convert Quote | ✅ | ✅ | ✅ | ✅ | |
| Auto Archive Quote | ✅ | ✅ | ✅ | ✅ | |
| Use Quote Terms | ✅ | ✅ | ✅ | ✅ | |

### Account Management

#### Account Management — Plan

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Plan tier (Free / Pro / Enterprise) | ✅ | ✅ | ✅ | ✅ | |
| Free trial banner | ✅ | ✅ | ✅ | ✅ | |
| Plan expires-on date | ✅ | ✅ | ✅ | ✅ | |
| Days-left countdown | ✅ | ✅ | ✅ | ✅ | |
| Change Plan (action) | ✅ | ✅ | ✅ | ✅ | |
| Upgrade Plan (action) | ✅ | ✅ | ✅ | ✅ | |
| Pro/Enterprise gating: advanced-settings banner + field disable | ✅ | ✅ | ✅ | ✅ | |
| Pro/Enterprise gating: sidebar lock icons + search-result tier chips | ✅ | — | ✅ | ✅ | |
| Pro/Enterprise gating: trial-aware (trialing users keep paid features) | ✅ | ✅ | ✅ | ✅ | |
| Self-hosted license state (White labeled vs Free) | ✅ | 🟡 | ✅ | | |
| Pro/Enterprise gating: single source of truth (`domain/plan_gate.dart`) | — | — | ✅ | ✅ | |
| Reports gated at Pro on hosted (banner + disabled Run/Export/Email) | ✅ | ✅ | ✅ | ✅ | |
| Document/attachment upload gated at Enterprise on hosted | ✅ | ✅ | ✅ | ✅ | |
| E-invoice settings gated at Enterprise on hosted | ✅ | — | ✅ | ✅ | |
| State-aware upgrade copy (trial / trialing / expired-renew / upgrade) | ✅ | ✅ | ✅ | ✅ | |
| Hosted upgrade via App Store / Play IAP (web/desktop → portal) | — | ✅ | 🟡 | ✅ | |
| `premium_business_plus` / `white_label` treated as full paid tiers | — | — | ✅ | ✅ | |
| Trial-expires-soon urgent footer (≤3 days) | ✅ | ✅ | ✅ | ✅ | |
| Purchase License (self-hosted white label) | ✅ | ✅ | ✅ | ✅ | |
| Apply License (redeem key) | ✅ | ✅ | ✅ | ✅ | |
| Renew a lapsed white-label license | — | — | ✅ | | |
| Purchase White Label CTA in shell chrome (self-hosted, unlicensed, admin) | ✅ | ✅ | ✅ | | |

#### Account Management — Overview

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Account ID (read-only) | ✅ | ✅ | ✅ | ✅ | |
| Account email (read-only) | ✅ | ✅ | ✅ | ✅ | |
| Set Default Company | ✅ | ✅ | ✅ | ✅ | |
| Activate / deactivate company | ✅ | ✅ | ✅ | ✅ | |
| Enable PDF Markdown | ✅ | ✅ | ✅ | ✅ | |
| Enable Email Markdown | ✅ | ✅ | ✅ | ✅ | |
| Include Drafts in lists | ✅ | ✅ | ✅ | ✅ | |
| Include Deleted in lists | ✅ | ✅ | ✅ | ✅ | |
| Force Full Sync | ✅ | ✅ | ✅ | ✅ | |

#### Account Management — Enabled Modules

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Module toggles (invoices, recurring, quotes, credits, projects, tasks, vendors, POs, expenses, recurring expenses) | ✅ | ✅ | ✅ | ✅ | |

#### Account Management — Integrations

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Google Analytics Tracking ID | ✅ | ✅ | ✅ | ✅ | |
| Matomo Site ID | ✅ | ✅ | ✅ | ✅ | |
| Matomo URL | ✅ | ✅ | ✅ | ✅ | |
| API Tokens (CRUD) | ✅ | ✅ | ✅ | ✅ | |
| API Webhooks (CRUD) | ✅ | ✅ | ✅ | ✅ | |
| API Docs (link) | ✅ | ✅ | ✅ | ✅ | |
| Zapier integration | ✅ | ✅ | ✅ | ✅ | |
| QuickBooks integration | ✅ | ❌ | ✅ | ✅ | |
| QuickBooks — 10-entity sync directions + import + income/tax mapping | ✅ | ❌ | ✅ | | |

#### Account Management — Security

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Password Timeout | ✅ | ✅ | ✅ | ✅ | |
| Web Session Timeout | ✅ | ✅ | ✅ | ✅ | |
| Require Password with Social Login | ✅ | ✅ | ✅ | ✅ | |
| End All Sessions (action) | ✅ | ✅ | ✅ | ✅ | |

#### Account Management — Referral

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Referral Program (enable) | ✅ | ✅ | ✅ | ✅ | |
| Referral Code (read / copy) | ✅ | ✅ | ✅ | ✅ | |
| Hidden on self-hosted | ✅ | 🟡 | ✅ | | |

#### Account Management — Danger Zone

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Purge Data (clear all company data) | ✅ | ✅ | ✅ | ✅ | |
| Delete Company | ✅ | ✅ | ✅ | ✅ | |
| Cancel Account (close account entirely) | ✅ | ✅ | ✅ | ✅ | |

### Backup & Restore

#### Backup & Restore — Backup tab

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Backup (email download link) | ✅ | ✅ | ✅ | ✅ | |

#### Backup & Restore — Restore tab

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Restore (.zip upload) | ✅ | 🟡 | ✅ | ✅ | |
| Export (action) | ✅ | 🟡 | ✅ | ✅ | |
| Import Settings (file upload) | ✅ | ❌ | ✅ | ✅ | |
| Import Data (file upload) | ✅ | 🟡 | ✅ | ✅ | |
| Company Backup File (display) | ✅ | 🟡 | ✅ | ✅ | |

### Import & Export

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Import — CSV (per-entity column mapping) | ✅ | 🟡 | ✅ | ✅ | |
| Import — third-party (FreshBooks / Invoice2Go / Invoicely / Wave / Zoho / QuickBooks) | ✅ | ✅ | ✅ | ✅ | |
| Import — company migration (.zip / .json) | ✅ | ✅ | ✅ | ✅ | |
| Export — CSV (per-entity, date-range filter) | ✅ | ✅ | ✅ | ✅ | |
| Export — CSV options (attach documents, include deleted) | ❌ | ✅ | ✅ | ✅ | |

### Device Settings

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Theme (light / dark / system, local) | — | ✅ | ✅ | ✅ | |
| Font Size (text scale, local) | — | ✅ | ✅ | ✅ | |
| Biometric Authentication toggle | — | ✅ | ✅ | ✅ | |
| Sync (pushes queued edits, re-downloads, shows last-updated) | — | ✅ | ✅ | ✅ | ✅ |

---

## Settings — Advanced

Field-level breakdown of every option under each advanced settings panel. Source of truth for v2: `lib/ui/features/settings/settings_search_catalog.dart` and per-screen `kFooSearchKeys` constants.

### Invoice Design

#### Invoice Design — General Settings tab

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Invoice Design (template picker) | ✅ | ✅ | ✅ | ✅ | |
| Quote Design | ✅ | ✅ | ✅ | ✅ | |
| Credit Design | ✅ | ✅ | ✅ | ✅ | |
| Purchase Order Design | ✅ | ✅ | ✅ | ✅ | |
| Delivery Note Design | ✅ | ✅ | ✅ | ✅ | |
| Statement Design | ✅ | ✅ | ✅ | ✅ | |
| Payment Receipt Design | ✅ | ✅ | ✅ | ✅ | |
| Payment Refund Design | ✅ | ✅ | ✅ | ✅ | |
| "Update all records" on design change → POST /designs/set/default (all scopes: company / group / client) | ✅ | ✅ | ✅ | | |
| Page Layout (portrait / landscape) | ✅ | ✅ | ✅ | ✅ | |
| Page Size (A4 / Letter / etc.) | ✅ | ✅ | ✅ | ✅ | |
| Font Size | ✅ | ✅ | ✅ | ✅ | |
| Logo Size | ✅ | ✅ | ✅ | ✅ | |
| Primary Font | ✅ | ✅ | ✅ | ✅ | |
| Secondary Font | ✅ | ✅ | ✅ | ✅ | |
| Primary Color | ✅ | ✅ | ✅ | ✅ | |
| Secondary Color | ✅ | ✅ | ✅ | ✅ | |
| Show Paid Stamp | ✅ | ✅ | ✅ | ✅ | |
| Show Shipping Address | ✅ | ✅ | ✅ | ✅ | |
| Share Invoice Quote Columns | ✅ | ✅ | ✅ | ✅ | |
| Empty Columns (hide / show) | ✅ | ✅ | ✅ | ✅ | |
| Page Numbering | ✅ | ✅ | ✅ | ✅ | |
| Page Numbering Alignment | ✅ | ✅ | ✅ | ✅ | |
| Invoice Embed Documents | ✅ | ✅ | ✅ | ✅ | |

#### Invoice Design — PDF Variable tabs

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Client Details columns | ✅ | ✅ | ✅ | ✅ | |
| Company Details columns | ✅ | ✅ | ✅ | ✅ | |
| Company Address columns | ✅ | ✅ | ✅ | ✅ | |
| Invoice Details columns | ✅ | ✅ | ✅ | ✅ | |
| Quote Details columns | ✅ | ✅ | ✅ | ✅ | |
| Credit Details columns | ✅ | ✅ | ✅ | ✅ | |
| Vendor Details columns | ✅ | ✅ | ✅ | ✅ | |
| Purchase Order Details columns | ✅ | ✅ | ✅ | ✅ | |
| Product Columns selector | ✅ | ✅ | ✅ | ✅ | |
| Quote Product Columns selector | ✅ | ✅ | ✅ | ✅ | |
| Task Columns selector | ✅ | ✅ | ✅ | ✅ | |
| Total Fields selector | ✅ | ✅ | ✅ | ✅ | |
| Reset field list to default — per tab, restores backend `getEntityVariableDefaults` | — | — | ✅ | | |
| Tag variables on PDFs (`$client.tags`, `$invoice.tags`, … 9 tokens across the variable tabs, custom-design editor autocomplete + Variables pane, and the WYSIWYG picker; opt-in, not default-selected) | ❌ | ❌ | ✅ | | |
| Custom Designs (CRUD: header / body / footer / includes / product / task) | ✅ | ✅ | ✅ | ✅ | |
| Custom design editor — live PDF preview of in-progress design | ✅ | ❌ | ✅ | ✅ | |
| Custom design editor — syntax-highlighted code editor + line numbers | ✅ | ❌ | ✅ | ✅ | |
| Custom design editor — tabbed sections + per-section help | ✅ | ❌ | ✅ | ✅ | |
| Custom design editor — start-from (built-in / custom / blank) | ✅ | 🟡 | ✅ | ✅ | |
| Custom design editor — "Edit a copy" of a built-in | ✅ | ❌ | ✅ | ✅ | |
| Custom design editor — variables reference (tap to insert) | ✅ | ❌ | ✅ | ✅ | |
| Custom design — import / export design JSON | ✅ | ❌ | ✅ | ✅ | |
| Custom design editor — inline 422 Twig/HTML error per section | ✅ | ❌ | ✅ | ✅ | |
| Custom design editor — unsaved-changes guard + "used for" warning | 🟡 | 🟡 | ✅ | ✅ | |
| **WYSIWYG invoice designer** — three-pane drag/drop builder | ✅ | ❌ | ✅ | — | |
| WYSIWYG — 17 block types (logo, info blocks, tables, totals, text, divider, spacer, etc.) | ✅ | ❌ | ✅ | — | |
| WYSIWYG — 12-column grid canvas with drag/drop reposition | ✅ | ❌ | ✅ | — | |
| WYSIWYG — corner + edge resize handles with grid snap | ✅ | ❌ | ✅ | — | |
| WYSIWYG — ghost preview + alignment guides during drag | ✅ | ❌ | ✅ | — | |
| WYSIWYG — undo/redo with Cmd-Z / Cmd-Shift-Z + Cmd-S | ✅ | ❌ | ✅ | — | |
| WYSIWYG — arrow-key nudging (move) + Shift+arrow resize | — | ❌ | ✅ | — | |
| WYSIWYG — fix-overlaps toolbar action | ✅ | ❌ | ✅ | — | |
| WYSIWYG — server-PDF live preview button | ✅ | ❌ | ✅ | — | |
| WYSIWYG — type-specific property editors (text / info / table / total / image / logo) | ✅ | ❌ | ✅ | — | |
| WYSIWYG — document settings panel (page layout / size / margins / fonts) | ✅ | ❌ | ✅ | — | |
| WYSIWYG — mobile reorder mode (full-width list, no canvas) | — | ❌ | ✅ | — | |
| WYSIWYG — Twig coexistence banner on legacy custom designs | ✅ | ❌ | ✅ | — | |
| WYSIWYG — Pro gate (Save disabled for free users) | ✅ | ❌ | ✅ | — | |
| WYSIWYG — export design JSON (copy to clipboard or download .json file) | ✅ | ❌ | ✅ | — | |
| WYSIWYG — Total block keepTogether page-break switch | ✅ | ❌ | ✅ | — | |
| WYSIWYG — import design JSON from the WYSIWYG toolbar (overwrite-confirm) | ✅ | ❌ | ✅ | — | |
| WYSIWYG — free-user PDF preview watermark | ✅ | ❌ | ✅ | — | |
| WYSIWYG — Total block-level alignment (left/center/right table positioning) | ✅ | ❌ | ✅ | — | |
| WYSIWYG — Total block-level fontSize default | ✅ | ❌ | ✅ | — | |
| WYSIWYG — document `embedDocuments` toggle | ✅ | ❌ | ✅ | — | |
| WYSIWYG — document `hideEmptyColumns` toggle | ✅ | ❌ | ✅ | — | |
| WYSIWYG — top bar packs design name + actions on one row (tablet+) | ✅ | ❌ | ✅ | — | |
| WYSIWYG — table columns reorder + delete | ✅ | ❌ | ✅ | — | |
| WYSIWYG — total items reorder + show/hide | ✅ | ❌ | ✅ | — | |
| WYSIWYG — info-block fieldConfigs reorder + hideIfEmpty toggle | ✅ | ❌ | ✅ | — | |
| WYSIWYG — image / logo source + maxWidth + align + objectFit | ✅ | ❌ | ✅ | — | |
| WYSIWYG — table column add (catalog picker) + remove | ✅ | ❌ | ✅ | — | |
| WYSIWYG — image upload (base64 → properties.source) | ✅ | ❌ | ✅ | — | |
| WYSIWYG — variable picker for info-block fieldConfigs | ✅ | ❌ | ✅ | — | |
| WYSIWYG — template gallery (Standard / Minimal / Quote-friendly starters) | ✅ | ❌ | ✅ | — | |
| WYSIWYG — real QR rendering via `qr_flutter` | ✅ | ❌ | ✅ | — | |
| WYSIWYG — Google Fonts loading for `documentSettings.primaryFont`/`secondaryFont` | ✅ | ❌ | ✅ | — | |
| WYSIWYG — `design.blocks` + `documentSettings` schema round-trip | ✅ | ❌ | ✅ | — | |
| WYSIWYG — per-row inline expansion (Info / Total / Table rows expand with chevron) | ✅ | ❌ | ✅ | — | |
| WYSIWYG — `CellTypographyEditor` sub-cards (labelStyle / valueStyle on field configs + table columns) | ✅ | ❌ | ✅ | — | |
| WYSIWYG — renderer cascade applies nested `labelStyle` / `valueStyle` on the canvas | ✅ | ❌ | ✅ | — | |
| WYSIWYG — `$..._label` token map translates row labels (`$subtotal_label` → "Subtotal") | ✅ | ❌ | ✅ | — | |
| WYSIWYG — QR code 5-preset picker (payment link / SEPA / Swiss / SPC / Verifactu) | ✅ | ❌ | ✅ | — | |
| WYSIWYG — block-level styling (lineHeight, padding, title sub-group, border editors) | ✅ | ❌ | ✅ | — | |
| WYSIWYG — desktop drag-and-drop image upload (`desktop_drop`) | — | ❌ | ✅ | — | |
| WYSIWYG — text-content 300 ms debounce on the canvas | ✅ | ❌ | ✅ | — | |
| WYSIWYG — table border width clamped to `[0, 20]` + page margins/padding clamped to `[0, 500]` | ✅ | ❌ | ✅ | — | |

### Custom Fields

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Company custom fields (4 slots: label + type) | ✅ | ✅ | ✅ | ✅ | |
| Client custom fields (4 slots) | ✅ | ✅ | ✅ | ✅ | |
| Contact custom fields (4 slots) | ✅ | ✅ | ✅ | ✅ | |
| Location custom fields (4 slots) | ✅ | ✅ | ✅ | ✅ | |
| Product custom fields (4 slots) | ✅ | ✅ | ✅ | ✅ | |
| Invoice custom fields (4 slots) | ✅ | ✅ | ✅ | ✅ | |
| Invoice surcharge custom fields (4 slots, with Charge taxes toggle) | ✅ | ✅ | ✅ | ✅ | |
| Payment custom fields (4 slots) | ✅ | ✅ | ✅ | ✅ | |
| Project custom fields (4 slots) | ✅ | ✅ | ✅ | ✅ | |
| Task custom fields (4 slots) | ✅ | ✅ | ✅ | ✅ | |
| Vendor custom fields (4 slots) | ✅ | ✅ | ✅ | ✅ | |
| Vendor contact custom fields (4 slots) | ✅ | ✅ | ✅ | ✅ | |
| Expense custom fields (4 slots) | ✅ | ✅ | ✅ | ✅ | |
| User custom fields (4 slots) | ✅ | ✅ | ✅ | ✅ | |
| Custom field types (single line / multi line / switch / date / dropdown) | ✅ | ✅ | ✅ | ✅ | |
| Module-gated tabs (hide Tasks / Vendors / Expenses / Projects when module disabled) | — | ✅ | ✅ | ✅ | |
| Non-Pro plan banner with upgrade link | ✅ | — | ✅ | ✅ | |
| 422 field errors → auto-jump to offending tab | — | — | ✅ |  | |

### Generated Numbers

#### Generated Numbers — Global

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Number Padding (digits) | ✅ | ✅ | ✅ | ✅ | |
| Number Counter (shared / per-entity) | ✅ | ✅ | ✅ | ✅ | |
| Recurring Prefix | ✅ | ✅ | ✅ | ✅ | |
| Reset Counter (frequency) | ✅ | ✅ | ✅ | ✅ | |

#### Generated Numbers — Per entity

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Client Number — pattern + counter + reset | ✅ | ✅ | ✅ | ✅ | |
| Invoice Number — pattern + counter + reset | ✅ | ✅ | ✅ | ✅ | |
| Recurring Invoice Number | ✅ | ✅ | ✅ | ✅ | |
| Quote Number — pattern + counter + reset | ✅ | ✅ | ✅ | ✅ | |
| Credit Number — pattern + counter + reset | ✅ | ✅ | ✅ | ✅ | |
| Payment Number — pattern + counter + reset | ✅ | ✅ | ✅ | ✅ | |
| Project Number — pattern + counter + reset | ✅ | ✅ | ✅ | ✅ | |
| Task Number — pattern + counter + reset | ✅ | ✅ | ✅ | ✅ | |
| Vendor Number — pattern + counter + reset | ✅ | ✅ | ✅ | ✅ | |
| Purchase Order Number | ✅ | ✅ | ✅ | ✅ | |
| Expense Number — pattern + counter + reset | ✅ | ✅ | ✅ | ✅ | |
| Recurring Expense Number | ✅ | ✅ | ✅ | ✅ | |

### Client Portal

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Client Portal (enable / disable) | ✅ | ✅ | ✅ | ✅ | |
| Dashboard (show in portal) | ✅ | ✅ | ✅ | ✅ | |
| Portal Mode (iframe / domain / subdomain) | ✅ | ✅ | ✅ | ✅ | |
| Subdomain | ✅ | ✅ | ✅ | ✅ | |
| Subdomain availability check (debounced) | ✅ | ✅ | ✅ | ✅ | |
| Domain (custom) | ✅ | ✅ | ✅ | ✅ | |
| Login URL display | ✅ | ✅ | ✅ | ✅ | |
| Client Document Upload | ✅ | ✅ | ✅ | ✅ | |
| Vendor Document Upload | ✅ | ✅ | ✅ | ✅ | |
| Accept Purchase Order Number | ✅ | ✅ | ✅ | ✅ | |
| Mobile Version | ✅ | ✅ | ✅ | ✅ | |
| Preference Product Notes For HTML View | ✅ | — | ✅ | ✅ | |
| Enable Client Profile Update | ✅ | ✅ | ✅ | ✅ | |
| Terms of Service / Privacy Policy | ✅ | ✅ | ✅ | ✅ | |
| Client Registration | ✅ | ✅ | ✅ | ✅ | |
| Registration Fields (20-field hide / optional / require matrix) | ✅ | ✅ | ✅ | ✅ | |
| Registration URL display | ✅ | ✅ | ✅ | ✅ | |
| Enable Portal Password | ✅ | ✅ | ✅ | ✅ | |
| Show Accept Invoice Terms | ✅ | ✅ | ✅ | ✅ | |
| Show Accept Quote Terms | ✅ | ✅ | ✅ | ✅ | |
| Require Invoice Signature | ✅ | ✅ | ✅ | ✅ | |
| Require Quote Signature | ✅ | ✅ | ✅ | ✅ | |
| Require Purchase Order Signature | ✅ | ✅ | ✅ | ✅ | |
| Signature on PDF | ✅ | ✅ | ✅ | ✅ | |
| Messages (welcome message editor) | ✅ | ✅ | ✅ | ✅ | |
| Header (HTML editor) | ✅ | ✅ | ✅ | ✅ | |
| Footer (HTML editor) | ✅ | ✅ | ✅ | ✅ | |
| Custom CSS | ✅ | ✅ | ✅ | ✅ | |
| Custom JavaScript | ✅ | ✅ | ✅ | ✅ | |

### Email Settings

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Send From Gmail | ✅ | ✅ | ✅ | ✅ | |
| Microsoft / Outlook OAuth | ✅ | ✅ | ✅ | ✅ | |
| Postmark API key | ✅ | ✅ | ✅ | ✅ | |
| Mailgun API key + domain | ✅ | ✅ | ✅ | ✅ | |
| SMTP server configuration | ✅ | ✅ | ✅ | ✅ | |
| From Name | ✅ | ✅ | ✅ | ✅ | |
| Reply To Email | ✅ | ✅ | ✅ | ✅ | |
| Reply To Name | ✅ | ✅ | ✅ | ✅ | |
| BCC Email | ✅ | ✅ | ✅ | ✅ | |
| Attach PDF | ✅ | ✅ | ✅ | ✅ | |
| Attach Documents | ✅ | ✅ | ✅ | ✅ | |
| Attach UBL | ✅ | ✅ | ✅ | ✅ | |
| Email Signature (HTML editor) | ✅ | ✅ | ✅ | ✅ | |
| Email Design (template picker) | ✅ | ✅ | ✅ | ✅ | |
| Email Alignment | ✅ | ✅ | ✅ | ✅ | |
| Show Email Footer | ✅ | ✅ | ✅ | ✅ | |
| Enable E-Invoice (send UBL with email) | ✅ | ✅ | ✅ | ✅ | |
| Send Test Email button | ✅ | ✅ | ✅ | ✅ | |
| Send-Time sync to existing entities (inline checkbox) | ✅ | — | ✅ | ✅ | |
| Password / secret reveal toggle | — | — | ✅ | ✅ | |
| Inline `$body` validation chip on custom style | — | — | ✅ | ✅ | |
| Pro / Enterprise gating chip on SMTP option | — | — | ✅ | ✅ | |
| OAuth Connect (in-app callback) | ✅ | 🟡 | ✅ | ✅ | |

### Templates & Reminders

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Template editor (subject + body, per entity type) | ✅ | ✅ | ✅ | ✅ | |
| Template variables reference | ✅ | ✅ | ✅ | ✅ | |
| First reminder rule (days before / after due + email) | ✅ | ✅ | ✅ | ✅ | |
| Second reminder rule | ✅ | ✅ | ✅ | ✅ | |
| Third reminder rule | ✅ | ✅ | ✅ | ✅ | |
| Endless reminder | ✅ | ✅ | ✅ | ✅ | |
| Quote reminder 1 | ✅ | ✅ | ✅ | ✅ | |
| Send Reminders (master toggle) | ✅ | ✅ | ✅ | ✅ | |
| Late Fees (auto-apply on reminder) | ✅ | ✅ | ✅ | ✅ | |
| Live HTML preview (mobile WebView) | ✅ | ✅ | ✅ | ✅ | |
| Markdown-rendered preview fallback (desktop) | — | ✅ | ✅ | ✅ | |
| Recurring invoice reminder customization | ✅ | ✅ | ✅ | ✅ | |

### Bank Accounts

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Bank account list | ✅ | 🟡 | ✅ | ✅ | 🟡 |
| Connect bank (Yodlee / Plaid) | ✅ | 🟡 | ✅ | ✅ | |
| Refresh accounts (upstream provider sync) | ✅ | ❌ | ✅ | ✅ | |
| Manual bank account fields | ✅ | ✅ | ✅ | ✅ | |
| Edit / archive / delete bank account | ✅ | ✅ | ✅ | ✅ | |
| Transaction rules list | ✅ | 🟡 | ✅ | ✅ | |
| Create transaction rule (auto-match) | ✅ | 🟡 | ✅ | ✅ | |
| Transaction rule — live "matches N" preview (debit, local) | — | — | ✅ | ✅ | |
| Bank transaction — matched-rule chip on detail (deep-link) | — | — | ✅ | | |
| Reconnect (Yodlee / Nordigen OAuth) | ✅ | 🟡 | ✅ | ✅ | |
| Plan / feature gating (enterprise) | ✅ | 🟡 | ✅ | ✅ | |

### E-Invoice

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| E-Invoice Settings (format selection: UBL / Factur-X / etc.) | ✅ | ❌ | ✅ | ✅ | |
| Merge to PDF | ✅ | ❌ | ✅ | ✅ | |
| Peppol registration (EU countries) | ✅ | ❌ | ✅ | ✅ | |
| Peppol registration (Singapore CorpPass) | ✅ | ❌ | ✅ | ✅ | |
| Verifactu (Spain) configuration | ✅ | ❌ | ✅ | ✅ | |
| France e-reporting (10-day / monthly schedule) | ✅ | ❌ | ✅ | | |
| E-invoice certificate upload + passphrase | ✅ | ❌ | ✅ | ✅ | |
| Payment means (IBAN / BIC / card) | ✅ | ❌ | ✅ | ✅ | |
| Additional tax identifiers | ✅ | ❌ | ✅ | ✅ | |
| Peppol — buy credit packs (500 / 1000) | ✅ | ❌ | ✅ | ✅ | |
| E-invoice compliance fields per entity | ✅ | ❌ | ✅ | ✅ | |
| Credit — Peppol billing reference (origin invoice + issue date) | ✅ | ❌ | ✅ | | |
| Recurring invoice — Peppol period (Description encoding) | ✅ | ❌ | ✅ | | |

### Group Settings

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Group list (Groups) | ✅ | ✅ | ✅ | ✅ | |
| Group create / edit (Name) | ✅ | ✅ | ✅ | ✅ | |
| Group Currency override | ✅ | ✅ | ✅ | ✅ | |
| Group Language override | ✅ | ✅ | ✅ | ✅ | |
| Group Country override | ✅ | ✅ | ✅ | ✅ | |
| Group archive / restore / delete | ✅ | ✅ | ✅ | ✅ | |
| Assign clients to group | ✅ | ✅ | ✅ | ✅ | |
| Group-level cascading settings override | ✅ | ✅ | ✅ | ✅ | |
| Group → Clients tab (members + New client shortcut) | ✅ | ✅ | ✅ | | |
| Group documents (upload / manage) | ✅ | ✅ | ✅ | | |

### Payment Links

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Payment link list | ✅ | ✅ | ✅ | ✅ | 🟡 |
| Create recurring payment link | ✅ | ✅ | ✅ | ✅ | |
| Subscription pricing / frequency | ✅ | ✅ | ✅ | ✅ | |
| Edit / cancel subscription | ✅ | ✅ | ✅ | ✅ | |
| Configurable checkout flow (Steps) | ✅ | — | ✅ | ✅ | |
| Webhook configuration (URL + headers) | ✅ | ✅ | ✅ | ✅ | |

### Schedules

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Schedule list | ✅ | ✅ | ✅ | ✅ | 🟡 |
| Create email schedule | ✅ | ✅ | ✅ | ✅ | |
| Schedule frequency / timing | ✅ | ✅ | ✅ | ✅ | |
| Report-delivery schedule | ✅ | ✅ | ✅ | ✅ | |
| Email-record schedule (single invoice / quote / credit / PO) | ✅ | ✅ | ✅ | ✅ | |
| Invoice-outstanding-tasks schedule | ✅ | ✅ | ✅ | ✅ | |
| Payment-schedule (split invoice into dated installments) | ✅ | ✅ | ✅ | ✅ | |
| Pause / resume schedule | — | — | ✅ | ✅ | |
| Starter cards on empty state | — | — | ✅ | ✅ | |

### User Management

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| User list | ✅ | ✅ | ✅ | ✅ | |
| Create / invite user | ✅ | ✅ | ✅ | ✅ | |
| User role assignment (admin / staff) | ✅ | ✅ | ✅ | ✅ | |
| Per-module permission grid | ✅ | ✅ | ✅ | ✅ | |
| Edit user details (Enterprise) | ✅ | ✅ | ✅ | ✅ | |
| Bulk user management | ✅ | ✅ | ✅ | ✅ | |
| User activity log | ✅ | ✅ | ✅ | ✅ | |
| Remove / revoke user | ✅ | ✅ | ✅ | ✅ | |

### Payment Terms

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Payment term list | ✅ | ✅ | ✅ | ✅ | 🟡 |
| Create / edit payment term (Name) | ✅ | ✅ | ✅ | ✅ | |
| Net-days / due-day configuration | ✅ | ✅ | ✅ | ✅ | |
| Archive / restore / delete | ✅ | ✅ | ✅ | ✅ | |

### Task Statuses

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Task status list | ✅ | ✅ | ✅ | ✅ | 🟡 |
| Create / edit task status (Name) | ✅ | ✅ | ✅ | ✅ | |
| Task status color picker | ✅ | ✅ | ✅ | ✅ | |
| Task status reordering | ✅ | ✅ | ✅ | ✅ | |
| Task status archive / restore / delete | ✅ | ✅ | ✅ | ✅ | |

### Expense Categories

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Expense category list | ✅ | ✅ | ✅ | ✅ | 🟡 |
| Create / edit expense category (Name) | ✅ | ✅ | ✅ | ✅ | |
| Expense category color | ✅ | ✅ | ✅ | ✅ | |
| Expense category archive / restore / delete / purge | ✅ | ✅ | ✅ | ✅ | |

### System Logs

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| App Version (display) | ✅ | ✅ | ✅ | ✅ | |
| Server Version (display) | ✅ | ✅ | ✅ | ✅ | |
| Pending Outbox count (display) | — | ✅ | ✅ | ✅ | |
| Dead-letter count (display) | — | ✅ | ✅ | ✅ | |
| Full-sync status (display) | — | ✅ | ✅ | ✅ | |
| View system / error logs (server feed + local diagnostics) | ✅ | ✅ | ✅ | ✅ | |
| Client system logs (detail tab) | ❌ | ✅ | ✅ | ✅ | |
| API call logs | ✅ | ✅ | ✅ | ✅ | |
| User action audit trail | ✅ | ✅ | ✅ | ✅ | |
| Outbox / diagnostics snapshot export | — | 🟡 | ✅ | ✅ | |

---

## Payment gateways

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Gateway list | ✅ | ✅ | ✅ | ✅ | 🟡 |
| Gateway detail | ✅ | ✅ | ✅ | ✅ | 🟡 |
| Webhook URL (copy to clipboard) | ✅ | ✅ | ✅ | ✅ | |
| Gateway edit | ✅ | ✅ | ✅ | ✅ | |
| Gateway fees, limits & fee taxes (per payment type) | ✅ | ✅ | ✅ | ✅ | |
| Gateway create / add | ✅ | ✅ | ✅ | ✅ | |
| Duplicate-gateway warning on add | ✅ | ❌ | ✅ | ✅ | |
| Gateway disconnect / deactivate | ✅ | ✅ | ✅ | ✅ | |
| Gateway archive / restore | ✅ | ✅ | ✅ | ✅ | |
| Gateway purge | ✅ | ✅ | ✅ | ✅ | |
| Import customers from gateway | ✅ | ✅ | ✅ | ✅ | |
| Verify customers at gateway | ✅ | ✅ | ✅ | ✅ | |
| OAuth setup launcher | ✅ | ✅ | ✅ | ✅ | |
| Stripe Connect flow | ✅ | ✅ | ✅ | ✅ | |
| Stripe (standard mode) | ✅ | ✅ | ✅ | ✅ | |
| PayPal | ✅ | ✅ | ✅ | ✅ | |
| Authorize.Net | ✅ | ✅ | ✅ | ✅ | |
| Multi-gateway priority ordering | ✅ | ✅ | ✅ | ✅ | |
| Gateway webhook supported-events list (detail) | ✅ | ✅ | ✅ | ✅ | |
| Gateway system logs (detail) | ✅ | ✅ | 🟡 | ✅ | |
| Gateway clone | ✅ | ❌ | ✅ | ✅ | |

---

## Sync & offline

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Outbox queue UI (pending / in-flight / dead) | — | ✅ | ✅ | ✅ | |
| Manual retry of failed sync | — | ✅ | ✅ | ✅ | |
| Discard stuck / dead outbox rows | — | ✅ | ✅ | ✅ | |
| 409 conflict resolution sheet | — | 🟡 | ✅ | ✅ | |
| 412 password gate (re-prompt for password) | ✅ | ✅ | ✅ | ✅ | |
| 422 field-level validation errors | ✅ | ✅ | ✅ | ✅ | |
| Idempotency keys on mutations | ✅ | 🟡 | ✅ | ✅ | |
| Background outbox drain when online | — | ✅ | ✅ | ✅ | ✅ |
| Company-switch sync parity (prompt for pending) | — | ✅ | ✅ | ✅ | |
| Per-company FIFO outbox ordering | — | 🟡 | ✅ | ✅ | |
| Offline editing (full CRUD without network) | — | 🟡 | ✅ | ✅ | |
| Encrypted local database (SQLCipher) | — | ❌ | ✅ | ✅ | |
| One-tap Sync in the sidebar header (push + download, shared progress) | — | — | ✅ | | |

---

## Cross-cutting

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Global search / command palette | ✅ | ✅ | ✅ | ✅ | |
| Settings search | ✅ | ✅ | ✅ | ✅ | |
| Dark mode / light mode toggle | ✅ | ✅ | ✅ | ✅ | |
| Sidebar footer theme quick-switch (light/dark/system + settings shortcut) | — | — | ✅ | | |
| Selectable sidebar counters (per-row: overdue / unpaid / draft / assigned-to-me / low stock / …, colour-coded, right-click or Settings → Device Settings) | — | — | ✅ | | |
| Multi-language UI (40+ locales) | ✅ | ✅ | ✅ | ✅ | |
| Company switcher | ✅ | ✅ | ✅ | ✅ | |
| Keyboard shortcuts | ✅ | ✅ | ✅ | ✅ | |
| Customizable keyboard shortcuts (Settings → Keyboard Shortcuts; rebind/clear/reset globals, assign 14 create actions, conflict detection, device-local persist) — feeds live handlers + hint bar + `?` dialog | ✅ | — | ✅ | | |
| Keyboard-shortcut discoverability — hold ⌘/Ctrl hint bar · Enter hint on dialog primaries · hover shortcut tooltips | — | — | ✅ | | |
| Browser-style back/forward history (Cmd/Alt+←/→ · sidebar arrow buttons · mouse back/forward thumb buttons · Android system back gesture) | — | — | ✅ | ✅ | |
| Recently-viewed entities (command palette "Recent" group, persisted, company-scoped) | ❌ | ✅ | ✅ | ✅ | |
| Real-time WebSocket / Pusher notifications | ✅ | ✅ | ❌ |  | |
| Live UI refresh on server-side change | ✅ | ✅ | ❌ |  | |
| Push notifications (FCM / APNs) | 🟡 | ✅ | ❌ |  | |
| Deep links | — | ✅ | ✅ | ✅ | |
| Native share sheet | — | ✅ | ✅ | ✅ | |
| Responsive layout — mobile | ✅ | ✅ | ✅ | ✅ | |
| Responsive layout — tablet | ✅ | ✅ | ✅ | ✅ | |
| Responsive layout — desktop | ✅ | ✅ | ✅ | ✅ | |
| Column picker on lists | ✅ | ✅ | ✅ | ✅ | |
| List filter — checkbox multi-select for status / state | — | — | ✅ | ✅ | |
| List filter — client country/industry/size/classification/vat/group/assigned/custom + number/id_number (exact) | ✅ | ✅ | ✅ | ✅ | v5 filter PR (number/id_number exact-match) + denormalized cols |
| List filter — expense project / vendor | ✅ | ✅ | ✅ | ✅ | v5 `project_ids`/`vendor_ids` |
| List filter — canonical `date_range` (`column,start,end`) | — | — | ✅ | ✅ | legacy 2-part still parsed |
| List filter — date "is between" comparator (date + due_date + client created/updated) | — | — | — | ✅ | unified into `DateColumnFilterKey`; dual-calendar popover; replaced bespoke payment date_range key; clients folded the standalone "updated between" entry into the operator (`created_at_range`/`updated_at_range`, mirrored locally); server `date_range`/`due_date_range` standardized 3-part in fork (BACKEND.md § E3) |
| Saved views (filter + sort + columns) | ✅ | ✅ | ✅ | ✅ | |
| Bulk-actions framework | ✅ | ✅ | ✅ | ✅ | |
| PDF generation | ✅ | ✅ | ✅ | ✅ | |
| In-app PDF preview / viewer | ✅ | ✅ | ✅ | ✅ | |
| CSV export | ✅ | ✅ | ✅ | ✅ | |
| Sentry / error-tracking integration | ✅ | ✅ | ✅ | ✅ | |
| Per-entity activity / audit feed | ✅ | ✅ | ✅ | ✅ | |
| Per-entity comments / internal notes | ✅ | ✅ | ✅ | ✅ | |
| Unsaved-changes guard on navigation | ✅ | ✅ | ✅ | ✅ | |
| Phone-number input with validation | ✅ | ✅ | ✅ | ✅ | |
| Signature pad | ✅ | ✅ | ✅ | ✅ | |
| Image crop editor | ✅ | ✅ | ✅ | ✅ | |
| QR code generation | ✅ | ✅ | ✅ | ✅ | |
| Accent color customization | ✅ | ✅ | ✅ | ✅ | |
| Help / tooltip system | ✅ | ✅ | ✅ | ✅ | |
| Onboarding tour | ✅ | 🟡 | ❌ | ✅ | removed — product decision |
| New-company setup wizard (name / currency / language) | ✅ | ✅ | ✅ | ✅ | |
| Contact-us dialog | ✅ | ✅ | ✅ | ✅ | |
| About dialog | ✅ | ✅ | ✅ | ✅ | |
| Health check dialog (self-hosted diagnostics) | ✅ | ✅ | ✅ | ✅ | |
| Trial-footer indicator | ✅ | ✅ | ✅ | ✅ | |
| Cookie / privacy banner | ✅ | — | — |  | |
| Migration import from competitors (FreshBooks / Wave / CSV) | ✅ | ❌ | ✅ | ✅ | |
| Clipboard copy actions | ✅ | ✅ | ✅ | ✅ | |
| Toast notifications | ✅ | ✅ | ✅ | ✅ | |
| Markdown editor (rich text) | ✅ | ✅ | ✅ | ✅ | |
| Restore-on-restart (resume last screen) | 🟡 | ✅ | ✅ | ✅ | |
| Encrypted local persistence | — | ❌ | ✅ | ✅ | |

---

## Platform / mobile specific

| Feature | React | Flutter v1 | Flutter v2 | AI review | Live E2E |
|---|---|---|---|---|---|
| Biometric lock (Touch ID / Face ID / fingerprint) | — | ✅ | ✅ | ✅ | |
| Push notifications (FCM / APNs) | — | ✅ | ❌ |  | |
| Native share sheet | — | ✅ | ✅ | ✅ | |
| OS deep links / universal links | — | ✅ | ✅ | ✅ | |
| Native window-state persistence (macOS + Windows) | — | ❌ | ✅ | ✅ | |
| OAuth deep-link handler (callback URL) | — | ✅ | ✅ | ✅ | |
| Web platform support (`flutter build web`) | ✅ | — | ✅ | | |
| Web persistence (drift WASM / IndexedDB, unencrypted) | — | — | ✅ | | |
| Web auth token storage (localStorage) | — | — | ✅ | | |
| Web data writes (blocked on server `Idempotency-Key` CORS — see BACKEND.md) | — | — | 🟡 | | |
| Biometric / IAP / native-window / OAuth-login on web | — | — | — | | |
