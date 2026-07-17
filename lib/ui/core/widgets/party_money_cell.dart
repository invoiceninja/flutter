import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/domain/columns/column_cells.dart';

/// Resolves a billing-doc party's (client *or* vendor) `currency_id` from the
/// local Drift cache and rebuilds [builder] with it — `null` until it resolves,
/// or when no party is set (→ company-default currency).
///
/// Mirrors [ClientNameLabel] / [VendorNameLabel]: it watches the very same
/// `(companyId, partyId)` row those labels already watch, so Drift dedupes the
/// underlying query — a money cell adds **no** extra DB work on top of the
/// name cell in the same row — and it lazily hydrates an off-page party via
/// `ensureLoaded` (paginated lists prefetch only page 1).
///
/// Exactly one of [clientId] / [vendorId] should be non-empty.
class PartyCurrencyBuilder extends StatefulWidget {
  const PartyCurrencyBuilder({
    super.key,
    this.clientId,
    this.vendorId,
    required this.builder,
  });

  final String? clientId;
  final String? vendorId;

  /// Rebuilt with the resolved party currency id (or `null`).
  final Widget Function(BuildContext context, String? currencyId) builder;

  @override
  State<PartyCurrencyBuilder> createState() => _PartyCurrencyBuilderState();
}

class _PartyCurrencyBuilderState extends State<PartyCurrencyBuilder> {
  /// Hoisted so the currency stream is NOT rebuilt on every parent rebuild.
  /// In the line-item editor this widget rebuilds ~every 250 ms while the user
  /// types; a fresh `watch()` per build would snap the [StreamBuilder] back to
  /// a null snapshot for a frame and flicker the currency symbol (the "stable
  /// stream" rule). Rebuilt only when the resolved `(company, party)` source id
  /// changes.
  Stream<String?>? _currencyId;
  String? _sourceKey;

  @override
  void initState() {
    super.initState();
    _ensure();
  }

  @override
  void didUpdateWidget(PartyCurrencyBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clientId != widget.clientId ||
        oldWidget.vendorId != widget.vendorId) {
      _ensure();
    }
  }

  /// Lazily hydrate an off-page party (paginated lists prefetch only page 1).
  void _ensure() {
    final vendorId = widget.vendorId ?? '';
    final clientId = widget.clientId ?? '';
    if (vendorId.isEmpty && clientId.isEmpty) return;
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId;
    if (companyId == null || companyId.isEmpty) return;
    if (vendorId.isNotEmpty) {
      services.vendors.ensureLoaded(companyId: companyId, id: vendorId);
    } else {
      services.clients.ensureLoaded(companyId: companyId, id: clientId);
    }
  }

  /// (Re)build the hoisted currency stream only when the resolved source id
  /// changes — idempotent so it can run from `build` and stay stable across the
  /// frequent rebuilds of an edit screen.
  void _ensureStream(Services services) {
    final vendorId = widget.vendorId ?? '';
    final clientId = widget.clientId ?? '';
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    String? key;
    if (companyId.isNotEmpty && vendorId.isNotEmpty) {
      key = 'v:$companyId:$vendorId';
    } else if (companyId.isNotEmpty && clientId.isNotEmpty) {
      key = 'c:$companyId:$clientId';
    }
    if (key == _sourceKey) return;
    _sourceKey = key;
    if (key == null) {
      _currencyId = null;
    } else if (vendorId.isNotEmpty) {
      _currencyId = services.vendors
          .watch(companyId: companyId, id: vendorId)
          .map((v) => v?.currencyId);
    } else {
      _currencyId = services.clients
          .watch(companyId: companyId, id: clientId)
          .map((c) => c?.currencyId);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Guard the no-party case before touching the provider: a billing row with
    // no client/vendor yet has no `Services` in its tree. Reset the hoisted
    // state so a party arriving later rebuilds a fresh stream (rather than
    // reusing a stream whose subscription was torn down).
    if ((widget.vendorId ?? '').isEmpty && (widget.clientId ?? '').isEmpty) {
      _sourceKey = null;
      _currencyId = null;
      return widget.builder(context, null);
    }
    _ensureStream(context.read<Services>());
    final stream = _currencyId;
    if (stream == null) {
      return widget.builder(context, null);
    }
    return StreamBuilder<String?>(
      stream: stream,
      builder: (context, snap) => widget.builder(context, snap.data),
    );
  }
}

/// Money cell for a billing-doc list column that renders in the document's own
/// party currency (client or vendor) instead of the company default. Resolves
/// the party currency via [PartyCurrencyBuilder] then delegates to [cellMoney]
/// — so the zero→em-dash convention, the currency precision, and the no-scope
/// fallback all stay identical to every other money column.
Widget cellPartyMoney(
  Decimal value,
  BuildContext context, {
  String? clientId,
  String? vendorId,
  bool cents = true,
}) {
  // Zero renders as an em-dash regardless of currency — skip the party stream
  // entirely (common for all-zero balance columns).
  if (value == Decimal.zero) return cellMoney(value, context, cents: cents);
  final hasVendor = vendorId != null && vendorId.isNotEmpty;
  final hasClient = clientId != null && clientId.isNotEmpty;
  if (!hasVendor && !hasClient) return cellMoney(value, context, cents: cents);
  return PartyCurrencyBuilder(
    clientId: clientId,
    vendorId: vendorId,
    builder: (context, currencyId) => cellMoney(
      value,
      context,
      cents: cents,
      clientCurrencyId: hasClient ? currencyId : null,
      vendorCurrencyId: hasVendor ? currencyId : null,
    ),
  );
}
