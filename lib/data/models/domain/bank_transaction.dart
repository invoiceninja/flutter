import 'package:decimal/decimal.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:admin/data/models/api/bank_transaction_api_model.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/models/value/money.dart';
import 'package:admin/data/models/value/parsing.dart';

part 'bank_transaction.freezed.dart';

/// `base_type` constants.
const String kTransactionTypeCredit = 'CREDIT';
const String kTransactionTypeDebit = 'DEBIT';

/// `status_id` constants. Stored as TEXT to mirror the wire shape.
const String kTransactionStatusUnmatched = '1';
const String kTransactionStatusMatched = '2';
const String kTransactionStatusConverted = '3';

/// Domain `BankTransaction` (wire entity: `bank_transaction`). Top-level
/// nav at `/transactions`.
@freezed
abstract class BankTransaction with _$BankTransaction {
  const BankTransaction._();

  const factory BankTransaction({
    required String id,
    required Decimal amount,
    required String currencyId,
    required String category,
    required String baseType,
    required Date? date,
    required String bankAccountId,
    required String description,
    required String statusId,
    required String categoryId,
    required String invoiceIds,
    required String paymentId,
    required String expenseId,
    required String vendorId,
    required String transactionId,
    required String transactionRuleId,
    required String participantName,
    required String participant,
    required bool isDeleted,
    required DateTime updatedAt,
    required DateTime createdAt,
    required DateTime? archivedAt,
    @Default(<String>[]) List<String> tagIds,
    @Default(false) bool isDirty,
  }) = _BankTransaction;

  factory BankTransaction.fromApi(BankTransactionApi a) => BankTransaction(
    id: a.id,
    amount: parseMoney(a.amount),
    currencyId: a.currencyId,
    category: a.categoryType,
    baseType: a.baseType,
    date: Date.tryParse(a.date),
    bankAccountId: a.bankIntegrationId,
    description: a.description,
    statusId: a.statusId,
    categoryId: a.ninjaCategoryId,
    invoiceIds: a.invoiceIds,
    paymentId: a.paymentId,
    expenseId: a.expenseId,
    vendorId: a.vendorId,
    transactionId: _parseProviderId(a.transactionId),
    transactionRuleId: a.bankTransactionRuleId,
    participantName: a.participantName,
    participant: a.participant,
    isDeleted: a.isDeleted,
    updatedAt: epochSecondsToUtc(a.updatedAt),
    createdAt: epochSecondsToUtc(a.createdAt),
    archivedAt: epochSecondsToUtcOrNull(a.archivedAt),
    tagIds: [
      for (final t in a.tags)
        if (t.id.isNotEmpty) t.id,
    ],
  );

  Map<String, dynamic> toApiJson({bool preserveTempId = false}) {
    final json = BankTransactionApi(
      id: id,
      amount: amount.toString(),
      currencyId: currencyId,
      categoryType: category,
      baseType: baseType,
      date: date?.toIso() ?? '',
      bankIntegrationId: bankAccountId,
      description: description,
      statusId: statusId,
      ninjaCategoryId: categoryId,
      invoiceIds: invoiceIds,
      paymentId: paymentId,
      expenseId: expenseId,
      vendorId: vendorId,
      transactionId: transactionId,
      bankTransactionRuleId: transactionRuleId,
      participantName: participantName,
      participant: participant,
      isDeleted: isDeleted,
      updatedAt: updatedAt.millisecondsSinceEpoch ~/ 1000,
      createdAt: createdAt.millisecondsSinceEpoch ~/ 1000,
      archivedAt: archivedAt == null
          ? 0
          : archivedAt!.millisecondsSinceEpoch ~/ 1000,
    ).toJson();
    // The API model's EmbeddedTagsConverter would serialize bare ids as
    // `[{id, name:'', color:null}]`; overwrite with the bare id list so the
    // wire shape matches the other entities (full-set sync).
    json['tags'] = tagIds;
    if (!preserveTempId && id.startsWith('tmp_')) {
      json.remove('id');
    }
    return json;
  }

  bool get isDeposit => baseType == kTransactionTypeCredit;
  bool get isWithdrawal => baseType == kTransactionTypeDebit;

  bool get isUnmatched => statusId == kTransactionStatusUnmatched;
  bool get isMatched => statusId == kTransactionStatusMatched;
  bool get isConverted => statusId == kTransactionStatusConverted;

  /// Parsed list of comma-separated linked invoice ids. Empty when none.
  List<String> get linkedInvoiceIds => invoiceIds.isEmpty
      ? const <String>[]
      : invoiceIds
            .split(',')
            .where((e) => e.isNotEmpty)
            .toList(growable: false);

  /// Parsed list of comma-separated linked expense ids.
  List<String> get linkedExpenseIds => expenseId.isEmpty
      ? const <String>[]
      : expenseId.split(',').where((e) => e.isNotEmpty).toList(growable: false);
}

/// The wire allows either int or string for `transaction_id`. Normalize to
/// string for storage (the column is TEXT in Drift).
String _parseProviderId(Object raw) {
  if (raw is String) return raw;
  if (raw is num) return raw == 0 ? '' : raw.toString();
  return '';
}
