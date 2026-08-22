import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/company_settings_api_model.dart';
import 'package:admin/data/models/domain/company_settings.dart';
import 'package:admin/ui/features/settings/widgets/settings_field_bindings.dart';

/// `documents_public_by_default` is the company-level default `is_public` the
/// server applies to every new attachment. It reaches the wire through three
/// separate registrations, each of which fails silently-ish on its own:
/// the freezed field, the `_settingsBoolKeys` coercion set, and the settings
/// binding the Company Details → Documents toggle reads.
void main() {
  group('documents_public_by_default', () {
    test('resolves to a binding', () {
      expect(
        () => settingsBindingOf('documents_public_by_default'),
        returnsNormally,
        reason:
            'missing binding — OverridableSwitchField throws StateError at '
            'the first frame of the Documents tab without it',
      );
    });

    test('round-trips true/false/null', () {
      const settings = CompanySettings();
      final b = settingsBindingOf('documents_public_by_default');

      expect(b.read(settings), isNull, reason: 'unset should read as null');

      final on = b.write(settings, 'true');
      expect(b.read(on), 'true');
      expect(on.documentsPublicByDefault, true);

      final off = b.write(on, 'false');
      expect(b.read(off), 'false');
      expect(off.documentsPublicByDefault, false);

      final cleared = b.write(off, null);
      expect(b.read(cleared), isNull);
      expect(cleared.documentsPublicByDefault, isNull);
    });

    test('is registered for bool coercion, so a server-side 1/0 parses', () {
      // The PHP server ships settings booleans as ints or strings. Without the
      // `_settingsBoolKeys` entry the generated `as bool?` cast throws and
      // takes the whole company parse down with it.
      expect(
        CompanySettingsApi.fromJsonLenient({
          'documents_public_by_default': 1,
        }).documentsPublicByDefault,
        true,
      );
      expect(
        CompanySettingsApi.fromJsonLenient({
          'documents_public_by_default': '0',
        }).documentsPublicByDefault,
        false,
      );
    });

    test('serializes back to the server key', () {
      const settings = CompanySettings(documentsPublicByDefault: false);
      expect(settings.toJson()['documents_public_by_default'], false);
    });
  });
}
