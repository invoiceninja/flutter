import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/value/currency.dart';
import 'package:admin/data/models/value/datetime_format.dart';
import 'package:admin/data/models/value/language.dart';
import 'package:admin/data/models/value/timezone.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/settings/state/settings_level_controller.dart';
import 'package:admin/ui/features/settings/view_models/settings_draft_view_model.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/settings/widgets/overridable_radio_field.dart';
import 'package:admin/ui/features/settings/widgets/overridable_searchable_dropdown_field.dart';
import 'package:admin/ui/features/settings/widgets/overridable_switch_field.dart';
import 'package:admin/ui/features/settings/widgets/settings_form_shell.dart';
import 'package:admin/utils/formatting.dart';

/// Localization "Settings" tab — field labels surfaced by the in-app search.
/// Combined with `kLocalizationCustomLabelsSearchKeys` in
/// `settings_search_catalog.dart` under the `localization` section.
const kLocalizationSettingsSearchKeys = <String>[
  'currency',
  'currency_format',
  'language',
  'timezone',
  'date_format',
  'military_time',
  'rappen_rounding',
  'decimal_comma',
  'first_month_of_the_year',
  'first_day_of_the_week',
];

/// Settings tab body. Mounted by `LocalizationShell` inside
/// `CascadeTabbedSettingsShell` — the shell owns the cascade VM and provides
/// it via Provider.
///
/// Country lives on Company Details > Address; Payment Terms belongs on
/// Workflow Settings — both are intentionally absent here to match the React
/// app and admin-portal.
///
/// `decimal_comma` and `first_month_of_the_year` are global format choices —
/// they're hidden at group/client scope (the cascade override doesn't make
/// sense per-client). Matches the React app and admin-portal.
class LocalizationSettingsBody extends StatelessWidget {
  const LocalizationSettingsBody({super.key});

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final statics = services.statics;
    final host = context.watch<SettingsDraftHost>();
    final scope = context.watch<SettingsLevelController>();

    final currencies = statics.currencies.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final languages = statics.languages.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final timezones = statics.timezones.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final dateFormats = statics.dateFormats.values.toList();
    // Locale for the date-format dropdown previews, so MMM month names match
    // how dates render elsewhere. Uses the already-warmed company Formatter
    // (null on a cold deep-link → DateFormat falls back to the default locale;
    // the _dateFormatPreview try/catch guards either way).
    final companyId = services.auth.session.value?.currentCompanyId;
    final previewLocale = companyId == null
        ? null
        : services.formatterIfReady(companyId)?.settings.locale;
    // First Month of the Year is a top-level company field (not cascade) — read
    // it off the company draft, mirroring Company Details' size / industry.
    final months = _monthOptions(context);
    final firstMonth = host.draft?.firstMonthOfYear ?? '';
    // First Day of the Week is likewise a top-level company field ('0'=Sun..
    // '6'=Sat), driving week starts for charts, report grouping, and the
    // date-range calendar.
    final days = _dayOptions(context);
    final firstDay = host.draft?.firstDayOfWeek ?? '';

    // `host.settings` is the resolved cascade at every scope, so this reads
    // the currency the client/group would actually bill in.
    final currencyCode = statics.currencies[host.settings.currencyId]?.code;
    final showRappenRounding =
        currencyCode == 'CHF' || (host.settings.enableRappenRounding ?? false);

    final isCompanyScope = scope.isCompany;
    // Demo accounts can't change the UI language — would conflict with the
    // hosted demo's tour scripting. Mirrors admin-portal's `AppState.isDemo`,
    // which compares the session's base URL against `kDemoBaseUrl`.
    final isDemoSession = services.auth.session.value?.isDemo ?? false;
    final showLanguage = !isDemoSession;

    return SettingsFormShell(
      sections: [
        FormSection(
          title: context.tr('region'),
          children: [
            OverridableSearchableDropdownField<Currency>(
              label: context.tr('currency'),
              apiKey: 'currency_id',
              value: host.settings.currencyId,
              items: currencies,
              displayString: (c) => '${c.code} — ${c.name}',
              idOf: (c) => c.id,
              onChanged: (v) =>
                  host.updateSettings((s) => s.copyWith(currencyId: v)),
            ),
            _currencyFormatField(context, host),
            if (showLanguage)
              OverridableSearchableDropdownField<Language>(
                label: context.tr('language'),
                apiKey: 'language_id',
                value: host.settings.languageId,
                items: languages,
                displayString: (l) => l.name,
                idOf: (l) => l.id,
                onChanged: (v) =>
                    host.updateSettings((s) => s.copyWith(languageId: v)),
              ),
            OverridableSearchableDropdownField<Timezone>(
              label: context.tr('timezone'),
              apiKey: 'timezone_id',
              value: host.settings.timezoneId,
              items: timezones,
              displayString: (t) => t.name,
              idOf: (t) => t.id,
              onChanged: (v) =>
                  host.updateSettings((s) => s.copyWith(timezoneId: v)),
            ),
            OverridableSearchableDropdownField<DatetimeFormat>(
              label: context.tr('date_format'),
              apiKey: 'date_format_id',
              value: host.settings.dateFormatId,
              items: dateFormats,
              displayString: (f) => _dateFormatPreview(f, previewLocale),
              idOf: (f) => f.id,
              onChanged: (v) =>
                  host.updateSettings((s) => s.copyWith(dateFormatId: v)),
            ),
          ],
        ),
        FormSection(
          title: context.tr('format'),
          children: [
            OverridableSwitchField(
              label: context.tr('military_time'),
              apiKey: 'military_time',
            ),
            // Rappen is the Swiss centime and the option rounds to 5 cents, so
            // it is noise on any other currency — the server only defaults it
            // on for Switzerland (CountryDefaults '756'). Gated on the
            // *resolved* cascade currency (invoiceninja/flutter#78). Stays
            // visible while it is switched on, so a company that deliberately
            // enabled 5-cent rounding on another currency can still find it
            // and turn it back off rather than being stranded with an
            // invisible setting.
            if (showRappenRounding)
              OverridableSwitchField(
                label: context.tr('rappen_rounding'),
                apiKey: 'enable_rappen_rounding',
              ),
            if (isCompanyScope) ...[
              // Decimal Comma is a TOP-LEVEL company field (not a cascade
              // setting) — the money formatter reads it off the company row via
              // Services._buildFormatter. Bind it to the company draft like
              // first_month/first_day below, NOT via OverridableSwitchField
              // (which would write the dead settings.use_comma_as_decimal_place
              // the server ignores). Company-scope only, same as before.
              SwitchListTile(
                title: Text(context.tr('decimal_comma')),
                subtitle: Text(context.tr('use_comma_as_decimal_place')),
                value: host.draft?.useCommaAsDecimalPlace ?? false,
                onChanged: (v) => host.updateCompany(
                  (c) => c.copyWith(useCommaAsDecimalPlace: v),
                ),
                contentPadding: EdgeInsets.zero,
              ),
              // first_month_of_year is a top-level company field, not a
              // settings-cascade value — a plain dropdown bound to the company
              // draft (like Company Details' size / industry), not an
              // OverridableDropdownField.
              DropdownButtonFormField<String>(
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: context.tr('first_month_of_the_year'),
                ),
                initialValue: months.any((m) => m.value == firstMonth)
                    ? firstMonth
                    : null,
                items: months,
                onChanged: (v) => host.updateCompany(
                  (c) => c.copyWith(firstMonthOfYear: v ?? ''),
                ),
              ),
              // first_day_of_week — also a top-level company field, same plain
              // dropdown bound to the company draft.
              DropdownButtonFormField<String>(
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: context.tr('first_day_of_the_week'),
                ),
                initialValue: days.any((d) => d.value == firstDay)
                    ? firstDay
                    : null,
                items: days,
                onChanged: (v) => host.updateCompany(
                  (c) => c.copyWith(firstDayOfWeek: v ?? ''),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// Currency-display radio (Symbol vs Code) with a live formatted sample on
  /// each option — `Symbol: $1,000.00` / `Code: 1,000.00 USD`. Mirrors the old
  /// admin-portal `BoolDropdownButton` behaviour. Samples format a fixed
  /// `1000` against the *draft's* currency so the preview updates the moment
  /// the user changes the Currency dropdown above (the whole body rebuilds on
  /// `host` change and this re-runs against the cached formatter Future).
  Widget _currencyFormatField(BuildContext context, SettingsDraftHost host) {
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId;
    return FutureBuilder<Formatter>(
      future: companyId == null ? null : services.formatterFor(companyId),
      initialData: companyId == null
          ? null
          : services.formatterIfReady(companyId),
      builder: (context, snapshot) {
        final formatter = snapshot.data;
        // Before the formatter resolves (cold deep-link) fall back to the bare
        // option labels; the sample appears once the Future completes.
        String optionLabel(String key, bool showCurrencyCode) {
          final label = context.tr(key);
          if (formatter == null) return label;
          final sample = formatter.money(
            Decimal.fromInt(1000),
            currencyId: host.settings.currencyId,
            showCurrencyCode: showCurrencyCode,
          );
          return '$label: $sample';
        }

        return OverridableRadioField<bool>(
          label: context.tr('currency_format'),
          apiKey: 'show_currency_code',
          value: host.settings.showCurrencyCode ?? false,
          options: [
            (value: false, label: optionLabel('symbol', false)),
            (value: true, label: optionLabel('currency_code', true)),
          ],
          onChanged: (v) =>
              host.updateSettings((s) => s.copyWith(showCurrencyCode: v)),
        );
      },
    );
  }

  static String _dateFormatPreview(DatetimeFormat f, [String? locale]) {
    if (f.format.isEmpty) return f.id;
    try {
      return DateFormat(
        f.format,
        (locale == null || locale.isEmpty) ? null : locale,
      ).format(DateTime.now());
    } catch (_) {
      return f.format;
    }
  }

  List<DropdownMenuItem<String>> _monthOptions(BuildContext context) {
    const months = [
      'january',
      'february',
      'march',
      'april',
      'may',
      'june',
      'july',
      'august',
      'september',
      'october',
      'november',
      'december',
    ];
    return [
      for (var i = 0; i < months.length; i++)
        DropdownMenuItem<String>(
          value: '${i + 1}',
          child: Text(context.tr(months[i])),
        ),
    ];
  }

  List<DropdownMenuItem<String>> _dayOptions(BuildContext context) {
    // 0=Sunday..6=Saturday, matching the API + `kDaysOfTheWeek` convention.
    const days = [
      'sunday',
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
    ];
    return [
      for (var i = 0; i < days.length; i++)
        DropdownMenuItem<String>(value: '$i', child: Text(context.tr(days[i]))),
    ];
  }
}
