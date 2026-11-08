import 'package:admin/domain/docuninja/docuninja_signed.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isDocuNinjaSigned', () {
    test('reads dn_completed in every form the server stores it', () {
      expect(isDocuNinjaSigned({'dn_completed': true}), isTrue);
      expect(isDocuNinjaSigned({'dn_completed': 1}), isTrue);
      expect(isDocuNinjaSigned({'dn_completed': '1'}), isTrue);
    });

    test('is false for no sync, no flag, or a false flag', () {
      expect(isDocuNinjaSigned(null), isFalse);
      expect(isDocuNinjaSigned(const {}), isFalse);
      expect(isDocuNinjaSigned({'dn_completed': false}), isFalse);
      expect(isDocuNinjaSigned({'qb_id': '12'}), isFalse);
    });
  });

  group('docuNinjaDocumentId', () {
    test("reads the first invitation's dn_id, as React does", () {
      expect(
        docuNinjaDocumentId({
          'invitations': [
            {'dn_id': 'first'},
            {'dn_id': 'second'},
          ],
        }),
        'first',
      );
    });

    test('is null when there is no usable id', () {
      expect(docuNinjaDocumentId(null), isNull);
      expect(docuNinjaDocumentId({'invitations': <Object?>[]}), isNull);
      expect(docuNinjaDocumentId({'invitations': 'x'}), isNull);
      expect(
        docuNinjaDocumentId({
          'invitations': [
            {'dn_id': ''},
          ],
        }),
        isNull,
      );
    });
  });
}
