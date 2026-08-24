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

  /// Find-or-create the label/group named [name] and return its id.
  ///
  /// **`null` is a supported outcome, not an error**: on Android a group must
  /// belong to an account, and a device whose contacts are local-only has none
  /// to put it in. Callers fall back to syncing without a label — see
  /// `ContactsSyncService`.
  Future<String?> ensureGroup(String name);

  /// Find the label named [name], or `null` if it doesn't exist. Unlike
  /// [ensureGroup] this never creates one — use it on teardown paths, where
  /// creating a label seconds before deleting it would briefly add one to a
  /// device that had none.
  Future<String?> findGroup(String name);

  /// The device contact ids currently in [groupId]. The reconcile's ownership
  /// boundary: everything here was written by this feature, and nothing outside
  /// it is ever touched.
  Future<List<String>> groupMemberIds(String groupId);

  /// Create [cards], returning the new device contact ids **in the same order**.
  /// When [groupId] is non-null the new contacts are added to it.
  Future<List<String>> createContacts(
    List<DeviceContactCard> cards, {
    String? groupId,
  });

  /// Overwrite the fields this feature owns on already-created contacts,
  /// preserving everything else the user or OS put there (photo, favourite,
  /// ringtone). Silently skips ids that no longer exist — a contact the user
  /// deleted by hand is not an error, and the next reconcile re-creates it.
  Future<void> updateContacts(List<DeviceContactUpdate> items);

  /// Delete by device contact id. Ids that no longer exist are ignored.
  Future<void> deleteContacts(List<String> deviceIds);

  /// Delete the label itself. Does **not** delete its members — callers remove
  /// the contacts first.
  Future<void> deleteGroup(String groupId);
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
