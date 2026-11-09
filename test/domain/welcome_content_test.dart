import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart'
    show Icons, TargetPlatform, ValueNotifier;
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/entity_modules.dart';
import 'package:admin/app/router.dart' show buildRouter;
import 'package:admin/domain/entity_registry.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/release_notes.dart';
import 'package:admin/domain/welcome_content.dart';
import 'package:admin/ui/features/dashboard/widgets/setup_checklist_card.dart';

/// The Welcome's bundled content (docs/first-run-welcome.md): every string
/// resolves, the App Store builds never name another store, no list runs
/// past three rows, and every row leads somewhere real.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final english = <String, dynamic>{
    ...jsonDecode(File('assets/i18n/_app_pending.json').readAsStringSync())
        as Map<String, dynamic>,
    ...jsonDecode(File('assets/i18n/en.json').readAsStringSync())
        as Map<String, dynamic>,
  };
  final all = [
    ...kWelcomeGetStarted,
    ...kWelcomeWhatsChanged,
    ...kWelcomeCantFind,
  ];
  String text(WelcomeItem i) => [
    i.titleKey,
    i.titleTemplateKey,
    i.bodyKey,
    i.touchBodyKey,
  ].nonNulls.map((k) => english[k] as String? ?? '').join(' ');

  test('every key resolves to English', () {
    final missing = [
      for (final item in all)
        for (final key in [
          if (item.titleTemplateKey == null) item.titleKey,
          item.titleTemplateKey,
          item.bodyKey,
          item.touchBodyKey,
          ...item.titleArgs.values,
        ])
          if (key != null && (english[key] as String? ?? '').trim().isEmpty)
            key,
    ];
    expect(missing, isEmpty);
  });

  test('every template placeholder has an argument, and nothing else', () {
    final token = RegExp(r':([a-z_]+)');
    for (final item in all) {
      final template = item.titleTemplateKey;
      if (template == null) {
        expect(item.titleArgs, isEmpty, reason: item.id);
        continue;
      }
      expect(item.titleKey, isEmpty, reason: '${item.id}: one title only');
      final placeholders = token
          .allMatches(english[template] as String)
          .map((m) => m.group(1))
          .toSet();
      expect(placeholders, item.titleArgs.keys.toSet(), reason: item.id);
    }
  });

  test('keyboard rows are left out on touch, a phone browser included', () {
    final webPhone = releaseNoteSurfaces(
      isWeb: true,
      platform: TargetPlatform.android,
    );
    final shown = visibleWelcomeItems(
      kWelcomeWhatsChanged,
      surfaces: webPhone,
      reachable: (_) => true,
      touch: true,
      limit: null,
    ).map((i) => i.id);
    expect(shown, isNot(contains('keyboard')));
  });

  test('no copy carries an em dash', () {
    for (final item in all) {
      expect(text(item), isNot(contains('—')), reason: item.id);
    }
  });

  group('the App Store builds (Apple guideline 2.3.10)', () {
    final forbidden = RegExp(
      r'android|google|play store|f-droid|fdroid|microsoft store|\bsnap\b|'
      r'appimage',
      caseSensitive: false,
    );
    for (final platform in [TargetPlatform.macOS, TargetPlatform.iOS]) {
      test('${platform.name} shows nothing that names another store', () {
        final surfaces = releaseNoteSurfaces(isWeb: false, platform: platform);
        for (final list in [
          kWelcomeGetStarted,
          kWelcomeWhatsChanged,
          kWelcomeCantFind,
        ]) {
          final shown = visibleWelcomeItems(
            list,
            surfaces: surfaces,
            reachable: (_) => true,
            limit: null,
          );
          for (final item in shown) {
            expect(text(item), isNot(matches(forbidden)), reason: item.id);
          }
        }
      });
    }
  });

  test('a phone is not pitched the phone app or the keyboard', () {
    final phone = releaseNoteSurfaces(
      isWeb: false,
      platform: TargetPlatform.android,
    );
    final ids = {
      for (final list in [kWelcomeGetStarted, kWelcomeWhatsChanged])
        ...visibleWelcomeItems(
          list,
          surfaces: phone,
          reachable: (_) => true,
          limit: null,
        ).map((i) => i.id),
    };
    expect(ids, isNot(contains('devices')));
    expect(ids, isNot(contains('keyboard')));
  });

  test('the web and Windows are not told about home-screen widgets', () {
    for (final surfaces in [
      releaseNoteSurfaces(isWeb: true, platform: TargetPlatform.macOS),
      releaseNoteSurfaces(isWeb: false, platform: TargetPlatform.windows),
    ]) {
      final ids = visibleWelcomeItems(
        kWelcomeWhatsChanged,
        surfaces: surfaces,
        reachable: (_) => true,
        limit: null,
      ).map((i) => i.id);
      expect(ids, isNot(contains('widgets')));
    }
  });

  test('no list shows more than $kWelcomeMaxRows rows on any surface', () {
    for (final platform in TargetPlatform.values) {
      for (final web in [true, false]) {
        final surfaces = releaseNoteSurfaces(isWeb: web, platform: platform);
        for (final list in [kWelcomeGetStarted, kWelcomeWhatsChanged]) {
          final shown = visibleWelcomeItems(
            list,
            surfaces: surfaces,
            reachable: (_) => true,
          );
          expect(shown.length, lessThanOrEqualTo(kWelcomeMaxRows));
          expect(shown, isNotEmpty);
        }
      }
    }
  });

  test('a row this user cannot reach is left out, and the next fills in', () {
    final shown = visibleWelcomeItems(
      kWelcomeWhatsChanged,
      surfaces: const {},
      reachable: (a) => a is! WelcomeRoute || !a.adminOnly,
    );
    expect(shown.map((i) => i.id), ['offline', 'reports', 'tasks']);
  });

  test('every route the Welcome and the checklist open is a real route', () {
    EntityHandlers nonSpec(EntityType type, String routePath) => EntityHandlers(
      type: type,
      wireName: type.name,
      apiPath: '/api/v1/${type.name}s',
      routePath: routePath,
      icon: Icons.business,
      dispatcher: DisabledEntityDispatcher(type),
    );
    final registry = EntityRegistry({
      for (final m in [...kWiredEntityModules, ...kDisabledEntityModules])
        m.type: m.toHandlers(DisabledEntityDispatcher(m.type)),
      EntityType.company: nonSpec(
        EntityType.company,
        '/settings/company_details',
      ),
      EntityType.user: nonSpec(EntityType.user, '/settings/account'),
    }, branchOrder: kBranchOrder);
    final router = buildRouter(
      isAuthenticated: () => true,
      postLoginRoute: () => '/clients',
      refreshListenable: ValueNotifier<int>(0),
      registry: registry,
    );
    addTearDown(router.dispose);
    final routes = <String>{
      for (final item in all)
        if (item.action case WelcomeRoute(:final path)) path,
      kChecklistLogoRoute,
      kChecklistInvoiceRoute,
      kChecklistGatewayRoute,
      kChecklistClientRoute,
      kChecklistImportRoute,
    };
    final dead = [
      for (final r in routes)
        if (router.configuration.findMatch(Uri.parse(r)).isError) r,
    ];
    expect(dead, isEmpty);
  });
}
