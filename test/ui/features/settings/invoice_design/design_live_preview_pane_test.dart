import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/domain/company_settings.dart';
import 'package:admin/data/models/domain/design.dart';
import 'package:admin/data/repositories/design_repository.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/designs_api.dart';
import 'package:admin/data/services/live_design_service.dart';
import 'package:admin/ui/features/settings/view_models/design_edit_view_model.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/widgets/design_live_preview_pane.dart';

import '../../../../_localization_helper.dart';

class _FakeDesignsApi implements DesignsApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Counts `renderDesignPreview` calls, records the entity it was asked for,
/// and (optionally) throws a 422 so the section-error path can be exercised.
/// Returns a non-empty stub PDF so the pane clears its loading state.
class _CountingService implements LiveDesignService {
  int calls = 0;
  String? lastEntity;
  ValidationException? throwOnce;

  @override
  Future<Uint8List> renderDesignPreview({
    required String entityType,
    required Design design,
    String? entityId,
  }) async {
    calls++;
    lastEntity = entityType;
    final err = throwOnce;
    if (err != null) {
      throwOnce = null;
      throw err;
    }
    return Uint8List.fromList(const [0x25, 0x50, 0x44, 0x46]);
  }

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
    return Uint8List.fromList(const [0x25, 0x50, 0x44, 0x46]);
  }
}

Design _design({
  String id = 'd1',
  List<String> entities = const ['invoice', 'quote'],
  String body = '<b>x</b>',
}) => Design(
  id: id,
  name: 'Source',
  isCustom: true,
  isActive: true,
  isTemplate: false,
  isFree: false,
  entities: entities,
  template: DesignTemplate(body: body),
  updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  archivedAt: null,
  isDeleted: false,
);

// invoices (1<<12) + quotes (1<<2): two entity segments available.
const _bitmaskInvoiceQuote = 1 << 12 | 1 << 2;

void main() {
  late AppDatabase db;
  late DesignRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DesignRepository(db: db, api: _FakeDesignsApi());
  });

  tearDown(() async {
    await db.close();
  });

  DesignEditViewModel vmWith({Design? existing}) =>
      DesignEditViewModel(repo: repo, companyId: 'co1', existing: existing);

  Widget harness(
    LiveDesignService service,
    DesignEditViewModel vm, {
    ValueChanged<Map<String, String>>? onSectionErrors,
  }) => MaterialApp(
    localizationsDelegates: const [SyncLocalizationDelegate()],
    theme: ThemeData.light().copyWith(extensions: const [InTheme.lightSand]),
    home: Scaffold(
      body: SizedBox(
        width: 500,
        height: 800,
        child: DesignLivePreviewPane(
          service: service,
          vm: vm,
          enabledModulesBitmask: _bitmaskInvoiceQuote,
          embedded: true,
          onSectionErrors: onSectionErrors,
        ),
      ),
    ),
  );

  testWidgets('fires exactly one render on first mount when body present', (
    tester,
  ) async {
    final service = _CountingService();
    final vm = vmWith(existing: _design());

    await tester.pumpWidget(harness(service, vm));
    await tester.pump(); // post-frame _renderNow
    await tester.pump(const Duration(milliseconds: 50));

    expect(service.calls, 1);
    expect(service.lastEntity, 'invoice');
  });

  testWidgets('empty template renders the empty-state and zero requests', (
    tester,
  ) async {
    final service = _CountingService();
    final vm = vmWith(); // create-mode: empty template

    final errors = <Map<String, String>>[];
    await tester.pumpWidget(harness(service, vm, onSectionErrors: errors.add));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(service.calls, 0);
    expect(
      find.text('Pick a starting template to see a preview'),
      findsOneWidget,
    );
    expect(errors.last, isEmpty);
  });

  testWidgets('a draft mutation triggers exactly one debounced re-render', (
    tester,
  ) async {
    final service = _CountingService();
    final vm = vmWith(existing: _design());

    await tester.pumpWidget(harness(service, vm));
    await tester.pump(const Duration(milliseconds: 50));
    expect(service.calls, 1);

    vm.setBody('<b>edited</b>'); // notifies → debounce
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 50));

    expect(service.calls, 2);
  });

  testWidgets('422 maps to section errors via onSectionErrors', (tester) async {
    final service = _CountingService()
      ..throwOnce = const ValidationException('invalid', {
        'design.design.body': ['Template syntax error on line 1.'],
      });
    final vm = vmWith(existing: _design());

    Map<String, String>? received;
    await tester.pumpWidget(
      harness(service, vm, onSectionErrors: (e) => received = e),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(service.calls, 1);
    expect(received, {'body': 'Template syntax error on line 1.'});
  });

  testWidgets(
    'entity-type choice persists across a remount of the same design',
    (tester) async {
      final service = _CountingService();
      final vm = vmWith(existing: _design());

      await tester.pumpWidget(harness(service, vm));
      await tester.pump(const Duration(milliseconds: 50));
      expect(service.lastEntity, 'invoice');

      await tester.tap(find.text('Quote'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(service.lastEntity, 'quote'); // entity tap fires a render

      // Rebuild a fresh pane State for the same design id — the remembered
      // entity type should drive the first render, not snap back to invoice.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(harness(service, vm));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(service.lastEntity, 'quote');
    },
  );
}
