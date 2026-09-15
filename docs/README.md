# docs/

Topic docs for the Invoice Ninja Flutter v2 admin app. `CLAUDE.md` at the repo root is the index
of rules — one or two lines each; these files carry the evidence behind them: the mechanism, the
SDK or server source that explains it, the measured numbers, and the failure each rule shipped as.

Start at `CLAUDE.md`'s Quick Index, which routes by symptom. `ARCHITECTURE.md` is the
read-it-first orientation for a new developer.

- [`adding-an-entity.md`](adding-an-entity.md) — **Adding a new entity.** The main file lists the leverage points and the 13-step recipe at a glance; this doc carries the full shape of each step, the standard / non-standard action helpers, and the bundled-entity sub-recipe.
- [`architecture.md`](architecture.md) — **Architecture.** The MVVM block diagram and the layered-split summary live there; this doc carries the DI / routing / persistence / HTTP detail, the offline-first write pipeline, and the on-disk project layout.
- [`comments-and-activity.md`](comments-and-activity.md) — **Comments and the activity feed.** A comment is an `activity_type_id = 141` row, so comments and activity are one feed rendered two ways.
- [`contacts-and-invitations.md`](contacts-and-invitations.md) — **Server-seeded contacts and invitations.** The server seeds rows the user never created — one blank contact per client and vendor, one invitation per send-email contact, and a placeholder email address it typed itself — so `isNotEmpty` is never the question.
- [`contacts-sync.md`](contacts-sync.md) — **Contacts sync — pushing client contacts to the device address book.** Settings → Device Settings → **Contacts**.
- [`dashboard-panels.md`](dashboard-panels.md) — **Dashboard panels.** The main file carries the registry shape — how a panel is declared, ordered and hidden — and the rule for each behaviour; this doc carries the evidence — the task-calendar panel (the first Drift-backed one), the consolidated Invoices & Quotes strip, and the ordering rules both depend on.
- [`deep-links.md`](deep-links.md) — **Deep links.** The main file carries the link shapes and the rule for each behaviour; this doc carries the evidence — why the https form replaced the custom scheme, why Flutter's own deep linking must stay off, the arrival choreography, and the registry obligations a new entity inherits.
- [`desktop-window-state.md`](desktop-window-state.md) — **Desktop window state.** Each desktop runner persists window size, position, and fullscreen across launches via the host OS's native preference store.
- [`diagnostics.md`](diagnostics.md) — **Diagnostics log.** Debug-only on-disk capture so future Claude sessions can read what went wrong without the user copy-pasting console output.
- [`entity-lists.md`](entity-lists.md) — **Entity lists — columns, status tabs, state filter, counters.** The main file carries the registry shapes and the rule for each behaviour; this doc carries the evidence.
- [`form-fields.md`](form-fields.md) — **Form field input types.** Every text input declares the keyboard, capitalization and autofill its data needs, and none of it is visible under `flutter test` — a soft keyboard never renders.
- [`integration-tests.md`](integration-tests.md) — **Integration tests.** `integration_test/app_smoke_test.dart` boots the real `InvoiceNinjaApp` with in-memory Drift + `InMemoryTokenStorage` and a `MockClient`.
- [`keyboard.md`](keyboard.md) — **The keyboard layer.** Shortcut discoverability, the focus invariant the whole keyboard layer hangs off, the `G`-leader table, and how a key is drawn in a cap.
- [`migrations.md`](migrations.md) — **Drift schema migrations.** **The app is shipped (beta).** Installed databases hold real user data and unsynced outbox.
- [`pane-width-and-overflow.md`](pane-width-and-overflow.md) — **When content doesn't fit its pane.** Four surfaces that overflowed a narrow pane, and the arithmetic behind each fix.
- [`pickers.md`](pickers.md) — **Searchable pickers.** The main file carries which widget to reach for and one line per rule; this doc carries the evidence.
- [`popup-dismissal.md`](popup-dismissal.md) — **Overflow menus and popups.** Which glyph an overflow menu wears, and how a surface that is not a route gets closed.
- [`probing-the-demo-api.md`](probing-the-demo-api.md) — **Probing the demo API.** The main file lists the legacy code pointers; this doc carries the live-server probe workflow.
- [`reports.md`](reports.md) — **Reports.** The main file carries the server-backed shape and the rule for each behaviour; this doc carries the evidence — the server-side `$date_key` map, the optional-date-column mechanism, and the chart's bucketing and labelling rules.
- [`rich-text-editing.md`](rich-text-editing.md) — **Rich text editing.** `MarkdownTextField` is the shared WYSIWYG editor for the note-shaped fields, which are HTML on the wire: what converts in each direction, and how a read-only surface renders one.
- [`row-actions-and-values.md`](row-actions-and-values.md) — **What a row shows, and what its actions do.** A narrow list row carries no labels, which changes what a tap means and what an empty value should render as.
- [`settings-screens.md`](settings-screens.md) — **Settings screens.** The main file carries the 5-second decision tree, the three style names, and the User-Details anti-pattern.
- [`setup.md`](setup.md) — **Setup.** .
- [`sidebar-and-shell.md`](sidebar-and-shell.md) — **The sidebar and the page shell.** The sidebar's own chrome — safe areas, ink, the upsell gate, the customisable menu and the pinned rows — plus which widget owns a full-page host.
- [`store-deployment-setup.md`](store-deployment-setup.md) — **Store deployment — setup runbook.** **How to get the six publish workflows working from zero.** This is the *how*; `docs/setup.md` §§ Shipping to the stores → Windows / Microsoft Store is the *why* (rationale, design decisions, per-platform background).
- [`sync.md`](sync.md) — **Sync — the non-obvious rules, with evidence.** The main file still states all 28 rules, one line each — it is the most-cited anchor in the repo.
- [`tap-to-call.md`](tap-to-call.md) — **Tap to call — dialling a phone number from the app.** Settings → Device Settings → **Phone numbers**.
- [`task-scheduling.md`](task-scheduling.md) — **Task scheduling — booked blocks and starting the timer.** A task carries no stored start time, so scheduling one means seeding a future `time_log` entry — which makes "start the timer" a decision rather than an append.
- [`tasks-views.md`](tasks-views.md) — **Tasks layout views.** The main file carries the `?view=` / `nav_state` precedence rule and the rule for each behaviour; this doc carries the evidence — why the URL is an override rather than the carrier, what the lock exists for, and why the kanban board has no create FAB.
- [`template-variables.md`](template-variables.md) — **Email-template variables as chips.** One topic that used to have two homes: the chips are super_editor inline placeholders, so the field rules and the editor rules belong together.
- [`token-rotation.md`](token-rotation.md) — **API token rotation (is_system UI token).** **Status: blocked on server.** Implement the client side once the backend ships.
- [`touch-targets.md`](touch-targets.md) — **Touch targets.** Hit-area size is a property of the input device, not the viewport — which is why it is the one responsive branch in the app that does not key off width.
- [`upstream-workarounds.md`](upstream-workarounds.md) — **Upstream-bug workarounds.** The single registry of workarounds this app carries for **open upstream bugs/limitations** — in Flutter, Dart, third-party pub packages, or platform SDKs — that we expect to **remove once the upstream ships a fix**.
