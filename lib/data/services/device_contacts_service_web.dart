import 'package:admin/data/services/device_contacts_service.dart';

/// Web stub: the browser has no OS-native contact picker, so the import button
/// hides itself ([isAvailable] == false) and [pickContact] is a no-op. Never
/// imports `flutter_contacts` (which has no web implementation and would break
/// `flutter build web --wasm`).
class UnsupportedDeviceContactsService implements DeviceContactsService {
  const UnsupportedDeviceContactsService();

  @override
  bool get isAvailable => false;

  @override
  Future<DeviceContactImport?> pickContact() async => null;

  // Push direction: equally unavailable. `canSync` false keeps the whole
  // Contacts settings section off the page, so none of the rest is reachable —
  // they're implemented as inert values (never throws) purely so a future
  // caller that skips the gate degrades instead of crashing.

  @override
  bool get canSync => false;

  @override
  Future<DeviceContactsPermission> checkPermission() async =>
      DeviceContactsPermission.unavailable;

  @override
  Future<DeviceContactsPermission> requestPermission() async =>
      DeviceContactsPermission.unavailable;

  @override
  Future<void> openSystemSettings() async {}

  @override
  Future<String?> ensureGroup(String name, {String? knownId}) async => null;

  @override
  Future<String?> createGroup(String name) async => null;

  @override
  Future<String?> findGroup(String name, {String? knownId}) async => null;

  @override
  Future<List<String>> groupMemberIds(String groupId) async => const <String>[];

  @override
  Future<Set<String>> existingContactIds(Iterable<String> ids) async =>
      const <String>{};

  @override
  Future<void> addContactsToGroup({
    required String groupId,
    required List<String> contactIds,
  }) async {}

  @override
  Future<List<String>> createContacts(
    List<DeviceContactCard> cards, {
    String? groupId,
  }) async => const <String>[];

  @override
  Future<void> updateContacts(List<DeviceContactUpdate> items) async {}

  @override
  Future<void> deleteContacts(List<String> deviceIds) async {}

  @override
  Future<void> deleteGroup(String groupId) async {}
}

DeviceContactsService defaultDeviceContactsService() =>
    const UnsupportedDeviceContactsService();
