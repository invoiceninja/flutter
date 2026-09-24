import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/shortcuts/key_binding.dart';
import 'package:admin/app/shortcuts/shortcut_catalog.dart';
import 'package:admin/app/text_scale_controller.dart';
import 'package:admin/data/prefs/device_pref_keys.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/domain/contacts_sync/contacts_sync_types.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/sidebar_badge_modes.dart';
import 'package:admin/domain/sidebar_menu.dart';
import 'package:admin/domain/tasks/tasks_view_mode.dart';

import '../ui/features/shell/_shell_test_helpers.dart';

/// Every device preference moved off its default through the controller that
/// owns it, then the session ends. A deliberate sign-out must leave the
/// device preferences alone and put every account preference back on its
/// default — in memory, where the UI reads it, and on disk, where the next
/// launch does; an involuntary end (a 401, an idle timeout) must leave both
/// alone.
///
/// This replaces a source scan that could only check that each controller's
/// `resetInMemory()` was *called* from the wipe hook, and that missed the
/// controllers that had never been given one. Here nothing is wired by hand:
/// the controllers follow `DevicePrefsStore`, and a key added without a probe
/// fails the first test.
class _Probe {
  const _Probe(this.change, this.isDefault);

  /// Moves the preference off its default through its owner.
  final Future<void> Function(Services s) change;

  /// Reads the owner's in-memory value.
  final bool Function(Services s) isDefault;
}

final _customInk = const Color(0xFF445566);
final _binding = KeyBinding.logical(
  LogicalKeyboardKey.keyB.keyId,
  usesPrimary: true,
);

/// In insertion order, which matters once: the light variant is changed
/// before the custom theme, because a new preset clears its side's overrides.
final Map<PrefKey<Object>, _Probe> _probes = {
  DevicePrefKeys.locale: _Probe(
    (s) => s.locale.set(const Locale('de')),
    (s) => s.locale.value == null,
  ),
  DevicePrefKeys.themeMode: _Probe(
    (s) => s.theme.setThemeMode(ThemeMode.dark),
    (s) => s.theme.themeMode == ThemeMode.system,
  ),
  DevicePrefKeys.lightVariant: _Probe(
    (s) => s.theme.setLightVariant(LightVariant.mist),
    (s) => s.theme.lightVariant == LightVariant.sand,
  ),
  DevicePrefKeys.darkVariant: _Probe(
    (s) => s.theme.setDarkVariant(DarkVariant.carbon),
    (s) => s.theme.darkVariant == DarkVariant.espresso,
  ),
  DevicePrefKeys.customTheme: _Probe(
    (s) =>
        s.theme.setCustomOverride(Brightness.dark, CustomToken.ink, _customInk),
    (s) => s.theme.customTheme == defaultCustomTheme,
  ),
  DevicePrefKeys.textScale: _Probe(
    (s) => s.textScale.set(kTextScaleLarge),
    (s) => s.textScale.value == kTextScaleNormal,
  ),
  DevicePrefKeys.keyboardShortcuts: _Probe(
    (s) async => s.keyboardShortcuts.setBinding(
      ShortcutActionIds.toggleSidebar,
      _binding,
    ),
    (s) => !s.keyboardShortcuts.isOverridden(ShortcutActionIds.toggleSidebar),
  ),
  DevicePrefKeys.sidebarBadgeModes: _Probe(
    (s) => s.sidebarBadgeModes.set(EntityType.invoice, 'overdue'),
    (s) => s.sidebarBadgeModes.modeFor(EntityType.invoice) == kBadgeModeTotal,
  ),
  DevicePrefKeys.confirmActions: _Probe(
    (s) => s.confirmActions.set(false),
    (s) => s.confirmActions.value,
  ),
  DevicePrefKeys.statusTabs: _Probe(
    (s) => s.statusTabs.set(false),
    (s) => s.statusTabs.value,
  ),
  DevicePrefKeys.contactsSync: _Probe(
    (s) => s.contactsSync.setScope(ContactsSyncScope.assignedToMe),
    (s) => s.contactsSync.scope == ContactsSyncScope.all,
  ),
  DevicePrefKeys.phoneActions: _Probe(
    (s) => s.phoneActions.setConfirmBeforeCall(true),
    (s) => !s.phoneActions.value.confirmBeforeCall,
  ),
  DevicePrefKeys.sidebarMenu: _Probe(
    (s) => s.sidebarMenu.setLayout(SidebarMenuLayout.grid),
    (s) => s.sidebarMenu.layout == SidebarMenuLayout.list,
  ),
  DevicePrefKeys.tasksView: _Probe(
    (s) => s.tasksView.set(TasksViewMode.kanban),
    (s) => s.tasksView.value == null,
  ),
  DevicePrefKeys.hideUnverifiedUsers: _Probe(
    (s) => s.hideUnverifiedUsers.set(true),
    (s) => !s.hideUnverifiedUsers.value,
  ),
  DevicePrefKeys.hideEmptyPanels: _Probe(
    (s) => s.hideEmptyPanels.set(false, isPhone: true),
    (s) => s.hideEmptyPanels.value == null,
  ),
  DevicePrefKeys.sidebarCollapsed: _Probe(
    (s) => s.sidebar.set(true),
    (s) => !s.sidebar.value,
  ),
};

void main() {
  test('every device preference has a probe', () {
    expect(
      {for (final k in DevicePrefKeys.all) k.name},
      {for (final k in _probes.keys) k.name},
      reason:
          'a new DevicePrefKeys entry needs a probe here, so its behaviour '
          'across a sign-out is decided and pinned',
    );
  });

  Future<ShellFixture> changedEverything() async {
    final fixture = await buildFixture(
      companies: const [FakeCompany(id: 'co1', name: 'Acme')],
    );
    for (final MapEntry(:key, value: probe) in _probes.entries) {
      await probe.change(fixture.services);
      expect(
        probe.isDefault(fixture.services),
        isFalse,
        reason: 'the ${key.name} probe must move it off its default',
      );
    }
    // The shortcut write is fire-and-forget; let it land.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    return fixture;
  }

  test('a deliberate sign-out keeps the device preferences and forgets the '
      'account ones, in memory and on disk', () async {
    final fixture = await changedEverything();
    addTearDown(fixture.dispose);

    await fixture.services.auth.logout(data: LocalDataPolicy.destroy);

    final rows = await fixture.db.devicePrefsDao.readAll();
    for (final MapEntry(:key, value: probe) in _probes.entries) {
      final kept = key.scope == PrefScope.device;
      expect(
        probe.isDefault(fixture.services),
        !kept,
        reason: kept
            ? '${key.name} belongs to the device — a sign-out keeps it'
            : '${key.name} belongs to the account — the next person to sign '
                  'in must not inherit it',
      );
      expect(rows.containsKey(key.name), kept, reason: '${key.name} on disk');
    }
  });

  test('an involuntary end (401, idle) keeps every preference', () async {
    final fixture = await changedEverything();
    addTearDown(fixture.dispose);

    await fixture.services.auth.logout(data: LocalDataPolicy.keep);

    final rows = await fixture.db.devicePrefsDao.readAll();
    for (final MapEntry(:key, value: probe) in _probes.entries) {
      expect(probe.isDefault(fixture.services), isFalse, reason: key.name);
      expect(rows.containsKey(key.name), isTrue, reason: key.name);
    }
  });
}
