/// Stored status discriminator on every quote. Wire ids are `'1'..'6'`.
/// Mirrors admin-portal `kQuoteStatus*` constants.
///
/// `rejected` ('5') is set server-side when a client rejects the quote in
/// the portal — the admin app never sets it but must display it.
///
/// `cancelled` ('6') is set by the `cancel` bulk action, which the server
/// allows only on a Sent quote and cannot reverse.
///
/// Computed-only pseudo-statuses (`expired`, `viewed`) are derived on the
/// client from the quote's `due_date` and invitation state — see the
/// `QuoteCalculation.calculatedStatusId` extension on `Quote`. They never
/// appear in the wire payload.
enum QuoteStatus {
  draft('1'),
  sent('2'),
  approved('3'),
  converted('4'),
  rejected('5'),
  cancelled('6');

  const QuoteStatus(this.wireId);

  final String wireId;

  static QuoteStatus fromWire(String? raw) => switch (raw) {
    '2' => QuoteStatus.sent,
    '3' => QuoteStatus.approved,
    '4' => QuoteStatus.converted,
    '5' => QuoteStatus.rejected,
    '6' => QuoteStatus.cancelled,
    _ => QuoteStatus.draft,
  };

  String get labelKey => switch (this) {
    QuoteStatus.draft => 'draft',
    QuoteStatus.sent => 'sent',
    QuoteStatus.approved => 'approved',
    QuoteStatus.converted => 'converted',
    QuoteStatus.rejected => 'rejected',
    QuoteStatus.cancelled => 'cancelled',
  };
}

/// Computed pseudo-statuses used by `Quote.calculatedStatusId` for the
/// status pill + list-filter chips. Never stored on the server.
class QuoteStatusComputed {
  const QuoteStatusComputed._();

  static const String expired = '-1';
  static const String viewed = '-2';
}

String quoteStatusLabelKey(String id) => switch (id) {
  QuoteStatusComputed.expired => 'expired',
  QuoteStatusComputed.viewed => 'viewed',
  _ => QuoteStatus.fromWire(id).labelKey,
};
