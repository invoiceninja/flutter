import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/ui/core/dialogs/confirm_sign_out_dialog.dart';
import 'package:admin/ui/features/shell/widgets/confirm_pending_outbox.dart';
import 'package:admin/data/models/value/currency.dart';
import 'package:admin/data/models/value/language.dart';
import 'package:admin/data/repositories/statics_repository.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/form_save_scope.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';
import 'package:admin/ui/features/shell/widgets/show_company_picker.dart';

/// One-shot gate shown when the active company hasn't been named yet
/// (settings.name is empty or still the server's default
/// `'Untitled Company'`). Mirrors admin-portal's `SettingsWizard` dialog
/// and React's `CompanyEdit` modal, but rendered as a full-screen route
/// outside the shell so it gates every deep link uniformly.
///
/// Single step on purpose — collects only what's needed to unwedge the
/// app: company name (required), currency, language. Logo / payment
/// gateways / subdomain live in their dedicated settings screens.
class SetupWizardScreen extends StatefulWidget {
  const SetupWizardScreen({super.key});

  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends State<SetupWizardScreen> {
  late final TextEditingController _nameController;
  String _currencyId = '';
  String _languageId = '';
  bool _isSaving = false;
  String? _nameError;
  bool _defaultsSeeded = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController()..addListener(_onNameChanged);
    // Statics may not be warm on a fresh first login. `ensureLoaded` reads
    // the Drift cache when present and only hits the network on a cold
    // launch; the callback's `setState` re-runs `didChangeDependencies` →
    // `_seedDefaultsFromLocale` once the maps are populated. The canonical
    // `StaticsWarmer` wrapper is unsuitable here because its `setState`
    // re-emits the same `child` reference, which Flutter optimizes into a
    // no-op for our subtree — we need an explicit wizard-state rebuild.
    final statics = context.read<Services>().statics;
    if (statics.currencies.isEmpty || statics.languages.isEmpty) {
      statics.ensureLoaded().then((_) {
        if (mounted) setState(_seedDefaultsFromLocale);
      });
    }
  }

  @override
  void dispose() {
    _nameController
      ..removeListener(_onNameChanged)
      ..dispose();
    super.dispose();
  }

  void _onNameChanged() {
    final hasError = _nameError != null;
    if (hasError) {
      setState(() => _nameError = null);
    } else {
      // Rebuild so `_canSubmit` reflects the latest text — also drives the
      // submit button's enabled state.
      setState(() {});
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_defaultsSeeded) _seedDefaultsFromLocale();
  }

  /// Pick currency + language from the device locale once statics are warm
  /// and the current company hasn't already chosen them. Falls back to USD
  /// / English (id `'1'`) when no locale-derived match is found — the
  /// historical Invoice Ninja defaults.
  void _seedDefaultsFromLocale() {
    final services = context.read<Services>();
    final statics = services.statics;
    if (statics.currencies.isEmpty || statics.languages.isEmpty) return;

    final session = services.auth.session.value;
    final companyId = session?.currentCompanyId;
    if (companyId == null || companyId.isEmpty) return;

    // Read the current company once, off-async. Defaults only seed
    // when the company hasn't set them yet (settings.{currencyId,languageId}
    // is empty). We don't await — seed runs after the future, but
    // `services.company.get` returns immediately from Drift cache.
    services.company.get(companyId).then((company) {
      if (!mounted || company == null) return;
      final existingCurrency = company.settings.currencyId ?? '';
      final existingLanguage = company.settings.languageId ?? '';
      final deviceLocale = Localizations.maybeLocaleOf(context);
      final pickedCurrency = existingCurrency.isNotEmpty
          ? existingCurrency
          : _defaultCurrencyId(statics, deviceLocale);
      final pickedLanguage = existingLanguage.isNotEmpty
          ? existingLanguage
          : _defaultLanguageId(statics, deviceLocale);
      setState(() {
        _currencyId = pickedCurrency;
        _languageId = pickedLanguage;
        _defaultsSeeded = true;
      });
    });
  }

  String _defaultCurrencyId(StaticsRepository statics, Locale? locale) {
    final countryCode = locale?.countryCode;
    if (countryCode == null || countryCode.isEmpty) return '1'; // USD
    final byCode = _currencyForCountry(statics, countryCode);
    return byCode ?? '1';
  }

  /// Hard-coded country → currency mapping for the common cases. Keeps the
  /// signup default smart without dragging in a full ISO-3166 → ISO-4217
  /// table. Anything not in the map falls back to USD.
  String? _currencyForCountry(StaticsRepository statics, String iso2) {
    const map = <String, String>{
      'US': 'USD',
      'GB': 'GBP',
      'CA': 'CAD',
      'AU': 'AUD',
      'NZ': 'NZD',
      'JP': 'JPY',
      'CH': 'CHF',
      'SE': 'SEK',
      'NO': 'NOK',
      'DK': 'DKK',
      'PL': 'PLN',
      'IN': 'INR',
      'BR': 'BRL',
      'MX': 'MXN',
      'AR': 'ARS',
      'ZA': 'ZAR',
      'SG': 'SGD',
      'HK': 'HKD',
      'IL': 'ILS',
      'KR': 'KRW',
      // Eurozone → EUR (20 members as of 2026, ordered by accession year)
      'DE': 'EUR', 'FR': 'EUR', 'ES': 'EUR', 'IT': 'EUR', 'NL': 'EUR',
      'BE': 'EUR', 'AT': 'EUR', 'IE': 'EUR', 'PT': 'EUR', 'GR': 'EUR',
      'FI': 'EUR', 'LU': 'EUR', 'CY': 'EUR', 'MT': 'EUR', 'SI': 'EUR',
      'SK': 'EUR', 'EE': 'EUR', 'LV': 'EUR', 'LT': 'EUR', 'HR': 'EUR',
    };
    final code = map[iso2.toUpperCase()];
    if (code == null) return null;
    final hit = statics.currencies.values
        .where((c) => c.code.toUpperCase() == code)
        .firstOrNull;
    return hit?.id;
  }

  String _defaultLanguageId(StaticsRepository statics, Locale? locale) {
    final languageCode = locale?.languageCode.toLowerCase();
    if (languageCode == null || languageCode.isEmpty) return '1';
    // Prefer exact `lang_country` match (e.g. `fr_CA`), fall back to the
    // first row whose `locale` starts with the device language code.
    final tag = locale?.countryCode != null
        ? '${languageCode}_${locale!.countryCode!.toLowerCase()}'
        : languageCode;
    final exact = statics.languages.values
        .where((l) => l.locale.toLowerCase() == tag)
        .firstOrNull;
    if (exact != null) return exact.id;
    final prefix = statics.languages.values
        .where((l) => l.locale.toLowerCase().startsWith(languageCode))
        .firstOrNull;
    return prefix?.id ?? '1'; // English
  }

  bool get _canSubmit => !_isSaving && _nameController.text.trim().isNotEmpty;

  Future<void> _onSave() async {
    if (_isSaving) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = context.tr('please_enter_a_value'));
      return;
    }
    setState(() {
      _isSaving = true;
      _nameError = null;
    });
    final services = context.read<Services>();
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final session = services.auth.session.value;
      final companyId = session?.currentCompanyId;
      if (companyId == null || companyId.isEmpty) {
        throw StateError('No active company');
      }
      final current = await services.company.get(companyId);
      if (current == null) throw StateError('No company row for $companyId');
      await services.company.updateCompany(
        draft: current.copyWith(
          settings: current.settings.copyWith(
            name: name,
            currencyId: _currencyId.isEmpty
                ? current.settings.currencyId
                : _currencyId,
            languageId: _languageId.isEmpty
                ? current.settings.languageId
                : _languageId,
          ),
        ),
      );
      // Push the PUT through immediately so a follow-on `/refresh` (e.g.
      // restore() on next cold launch) gets the server-truth name and
      // doesn't bounce the user back into the wizard.
      unawaited(services.sync.drainOnce(companyId: companyId));
      if (!mounted) return;
      Notify.success(
        context,
        context.tr('welcome_x', {'name': name}),
        messenger: messenger,
      );
      // Router redirect fires on auth.session notify → bounces to
      // postLoginRoute(). No manual context.go(...) needed.
    } catch (e) {
      if (!mounted) return;
      Notify.error(
        context,
        context.tr('failed'),
        error: e,
        messenger: messenger,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _onSignOut() async {
    // Resolved before the first await so the confirm below doesn't push a
    // `context` read past one (`use_build_context_synchronously`).
    final services = context.read<Services>();
    // Note this screen reaches sign-out twice: here, and via
    // `_onSwitchCompany` -> `showCompanyPicker` -> the picker's Log Out row,
    // which carries its own confirm through `SettingsActions.signOut`.
    if (!await showConfirmSignOutDialog(context)) return;
    if (!mounted) return;
    // Full logout wipes every company's local DB — quiesce pending offline
    // rows first, same guard as every other sign-out entry point.
    final companyId = services.auth.session.value?.currentCompanyId;
    if (companyId != null) {
      final outbox = await confirmPendingOutboxIfAny(
        context,
        companyId: companyId,
        checkAllCompanies: true,
      );
      if (outbox == OutboxConfirmResult.cancelled || !mounted) return;
    }
    await services.auth.logout();
  }

  Future<void> _onSwitchCompany() async {
    await showCompanyPicker(context);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final session = context.watch<Services>().auth.session.value;
    final canSwitch = (session?.companies.length ?? 0) > 1;
    final statics = context.watch<Services>().statics;
    final currencies = statics.currencies.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final languages = statics.languages.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final currentCurrency = currencies
        .where((c) => c.id == _currencyId)
        .firstOrNull;
    final currentLanguage = languages
        .where((l) => l.id == _languageId)
        .firstOrNull;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: tokens.bg,
      body: SafeArea(
        child: FormSaveScope(
          onSubmit: _onSave,
          enabled: _canSubmit,
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: InSpacing.xl,
              vertical: InSpacing.xxl,
            ),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Image.asset(
                        isDark
                            ? 'assets/images/logo_dark.png'
                            : 'assets/images/logo_light.png',
                        height: 48,
                      ),
                      const SizedBox(height: InSpacing.xl),
                      Text(
                        context.tr('welcome_to_invoice_ninja'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: tokens.ink,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: InSpacing.sm),
                      Text(
                        context.tr('setup_wizard_intro'),
                        textAlign: TextAlign.center,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: tokens.ink3),
                      ),
                      const SizedBox(height: InSpacing.xl),
                      _SurfaceCard(
                        padding: const EdgeInsets.all(InSpacing.xl),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _NameField(
                              controller: _nameController,
                              errorText: _nameError,
                            ),
                            SizedBox(height: InSpacing.md(context)),
                            SearchableDropdownField<Currency>(
                              label: context.tr('currency'),
                              items: currencies,
                              initialValue: currentCurrency,
                              displayString: (c) => '${c.name} (${c.code})',
                              idOf: (c) => c.id,
                              onChanged: (c) =>
                                  setState(() => _currencyId = c?.id ?? ''),
                            ),
                            SizedBox(height: InSpacing.md(context)),
                            SearchableDropdownField<Language>(
                              label: context.tr('language'),
                              items: languages,
                              initialValue: currentLanguage,
                              displayString: (l) => l.name,
                              idOf: (l) => l.id,
                              onChanged: (l) =>
                                  setState(() => _languageId = l?.id ?? ''),
                            ),
                            const SizedBox(height: InSpacing.xl),
                            FilledButton.icon(
                              key: const ValueKey('setup_submit'),
                              onPressed: _canSubmit ? _onSave : null,
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : const Icon(Icons.arrow_forward, size: 18),
                              label: Text(context.tr('setup_submit')),
                              style: FilledButton.styleFrom(
                                backgroundColor: tokens.accent,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    InRadii.r2,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: InSpacing.md(context)),
                      Row(
                        mainAxisAlignment: canSwitch
                            ? MainAxisAlignment.spaceBetween
                            : MainAxisAlignment.center,
                        children: [
                          if (canSwitch)
                            TextButton.icon(
                              key: const ValueKey('setup_switch_company'),
                              onPressed: _isSaving ? null : _onSwitchCompany,
                              icon: const Icon(
                                Icons.swap_horiz_outlined,
                                size: 16,
                              ),
                              label: Text(context.tr('switch_company')),
                            ),
                          TextButton.icon(
                            key: const ValueKey('setup_sign_out'),
                            onPressed: _isSaving ? null : _onSignOut,
                            icon: const Icon(Icons.logout_outlined, size: 16),
                            label: Text(context.tr('logout')),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NameField extends StatelessWidget {
  const _NameField({required this.controller, this.errorText});

  final TextEditingController controller;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final scope = FormSaveScope.maybeOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            context.tr('company_name'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: tokens.ink3,
            ),
          ),
        ),
        TextField(
          key: const ValueKey('setup_company_name'),
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(errorText: errorText),
          onSubmitted: (_) => scope?.trySubmit(),
        ),
      ],
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child, required this.padding});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(InRadii.r3),
        border: Border.all(color: tokens.border),
        boxShadow: tokens.shadow2,
      ),
      padding: padding,
      child: child,
    );
  }
}
