# Contacts sync — pushing client contacts to the device address book

Settings → Device Settings → **Contacts**. One-way, device-local, opt-in: Invoice Ninja client
contacts are written into the phone's own address book so an incoming call resolves to a name and a
company on the call screen. From [invoiceninja/flutter#54](https://github.com/invoiceninja/flutter/issues/54).

**Android + iOS only.** `DeviceContactsService.canSync` is `Env.isMobile`, and the settings card
renders nothing at all where that's false — there is nothing a desktop or web user could do about it.
macOS is excluded deliberately: its sandbox would need a
`com.apple.security.personal-information.addressbook` entitlement in both `macos/Runner/*.entitlements`.

## The shape

```
ContactsSyncController          device-local preference + single-flight guard   lib/app/
  └─ ContactsSyncService        the reconcile (implements ContactsSyncEngine)   lib/domain/contacts_sync/
       ├─ buildCards()          pure Client → List<DeviceContactCard>           lib/domain/contacts_sync/
       ├─ ClientRepository      paged, non-streaming read from Drift
       ├─ DeviceContactLinkDao  what we wrote last time (company_id, source_id) lib/data/db/dao/
       └─ DeviceContactsService the platform seam (io / web)                    lib/data/services/
```

`ContactsSyncEngine` (in `contacts_sync_types.dart`) is a four-method interface the service
implements, so the controller unit-tests against a fake instead of dragging in `ClientRepository`,
Drift and the platform seam.

## Card mapping

One card per **client contact**, not per client — caller ID resolves a number to a *person*.

| Device field | Source |
|---|---|
| name | contact first/last; the client's name if the contact is unnamed |
| organization | the client's display name |
| phones | the contact's phone (`mobile`) + on the **primary** contact only, the client-level phone (`work`) |
| email | the contact's email |
| address / website | the client's billing address and website |

Plus two rules that are easy to break:

- **A card with neither a phone nor an email is dropped.** It can't do the job the feature exists for
  and is pure noise in the address book.
- **A client whose contacts all drop out still yields one card from its own record**, keyed
  `client:<clientId>` — a company that never named a person shouldn't be invisible.

`cardHash()` fingerprints everything written to the device. **Any field added to `DeviceContactCard`
must be added to the hash too**, or edits to it will never propagate: the reconcile skips a card whose
hash matches, and that's what makes a repeat sync cost one Drift read instead of thousands of writes.
The hash is over a JSON encoding, not a joined string, so `["Jane Smith",""]` and `["Jane","Smith"]`
can't collide.

## The reconcile

`ContactsSyncService.run` never throws — every failure comes back as a `ContactsSyncSummary`.

1. Gate on `canSync`, a company, and **`granted`** permission.
2. Refresh clients **if the caller asked for it** (`refreshClients`) — the local cache only holds
   page 1 until the user browses, so reading straight from Drift would sync a fraction of the book.
   `isFirstRun` then picks full vs delta. A failure here is logged and the stale cache used; doing
   nothing would be worse. See § Who refreshes below.
3. `ensureGroup('Invoice Ninja — <Company>')`.
4. Read active clients from Drift in pages of 100 (`ClientDao.pageForContactSync`), skipping `tmp_`
   ids (an offline create whose id is about to change).
5. Read the label's members, then diff the desired cards against the link table → create / update /
   **unchanged** / delete. Membership is read *before* the diff on purpose: it's what proves a link
   still points at a real card. A contact the user deleted by hand would otherwise be "updated" into
   the void, get a fresh hash stamped on its link, and read as unchanged forever after — gone from
   the device and never re-created.
6. **Heal against the label** (below).
7. Apply in chunks, polling `isCancelled` between them, persisting link rows **per chunk**.

### Who refreshes

`refreshClients` is the **caller's** decision, not something `run()` always does, because the answer
depends on what just happened:

| Caller | Refresh? | Why |
|---|---|---|
| Post-Sync hook (`services.dart` resync runner) | no | `syncNow` just re-downloaded every client; refreshing again pages the whole list a second time, back to back, with the Sync spinner up |
| First-enable pre-flight → `previewCardCount` | **yes**, full | the count is the number the user decides on |
| First-enable → `run` straight after | no | the pre-flight just refreshed |
| Settings "Sync now" | yes, delta | cheap, and the user asked |

Get it wrong and you lose performance, not correctness — but the pre-flight case is the exception:
counting off an unrefreshed cache reports ~50 for an account with thousands, which inverts the one
guard rail this feature has.

### Ownership is the label, not the link table

Everything the feature writes goes into one group per company, and the reconcile deletes any group
member it has no link row for. That's what makes it recover from `logout()` wiping the link table, or
a pass dying between the OS write and the Drift write — without it those cards would be stranded
forever and the next run would create duplicates beside them. **Contacts outside the group are never
read, written or deleted.**

#### …but an empty group is ambiguous, so it is never trusted on its own

Membership answers "is this link's card still real?" — except when the group itself is empty, which
means one of two opposite things:

* the user deleted the **cards** by hand, and they really are gone; or
* the user deleted the **label** (or the device only just gained its first contacts account), so
  `ensureGroup` minted an empty replacement while every card is still sitting there.

Reading the second case as the first re-created the entire address book, and `upsertAll` then
re-pointed each link at the new copy — leaving the originals outside the new group where the heal
pass can never reclaim them, not even via *Remove synced contacts*. So a link whose card is **not**
in the group is not dead yet: `_reconcile` asks `DeviceContactsService.existingContactIds` (one
platform call, and only for links that already failed the membership test) and keeps the ones that
still exist, then re-adopts them with `addContactsToGroup` so the next pass can go back to trusting
membership by itself. A card that genuinely was deleted returns from neither, and is re-created as
before.

### …and the label is found by id, never by name

Since the reconcile deletes every group member it doesn't recognise, *which* group a company resolves
to is a data-safety question, not a lookup detail. `labelFor(companyName)` is a **display name only**:
two companies can share a name, and every unnamed one falls back to a bare `Invoice Ninja`. Resolving
by name therefore handed them one group, and each pass deleted the other company's cards off the
phone — silently, in both directions, and the same flaw let "Remove synced contacts" for one company
wipe the other's.

So `ContactsSyncService._resolveGroupId` keys on the **company id**:

- `ContactsSyncGroupStore` (implemented by `ContactsSyncController`, persisted in the device-local
  `nav_state.contacts_sync_json` blob alongside `enabled` / `scope` / `lastRun`) remembers
  `companyId -> groupId`.
- `ensureGroup(label, knownId:)` tries that id first. Finding it under a *different* name means the
  company was renamed, so the label is renamed to match rather than orphaned.
- The name lookup survives only as the upgrade path for installs predating the stored id, and is
  **refused** when another company already claims what it finds — otherwise the second company to
  sync would adopt the first one's group and the collision would outlive the fix.
- Refused, or genuinely absent, the pass calls `createGroup(label)`, which creates a second label
  *with the same name*. Groups are identified by id, so two same-named companies honestly get two
  same-named labels — better than one of them carrying a suffix built from a raw company id.

The blob is free-form JSON and `restore()` tolerates missing keys, so this needed no schema bump.

## Traps

Each of these is a real constraint that was verified in the `flutter_contacts` 2.2.2 sources, and each
fails in a way that doesn't look like the cause.

- **One account, used for both the label and the contacts.** `GroupUtils.addContactsToGroup` throws
  `IllegalStateException` if the group has a null account, and throws again if the contact has no raw
  contact *in that same account*. `NativeDeviceContactsService` resolves one `Account` once
  (`accounts.getDefault()`, else the first listed) and passes it to both `groups.create` and
  `create`. Getting this wrong doesn't degrade — it throws on the first grouped write.
- **No account ⇒ no label, not a failure.** A device whose contacts are local-only has no account to
  hang a group on. `ensureGroup` returns `null`, the sync runs *without* a label, `summary.labelled`
  is false, and the heal step is skipped (the link table is then the only ownership record).
- **`update` only writes properties you fetched.** The package enforces this. The `get()` before an
  `update()` requests exactly `_ownedProperties`; fetch a narrower set and those writes are silently
  dropped — a sync that runs clean and changes nothing.
- **iOS 18's `limited` grant is not enough.** We could neither enumerate our own label nor trust a
  diff built from a partial view, and that diff implies deletes. It's reported distinctly so the UI
  can explain rather than no-op.
- **`logout()` wipes the link table.** `AuthRepository.onBeforeDataWipe` (destructive path only — not
  the `preserveLocalData` idle-timeout re-lock) runs `removeAllCompanies` first. Without it a
  signed-out user's whole client list stays in their address book.
- **A blank user id must never widen the scope.** `ClientDao.pageForContactSync` treats a null *or
  empty* assignee as "no filter" — a reasonable general contract, but it means passing an empty
  `currentUserId()` through would silently turn "Assigned to me" into every client in the company.
  `_desiredCards` fails closed with `ContactsSyncOutcome.noUser` instead.
- **`removeAll` uses `findGroup`, not `ensureGroup`.** The latter is find-*or-create*, so on a
  teardown path it would briefly add a label to a device that never had one. It resolves through the
  same stored group id (above), so purging one company can't reach an identically-named sibling's
  cards.
- **`labelFor` is not an identity.** It is derived from the company name, so it collides by design —
  see the section above. A change that makes anything resolve a group by name alone re-introduces a
  silent contact-destroying bug; `test/domain/contacts_sync/contacts_sync_service_test.dart`'s
  "two companies never share a group" group is the guard.
- **`removeAllCompanies` awaits the in-flight pass**, it doesn't just `cancel()` it. Cancellation is
  cooperative and returns immediately, so a running pass would otherwise keep creating contacts after
  the removal deleted them — and `_db.wipe()`, a moment later, destroys the link table that recorded
  them.
- **Cards land in the OS default account**, which for most Android users is a Google account that
  syncs to the cloud. That's what makes the feature useful across devices, but it is real data egress
  — the help text says so.

## Changing it

- **A new card field**: add it to `DeviceContactCard`, `buildCards`, `cardHash`, `_toContact`, and
  `_ownedProperties` if it's a new `ContactProperty`.
- **A new scope**: add to `ContactsSyncScope` (never rename an existing `id` — a stored preference
  would silently fall back to `all`, which on a large account means a flood of cards), extend
  `ClientDao.pageForContactSync`, and add the label key to `kContactsSyncSearchKeys`.
- **A new settings string**: `assets/i18n/_app_pending.json`, and check it doesn't already exist in
  `en.json` (a shadowed pending key is dead — lookup is locale → `en.json` → pending).

## Tests

| What | Where |
|---|---|
| Card mapping + hash | `test/domain/contacts_sync/contact_card_builder_test.dart` |
| Reconcile, heal, scope, removal | `test/domain/contacts_sync/contacts_sync_service_test.dart` |
| Preference persistence + single-flight | `test/app/contacts_sync_controller_test.dart` |
| Paged Drift read | `test/data/db/dao/client_dao_contact_sync_test.dart` |
| Settings card + permission states | `test/ui/features/settings/widgets/contacts_sync_section_test.dart` |

Widget tests **must** inject a fake via `buildFixture(deviceContactsService:)` — `flutter test`
reports `TargetPlatform.android`, so the real impl reports `canSync == true` and then talks to a
method channel that isn't there.

They must also pump the section **inside a scrollable**, the way `SettingsFormShell` (a `ListView`)
does on the real screen. Without one the card overflows a short viewport *vertically*, and that
masks the horizontal overflow the 360 px and 1.4×-text-scale cases exist to catch.
