/// Statics-bundle payment-type entry (Apple Pay, Bitcoin, Cash, Credit Card,
/// …). Wire shape matches `admin-portal/lib/data/models/static/payment_type_model.dart`.
class PaymentType {
  const PaymentType({required this.id, required this.name});

  final String id;
  final String name;

  factory PaymentType.fromMap(Map<String, dynamic> json) => PaymentType(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
  );
}

/// Payment type 32, "Credit": the server records an applied credit (and a
/// subscription change) as a manual payment of this type. Not a way a client
/// pays, so it never stands as a client's last payment method
/// (docs/payment-types.md).
const String kCreditPaymentTypeId = '32';
