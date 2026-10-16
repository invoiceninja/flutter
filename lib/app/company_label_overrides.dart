import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:logging/logging.dart';

import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/company_repository.dart';
import 'package:admin/data/repositories/statics_repository.dart';

/// The active company's Custom Labels — `settings.translations`, edited under
/// Settings → Localization → Custom Labels — as the app's own strings should
/// read them (invoiceninja/flutter#84). `CompanyLabelsScope` carries the value
/// to `Localization.of`, which looks every key up here first.
///
/// The server applies the map to everything it renders (PDFs, emails, the
/// portal), and React to every string in the app (`useCompanyTranslations`
/// pushes it into i18next). This app used to apply it at the line-item
/// headers alone.
///
/// - **It watches the company row**, not a settings save: a save, a Sync and
///   a `/refresh` all rewrite that row, and a company switch swaps the stream.
///   (`AppLocaleResolver` reads its row once and recomputes on a local save
///   only, so a label changed on another device would not reach it.)
/// - **Company only, no client or group cascade.** The app's own strings are
///   not about one client; React applies the company map too.
/// - **Empty while the app shows another language than the company's.**
///   Someone who set the app to English on a German company would otherwise
///   read German labels inside English sentences. React applies them to
///   whatever language is active; skipping them here was a product decision.
///   The comparison is with the language the app SHOWS (`AppLocaleResolver`),
///   not with the device setting: a company whose language ships no UI
///   strings (Turkish, say) runs the app in English with no device override
///   at all, and its labels are Turkish words.
/// - **Empty when signed out**, so the next user's login screen is the
///   bundle's.
class CompanyLabelOverrides extends ValueNotifier<Map<String, String>> {
  CompanyLabelOverrides({
    required AuthRepository auth,
    required CompanyRepository company,
    required ValueListenable<Locale?> appLocale,
    required StaticsRepository statics,
  }) : _auth = auth,
       _company = company,
       _appLocale = appLocale,
       _statics = statics,
       super(const {}) {
    _auth.session.addListener(_followCompany);
    _appLocale.addListener(_recompute);
    _followCompany();
  }

  static final _log = Logger('CompanyLabelOverrides');

  final AuthRepository _auth;
  final CompanyRepository _company;

  /// The locale the app renders in — `Services.appLocale`. Null only before
  /// a company is active.
  final ValueListenable<Locale?> _appLocale;
  final StaticsRepository _statics;

  /// True while the company has labels and the app is withholding them
  /// because it shows another language — what the Custom Labels screen says
  /// so the setting does not look ignored.
  bool get withheldForLanguage => _withheld;
  bool _withheld = false;

  String? _companyId;
  Company? _row;
  StreamSubscription<Company?>? _sub;
  int _seq = 0;
  bool _disposed = false;

  void _followCompany() {
    final id = _auth.session.value?.currentCompanyId;
    if (id == _companyId) return;
    _companyId = id;
    unawaited(_sub?.cancel());
    _sub = null;
    _row = null;
    // Cleared at once, not when the new row arrives: until then the last
    // company's words would be shown in this one's app.
    _seq++;
    _set(const {});
    if (id == null || id.isEmpty) return;
    _sub = _company.watchCompany(id).listen((row) {
      _row = row;
      _recompute();
    });
  }

  Future<void> _recompute() async {
    final seq = ++_seq;
    final labels = companyLabelOverrides(_row);
    if (labels.isEmpty) {
      _set(const {});
      return;
    }
    final shown = _appLocale.value;
    if (shown != null) {
      final written = await _companyLanguage();
      if (_disposed || seq != _seq) return;
      if (written != null && written != shown.languageCode) {
        _set(const {}, withheld: true);
        return;
      }
    }
    _set(labels);
  }

  /// The language the company's labels are written in — the company's own:
  /// its `language_id` through the statics table, English when unset. Null
  /// when that cannot be told (an id the statics do not know, or statics that
  /// failed to load); the labels then apply unchecked rather than stay stale.
  Future<String?> _companyLanguage() async {
    final languageId = _row?.settings.languageId ?? '';
    if (languageId.isEmpty) return 'en';
    try {
      await _statics.ensureLoaded();
    } catch (e, st) {
      // Unawaited listener: an escape here is an unhandled zone error.
      _log.warning(
        'statics unavailable; Custom Labels applied unchecked',
        e,
        st,
      );
      return null;
    }
    final code = _statics.languages[languageId]?.locale ?? '';
    if (code.isEmpty) return null;
    return code.split(RegExp('[_-]')).first.toLowerCase();
  }

  void _set(Map<String, String> next, {bool withheld = false}) {
    if (_disposed) return;
    final flagChanged = withheld != _withheld;
    _withheld = withheld;
    if (!mapEquals(next, value)) {
      value = next;
    } else if (flagChanged) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _auth.session.removeListener(_followCompany);
    _appLocale.removeListener(_recompute);
    unawaited(_sub?.cancel());
    super.dispose();
  }
}

/// The company's `settings.translations` as label overrides.
///
/// Two filters, both load-bearing:
///
/// - **Blank values are dropped**, so the bundled string shows. The Custom
///   Labels editor seeds a newly added row with `''`
///   (`custom_labels_screen._addLabel`) and the server coerces nulls to `''`
///   (`CompanySettingsSaver`), so a user who adds a row and never types in it
///   keeps the shipped label rather than getting a blank one. admin-portal
///   guards the same way.
/// - **Non-string values are dropped.** The field is `Map<String, dynamic>`
///   because some accounts store a nested object under a lang key; those
///   would otherwise stringify onto the screen as `{a: b}`.
Map<String, String> companyLabelOverrides(Company? company) {
  final raw = company?.settings.translations;
  if (raw == null || raw.isEmpty) return const {};
  final out = <String, String>{};
  for (final entry in raw.entries) {
    final value = entry.value;
    if (value is! String || value.trim().isEmpty) continue;
    out[entry.key] = value;
  }
  return out.isEmpty ? const {} : Map.unmodifiable(out);
}
