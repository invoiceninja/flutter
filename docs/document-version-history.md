# Document version history

Companion to CLAUDE.md § Document version history. The main file carries the rules one line each;
this doc carries the evidence — what the server actually stores, why only one include works, and
the three server limits the UI has to admit.

Shipped for invoiceninja/flutter#168, which asked for WordPress-style revisions on `invoice`,
`quote` **and `client`**, plus git-style "what changed" detail in the Activity log. Only part of
that is possible, and the boundary is a server one — see § What the server does not store.

## The server writes one backup per non-email activity, for five entity types only

`ActivityRepository::save()` calls `createBackup()` for every activity **except** the four email
types (`EMAIL_INVOICE` / `EMAIL_CREDIT` / `EMAIL_QUOTE` / `EMAIL_PURCHASE_ORDER`), so a plain
"emailed" row can never appear in a history list. `createBackup()` then branches on the entity
class: **Invoice, Quote, Credit, RecurringInvoice** store against the client, **PurchaseOrder**
against the vendor, and everything else falls through with no row at all.

`Client` has no `history()` relation and no backup rows — verified live: a client activity's
download returns `{"message":"No backup exists for this activity"}`. Neither do payments, expenses,
tasks, projects, vendors or recurring expenses. A client's `?include=activities.history` *does*
return populated history objects, but those are the client's **invoice** activities, which is a
different thing and reads as a false positive if you probe only that.

## What the server does not store, and why no client can diff

The backup is a **rendered HTML document** written to object storage — `Backup::storeRemotely()`
saves `…/Y_m_d_<md5>.html` and keeps only `filename` + `disk` in the row. There is no entity
snapshot:

- `json_backup` is a `mediumText` column that `createBackup()` explicitly writes as `''`, and
  `InvoiceHistoryTransformer` hardcodes `''` on the wire regardless.
- `html_backup` was **dropped from the table** in 2022
  (`2022_11_06_215526_drop_html_backups_column_from_backups_table.php`), and the transformer still
  emits the key marked `//deprecated`.

So a version can be *shown* (as a PDF) but never diffed, never restored, and never inspected
field-by-field. Item (b) of #168 — "revision-style information in Activity logs, comparable to how
Git commits or WordPress revisions document modifications" — is backend work, spec'd in
`BACKEND.md`. What the app does instead is render the four facts the payload genuinely carries:
the event, the document total, who did it, and when.

## `activities.history` is the only include that works

Three dead ends, all measured against `demo.invoiceninja.com`:

| request | result |
|---|---|
| `?include=activities.history` | **works** — this is the one |
| `?include=activities` | activities, but every `history` key absent |
| `?include=history` | silently dropped |

`history` is not in `InvoiceTransformer::$availableIncludes` (nor Quote's, Credit's,
RecurringInvoice's or PurchaseOrder's) even though each defines an `includeHistory()` method, and
`BaseController::getRequestIncludes()` drops any include it cannot match. The nested form resolves
through `ActivityTransformer::$availableIncludes`, which *does* list it.

**`POST /activities/entity` can never carry it.** That endpoint — which backs this app's entire
per-record activity feed — calls `->without('backup')` and returns flat `activity_string()` rows.
That is why version history has its own model and its own service rather than extending
`ActivityApi`: they are two different serializers of the same table.

`GET /activities?include=history` does carry it, but the index accepts **no entity filter at all**
(it returns the last 75 company-wide rows, `->take($default_activities)` with no `where`), so it is
useless per-record.

## The `history` object is present even when there is no backup

```json
"history": { "id": "", "activity_id": "", "json_backup": "", "html_backup": "",
             "amount": 0, "created_at": 0 }
```

`InvoiceHistoryTransformer` has a null-backup branch that serializes this shell rather than
omitting the key, so `history != null` is not the question — **`history.id` non-empty is**. Legacy
admin-portal (`invoice_view_history.dart`) and the React client (`History.tsx`) both gate on
exactly that, and so does `DocumentVersion.fromApi`.

## Wire types, which are not what you would guess

Probed live, and each one is a real coercion hazard:

- `activity_type_id` is a **string** (`"5"`) from `ActivityTransformer` — an `int` from the
  `/activities/entity` serializer. Both are parsed through `jsonScalarToStringOrEmpty`.
- `history.amount` is a **float**, and is typed `Object` + `parseMoney` because raw-JSON blobs
  bypass the server's read-time casts, so an int or a string is reachable.
- `created_at` is epoch **seconds**, built with `epochSecondsToUtc`. A non-UTC `DateTime` renders
  an ISO string with no `Z`, which `Formatter.date(showTime: true)` then localizes a **second**
  time — a silent offset, not an error.

## Three server limits the UI has to admit rather than hide

**The list is capped at 50 activities, with no pagination.** `Invoice::activities()` — and the
identical relation on the other four — is
`->where('client_id', $this->client_id)->orderBy('id','DESC')->take(50)`. There is no parameter to
widen it. A long-lived document therefore loses its oldest versions, which is why
`DocumentVersionPage.truncated` exists and why the tab prints a footer rather than implying the
list is complete. It is also why **the oldest row gets no delta**: its real predecessor may be
outside the window, so a delta there would be measured against a version we simply do not hold.

**Free and trialing hosted accounts get no backups at all.** `createBackup()` returns early on
`$entity->company?->account->isFreeHostedClient()`, which is `plan` free/null/empty **or** a
`plan_expires` more than 12 hours past. For those accounts the History tab can never fill, and
"No records found" would be a confident falsehood — hence the second empty state.

The client-side predicate is `isHosted && (!isPaidPlanSlug || isPlanExpired)`, deliberately **not**
`AuthSession.isFreePlan`: that routes through `hasProAccess`, which is trial-aware, so it reports
`false` for exactly the trialing user whose history is empty. The server's predicate has no trial
branch. Self-hosted is never affected (`Ninja::isNinja()` guards the whole thing).

Two deliberate divergences from the server rule. `isPlanExpired` has **no grace window** while the
server allows 12 hours, so for up to half a day after expiry the tab claims a paid plan is needed
while backups are still being written — it over-reports, which is the safe direction for a message
that only shows when the list is *also* empty. And the empty state's action is a plain upgrade
button rather than `PlanGateBanner`: that widget self-hides on the trial-aware `hasProAccess`, so
pairing it with this slug-only gate would show a trialing user "available on a paid plan" with no
CTA at all, behind the 24 px gap `EmptyState` reserves for a non-null action.

**The relation filters on the document's *current* party.** `where('client_id', …)` /
`where('vendor_id', …)` compares against the live document, while each activity row carries the
party it was written under. The party is frozen after save (`docs/pickers.md` § A field the server
freezes is a locked row), so the only way to reach this is a **client merge**, which moves
documents but leaves their old activities behind. Accepted; noted so it isn't re-diagnosed as a
client bug.

## Ties are broken on arrival order, never on the id

`created_at` is second-resolution, so a save followed immediately by mark-sent — or any bulk
action — lands several versions on one second. The tie-break is the row's **arrival index**, which
is the server's own `orderBy('id','DESC')`.

Not `activityId`: that is a **hashid**, deliberately non-monotonic, so comparing it
lexicographically is an arbitrary permutation of real activity order (`docs/dashboard-panels.md`
§ Most recent needs a tie-break records the same trap). And not sort stability either — `List.sort`
is stable only below `_INSERTION_SORT_THRESHOLD` (32) and this window holds up to 50.

It matters beyond ordering: the tab derives each row's amount delta from list **adjacency**, so a
mis-ordered pair renders its delta with the wrong sign.

## A 404 here is a real data condition — the one place on this API where it is

`api_client.dart`'s `case 404:` documents the premise that this server 404s only when *we* built a
bad URL, and maps it to a plain permanent `ServerException` for that reason. `download_entity`
breaks the premise: `generateHtml()` returns `''` when the document has no invitation or no design,
`storeRemotely()` early-returns on empty HTML, and the `Backup` row is left with `filename = null`.
Such a row still has a non-empty `history.id`, so it passes the list gate and 404s on open. The
message (`"No backup exists for this activity"`) is surfaced verbatim by `BillingDocPdfView`'s
`ErrorView`, which is why nothing in this path swallows or rewrites it.

## Deliberately not in Drift

CLAUDE.md § Strict rules says Drift is the only thing the UI reads from. This bypasses it, exactly
as the per-entity activity feed already does, and for the same reason: it is remote-only metadata
about remote blobs. Nothing here is offline-editable, nothing goes through the outbox, and there is
no table — so **no schema bump and no migration**. `DocumentVersionsApi` mirrors `ActivitiesApi`'s
four cache rules (credential-fingerprint key, stored timestamp rather than a `Timer`, in-flight
dedupe, generation guard) and joins both `clearCache()` fan-outs in `services.dart`.

The cache is a **first-frame seed, never a fetch suppressor** — `kick()` adopts it without
notifying (it runs from `initState`) and then requests anyway, the same contract as the sibling
activity feed. Two readers make it worth having: stepping back onto a record paints instantly, and
tapping a version on narrow hands `/pdf?activity_id=` a list the History tab already fetched
instead of re-GETting the whole document. **A seed that nothing reads is worse than no cache** —
the first cut shipped `peek()` with no caller while three comments claimed it deduped the tab
against the route, which it could not, because the two are sequential and `_inFlight` only covers
simultaneous calls.

Staleness is handled by the tab, not the cache: a save writes a new server-side version while the
tab's `State` outlives the edit round trip (the edit route is a child, so the detail page stays
mounted underneath), so `didUpdateWidget` refetches when the record's `updatedAt` moves. Without
that the list keeps its old rows while the **Current version** row's amount updates from the
watched entity — the card visibly contradicting itself.

## Wide swaps the pane; narrow routes

`router.dart` notes that `extraChildRoutes` like `/invoices/:id/pdf` are siblings of the
`ShellRoute`, so they take the **whole** screen. On a wide layout the detail screen is already
showing the live PDF beside the tabs, and navigating there would destroy the list, the tabs and the
very document the user wants to compare against. So on wide, selecting a version drives a
`ValueNotifier<String?>` the screen owns and `VersionedPdfPane` re-renders in place under a banner;
narrow has no pane and keeps the route.

**The pane must keep a fixed tree shape.** Returning a bare `BillingDocPdfView` for the live
document and a `Column` for a version flips the runtimeType at that slot, so `Widget.canUpdate` is
false and the framework rebuilds the element from scratch — discarding `_bytes` and blinking to a
full-pane spinner at zoom 1 on the two commonest transitions, which is precisely the remount the
`revision:` seam exists to avoid. The banner slot is therefore always occupied, by
`SizedBox.shrink()` when live.

Two things about the route that are easy to get wrong:

**Do not re-key `BillingDocPdfScreen` on the selected version.** That widget *is* the `Scaffold` +
`AppBar` + body, so a remount tears down the picker the user just tapped — and `MenuAnchor` closes
*after* its item callback runs, so `BackDismissibleMenuAnchor._release()` would never un-register
the back dispatcher. It also discards the deliberate "keep the last-good PDF behind a translucent
overlay" behaviour for a full-pane spinner at zoom 1. The seam is `revision:` plus
`autoRefreshDebounce: Duration.zero`, both already constructor params on `BillingDocPdfView`, whose
generation counter handles the race.

**Selection is local state seeded from `?activity_id=`, not written back to the URL.** That is the
same contract the delivery-note toggle beside it already has (`?delivery_note=true` seeds
`_deliveryNote`, the toggle then owns it). Writing each pick back through `context.go` would append
one `NavHistoryController` entry per tap, and a user comparing four versions should not need four
presses of back to leave the screen. The deep link still works, and `stripTransientQuery` preserves
`activity_id` so a restored route reopens on the same version.

## Row content, and the three rules behind it

**The event label is `kActivityTypeLabelKeys`, never `buildActivitySpans`.** The templated
`activity_<id>` sentences substitute `:token`s from `Activity.refs`, which this payload does not
carry — an absent ref falls back to `context.tr(token)`, so `activity_5` renders as the literal
*"User updated invoice Invoice"*. `docs/comments-and-activity.md` records that exact failure
shipping for real on credits. The short catalog labels are already user-facing in the Reports
activity filter, so they cost no new strings.

**The tone map was extended, and its test pins it.** `kActivityTones` was partial in a way that
mattered here: on credit, purchase order and recurring invoice **every** row resolved to neutral
grey. Six create/update arms (`14`/`15`, `100`/`101`, `130`/`131`) plus `137` (PO accepted → `paid`,
the vendor-side mirror of `29`) now cover the set that can actually appear. `activity_formatter_test`
holds a hardcoded `exact` allowlist for the non-lexical arms — extend it in the same commit or the
build fails, which is the guard working as designed.

**A zero delta renders nothing.** `$backup->amount = $entity->amount` is assigned after
`$entity->fresh()`, so it is the total *after* the event and a delta between consecutive kept rows
is honest. But most events — mark sent, archive, restore, a reminder — leave the total alone, and
this is an unlabelled slot, so `docs/row-actions-and-values.md` applies directly: a column of
`$0.00` would claim a change that did not happen. `Formatter.money(zeroIsNull: true)` returning
`''` is the predicate, and the blank slot is itself the signal. No colour either — green and red are
semantic on these screens (paid / overdue), and a total moving up is not good news.

**An unresolved actor is never an em dash.** An edit *was* made by somebody, so this follows
`UserAvatar`'s rule rather than `UserNameLabel`'s. Resolution order is `is_system` → portal contact
→ roster user → `tr('user')`, and the contact is checked first because an approval or rejection
from the other side is the change users least expect to find.

## Two strings that look available and are not

**There are three empty states, not two.** Besides the plan branch and the ordinary one, a
`tmp_` (offline-created) record short-circuits before any request — `requireSynced`'s sentence goes
in the *subtitle*, since `title` renders at `titleMedium` and every other empty state puts its
sentence there.

**`no_history` is unusable.** `fr.json` carries it as Greek (`Κανένα Ιστορικό`) and `zh_CN` as
English, and `_app_pending.json` can only *add* a key, never override a present-but-wrong locale
value (lookup order is active locale → `en.json` → pending). The empty state uses
`no_records_found`, which is clean in all eleven bundles — the same substitution
`billing_doc_sends_tab.dart` already made. `docs/contacts-and-invitations.md` litigated this key
once before.

**There is no plural `versions` key** in any bundle, which is why the tab is labelled
`tr('history')` despite the screens already having an Activity tab and an Email History tab. What
disambiguates it is the **icon**: `Icons.layers_outlined`, never `Icons.history_outlined`, which all
five screens already give to Activity — two slots to the left, three on a recurring invoice where
Schedule intervenes. On a narrow pane the strip shows about three tabs, so the same clock twice
would be a coin flip the user cannot even see to resolve.
(`current_version` *is* translated everywhere, including `zh_CN`, which is why the anchor row costs
nothing.)
