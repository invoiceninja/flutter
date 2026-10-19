import 'package:admin/data/models/value/country.dart';

/// Platform-neutral snapshot of a contact the user picked from the device
/// address book. Keeps `flutter_contacts` types out of the UI/VM — the native
/// impl ([NativeDeviceContactsService]) maps the plugin's `Contact` onto this;
/// the web stub never produces one. Every field defaults to `''` so callers
/// (and tests) can build a partial import.
class DeviceContactImport {
  const DeviceContactImport({
    this.firstName = '',
    this.lastName = '',
    this.displayName = '',
    this.organization = '',
    this.email = '',
    this.phone = '',
    this.address1 = '',
    this.city = '',
    this.state = '',
    this.postalCode = '',
    this.countryIso = '',
    this.countryName = '',
    this.website = '',
  });

  final String firstName;
  final String lastName;

  /// The OS-computed display name (used only as a labelling fallback).
  final String displayName;

  /// Company / organization name → the client's `name` when it has no own name.
  final String organization;

  final String email;
  final String phone;
  final String address1;
  final String city;
  final String state;
  final String postalCode;

  /// ISO 3166-1 alpha-2 country code (locale-independent; iOS populates this).
  final String countryIso;

  /// Localized country name (device-locale; best-effort match only).
  final String countryName;

  final String website;

  /// Best-effort human label for toasts: the person's full name, else the
  /// OS display name, else the organization, else the email.
  String get displayLabel {
    final full = '$firstName $lastName'.trim();
    if (full.isNotEmpty) return full;
    if (displayName.trim().isNotEmpty) return displayName.trim();
    if (organization.trim().isNotEmpty) return organization.trim();
    return email.trim();
  }
}

/// One outbound address-book card — the mirror of [DeviceContactImport] for the
/// push direction (Settings → Device Settings → Contacts). Platform-neutral by
/// design: `flutter_contacts` types stay inside
/// [NativeDeviceContactsService] so the mapper and the reconcile engine are
/// pure Dart and unit-testable without a device.
class DeviceContactCard {
  const DeviceContactCard({
    required this.sourceId,
    this.firstName = '',
    this.lastName = '',
    this.organization = '',
    this.email = '',
    this.website = '',
    this.phones = const <DeviceContactPhone>[],
    this.address1 = '',
    this.city = '',
    this.state = '',
    this.postalCode = '',
    this.countryName = '',
  });

  /// Stable Invoice Ninja identity for this card: the client contact's id, or
  /// `client:<clientId>` for the fallback card emitted when a client has no
  /// usable contact of its own. Used as the link-table key — never written to
  /// the device (there is no field that survives on both platforms without an
  /// entitlement).
  final String sourceId;

  final String firstName;
  final String lastName;

  /// The client's name — shown as the company line on the OS contact card, and
  /// what makes an incoming call read as "Jane Smith · Acme Corp".
  final String organization;

  final String email;
  final String website;
  final List<DeviceContactPhone> phones;
  final String address1;
  final String city;
  final String state;
  final String postalCode;

  /// Localized country name resolved from the client's `country_id`. Blank when
  /// the id is unset or unknown — the address simply omits the line.
  final String countryName;

  /// A card with no phone and no email can't do the one job this feature
  /// exists for, and would just be noise in the user's address book.
  bool get isUseful =>
      phones.any((p) => p.number.trim().isNotEmpty) || email.trim().isNotEmpty;

  /// Best-effort human label for toasts and the pre-flight dialog.
  String get displayLabel {
    final full = '$firstName $lastName'.trim();
    if (full.isNotEmpty) return full;
    return organization.trim();
  }
}

/// A phone number on an outbound card. [isWork] picks the OS label: the
/// client-level number rides along as `work`, a contact's own as `mobile`.
class DeviceContactPhone {
  const DeviceContactPhone(this.number, {this.isWork = false});

  final String number;
  final bool isWork;
}

/// Platform-neutral view of the OS contacts permission.
///
/// Mirrors `flutter_contacts`' `PermissionStatus` minus the states we don't act
/// on differently. [limited] is iOS 18's "selected contacts" grant: reads are
/// partial and a reconcile can't see what it doesn't own, so it is deliberately
/// **not** treated as sufficient — see [DeviceContactsService.checkPermission].
enum DeviceContactsPermission {
  granted,
  limited,
  denied,

  /// Android "Don't ask again" / iOS second denial / parental restriction —
  /// requesting again does nothing, the user must go to system settings.
  permanentlyDenied,

  /// The platform has no address book to talk to at all (web, desktop).
  unavailable,
}

/// Reads a single contact from the device address book via the OS-native
/// picker. Native-only (iOS today); the web stub and non-iOS native platforms
/// report [isAvailable] == false so the import button hides itself.
///
/// Mirrors [BiometricService]'s seam: an abstract interface, a native impl, and
/// an unsupported stub, selected per platform in `Services.build` via
/// `defaultDeviceContactsService()` (`device_contacts_service_factory.dart`).
abstract class DeviceContactsService {
  /// True only where the OS-native contact picker exists (iOS). Synchronous so
  /// the import button can show/hide at build time without a `FutureBuilder`.
  bool get isAvailable;

  /// Launches the OS contact picker and returns the chosen contact, or `null`
  /// if the user cancelled (or the platform is unsupported). Throws on a
  /// genuine platform failure so the caller can tell failure from cancel.
  Future<DeviceContactImport?> pickContact();

  // ---------------------------------------------------------------------------
  // Push direction — writing Invoice Ninja records into the address book.
  // Driven by `ContactsSyncService`; see `docs/contacts-sync.md`.
  // ---------------------------------------------------------------------------

  /// True where the app can *write* the address book — native iOS/Android only.
  /// Synchronous so the settings section can hide itself at build time.
  ///
  /// Distinct from [isAvailable] (the read-only picker): writing needs a real
  /// runtime permission, which the picker deliberately avoids.
  bool get canSync;

  /// The current permission, without prompting.
  Future<DeviceContactsPermission> checkPermission();

  /// Prompt for read+write access. Returns the resulting state; already-granted
  /// returns [DeviceContactsPermission.granted] without showing a dialog.
  Future<DeviceContactsPermission> requestPermission();

  /// Open the OS app-settings page. The only way forward from
  /// [DeviceContactsPermission.permanentlyDenied], and how an iOS user upgrades
  /// a [DeviceContactsPermission.limited] grant to full access.
  Future<void> openSystemSettings();

  /// Find-or-create the label/group for a company and return its id.
  ///
  /// [knownId] is the id this install last resolved for that company, and is
  /// tried **first**. It is what makes ownership id-keyed rather than
  /// name-keyed: [name] is derived from the company name, so resolving by name
  /// alone hands two same-named companies the same group — see
  /// `ContactsSyncGroupStore` for why that destroys contacts. A [knownId] that
  /// no longer exists (the user deleted the label) falls back to [name].
  ///
  /// Finding the group by [knownId] under a different name means the company
  /// was renamed, so the label is renamed to match rather than orphaned.
  ///
  /// **`null` is a supported outcome, not an error**: on Android a group must
  /// belong to an account, and a device whose contacts are local-only has none
  /// to put it in. Callers fall back to syncing without a label — see
  /// `ContactsSyncService`.
  Future<String?> ensureGroup(String name, {String? knownId});

  /// Create a new label named [name] **unconditionally** — even when one by
  /// that name already exists.
  ///
  /// Two companies can legitimately share a name (and every unnamed one shares
  /// the same fallback label), and they must not share a group. Groups are
  /// identified by id, not name, so the honest resolution is a second label
  /// with the same name rather than one carrying a disambiguating suffix the
  /// user would have to decode.
  Future<String?> createGroup(String name);

  /// Find the label for a company, or `null` if it doesn't exist. Unlike
  /// [ensureGroup] this never creates one — use it on teardown paths, where
  /// creating a label seconds before deleting it would briefly add one to a
  /// device that had none. [knownId] is tried first, as in [ensureGroup].
  Future<String?> findGroup(String name, {String? knownId});

  /// The device contact ids currently in [groupId].
  ///
  /// A **liveness hint only, never an ownership record.** Nothing is ever
  /// deleted because it is (or is not) in this list: flutter_contacts before
  /// 2.3.0 answered an *empty* group with every contact on the phone, and the
  /// reconcile that trusted it deleted the user's whole address book on its
  /// first pass. Ownership is the link table plus [ownsDeviceContact] — see
  /// `docs/contacts-sync.md`.
  Future<List<String>> groupMemberIds(String groupId);

  /// Where each of [refs] lives on the device now, keyed by the
  /// [DeviceContactRef.contactId] it was stored under. A ref missing from the
  /// result is gone from the device.
  ///
  /// Android merges contacts on its own (same name, phone or email), so a card
  /// can move: our entry joins the user's existing contact and the id we stored
  /// stops existing. A ref with a [DeviceContactRef.rawContactId] is then found
  /// again by that entry id, and its state names the contact it moved into —
  /// re-creating it instead would add another entry to the user's contact on
  /// every pass.
  ///
  /// Returns **null** when the device couldn't be read. The caller must then
  /// treat every ref as still present (re-creating them all doubles the
  /// address book) *and* as not provably ours (so nothing is updated or
  /// deleted this pass).
  Future<Map<String, DeviceContactState>?> resolveContacts(
    Iterable<DeviceContactRef> refs,
  );

  /// Put already-created contacts into [groupId]. Used to re-adopt cards that
  /// outlived their label (see [resolveContacts]) so the label shows them
  /// again. Failures are cosmetic — the cards still work.
  Future<void> addContactsToGroup({
    required String groupId,
    required List<String> contactIds,
  });

  /// Create [cards], returning the new contacts' states **in the same order**.
  /// When [groupId] is non-null, each new contact that is its own single entry
  /// is added to it. One Android merged into another contact on insert is
  /// left out: labelling the merged contact labels the user's own entry too.
  ///
  /// The state is read back after the write because Android may already have
  /// merged a new card into one of the user's contacts — its
  /// [DeviceContactState.entryIds] then lists more than ours, and
  /// [entryIdToRecord] says so. A failed read-back yields empty `entryIds`
  /// (unknown, settled on a later pass), never a guess.
  Future<List<DeviceContactState>> createContacts(
    List<DeviceContactCard> cards, {
    String? groupId,
  });

  /// Overwrite the fields this feature owns on already-created contacts,
  /// preserving everything else the user or OS put there (photo, favourite,
  /// ringtone). Silently skips ids that no longer exist — a contact the user
  /// deleted by hand is not an error, and the next reconcile re-creates it.
  ///
  /// Returns the ids actually written. A skipped or refused contact is left
  /// out, so the caller keeps its old hash and the next pass tries again.
  ///
  /// **Callers pass only contacts [ownsDeviceContact] cleared.** On Android an
  /// update addresses the whole merged contact, so on one the user also owns
  /// it overwrites *their* phones and emails.
  Future<Set<String>> updateContacts(List<DeviceContactUpdate> items);

  /// Delete by device contact id. Ids that no longer exist are ignored.
  ///
  /// **Callers pass only contacts [ownsDeviceContact] cleared.** On Android this
  /// deletes every entry merged into the contact (flutter_contacts deletes
  /// `RawContacts WHERE CONTACT_ID IN …`), so a card merged into one of the
  /// user's contacts takes the user's own copy with it.
  Future<void> deleteContacts(List<String> deviceIds);

  /// Delete the label itself. Does **not** delete its members — callers remove
  /// the contacts first.
  Future<void> deleteGroup(String groupId);
}

/// A device contact one link row points at.
class DeviceContactRef {
  const DeviceContactRef({required this.contactId, this.rawContactId});

  /// The contact id the link row stored.
  final String contactId;

  /// The entry id recorded for the card — see `DeviceContactLinks.rawContactId`
  /// for what null and [kUnidentifiedEntry] mean.
  final String? rawContactId;
}

/// What the device holds for one contact right now.
class DeviceContactState {
  const DeviceContactState({required this.contactId, required this.entryIds});

  /// Where the card lives now — the stored id, or the contact Android merged
  /// it into.
  final String contactId;

  /// Every entry that makes up [contactId]. Android: the ids of its raw
  /// contacts, one per account or app that contributed to it (Google,
  /// WhatsApp, this feature…). iOS has no such level, so a contact is its own
  /// single entry: `[contactId]`. Empty means it couldn't be read.
  final List<String> entryIds;
}

/// The recorded entry id for a card that was already merged into another
/// contact when it was created: the contact has several entries and nothing
/// says which one is ours. Never null — null means "not checked yet".
const String kUnidentifiedEntry = '';

/// The entry id to record for a contact whose entries are [entryIds]: its
/// only entry, [kUnidentifiedEntry] when there are several, or null when they
/// couldn't be read (left for a later pass to settle).
String? entryIdToRecord(List<String> entryIds) => switch (entryIds.length) {
  0 => null,
  1 => entryIds.single,
  _ => kUnidentifiedEntry,
};

/// Whether a contact may be updated or deleted by contacts sync: true only
/// when it consists of **exactly one entry, and that entry is ours**.
///
/// [recorded] is the link row's entry id. A null one predates the column
/// (schema v15) and is adopted on a single entry — the one case the old rows
/// leave to judgement, documented in `docs/contacts-sync.md`. Anything else —
/// merged with the user's own contact, split since, unidentified, unreadable —
/// is left alone: a stray card is recoverable, the user's contact is not.
bool ownsDeviceContact({
  required String? recorded,
  required List<String> entryIds,
}) {
  if (entryIds.length != 1) return false;
  if (recorded == null) return true;
  return recorded.isNotEmpty && entryIds.single == recorded;
}

/// One entry of an [DeviceContactsService.updateContacts] batch.
class DeviceContactUpdate {
  const DeviceContactUpdate({required this.deviceId, required this.card});

  final String deviceId;
  final DeviceContactCard card;
}

/// Resolves an Invoice Ninja country id (the server integer-as-string, e.g.
/// `"840"` for the US) from a device contact's ISO code or country name.
/// Returns `''` when nothing matches — the caller's blanks-only merge makes a
/// miss harmless.
///
/// Priority: ISO 3166-1 alpha-2 against [Country.iso2] (locale-independent),
/// then the country name against [Country.name] (best-effort — the device
/// returns names in its own locale, so this branch mostly hits for English).
String resolveCountryId(
  Iterable<Country> countries, {
  required String iso2,
  required String name,
}) {
  final iso = iso2.trim().toLowerCase();
  if (iso.isNotEmpty) {
    for (final c in countries) {
      if (c.iso2.trim().toLowerCase() == iso) return c.id;
    }
  }
  final n = name.trim().toLowerCase();
  if (n.isNotEmpty) {
    for (final c in countries) {
      if (c.name.trim().toLowerCase() == n) return c.id;
    }
  }
  return '';
}
