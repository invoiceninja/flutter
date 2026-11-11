import 'package:decimal/decimal.dart';

import 'package:admin/data/models/api/terminal_models.dart';
import 'package:admin/data/services/api_client.dart';
import 'package:admin/data/services/request_scope.dart';
import 'package:admin/data/services/terminal_server_error.dart';

/// The in-person card payment endpoints (docs/in-person-payments.md).
///
/// **Not through the outbox, and not read from Drift** (an accepted
/// exception, CLAUDE.md § Strict rules): taking a card is a live
/// conversation with the server and a card reader — a queued "charge this
/// card" could only ever run after the customer had left. Recording never
/// depends on it either: the server records every charge from Stripe's
/// webhook and its own reconciliation, and [complete] is only the fast path.
///
/// Every call runs in the company's [RequestScope], so a company switch can't
/// send it under another company's token. A refusal the screen branches on
/// is rethrown as a [TerminalServerError]; anything else (offline, a 500)
/// propagates as the API failure it is.
class TerminalRepository {
  TerminalRepository({
    required ApiClient apiClient,
    required this.refreshInvoice,
    required this.refreshClients,
    required this.refreshPayment,
  }) : _api = apiClient;

  final ApiClient _api;

  /// Re-fetches an invoice and returns its client ids —
  /// `InvoiceRepository.refreshByIds`.
  final Future<Set<String>> Function(String companyId, String invoiceId)
  refreshInvoice;
  final Future<void> Function(String companyId, Set<String> clientIds)
  refreshClients;
  final Future<void> Function(String companyId, String paymentId)
  refreshPayment;

  /// Answers well inside Stripe's 30 seconds between reading a card and
  /// charging it.
  static const finalizeTimeout = Duration(seconds: 12);

  Future<TerminalConfig> config(String companyId) async =>
      TerminalConfig.fromJson(
        _body(
          await _run(companyId, () => _api.getOne('/api/v1/terminal/config')),
        ),
      );

  /// A connection token for the SDK, for one Stripe Location.
  Future<String> connectionToken(
    String companyId, {
    required String companyGatewayId,
    required String locationId,
  }) async {
    final body = _body(
      await _run(
        companyId,
        () => _api.postJson(
          '/api/v1/company_gateways/$companyGatewayId/terminal/connection_token',
          body: {'location_id': locationId},
        ),
      ),
    );
    final secret = body['secret'];
    if (secret is! String || secret.isEmpty) {
      throw const FormatException('connection_token returned no secret');
    }
    return secret;
  }

  /// Creates the gateway's Stripe Location from the company address (admin).
  Future<TerminalLocation> createLocation(
    String companyId, {
    required String companyGatewayId,
  }) async => TerminalLocation.fromJson(
    _body(
      await _run(
        companyId,
        () => _api.postJson(
          '/api/v1/company_gateways/$companyGatewayId/terminal/locations',
        ),
      ),
    ),
  );

  /// Records that an admin accepted the surcharge rules for this gateway.
  Future<void> acknowledgeSurcharge(
    String companyId, {
    required String companyGatewayId,
  }) => _run(
    companyId,
    () => _api.postJson(
      '/api/v1/company_gateways/$companyGatewayId/terminal/surcharge_acknowledgement',
    ),
  );

  Future<TerminalQuote> quote(
    String companyId, {
    required String invoiceId,
    required String companyGatewayId,
    required Decimal amount,
    required bool applyFee,
  }) async => TerminalQuote.fromJson(
    _body(
      await _run(
        companyId,
        () => _api.getOneWithQuery(
          '/api/v1/invoices/$invoiceId/terminal/quote',
          query: {
            'company_gateway_id': companyGatewayId,
            'amount': amount.toString(),
            // Laravel's `boolean` rule refuses "true" / "false".
            'apply_fee': applyFee ? '1' : '0',
          },
        ),
      ),
    ),
  );

  /// Creates (or, for the same [collectionId], returns) the collection's
  /// PaymentIntent. The server marks a draft sent here, so the invoice is
  /// re-fetched whatever the outcome.
  Future<TerminalIntent> createPaymentIntent(
    String companyId, {
    required String invoiceId,
    required String companyGatewayId,
    required Decimal amount,
    required bool applyFee,
    required String collectionId,
    required Decimal expectedTotal,
  }) async {
    try {
      return TerminalIntent.fromJson(
        _body(
          await _run(
            companyId,
            () => _api.postJson(
              '/api/v1/invoices/$invoiceId/terminal/payment_intents',
              body: {
                'company_gateway_id': companyGatewayId,
                'amount': amount.toString(),
                'apply_fee': applyFee,
                'collection_id': collectionId,
                'expected_total': expectedTotal.toString(),
              },
            ),
          ),
        ),
      );
    } finally {
      await _quietly(companyId, () => refreshInvoice(companyId, invoiceId));
    }
  }

  Future<TerminalFinalize> finalize(
    String companyId,
    String paymentIntentId, {
    required String invoiceId,
  }) async => TerminalFinalize.fromJson(
    _body(
      await _run(
        companyId,
        () => _api.postJson(
          _collectionPath(invoiceId, paymentIntentId, 'finalize'),
          timeout: finalizeTimeout,
        ),
      ),
    ),
  );

  /// Records the charge, if there is one, and refreshes what it changed.
  Future<TerminalCompletion> complete(
    String companyId,
    String paymentIntentId, {
    required String invoiceId,
  }) => _settle(companyId, paymentIntentId, 'complete', invoiceId);

  /// Cancels the PaymentIntent if Stripe still allows it. It may answer
  /// `recorded` instead: the card was charged after all.
  Future<TerminalCompletion> cancel(
    String companyId,
    String paymentIntentId, {
    required String invoiceId,
  }) => _settle(companyId, paymentIntentId, 'cancel', invoiceId);

  /// Stripe's receipt for the charge, to [email].
  Future<void> receipt(
    String companyId,
    String paymentIntentId, {
    required String invoiceId,
    required String email,
  }) => _run(
    companyId,
    () => _api.postJson(
      _collectionPath(invoiceId, paymentIntentId, 'receipt'),
      body: {'email': email},
    ),
  );

  /// A collection's actions live under the invoice it was taken for: the
  /// server finds it by the invoice, which is indexed, and its PaymentIntent.
  static String _collectionPath(
    String invoiceId,
    String paymentIntentId,
    String action,
  ) =>
      '/api/v1/invoices/$invoiceId/terminal/payment_intents/'
      '$paymentIntentId/$action';

  Future<TerminalCompletion> _settle(
    String companyId,
    String paymentIntentId,
    String action,
    String invoiceId,
  ) async {
    final completion = TerminalCompletion.fromJson(
      _body(
        await _run(
          companyId,
          () => _api.postJson(
            _collectionPath(invoiceId, paymentIntentId, action),
          ),
        ),
      ),
    );
    await _quietly(companyId, () async {
      final clientIds = await refreshInvoice(companyId, invoiceId);
      if (completion.isRecorded) {
        await refreshClients(companyId, clientIds);
        if (completion.paymentId.isNotEmpty) {
          await refreshPayment(companyId, completion.paymentId);
        }
      }
    });
    return completion;
  }

  Future<T> _run<T>(String companyId, Future<T> Function() call) async {
    try {
      return await RequestScope(companyId).run(call);
    } catch (e) {
      final terminal = TerminalServerError.from(e);
      if (terminal != null) throw terminal;
      rethrow;
    }
  }

  /// A refresh is a courtesy: the screen's answer stands without it.
  static Future<void> _quietly(
    String companyId,
    Future<void> Function() refresh,
  ) async {
    try {
      await RequestScope(companyId).run(refresh);
    } catch (_) {}
  }

  static Map<String, dynamic> _body(Object? raw) => raw is Map<String, dynamic>
      ? raw
      : throw const FormatException('terminal endpoint returned no object');
}
