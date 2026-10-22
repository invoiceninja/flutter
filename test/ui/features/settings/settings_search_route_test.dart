import 'package:flutter/material.dart' show Icons, ValueNotifier;
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/entity_modules.dart';
import 'package:admin/app/router.dart' show buildRouter;
import 'package:admin/domain/entity_registry.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/settings/settings_search_catalog.dart';

/// Every place a settings search hit can send the user is a real route.
///
/// A hit navigates with `context.go(hit.route)`, and go_router's
/// `errorBuilder` is registered at the ROOT — an unroutable hit replaces the
/// whole app, sidebar included, with the route-error screen. The tab routes
/// are regex-constrained (`:tab(address|logo|…)`, `tabbedSettingsRoutePair`),
/// so a typo'd or renamed slug in `kSettingsSearchCatalog` is exactly such a
/// dead end. Resolved through the real router rather than by scanning
/// `settings_routes.dart`, because the tab patterns are assembled at runtime.
void main() {
  // A key gate can ask the platform (`platformSupportsSpellCheck` reads the
  // binding's dispatcher), so searchSettings needs a binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  EntityHandlers nonSpecHandlers(EntityType type, String routePath) =>
      EntityHandlers(
        type: type,
        wireName: type.name,
        apiPath: '/api/v1/${type.name}s',
        routePath: routePath,
        icon: Icons.business,
        dispatcher: DisabledEntityDispatcher(type),
      );

  // Mirrors `lib/app/services.dart`, as `entity_links_test.dart` does.
  EntityRegistry realRegistry() => EntityRegistry({
    for (final m in [...kWiredEntityModules, ...kDisabledEntityModules])
      m.type: m.toHandlers(DisabledEntityDispatcher(m.type)),
    EntityType.company: nonSpecHandlers(
      EntityType.company,
      '/settings/company_details',
    ),
    EntityType.user: nonSpecHandlers(EntityType.user, '/settings/account'),
  }, branchOrder: kBranchOrder);

  test('every section and every catalog tab resolves to a real route', () {
    final router = buildRouter(
      isAuthenticated: () => true,
      postLoginRoute: () => '/clients',
      refreshListenable: ValueNotifier<int>(0),
      registry: realRegistry(),
    );
    addTearDown(router.dispose);

    final routes = <String>{
      for (final section in kSettingsSections) section.route,
      for (final entry in kSettingsSearchCatalog.entries)
        for (final tab in entry.value)
          SettingsSearchHit(
            fieldKey: '',
            section: kSettingsSectionsBySlug[entry.key]!,
            tab: tab,
          ).route,
    };
    final dead = [
      for (final route in routes)
        if (router.configuration.findMatch(Uri.parse(route)).isError) route,
    ];
    expect(
      dead,
      isEmpty,
      reason:
          'These settings search destinations match no route — selecting one '
          'would blank the app:\n  ${dead.join('\n  ')}',
    );
    // Without this the loop could pass vacuously if the catalog emptied.
    expect(routes.length, greaterThan(kSettingsSections.length + 40));
  });

  test('a hit carries its tab in the route it opens', () {
    final l10n = Localization.forTesting(
      strings: const {'postal_code': 'Postal Code'},
    );
    final hit = searchSettings(
      'postal code',
      l10n,
    ).firstWhere((h) => h.fieldKey == 'postal_code');
    expect(hit.route, '/settings/company_details/address');
  });
}
