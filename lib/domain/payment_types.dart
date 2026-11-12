import 'package:admin/data/models/value/payment_type.dart';
import 'package:admin/l10n/localization.dart';

/// Payment types: their company-renamed names, and the ones a company hides
/// from the Type pickers (invoiceninja/flutter#191, docs/payment-types.md).

/// Payment type id → the translation key the server names it by, mirrored
/// from `PaymentType::$type_names` (`app/Models/PaymentType.php`). A company
/// renames a type by setting that key in `settings.translations` — the server
/// then prints the new name on PDFs, the portal, emails and exports — and
/// [paymentTypeLabel] shows it here.
///
/// Two ids are left out on purpose. The server names 46 (FPX) by `fpx` and
/// 50 (Stripe Bank Transfer) by `bank_transfer` in documents, but by
/// `payment_type_FPX` / `payment_type_Stripe Bank Transfer` in `/statics`, so
/// no one key renames them consistently — and renaming 50 through
/// `bank_transfer` would relabel every "Bank Transfer" word the server
/// prints. They keep the server's name and can't be renamed.
const Map<String, String> kPaymentTypeLabelKeys = {
  '1': 'payment_type_Bank Transfer',
  '2': 'payment_type_Cash',
  '3': 'payment_type_Debit',
  '4': 'payment_type_ACH',
  '5': 'payment_type_Visa Card',
  '6': 'payment_type_MasterCard',
  '7': 'payment_type_American Express',
  '8': 'payment_type_Discover Card',
  '9': 'payment_type_Diners Card',
  '10': 'payment_type_EuroCard',
  '11': 'payment_type_Nova',
  '12': 'payment_type_Credit Card Other',
  '13': 'payment_type_PayPal',
  '14': 'payment_type_Google Wallet',
  '15': 'payment_type_Check',
  '16': 'payment_type_Carte Blanche',
  '17': 'payment_type_UnionPay',
  '18': 'payment_type_JCB',
  '19': 'payment_type_Laser',
  '20': 'payment_type_Maestro',
  '21': 'payment_type_Solo',
  '22': 'payment_type_Switch',
  '23': 'payment_type_iZettle',
  '24': 'payment_type_Swish',
  '25': 'payment_type_Venmo',
  '26': 'payment_type_Money Order',
  '27': 'payment_type_Alipay',
  '28': 'payment_type_Sofort',
  '29': 'payment_type_SEPA',
  '30': 'payment_type_GoCardless',
  '31': 'payment_type_Crypto',
  '32': 'payment_type_Credit',
  '33': 'payment_type_Zelle',
  '34': 'payment_type_Mollie Bank Transfer',
  '35': 'payment_type_KBC/CBC',
  '36': 'payment_type_Bancontact',
  '37': 'payment_type_iDEAL',
  '38': 'payment_type_Hosted Page',
  '39': 'payment_type_GiroPay',
  '40': 'payment_type_Przelewy24',
  '41': 'payment_type_EPS',
  '42': 'payment_type_Direct Debit',
  '43': 'payment_type_BECS',
  '44': 'payment_type_ACSS',
  '45': 'payment_type_Instant Bank Pay',
  '47': 'payment_type_Klarna',
  '48': 'payment_type_Interac E Transfer',
  '49': 'payment_type_BACS',
  '51': 'payment_type_Cash App',
  '52': 'payment_type_Pay Later',
  '53': 'payment_type_Mobile Payment',
};

/// The name to show for payment type [id]: the company's own name for it
/// (Settings → Payment Types, stored in `settings.translations`), else
/// [serverName] — the name `/statics` sent, already in the user's language.
///
/// Only an actual override replaces [serverName]: when [l10n]'s lookup equals
/// the bundled string there is none, and the server's name stays — the
/// bundled translation could otherwise swap a localized name for English
/// where the locale's bundle lacks the key. Note `Localization.of` withholds
/// every Custom Label while the app's language differs from the company's
/// (`CompanyLabelOverrides`); that applies here too.
String paymentTypeLabel(Localization? l10n, String id, String serverName) {
  final key = kPaymentTypeLabelKeys[id];
  if (key == null || l10n == null) return serverName;
  final label = l10n.lookup(key);
  return label == l10n.lookupBundled(key) ? serverName : label;
}

/// [paymentTypeLabel] for a statics [PaymentType].
String paymentTypeName(Localization? l10n, PaymentType type) =>
    paymentTypeLabel(l10n, type.id, type.name);

/// The ids in the `hidden_payment_types` company setting (comma-separated,
/// blank entries dropped).
Set<String> parseHiddenPaymentTypes(String? csv) => {
  for (final part in (csv ?? '').split(','))
    if (part.trim().isNotEmpty) part.trim(),
};

/// [ids] as the `hidden_payment_types` setting: numeric order, comma-joined,
/// `''` for none — never null, which the settings save would drop and so
/// leave the old list in place.
String encodeHiddenPaymentTypes(Iterable<String> ids) {
  final sorted = ids.where((id) => id.isNotEmpty).toSet().toList()
    ..sort((a, b) {
      final na = int.tryParse(a);
      final nb = int.tryParse(b);
      if (na != null && nb != null) return na.compareTo(nb);
      return a.compareTo(b);
    });
  return sorted.join(',');
}
