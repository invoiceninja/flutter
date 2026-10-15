import 'dart:async';

/// How a client's VAT check ended — the server's verdict, or why there isn't
/// one.
enum VatCheckResult {
  valid,
  invalid,

  /// VIES gave no verdict (a member state's system is down, or the caller is
  /// rate limited). The server retries its job on its own.
  unavailable,

  /// No verdict inside the deadline.
  timeout,

  /// The request failed, or the server answered something unexpected.
  error,
}

/// Run a VAT check the way the server makes it work: [start] queues a VIES
/// lookup (`POST /clients/{id}/check_vat`), and the verdict lands in a cache
/// that [status] reads (`GET /clients/{id}/vat_status`) — so poll every
/// [interval] until it isn't `pending`, giving up at [deadline]. Mirrors
/// React's `VatValidation` (2 s polls, 30 s deadline).
///
/// Returns null when [cancelled] says the caller has gone (checked after every
/// wait). A `null` status after `pending` is an error rather than "keep
/// waiting": the server forgets a verdict on its first read, so nothing more
/// is coming.
Future<VatCheckResult?> runVatCheck({
  required Future<void> Function() start,
  required Future<String?> Function() status,
  bool Function()? cancelled,
  Duration interval = const Duration(seconds: 2),
  Duration deadline = const Duration(seconds: 30),
}) async {
  try {
    await start();
  } catch (_) {
    return VatCheckResult.error;
  }
  final clock = Stopwatch()..start();
  while (true) {
    await Future<void>.delayed(interval);
    if (cancelled?.call() ?? false) return null;
    final left = deadline - clock.elapsed;
    if (left <= Duration.zero) return VatCheckResult.timeout;
    final String? answer;
    try {
      answer = await status().timeout(left);
    } on TimeoutException {
      return VatCheckResult.timeout;
    } catch (_) {
      return VatCheckResult.error;
    }
    if (cancelled?.call() ?? false) return null;
    switch (answer) {
      case 'pending':
        continue;
      case 'valid':
        return VatCheckResult.valid;
      case 'invalid':
        return VatCheckResult.invalid;
      case 'unavailable':
        return VatCheckResult.unavailable;
      default:
        return VatCheckResult.error;
    }
  }
}

/// Numeric `country_id`s of the EU member states, where a VAT number can be
/// checked against VIES — the server's `ClientObserver::$eu_country_ids`
/// (and React's `EU_COUNTRY_IDS`).
const Set<String> kVatCheckCountryIds = {
  '40', '56', '100', '196', '203', '276', '208', '233', '724', //
  '246', '250', '300', '191', '348', '372', '380', '440', '442', //
  '428', '470', '528', '616', '620', '642', '752', '705', '703', //
};
