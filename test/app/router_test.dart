import 'package:admin/app/entity_modules.dart' show DisabledEntityDispatcher;
import 'package:admin/app/router.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/domain/entity_registry.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter_test/flutter_test.dart';

/// `defaultPostLoginRoute` is the post-login landing decision. Admin-portal
/// routes to the dashboard when the active company has `view_dashboard` and
/// falls back to clients otherwise — we mirror that here.

AuthSession _sessionWith(AuthCompany company) => AuthSession(
  baseUrl: 'https://example.test',
  isHosted: false,
  accountId: 'acc-1',
  companies: [company],
  currentCompanyId: company.id,
  plan: '',
  hostedCompanyCount: 0,
);

AuthCompany _company({
  required String permissions,
  bool isAdmin = false,
  bool isOwner = false,
  String name = 'Co',
  String displayName = 'Co',
}) => AuthCompany(
  id: 'co-1',
  name: name,
  displayName: displayName,
  permissions: permissions,
  isAdmin: isAdmin,
  isOwner: isOwner,
);

const _testRoots = ['/clients', '/products'];

EntityHandlers _handler(
  EntityType type,
  String wire,
  String routePath, {
  SidebarSection section = SidebarSection.top,
  bool disabled = false,
}) => EntityHandlers(
  type: type,
  wireName: wire,
  apiPath: '/api/v1/$wire',
  routePath: routePath,
  icon: Icons.circle,
  dispatcher: DisabledEntityDispatcher(type),
  sidebarSection: section,
  disabled: disabled,
);

/// client (always-on), invoice + task (module-gated), companyGateway
/// (settings-only / SidebarSection.none — never a disabled-root candidate).
EntityRegistry _registry() => EntityRegistry({
  EntityType.client: _handler(EntityType.client, 'client', '/clients'),
  EntityType.invoice: _handler(EntityType.invoice, 'invoice', '/invoices'),
  EntityType.task: _handler(EntityType.task, 'task', '/tasks'),
  EntityType.companyGateway: _handler(
    EntityType.companyGateway,
    'company_gateway',
    '/settings/company_gateways',
    section: SidebarSection.none,
  ),
});

void main() {
  group('defaultPostLoginRoute', () {
    test('routes to /dashboard when company has view_dashboard', () {
      final session = _sessionWith(_company(permissions: 'view_dashboard'));
      expect(defaultPostLoginRoute(session), '/dashboard');
    });

    test('routes to /dashboard for admins regardless of permissions', () {
      final session = _sessionWith(_company(permissions: '', isAdmin: true));
      expect(defaultPostLoginRoute(session), '/dashboard');
    });

    test('routes to /dashboard for owners regardless of permissions', () {
      final session = _sessionWith(_company(permissions: '', isOwner: true));
      expect(defaultPostLoginRoute(session), '/dashboard');
    });

    test('routes to /clients when restricted user lacks view_dashboard', () {
      final session = _sessionWith(
        _company(permissions: 'view_client,edit_client'),
      );
      expect(defaultPostLoginRoute(session), '/clients');
    });

    test('routes to /clients when there is no session', () {
      expect(defaultPostLoginRoute(null), '/clients');
    });
  });

  group('companySafeLocation', () {
    test('passes /dashboard through unchanged', () {
      expect(companySafeLocation('/dashboard', _testRoots), '/dashboard');
    });

    test('passes /clients (list) through unchanged', () {
      expect(companySafeLocation('/clients', _testRoots), '/clients');
    });

    test('strips /clients/new back to /clients — a create form binds the '
        'active company at mount, so it must not survive a switch', () {
      // Keeping the location made go_router short-circuit (same path), so the
      // form stayed bound to the previous company and Save queued the record
      // into the wrong workspace.
      expect(companySafeLocation('/clients/new', _testRoots), '/clients');
    });

    test('strips /clients/<id> back to /clients', () {
      expect(companySafeLocation('/clients/abc123', _testRoots), '/clients');
    });

    test('strips /clients/<id>/edit back to /clients', () {
      expect(
        companySafeLocation('/clients/abc123/edit', _testRoots),
        '/clients',
      );
    });

    test('passes /settings/company_details through unchanged', () {
      expect(
        companySafeLocation('/settings/company_details', _testRoots),
        '/settings/company_details',
      );
    });

    test('passes deep settings sub-routes through unchanged', () {
      expect(
        companySafeLocation('/settings/company_details/address', _testRoots),
        '/settings/company_details/address',
      );
    });

    // Settings-hosted entities are in `uiRoutePaths` too: their edit/detail
    // screens bind the active company once at mount, so a stale
    // `/settings/<entity>/<id>` surviving a company switch would keep
    // showing — and saving to — the previous company's record.
    const settingsRoots = [
      '/settings/company_gateways',
      '/settings/bank_accounts',
      '/settings/bank_accounts/transaction_rules',
    ];

    test('strips /settings/<entity>/<id>/edit back to the entity list', () {
      expect(
        companySafeLocation(
          '/settings/company_gateways/gw1/edit',
          settingsRoots,
        ),
        '/settings/company_gateways',
      );
    });

    test('strips /settings/<entity>/new back to its list — same reason as '
        '/clients/new: the create form binds the company at mount', () {
      expect(
        companySafeLocation('/settings/company_gateways/new', settingsRoots),
        '/settings/company_gateways',
      );
    });

    test('nested entity root: its own list passes through unchanged', () {
      // `/settings/bank_accounts/transaction_rules` nests under
      // `/settings/bank_accounts` — the longer root must win, or the rules
      // list itself would be mis-stripped to the bank accounts list.
      expect(
        companySafeLocation(
          '/settings/bank_accounts/transaction_rules',
          settingsRoots,
        ),
        '/settings/bank_accounts/transaction_rules',
      );
    });

    test(
      'nested entity root: ids strip to the nested list, not the parent',
      () {
        expect(
          companySafeLocation(
            '/settings/bank_accounts/transaction_rules/tr1/edit',
            settingsRoots,
          ),
          '/settings/bank_accounts/transaction_rules',
        );
      },
    );

    test('preserves query string on safe routes', () {
      expect(
        companySafeLocation('/clients?filter=active', _testRoots),
        '/clients?filter=active',
      );
    });

    test('falls back to /clients for empty input', () {
      expect(companySafeLocation('', _testRoots), '/clients');
    });

    test('falls back to /clients for garbage input', () {
      // `Uri.tryParse` accepts most strings; an empty path is the only
      // structural failure we treat as garbage.
      expect(companySafeLocation('http://', _testRoots), '/clients');
    });

    test(
      'strips a disabled-but-routed settings entity id (tax_rates) on switch',
      () {
        // Regression (H2): `tax_rate` / custom designs are `disabled: true`
        // but have a wired, reachable edit/detail route. They MUST appear in
        // `uiRoutePaths` so a stale `/settings/tax_rates/<id>` is stripped on a
        // company switch — otherwise the edit screen (company captured once at
        // mount) keeps reading from, and Save/Archive/Delete keeps writing to,
        // the previous company's record.
        final registry = EntityRegistry({
          EntityType.client: _handler(EntityType.client, 'client', '/clients'),
          EntityType.taxRate: _handler(
            EntityType.taxRate,
            'tax_rate',
            '/settings/tax_rates',
            section: SidebarSection.none,
            disabled: true,
          ),
        });
        final roots = registry.uiRoutePaths.toList();
        expect(roots, contains('/settings/tax_rates'));
        expect(
          companySafeLocation('/settings/tax_rates/tr1/edit', roots),
          '/settings/tax_rates',
        );
        expect(
          companySafeLocation('/settings/tax_rates/tr1', roots),
          '/settings/tax_rates',
        );
      },
    );
  });

  group('isCompanySetupRequired', () {
    test('false when there is no session', () {
      expect(isCompanySetupRequired(null), isFalse);
    });

    test('true when displayName is empty', () {
      final session = _sessionWith(
        _company(permissions: '', name: '', displayName: ''),
      );
      expect(isCompanySetupRequired(session), isTrue);
    });

    test('true when displayName is the server seed "Untitled Company"', () {
      final session = _sessionWith(
        _company(permissions: '', name: '', displayName: 'Untitled Company'),
      );
      expect(isCompanySetupRequired(session), isTrue);
    });

    test('true when displayName resolves to bare "Untitled" fallback '
        '(every name source empty)', () {
      // `companyDisplayName` returns "Untitled" only when settings.name,
      // displayName, and the row\'s name are all empty.
      final session = _sessionWith(
        _company(permissions: '', name: '', displayName: 'Untitled'),
      );
      expect(isCompanySetupRequired(session), isTrue);
    });

    test('false when user genuinely named the company "Untitled" '
        '(row name column is non-empty)', () {
      // Real-life edge case: the resolver still surfaces the user-typed
      // value via displayName, but the row\'s name column is also
      // "Untitled" — that\'s our signal that the user set this, not a
      // fallback.
      final session = _sessionWith(
        _company(permissions: '', name: 'Untitled', displayName: 'Untitled'),
      );
      expect(isCompanySetupRequired(session), isFalse);
    });

    test('false when company has a real name', () {
      final session = _sessionWith(
        _company(permissions: '', name: 'Acme', displayName: 'Acme Co'),
      );
      expect(isCompanySetupRequired(session), isFalse);
    });
  });

  group('entityRecordPath (row-click target)', () {
    test('row-click always opens the view/detail screen', () {
      expect(
        entityRecordPath(
          routePath: '/invoices',
          id: 'inv1',
          hasDetailScreen: true,
        ),
        '/invoices/inv1',
      );
    });

    test('no detail screen falls back to edit (never a dead route)', () {
      expect(
        entityRecordPath(
          routePath: '/settings/company_gateways',
          id: 'g1',
          hasDetailScreen: false,
        ),
        '/settings/company_gateways/g1/edit',
      );
    });

    test('settings routePath is preserved verbatim', () {
      expect(
        entityRecordPath(
          routePath: '/settings/expense_categories',
          id: 'c1',
          hasDetailScreen: true,
        ),
        '/settings/expense_categories/c1',
      );
    });
  });

  group('disabledEntityRoots', () {
    test('all modules on → nothing disabled', () {
      const allOn = 4096 | 8; // invoices + tasks
      expect(disabledEntityRoots(_registry(), allOn), isEmpty);
    });

    test('disabled module yields its root; client stays always-on', () {
      const tasksOnly = 8;
      final roots = disabledEntityRoots(_registry(), tasksOnly).toSet();
      // invoices off → /invoices disabled; tasks on, client always-on.
      expect(roots, contains('/invoices'));
      expect(roots, isNot(contains('/tasks')));
      expect(roots, isNot(contains('/clients')));
    });

    test('settings-only (SidebarSection.none) entities never appear', () {
      // credits=2 only: non-zero, invoices+tasks both off.
      final roots = disabledEntityRoots(_registry(), 2).toSet();
      expect(roots, isNot(contains('/settings/company_gateways')));
      expect(roots, containsAll(['/invoices', '/tasks']));
    });

    test('all-off mask (0) disables every module root', () {
      // 0 = every module switched off; all module-gated roots are disabled
      // while always-on roots (clients) stay reachable.
      final roots = disabledEntityRoots(_registry(), 0).toSet();
      expect(roots, contains('/invoices'));
      expect(roots, contains('/tasks'));
      expect(roots, isNot(contains('/clients')));
    });
  });

  group('settingsIndexRedirect', () {
    // The redirect threshold splits the *shell* width (window minus the global
    // InSidebar: 232 px expanded / 64 px collapsed) against
    // Breakpoints.settingsTwoPane (880) — the same gate SettingsShell uses to
    // show its menu sidebar. So with the sidebar expanded it fires at
    // screenWidth ≥ 1112, collapsed at ≥ 944.

    test('redirects to Company Details once the shell can host two panes', () {
      // 1200 − 232 = 968 ≥ 880.
      expect(
        settingsIndexRedirect(screenWidth: 1200, sidebarCollapsed: false),
        '/settings/company_details',
      );
    });

    test('stays on the /settings list while the menu sidebar is hidden', () {
      // 1000 − 232 = 768 < 880. This is the regression band: the old
      // `Breakpoints.wide` (600) threshold redirected here, stranding the
      // user on Company Details with no menu list.
      expect(
        settingsIndexRedirect(screenWidth: 1000, sidebarCollapsed: false),
        isNull,
      );
    });

    test('expanded-sidebar boundary: redirects at exactly shell width 880', () {
      // 1112 − 232 = 880 (redirect); 1111 − 232 = 879 (stay).
      expect(
        settingsIndexRedirect(screenWidth: 1112, sidebarCollapsed: false),
        '/settings/company_details',
      );
      expect(
        settingsIndexRedirect(screenWidth: 1111, sidebarCollapsed: false),
        isNull,
      );
    });

    test('collapsed sidebar frees width, so it redirects sooner', () {
      // 944 − 64 = 880 (redirect); 943 − 64 = 879 (stay). At 1000 a collapsed
      // sidebar redirects (936 ≥ 880) where an expanded one does not.
      expect(
        settingsIndexRedirect(screenWidth: 944, sidebarCollapsed: true),
        '/settings/company_details',
      );
      expect(
        settingsIndexRedirect(screenWidth: 943, sidebarCollapsed: true),
        isNull,
      );
      expect(
        settingsIndexRedirect(screenWidth: 1000, sidebarCollapsed: true),
        '/settings/company_details',
      );
    });

    test('narrow (mobile) widths never redirect', () {
      expect(
        settingsIndexRedirect(screenWidth: 500, sidebarCollapsed: false),
        isNull,
      );
    });
  });
}
