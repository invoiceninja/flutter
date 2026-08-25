import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:logging/logging.dart';

import 'package:admin/app/env.dart';
import 'package:admin/data/services/device_contacts_service.dart';

final _log = Logger('DeviceContactsService');

/// The real device address book, over `flutter_contacts` — both directions:
/// the OS picker for a single inbound contact ([pickContact]), and the write
/// surface the contacts-sync reconcile drives.
///
/// iOS + Android only ([Env.isMobile]). macOS compiles this file (the package
/// ships a macOS plugin) but has no native picker, and its sandbox would need a
/// `com.apple.security.personal-information.addressbook` entitlement to touch
/// contacts at all — so it reports both capabilities false and every affordance
/// hides itself.
///
/// House rule, inherited from `BiometricService`: **no method throws for a
/// platform or permission problem.** A denial, a missing account, or a contact
/// the user deleted by hand all resolve to a value, so the reconcile can carry
/// on and report rather than abort mid-way through the address book.
class NativeDeviceContactsService implements DeviceContactsService {
  NativeDeviceContactsService();

  /// The account new contacts and the label both go into, resolved once per
  /// process. `false` for [_accountResolved] means "not looked up yet";
  /// a resolved `null` means "this device has no contacts account", which is a
  /// supported state (see [ensureGroup]) and must not trigger a re-probe.
  Account? _account;
  bool _accountResolved = false;

  @override
  // iOS and Android both ship an OS picker. macOS compiles this file (the
  // package has a macOS plugin) but has no picker — `showPicker` throws there —
  // and `Env.isMobile` excludes it, so the button hides itself.
  bool get isAvailable => Env.isMobile;

  @override
  Future<DeviceContactImport?> pickContact() async {
    if (!isAvailable) return null;
    final Contact? picked;
    try {
      // Request the fields we map. Without `properties` the picker returns only
      // id + displayName; passing them keeps the picker permission-free on iOS
      // (no address-book permission prompt — the user hands over one contact).
      // iOS's picker is permissionless (the user hands over exactly one
      // contact), but Android's throws without READ_CONTACTS at targetSdk 36.
      // Asking on iOS too would trade that property away for nothing, so the
      // request is Android-only.
      if (defaultTargetPlatform == TargetPlatform.android &&
          !await FlutterContacts.permissions.has(PermissionType.read)) {
        final status = await FlutterContacts.permissions.request(
          PermissionType.read,
        );
        if (status != PermissionStatus.granted &&
            status != PermissionStatus.limited) {
          return null; // treated as a cancel — no error toast.
        }
      }
      picked = await FlutterContacts.native.showPicker(
        properties: const {
          ContactProperty.name,
          ContactProperty.phone,
          ContactProperty.email,
          ContactProperty.address,
          ContactProperty.organization,
          ContactProperty.website,
        },
      );
    } on PlatformException catch (e, st) {
      _log.warning('device contact pick failed', e, st);
      rethrow; // genuine failure → caller shows an error toast (≠ cancel).
    }
    if (picked == null) return null; // user cancelled.
    return _map(picked);
  }

  DeviceContactImport _map(Contact c) {
    final address = c.addresses.isNotEmpty ? c.addresses.first : null;
    return DeviceContactImport(
      firstName: c.name?.first ?? '',
      lastName: c.name?.last ?? '',
      displayName: c.displayName ?? '',
      organization: c.organizations.isNotEmpty
          ? (c.organizations.first.name ?? '')
          : '',
      email: c.emails.isNotEmpty ? c.emails.first.address : '',
      phone: _preferredPhone(c),
      address1: address?.street ?? '',
      city: address?.city ?? '',
      state: address?.state ?? '',
      postalCode: address?.postalCode ?? '',
      countryIso: address?.isoCountryCode ?? '',
      countryName: address?.country ?? '',
      website: c.websites.isNotEmpty ? c.websites.first.url : '',
    );
  }

  /// Prefer a mobile / iPhone number; fall back to the first listed.
  String _preferredPhone(Contact c) {
    if (c.phones.isEmpty) return '';
    for (final p in c.phones) {
      final label = p.label.label;
      if (label == PhoneLabel.mobile || label == PhoneLabel.iPhone) {
        return p.number;
      }
    }
    return c.phones.first.number;
  }

  // ---------------------------------------------------------------------------
  // Push direction
  // ---------------------------------------------------------------------------

  /// Exactly the properties this feature owns and overwrites. The package only
  /// lets you update properties you *fetched* ("Data Integrity"), so a
  /// get-before-update must request this same set — fetch fewer and those
  /// writes are silently dropped, which looks like a sync that runs clean and
  /// changes nothing.
  static const _ownedProperties = <ContactProperty>{
    ContactProperty.name,
    ContactProperty.phone,
    ContactProperty.email,
    ContactProperty.address,
    ContactProperty.organization,
    ContactProperty.website,
  };

  @override
  bool get canSync => Env.isMobile;

  @override
  Future<DeviceContactsPermission> checkPermission() async {
    if (!canSync) return DeviceContactsPermission.unavailable;
    try {
      return _mapPermission(
        await FlutterContacts.permissions.check(PermissionType.readWrite),
      );
    } catch (e, st) {
      _log.fine('contacts permission check failed', e, st);
      return DeviceContactsPermission.unavailable;
    }
  }

  @override
  Future<DeviceContactsPermission> requestPermission() async {
    if (!canSync) return DeviceContactsPermission.unavailable;
    try {
      return _mapPermission(
        await FlutterContacts.permissions.request(PermissionType.readWrite),
      );
    } on PlatformException catch (e, st) {
      // "CONCURRENT_REQUEST" when a prompt is already up — report the current
      // state rather than surfacing a plumbing error to the user.
      _log.fine('contacts permission request failed', e, st);
      return checkPermission();
    }
  }

  @override
  Future<void> openSystemSettings() async {
    try {
      await FlutterContacts.permissions.openSettings();
    } catch (e, st) {
      _log.warning('opening app settings failed', e, st);
    }
  }

  @override
  Future<String?> ensureGroup(String name, {String? knownId}) async {
    final account = await _resolveAccount();
    // Android refuses to group contacts that live outside the label's own
    // account (`GroupUtils.addContactsToGroup` throws on a null account, and
    // again if the contact has no raw contact in it). A device with no accounts
    // therefore cannot have a label at all — that's a supported degradation,
    // not a failure, so callers get null and sync without one.
    if (account == null) {
      _log.info('no contacts account on this device — syncing without a label');
      return null;
    }
    try {
      final known = await _groupById(knownId);
      if (known != null) {
        // Found by id under a different name: the company was renamed. Rename
        // the label to match instead of stranding it — the alternative is a
        // group in the user's Contacts app naming a company that no longer
        // exists, with the cards for the renamed one in a second group beside
        // it. A failed rename is cosmetic, so it must not fail the pass.
        if (known.name != name) {
          try {
            await FlutterContacts.groups.update(
              Group(id: known.id, name: name),
            );
          } catch (e, st) {
            _log.warning('could not rename the label to "$name"', e, st);
          }
        }
        return known.id;
      }
      final existing = await _findGroup(name, account);
      if (existing != null) return existing;
      final created = await FlutterContacts.groups.create(
        name,
        account: account,
      );
      return created.id;
    } catch (e, st) {
      _log.warning('could not find or create the "$name" label', e, st);
      return null;
    }
  }

  @override
  Future<String?> createGroup(String name) async {
    final account = await _resolveAccount();
    if (account == null) return null;
    try {
      final created = await FlutterContacts.groups.create(
        name,
        account: account,
      );
      return created.id;
    } catch (e, st) {
      _log.warning('could not create a second "$name" label', e, st);
      return null;
    }
  }

  @override
  Future<String?> findGroup(String name, {String? knownId}) async {
    final account = await _resolveAccount();
    if (account == null) return null;
    try {
      final known = await _groupById(knownId);
      if (known != null) return known.id;
      return await _findGroup(name, account);
    } catch (e, st) {
      _log.warning('could not look up the "$name" label', e, st);
      return null;
    }
  }

  /// The group [id] names, or null when it is null or no longer exists.
  ///
  /// Deliberately swallows its own errors rather than failing the caller: a
  /// stale id is the *expected* state after the user deletes the label by hand,
  /// and the name lookup behind it is a complete fallback.
  Future<Group?> _groupById(String? id) async {
    if (id == null || id.isEmpty) return null;
    try {
      final group = await FlutterContacts.groups.get(id);
      return group?.id == null ? null : group;
    } catch (e, st) {
      _log.info('the remembered label $id could not be read', e, st);
      return null;
    }
  }

  Future<String?> _findGroup(String name, Account account) async {
    final existing = await FlutterContacts.groups.getAll(accounts: [account]);
    for (final group in existing) {
      if (group.name == name && group.id != null) return group.id;
    }
    return null;
  }

  @override
  Future<List<String>> groupMemberIds(String groupId) async {
    try {
      final members = await FlutterContacts.getAll(
        filter: ContactFilter.group(groupId),
      );
      return [
        for (final c in members)
          if (c.id case final id?) id,
      ];
    } catch (e, st) {
      _log.warning('could not read the label members', e, st);
      return const <String>[];
    }
  }

  @override
  Future<Set<String>> existingContactIds(Iterable<String> ids) async {
    final wanted = ids.toSet();
    if (wanted.isEmpty) return const <String>{};
    try {
      // One platform call rather than N `get()`s — with no `properties` this
      // returns id + display name only.
      final all = await FlutterContacts.getAll();
      return <String>{
        for (final c in all)
          if (c.id case final id?)
            if (wanted.contains(id)) id,
      };
    } catch (e, st) {
      // Fail toward "they still exist". The caller only asks once it already
      // suspects the label is untrustworthy, and re-creating every card is by
      // far the worse of the two errors.
      _log.warning('could not enumerate contacts to verify links', e, st);
      return wanted;
    }
  }

  @override
  Future<void> addContactsToGroup({
    required String groupId,
    required List<String> contactIds,
  }) async {
    if (contactIds.isEmpty) return;
    try {
      await FlutterContacts.groups.addContacts(
        groupId: groupId,
        contactIds: contactIds,
      );
    } catch (e, st) {
      // Cosmetic: the cards work for caller ID either way, they're just not
      // in the label yet. The next pass tries again.
      _log.warning('could not re-add contacts to the label', e, st);
    }
  }

  @override
  Future<List<String>> createContacts(
    List<DeviceContactCard> cards, {
    String? groupId,
  }) async {
    if (cards.isEmpty) return const <String>[];
    // Same account as the label, or Android's group insert throws.
    final account = await _resolveAccount();
    final ids = await FlutterContacts.createAll([
      for (final card in cards) _toContact(card),
    ], account: account);
    if (groupId != null && ids.isNotEmpty) {
      try {
        await FlutterContacts.groups.addContacts(
          groupId: groupId,
          contactIds: ids,
        );
      } catch (e, st) {
        // The cards exist and work for caller ID; they're just unlabelled.
        // Losing them over a labelling failure would be the worse outcome.
        _log.warning('could not add new contacts to the label', e, st);
      }
    }
    return ids;
  }

  @override
  Future<void> updateContacts(List<DeviceContactUpdate> items) async {
    if (items.isEmpty) return;
    final updated = <Contact>[];
    for (final item in items) {
      final Contact? current;
      try {
        current = await FlutterContacts.get(
          item.deviceId,
          properties: _ownedProperties,
        );
      } catch (e, st) {
        _log.fine('skipping unreadable contact ${item.deviceId}', e, st);
        continue;
      }
      // Deleted by hand between two syncs. Not an error — the reconcile's next
      // pass sees the missing link and re-creates it.
      if (current == null) continue;
      final next = _toContact(item.card);
      // Replace only what we own; `copyWith` carries the photo, favourite,
      // ringtone and anything else the user or OS attached.
      updated.add(
        current.copyWith(
          name: next.name,
          phones: next.phones,
          emails: next.emails,
          addresses: next.addresses,
          organizations: next.organizations,
          websites: next.websites,
        ),
      );
    }
    if (updated.isEmpty) return;
    await FlutterContacts.updateAll(updated);
  }

  @override
  Future<void> deleteContacts(List<String> deviceIds) async {
    if (deviceIds.isEmpty) return;
    try {
      await FlutterContacts.deleteAll(deviceIds);
    } catch (e, st) {
      // One already-gone id must not strand the rest of the batch, so fall back
      // to per-id deletes and let the misses fail individually.
      _log.fine('batch delete failed, retrying individually', e, st);
      for (final id in deviceIds) {
        try {
          await FlutterContacts.delete(id);
        } catch (e2, st2) {
          _log.fine('could not delete contact $id', e2, st2);
        }
      }
    }
  }

  @override
  Future<void> deleteGroup(String groupId) async {
    try {
      await FlutterContacts.groups.delete(groupId);
    } catch (e, st) {
      _log.warning('could not delete the label', e, st);
    }
  }

  /// The device's default contacts account (iOS: container), falling back to
  /// the first one listed. Cached: it can't change mid-process in a way that
  /// matters, and both `ensureGroup` and every `createContacts` need it.
  Future<Account?> _resolveAccount() async {
    if (_accountResolved) return _account;
    _accountResolved = true;
    try {
      _account = await FlutterContacts.accounts.getDefault();
      if (_account == null) {
        final all = await FlutterContacts.accounts.getAll();
        if (all.isNotEmpty) _account = all.first;
      }
    } catch (e, st) {
      _log.warning('could not resolve a contacts account', e, st);
      _account = null;
    }
    return _account;
  }

  DeviceContactsPermission _mapPermission(PermissionStatus status) =>
      switch (status) {
        PermissionStatus.granted => DeviceContactsPermission.granted,
        // iOS 18 "selected contacts": we can neither enumerate the label nor
        // trust a reconcile, so the caller treats this as not-yet-usable and
        // points the user at system settings.
        PermissionStatus.limited => DeviceContactsPermission.limited,
        PermissionStatus.denied ||
        PermissionStatus.notDetermined => DeviceContactsPermission.denied,
        PermissionStatus.permanentlyDenied || PermissionStatus.restricted =>
          DeviceContactsPermission.permanentlyDenied,
      };

  Contact _toContact(DeviceContactCard card) {
    final hasAddress = [
      card.address1,
      card.city,
      card.state,
      card.postalCode,
      card.countryName,
    ].any((v) => v.trim().isNotEmpty);
    return Contact(
      name: Name(first: card.firstName, last: card.lastName),
      phones: [
        for (final phone in card.phones)
          if (phone.number.trim().isNotEmpty)
            Phone(
              number: phone.number.trim(),
              label: Label(phone.isWork ? PhoneLabel.work : PhoneLabel.mobile),
            ),
      ],
      emails: [
        if (card.email.trim().isNotEmpty)
          Email(
            address: card.email.trim(),
            label: const Label(EmailLabel.work),
          ),
      ],
      addresses: [
        if (hasAddress)
          Address(
            street: _orNull(card.address1),
            city: _orNull(card.city),
            state: _orNull(card.state),
            postalCode: _orNull(card.postalCode),
            country: _orNull(card.countryName),
            label: const Label(AddressLabel.work),
          ),
      ],
      organizations: [
        if (card.organization.trim().isNotEmpty)
          Organization(name: card.organization.trim()),
      ],
      websites: [
        if (card.website.trim().isNotEmpty)
          Website(
            url: card.website.trim(),
            label: const Label(WebsiteLabel.work),
          ),
      ],
    );
  }

  static String? _orNull(String value) =>
      value.trim().isEmpty ? null : value.trim();
}

DeviceContactsService defaultDeviceContactsService() =>
    NativeDeviceContactsService();
