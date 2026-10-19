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
5. Read the label's members — a **liveness hint, nothing more** — and diff the desired cards against
   the link table → create / update / **unchanged** / delete.
6. Ask the device (`DeviceContactsService.resolveContacts`, one call) about every link the pass is
   about to update or delete, and every link whose card isn't in the label. It answers where each
   card lives now and which entries make up that contact. An update or delete goes ahead only when
   `ownsDeviceContact` clears it (below); a card that is gone is re-created; a card that moved is
   re-pointed.
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

### Contacts sync touches only a device contact it can prove it wrote

A device contact is updated or deleted only through a link row, and only when
`ownsDeviceContact(recorded:, entryIds:)` (`lib/data/services/device_contacts_service.dart`) says the
contact consists of **exactly one entry, and that entry is the one this install recorded** when it
created the card (`device_contact_links.raw_contact_id`, schema v15). Label membership never
decides anything destructive. Both rules come from a beta user whose address book the feature
wiped (v5.1.8 – v5.1.16, Android).

#### The label is not an ownership record

The reconcile used to treat the label as the ownership boundary: it deleted every member it had no
link row for, so it could reclaim cards after `logout()` wiped the link table. But flutter_contacts
before **2.3.0** answers an *empty* group filter with **every contact on the phone**:
`ContactFilterUtils.getContactIdsFromGroups` returns `[]`, and
`ContactQueryBuilder.buildContactIdSelection` treats an empty list as "no filter"
(`!contactIds.isNullOrEmpty()`). Verified in the 2.2.0 sources the app shipped with; 2.3.0 fixed
it (#240) and 2.6.0's `ContactFetcher` returns nothing for a non-null empty list. On a first sync
`ensureGroup` mints an empty label, so the heal pass deleted the user's whole address book — and on
most phones those contacts live in a Google account, so the delete synced to the cloud. "Remove
synced contacts" and the logout cleanup did the same through `removeAll`.

So membership is now only a liveness hint. A linked card that is a member is taken as present
without asking again (a repeat sync stays one read); one that isn't is checked against the address
book. The cost is honest: after `logout()` wipes the link table, or a pass dies between the OS write
and the Drift write, a card can be left behind and re-created beside its old copy. A duplicate is
recoverable; a wiped address book is not.

#### A merged contact is never ours

Android merges contacts on its own: a card for someone already in the phone (same name, phone or
email — the common case for a client contact) joins the user's existing contact, on insert or later
when either side changes. flutter_contacts works at the merged level: `createAll` returns the
merged contact's id, `deleteAll` runs `DELETE FROM raw_contacts WHERE contact_id IN (…)` — every
entry, the user's own included — and `updateAll` writes through whichever entry
`getPrimaryRawContactIdForUpdate` picks. Still true in 2.6.0, and the plugin has no per-entry
delete. So:

- **On create** the new contacts are read back with `ContactProperty.identifiers`.
  `entryIdToRecord` records the single entry's id, `kUnidentifiedEntry` (`''`) when Android had
  already merged the card (nothing says which entry is ours, so it is never touched), or null when
  the read failed (settled later).
- **Only a card that is its own contact goes into the label.** `groups.addContacts` writes a
  membership for every entry of the contact in the label's account
  (`GroupUtils.addContactsToGroup`), so labelling a card merged on insert files the user's own entry
  under "Invoice Ninja — …". A merged card stays unlabelled, and so is checked by id on every pass
  (one by-id read, since it is never a member).
- **Before an update or delete** the contact must be exactly `[recorded]`. A merged one is left as
  it is and counted in `ContactsSyncSummary.skippedMerged`, which the settings card reports; its
  link row stays, so a later pass can still act if the contacts are split apart.
- **A card merged after the fact** loses the id we stored. `resolveContacts` finds it again by its
  recorded entry and the link is re-pointed — re-creating it would add another entry to the user's
  contact on every pass.
- **iOS** has no entry level, so a contact is its own single entry (`entryIds: [id]`) and the rule
  reduces to "it still exists". *Unverified:* iOS links contacts across accounts (iCloud + Gmail),
  and whether deleting a unified contact deletes its linked ones was not confirmed — check on a
  device with two accounts.
- **Rows from before v15** have a null entry and are adopted the first time the pass acts on them:
  a single entry is taken as ours, a merged contact becomes `kUnidentifiedEntry`. The one case left
  to judgement is a pre-v15 row whose merged contact the user has since split, leaving the user's
  half alone under our stored id.

#### …but an empty group is still ambiguous, so it never re-creates on its own

A linked card missing from the label means one of two opposite things: the user deleted the
**card**, or deleted the **label** (or the device only just gained its first contacts account, so
`ensureGroup` minted an empty replacement) while every card is still there. Reading the second as
the first re-creates the entire set beside the originals, so the pass asks the address book
(`resolveContacts`) and re-creates only what is really gone. Cards that outlived their label are
put back in it with `addContactsToGroup` — but only ones that are only ours: on a merged contact
Android files the membership under whichever entry shares the label's account, which may be the
user's. If the device can't be read at all (`resolveContacts` returns null), every card counts as
present and none as ours: nothing is created, updated or deleted for those links that pass.

### …and the label is found by id, never by name

When the reconcile still deleted every group member it didn't recognise, *which* group a company
resolved to was a data-safety question, not a lookup detail; it is still what keeps each company's
cards under its own label. `labelFor(companyName)` is a **display name only**:
two companies can share a name, and every unnamed one falls back to a bare `Invoice Ninja`. Resolving
by name therefore handed them one group, and each pass deleted the other company's cards off the
phone — silently, in both directions, and the same flaw let "Remove synced contacts" for one company
wipe the other's.

So `ContactsSyncService._resolveGroupId` keys on the **company id**:

- `ContactsSyncGroupStore` (implemented by `ContactsSyncController`, persisted in the device-local
  `DevicePrefKeys.contactsSync` blob alongside `enabled` / `scope` / `lastRun`) remembers
  `companyId -> groupId`.
- `ensureGroup(label, knownId:)` tries that id first. Finding it under a *different* name means the
  company was renamed, so the label is renamed to match rather than orphaned.
- The name lookup survives only as the upgrade path for installs predating the stored id, and is
  **refused** when another company already claims what it finds — otherwise the second company to
  sync would adopt the first one's group and the collision would outlive the fix.
- Refused, or genuinely absent, the pass calls `createGroup(label)`, which creates a second label
  *with the same name*. Groups are identified by id, so two same-named companies honestly get two
  same-named labels — better than one of them carrying a suffix built from a raw company id.

The blob is free-form JSON and the controller's parse tolerates missing keys, so this needed no schema bump.

## Traps

Each of these is a real constraint verified in the `flutter_contacts` sources (2.2.0, re-checked
against 2.6.0, the version now locked), and each fails in a way that doesn't look like the cause.

- **An empty group filter matched every contact before 2.3.0.** Never let a group read decide a
  delete; and if the plugin is ever pinned back below 2.3.0, `groupMemberIds` must guard an empty
  group itself. `test/domain/contacts_sync/contacts_sync_service_test.dart` › "never touches a
  contact it cannot prove it wrote" runs the fake with `emptyGroupReturnsEverything`.
- **Delete and update address the whole merged contact.** `deleteAll` / `delete` / `updateAll` take
  a contact id, and on Android that is every raw contact merged under it. Nothing reaches them
  except through `ownsDeviceContact`.
- **2.5.0+ `update` throws `read_only_contact`,** and one such contact fails a whole `updateAll`.
  `updateContacts` retries the batch one contact at a time so it can't fail the pass, and returns
  the ids it actually wrote: only those get the new hash, so a refused card is retried next pass.
- **`device_contact_links` is `durable` in `kTableRetention`.** It is the only record of which cards
  are ours. As `cache`, a schema repair could drop it and a reset leave it behind, and every synced
  card would then be re-created beside one the app can never remove. Salvage imports the columns
  both schemas share, so a pre-v15 snapshot lands with `raw_contact_id` null (not checked yet).
- **One account, used for both the label and the contacts.** `GroupUtils.addContactsToGroup` throws
  `IllegalStateException` if the group has a null account, and throws again if the contact has no raw
  contact *in that same account*. `NativeDeviceContactsService` resolves one `Account` once
  (`accounts.getDefault()`, else the first listed) and passes it to both `groups.create` and
  `create`. Getting this wrong doesn't degrade — it throws on the first grouped write.
- **No account ⇒ no label, not a failure.** A device whose contacts are local-only has no account to
  hang a group on. `ensureGroup` returns `null`, the sync runs *without* a label, `summary.labelled`
  is false, and every linked card is taken as present (there is no membership to check).
- **`update` only writes properties you fetched.** The package enforces this. The `get()` before an
  `update()` requests exactly `_ownedProperties`; fetch a narrower set and those writes are silently
  dropped — a sync that runs clean and changes nothing.
- **iOS 18's `limited` grant is not enough.** We could neither enumerate our own label nor trust a
  diff built from a partial view, and that diff implies deletes. It's reported distinctly so the UI
  can explain rather than no-op.
- **`logout()` wipes the link table.** `AuthRepository.onBeforeDataWipe` (destructive path only — not
  the `LocalDataPolicy.keep` idle-timeout re-lock) runs `removeAllCompanies` first. Without it a
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
  see the section above. A change that makes anything resolve a group by name alone puts two
  companies' cards under one label; `test/domain/contacts_sync/contacts_sync_service_test.dart`'s
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
| Reconcile, ownership, merged contacts, scope, removal | `test/domain/contacts_sync/contacts_sync_service_test.dart` |
| `ownsDeviceContact` / `entryIdToRecord` | `test/data/services/device_contacts_service_test.dart` |
| The v15 `raw_contact_id` upgrade | `test/data/db/migration_test.dart` |
| Preference persistence + single-flight | `test/app/contacts_sync_controller_test.dart` |
| Paged Drift read | `test/data/db/dao/client_dao_contact_sync_test.dart` |
| Settings card + permission states | `test/ui/features/settings/widgets/contacts_sync_section_test.dart` |

Widget tests **must** inject a fake via `buildFixture(deviceContactsService:)` — `flutter test`
reports `TargetPlatform.android`, so the real impl reports `canSync == true` and then talks to a
method channel that isn't there.

They must also pump the section **inside a scrollable**, the way `SettingsFormShell` (a `ListView`)
does on the real screen. Without one the card overflows a short viewport *vertically*, and that
masks the horizontal overflow the 360 px and 1.4×-text-scale cases exist to catch.
