# Invoice Ninja — list filter & sort gaps (backend PR spec)

This file is the spec for an upstream PR against the Invoice Ninja API. It
finishes the datatable **search / filter / sort** feature: the official
clients expose filter UI for many params the list endpoints silently ignore.

**Read this first:** the actionable work is in
[§ Requested backend changes](#requested-backend-changes-pr-scope). The
per-endpoint tables and curls below are the supporting evidence. A separate
[§ Client-side mismatches — FIXED](#client-side-mismatches--fixed-not-part-of-this-pr)
section lists symptoms that were *client* bugs (already fixed and shipped in
the Flutter app) so they are explicitly **out of scope** here.

**Also in this file (non-filter backend asks, appended at the bottom):**
- Web platform CORS — `Idempotency-Key` not allow-listed (**R**, blocks web writes).
- Server-side `Idempotency-Key` dedupe — not implemented (**R**, retry-safety / duplicate creates).
- Company write — partial login envelope + full-replace PUT force a client fetch-gate (**O**).
- E-Invoice PEPPOL — Singapore "government" classification rejected by `StoreEntityRequest` (**O**, blocks SG government onboarding).
- Dashboard net (ex-tax) chart totals — chart endpoints have no `net` param (**O**, feature request flutter#4).
- Purchase-order PDF line-item currency — a PO with an attached client prints line items in the *client's* currency while totals stay in the *vendor's* (**R**, PDF correctness).

**Shipped since this file was written** (kept for the record, no action left):
- **§§ A–E, E2, E3** — the list filter/sort PR, merged upstream 2026-05-17 (`db4aed2c5c`) + `tag_ids` 2026-06-01.
- **Calendar connect native callback** — `platform=flutter_native` on `/one_time_token`; both sides done.
- **Multi-rate inclusive tax** — server adopted the additive `InclusiveTax::backout` model 2026-07-09 (two small client-side residuals noted in that section).

**Provenance**
- **2026-05-15** — empirical curl probe vs `demo.invoiceninja.com`.
- **2026-05-17** — source-read of `app/Filters/*`; reclassified rows.
- **2026-05-17 (rev 2)** — every `app/Filters/...:line` citation
  re-verified TRUE against current source; client-side items confirmed
  fixed & shipped; restructured into this PR-scope spec; live re-probe
  refreshed the appendix to behavioral assertions.
- **2026-05-17 (rev 3)** — full 33-file `app/Filters` inventory +
  `app/Models/Client.php` schema cross-check. Corrected three claims:
  `currency_id`/`language_id` are `settings` JSON, not columns (§ A2);
  `assigned_user_id` already works via the column-guarded base
  `assigned_user_ids` (§ A3); expense `vendor_id` works via base, only
  `project_ids` is a real gap (§ C). All other claims (every
  `client_status` value set, the four `date_range` contracts, `status_id`
  Invoice-only, the ClientFilters/ExpenseFilters/TaskFilters method lists,
  `next_send_between` dual separator) verified TRUE.
- **2026-07-24** — backend catch-up review vs `v5-develop` HEAD `36f4a6b1c9`;
  §§ A–E / calendar / inclusive-tax re-verified against current server
  source and marked SHIPPED; §§ F, F1, F2, G, H re-verified still open.

The root failure mode: **`QueryFilters::apply()` does
`if (!method_exists($this,$name)) continue;`** — every unknown filter param
and every invalid `sort` column returns `200` with the unfiltered/default
set. Nothing 422s, so a client can't tell a typo/missing-filter from a real
empty result. That is why this list is needed and why the hygiene item is #1.

---

## Requested backend changes (PR scope)

> **STATUS 2026-07-24 — §§ A–E are SHIPPED upstream.** The filter PR
> specified below merged into the official `invoiceninja/invoiceninja`
> `v5-develop` as `db4aed2c5c` "List feature/sort" (2026-05-17), with
> `tag_ids` following in `273efd5ffb` (2026-06-01). Verified against the
> current server source: `ClientFilters` now has `group_settings_id`,
> `country_id`, `industry_id`, `size_id`, `classification`, `vat_number`;
> base `QueryFilters` has `custom_value1..4`, `client_ids`,
> `assigned_user_ids`, `tag_ids`, `updated_between`, `created_at`,
> `updated_at`, `date_range`, `due_date_range`; `ExpenseFilters` has
> `project_ids`, `vendor_ids`, `payment_type`; `ProjectFilters` has
> `assigned_user`; `TaskFilters` has `project_ids`. The Flutter client
> already consumes these (see `lib/ui/features/clients/client_filter_keys.dart`).
> **§§ F, F1, F2, G and H below remain open** — re-verified against current
> source on 2026-07-24. Kept in full as the record of what was asked for and
> why.


Each row: **R**equired / **O**ptional · target file · what to add · one
acceptance check. IDs in Invoice Ninja are Hashids — a CSV id filter must
decode via `$this->transformKeys(explode(',', $value))` (multi) or
`$this->decodePrimaryKey($value)` (single); see the existing
`QueryFilters::client_ids():446` / `ClientFilters::group():109` for the
pattern.

### A. `app/Filters/ClientFilters.php` — add the missing id/enum filters — **SHIPPED upstream**

`ClientFilters` has only `name`, `balance`, `between_balance`, `email`,
`client_id`, `id_number`, `number`, `group`, `filter`.

**A1 — Required: real-column filters that genuinely have no method.**
`clients.country_id`, `industry_id`, `size_id` (plain int FKs),
`classification`, `vat_number` (strings) are real columns
(`app/Models/Client.php` `$fillable`) with no filter method:

```php
public function country_id(string $value = ''): Builder
{
    if (strlen($value) == 0) return $this->builder;
    return $this->builder->whereIn('country_id', explode(',', $value)); // int FK, no decode
}
// same shape (int FK, no decode): industry_id, size_id
public function classification(string $value = ''): Builder
{
    if (strlen($value) == 0) return $this->builder;
    return $this->builder->whereIn('classification', explode(',', $value)); // string column
}
public function vat_number(string $value = ''): Builder
{
    if (strlen($value) == 0) return $this->builder;
    return $this->builder->where('vat_number', 'like', "%{$value}%");
}
```
- **R.** Make `id_number` and `number` LIKE/prefix (today `where('id_number',$v)`
  / `where('number',$v)` are exact — `number=000` returns 0, not `0001..`).
- **R (CSV gap).** `group_settings_id` — a single decoded `group=<hashid>`
  already works (`ClientFilters::group():109`); add a multi `group_settings_id`
  (`whereIn('group_settings_id', $this->transformKeys(explode(',', $v)))`).
- Accept: `clients?country_id=<id>` returns fewer rows than `clients` (today:
  unchanged — no method).

**A2 — `currency_id` / `language_id` are NOT columns.** Invoice Ninja stores
client currency/language inside the `clients.settings` JSON blob (`Client.php`
casts `settings => object`; there is no `currency_id`/`language_id` column).
A `whereIn('currency_id', …)` would error. Filtering these requires a JSON
path (`where('settings->currency_id', $v)`) **and** only matches clients with
an *explicit per-client override* — it does not reflect the
group→company settings cascade, so it's semantically partial. Treat as an
**Optional design decision**, not a one-line `whereIn`. (The Flutter client
gates these filters off until resolved.)

**A3 — `assigned_user_id` is NOT absent.** The inherited base
`QueryFilters::assigned_user_ids():435` is column-guarded and
`clients.assigned_user_id` exists, so
`clients?assigned_user_ids=<hashid,…>` **already filters today** (just
undocumented). **Optional:** add a singular `assigned_user_id` alias and
document it distinctly from the owner `user_id` (today both are conflated).
No Required backend work — the client can adopt `assigned_user_ids` now
(see § Client-side).

### B. Universal `custom_value1..4` filtering — **SHIPPED upstream**

No `custom_value*` filter method exists on the base or any entity (it's only
referenced inside `filter()` free-text search). Add to a shared trait / the
base so every entity with `custom_value1..4` columns (client, invoice, quote,
credit, payment, expense, PO, recurring, project, task, vendor) gets:

```php
public function custom_value1(string $v=''): Builder
{ return strlen($v)==0 ? $this->builder : $this->builder->where('custom_value1','like',"%$v%"); }
// custom_value2, custom_value3, custom_value4
```
- Accept: `invoices?custom_value1=<known>` narrows.

### C. `app/Filters/ExpenseFilters.php` — **SHIPPED upstream**

`categories` already exists (`:185`, CSV→`whereIn('category_id', transformKeys)`).
Inherited base methods already cover **single** `vendor_id`
(`QueryFilters:303`, decoded, column-guarded), `client_id` (`:294`) and CSV
`client_ids` (`:446`) — expenses have those columns, so those filters work
today. The genuine gap is **project filtering** — no `project_*` method
exists on `ExpenseFilters` or the base.

**R.** Add `project_ids` (the real gap):
```php
public function project_ids(string $v=''): Builder
{ if(strlen($v)==0) return $this->builder; return $this->builder->whereIn('project_id', $this->transformKeys(explode(',', $v))); }
```
**O.** Add a CSV `vendor_ids` convenience (single `vendor_id` already works
via base — this is only for multi-select):
```php
public function vendor_ids(string $v=''): Builder
{ if(strlen($v)==0) return $this->builder; return $this->builder->whereIn('vendor_id', $this->transformKeys(explode(',', $v))); }
```
- Accept: `expenses?project_ids=<id>` narrows (today: unchanged — no method);
  `expenses?vendor_id=<hashid>` already narrows via base.

### D. `app/Filters/ProjectFilters.php` — **SHIPPED upstream**

Add `assigned_user` / `assigned_user_ids` (mirror base
`QueryFilters::assigned_user_ids():435`). Accept: `projects?assigned_user_ids=<id>`
narrows.

### E. Base — `updated_between` — **SHIPPED upstream**

Only `created_between` exists (`QueryFilters:389`, 2-part on `created_at`).
Add the symmetric `updated_between` (2-part `start,end`, `whereBetween('updated_at',…)`).

### E2. Comparable date / numeric operators — **SHIPPED upstream** (was: in this fork)

`feat/list-filter-sort-gaps` now carries `QueryFilters::comparableDate()`
and rewires `created_at` / `updated_at` (base) + `date` / `due_date`
(`InvoiceFilters`, and new methods on `QuoteFilters` / `CreditFilters`)
through it. Contract the Flutter client relies on:

- **Canonical wire = PREFIX `op:value`** (`created_at=gte:2026-01-01`,
  `balance=gt:5000`). `op ∈ {lt,gt,lte,gte,eq}` via the existing
  `split()` / `operatorConvertor()`. `ClientFilters::balance()` already
  used this — the client now sends it (fixes the prior suffix
  `value:op` → `where(col,'=','op')` zero-row bug).
- **Bare value (no op prefix) keeps the historical default** — the date
  filters default to `>=`, so legacy `created_at=<date>` and other API
  clients are unchanged.
- **`whereDate` calendar-day semantics** for date-only values: `eq` is
  "that calendar day", `before`/`after` are day-granular. A value
  carrying a time component uses an exact `where`.
- **Malformed input is a silent no-op** (returns the unfiltered set, no
  422 — matches the framework's `method_exists` skip contract).
  `due_date()` previously had no try/catch and would 500 on an
  `op:value` wire; `comparableDate()` fixes that.
- **`split()` colon invariant:** a value must not itself contain `:`
  (the date filters use `explode(':', $v, 2)`; `balance` uses the
  unlimited `split()`). The client guarantees date-only / numeric
  values. The rolling **`rel:` relative token is resolved to an
  absolute value client-side** and never reaches the API.

Tests: `tests/Feature/QueryFilterEnhancementsTest.php` (created_at
gt/lte/eq-calendar-day, plain-date still `>=`, balance prefix, invoice
date/due_date, quote/credit date, malformed-is-safe).

### E3. `date_range` / `due_date_range` standardization — **SHIPPED upstream** (was: in this fork)

`feat/list-filter-sort-gaps` standardized the date-window filters on the
**base** `QueryFilters` so every entity behaves identically (resolves the
G.3 punch-list item below; the per-entity overrides described in the
Hygiene detail no longer apply on this branch):

- **`QueryFilters::date_range()`** (`:501`) is now arity-tolerant +
  column-aware: 2-part `start,end` → `whereBetween('date', …)`; 3-part
  `column,start,end` → `whereBetween(column, …)` when `column` is a real
  table column; 3-part placeholder `_,start,end` → defaults to `date`
  (absorbs the old Payment / Project / RecurringExpense contracts).
  Silent no-op on a non-existent column or unparseable bound.
- **`QueryFilters::due_date_range()`** (`:603`) now mirrors `date_range()`
  exactly, defaulting the column to `due_date`. This fixes the prior
  2-part-only guard that silently dropped the Flutter client's canonical
  3-part `due_date_range=due_date,<start>,<end>`. Inherited by
  Invoices / Quotes / Credits; no per-entity override needed.
- Flutter client wire: `date` "between" → `date_range=date,<s>,<e>`;
  `due_date` "between" → `due_date_range=due_date,<s>,<e>` (legacy 2-part
  `<s>,<e>` still parsed both client- and server-side).

Tests: `tests/Feature/QueryFilterEnhancementsTest.php` —
`testDateRange{Legacy,CanonicalThreePart}*`, `testPaymentLegacyThreePart*`,
`testDueDateRange{LegacyTwoPart,CanonicalThreePart,ThreePartOnQuotesAndCredits,MalformedIsSafeNoOp}`.

### F. `status_id` parity — **O**

`status_id` is defined **only** in `InvoiceFilters:148`. Optional: add the
same `whereIn('status_id', explode(',', $v))` to Quote/Credit/Payment/
PurchaseOrder/RecurringInvoice filters for cross-entity consistency. Low
priority — the official clients use the computed `client_status` for these.

### F1. `QuoteFilters::client_status` — missing `rejected` — **O**

`client_status` handles `sent / draft / approved / expired / upcoming /
converted` but has **no `rejected` branch**, so `client_status=rejected`
hits the global silent-no-op (returns the unfiltered set). Quotes do carry
`STATUS_REJECTED = 5` (set when a client rejects in the portal), and the
official clients expose a "Rejected" filter chip. Requested: add
`if (in_array('rejected', $status_parameters)) $query->orWhere('status_id',
Quote::STATUS_REJECTED);`. Low priority — the v2 client already filters
`rejected` **locally** as a deliberate approximation (the chip narrows
cached rows), so this only improves server-side narrowing for large lists.

### F2. `app/Filters/PaymentFilters.php` — `company_gateway_id` — **O**

`payments?company_gateway_id=<id>` is **silently ignored today** — confirmed
against the live demo server: a bogus id returns the full unfiltered set (same
silent-no-op as `status_id` above). The v2 client wants this to power
per-gateway stats on the Credit Cards & Banks detail (processed total + payment
count). Until it narrows server-side, the v2 client deliberately does **not**
render those tiles — a wrong, unfiltered number is worse than omitting them.

**O.** Add a single/CSV, hashid-decoded, column-guarded filter (mirrors
`ExpenseFilters::project_ids`):
```php
public function company_gateway_id(string $v=''): Builder
{ if(strlen($v)==0) return $this->builder; return $this->builder->whereIn('company_gateway_id', $this->transformKeys(explode(',', $v))); }
```
- Accept: `payments?company_gateway_id=<hashid>` narrows to that gateway's
  payments (today: unchanged — no method). A matching
  `client_gateway_tokens?company_gateway_id=` listing would also unblock the
  "clients with token billing" tile.

### H. `task_statuses/sort` endpoint — **O** (client now works around it)

There is **no** `POST /api/v1/task_statuses/sort` route (only `tasks/sort`
exists; `routes/api.php` registers the `task_statuses` resource + `/bulk`
only, and `TaskStatusController` has no `sort` method). The v2 client
previously POSTed there to persist drag-reorder of task statuses (Settings →
Task Statuses and the kanban column headers) → **404** (treated as a
conflict on outbox drain).

**Fixed client-side (no PR required):** the v2 client now reorders a status
the way `TaskStatusController::update` already supports — a single
`PUT /api/v1/task_statuses/{id}` carrying the moved status's new
`status_order`, which trips `$task_status->isDirty('status_order')` and runs
`TaskStatusRepository::reorder()` to shift + renumber every sibling (1..N).
The client sends the insertion slot = the moved status's new successor's
current `status_order`. **O.** If you later add a `task_statuses/sort` route
mirroring `TaskController::sort` (`{status_ids}` → renumber), the client
could batch a multi-move into one request; until then per-move PUTs are
correct and sufficient (status counts are tiny).

### G. Hygiene — highest leverage

1. **R (non-breaking first).** Unknown filter param → surface in a
   `meta.warnings: []` envelope key (always-on, additive, safe). Then add an
   **opt-in strict mode** (`?strict=true` or `X-Strict-Filters: 1`) that
   `422`s on unknown param / invalid sort. A hard 422 by default would break
   existing integrations that lean on silent-ignore — ship the warning
   envelope first.
2. **R.** Invalid/unknown `sort` column: same — echo the applied sort in
   `meta` and/or warn; today it silently falls back to
   `ensureDefaultOrder()` → `orderByDesc(getQualifiedKeyName())`
   (effectively `<table>.id DESC`), so the client can't detect disagreement.
3. ~~**R.** Standardize `date_range` to **one** contract — recommend 3-part
   `column,start,end` with `column` defaulting to `date` — and apply it on
   the base so all entities behave identically.~~ **SHIPPED in this fork —
   see § E3** (`date_range` + `due_date_range` now unified on the base;
   the four-contract divergence below is the pre-fork state).
4. **O.** `filter=<text>` OR-scope: today LIKE on the primary display column
   only; users expect e.g. an invoice search to match the client name.
5. **O.** Honor `*` as a wildcard in LIKE filters (or document that values
   are always `%v%`-wrapped) — `name=Bob*` returns 0 today (literal `*`).
6. **R.** Publish the per-endpoint **filter + sortable-column contract** in
   the public API reference (today aspirational on most list endpoints) and
   document `status` (lifecycle) vs `client_status` (computed business
   status) — the overload is correct server-side but undocumented and the
   official clients historically conflated them.

**Compatibility constraint:** the official React client already emits
`project_ids`, `assigned_user_ids`, `client_ids`, `categories`,
`date_range` (with column), `created_between`, lifecycle on `status`. Prefer
these exact names for any new param — see [§ React-parity](#react-parity-note).

See [§ Acceptance & rollout](#acceptance--rollout) for done-criteria.

---

## How to verify a row

Self-contained — runs against the public demo (canned read-only creds; the
demo dataset resets periodically so assert **behavior** — "narrows vs
baseline" / "unchanged" / "422" — not exact counts):

```
BASE=https://demo.invoiceninja.com/api/v1
curl "$BASE/clients?per_page=100" \
  -H "Content-Type: application/json" \
  -H "X-API-SECRET: password" \
  -H "X-API-TOKEN: TOKEN" \
  -H "X-Requested-With: XMLHttpRequest"
```

A row is **fixed** when changing the param value changes the response
(different count/order, or 422 on a malformed value). Today almost every
unknown param returns 200 with the unfiltered set — that's the bug class.

## What the base `QueryFilters` already provides

`app/Filters/QueryFilters.php` is inherited by **every** per-entity
`*Filters`. Each method is **column-guarded** (`in_array('<col>',
Schema::getColumnListing($table))`) → it works on **any** entity whose table
has that column, even with no entity-specific method. This is load-bearing:
it means `assigned_user_ids` already filters clients, `vendor_id` already
filters expenses, etc. — those are *not* gaps.

| Param | Behavior | Source |
|---|---|---|
| `status=active,archived,deleted` | Entity **lifecycle** (`deleted_at`/`is_deleted`). Distinct param from computed `client_status`; never collide server-side. | `QueryFilters.php:172` |
| `created_at=<date\|ts>` | `created_at >= Carbon::parse(value)`. **Plain value only** — an operator suffix (`:gt`) throws and is swallowed → unfiltered. | `:238` |
| `updated_at=<date\|ts>` | `updated_at >= value`. Same plain-value contract. | `:257` |
| `created_between=<start>,<end>` | `whereBetween('created_at', …)`. **2-part.** No `updated_between` exists. | `:389` |
| `date_range=<start>,<end>` | `whereBetween('date', …)`. **2-part, base contract** (overridden inconsistently — see Hygiene). | `:415` |
| `due_date_range=<start>,<end>` | `whereBetween('due_date', …)`. 2-part. | `:463` |
| `client_id=<id>` | single, decoded hashid, column-guarded. | `:294` |
| `vendor_id=<id>` | single, decoded hashid, column-guarded → **filters expenses/POs today**. | `:303` |
| `client_ids` / `assigned_user_ids` | multi, CSV of **hashids** (`transformKeys`), column-guarded → `assigned_user_ids` **filters clients today** (clients.assigned_user_id exists). | `:446` / `:435` |
| (dispatch) | Unknown param → `if (!method_exists(...)) continue;` (**silent 200**). Invalid `sort` → `ensureDefaultOrder()` → `orderByDesc(getQualifiedKeyName())` ≈ `<table>.id DESC`. | `:88` / `:123` |

`per_page` is capped `min(abs(input), 5000)`, default 20
(`app/Http/Controllers/BaseController.php:606`).

## Legend

- ✅ Works — server honors the param.
- ⚠️ Partial — works with unexpected semantics (exact where LIKE expected).
- ❌ Silently ignored — 200 OK, set unchanged, **no server method exists**
  (genuine backend gap → in PR scope).
- 🔁 Historical — server supports it; the symptom was a *client* wire-format
  / param-name mismatch, **already fixed & shipped client-side** (see
  § Client-side — FIXED). **No backend action.**
- 🚫 Not implemented.
- **untested** — wanted by the app; no controlled probe yet.

## Per-endpoint evidence (supporting detail)

Skipping small reference endpoints (designs, payment_terms, tax_rates,
webhooks, tokens, schedulers, subscriptions, company_gateways,
expense_categories, transaction_rules) — state filtering only.

### GET /api/v1/clients — `app/Filters/ClientFilters.php`

`ClientFilters` adds only `name`, `balance`, `between_balance`, `email`,
`client_id`, `id_number`, `number`, `group`, `filter`. Rest is inherited or
absent (→ § A).

| Param | Current | Backend ask |
|---|---|---|
| `filter=<text>` | ✅ LIKE on `name` | OR name + number + contact name/email (G.4) |
| `name=<text>` | ✅ LIKE | keep |
| `status=active,archived,deleted` | ✅ base `:172` lifecycle | keep (correct lifecycle param) |
| `number=<value>` | ⚠️ exact (`number=000`→0) | LIKE/prefix (§ A) |
| `id_number=<value>` | ⚠️ exact (`:91`) | LIKE substring (§ A) |
| `email=<value>` | ⚠️ exact, via `whereHas('contacts', email = v)` relationship (`:71`) | LIKE substring on the contact email |
| `balance=<n>:gt\|lt\|gte\|lte\|eq` | ✅ suffix-operator (`ClientFilters::balance:43`); `between_balance` uses `min:max` (`:60`) | keep; document both shapes |
| `created_at=<date>` plain | ✅ base `:238` | keep |
| `created_between` | ✅ base `:389` | keep |
| `country_id` `industry_id` `size_id` | ❌ no method (real int-FK columns) | § A1 (Required) |
| `classification` `vat_number` | ❌ no method (real string columns) | § A1 (Required) |
| `group_settings_id` | ⚠️ single decoded `group=` works (`:109`); no CSV | § A1 (CSV gap) |
| `currency_id` `language_id` | 🚫 not columns — in `clients.settings` JSON | § A2 (Optional, JSON, partial) |
| `assigned_user_id` | ⚠️ works via inherited base `assigned_user_ids` (`QueryFilters:435`, column-guarded); undocumented | § A3 (Optional alias only) |
| `custom_value1..4` | ❌ no method anywhere | § B (Required) |
| `user_id` vs `assigned_user_id` | ⚠️ both unchanged | disambiguate owner vs assignee, or deprecate one |

### GET /api/v1/invoices — `app/Filters/InvoiceFilters.php`

| Param | Current | Backend ask |
|---|---|---|
| `filter` | ✅ LIKE on `number` | OR + client name + po_number (G.4) |
| `client_id`/`client_ids` · `status_id` (`:148`) · `client_status` (draft\|paid\|unpaid\|overdue\|cancelled) · `overdue` · `status` lifecycle · `date`/`due_date` `>=` · `due_date_range` | ✅ | keep |
| `overdue` (note) | ✅ `InvoiceFilters::overdue():197` is a **no-arg** method; the dispatcher calls it whenever `overdue` is present and **ignores the value** (`overdue=false` still filters to overdue). Send only when active. | keep |
| `date_range=<s>,<e>` 2-part | ✅ inherits base `:415` (re-probed: far-future range → 0) | keep; standardize arity (G.3) |
| `project_id`/`project_ids` | ❌ no method | add `project_ids` (hashid CSV) |
| `start_date`/`end_date` | 🔁 no such method — the window is `date_range` (historical client naming; now sends `date_range`) | none (use `date_range`); optional aliases |
| `custom_value1..4` | ❌ | § B |

### GET /api/v1/quotes · /credits — `Quote/CreditFilters.php`

`filter`, `client_id`, `status` lifecycle, `created_between`, `client_status`
(quote `draft\|sent\|approved\|expired\|upcoming\|converted`; credit
`draft\|sent\|partial\|applied`), `date_range` (base 2-part) → ✅ keep.
`status_id` ❌ → § F (optional). `custom_value1..4` ❌ → § B.

### GET /api/v1/payments — `app/Filters/PaymentFilters.php`

`filter`, `client_id`, `status` lifecycle, `client_status`
(`pending\|cancelled\|failed\|completed\|partially_refunded\|refunded\|partially_unapplied`)
→ ✅. `date_range` ⚠️ **3-part** `_,start,end` (`PaymentFilters:275`, uses
`$parts[1]`,`$parts[2]`, `isset($parts[2])` required; a 2-part value
silently no-ops) → standardize (G.3). `status_id` ❌ → § F. `custom_value*`
❌ → § B.

### GET /api/v1/expenses — `app/Filters/ExpenseFilters.php`

`filter`, `client_id`, `status` lifecycle, `client_status`,
`payment_type`, `amount`, `number`, `has_invoices`, `match_transactions`
→ ✅. `categories=<id,id>` ✅ (`:185`, hashid CSV→`whereIn('category_id',…)`;
canonical name — `category_id` was never a method; the client now sends
`categories`, fixed). `project_ids`/`vendor_ids` ❌ → § C.
`custom_value1..4` ❌ → § B.

### GET /api/v1/tasks — `app/Filters/TaskFilters.php`

Canonical server names: `project_tasks=<hashid>` (single, `:97`,
`where('project_id', decode)`) ✅; `task_status=<hashid,…>` (CSV, `:236`,
`whereIn('status_id', transformKeys)` **plus `whereNull('invoice_id')`** —
filtering by status also hides invoiced tasks, server-side) ✅;
`client_status=invoiced\|uninvoiced\|is_running` ✅; `assigned_user`,
`user_id`, `hash`, `number` ✅. `project_id`/`status_id` 🔁 — no such method;
this was the headline "visible UI bug" but it was a *client* param-name
mismatch, **fixed & shipped** (client now sends `project_tasks`/`task_status`).
Optional: add `project_ids`/`status_id` aliases for cross-entity
consistency. `custom_value1..4` ❌ → § B.

### GET /api/v1/projects — `app/Filters/ProjectFilters.php`

`filter`, `client_id`, `number`, `status` lifecycle → ✅.
`date_range=<col>,<start>,<end>` ⚠️ **3-part with explicit column**
(`ProjectFilters:152`, `$parts[0]` must be a real column) → standardize
(G.3). `assigned_user`/`assigned_user_ids` ❌ → § D.

### GET /api/v1/recurring_invoices · /recurring_expenses

`filter`, `client_id`, `status` lifecycle, `client_status` ✅.
`next_send_between` ✅ but accepts **both** `|` and `,` separators — pick one
+ document. `frequency_id`, `product_key` (rec. invoices) ✅. `date_range`
(recurring_expenses) ⚠️ **2-part `$parts[0],$parts[1]`**
(`RecurringExpenseFilters:243`) — a *fourth* contract → standardize (G.3).
`custom_value1..4` ❌ → § B.

### GET /api/v1/purchase_orders · /vendors · /products · /bank_transactions

| Endpoint | Notable gaps |
|---|---|
| purchase_orders | `status_id` ❌ (use `client_status=draft\|sent\|accepted\|cancelled`; § F optional); `start_date/end_date` 🔁 (use base `date_range`); `custom_value1..4` ❌ (§ B) |
| vendors | `number` ⚠️ exact; `vat_number`/`id_number` substring ❌; `country_id`/`currency_id`/`assigned_user_id`/`custom_value1..4` ❌ — mirror § A |
| products | `product_key` ✅ exact; `filter` ✅ LIKE on product_key/notes; no enum filters needed |
| bank_transactions | `name` ✅; `client_status=unmatched\|matched\|converted\|deposits\|withdrawals` ✅; `bank_integration_ids` ✅; `date_range` ⚠️ Payment-style 3-part → standardize (G.3) |

## Client-side mismatches — FIXED (not part of this PR)

These were **Flutter client** bugs (wrong param name / wire format) against
already-working server params — all fixed & committed 2026-05-17. Listed so
the backend reviewer knows they need **no backend work**. *(Flutter-repo
context — not required to action this PR.)*

1. ✅ Lifecycle now sent on `status` (was `client_status` on Client/Vendor,
   nothing elsewhere — archived/deleted views were silently empty).
   Resolves the quote/payment `client_status` collision.
2. ✅ Client `created`/`updated` send a plain date (no `:gt`); server `>=`.
3. ✅ Tasks send `project_tasks` (single) + `task_status`.
4. ✅ Expenses send `categories` (CSV). Expense **`vendor_id`** (single) and
   `client_id`/`client_ids` already work via the inherited base methods;
   only `project_ids` is a real backend gap → § C.
5. ✅ Invoices/quotes send the (working) 2-part `date_range`; the dashboard
   invoice KPI sends a closed `date_range`.

**Available with no backend change (client can adopt now):**
`assigned_user_ids` (CSV hashids) already filters **clients** and any entity
whose table has `assigned_user_id`, via the column-guarded base
`QueryFilters::assigned_user_ids:435`. Single `vendor_id` already filters
**expenses**. These need only a client-side wiring change, not a PR.

## Sort

App sends `sort=<field>|asc|desc`. Confirmed honored: `name`, `number`,
`updated_at`, `created_at`, `balance`, `amount`, `date`, `product_key`.
Per-entity `sort()` validates against `Schema::getColumnListing` +
`client.`/`contact.`/`documents` prefixes; **unknown column → silent
`ensureDefaultOrder()`** (`QueryFilters:123`). Clients sort the cache
locally, so server disagreement is invisible → see Hygiene G.2.

Unverified columns the app sends: Clients `paid_to_date`, `contact_*`,
`last_login_at`, `custom1..4`; document entities `due_date`,
`partial_due_date`, `paid_to_date`, `po_number`, `assigned_user_id`,
`custom_value1..4`; Recurring `next_send_date`, `frequency_id`,
`remaining_cycles`; Payments `applied`, `refunded`, `type_id`; Expenses
`payment_date`, `category_id`; Tasks `task_status_id`; Projects `due_date`,
`budgeted_hours`. Invoice `status_id` sort renders a *computed* status
client-side — expose `calculated_status_id` server-side or document the
mismatch.

## Cross-cutting API hygiene

1. Unknown filter param: `meta.warnings[]` (non-breaking), then opt-in
   strict `422` (`QueryFilters::apply:88`). **The single highest-leverage
   change.**
2. Invalid sort column: warn / echo applied sort (`:123`).
3. **`date_range` has four incompatible contracts** — standardize (3-part
   `column,start,end`, default `date`):
   - base `QueryFilters::date_range:415` — 2-part `start,end`, hard `date`.
   - `PaymentFilters::date_range:275` — 3-part `_,start,end`.
   - `ProjectFilters::date_range:152` — 3-part `column,start,end`.
   - `RecurringExpenseFilters::date_range:243` — 2-part `$parts[0],$parts[1]`.
4. `number=<value>` → LIKE/prefix across entities (currently exact).
5. `filter=<text>` OR-scope beyond the primary display column.
6. `*` wildcard in LIKE (`name=Bob*` → 0 today).
7. `updated_between` (only `created_between` exists).
8. Uniform hashid CSV multi-value across all id filters.
9. Document `status` vs `client_status` + per-endpoint contract publicly.

## React-parity note

The official React client emits, per its DataTable: `per_page`, `page`,
`filter`, `sort=<f>|<dir>`, `status` (lifecycle), `include`,
`without_deleted_clients`; Tasks `project_ids`/`assigned_user_ids`/
`client_ids`; Expenses `categories`; date pickers `date_range` (with
column) + `created_between`. **New params must use these exact names** so
both official clients converge.

## Acceptance & rollout

- **Per change:** the acceptance curl in § A–F changes the result set
  (narrows / 422 on malformed) where today it is unchanged. Add/extend the
  backend's own filter feature tests alongside.
- **Hygiene 422:** ship `meta.warnings[]` (additive, no version bump) first;
  gate hard `422` behind opt-in (`?strict=true` / header) so existing API
  consumers don't break. Document in the API changelog.
- **`date_range` standardization:** keep accepting the legacy per-entity
  shapes for one deprecation cycle (parse 2-part *and* 3-part); log a
  deprecation warning via the `meta.warnings[]` channel.
- **Naming:** match the React param names (§ React-parity) so the PR doesn't
  fork client behavior.

## Appendix — reproducible curls (behavioral)

Auth headers from § How to verify. Demo resets — assert the **direction**,
not the count. Last reproduced 2026-05-17: clients/invoices/tasks baseline
≈25, expenses ≈72.

```bash
# Genuine gaps — param has no method, set is UNCHANGED vs baseline:
curl "$BASE/clients?per_page=100&country_id=840"          # unchanged  → § A
curl "$BASE/clients?per_page=100&custom_value1=zzz"       # unchanged  → § B
curl "$BASE/expenses?per_page=100&project_ids=<id>"       # unchanged  → § C
# Base filters that DO work (regression guards, keep working):
curl "$BASE/clients?per_page=100&created_at=2030-01-01"   # → 0 (>=)
curl "$BASE/invoices?per_page=100&date_range=2100-01-01,2100-12-31" # → 0
curl "$BASE/tasks?per_page=100&project_tasks=<projectId>" # narrows
curl "$BASE/expenses?per_page=100&categories=<catId>"     # narrows (source-verified; demo had no category data to probe)
# Hygiene target — today returns 200 + unfiltered; after PR: meta.warnings[] / 422 in strict mode:
curl "$BASE/clients?per_page=100&bogus_param=1"           # 200 unchanged (the bug)
```

`<id>`/`<projectId>`/`<catId>` = a value from a `?per_page=1` baseline call.

## OAuth — Microsoft / Azure (client-side gap, not a server gap)

FEATURES.md line 65 stays ❌ deliberately. The `/api/v1/oauth_login` and
`/api/v1/connected_account?provider=microsoft` exchanges already work
(identical to the shipped Google/Apple path — `AuthService.oauthLogin`,
`UsersApi.connectOauth`). The blocker is **client-side token acquisition**:
there is no maintained native Flutter MSAL SDK (admin-portal is web-only
`msal_js`; `aad_oauth` is deprecated/unmaintained, webview-based). Until a
stable native Flutter MSAL option exists, Microsoft sign-in cannot be
shipped to the verified standard Google/Apple were — so it is NOT flipped.
No server change is required; this note exists only so the gap is traceable.

---

## Web platform CORS — `Idempotency-Key` not allow-listed — **R (server gap, blocks web writes)**

**Provenance** — 2026-05-19, live `OPTIONS` preflight probe vs
`demo.invoiceninja.com` while adding the web platform target.

The web build runs at a browser origin and calls the API cross-origin, so
every request is subject to CORS preflight. `ApiClient._buildHeaders`
(`lib/data/services/api_client.dart:756-768`) sends `Idempotency-Key` on
**every outbox write** (stable per outbox row, the M1 retry-safety
contract — see CLAUDE.md § Sync). The demo server's preflight response
does **not** allow that header:

```
$ curl -s -i -X OPTIONS 'https://demo.invoiceninja.com/api/v1/clients' \
    -H 'Origin: https://admin.example.com' \
    -H 'Access-Control-Request-Method: POST' \
    -H 'Access-Control-Request-Headers: idempotency-key'
access-control-allow-origin: *
access-control-allow-methods: POST, GET, OPTIONS, PUT, DELETE
access-control-allow-headers: X-CLIENT-PLATFORM,X-React,X-API-PASSWORD-BASE64,
  X-API-COMPANY-KEY,X-CLIENT-VERSION,X-API-SECRET,X-API-TOKEN,X-API-PASSWORD,
  DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,
  Content-Disposition,Range,X-CSRF-TOKEN,X-XSRF-TOKEN,X-LIVEWIRE,X-Socket-ID
```

`Idempotency-Key` is absent → the browser blocks every web write
(create/update/delete) at preflight. All other admin-client headers
(`X-API-TOKEN`, `X-API-PASSWORD-BASE64`, `X-CLIENT-*`, `X-API-SECRET`,
`X-Requested-With`, `Content-Type`) **are** allowed, so reads and login
work; only writes are blocked.

**Required change** — add `Idempotency-Key` to the API's CORS
`Access-Control-Allow-Headers` list (the middleware/config that produces
the header set above; mirror how `X-API-TOKEN` is registered).

**Optional, same change site** — add
`Access-Control-Expose-Headers: X-MINIMUM-CLIENT-VERSION`. There is no
`Access-Control-Expose-Headers` in the response today, so the
`x-minimum-client-version` response header (read on every request to throw
`ClientTooOldException` — CLAUDE.md § Sync) is invisible to JS on web. It
fails open (the min-version gate silently never trips on web) rather than
breaking anything, so this is **O**, not **R**. Pagination needs nothing
here — the keyset cursor reads `data.last` from the body, not a header.

**Acceptance** — re-run the curl above with
`Access-Control-Request-Headers: idempotency-key`; `Idempotency-Key` must
appear in the returned `access-control-allow-headers`. Then a web build
create/edit/delete must complete instead of failing with a console CORS
preflight error.

Until this ships, web is **read + login only**; outbox drains will fail at
the network layer (surfaced as transient sync errors). Client code needs
no change — `Idempotency-Key` stays sent unconditionally; it is correct
and required for retry safety on every platform.

## Server-side `Idempotency-Key` dedupe — not implemented — **R (retry-safety gap)**

The client sends `Idempotency-Key: <uuid>` on every outbox mutation, stable
across retries (generated once at outbox-row creation — CLAUDE.md § Sync).
The intent is exactly-once semantics: a request that times out *after* the
server committed (or whose response is lost) is retried with the same key,
and the server should return the original result instead of re-executing.

**Verified gap** (deep-review 2026-06-10, `~/Code/invoiceninja-fork`): no
code path reads the `Idempotency-Key` header — `grep -ri "idempotency"
app/` returns nothing. Every retry re-executes the handler, so:

- `POST /api/v1/clients` (etc.) retried after a timeout-after-commit
  **creates a duplicate entity**;
- non-idempotent actions (`/payments/refund`, `bulk` actions, `/email`)
  can double-fire.

The client cannot fully compensate: it retries on
timeouts/5xx/connection-reset precisely because it cannot know whether the
first attempt committed.

**Required change** — middleware (or base-request hook) that, for mutating
verbs, caches `(token, Idempotency-Key) → response` for ~24h and replays
the cached response on a key hit. Laravel packages exist
(`square1-io/laravel-idempotency`-style) or it's ~50 lines with the cache
facade.

**Acceptance** — send the same `POST /api/v1/clients` twice with one
`Idempotency-Key`: exactly one client row exists; both responses carry the
same entity id.

Until this ships, a retried create after a lost response duplicates the
entity. Client mitigation already in place: stable keys per row (so the fix
is purely server-side) and single-flight drains minimizing concurrent
retries.

## Company write: partial envelope + full-replace PUT force a fetch-gate — **O (would simplify the client)**

**Provenance** — 2026-06-11, pre-beta deep-review finding #40 + source-read
of `lib/data/models/api/login_response_api_model.dart` (`CompanyEnvelopeApi`)
vs `company_api_model.dart` (`CompanyApi`), and `company_sync_dispatcher.dart`.

The Account-Management screens (Enabled Modules / Security / Overview /
Analytics) edit **top-level company columns** and save the **whole company**
via `PUT /api/v1/companies/{id}` (`draft.toApiJson()`). Two server behaviors
combine into a data-loss footgun the client now has to work around:

1. **The `/login` + `/refresh` company envelope omits ~29 server-only
   columns** that the full `GET /api/v1/companies/{id}` returns: the SMTP
   block (`smtp_host`/`smtp_port`/`smtp_encryption`/…), the expense block
   (`mark_expenses_*`/`convert_expense_currency`/`expense_mailbox*`/…), the
   task-invoicing block (`auto_start_tasks`/`invoice_task_*`/…), and
   `enable_applying_payments` / `convert_payment_currency`. Verified: all four
   probe fields (`smtp_host`, `enable_applying_payments`,
   `convert_expense_currency`, `auto_start_tasks`) are present in `CompanyApi`
   and **absent** from `CompanyEnvelopeApi`. So after login the cached company
   row carries Drift **table defaults** for those columns until a separate
   `GET` backfills them.
2. **`PUT /companies/{id}` full-replaces top-level columns from the body** —
   it does not merge-patch. Evidence: removing an e-invoice certificate needs
   its own PUT carrying an explicit `{"e_invoice_certificate": null}` because
   "a plain company PUT never sends that key" (`company_sync_dispatcher.dart`
   :156-165) — an omitted key is not cleared, and a *defaulted* key
   overwrites the server's real value.

Together: a user who opens an Account-Management tab and toggles one switch
before a canonical `GET` has landed (or while offline, where it never lands)
PUTs the whole cached row — shipping the **defaulted** SMTP / expense / task /
payment-conversion columns and silently wiping the server's real settings.

**Client mitigation already shipped (so this is O, not R):** the v2 client
gates those four screens' controls behind a successful canonical
`GET /companies/{id}` this session (`CompanyRepository.canonicalFetched` +
`CompanySettingsGate`) — controls stay disabled until the real values are in
hand, and disabled offline. Correct, but it makes those settings
**uneditable offline** and adds a fetch-latency gate.

**Optional backend changes that would let the client drop the gate** (either
suffices):
- **(a) Complete the envelope** — include the omitted top-level columns in
  the `/login` + `/refresh` company payload (`first_load` already enriches
  the envelope with reference data; extend it to the full company column
  set). Then the cached row is always safe to PUT.
- **(b) Support a partial/merge update** — honor a field-subset body on
  `PUT /companies/{id}` (or a `PATCH`) that updates only the keys present and
  leaves omitted columns untouched. Then the client can send a one-field diff
  regardless of what else is cached.

**Acceptance** — (a) a fresh `/login?include_static=true&first_load=true`
returns `smtp_host` / `enable_applying_payments` / `auto_start_tasks` /
`convert_expense_currency` in each company; **or** (b) `PUT /companies/{id}`
with a body of `{"enabled_modules": <n>}` leaves `smtp_host` unchanged on the
server. Either unblocks removing the client-side fetch-gate.

---

## Calendar connect — callback must reach native/Flutter clients — **SHIPPED (both sides)**

> **STATUS 2026-07-24 — done, no action left.** Server side:
> `OneTimeTokenRequest` accepts `platform` (`in:flutter_native,react`) and
> `CalendarConnectionController::redirectToClient` sends the callback to
> `config('ninja.calendar.native_redirect')` — default
> `invoiceninja://calendar_connection/complete` — when
> `platform === 'flutter_native'`, falling back to the React/web `react_url`
> redirect otherwise. Client side: `CalendarConnectionRepository.buildAuthorizeUrl`
> already passes `platform`, and `/calendar_connection/complete` is a
> registered route (`lib/app/router.dart`). Kept below as the record of the
> original ask.


**Provenance** — 2026-06-14, porting React PR `invoiceninja/ui#3180`
("Connect Google/Microsoft calendar → convert event to task") to the Flutter
client.

The OAuth handshake is server-mediated (Socialite) and ends with the
authenticated, security-critical `POST /api/v1/calendar_connection/{provider}/complete`
that relays a one-time `handoff` (the server asserts the completing user
started the flow — `CalendarConnectionService::completeConnection`). To get
the `handoff` to the front end, `CalendarConnectionController::callback`
(`routes/web.php` → `app/Http/Controllers/CalendarConnectionController.php`)
**always** redirects to `config('ninja.react_url')`:

```
{ninja.react_url}/#/calendar_connection/complete?calendar_connection=pending&provider=<p>&handoff=<h>
```

That target reaches the React SPA only. The Flutter clients need the handoff
delivered to *them*:

- **Native (macOS/iOS/Android/Windows)** — there is no full-page redirect to
  ride. The app opens the system browser (Google blocks OAuth in embedded
  webviews) and catches a **custom-scheme deep link**. The client registers
  `invoiceninja://calendar_connection/complete` (Info.plist + AndroidManifest;
  on Windows via MSIX `protocol_activation` plus the app_links second-instance
  forward in `windows/runner/main.cpp`) and bridges it into its router
  (`lib/app/calendar_deep_links.dart`). The server must redirect there for
  native callers. Windows caveat: only packaged (MSIX/Store) installs register
  the scheme — `flutter run -d windows` dev builds can't complete the flow.
- **Web (Flutter) and Linux** — reuse the existing `react_url` redirect:
  the flow lands on `/#/calendar_connection/complete` in the browser,
  **provided `react_url` resolves to the Flutter web app's origin**. Linux
  deliberately rides this path too (the client omits `platform` there): an
  AppImage can't reliably register an `x-scheme-handler`, and the GTK runner
  is `G_APPLICATION_NON_UNIQUE`, so the native callback would strand the
  browser. The desktop app picks the connection up on the next
  `loadStatus()`.

**The change (implemented; PR-ready against `invoiceninja/invoiceninja:v5-develop`).**
Native clients declare themselves so the callback can deliver the handoff to the
app; everything else keeps today's React behavior:

1. `POST /api/v1/one_time_token` accepts an optional `platform` (validated
   `in:flutter_native`). The Flutter client sends
   `{"context":"calendar_<provider>","platform":"flutter_native"}` on **native
   only** (web omits it). It's bound to the `state` cache in
   `CalendarConnectionService::buildAuthorizationUrl`.
2. The public `callback` reads the `state` cache non-destructively (`Cache::get`,
   not `pull`) and picks the redirect: `flutter_native` → the allow-listed custom
   scheme `config('ninja.calendar.native_redirect')` (default
   `invoiceninja://calendar_connection/complete`); anything else (web / React /
   absent) → `react_url`, unchanged.
3. The target comes from config, never client input (no open-redirect); the
   `state.user_id` binding in `completeConnection` is untouched, so a hijacked
   scheme still yields a useless handoff.

Only one env var is needed: `CALENDAR_NATIVE_REDIRECT` (defaults to the scheme
above). The client side — scheme registration (Info.plist + AndroidManifest) and
the deep-link bridge (`lib/app/calendar_deep_links.dart`) — is already in place.

**Acceptance** — a `one_time_token` minted with `platform=flutter_native`
produces a callback `302` to `invoiceninja://calendar_connection/complete?...handoff=...`;
a request with no platform still redirects to `react_url`.

## E-Invoice PEPPOL — Singapore "government" classification rejected by `StoreEntityRequest` — **O (server gap, blocks SG government onboarding)**

`POST /api/v1/einvoice/peppol/setup` is validated by
`app/Http/Requests/EInvoice/Peppol/StoreEntityRequest.php`, whose rule is
`'classification' => ['required', 'in:business,individual']`. For a Singapore
company the onboarding UI offers **business** or **government** (CorpPass);
React (`Onboarding.tsx`) and the Flutter client (`peppol_onboarding_card.dart`,
`buildPeppolSetupPayload`) both send `classification: 'government'` for that
choice — which is **not** in the `in:` list, so the setup `422`s on the
`classification` field. The request already has SG-aware rules in the same
method (`id_number` / `c5_signer_*` required-if-SG, `vat_number` not required
when SG), so SG support is clearly intended; the `in:` list was simply never
widened.

**Required change** — widen the rule to accept `government` for SG, e.g.
`'classification' => ['required', $this->isSingapore() ? 'in:business,government' : 'in:business,individual']`
(or just add `government` to the list). This is a **shared** client/server gap
(React sends the same value), not a Flutter rebuild regression — do **not**
change either client to stop sending `government`.

**Client side** — the Flutter SG `peppolSetupDirect` path currently surfaces a
422 only as a generic `could_not_save` toast (no inline `classification`
field error); once the server accepts `government` this is moot for the common
case. Tracked as low-severity client polish.

**Acceptance** — a Singapore company completing PEPPOL onboarding with the
**Government** entity type returns `200` (legal entity created) instead of a
`422` on `classification`.

## Dashboard net (ex-tax) chart totals — chart endpoints have no `net` param — **O (feature request, [flutter#4](https://github.com/invoiceninja/flutter/issues/4))**

**Provenance** — 2026-07-03, feature request flutter#4 ("Dashboard with net
values"): *"a setting to see the dashboard with net values only (without
taxes)."* Source-read of `app/Services/Chart/*` + `app/Http/Controllers/ChartController.php`
+ `app/Http/Requests/Chart/*` against `~/Code/invoiceninja` (`v5-develop`).

The dashboard KPIs (Outstanding / Overdue / Paid-this-month) and hero chart
are **server-aggregated** — the Flutter client posts to
`/api/v1/charts/totals_v2` and `/charts/chart_summary_v2`
(`lib/data/services/dashboard_api.dart`) and never holds the full invoice
set, so it **cannot** compute net locally (the old admin-portal only could
because it loaded every entity via `per_page=999999`, which this rebuild
forbids). `ChartQueries` hardcodes **gross** everywhere —
`SUM(invoices.amount)` (invoiced), `SUM(invoices.balance)` (outstanding),
`payments.amount - payments.refunded` (revenue), and the expense `CASE` adds
tax back on. There is no `net`/`include_taxes` param and no `net_amount`
field. So net is a **server** feature; the client change afterward is tiny
(one query param — see § acceptance).

**Required change** — add a `net` flag (default `false` = gross → fully
backward-compatible; unknown query params are already silently ignored, so a
newer client that sends `net=true` to an un-upgraded server degrades safely
to gross). `net=true` returns ex-tax values in the **same response fields** —
no shape change. (Alt name `include_taxes`, default `true`, would mirror the
existing `include_drafts`; `net` is recommended for clarity.)

**1 — Request validation.** In both `app/Http/Requests/Chart/ShowChartRequest.php`
(`rules()` L35-43, `prepareForValidation()` L45-71) and
`ShowCalculatedFieldRequest.php` (L35-46 / L48-77), mirror `include_drafts`:

```php
// rules()
'net' => 'bail|sometimes|boolean',
// prepareForValidation()
$input['net'] = filter_var($input['net'] ?? false, FILTER_VALIDATE_BOOLEAN);
```

**2 — Thread controller → service.** `app/Http/Controllers/ChartController.php`
— pass `$request->input('net', false)` as a new 5th `ChartService` arg in
`totalsV2()` (L63), `chart_summaryV2()` (L75), `calculatedFields()` (L174).
**Fold in a pre-existing bug:** `chart_summaryV2()` builds `ChartService`
**without** the `include_drafts` arg (L75), so the hero chart silently ignores
the drafts toggle the client already sends (`dashboard_api.dart:45`) — thread
**both** here:

```php
$cs = new ChartService($user->company(), $user, $admin_equivalent_permissions,
        $request->input('include_drafts', false), $request->input('net', false));
```

`app/Services/Chart/ChartService.php` — add the ctor arg (L28):

```php
public function __construct(public Company $company, private User $user,
    private bool $is_admin, private bool $include_drafts = false, private bool $net = false) {}
```

**3 — `ChartQueries` SQL.** Build each amount expression in PHP conditioned on
`$this->net` and interpolate into the existing SQL (every query's structure,
params, exchange-rate wrapper, and `GROUP BY` stay byte-identical — only the
summed expression changes). `invoices.total_taxes` is a real column
(`decimal(13,3)`, confirmed).

- **Invoiced** — `getInvoicesQuery` (L444), `getAggregateInvoicesQuery` (L416),
  `getInvoiceChartQuery` (L563), `getAggregateInvoiceChartQuery` (L536). Exact:
  ```php
  $amount = $this->net ? '(invoices.amount - invoices.total_taxes)' : 'invoices.amount';
  // ... SUM({$amount}) ...  (aggregate variants keep the / COALESCE(NULLIF(exchange_rate,0),1) wrapper)
  ```
- **Outstanding** — `getOutstandingQuery` (L321), `getAggregateOutstandingQuery`
  (L347), `getOutstandingChartQuery` (L500), `getAggregateOutstandingChartQuery`
  (L468). Balance is a partial of gross → prorate by the invoice's net ratio
  (partial-payment safe, div-by-zero guarded):
  ```php
  $balance = $this->net
      ? 'COALESCE(invoices.balance * (invoices.amount - invoices.total_taxes) / NULLIF(invoices.amount, 0), invoices.balance)'
      : 'invoices.balance';
  ```
- **Expenses** — `getExpenseQuery` (L25), `getAggregateExpenseQuery` (L58),
  `getExpenseChartQuery` (L162), `getAggregateExpenseChartQuery` (L106). The
  gross `CASE` adds tax to exclusive-tax rows; net is its symmetric inverse
  (matches admin-portal `expense.netAmount = uses_inclusive ? amount - tax : amount`):
  ```php
  $tax = '((COALESCE(expenses.tax_amount1,0) + COALESCE(expenses.tax_amount2,0) + COALESCE(expenses.tax_amount3,0)) '
       . '+ ((expenses.amount * COALESCE(expenses.tax_rate1,0)/100) + (expenses.amount * COALESCE(expenses.tax_rate2,0)/100) + (expenses.amount * COALESCE(expenses.tax_rate3,0)/100)))';
  $expense = $this->net
      ? "CASE WHEN expenses.uses_inclusive_taxes = 0 THEN expenses.amount ELSE expenses.amount - {$tax} END"
      : "CASE WHEN expenses.uses_inclusive_taxes = 0 THEN expenses.amount + {$tax} ELSE expenses.amount END"; // gross == today
  // aggregate/chart variants keep their outer * exchange_rate wrapper; swap only the inner CASE
  ```
- **Revenue / Payments — "net everything", the hard part** — `getRevenueQuery`
  (L394), `getAggregateRevenueQuery` (L373), `getPaymentQuery` (L210),
  `getAggregatePaymentQuery` (L235), `getPaymentChartQuery` (L287),
  `getAggregatePaymentChartQuery` (L261). Payments carry **no** tax split, so
  net requires allocating each payment across the invoices it paid via the
  `paymentables` pivot (per-allocation `amount`/`refunded`; `paymentable_type`
  stored as the morph alias `'invoices'` — verified against
  `PaymentService`/`RefundPayment` which query `where('paymentable_type','invoices')`;
  `Payment::invoices()` morphs to `Invoice`). Weight each allocation by the
  invoice's net ratio and pass the **unapplied** remainder through untaxed.
  E.g. `getRevenueQuery`:
  ```sql
  -- gross today: sum(payments.amount - payments.refunded) as paid_to_date
  SELECT
      SUM( COALESCE(alloc.net_applied, 0)
           + ((payments.amount - payments.refunded) - COALESCE(alloc.gross_applied, 0)) ) as paid_to_date,
      payments.currency_id AS currency_id
  FROM payments
  JOIN clients ON payments.client_id = clients.id
  LEFT JOIN (
      SELECT pt.payment_id,
             SUM(pt.amount - pt.refunded) AS gross_applied,
             SUM((pt.amount - pt.refunded) * (i.amount - i.total_taxes) / NULLIF(i.amount, 0)) AS net_applied
      FROM paymentables pt
      JOIN invoices i ON i.id = pt.paymentable_id AND pt.paymentable_type = 'invoices'
      WHERE pt.deleted_at IS NULL
      GROUP BY pt.payment_id
  ) alloc ON alloc.payment_id = payments.id
  WHERE payments.company_id = :company_id AND payments.is_deleted = 0 AND clients.is_deleted = 0
    AND payments.status_id IN (1,4,5,6) AND (payments.date BETWEEN :start_date AND :end_date)
  GROUP BY payments.currency_id
  ```
  The other five payment queries take the same `alloc` subquery (chart variants
  keep `GROUP BY payments.date`; aggregate variants keep the `* exchange_rate`
  wrapper). **Edge cases the maintainer must decide:** (a) **credits**
  (`paymentable_type='credits'`, which also have `total_taxes`) — apply the
  same ratio, or leave as-is; (b) **unapplied** payment balance — no invoice, so
  treated as already tax-free (the `- gross_applied` remainder term); (c)
  **refunds** — handled via `pt.refunded` / `payments.refunded`.
  **Simpler fallback** if the allocation join is deemed too heavy: apply a
  company/window net ratio `SUM(invoices.amount - invoices.total_taxes) / NULLIF(SUM(invoices.amount),0)`
  to the existing gross payment sums — cheaper, less exact.

**Phasing (recommend splitting the PR).** *Phase 1* — `totals_v2` +
`chart_summary_v2` (the built-in KPIs + hero chart, highest value). *Phase 2* —
`calculated_fields`: `ChartService::getCalculatedField()` (L343) dispatches into
the `ChartCalculations` trait, where each money-format calc
(`active_invoices`, `outstanding_invoices`, `completed_payments`,
`invoiced_expenses`, …) needs the same net treatment — larger surface, can land
second.

**Acceptance** — against a server **with** the PR, two `POST /api/v1/charts/totals_v2`
over one date range differing only by `net`:

```bash
curl -sX POST "$BASE/api/v1/charts/totals_v2?net=false" -H "$AUTH" -H 'Content-Type: application/json' \
  -d '{"start_date":"2026-01-01","end_date":"2026-12-31","date_range":"custom"}' | jq '.data["999"].invoices, .data["999"].revenue'
curl -sX POST "$BASE/api/v1/charts/totals_v2?net=true"  -H "$AUTH" -H 'Content-Type: application/json' \
  -d '{"start_date":"2026-01-01","end_date":"2026-12-31","date_range":"custom"}' | jq '.data["999"].invoices, .data["999"].revenue'
```

`net=true` must return `invoices.invoiced_amount` reduced by exactly the summed
`invoices.total_taxes` for the window, `outstanding.amount` and
`revenue.paid_to_date` reduced proportionally, and (for a company with any
taxed line) net < gross on every money field. `net=false` must be byte-identical
to today's response (regression guard). (The demo/production server won't
reflect this until the change is **deployed** — a client sending `net` sees no
change until then.)

**Client follow-up (already scoped, not blocking this PR)** — once `net` ships,
the Flutter change clones the `includeDrafts` plumbing: a `showNet` bool on
`DashboardFilter` (folded into `filterHash` so the cache re-keys), sent as
`net=<bool>` on the three chart calls, plus a Gross/Net control in the
dashboard settings popover. No Drift schema/migration (the cache is keyed by
`filterHash`; `nav_state` is schemaless JSON).

## Recurring-invoice `amount` stored as `Σ(cost×quantity)` — drops discounts + all taxes — **R (billing correctness)**

**Provenance** — 2026-07-07, financial-calculation audit (follow-up to
[#12072](https://github.com/invoiceninja/invoiceninja/issues/12072)). Source-read of
`~/Code/invoiceninja` (`v5-develop`), verified against actual line numbers.

**Problem.** When a recurring invoice is created or updated, the server computes
and persists `amount` from **line-item subtotal only**, ignoring line + invoice
discounts, all line/invoice taxes (inclusive and exclusive), and custom
surcharges. The stored figure the API/UI reports then **disagrees with the
invoices the template actually generates**, because the send path recomputes
correctly.

**Evidence.**
- `app/Http/Requests/RecurringInvoice/StoreRecurringInvoiceRequest.php:115` —
  `$input['amount'] = $this->entityTotalAmount($input['line_items']);` (also
  `UpdateRecurringInvoiceRequest.php:106`), inside `prepareForValidation()`, which
  first zeroes `$input['amount'] = 0` (L88) then overwrites it.
- `app/Utils/Traits/CleanLineItems.php:88-97` — `entityTotalAmount()` is literally
  `foreach ($items as $item) { $total += ($item['cost'] * $item['quantity']); }` —
  no discount, no tax, no surcharge.
- Correct engine: `app/Helpers/Invoice/InvoiceSum.php::_calculateTotal` — applies
  discounts + taxes. It is what the **send** path uses:
  `app/Jobs/RecurringInvoice/SendRecurring.php:61` →
  `$this->recurring_invoice->calc()->getRecurringInvoice()`.

**Repro.** Recurring invoice, 1 line (qty 2 × cost $50 = $100 subtotal), 10%
invoice discount (−$10), 10% invoice tax on the discounted base (+$9). Correct
total **$99**. Server stores **$100** (subtotal only). When `SendRecurring` fires,
the generated invoice is **$99** — so the recurring record overstates by $1.

**Client impact.** The new Flutter app already computes the correct total via
`lib/domain/billing/totals_calculator.dart` and stamps it onto the draft
(`recurring_invoice_edit_view_model.dart:149-153`, `copyWithStampedTotals`);
`prepareForValidation()` then discards it. No client change is needed once the
server is fixed — the client is already correct.

**Required change.** In `prepareForValidation()` compute `amount` through the full
`InvoiceSum` pipeline (as the send path does), not `entityTotalAmount()`. Add a
feature test asserting a discounted/taxed recurring invoice stores the same
`amount` the generated invoice carries.

## Multi-rate **inclusive** tax extraction is mathematically incoherent (expense + invoice line-item + invoice-level) — **SHIPPED server-side**

> **STATUS 2026-07-24 — the server adopted the additive model.**
> `App\Helpers\Invoice\InclusiveTax::backout` (2026-07-09, `a6ab6c1ca9` /
> `c6d62cc43f` / `29552f4dc3`) is now the single source of truth, and all
> three paths route through it: invoice line item
> (`InvoiceItemSumInclusive`), invoice level (`InvoiceSumInclusive`) and
> expense (`Expense::getNetAmount` → `inclusiveTaxTotal`). The model matches
> what this app shipped on the same day: each component is
> `round(amount x rate_i / (100 + Sum r), precision)`, tax-anchored, with the
> net absorbing the sub-cent residual.
>
> **Two residual notes, both client-side follow-ups rather than server asks:**
>
> 1. **The invoice-level divisor is not name-gated.**
>    `InvoiceSumInclusive::calculateTaxes` feeds the raw
>    `[tax_rate1, tax_rate2, tax_rate3]` into `backout` and applies the
>    `strlen(tax_name) > 1` gate only when deciding which component to *add*.
>    So a rate carrying a blank / 1-char name still shrinks the shared base
>    for the tiers that do survive the gate. Arguably surprising, but it is
>    the stored behavior, so this app now mirrors it exactly
>    (`computeTaxBreakdown` in `lib/domain/billing/totals_calculator.dart`).
> 2. **Expense precision.** The server backs expense tax out at the client's
>    **currency precision**; `expenseTierTaxAmount`
>    (`lib/domain/expense_tax_math.dart`) hardcodes 2 decimals. Identical for
>    2-decimal currencies, divergent for JPY (0) / BHD (3). Threading
>    precision through touches every caller — not yet done.
>
> React remains unfixed. Kept below as the record of the original analysis.


**Provenance** — 2026-07-07, financial-calculation audit. This is the general
form of [#12072](https://github.com/invoiceninja/invoiceninja/issues/12072) (filed
against React for expenses); source-read confirms the same shape server-side and
across every client.

**Problem.** With **two or more inclusive tax rates** on one base (expense, invoice
line item, or invoice level), each rate is extracted **independently from the same
gross** and the results are summed: `taxᵢ = amount − amount/(1 + rateᵢ/100)`. The
resulting net reconciles to **no** valid multi-rate inclusive model — it is neither
compound (tax-on-tax) nor a shared-base extraction — because each tax is computed
as though it were the only tax, then all are subtracted together.

**Evidence (all four codebases agree — so the fix must be server-first).**
- Backend: `app/Models/Expense.php::getNetAmount` / `calcInclusiveLineTax`;
  `app/Helpers/Invoice/InvoiceItemSumInclusive.php:261,270,278` (per-rate
  `calcInclusiveLineTax($this->item->tax_rateN, $amount)` against the same
  `$amount`); `app/Helpers/Invoice/InvoiceSumInclusive.php` (invoice level).
- Clients mirror it faithfully: React `invoice-item-sum-inclusive.ts` /
  `useCalculateExpenseAmount.ts`; new Flutter
  `lib/domain/billing/totals_calculator.dart` + `lib/domain/expense_tax_math.dart`.

**Repro.** Gross $1000, two 10% inclusive rates. Current: tax₁ = tax₂ =
`1000 − 1000/1.10 = 90.91`, total tax $181.82, **net $818.18**. That is neither
compound (`1000/1.10² = 826.45`) nor shared-base additive
(`1000/(1+0.10+0.10) ≈ 833.33`, tax₁ = tax₂ = 83.33). Only the additive result is
internally consistent. The **Decision** below adopts its reconciling rounded
form — `net = round(gross − Σtax) = 833.34` (833.34 + 166.66 = 1000) — not the
raw 833.33 (which would leave a 1¢ gap).

**Decision (2026-07-09): additive shared-base, net = gross − Σtax → 833.34.**
Matches the backend helper `app/Helpers/Invoice/InclusiveTax.php` (`backout()`):
- per-rate `taxᵢ = round(gross × rateᵢ/(100+Σr), p)` (≡ `round(rateᵢ/100 × gross/(1+Σr/100), p)`), each rounded independently → **83.33** each;
- `net = round(gross − Σtax, p)` — the net absorbs the rounding residual → **833.34** (833.34 + 166.66 = 1000, reconciles). Symmetric equal-rate taxes.
Applied per rate-group: expense; invoice line item; invoice level (name-gated to `strlen(tax_nameN) ≥ 2`).

**Client status — DONE.** Both Flutter apps implement exactly this (verified
against `InclusiveTax::backout()`), each with a `Σr == rate` single-rate guard
keeping the common single-rate case byte-identical, and a `Σr ≤ 0 → 0` guard in
every inclusive primitive mirroring `backout()`'s `combined_rate <= 0` clause:
- New app: `lib/domain/expense_tax_math.dart` (`expenseTierTaxAmount`) and
  `lib/domain/billing/totals_calculator.dart` (`_taxAmount` + threaded
  `itemRateSum` / name-gated `invoiceRateSum`); net via `gross − taxAmountSum`
  on the expense/recurring-expense getters and `amount − taxAmount` on the
  invoice. Covered by new multi-rate tests.
- Old app (`admin-portal`): `expense_model.dart`, `invoice_model.dart`
  (`InvoiceItemEntity.taxAmount`), `mixins/invoice_mixin.dart`.

**Server + React — TODO (must match to the penny).** The server already ships
`InclusiveTax::backout()`; wire it uniformly through `InvoiceSumInclusive`,
`InvoiceItemSumInclusive`, and `Expense::getNetAmount`. Note `getNetAmount`
already derives `gross − Σtax`, so only the per-rate extraction needs to become
additive — the net derivation stays as-is (→ 833.34). React must adopt the same.
**Data implications:** this changes computed tax on existing multi-rate-inclusive
documents — needs a migration/reporting review, not a silent swap. Single-rate
inclusive (the common case) is unaffected — all models already agree there.

## Purchase-order PDF renders line items in the attached client's currency instead of the vendor's — **R (PDF correctness)**

**Provenance** — 2026-07-17, user report (PO/2026/0006) + source-read of
`~/Code/invoiceninja` (`v5-develop`), verified against actual line numbers.

**Problem.** A purchase order is a **vendor** document — every money value on its
PDF should be the vendor's currency. But when a PO also carries a `client_id`
(legitimately used for the drop-ship "ship to" block), the PDF renders **line-item
cells in the client's currency** while **totals stay in the vendor's currency**. A
USD-vendor PO with an EUR client attached prints EUR unit costs / line totals under
a USD subtotal/total — mixed currency on one document. The overview/detail and the
app's edit screen are correct (the edit-screen client-side fix shipped alongside
this note); this is purely the server-rendered PDF.

**Evidence.**
- `app/Services/Pdf/PdfConfiguration.php:172-179` — `setCurrencyForPdf()`:
  `$this->currency = $this->client ? $this->client->currency() : $this->vendor->currency();`
  — the client wins whenever present, and the PO's own `currency_id` (fillable at
  `app/Models/PurchaseOrder.php:212`, transformed at
  `app/Transformers/PurchaseOrderTransformer.php:152`) is ignored. The PO branch of
  `setEntityType()` (`:264`) sets `$this->client = $this->entity->client ?? null`.
- Line-item cells format via `$this->service->config->formatMoney(...)` in
  `app/Services/Pdf/PdfBuilder.php` (unit_cost `:1065`, cost `:1069`, line_total
  `:1071`, gross_line_total `:1085`, tax_amount `:1091`, discount `:1098`) → the
  client currency above.
- Totals come from `VendorHtmlEngine` (`app/Utils/VendorHtmlEngine.php`), which
  formats every total with `Number::formatMoney($value, $this->vendor)` (subtotal
  `:179`, total `:223`, balance_due `:205/210`) → always the vendor currency.
  `PdfService` selects `VendorHtmlEngine` for a `PurchaseOrderInvitation`
  (`:98-104`, `:207-214`). Hence the split.

**Repro.** Create a PO for a USD vendor; attach a client whose currency is EUR
(via API/import or a drop-ship link — the field is `fillable`). Generate the PDF
(`POST /api/v1/live_preview/purchase_order`, or the emailed/downloaded PDF): line
items print `€`, subtotal/total print `$`.

**Client impact.** None — the Flutter app forwards correct data. It never sets a PO
`client_id` itself (the PO editor hardcodes it empty) and never sends a
`currency_id`; it only round-trips a `client_id` already present on the server
record (which the server also needs for the ship-to block, so the client can't just
drop it). Only the server can make the line items match the vendor-currency totals.

**Required change.** In `PdfConfiguration::setCurrencyForPdf()`, special-case a
purchase order to use the **vendor's** currency (or the PO's own `currency_id`) for
`$this->currency`, so line-item cells and the `VendorHtmlEngine` totals agree. Add a
feature test: a PO with a differing-currency client attached renders unit costs and
line totals in the vendor currency, matching the subtotal/total.

## Broken bulk actions surfaced by the 2026-07-15 deep review

These client actions send server-valid-looking requests that the API rejects or
mishandles. Client-side mitigations were applied where noted; the server fixes
below are still needed.

### Cross-type clone (`clone_to_quote` / `clone_to_invoice`) 500s (review #17)
`InvoiceController::performAction` / `QuoteController` handle `clone_to_quote` /
`clone_to_invoice` inside the **bulk** action by mutating `$this->entity_transformer`
to the target type and returning `itemResponse($clonedEntity)`. In the bulk
response wrapper this 500s (transformer/response-type mismatch), so the old
client "Clone to quote" / "Clone to invoice" produced a success toast then a dead
outbox row — nothing was created. **Client FIXED (no longer server-blocked):** the
two cross-type clones now build the target draft **locally** (`cloneToQuote` /
`cloneToInvoice` in `billing_cross_clone.dart`) and open it in the target's create
form — exactly like the already-working invoice→credit/recurring/PO clones — so
they never hit the broken server bulk path. The server bug is still worth fixing
(any API consumer using `clone_to_quote`/`clone_to_invoice` 500s), but it no
longer blocks the client. (The dormant `cloneTo` server-clone repo/API/outbox
handlers are now unused by the UI — safe to prune in a follow-up.)

### `payment_schedule` scheduler update ignores row edits (review #13)
`UpdateSchedulerRequest` for `template == 'payment_schedule'` overwrites
`parameters.schedule` with the existing stored value (only name + auto_bill are
editable on update). So editing an existing schedule's installment rows is
silently discarded. **Client mitigation:** the edit screen makes existing rows
read-only. If per-row edits should be supported, the server must accept an updated
`parameters.schedule` on update.

### Recurring-invoice `template` bulk action unsupported (review #19)
`BulkRecurringInvoiceRequest` action whitelist has no `template`, and the
controller has no template branch, so the client's "Run template" 422'd into a
dead outbox row. **Client mitigation:** the action was removed from the recurring-
invoice menu. (The `/api/v1/templates` route is a design-preview engine, a
different feature.) If "run template" should exist for recurring invoices, add a
server action/endpoint.

### Bank-rule `is_empty` operator: save 422s (review U2)
`ProcessBankRules::matchStringOperator` supports `'is_empty' => empty($bt_value)` (matches on the transaction's empty field, ignoring the rule value), but the store/update request validates `rules.*.value` as required, and `ConvertEmptyStringsToNull` turns the empty value → null, so saving a rule that uses `is_empty` 422s and parks in the outbox. The engine supports the operator; the request validation should allow an empty/absent `value` when the operator is `is_empty` (e.g. `required_unless:rules.*.operator,is_empty`). **Client mitigation:** the `is_empty` operator is no longer offered for DEBIT (bank-transaction-field) rule criteria, since it always 422'd. CREDIT criteria keep it (their `value` carries a non-empty `$invoice.*`/`$payment.*`/`$client.*` placeholder the server accepts). Re-add the DEBIT option once the request validation is relaxed.

### Dashboard `totals_v2` exposes no overdue count/amount (review U7)
`ChartQueries::getOutstandingQuery` / `getAggregateOutstandingQuery` return only an `outstanding` bucket — `SUM(balance)` + `COUNT(*)` over `status_id IN (2,3)` (sent + partial) with the invoice **issue** `date` in the dashboard window. There is **no** overdue dimension (`due_date < today`), so `/api/v1/charts/totals_v2` gives the dashboard no genuine overdue count/amount to bind to. **Client mitigation:** the KPI tile that reused `outstanding_count` under an "Overdue" label (whose number and drill-through disagreed) is relabeled **"Unpaid"** (a count of unpaid invoices) and drills through to the same windowed-unpaid list as the sibling "Outstanding" amount tile. If a true Overdue KPI is wanted, `totals_v2` should add an overdue `{amount, count}` bucket (`due_date < today AND status_id IN (2,3)`), after which the client can restore an "Overdue" tile bound to it.
