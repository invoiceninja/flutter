import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/value/country.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/form_save_scope.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/searchable_dropdown_field.dart';
import 'package:admin/ui/features/gateways/oauth_setup_launcher.dart'
    show openExternal;
import 'package:admin/ui/features/settings/view_models/settings_draft_view_model.dart';
import 'package:admin/ui/features/settings/views/advanced/e_invoice/e_invoice_constants.dart';
import 'package:admin/ui/features/settings/views/advanced/e_invoice/peppol_buy_credits_links.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';

/// Assemble the `POST /api/v1/einvoice/peppol/setup` body. Pure + top-level
/// so the EU vs Singapore wire shape is unit-testable without widget
/// scaffolding (mirrors the project's `parseEInvoiceValidation` pattern).
///
/// EU (isSingapore=false) emits exactly the historically-shipped keys —
/// changing this set would regress the already-✅ EU flow. Singapore swaps
/// the VAT/individual branch for an always-present UEN (`id_number`), adds
/// the C5 signer pair + `e_invoicing_token`, and the second classification
/// option is `government` (not `individual`).
Map<String, dynamic> buildPeppolSetupPayload({
  required bool isSingapore,
  required bool isBusiness,
  required String partyName,
  required String line1,
  required String line2,
  required String city,
  required String county,
  required String zip,
  required String countryId,
  required String vatNumber,
  required String idNumber,
  required bool actsAsSender,
  required bool actsAsReceiver,
  required String tenantId,
  required String signerName,
  required String signerEmail,
  required String eInvoicingToken,
}) {
  return <String, dynamic>{
    'party_name': partyName,
    'line1': line1,
    'line2': line2,
    'city': city,
    'county': county,
    'zip': zip,
    'country': countryId,
    'acts_as_sender': actsAsSender,
    'acts_as_receiver': actsAsReceiver,
    'tenant_id': tenantId,
    if (isSingapore) ...{
      // UEN is mandatory for Singapore (replaces the VAT/ID branch).
      'id_number': idNumber,
      'c5_signer_name': signerName,
      'c5_signer_email': signerEmail,
      'classification': isBusiness ? 'business' : 'government',
      'e_invoicing_token': eInvoicingToken,
    } else ...{
      if (isBusiness) 'vat_number': vatNumber,
      if (!isBusiness) 'id_number': idNumber,
      'classification': isBusiness ? 'business' : 'individual',
    },
  };
}

/// Settings → E-Invoice — PEPPOL Onboarding card. Rendered when the user
/// has selected `eInvoiceType = PEPPOL` and the tenant has not been
/// bound to a legal entity yet (`legalEntityId == 0`).
///
/// Form fields mirror admin-portal `e_invoice_settings.dart` and React
/// `peppol/Onboarding.tsx`:
///   * Business/Individual classification
///   * Party name (defaults to company name)
///   * VAT number (business) or ID number (individual)
///   * Address (line1, line2, city, county, postal_code, country)
///   * Acts-as-sender / acts-as-receiver
///
/// On Setup, fires `enqueuePeppolSetup` with the assembled payload. The
/// dispatcher applies the server response (with the new `legal_entity_id`)
/// and the body's conditional gates swap this card out for
/// [PeppolPreferencesCard].
///
/// Singapore (`country_id == '702'`) drives the CorpPass variant: it swaps
/// the VAT/individual branch for an always-present UEN, adds the C5 signer
/// pair, offers business/government classification, and on Setup posts
/// directly (`peppolSetupDirect`) so the returned gov-auth URL can be
/// launched at tap-time — see `_onSetup`.
class PeppolOnboardingCard extends StatefulWidget {
  const PeppolOnboardingCard({super.key});

  @override
  State<PeppolOnboardingCard> createState() => _PeppolOnboardingCardState();
}

class _PeppolOnboardingCardState extends State<PeppolOnboardingCard> {
  bool _isBusiness = true;
  bool _actsAsSender = true;
  bool _actsAsReceiver = true;
  String? _countryId;
  bool _saving = false;

  final _partyName = TextEditingController();
  final _vatNumber = TextEditingController();
  final _idNumber = TextEditingController();
  final _line1 = TextEditingController();
  final _line2 = TextEditingController();
  final _city = TextEditingController();
  final _county = TextEditingController();
  final _zip = TextEditingController();
  // Singapore CorpPass-only.
  final _signerName = TextEditingController();
  final _signerEmail = TextEditingController();

  bool _seeded = false;
  bool _seededSigner = false;

  /// Singapore drives the CorpPass variant: UEN + C5 signer fields,
  /// business/government classification, and a gov-auth redirect on submit.
  bool get _isSingapore => _countryId == kSingaporeCountryId;

  /// Required-field gate for the Setup button. Mirrors admin-portal's
  /// pre-submit check so the user sees the disabled-button affordance
  /// instead of a server 422. `_actsAsSender` / `_actsAsReceiver` carry
  /// defaults and don't need validation; `_line2` is optional.
  bool get _canSubmit {
    if (_partyName.text.trim().isEmpty) return false;
    if (_countryId == null || _countryId!.isEmpty) return false;
    if (_line1.text.trim().isEmpty) return false;
    if (_city.text.trim().isEmpty) return false;
    if (_zip.text.trim().isEmpty) return false;
    if (_isSingapore) {
      // UEN + both C5 signer fields are mandatory for CorpPass.
      if (_idNumber.text.trim().isEmpty) return false;
      if (_signerName.text.trim().isEmpty) return false;
      if (_signerEmail.text.trim().isEmpty) return false;
      return true;
    }
    if (_isBusiness && _vatNumber.text.trim().isEmpty) return false;
    if (!_isBusiness && _idNumber.text.trim().isEmpty) return false;
    return true;
  }

  @override
  void initState() {
    super.initState();
    // Subscribe to every controller so the Setup button re-evaluates
    // _canSubmit as the user types — without this, the button stays
    // disabled until something else triggers a rebuild.
    for (final c in [
      _partyName,
      _vatNumber,
      _idNumber,
      _line1,
      _city,
      _zip,
      _signerName,
      _signerEmail,
    ]) {
      c.addListener(_onFieldChanged);
    }
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final c in [
      _partyName,
      _vatNumber,
      _idNumber,
      _line1,
      _city,
      _zip,
      _signerName,
      _signerEmail,
    ]) {
      c.removeListener(_onFieldChanged);
    }
    _partyName.dispose();
    _vatNumber.dispose();
    _idNumber.dispose();
    _line1.dispose();
    _line2.dispose();
    _city.dispose();
    _county.dispose();
    _zip.dispose();
    _signerName.dispose();
    _signerEmail.dispose();
    super.dispose();
  }

  /// Seed the form controllers from the current settings snapshot. Runs
  /// once after the first non-empty draft lands — admin-portal does the
  /// same: copy the company's name + address into the PEPPOL form as
  /// the starting point so the user only has to verify.
  ///
  /// Country gets special handling: PEPPOL is country-restricted, so we
  /// only carry the company country into the form when it's actually a
  /// PEPPOL country. Otherwise we leave `_countryId` null so the picker
  /// renders empty and the user actively chooses (vs. displaying a
  /// non-listed id and confusing them).
  void _seedIfNeeded(SettingsDraftHost host) {
    if (_seeded) return;
    final settings = host.settings;
    _partyName.text = settings.name ?? '';
    _vatNumber.text = settings.vatNumber ?? '';
    _idNumber.text = settings.idNumber ?? '';
    _line1.text = settings.address1 ?? '';
    _line2.text = settings.address2 ?? '';
    _city.text = settings.city ?? '';
    _county.text = settings.state ?? '';
    _zip.text = settings.postalCode ?? '';
    final seededCountry = settings.countryId;
    _countryId =
        (seededCountry != null && kPeppolCountries.contains(seededCountry))
        ? seededCountry
        : null;
    _seeded = true;
  }

  @override
  Widget build(BuildContext context) {
    final host = context.watch<SettingsDraftHost>();
    if (host.draft == null) return const SizedBox.shrink();
    _seedIfNeeded(host);

    final services = context.read<Services>();
    // Singapore: default the C5 signer to the authenticated user (React
    // does the same). Seeded once; the user can override.
    if (_isSingapore && !_seededSigner) {
      final s = services.auth.session.value;
      if (s != null) {
        _signerName.text = '${s.userFirstName} ${s.userLastName}'.trim();
        _signerEmail.text = s.userEmail;
        // Latch only once we've actually seeded — a null session (not
        // expected on an authenticated settings screen) still gets a
        // chance on a later build.
        _seededSigner = true;
      }
    }
    final countries =
        services.statics.countries.values
            .where((c) => kPeppolCountries.contains(c.id))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    final selectedCountry = _countryId == null
        ? null
        : countries.firstWhere(
            (c) => c.id == _countryId,
            orElse: () => Country(
              id: _countryId ?? '',
              name: _countryId ?? '',
              iso2: '',
              iso3: '',
              swapCurrencySymbol: false,
              thousandSeparator: ',',
              decimalSeparator: '.',
              swapPostalCode: false,
            ),
          );

    return FormSaveScope(
      enabled: !_saving && _canSubmit,
      onSubmit: _onSetup,
      child: FormSection(
        title: context.tr('setup'),
        trailing: FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
          onPressed: (_saving || !_canSubmit) ? null : _onSetup,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(context.tr('setup')),
        ),
        children: [
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: true, label: Text(context.tr('business'))),
              ButtonSegment(
                value: false,
                label: Text(
                  context.tr(_isSingapore ? 'government' : 'individual'),
                ),
              ),
            ],
            selected: {_isBusiness},
            onSelectionChanged: (s) => setState(() => _isBusiness = s.first),
          ),
          _OnboardingField(
            controller: _partyName,
            label: context.tr('company_name'),
            textCapitalization: TextCapitalization.words,
          ),
          if (_isSingapore)
            // UEN is always required for CorpPass (no VAT branch).
            _OnboardingField(
              controller: _idNumber,
              label: context.tr('unique_entity_number'),
              autocorrect: false,
            )
          else if (_isBusiness)
            _OnboardingField(
              controller: _vatNumber,
              label: context.tr('vat_number'),
              autocorrect: false,
            )
          else
            _OnboardingField(
              controller: _idNumber,
              label: context.tr('id_number'),
              autocorrect: false,
            ),
          if (_isSingapore) ...[
            _OnboardingField(
              controller: _signerName,
              label: context.tr('signer_name'),
              textCapitalization: TextCapitalization.words,
            ),
            _OnboardingField(
              controller: _signerEmail,
              label: context.tr('signer_email'),
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
            ),
          ],
          SearchableDropdownField<Country>(
            label: context.tr('country'),
            items: countries,
            initialValue: selectedCountry,
            displayString: (c) => c.name,
            idOf: (c) => c.id,
            onChanged: (c) => setState(() => _countryId = c?.id),
          ),
          _OnboardingField(
            controller: _line1,
            label: context.tr('address1'),
            textCapitalization: TextCapitalization.words,
          ),
          _OnboardingField(
            controller: _line2,
            label: context.tr('address2'),
            textCapitalization: TextCapitalization.words,
          ),
          _OnboardingField(
            controller: _city,
            label: context.tr('city'),
            textCapitalization: TextCapitalization.words,
          ),
          _OnboardingField(controller: _county, label: context.tr('state')),
          // Alphanumeric outside the US (UK/CA/NL/PL), so never a numeric
          // keyboard — uppercase + no autocorrect is the universal choice.
          _OnboardingField(
            controller: _zip,
            label: context.tr('postal_code'),
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
          ),
          SwitchListTile(
            title: Text(context.tr('act_as_sender')),
            contentPadding: EdgeInsets.zero,
            value: _actsAsSender,
            onChanged: (v) => setState(() => _actsAsSender = v),
          ),
          SwitchListTile(
            title: Text(context.tr('act_as_receiver')),
            contentPadding: EdgeInsets.zero,
            value: _actsAsReceiver,
            onChanged: (v) => setState(() => _actsAsReceiver = v),
          ),
          // New tenants need credits before their first send — surface the
          // purchase links here (hosted-only, self-gates otherwise).
          const PeppolBuyCreditsLinks(),
        ],
      ),
    );
  }

  Future<void> _onSetup() async {
    final services = context.read<Services>();
    final host = context.read<SettingsDraftHost>();
    final company = host.draft;
    if (company == null) return;

    final isSingapore = _isSingapore;
    final payload = buildPeppolSetupPayload(
      isSingapore: isSingapore,
      isBusiness: _isBusiness,
      partyName: _partyName.text.trim(),
      line1: _line1.text.trim(),
      line2: _line2.text.trim(),
      city: _city.text.trim(),
      county: _county.text.trim(),
      zip: _zip.text.trim(),
      countryId: _countryId ?? '',
      vatNumber: _vatNumber.text.trim(),
      idNumber: _idNumber.text.trim(),
      actsAsSender: _actsAsSender,
      actsAsReceiver: _actsAsReceiver,
      // admin-portal sends `company.id`; React sends `company.companyKey`.
      // Both are accepted by the server. Following admin-portal here so
      // the wire shape matches the legacy client we're porting from.
      tenantId: company.id,
      signerName: _signerName.text.trim(),
      signerEmail: _signerEmail.text.trim(),
      eInvoicingToken: services.auth.session.value?.eInvoicingToken ?? '',
    );

    setState(() => _saving = true);
    try {
      if (isSingapore) {
        // Direct (non-outbox) by design: the response carries a CorpPass
        // gov-auth URL that must be launched at tap-time. EU keeps the
        // outbox path below, untouched.
        final corppassUrl = await services.company.peppolSetupDirect(
          companyId: company.id,
          payload: payload,
        );
        if (!mounted) return;
        if (corppassUrl != null) {
          // Launch first, then report the real outcome — don't claim
          // "redirecting" before we know the browser actually opened.
          final ok = await openExternal(Uri.parse(corppassUrl));
          if (!mounted) return;
          if (ok) {
            Notify.success(context, context.tr('redirecting_to_corppass'));
          } else {
            Notify.error(context, context.tr('could_not_launch'));
          }
        } else {
          Notify.success(context, context.tr('saved'));
        }
      } else {
        await services.company.enqueuePeppolSetup(
          companyId: company.id,
          payload: payload,
        );
        if (!mounted) return;
        Notify.success(context, context.tr('saved'));
      }
    } catch (e) {
      if (!mounted) return;
      Notify.error(context, context.tr('could_not_save'), error: e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

/// Single-line text field bound to a controller, wired to the surrounding
/// [FormSaveScope] so Enter submits the form. Used for every text input
/// inside the onboarding card.
class _OnboardingField extends StatelessWidget {
  const _OnboardingField({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.autocorrect = true,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final bool autocorrect;

  @override
  Widget build(BuildContext context) {
    final scope = FormSaveScope.maybeOf(context);
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.done,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      autocorrect: autocorrect,
      enableSuggestions: autocorrect,
      decoration: InputDecoration(labelText: label),
      onSubmitted: scope == null ? null : (_) => scope.trySubmit(),
    );
  }
}
