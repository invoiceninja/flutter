import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/services/device_contacts_service.dart';
import 'package:admin/domain/contacts_sync/contacts_sync_types.dart';
import 'package:admin/ui/features/settings/widgets/contacts_sync_section.dart';

import '../../shell/_shell_test_helpers.dart';

/// Only the capability + permission surface matters here; the reconcile itself
/// is covered in `test/domain/contacts_sync/`.
class _FakeDeviceContacts implements DeviceContactsService {
  _FakeDeviceContacts({
    this.canSync = true,
    this.permission = DeviceContactsPermission.granted,
  });

  @override
  final bool canSync;
  DeviceContactsPermission permission;
  int openedSettings = 0;
  int requests = 0;

  @override
  Future<DeviceContactsPermission> checkPermission() async => permission;

  @override
  Future<DeviceContactsPermission> requestPermission() async {
    requests++;
    return permission;
  }

  @override
  Future<void> openSystemSettings() async => openedSettings++;

  @override
  Future<String?> ensureGroup(String name, {String? knownId}) async => 'g1';

  @override
  Future<String?> createGroup(String name) async => null;

  @override
  Future<String?> findGroup(String name, {String? knownId}) async => 'g1';

  @override
  Future<List<String>> groupMemberIds(String groupId) async => const [];

  @override
  Future<List<String>> createContacts(
    List<DeviceContactCard> cards, {
    String? groupId,
  }) async => const [];

  @override
  Future<void> updateContacts(List<DeviceContactUpdate> items) async {}

  @override
  Future<void> deleteContacts(List<String> deviceIds) async {}

  @override
  Future<void> deleteGroup(String groupId) async {}

  @override
  bool get isAvailable => true;

  @override
  Future<DeviceContactImport?> pickContact() async => null;
}

void main() {
  Future<ShellFixture> pump(
    WidgetTester tester,
    _FakeDeviceContacts device, {
    bool enabled = false,
    ContactsSyncScope scope = ContactsSyncScope.all,
    bool hasRun = false,
    Size? surfaceSize,
    double textScale = 1,
  }) async {
    if (surfaceSize != null) {
      await tester.binding.setSurfaceSize(surfaceSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
    }
    final fixture = await buildFixture(
      companies: const [FakeCompany(id: 'c1', name: 'Acme Co', token: 't')],
      currentCompanyId: 'c1',
      deviceContactsService: device,
    );
    addTearDown(fixture.dispose);
    if (enabled) await fixture.services.contactsSync.setEnabled(true);
    if (scope != ContactsSyncScope.all) {
      await fixture.services.contactsSync.setScope(scope);
    }
    // Give the company a last-run mark so the status row (and its Remove
    // button) is reachable — the same state a completed pass leaves behind.
    if (hasRun) await fixture.services.contactsSync.run('c1');
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        // The real screen renders this inside `SettingsFormShell`, which is a
        // ListView. Without a scrollable here the card overflows the viewport
        // vertically on a short window and masks the horizontal overflow these
        // tests are actually looking for.
        child: wrapWithShell(
          fixture.services,
          const SingleChildScrollView(child: ContactsSyncSection()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return fixture;
  }

  Future<void> teardown(WidgetTester tester, ShellFixture fixture) async {
    fixture.services.recentlyViewed.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  testWidgets('renders nothing where the app cannot write contacts — desktop '
      'and web get no dead toggle they can do nothing about', (tester) async {
    final device = _FakeDeviceContacts(canSync: false);
    final fixture = await pump(tester, device);

    expect(find.byType(SwitchListTile), findsNothing);
    expect(find.text('Sync contacts to this device'), findsNothing);

    await teardown(tester, fixture);
  });

  testWidgets('shows just the toggle, off, when the feature is unused', (
    tester,
  ) async {
    final device = _FakeDeviceContacts();
    final fixture = await pump(tester, device);

    expect(find.text('Sync contacts to this device'), findsOneWidget);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );
    // Nothing below the toggle until it is switched on.
    expect(find.text('Sync now'), findsNothing);
    expect(find.text('All Clients'), findsNothing);

    await teardown(tester, fixture);
  });

  testWidgets('once enabled and granted, shows the scope picker and the '
      'sync/remove controls', (tester) async {
    final device = _FakeDeviceContacts();
    final fixture = await pump(tester, device, enabled: true);

    expect(find.text('All Clients'), findsOneWidget);
    expect(find.text('Assigned to me'), findsOneWidget);
    expect(find.text('Sync now'), findsOneWidget);
    expect(find.text('Remove synced contacts'), findsOneWidget);
    expect(find.text('Not synced yet'), findsOneWidget);
    // No permission prompt when access is already granted.
    expect(find.text('Grant permission'), findsNothing);

    await teardown(tester, fixture);
  });

  testWidgets('a re-askable denial offers Grant permission, not a dead-end', (
    tester,
  ) async {
    final device = _FakeDeviceContacts(
      permission: DeviceContactsPermission.denied,
    );
    final fixture = await pump(tester, device, enabled: true);

    expect(find.text('Grant permission'), findsOneWidget);
    expect(find.text('Open settings'), findsNothing);
    // The sync controls are hidden while access is missing — pressing them
    // could only fail.
    expect(find.text('Sync now'), findsNothing);

    await tester.tap(find.text('Grant permission'));
    await tester.pumpAndSettle();
    expect(device.requests, 1);

    await teardown(tester, fixture);
  });

  testWidgets('a permanent denial offers Open settings — the only way back, '
      'and it works without adding permission_handler', (tester) async {
    final device = _FakeDeviceContacts(
      permission: DeviceContactsPermission.permanentlyDenied,
    );
    final fixture = await pump(tester, device, enabled: true);

    expect(find.text('Open settings'), findsOneWidget);
    expect(find.text('Grant permission'), findsNothing);

    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    expect(device.openedSettings, 1);

    await teardown(tester, fixture);
  });

  testWidgets("iOS 18's limited grant is surfaced, not silently ignored", (
    tester,
  ) async {
    final device = _FakeDeviceContacts(
      permission: DeviceContactsPermission.limited,
    );
    final fixture = await pump(tester, device, enabled: true);

    expect(find.text('Open settings'), findsOneWidget);
    expect(
      find.textContaining('Only selected contacts are shared'),
      findsOneWidget,
    );
    expect(find.text('Sync now'), findsNothing);

    await teardown(tester, fixture);
  });

  testWidgets('the scope picker reflects the stored preference', (
    tester,
  ) async {
    final device = _FakeDeviceContacts();
    final fixture = await pump(
      tester,
      device,
      enabled: true,
      scope: ContactsSyncScope.assignedToMe,
    );

    final button = tester.widget<SegmentedButton<ContactsSyncScope>>(
      find.byType(SegmentedButton<ContactsSyncScope>),
    );
    expect(button.selected, {ContactsSyncScope.assignedToMe});

    await teardown(tester, fixture);
  });

  testWidgets('the help text names the label so the user knows what will '
      'appear in their address book', (tester) async {
    final device = _FakeDeviceContacts();
    final fixture = await pump(tester, device);

    expect(find.textContaining('Invoice Ninja — Acme Co'), findsOneWidget);

    await teardown(tester, fixture);
  });

  testWidgets('the action buttons do not overflow a 360px handset — the only '
      'device class this section renders on', (tester) async {
    final device = _FakeDeviceContacts();
    final fixture = await pump(
      tester,
      device,
      enabled: true,
      hasRun: true,
      surfaceSize: const Size(360, 720),
    );

    expect(find.text('Remove synced contacts'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await teardown(tester, fixture);
  });

  testWidgets('nor at 1.4x text scale, where Inter Tight is wider still', (
    tester,
  ) async {
    final device = _FakeDeviceContacts();
    final fixture = await pump(
      tester,
      device,
      enabled: true,
      hasRun: true,
      surfaceSize: const Size(360, 720),
      textScale: 1.4,
    );

    expect(tester.takeException(), isNull);

    await teardown(tester, fixture);
  });

  testWidgets('switching the toggle off keeps a way to remove the cards an '
      'earlier pass already added — otherwise they are stranded', (
    tester,
  ) async {
    final device = _FakeDeviceContacts();
    final fixture = await pump(tester, device, hasRun: true);

    // Toggle is off...
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );
    // ...but Remove is still reachable, and the sync controls are not.
    expect(find.text('Remove synced contacts'), findsOneWidget);
    expect(find.text('Sync now'), findsNothing);
    expect(find.text('All Clients'), findsNothing);

    await teardown(tester, fixture);
  });

  testWidgets('with no prior pass, switching off leaves nothing behind', (
    tester,
  ) async {
    final device = _FakeDeviceContacts();
    final fixture = await pump(tester, device);

    expect(find.text('Remove synced contacts'), findsNothing);

    await teardown(tester, fixture);
  });
}
