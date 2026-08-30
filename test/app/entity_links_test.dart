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
    EntityRegistry realRegistry() => EntityRegistry({
      for (final m in [...kWiredEntityModules, ...kDisabledEntityModules])
        m.type: m.toHandlers(DisabledEntityDispatcher(m.type)),
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
      for (final module in kWiredEntityModules) {
        final root = module.routePath;
        for (final path in [root, '$root/AbC_123-x', '$root/AbC_123-x/edit']) {
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
    });
  });
}
