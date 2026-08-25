import 'package:flutter/widgets.dart';

import 'package:admin/data/models/domain/company.dart';
import 'package:admin/l10n/localization.dart';

/// The active company's Custom Labels — `settings.translations`, edited under
/// Settings → Localization → Custom Labels — resolved over the bundled
/// localization strings.
///
/// The server applies this map to everything it renders (`Ninja::transformTranslations`
/// feeds the Laravel translator, so PDFs, emails, reports and the client
/// portal all honor it). React mirrors that globally by pushing the map into
/// i18next once at app start (`useCompanyTranslations`), so every `t()` picks
/// an override up; admin-portal reads it inline at the line-item table.
///
/// This app applies it at the line-item headers only — see
/// [LineItemColumnConfig.labels] — but the type is deliberately independent of
/// that one caller so a wider layer can reuse it later without touching call
/// sites.
@immutable
class CompanyLabels {
  const CompanyLabels(this._overrides);

  const CompanyLabels.empty() : _overrides = const {};

  /// Reads the company's `settings.translations`.
  ///
  /// Two filters, both load-bearing:
  ///
  /// - **Blank values are dropped**, so [resolve] falls through to the bundled
  ///   string. The Custom Labels editor seeds a newly added row with `''`
  ///   (`custom_labels_screen._addLabel`) and the server coerces nulls to `''`
  ///   (`CompanySettingsSaver`), so a user who adds a row and never types in it
  ///   must keep the shipped label rather than get a blank column header.
  ///   admin-portal guards the same way.
  /// - **Non-string values are dropped.** The field is `Map<String, dynamic>`
  ///   because some accounts store a nested object under a lang key; those
  ///   would otherwise stringify onto a header as `{a: b}`.
  factory CompanyLabels.fromCompany(Company? company) {
    final raw = company?.settings.translations;
    if (raw == null || raw.isEmpty) return const CompanyLabels.empty();
    final out = <String, String>{};
    for (final entry in raw.entries) {
      final value = entry.value;
      if (value is! String || value.trim().isEmpty) continue;
      out[entry.key] = value;
    }
    return out.isEmpty ? const CompanyLabels.empty() : CompanyLabels(out);
  }

  final Map<String, String> _overrides;

  /// The company's override for [key], or `null` when it has none.
  String? operator [](String key) => _overrides[key];

  /// The company's override for [key], falling back to the bundled string.
  String resolve(BuildContext context, String key) =>
      _overrides[key] ?? context.tr(key);
}
