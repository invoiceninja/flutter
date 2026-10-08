import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/company_settings.dart';
import 'package:admin/data/models/domain/design.dart';
import 'package:admin/data/services/live_design_service.dart';
import 'package:admin/ui/features/settings/state/settings_level_controller.dart';
import 'package:admin/ui/features/settings/view_models/settings_draft_view_model.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/widgets/live_pdf_preview_pane.dart';

import '../../../../_localization_helper.dart';

/// Counts every call to [renderPreview]. Returns a zero-byte stub so the
/// pane never touches the network.
class _CountingService implements LiveDesignService {
  int calls = 0;

  @override
  Future<Uint8List> renderPreview({
    required String entityType,
    required CompanySettings settings,
    String settingsType = 'company',
    String? groupId,
    String? clientId,
    String? entityId,
  }) async {
    calls++;
    // Return a non-empty buffer so the pane treats this as a successful
    // render and clears its loading state.
    return Uint8List.fromList(const [0x25, 0x50, 0x44, 0x46]);
  }

  @override
  Future<Uint8List> renderDesignPreview({
    required String entityType,
    required Design design,
    String? entityId,
  }) async {
    calls++;
    return Uint8List.fromList(const [0x25, 0x50, 0x44, 0x46]);
  }
}

/// Minimal [SettingsDraftHost] for the test. `notify()` exposes the
/// underlying `ChangeNotifier.notifyListeners` so the test can simulate the
/// user typing.
class _FakeHost extends SettingsDraftHost {
  @override
  CompanySettings get settings => const CompanySettings();
  @override
  CompanySettings get draftSettings => const CompanySettings();
  @override
  CompanySettings get initialSettings => const CompanySettings();
  @override
  Company? get draft => const Company();
  @override
  bool get isLoaded => true;
  @override
  bool get isDirty => false;
  @override
  bool get isSaving => false;
  @override
  String? get loadError => null;
  @override
  String? get submitError => null;
  @override
  Map<String, List<String>> get fieldErrors => const {};
  @override
  bool isOverridden(String apiKey) => false;
  @override
  void updateSettings(CompanySettings Function(CompanySettings) edit) {}
  @override
  void updateCompany(Company Function(Company) edit) {}
  @override
  void setOverride({
    required String apiKey,
    required bool enabled,
    String? cascadedValue,
  }) {}
  @override
  void reset() {}
  @override
  Future<Object?> save() async => null;
  @override
  Future<void> load() async {}

  void notify() => notifyListeners();
}

Widget _harness({
  required LiveDesignService service,
  required SettingsDraftHost host,
  required SettingsLevelController level,
}) {
  return MaterialApp(
    localizationsDelegates: const [SyncLocalizationDelegate()],
    theme: ThemeData.light().copyWith(extensions: const [InTheme.lightSand]),
    home: MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsDraftHost>.value(value: host),
        ChangeNotifierProvider<SettingsLevelController>.value(value: level),
      ],
      child: Scaffold(
        body: SizedBox(
          width: 500,
          height: 800,
          child: LivePdfPreviewPane(service: service, embedded: true),
        ),
      ),
    ),
  );
}

void main() {
  group('LivePdfPreviewPane render lifecycle', () {
    testWidgets(
      'fires exactly one render on first mount, regardless of how many '
      'inherited-widget notifications occur before the user edits',
      (tester) async {
        final service = _CountingService();
        final host = _FakeHost();
        final level = SettingsLevelController();

        await tester.pumpWidget(
          _harness(service: service, host: host, level: level),
        );

        // Initial post-frame render kicks in.
        await tester.pump();
        // Settle the (immediate) future returned by _CountingService.
        await tester.pump(const Duration(milliseconds: 50));

        // Bumping the level controller (which is in scope) used to re-fire
        // `didChangeDependencies`, attach a duplicate listener, and trigger
        // a redundant render. After the fix, no new render fires.
        level.setLevel(SettingsLevel.client, targetId: 'c1', targetName: 'C');
        await tester.pump(const Duration(milliseconds: 50));

        // Reset back to company scope. Still no new render — the host
        // hasn't changed.
        level.reset();
        await tester.pump(const Duration(milliseconds: 50));

        expect(
          service.calls,
          1,
          reason:
              'first-mount render is the only one expected before the host '
              'fires; any extra count means duplicate listeners are attached',
        );
      },
    );

    testWidgets('host.notifyListeners() fires exactly one debounced render '
        '(not N, where N = listener registrations)', (tester) async {
      final service = _CountingService();
      final host = _FakeHost();
      final level = SettingsLevelController();

      await tester.pumpWidget(
        _harness(service: service, host: host, level: level),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(service.calls, 1);

      // Trigger several InheritedWidget notifications via the level
      // controller before the host notifies. With the bug present, each
      // `didChangeDependencies` cycle added a duplicate listener; with
      // the fix, only one listener stays attached.
      level.setLevel(SettingsLevel.client, targetId: 'c1', targetName: 'C');
      await tester.pump();
      level.reset();
      await tester.pump();
      level.setLevel(SettingsLevel.client, targetId: 'c2', targetName: 'C2');
      await tester.pump();

      // Now simulate the user editing — the host notifies once.
      host.notify();

      // Wait for the 400 ms debounce window to elapse. 500 ms (not 410)
      // leaves headroom on slow CI runners where the timer can fire late.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        service.calls,
        2,
        reason:
            'first-mount render + one debounced render = 2; any higher '
            'count indicates duplicate host listeners.',
      );
    });

    testWidgets(
      'didUpdateWidget snaps _entityType when the active entity falls off '
      'the enabled-modules bitmask, and fires exactly one render',
      (tester) async {
        final service = _CountingService();
        final host = _FakeHost();
        final level = SettingsLevelController();

        // Start with invoices + quotes enabled. The pane's initial entity
        // type is `'invoice'` (first option), but the user can swap to
        // quote — same code path as the auto-correct.
        const startBitmask = 1 << 12 | 1 << 2; // invoices (4096) + quotes (4)
        const endBitmask = 1 << 12; // invoices only

        Widget harness(int bitmask) => MaterialApp(
          localizationsDelegates: const [SyncLocalizationDelegate()],
          theme: ThemeData.light().copyWith(
            extensions: const [InTheme.lightSand],
          ),
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<SettingsDraftHost>.value(value: host),
              ChangeNotifierProvider<SettingsLevelController>.value(
                value: level,
              ),
            ],
            child: Scaffold(
              body: SizedBox(
                width: 500,
                height: 800,
                child: LivePdfPreviewPane(
                  service: service,
                  enabledModulesBitmask: bitmask,
                  embedded: true,
                ),
              ),
            ),
          ),
        );

        await tester.pumpWidget(harness(startBitmask));
        await tester.pump(const Duration(milliseconds: 50));
        expect(service.calls, 1);

        // Find the segmented button and tap "quote".
        await tester.tap(find.text('Quote'));
        await tester.pump(const Duration(milliseconds: 50));
        // Tapping the segmented button fires `_renderNow()` directly
        // (no debounce on entity-type changes).
        expect(service.calls, 2, reason: 'entity-type tap fires one render');

        // Now disable the quotes module. `didUpdateWidget` should snap
        // `_entityType` back to `'invoice'` and fire one render — not two
        // (the old build-time mutation would re-render via setState
        // followed by another via the snap).
        await tester.pumpWidget(harness(endBitmask));
        await tester.pump(const Duration(milliseconds: 50));
        expect(
          service.calls,
          3,
          reason:
              'bitmask change that drops the active entity should fire '
              'exactly one auto-correct render',
        );
        // And subsequent pumps must not fire more renders — confirms the
        // snap doesn't loop.
        await tester.pump(const Duration(milliseconds: 100));
        expect(service.calls, 3);
      },
    );
  });
}
