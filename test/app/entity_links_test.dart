import 'package:flutter/material.dart' show Icons, SizedBox, ValueNotifier;
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/entity_links.dart';
import 'package:admin/app/entity_modules.dart';
import 'package:admin/app/router.dart' show buildRouter;
import 'package:admin/domain/entity_registry.dart';
import 'package:admin/domain/entity_type.dart';

/// The link grammar for shared record deep links (invoiceninja/flutter#96).
///
/// Every case here is a silent failure if it regresses: a link that parses to
/// the wrong route opens the wrong record, and one that reaches `router.go`
/// unvalidated replaces the whole app with go_router's route-error screen
/// (outside the shell, sidebar gone).

EntityHandlers _handler(
  EntityType type,
  String wire,
  String routePath, {
  bool disabled = false,
  bool hasDetail = true,
}) => EntityHandlers(
  type: type,
  wireName: wire,
  apiPath: '/api/v1/$wire',
  routePath: routePath,
  icon: Icons.circle,
  dispatcher: DisabledEntityDispatcher(type),
  disabled: disabled,
  detailBuilder: hasDetail ? (_, _) => const SizedBox.shrink() : null,
);

/// Mirrors the real registry's awkward shapes: an underscored root, a
/// settings-nested root, a root that NESTS inside another root, an entity with
/// no detail screen, and a disabled entity.
EntityRegistry _registry() => EntityRegistry({
  EntityType.client: _handler(EntityType.client, 'client', '/clients'),
  EntityType.purchaseOrder: _handler(
    EntityType.purchaseOrder,
    'purchase_order',
    '/purchase_orders',
  ),
  EntityType.bankAccount: _handler(
    EntityType.bankAccount,
    'bank_account',
    '/settings/bank_accounts',
  ),
  EntityType.transactionRule: _handler(
    EntityType.transactionRule,
    'transaction_rule',
    '/settings/bank_accounts/transaction_rules',
    hasDetail: false,
  ),
  EntityType.taxRate: _handler(
    EntityType.taxRate,
    'tax_rate',
    '/settings/tax_rates',
    disabled: true,
  ),
});

EntityHandlers _of(EntityType type) => _registry()[type]!;

void main() {
  group('buildEntityDeepLink', () {
    test('builds the canonical form for an entity with a detail screen', () {
      expect(
        buildEntityDeepLink(
          handlers: _of(EntityType.client),
          entityId: 'Wpmbk5ezJn',
          companyId: 'Xrtq1oa8Aq',
        ),
        'invoiceninja://app/clients/Wpmbk5ezJn?company=Xrtq1oa8Aq',
      );
    });

    test('falls back to /edit when the entity has no detail screen — the '
        'same rule row-tap uses, so the link opens what tapping opens', () {
      expect(
        buildEntityDeepLink(
          handlers: _of(EntityType.transactionRule),
          entityId: 'Kq7',
          companyId: 'co1',
        ),
        'invoiceninja://app/settings/bank_accounts/transaction_rules/Kq7/edit'
        '?company=co1',
      );
    });

    test(
      'a settings-nested entity WITH a detail screen keeps the plain form',
      () {
        expect(
          buildEntityDeepLink(
            handlers: _of(EntityType.bankAccount),
            entityId: 'Kq7',
            companyId: 'co1',
          ),
          'invoiceninja://app/settings/bank_accounts/Kq7?company=co1',
        );
      },
    );

    test('null for an unlinkable record', () {
      final client = _of(EntityType.client);
      expect(
        buildEntityDeepLink(handlers: null, entityId: 'a', companyId: 'c'),
        isNull,
      );
      expect(
        buildEntityDeepLink(
          handlers: _of(EntityType.taxRate),
          entityId: 'a',
          companyId: 'c',
        ),
        isNull,
        reason: 'disabled entity',
      );
      expect(
        buildEntityDeepLink(handlers: client, entityId: '', companyId: 'c'),
        isNull,
      );
      expect(
        buildEntityDeepLink(
          handlers: client,
          entityId: 'tmp_abc',
          companyId: 'c',
        ),
        isNull,
        reason: 'a local-only offline-create id resolves to nothing elsewhere',
      );
      expect(
        buildEntityDeepLink(handlers: client, entityId: 'a', companyId: ''),
        isNull,
        reason: 'no active company to scope the link to',
      );
    });
  });

  group('parseAppDeepLink', () {
    final registry = _registry();
    DeepLinkTarget? parse(String s) => parseAppDeepLink(Uri.parse(s), registry);

    test('round-trips what buildEntityDeepLink produced', () {
      final link = buildEntityDeepLink(
        handlers: _of(EntityType.client),
        entityId: 'Wpmbk5ezJn',
        companyId: 'Xrtq1oa8Aq',
      )!;
      final target = parse(link);
      expect(target?.path, '/clients/Wpmbk5ezJn');
      expect(target?.companyId, 'Xrtq1oa8Aq');
    });

    test('preserves a case-sensitive hashid — the reason the route lives in '
        'the path and not the host, which Uri lower-cases', () {
      expect(
        parse('invoiceninja://app/clients/AbCdEf')?.path,
        '/clients/AbCdEf',
      );
    });

    test('parses an underscored root', () {
      expect(
        parse('invoiceninja://app/purchase_orders/Ab3xY')?.path,
        '/purchase_orders/Ab3xY',
      );
    });

    test('a list root with no id is a valid target', () {
      expect(parse('invoiceninja://app/clients')?.path, '/clients');
    });

    test('accepts the /edit suffix', () {
      expect(
        parse('invoiceninja://app/clients/abc/edit')?.path,
        '/clients/abc/edit',
      );
    });

    test('nested roots resolve longest-first, in both directions', () {
      expect(
        parse(
          'invoiceninja://app/settings/bank_accounts/transaction_rules/r1',
        )?.path,
        '/settings/bank_accounts/transaction_rules/r1',
        reason: 'must not be read as bank account id "transaction_rules"',
      );
      expect(
        parse('invoiceninja://app/settings/bank_accounts/b1')?.path,
        '/settings/bank_accounts/b1',
      );
    });

    test('drops the whole query string, not just company — a survivor would '
        'be persisted into nav_state and replayed every cold start', () {
      final target = parse(
        'invoiceninja://app/clients/abc?company=co1&foo=1&view=full',
      );
      expect(target?.path, '/clients/abc');
      expect(target?.companyId, 'co1');
    });

    test('normalises a trailing slash', () {
      expect(parse('invoiceninja://app/clients/abc/')?.path, '/clients/abc');
    });

    test('company is null when the link carries none', () {
      expect(parse('invoiceninja://app/clients/abc')?.companyId, isNull);
      expect(
        parse('invoiceninja://app/clients/abc?company=')?.companyId,
        isNull,
      );
    });

    test('accepts the empty-authority form some senders normalise to', () {
      expect(parse('invoiceninja:/app/clients/abc')?.path, '/clients/abc');
    });

    test(
      'accepts an https form, so universal links later need no Dart change',
      () {
        expect(
          parse('https://app.invoicing.co/app/clients/abc?company=co1')?.path,
          '/clients/abc',
        );
        expect(
          parse('https://example.test/admin/app/clients/abc')?.path,
          '/clients/abc',
          reason: 'deployed under a sub-path',
        );
      },
    );

    group('rejects', () {
      test('a host that is not the constant app host', () {
        // The rejected alternative design: host == first route segment. Pinned
        // so nobody reintroduces it — Uri lower-cases the host.
        expect(parse('invoiceninja://clients/abc'), isNull);
        expect(parse('invoiceninja://Clients/abc'), isNull);
      });

      test('an unknown root', () {
        expect(parse('invoiceninja://app/widgets/abc'), isNull);
      });

      test('a disabled entity', () {
        expect(parse('invoiceninja://app/settings/tax_rates/t1'), isNull);
      });

      test('the create route', () {
        expect(parse('invoiceninja://app/clients/new'), isNull);
      });

      test('a tmp_ id', () {
        expect(parse('invoiceninja://app/clients/tmp_abc'), isNull);
      });

      test('an id with illegal characters', () {
        expect(parse('invoiceninja://app/clients/a%20b'), isNull);
        expect(parse('invoiceninja://app/clients/a.b'), isNull);
      });

      test('a path traversal', () {
        expect(parse('invoiceninja://app/clients/../../secrets'), isNull);
      });

      test('too many segments, or an unknown trailing segment', () {
        expect(parse('invoiceninja://app/clients/abc/edit/more'), isNull);
        expect(parse('invoiceninja://app/clients/abc/pdf'), isNull);
      });

      test('a bare scheme, and an unrelated scheme', () {
        expect(parse('invoiceninja://app'), isNull);
        expect(parse('invoiceninja://app/'), isNull);
        expect(parse('mailto:someone@example.test'), isNull);
      });

      test('the calendar OAuth return — that one is not a record link', () {
        expect(
          parse('invoiceninja://calendar_connection/complete?handoff=x'),
          isNull,
        );
      });
    });
  });

  group('parseCalendarCompleteLink', () {
    test('keeps its query string — the handoff token is single-use', () {
      expect(
        parseCalendarCompleteLink(
          Uri.parse('invoiceninja://calendar_connection/complete?handoff=abc'),
        ),
        '/calendar_connection/complete?handoff=abc',
      );
    });

    test('tolerates a trailing slash and a universal-link form', () {
      expect(
        parseCalendarCompleteLink(
          Uri.parse('invoiceninja://calendar_connection/complete/'),
        ),
        '/calendar_connection/complete',
      );
      expect(
        parseCalendarCompleteLink(
          Uri.parse('https://example.test/calendar_connection/complete'),
        ),
        '/calendar_connection/complete',
      );
    });

    test('null for a record link', () {
      expect(
        parseCalendarCompleteLink(Uri.parse('invoiceninja://app/clients/abc')),
        isNull,
      );
    });
  });

  // ── The invariant the hand-built fake registry above cannot check ────────
  //
  // Everything else here runs against five made-up handlers. These two run
  // against the REAL module specs and the REAL route table, because the
  // failure they guard is silent: a future entity whose `routePath` the
  // grammar can't round-trip ships a dead Copy Link, and one whose routes
  // don't cover a shape the parser emits sends `router.go` into go_router's
  // top-level `errorBuilder` — which replaces the whole app with the route
  // error screen, outside the shell, sidebar gone.
  group('against the real registry', () {
    // The module specs are NOT the whole registry. `Services.build` registers
    // `user` and `company` directly — they exist for sync and have no list /
    // detail UI — and both carry a `routePath` that is a settings screen
    // rather than a record route. Leaving them out of this fixture is what
    // let a link to `/settings/account` (which is not a route at all) reach
    // `router.go` and replace the whole app with the route-error screen: the
    // "every path the parser can emit matches a real route" test below was
    // structurally unable to see them.
    //
    // Mirrors `lib/app/services.dart` — keep the routePaths in step.
    EntityHandlers nonSpecHandlers(EntityType type, String routePath) =>
        EntityHandlers(
          type: type,
          wireName: type.name,
          apiPath: '/api/v1/${type.name}s',
          routePath: routePath,
          icon: Icons.business,
          dispatcher: DisabledEntityDispatcher(type),
        );

    EntityRegistry realRegistry() => EntityRegistry({
      for (final m in [...kWiredEntityModules, ...kDisabledEntityModules])
        m.type: m.toHandlers(DisabledEntityDispatcher(m.type)),
      EntityType.company: nonSpecHandlers(
        EntityType.company,
        '/settings/company_details',
      ),
      EntityType.user: nonSpecHandlers(EntityType.user, '/settings/account'),
    }, branchOrder: kBranchOrder);

    test('every wired entity round-trips build -> parse unchanged', () {
      final registry = realRegistry();
      const id = 'AbC_123-x'; // every character class a server hashid can use
      for (final module in kWiredEntityModules) {
        final handlers = registry[module.type]!;
        final link = buildEntityDeepLink(
          handlers: handlers,
          entityId: id,
          companyId: 'co1',
        );
        expect(link, isNotNull, reason: '${module.type} produced no link');
        final target = parseAppDeepLink(Uri.parse(link!), registry);
        expect(
          target?.path,
          entityRecordPath(
            routePath: handlers.routePath,
            id: id,
            hasDetailScreen: handlers.detailBuilder != null,
          ),
          reason:
              '${module.type} (${handlers.routePath}) does not survive its own '
              'link grammar — a route root has to stay path-safe',
        );
        expect(target?.companyId, 'co1');
      }
    });

    test('every path the parser can emit matches a real route', () {
      final registry = realRegistry();
      final router = buildRouter(
        isAuthenticated: () => true,
        postLoginRoute: () => '/clients',
        refreshListenable: ValueNotifier<int>(0),
        registry: registry,
      );
      addTearDown(router.dispose);
      // Drive this from the REGISTRY, not from `kWiredEntityModules`. The
      // module specs are a subset: `user` and `company` are registered
      // directly in `Services.build`, and those two are exactly the ones that
      // carry a non-record `routePath`. Iterating the specs made this test
      // structurally blind to the only entries that could fail it.
      //
      // The filter below is deliberately the BROAD one the parser used to
      // use, so the assertion is "for every route root the parser might be
      // offered, either it refuses the link or the path resolves" — which is
      // the actual invariant ("an unvalidated path must never reach `go()`"),
      // rather than a restatement of the parser's own filter.
      final roots = registry.all
          .where((h) => !h.disabled && h.routePath.isNotEmpty)
          .toList();
      expect(
        roots.map((h) => h.type),
        containsAll(<EntityType>[EntityType.user, EntityType.company]),
        reason:
            'fixture regression: the non-spec registrations are what this '
            'test exists to cover',
      );
      var checked = 0;
      for (final handlers in roots) {
        final root = handlers.routePath;
        for (final path in [root, '$root/AbC_123-x', '$root/AbC_123-x/edit']) {
          final link = Uri.parse('$kAppLinkScheme://$kAppLinkHost$path');
          if (parseAppDeepLink(link, registry) == null) continue;
          checked++;
          final match = router.configuration.findMatch(Uri.parse(path));
          expect(
            match.isError,
            isFalse,
            reason:
                '$path parses as a deep link but matches no route — following '
                'one would blank the app with the route-error screen',
          );
        }
      }
      // Without this the loop above can go completely silent: `continue` on a
      // refused path means a parser that started rejecting broadly would
      // execute zero assertions and still report green.
      expect(
        checked,
        greaterThanOrEqualTo(3 * kWiredEntityModules.length),
        reason:
            'the loop asserted almost nothing — is the parser refusing '
            'paths it should accept?',
      );
    });

    test('the fixture still mirrors the real non-spec registrations', () {
      // `nonSpecHandlers` hand-copies two `routePath`s out of `Services.build`,
      // and nothing makes that copy follow the original. If one is repointed
      // (`user` in particular has a real record route at `/settings/users/:id`
      // that its registry entry does not name) the tests above would keep
      // guarding a shape the app no longer has.
      final registry = realRegistry();
      expect(registry[EntityType.user]!.routePath, '/settings/account');
      expect(
        registry[EntityType.company]!.routePath,
        '/settings/company_details',
      );
      // Both must also be types the link layer refuses — the property the
      // fixture exists to exercise.
      for (final type in [EntityType.user, EntityType.company]) {
        expect(
          entityTypeHasRecordRoute(type),
          isFalse,
          reason: '$type must stay in kNonRecordRouteEntityTypes',
        );
      }
    });

    test('the refused settings paths really do match no route', () {
      // The premise behind the refusal, pinned rather than assumed: these are
      // the exact paths the parser used to emit and hand to `go()`. If a real
      // route is ever added at one of them this goes red, which is the moment
      // to re-examine `kNonRecordRouteEntityTypes` rather than to delete the
      // expectation.
      final router = buildRouter(
        isAuthenticated: () => true,
        postLoginRoute: () => '/clients',
        refreshListenable: ValueNotifier<int>(0),
        registry: realRegistry(),
      );
      addTearDown(router.dispose);
      for (final path in [
        '/settings/account',
        '/settings/account/AbC_123-x',
        '/settings/account/AbC_123-x/edit',
        '/settings/company_details/AbC_123-x',
        '/settings/company_details/AbC_123-x/edit',
      ]) {
        expect(
          router.configuration.findMatch(Uri.parse(path)).isError,
          isTrue,
          reason: '$path was expected to be a dead route',
        );
      }
      // …while the bare company-details tab host is a real screen, which is
      // why the type — not the path — is what has to be refused.
      expect(
        router.configuration
            .findMatch(Uri.parse('/settings/company_details'))
            .isError,
        isFalse,
      );
    });

    test('build and parse both refuse a settings-hosted entity', () {
      // `user` -> `/settings/account` is not a route at all; `company` ->
      // `/settings/company_details` has only tab slugs beneath it. Reaching
      // `go()` with either replaces the whole app with the route-error
      // screen, outside the shell. Both directions are asserted because an
      // asymmetry is just as bad: Copy Link reporting success for a URL the
      // app itself refuses to open.
      final registry = realRegistry();
      for (final type in [EntityType.user, EntityType.company]) {
        final handlers = registry[type]!;
        expect(
          buildEntityDeepLink(
            handlers: handlers,
            entityId: 'AbC_123-x',
            companyId: 'co1',
          ),
          isNull,
          reason: '$type has no record route, so no link to one can exist',
        );
        final root = handlers.routePath;
        for (final path in [root, '$root/AbC_123-x', '$root/AbC_123-x/edit']) {
          expect(
            parseAppDeepLink(
              Uri.parse('$kAppLinkScheme://$kAppLinkHost$path'),
              registry,
            ),
            isNull,
            reason: '$path must not parse as a record link',
          );
        }
      }
    });
  });
}
