import 'package:admin/data/models/api/company_api_model.dart';
import 'package:admin/data/models/api/json_coercion.dart';
import 'package:admin/data/models/api/login_response_api_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('jsonScalarToString', () {
    test('passes strings through unchanged', () {
      expect(jsonScalarToString('abc'), 'abc');
      expect(jsonScalarToString(''), '');
    });

    test('coerces ints to their string form (the reported crash)', () {
      expect(jsonScalarToString(1), '1');
      expect(jsonScalarToString(0), '0');
      expect(jsonScalarToString(42), '42');
      expect(jsonScalarToString(-7), '-7');
    });

    test('renders whole doubles without a trailing ".0"', () {
      expect(jsonScalarToString(1.0), '1');
      expect(jsonScalarToString(2.0), '2');
    });

    test('keeps the fractional part of non-whole doubles', () {
      expect(jsonScalarToString(1.5), '1.5');
      expect(jsonScalarToString(0.25), '0.25');
    });

    test('returns null for null so freezed @Default still applies', () {
      expect(jsonScalarToString(null), isNull);
    });

    test('coerces bool defensively', () {
      expect(jsonScalarToString(true), 'true');
    });
  });

  group('jsonScalarToBool', () {
    test('reads true however the server casts it', () {
      expect(jsonScalarToBool(true), isTrue);
      expect(jsonScalarToBool(1), isTrue);
      expect(jsonScalarToBool('1'), isTrue);
      expect(jsonScalarToBool('true'), isTrue);
      expect(jsonScalarToBool(' TRUE '), isTrue);
    });

    test('reads false, absence and junk as false', () {
      expect(jsonScalarToBool(false), isFalse);
      expect(jsonScalarToBool(0), isFalse);
      expect(jsonScalarToBool('0'), isFalse);
      expect(jsonScalarToBool(''), isFalse);
      expect(jsonScalarToBool(null), isFalse);
      expect(jsonScalarToBool(const <String, dynamic>{}), isFalse);
    });
  });

  group('company enable_modules (DocuNinja)', () {
    test('parses on CompanyApi and the login envelope, never sent back', () {
      final api = CompanyApi.fromJson({'id': 'c1', 'enable_modules': 1});
      expect(api.enableModules, isTrue);
      expect(api.toJson().containsKey('enable_modules'), isFalse);
      expect(CompanyApi.fromJson({'id': 'c1'}).enableModules, isFalse);

      expect(
        CompanyEnvelopeApi.fromJson({
          'id': 'c1',
          'enable_modules': true,
        }).enableModules,
        isTrue,
      );
      // The envelope is persisted through toJson; the flag must survive it.
      final envelope = CompanyEnvelopeApi.fromJson({
        'id': 'c1',
        'enable_modules': true,
      });
      expect(
        CompanyEnvelopeApi.fromJson(envelope.toJson()).enableModules,
        isTrue,
      );
    });

    test('docuninja_num_users rides the account envelope round trip', () {
      final account = AccountEnvelopeApi.fromJson({
        'id': 'a1',
        'docuninja_num_users': 3,
      });
      expect(account.docuninjaNumUsers, 3);
      expect(account.toJson()['docuninja_num_users'], 3);
    });
  });

  group('tolerantList', () {
    Map<String, dynamic> asMap(Object? e) => e as Map<String, dynamic>;
    int parseV(Map<String, dynamic> m) => m['v'] as int;

    test('parses every element when all are valid', () {
      final result = tolerantList<int>(
        const [
          {'v': 1},
          {'v': 2},
          {'v': 3},
        ],
        parseV,
        label: 'thing',
      );
      expect(result, [1, 2, 3]);
    });

    test('drops elements that throw and keeps the rest', () {
      final result = tolerantList<int>(
        const [
          {'v': 1},
          {'oops': true}, // m['v'] is null → `null as int` throws → dropped
          {'v': 3},
        ],
        parseV,
        label: 'thing',
      );
      expect(result, [1, 3]);
    });

    test('drops a non-map element instead of failing the whole list', () {
      final result = tolerantList<Map<String, dynamic>>(
        const [
          {'id': 'a'},
          'not an object', // `as Map` throws → dropped
          {'id': 'b'},
        ],
        asMap,
        label: 'thing',
      );
      expect(result.map((e) => e['id']), ['a', 'b']);
    });

    test('returns an empty list when raw is not a JSON array', () {
      expect(tolerantList<int>(null, parseV, label: 'thing'), isEmpty);
      expect(tolerantList<int>('nope', parseV, label: 'thing'), isEmpty);
      expect(
        tolerantList<int>(const {'v': 1}, parseV, label: 'thing'),
        isEmpty,
      );
    });
  });
}
