import 'dart:convert';

import 'package:admin/data/models/api/client_api_model.dart';
import 'package:admin/data/models/api/gateway_token_api_model.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/contact.dart';
import 'package:admin/data/models/domain/gateway_token.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Client.fromApi', () {
    test('parses money as Decimal whether server sends string or number', () {
      final fromString = ClientApi.fromJson({
        'id': 'abc',
        'name': 'Acme',
        'balance': '123.45',
        'paid_to_date': '7.89',
      });
      final fromNumber = ClientApi.fromJson({
        'id': 'abc',
        'name': 'Acme',
        'balance': 123.45,
        'paid_to_date': 7.89,
      });

      final a = Client.fromApi(fromString);
      final b = Client.fromApi(fromNumber);

      expect(a.balance, Decimal.parse('123.45'));
      expect(a.paidToDate, Decimal.parse('7.89'));
      expect(b.balance, Decimal.parse('123.45'));
      expect(b.paidToDate, Decimal.parse('7.89'));
    });

    test('treats missing money as zero, never null', () {
      final c = Client.fromApi(ClientApi.fromJson({'id': 'a', 'name': 'X'}));
      expect(c.balance, Decimal.zero);
      expect(c.paidToDate, Decimal.zero);
      expect(c.creditBalance, Decimal.zero);
    });

    test('embeds contacts and surfaces the primary one', () {
      final api = ClientApi.fromJson({
        'id': 'a',
        'name': 'Acme',
        'contacts': [
          {
            'id': 'c1',
            'first_name': 'Jane',
            'last_name': 'Doe',
            'email': 'jane@acme.test',
            'is_primary': true,
          },
          {
            'id': 'c2',
            'first_name': 'John',
            'last_name': 'Roe',
            'is_primary': false,
          },
        ],
      });

      final c = Client.fromApi(api);
      expect(c.contacts, hasLength(2));
      expect(c.contacts.first.firstName, 'Jane');
      expect(c.contacts.first.isPrimary, isTrue);
      expect(c.contacts[1].firstName, 'John');
    });

    test('maps contact is_locked (bounce/unsubscribe) and never writes it '
        'back so a normal save cannot clear server bounce state', () {
      final api = ClientApi.fromJson({
        'id': 'a',
        'name': 'Acme',
        'contacts': [
          {'id': 'c1', 'email': 'a@x.test', 'is_locked': true},
          {'id': 'c2', 'email': 'b@x.test'},
        ],
      });

      final c = Client.fromApi(api);
      expect(c.contacts[0].isLocked, isTrue);
      expect(c.contacts[1].isLocked, isFalse, reason: 'defaults false');

      final json = c.toApiJson();
      final contactsJson = (json['contacts'] as List)
          .cast<Map<String, dynamic>>();
      expect(
        contactsJson.every((m) => !m.containsKey('is_locked')),
        isTrue,
        reason: 'is_locked is server-managed; reactivation is the only writer',
      );
    });

    test('round-trips contact cc_only (defaults false, written back)', () {
      final api = ClientApi.fromJson({
        'id': 'a',
        'name': 'Acme',
        'contacts': [
          {'id': 'c1', 'email': 'a@x.test', 'cc_only': true},
          {'id': 'c2', 'email': 'b@x.test'},
        ],
      });

      final c = Client.fromApi(api);
      expect(c.contacts[0].ccOnly, isTrue);
      expect(c.contacts[1].ccOnly, isFalse, reason: 'defaults false');

      final json = c.toApiJson();
      final contactsJson = (json['contacts'] as List)
          .cast<Map<String, dynamic>>();
      expect(contactsJson[0]['cc_only'], isTrue);
      expect(contactsJson[1]['cc_only'], isFalse);
    });

    test('blanks the server-minted portal placeholder email and carries it '
        'back out untouched (invoiceninja/flutter#116)', () {
      const minted = 'dq9GHaI6Dncm0Zd@example.com';
      final api = ClientApi.fromJson({
        'id': 'a',
        'name': 'Acme',
        'contacts': [
          {'id': 'c1', 'first_name': 'Jimmy', 'email': minted},
          {'id': 'c2', 'first_name': 'Real', 'email': 'real@acme.test'},
        ],
      });

      final c = Client.fromApi(api);
      expect(c.contacts[0].email, isEmpty, reason: 'never shown to the user');
      expect(c.contacts[0].portalPlaceholderEmail, minted);
      expect(c.contacts[1].email, 'real@acme.test');
      expect(
        c.contacts[1].portalPlaceholderEmail,
        isEmpty,
        reason: 'a real address carries nothing',
      );

      final contactsJson = (c.toApiJson()['contacts'] as List)
          .cast<Map<String, dynamic>>();
      expect(
        contactsJson[0]['email'],
        minted,
        reason: 'an unrelated save must not clear the server value',
      );
      expect(contactsJson[1]['email'], 'real@acme.test');
    });

    test('a CLONED contact drops the placeholder instead of inheriting it', () {
      // `ClientAction.clone` copies each contact with `id: ''` and keeps every
      // other field. Without the `id.isNotEmpty` guard in `toApiJson` the clone
      // would POST a brand-new contact carrying the SOURCE contact's minted
      // address — and the form shows the email field blank, so nobody could see
      // or clear it.
      const minted = 'dq9GHaI6Dncm0Zd@example.com';
      final c = Client.fromApi(
        ClientApi.fromJson({
          'id': 'a',
          'name': 'Acme',
          'contacts': [
            {'id': 'c1', 'first_name': 'Jimmy', 'email': minted},
          ],
        }),
      );
      expect(
        c.contacts[0].toApiJson()['email'],
        minted,
        reason: 'the original',
      );

      final cloned = c.contacts[0].copyWith(id: '');
      expect(
        cloned.portalPlaceholderEmail,
        minted,
        reason: 'copyWith carries it — the guard is in toApiJson, not here',
      );
      expect(cloned.toApiJson()['email'], isEmpty);
    });

    test('a user clearing a REAL email still transmits as empty', () {
      final api = ClientApi.fromJson({
        'id': 'a',
        'name': 'Acme',
        'contacts': [
          {'id': 'c1', 'email': 'real@acme.test'},
        ],
      });
      final c = Client.fromApi(api);
      final cleared = c.copyWith(
        contacts: [c.contacts.first.copyWith(email: '')],
      );

      final contactsJson = (cleared.toApiJson()['contacts'] as List)
          .cast<Map<String, dynamic>>();
      expect(contactsJson[0]['email'], isEmpty);
    });

    test('the placeholder survives the local-save payload round-trip', () {
      // `_domainToCompanion` stores `toApiJson(preserveTempId: true)` in the
      // Drift `payload` column and `_fromRow` re-reads the domain from it. If
      // `toApiJson` omitted the key instead of re-emitting the raw value, one
      // local save would round-trip the carried value to '' and the *second*
      // save would clear the server's address after all.
      const minted = 'dq9GHaI6Dncm0Zd@example.com';
      var c = Client.fromApi(
        ClientApi.fromJson({
          'id': 'a',
          'name': 'Acme',
          'contacts': [
            {'id': 'c1', 'first_name': 'Jimmy', 'email': minted},
          ],
        }),
      );

      for (var save = 0; save < 2; save++) {
        final stored = jsonDecode(
          jsonEncode(c.toApiJson(preserveTempId: true)),
        );
        c = Client.fromApi(ClientApi.fromJson(stored as Map<String, dynamic>));
        expect(c.contacts[0].email, isEmpty, reason: 'save ${save + 1}');
        expect(c.contacts[0].portalPlaceholderEmail, minted);
      }
      final contactsJson = (c.toApiJson()['contacts'] as List)
          .cast<Map<String, dynamic>>();
      expect(contactsJson[0]['email'], minted);
    });

    test('a display_name the server derived from a placeholder falls back to '
        'the client name', () {
      // `ClientPresenter::name()` falls back to the first contact's email for a
      // nameless client, so `display_name` on the wire can be the junk address.
      final c = Client.fromApi(
        ClientApi.fromJson({
          'id': 'a',
          'name': '',
          'display_name': 'dq9GHaI6Dncm0Zd@example.com',
          'contacts': [
            {'id': 'c1', 'email': 'dq9GHaI6Dncm0Zd@example.com'},
          ],
        }),
      );
      expect(c.displayName, isEmpty, reason: 'list tile renders (no name)');

      final real = Client.fromApi(
        ClientApi.fromJson({'id': 'b', 'name': '', 'display_name': 'Acme Ltd'}),
      );
      expect(real.displayName, 'Acme Ltd');
    });

    test(
      'round-trips client-level custom_value1..4 (read + written back to wire)',
      () {
        // Regression: toApiJson previously omitted the client-level
        // custom_value1..4 keys, so edits were silently dropped on save (and
        // the local optimistic copy blanked them too).
        final api = ClientApi.fromJson({
          'id': 'a',
          'name': 'Acme',
          'custom_value1': 'one',
          'custom_value2': 'two',
          'custom_value3': 'three',
          'custom_value4': 'four',
        });

        final c = Client.fromApi(api);
        expect(c.customValue1, 'one');
        expect(c.customValue4, 'four');

        final json = c.toApiJson();
        expect(json['custom_value1'], 'one');
        expect(json['custom_value2'], 'two');
        expect(json['custom_value3'], 'three');
        expect(json['custom_value4'], 'four');
      },
    );

    test(
      'round-trips contact custom_value1..4 (defaults empty, written back)',
      () {
        final api = ClientApi.fromJson({
          'id': 'a',
          'name': 'Acme',
          'contacts': [
            {
              'id': 'c1',
              'email': 'a@x.test',
              'custom_value1': 'one',
              'custom_value2': 'two',
              'custom_value3': 'three',
              'custom_value4': 'four',
            },
            {'id': 'c2', 'email': 'b@x.test'},
          ],
        });

        final c = Client.fromApi(api);
        expect(c.contacts[0].customValue1, 'one');
        expect(c.contacts[0].customValue4, 'four');
        expect(c.contacts[1].customValue1, isEmpty, reason: 'defaults empty');

        final json = c.toApiJson();
        final contactsJson = (json['contacts'] as List)
            .cast<Map<String, dynamic>>();
        expect(contactsJson[0]['custom_value1'], 'one');
        expect(contactsJson[0]['custom_value4'], 'four');
        expect(contactsJson[1]['custom_value1'], isEmpty);
      },
    );

    test('embeds locations read-side; toApiJson omits them (written via '
        'the standalone /api/v1/locations resource)', () {
      final api = ClientApi.fromJson({
        'id': 'a',
        'name': 'Acme',
        'locations': [
          {
            'id': 'L1',
            'client_id': 'a',
            'name': 'HQ',
            'address1': '1 Main St',
            'city': 'Springfield',
            'country_id': '840',
            'is_shipping_location': true,
          },
          {
            'id': 'L2',
            'client_id': 'a',
            'name': 'Warehouse',
            'is_shipping_location': false,
          },
        ],
      });

      final c = Client.fromApi(api);
      expect(c.locations, hasLength(2));
      expect(c.locations.first.name, 'HQ');
      expect(c.locations.first.address1, '1 Main St');
      expect(c.locations.first.countryId, '840');
      expect(c.locations.first.isShippingLocation, isTrue);
      expect(c.locations[1].name, 'Warehouse');
      expect(c.locations[1].isShippingLocation, isFalse);
      // Locations are NOT part of the client save payload (React parity:
      // they're written via POST/PUT/DELETE /api/v1/locations).
      expect(c.toApiJson().containsKey('locations'), isFalse);
    });

    test('toApiJson round-trips money as fixed-precision strings', () {
      final c = Client.fromApi(
        ClientApi.fromJson({'id': 'a', 'name': 'Acme', 'balance': '99.99'}),
      );
      final json = c.toApiJson();
      expect(json['balance'], '99.99');
      expect(json['id'], 'a');
    });

    test('toApiJson omits tmp ids so the server allocates a real one', () {
      final c = Client.fromApi(
        ClientApi.fromJson({'id': 'tmp_xyz', 'name': 'New'}),
      );
      final json = c.toApiJson();
      expect(json.containsKey('id'), isFalse);
      expect(json['name'], 'New');
    });
  });

  group('Client cascade settings (currency / language / payment_terms)', () {
    test('reads currency_id/language_id/payment_terms from settings, not '
        'top-level (the live API only sends them inside settings)', () {
      // Mirrors the live demo client: a per-client EUR override lives in
      // `settings.currency_id`; there is NO top-level `currency_id`.
      final api = ClientApi.fromJson({
        'id': 'a',
        'name': 'Acme',
        'settings': {
          'currency_id': '3',
          'language_id': '5',
          'payment_terms': '30',
        },
      });

      final c = Client.fromApi(api);
      expect(c.currencyId, '3', reason: 'sourced from settings.currency_id');
      expect(c.languageId, '5');
      expect(c.paymentTerms, '30');
    });

    test('falls back to top-level when settings is absent (resilience)', () {
      final c = Client.fromApi(
        ClientApi.fromJson({'id': 'a', 'name': 'Acme', 'currency_id': '7'}),
      );
      expect(c.currencyId, '7');
    });

    test('inherits (empty) when neither settings nor top-level set it', () {
      final c = Client.fromApi(ClientApi.fromJson({'id': 'a', 'name': 'Acme'}));
      expect(c.currencyId, isEmpty);
      expect(c.languageId, isEmpty);
      expect(c.paymentTerms, isEmpty);
    });

    test('toApiJson folds the three fields INTO settings and never emits '
        'them top-level (server ignores the top-level keys)', () {
      final c = Client.fromApi(
        ClientApi.fromJson({
          'id': 'a',
          'name': 'Acme',
          'settings': {'currency_id': '3'},
        }),
      );
      final json = c.toApiJson();
      expect(json.containsKey('currency_id'), isFalse);
      expect(json.containsKey('language_id'), isFalse);
      expect(json.containsKey('payment_terms'), isFalse);
      expect((json['settings'] as Map)['currency_id'], '3');
    });

    test('full round-trip preserves a per-client currency override', () {
      final api = ClientApi.fromJson({
        'id': 'a',
        'name': 'Acme',
        'settings': {'currency_id': '3', 'enable_client_portal': true},
      });
      // domain → wire → domain again
      final c1 = Client.fromApi(api);
      final wire = c1.toApiJson();
      final c2 = Client.fromApi(ClientApi.fromJson(wire));
      expect(c2.currencyId, '3', reason: 'override survives the round-trip');
      // Pre-existing unrelated settings keys are preserved, not clobbered.
      expect((wire['settings'] as Map)['enable_client_portal'], true);
    });

    test('clearing currency (empty) removes the settings key (= inherit) and '
        'preserves other overrides', () {
      final c = Client.fromApi(
        ClientApi.fromJson({
          'id': 'a',
          'name': 'Acme',
          'settings': {'currency_id': '3', 'enable_client_portal': true},
        }),
      ).copyWith(currencyId: '');
      final json = c.toApiJson();
      final settings = json['settings'] as Map;
      expect(settings.containsKey('currency_id'), isFalse);
      expect(settings['enable_client_portal'], true);
    });

    test('emits no settings key at all when there are zero overrides', () {
      final c = Client.fromApi(ClientApi.fromJson({'id': 'a', 'name': 'Acme'}));
      expect(c.toApiJson().containsKey('settings'), isFalse);
    });
  });

  group('Client newly-mapped fields', () {
    test('round-trips the shipping address (read + write)', () {
      final api = ClientApi.fromJson({
        'id': 'a',
        'name': 'Acme',
        'shipping_address1': '500 Dock Rd',
        'shipping_address2': 'Bay 7',
        'shipping_city': 'Newark',
        'shipping_state': 'NJ',
        'shipping_postal_code': '07101',
        'shipping_country_id': '840',
      });
      final c = Client.fromApi(api);
      expect(c.shippingAddress1, '500 Dock Rd');
      expect(c.shippingCity, 'Newark');
      expect(c.shippingCountryId, '840');

      final json = c.toApiJson();
      expect(json['shipping_address1'], '500 Dock Rd');
      expect(json['shipping_city'], 'Newark');
      expect(json['shipping_country_id'], '840');
    });

    test('maps payment_balance / last_login / user_id (read-only)', () {
      final c = Client.fromApi(
        ClientApi.fromJson({
          'id': 'a',
          'name': 'Acme',
          'payment_balance': '42.50',
          'last_login': 1700000000,
          'user_id': 'VolejRejNm',
          'is_tax_exempt': true,
          'routing_id': '111122',
        }),
      );
      expect(c.paymentBalance, Decimal.parse('42.50'));
      expect(c.lastLogin, isNotNull);
      expect(c.userId, 'VolejRejNm');
      expect(c.isTaxExempt, isTrue);
      expect(c.routingId, '111122');
    });

    test('parses gateway_tokens with meta but never writes them back to the '
        'server wire (read-only relation)', () {
      final api = ClientApi.fromJson({
        'id': 'a',
        'name': 'Acme',
        'gateway_tokens': [
          {
            'id': 'gt1',
            'gateway_type_id': '1',
            'is_default': true,
            'meta': {
              'brand': 'visa',
              'last4': '4242',
              'exp_month': '12',
              'exp_year': '2027',
              'type': 'card',
            },
          },
        ],
      });
      final c = Client.fromApi(api);
      expect(c.gatewayTokens, hasLength(1));
      expect(c.gatewayTokens.first.brand, 'visa');
      expect(c.gatewayTokens.first.last4, '4242');
      expect(c.gatewayTokens.first.isDefault, isTrue);
      // Off the outbound wire — the server manages tokens; we must not echo
      // them on a client save.
      expect(c.toApiJson().containsKey('gateway_tokens'), isFalse);
    });

    test('coerces gateway_token meta values that arrive as numbers', () {
      final c = Client.fromApi(
        ClientApi.fromJson({
          'id': 'a',
          'name': 'Acme',
          'gateway_tokens': [
            {
              'id': 'gt1',
              'meta': {'last4': 1234, 'exp_month': 1, 'exp_year': 2030},
            },
          ],
        }),
      );
      expect(c.gatewayTokens.first.last4, '1234');
      expect(c.gatewayTokens.first.expMonth, '1');
    });

    test('contact maps contact_key / can_sign / last_login and writes back '
        'contact_key + can_sign', () {
      final api = ClientApi.fromJson({
        'id': 'a',
        'name': 'Acme',
        'contacts': [
          {
            'id': 'c1',
            'email': 'a@x.test',
            'contact_key': 'KEY123',
            'can_sign': true,
            'last_login': 1700000000,
          },
        ],
      });
      final c = Client.fromApi(api);
      expect(c.contacts.first.contactKey, 'KEY123');
      expect(c.contacts.first.canSign, isTrue);
      expect(c.contacts.first.lastLogin, isNotNull);

      final contactJson = (c.toApiJson()['contacts'] as List)
          .cast<Map<String, dynamic>>()
          .first;
      expect(contactJson['contact_key'], 'KEY123');
      expect(contactJson['can_sign'], isTrue);
    });

    test('GatewayToken survives the toApiJson → fromApi round-trip (the local '
        'Drift payload inject path in _domainToCompanion)', () {
      const original = GatewayToken(
        id: 'gt1',
        companyGatewayId: 'cg1',
        gatewayTypeId: '1',
        customerReference: 'cus_123',
        isDefault: true,
        brand: 'visa',
        last4: '4242',
        expMonth: '12',
        expYear: '2027',
        cardType: 'card',
      );
      final round = GatewayToken.fromApi(
        GatewayTokenApi.fromJson(original.toApiJson()),
      );
      expect(round.brand, 'visa');
      expect(round.last4, '4242');
      expect(round.expMonth, '12');
      expect(round.expYear, '2027');
      expect(round.cardType, 'card');
      expect(round.isDefault, isTrue);
      expect(round.customerReference, 'cus_123');
      expect(round.companyGatewayId, 'cg1');
    });
  });
}
