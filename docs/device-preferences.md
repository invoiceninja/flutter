# Device preferences

Companion to CLAUDE.md § Strict rules. The rule there: a device preference is a
`DevicePrefKeys` entry, never a `nav_state` column or a schema change. This doc
covers how to add one, what a sign-out does with it, how the store and its
controllers fit together, and how v12 moved the old columns across.

## A device preference is a DevicePrefKeys entry, never a nav_state column

A device preference is anything this install remembers for itself: the theme,
the language, text size, keyboard shortcuts, the sidebar counters, the main
menu, the Tasks layout, and so on. It lives in one `device_prefs` row, named by
its `PrefKey` in `lib/data/prefs/device_pref_keys.dart`. Adding one needs no
schema change and no migration:

1. **A key.** Append a `PrefKey<T>` to `DevicePrefKeys` and to
   `DevicePrefKeys.all`, giving it a `PrefCodec` (`string`, `boolean` or
   `decimal`; a structured value is a JSON string) and a `PrefScope` (see the
   next section). Add its name and scope to the `shipped` map in
   `test/data/prefs/device_pref_keys_test.dart`.
2. **An owner.** Each key has exactly one owning controller.
   - A plain scalar with a fixed default extends `DevicePref<T>` (the pattern
     `ConfirmActionsController` uses).
   - Anything else follows the store itself: read the key in the constructor,
     `prefs.addListener(_sync)` to re-read it, write with `prefs.write(key, v)`,
     and remove the listener in `dispose` (the patterns `TasksViewController`
     and `PhoneActionsController` use).
   - A default that depends on the device is the owner's business: keep "never
     set" as no row, and compute the default when reading. Tap-to-call follows
     `Env.isTouchPrimary`; "Hide empty panels" follows `Breakpoints.isPhone`.
3. **Wiring.** Build the owner in `Services.build` on the shared
   `devicePrefs`. Nothing is added to `main` — its single
   `devicePrefs.load()` serves every key.
4. **A probe** in `test/app/device_prefs_wipe_test.dart`. It moves the value
   off its default and reads it back in memory. That test fails for a key that
   has no probe, and it proves the key's sign-out behaviour.

Through schema v11 every preference was a `nav_state` column. That cost a lot:

- All ten schema bumps after release existed only to add one. Each ran
  `onUpgrade` on every installed database, and `onUpgrade` is the path whose
  failure resets the store — § A failed open destroys the store only when a
  fresh store fixes it. A defect on that path wiped the store for every
  returning web-demo visitor, pending edits included (`docs/migrations.md`
  § `user_version = 1` is not one schema).
- Each column added a 17-file skeleton and about 19,000 generated lines
  (9d1c3f78 was 49 files and +22,073). A missed wiring surfaced days later:
  v10's reset hook landed six days after its column (40516c42).
- The four oldest controllers wrote with read-modify-write. They read the
  whole row and wrote it all back, so a change to another field (the route,
  the filters) made in between was reverted.

`test/lint/nav_state_columns_frozen_test.dart` freezes `nav_state`'s column
list so none of this can come back.

## Device or account: what a sign-out keeps

A key's `PrefScope` decides what wiping local data does with it. Local data is
wiped by a deliberate sign-out, and by another identity signing in on this
device.

- **`device`** is kept: how the app looks and responds on this device. That
  covers theme mode, both palette variants and the custom colours, language,
  text size, keyboard shortcuts, sidebar collapsed, status tabs and phone
  actions.
- **`account`** is forgotten, because it describes the signed-in account and
  the next person to sign in must not inherit it. That covers sidebar counters
  (the account's modules), the main menu, the Tasks layout, "Hide unverified
  users" (the account's roster), "Hide empty panels" (its dashboard), contacts
  sync (its address-book groups, one per company) and "Confirm actions", which
  goes back to on.

`AppDatabase.wipe` deletes every `device_prefs` row outside
`DevicePrefKeys.keptOnWipe`. That set is the device keys plus the carry
marker. Anything else goes, including a key this build does not know, since
its scope is unknown. `LocalDataDisposer.wipeAll` then calls
`DevicePrefsStore.forgetWiped`, which does the same to the in-memory mirror
and notifies. Every owner follows the store back to its default. No hook is
involved.

Before v12 this took a `resetInMemory()` per controller, called from
`AuthRepository.onBeforeDataWipe`. Only four controllers had one. The sidebar
counters, "Confirm actions" and contacts sync's toggle all outlived a sign-out
in memory, so the next user inherited them until the app was relaunched. The
counters' next change saved the inherited choices as that user's own, and an
inherited contacts-sync toggle ran the next Sync pass into the device address
book for an account that never switched it on. And because the wipe deleted
the whole `nav_state` row, the theme and language went back to their defaults
on the next launch. An involuntary end — a 401 or an idle timeout,
`LocalDataPolicy.keep` — wipes nothing, so every preference stays.

A key's scope is pinned in `device_pref_keys_test.dart`, because changing it
changes what a sign-out does.

## The store is the one writer, and the controllers follow it

`DevicePrefsStore` (`lib/data/prefs/device_prefs_store.dart`) mirrors the table
in memory, so every read is synchronous. The rules:

- **Load once, at boot.** `main` awaits `devicePrefs.load()` inside the
  bounded boot `Future.wait`. If the load fails, every preference stays on its
  default for that launch and the rows are left for the next one.
- **A write goes to memory first, then to its own row.** No write can disturb
  another preference. A failed write is logged and keeps the new value in
  memory, as every controller did before.
- **Listeners hear only about changes an owner did not make.** That means the
  load and `forgetWiped`, never a `write`. Each key has one owner, which
  already holds what it wrote. An owner that writes several keys in a row (the
  theme) must not be re-synced from a half-written set.
- **Nothing else touches the rows.** `test/lint/device_prefs_wiring_test.dart`
  fails on any use of `devicePrefsDao` outside the store in `lib/`, and on a
  `main` that no longer loads the store.

## v12 carried the nav_state columns across once

The v11 → v12 step creates `device_prefs` and runs `carryNavStatePrefs`
(`lib/data/db/nav_state_prefs_carry.dart`). The carry copies each of the
seventeen preference columns into the row of the same name:
`INSERT OR IGNORE … SELECT`. SQLite converts on the way in: the `value` column
is TEXT, so a BOOLEAN arrives as `'1'` / `'0'` and `text_scale` as `'1.2'`.
Those are the forms the codecs read.

- **Once per store.** A marker row (`kPrefsCarriedFromNavState`) records that
  the carry ran. The step can run again: after the app is killed between
  drift's commit and its `user_version` write, or after a build rolled back
  past v12 is replaced by a newer one. Without the marker, a re-run would bring
  back a stale column value over a preference the user has since reset (no row
  to ignore).
- **After a repair, and after a salvage.** `repairSchema` restores shape, not
  data: after a failed upgrade it creates `device_prefs` empty. So the repair
  branch of `onUpgrade` runs the carry too. `importSalvaged` also runs it, for
  a quarantined store older than v12, whose preferences come across in
  `nav_state`. A v12 store's marker comes across with its rows, so its carry is
  a no-op. Both calls are best-effort, since preferences are not worth failing
  an open or an outbox import over.
- **The old columns stay declared.** A build rolled back past v12 still opens
  the store (drift runs no downgrade step, and `isSchemaIntact` only checks
  that the declared columns exist). It sees the preferences as they were at
  the upgrade. `test/data/db/schema_additive_test.dart` pins the general rule:
  every schema version keeps every table and column of the one before.

Pinned by `test/data/db/migration_test.dart`: every column round-trips from a
seeded v11 store, and a re-run never overwrites a changed or reset
preference. `test/data/db/salvage_test.dart` covers the pre-v12 and v12
salvage cases.
