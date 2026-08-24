/// Shared constants for the E-Invoice settings page.
///
/// Mirrors the equivalents in admin-portal `lib/constants.dart:263-310` and
/// React `pages/settings/e-invoice/EInvoice.tsx`. Kept narrow on purpose —
/// e-invoice payload schemas, payment-means codes, and PEPPOL country tables
/// belong in their own files when the related cards land in later phases.
///
/// Constant names intentionally carry underscores after the type prefix
/// (`XInvoice_Extended`, `Facturae_3_2`, `OrderX_Basic`, …) to read 1:1
/// against the wire values they hold — making cross-referencing the React
/// app, admin-portal, and the server schema effortless. The
/// `constant_identifier_names` lint is suppressed at file scope for that
/// reason.
library;

// ignore_for_file: constant_identifier_names

import 'package:admin/ui/core/utils/external_url.dart';

/// Wire values for `company.settings.e_invoice_type`. Order matches
/// admin-portal so the dropdown reads identically.
const String kEInvoiceTypeEN16931 = 'EN16931';
const String kEInvoiceTypeXInvoice_3_0 = 'XInvoice_3_0';
const String kEInvoiceTypeXInvoice_2_3 = 'XInvoice_2_3';
const String kEInvoiceTypeXInvoice_2_2 = 'XInvoice_2_2';
const String kEInvoiceTypeXInvoice_2_1 = 'XInvoice_2_1';
const String kEInvoiceTypeXInvoice_2_0 = 'XInvoice_2_0';
const String kEInvoiceTypeXInvoice_1_0 = 'XInvoice_1_0';
const String kEInvoiceTypeXInvoice_Extended = 'XInvoice-Extended';
const String kEInvoiceTypeXInvoice_BasicWL = 'XInvoice-BasicWL';
const String kEInvoiceTypeXInvoice_Basic = 'XInvoice-Basic';
const String kEInvoiceTypeFacturae_3_2 = 'Facturae_3.2';
const String kEInvoiceTypeFacturae_3_2_1 = 'Facturae_3.2.1';
const String kEInvoiceTypeFacturae_3_2_2 = 'Facturae_3.2.2';
const String kEInvoiceTypeFACT1 = 'FACT1';
const String kEInvoiceTypeFatturaPA = 'FatturaPA';
const String kEInvoiceTypePEPPOL = 'PEPPOL';
const String kEInvoiceTypeVERIFACTU = 'VERIFACTU';
const String kEInvoiceTypeOrderX_Basic = 'OrderX_Basic';
const String kEInvoiceTypeOrderX_Comfort = 'OrderX_Comfort';
const String kEInvoiceTypeOrderX_Extended = 'OrderX_Extended';

const List<String> kEInvoiceTypes = <String>[
  kEInvoiceTypeEN16931,
  kEInvoiceTypeXInvoice_3_0,
  kEInvoiceTypeXInvoice_2_3,
  kEInvoiceTypeXInvoice_2_2,
  kEInvoiceTypeXInvoice_2_1,
  kEInvoiceTypeXInvoice_2_0,
  kEInvoiceTypeXInvoice_1_0,
  kEInvoiceTypeXInvoice_Extended,
  kEInvoiceTypeXInvoice_BasicWL,
  kEInvoiceTypeXInvoice_Basic,
  kEInvoiceTypeFacturae_3_2_2,
  kEInvoiceTypeFacturae_3_2_1,
  kEInvoiceTypeFacturae_3_2,
  kEInvoiceTypeFACT1,
  kEInvoiceTypeFatturaPA,
  kEInvoiceTypePEPPOL,
  kEInvoiceTypeVERIFACTU,
  kEInvoiceTypeOrderX_Basic,
  kEInvoiceTypeOrderX_Comfort,
  kEInvoiceTypeOrderX_Extended,
];

/// Pure filter for the E-Invoice type dropdown. Mirrors React's
/// `shouldShowPEPPOLOption` / `shouldShowVERIFACTUOption` gating
/// (`EInvoice.tsx:86-112`) so the option list matches the web client:
///
///   * **PEPPOL** — visible only with Enterprise access **and** a
///     PEPPOL-network country ([kPeppolCountries]). React's
///     `(isPlanActive && PEPPOL_COUNTRIES.includes(country))`.
///   * **VERIFACTU** — visible only when the build flag is on, the account is
///     hosted, and the company country is Spain ([kEInvoiceCountryIdSpain]).
///
/// Both keep an already-selected value visible (the `…Selected` carve-outs) so
/// a user whose plan lapsed or whose country isn't listed can still switch
/// *away* from a standard they previously saved. Every other standard is
/// always offered. Pure + top-level so it's unit-testable without widget
/// scaffolding (mirrors `buildPeppolSetupPayload`).
List<String> visibleEInvoiceTypes({
  required String? selectedType,
  required String? countryId,
  required bool hasEnterpriseAccess,
  required bool isHosted,
  required bool verifactuFlagEnabled,
}) {
  final isPeppolSelected = selectedType == kEInvoiceTypePEPPOL;
  final isVerifactuSelected = selectedType == kEInvoiceTypeVERIFACTU;
  final isPeppolCountry =
      countryId != null && kPeppolCountries.contains(countryId);
  final isSpain = countryId == kEInvoiceCountryIdSpain;
  final verifactuVisible = verifactuFlagEnabled && isHosted && isSpain;

  return kEInvoiceTypes
      .where((t) {
        if (t == kEInvoiceTypePEPPOL) {
          return (hasEnterpriseAccess && isPeppolCountry) || isPeppolSelected;
        }
        if (t == kEInvoiceTypeVERIFACTU) {
          return verifactuVisible || isVerifactuSelected;
        }
        return true;
      })
      .toList(growable: false);
}

const String kEQuoteTypeOrderX_Comfort = 'OrderX_Comfort';
const String kEQuoteTypeOrderX_Basic = 'OrderX_Basic';
const String kEQuoteTypeOrderX_Extended = 'OrderX_Extended';

const List<String> kEQuoteTypes = <String>[
  kEQuoteTypeOrderX_Comfort,
  kEQuoteTypeOrderX_Basic,
  kEQuoteTypeOrderX_Extended,
];

/// Country id (`company.settings.country_id`) for Spain. VERIFACTU is the
/// Spanish tax-authority's e-invoicing standard; React only shows the option
/// when the active company is in Spain.
const String kEInvoiceCountryIdSpain = '724';

/// Country id (`company.settings.country_id`) for France. The French
/// e-reporting section on the E-Invoice page is gated to this country.
const String kFranceCountryId = '250';

/// `france_reporting_schedule` wire values. `ten_day` is the server default;
/// `monthly` is the alternative. Single-sourced so the radio and any future
/// reader agree on the exact strings.
const String kFranceReportingTenDay = 'ten_day';
const String kFranceReportingMonthly = 'monthly';

/// External help URL for the e-invoicing docs. Rendered as a `LinkText` at
/// the top of the body so users can find background on the field set without
/// leaving the page.
const String kEInvoiceHelpUrl =
    'https://invoiceninja.github.io/docs/user-guide/einvoicing';

/// Hosted-billing purchase links for PEPPOL credit packs. Verbatim from React
/// `peppol/Onboarding.tsx:341,353` (the `BuyCredits` step). Surfaced by
/// [PeppolBuyCreditsLinks] on the onboarding + preferences cards; hosted-only
/// (these are invoicing.co subscription URLs, inapplicable to self-hosted).
const String kPeppolBuy500Url =
    'https://invoiceninja.invoicing.co/client/subscriptions/WJxboqNegw/purchase';
const String kPeppolBuy1000Url =
    'https://invoiceninja.invoicing.co/client/subscriptions/k8mep0reMy/purchase';

/// Open the e-invoicing user-guide URL in the host browser. Best-effort;
/// failures (no browser, sandbox restrictions) are swallowed. Used by the
/// help link in [_HelpLinkRow] and the "Read the setup guide" link inside
/// the VERIFACTU info card.
Future<void> launchEInvoiceHelpUrl() async {
  // Silent — failing to open a help link is non-blocking.
  await launchExternalUri(Uri.parse(kEInvoiceHelpUrl));
}

/// Country ids (`company.settings.country_id`) supported by the PEPPOL
/// network. Mirrors React `peppol-countries.ts` `PEPPOL_COUNTRIES` exactly
/// (15 ids). Used as the allowlist for the onboarding card's country picker
/// and the Tax Identifiers add-dialog. Singapore (`702`) triggers the
/// CorpPass-specific form (UEN + signer fields) and the gov-auth redirect —
/// see `peppol_onboarding_card.dart`.
const List<String> kPeppolCountries = <String>[
  '20', // Andorra
  '40', // Austria
  '56', // Belgium
  '208', // Denmark
  '250', // France
  '276', // Germany
  '352', // Iceland
  '372', // Ireland
  '442', // Luxembourg
  '528', // Netherlands
  '578', // Norway
  '616', // Poland
  '702', // Singapore (CorpPass onboarding)
  '752', // Sweden
  '826', // United Kingdom
];

/// `company.settings.country_id` for Singapore — selects the CorpPass
/// onboarding variant (UEN + C5 signer fields, business/government
/// classification, gov-auth redirect) instead of the EU VAT/individual
/// form.
const String kSingaporeCountryId = '702';

/// 97 UN/CEFACT payment method codes accepted by the e-invoicing
/// configuration endpoint. Verbatim copy of admin-portal
/// `constants.dart:317-401`; the wire-value is the map key (always sent
/// to the server as a string).
const Map<String, String> kPaymentMeansCodes = <String, String>{
  '1': 'Instrument not defined',
  '2': 'Automated clearing house credit',
  '3': 'Automated clearing house debit',
  '4': 'ACH demand debit reversal',
  '5': 'ACH demand credit reversal',
  '6': 'ACH demand credit',
  '7': 'ACH demand debit',
  '8': 'Hold',
  '9': 'National or regional clearing',
  '10': 'In cash',
  '11': 'ACH savings credit reversal',
  '12': 'ACH savings debit reversal',
  '13': 'ACH savings credit',
  '14': 'ACH savings debit',
  '15': 'Bookentry credit',
  '16': 'Bookentry debit',
  '17': 'ACH demand CCD credit',
  '18': 'ACH demand CCD debit',
  '19': 'ACH demand CTP credit',
  '20': 'Cheque',
  '21': "Banker's draft",
  '22': "Certified banker's draft",
  '23': 'Bank cheque',
  '24': 'Bill of exchange awaiting acceptance',
  '25': 'Certified cheque',
  '26': 'Local cheque',
  '27': 'ACH demand CTP debit',
  '28': 'ACH demand CTX credit',
  '29': 'ACH demand CTX debit',
  '30': 'Credit transfer',
  '31': 'Debit transfer',
  '32': 'ACH demand CCD+ credit',
  '33': 'ACH demand CCD+ debit',
  '34': 'ACH prearranged payment and deposit (PPD)',
  '35': 'ACH savings CCD credit',
  '36': 'ACH savings CCD debit',
  '37': 'ACH savings CTP credit',
  '38': 'ACH savings CTP debit',
  '39': 'ACH savings CTX credit',
  '40': 'ACH savings CTX debit',
  '41': 'ACH savings CCD+ credit',
  '42': 'Payment to bank account',
  '43': 'ACH savings CCD+ debit',
  '44': 'Accepted bill of exchange',
  '45': 'Referenced home-banking credit transfer',
  '46': 'Interbank debit transfer',
  '47': 'Home-banking debit transfer',
  '48': 'Bank card',
  '49': 'Direct debit',
  '50': 'Payment by postgiro',
  '51': 'FR, norme 6 97-Telereglement CFONB',
  '52': 'Urgent commercial payment',
  '53': 'Urgent Treasury Payment',
  '54': 'Credit card',
  '55': 'Debit card',
  '56': 'Bankgiro',
  '57': 'Standing agreement',
  '58': 'SEPA credit transfer',
  '59': 'SEPA direct debit',
  '60': 'Promissory note',
  '61': 'Promissory note signed by the debtor',
  '62': 'Promissory note signed by debtor and endorsed by bank',
  '63': 'Promissory note signed by debtor and endorsed by third party',
  '64': 'Promissory note signed by a bank',
  '65': 'Promissory note signed by bank and endorsed by another bank',
  '66': 'Promissory note signed by a third party',
  '67': 'Promissory note signed by third party and endorsed by bank',
  '68': 'Online payment service',
  '69': 'Transfer Advice',
  '70': 'Bill drawn by the creditor on the debtor',
  '74': 'Bill drawn by the creditor on a bank',
  '75': 'Bill drawn by creditor, endorsed by another bank',
  '76': 'Bill drawn by creditor on bank and endorsed by third party',
  '77': 'Bill drawn by the creditor on a third party',
  '78': 'Bill drawn by creditor on third party, accepted and endorsed',
  '91': "Not transferable banker's draft",
  '92': 'Not transferable local cheque',
  '93': 'Reference giro',
  '94': 'Urgent giro',
  '95': 'Free format giro',
  '96': 'Requested method for payment was not used',
  '97': 'Clearing between partners',
  'ZZZ': 'Mutually defined',
};

/// Maps each payment-means code to the sub-field set the form should
/// render. Order matters — the form should render fields in this order.
/// Verbatim copy of admin-portal `constants.dart:403-487`.
const Map<String, List<String>> kPaymentMeansFormElements =
    <String, List<String>>{
      '1': [],
      '2': ['iban', 'bic_swift'],
      '3': ['payer_bank_account', 'iban', 'bic_swift'],
      '4': ['payer_bank_account', 'iban', 'bic_swift'],
      '5': ['iban', 'bic_swift'],
      '6': ['iban', 'bic_swift'],
      '7': ['payer_bank_account', 'iban', 'bic_swift'],
      '8': [],
      '9': ['iban', 'bic_swift'],
      '10': [],
      '11': ['iban', 'bic_swift'],
      '12': ['payer_bank_account', 'iban', 'bic_swift'],
      '13': ['iban', 'bic_swift'],
      '14': ['payer_bank_account', 'iban', 'bic_swift'],
      '15': ['account_holder', 'bsb_sort'],
      '16': ['account_holder', 'bsb_sort'],
      '17': ['iban', 'bic_swift'],
      '18': ['payer_bank_account', 'iban', 'bic_swift'],
      '19': ['iban', 'bic_swift'],
      '20': [],
      '21': [],
      '22': [],
      '23': [],
      '24': [],
      '25': [],
      '26': [],
      '27': ['payer_bank_account', 'iban', 'bic_swift'],
      '28': ['iban', 'bic_swift'],
      '29': ['payer_bank_account', 'iban', 'bic_swift'],
      '30': ['iban', 'bic_swift', 'account_holder'],
      '31': ['iban', 'bic_swift', 'account_holder'],
      '32': ['iban', 'bic_swift', 'account_holder'],
      '33': ['payer_bank_account', 'iban', 'bic_swift', 'account_holder'],
      '34': ['iban', 'bic_swift', 'account_holder'],
      '35': ['iban', 'bic_swift', 'account_holder'],
      '36': ['payer_bank_account', 'iban', 'bic_swift', 'account_holder'],
      '37': ['iban', 'bic_swift', 'account_holder'],
      '38': ['payer_bank_account', 'iban', 'bic_swift', 'account_holder'],
      '39': ['iban', 'bic_swift', 'account_holder'],
      '40': ['payer_bank_account', 'iban', 'bic_swift', 'account_holder'],
      '41': ['iban', 'bic_swift', 'account_holder'],
      '42': ['iban', 'bic_swift', 'account_holder'],
      '43': ['payer_bank_account', 'iban', 'bic_swift', 'account_holder'],
      '44': [],
      '45': ['iban', 'bic_swift'],
      '46': ['iban', 'bic_swift'],
      '47': ['iban', 'bic_swift'],
      '48': ['card_type', 'card_number'],
      '49': ['payer_bank_account', 'iban', 'bic_swift'],
      '50': ['account_holder'],
      '51': ['iban', 'bic_swift'],
      '52': ['iban', 'bic_swift'],
      '53': ['iban', 'bic_swift'],
      '54': ['card_type', 'card_number', 'card_holder'],
      '55': ['card_type', 'card_number', 'card_holder'],
      '56': ['account_holder'],
      '57': ['iban', 'bic_swift'],
      '58': ['account_holder', 'iban', 'bic_swift'],
      '59': ['account_holder', 'iban', 'bic_swift'],
      '60': [],
      '61': [],
      '62': ['bic_swift'],
      '63': [],
      '64': ['bic_swift'],
      '65': ['bic_swift'],
      '66': [],
      '67': ['bic_swift'],
      '68': ['iban'],
      '69': ['iban', 'bic_swift'],
      '70': [],
      '74': ['bic_swift'],
      '75': ['bic_swift'],
      '76': ['bic_swift'],
      '77': [],
      '78': [],
      '91': [],
      '92': [],
      '93': ['iban', 'bic_swift'],
      '94': ['iban', 'bic_swift'],
      '95': ['iban', 'bic_swift'],
      '96': [],
      '97': ['account_holder'],
      'ZZZ': [],
    };
